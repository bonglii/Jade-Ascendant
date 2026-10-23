import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {planRepair} from './repair_trials_time.mjs';
const now=1792814400,WEEK=604800,start=now-((now+270000)%WEEK+WEEK)%WEEK;
const campaign=(id='future',extra={})=>({id,starts_at:start+3*WEEK,enabled:true,ads_enabled:false,shop_enabled:false,themes:['jade_wind','scarlet_rite','starfall','froststep','sunforge'],reward:{celestial_jade:20,pavilion_seal:1,spirit_stone:300},...extra});
const row=c=>({id:c.id,document:JSON.stringify(c),created_at:now-100,server_now:now,materialized_weeks:0});
function db(rows){const d=new DatabaseSync(':memory:');d.function('unixepoch',{varargs:true},()=>now);d.exec('CREATE TABLE ht_campaigns(id TEXT PRIMARY KEY,document TEXT,created_at INTEGER);CREATE TABLE ht_weeks(id TEXT,campaign TEXT);CREATE TABLE ht_audit(campaign TEXT,action TEXT,document TEXT,created_at INTEGER);CREATE TABLE player_save(id TEXT,value TEXT);INSERT INTO player_save VALUES(1,\'keep\')');for(const r of rows)d.prepare('INSERT INTO ht_campaigns VALUES(?,?,?)').run(r.id,r.document,r.created_at);return d;}
test('first unpublished-in-time rotation moves to current Monday04WIB without changing rewards or flags',()=>{const r=row(campaign()),p=planRepair([r]);assert.equal(p.starts_at,start);assert.equal((p.starts_at+270000)%WEEK,0);const n=JSON.parse(p.after);assert.deepEqual({...n,starts_at:JSON.parse(p.before).starts_at},JSON.parse(p.before));assert.match(p.starts_wib,/WIB/);const d=db([r]);try{d.exec(p.sql);assert.equal(d.prepare('SELECT document FROM ht_campaigns').get().document,p.after);d.exec(p.sql);assert.equal(d.prepare('SELECT COUNT(*) n FROM ht_audit').get().n,1);assert.equal(d.prepare('SELECT value FROM player_save').get().value,'keep')}finally{d.close()}});
test('current live week is preserved, future rotation uses next Monday',()=>{const rows=[row(campaign()),row(campaign('active',{starts_at:start}))];const p=planRepair(rows);assert.equal(p.starts_at,start+WEEK);const d=db(rows);try{d.exec(p.sql);assert.equal(d.prepare("SELECT document FROM ht_campaigns WHERE id='active'").get().document,rows[1].document)}finally{d.close()}});
test('ambiguous, no future, occupied slot and frozen weeks refuse before any write',()=>{assert.throws(()=>planRepair([row(campaign()),row(campaign('second'))]),/Expected one/);assert.throws(()=>planRepair([row(campaign('live',{starts_at:start}))]),/Expected one/);assert.throws(()=>planRepair([{...row(campaign()),materialized_weeks:1}]),/frozen/);assert.throws(()=>planRepair([row(campaign()),row(campaign('paused',{starts_at:start+WEEK,enabled:false})),row(campaign('live',{starts_at:start-WEEK}))]),/occupied/)});
for(const mutation of ['freeze','document','slot','new campaign','another edit'])test('atomic compare-and-swap rejects concurrent '+mutation,()=>{const rows=[row(campaign()),row(campaign('old',{starts_at:start-WEEK}))],p=planRepair(rows),d=db(rows);try{if(mutation==='freeze')d.exec("INSERT INTO ht_weeks VALUES('frozen','future')");if(mutation==='document')d.exec("UPDATE ht_campaigns SET document=json_set(document,'$.enabled',0) WHERE id='future'");if(mutation==='slot')d.prepare('INSERT INTO ht_campaigns VALUES(?,?,?)').run('collision',JSON.stringify(campaign('collision',{starts_at:start+WEEK})),now);if(mutation==='new campaign')d.prepare('INSERT INTO ht_campaigns VALUES(?,?,?)').run('new',JSON.stringify(campaign('new',{starts_at:start+5*WEEK})),now);if(mutation==='another edit')d.exec("UPDATE ht_campaigns SET document=json_set(document,'$.enabled',0) WHERE id='old'");d.exec(p.sql);assert.notEqual(d.prepare("SELECT document FROM ht_campaigns WHERE id='future'").get().document,p.after);assert.equal(d.prepare('SELECT COUNT(*) n FROM ht_audit').get().n,0)}finally{d.close()}});

// Regression: the original campaign-driven SELECT returned zero rows and lost
// unixepoch('now') as well. Exercise the production query against real SQLite.
import {SNAPSHOT_SQL,verifyResult,readRows} from './repair_trials_time.mjs';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
test('empty campaign table retains the independent database clock and produces no SQL write',()=>{
 const d=db([]);try{
  const old=d.prepare("SELECT c.id,unixepoch('now') AS server_now FROM ht_campaigns c").all();assert.deepEqual(old,[]);assert.throws(()=>planRepair(old),/no clock row/);
  const rows=d.prepare(SNAPSHOT_SQL).all();assert.equal(rows.length,1);assert.equal(rows[0].server_now,now);assert.equal(rows[0].id,null);
  const p=planRepair(rows);assert.equal(p.kind,'skip');assert.equal(p.reason,'NO_CAMPAIGNS');assert.equal(p.sql,null);
  assert.equal(verifyResult(rows,p).status,'skipped');
  assert.equal(d.prepare('SELECT COUNT(*) n FROM ht_campaigns').get().n,0);assert.equal(d.prepare('SELECT COUNT(*) n FROM ht_audit').get().n,0);
  assert.equal(d.prepare('SELECT value FROM player_save').get().value,'keep');
 }finally{d.close()}
});
test('clock-backed snapshot repairs a real future campaign with unchanged guards',()=>{
 const d=db([row(campaign())]);try{const rows=d.prepare(SNAPSHOT_SQL).all(),p=planRepair(rows);assert.equal(p.kind,'repair');d.exec(p.sql);assert.equal(verifyResult(d.prepare("SELECT document FROM ht_campaigns WHERE id='future'").all(),p).status,'repaired')}finally{d.close()}
});
test('empty skip cannot silently target an explicit ID or erase a newly appeared event',()=>{
 const d=db([]);try{const rows=d.prepare(SNAPSHOT_SQL).all();assert.throws(()=>planRepair(rows,'missing'),/does not exist/);const p=planRepair(rows);d.prepare('INSERT INTO ht_campaigns VALUES(?,?,?)').run('future',JSON.stringify(campaign()),now);assert.throws(()=>verifyResult(d.prepare(SNAPSHOT_SQL).all(),p),/changed/);assert.equal(d.prepare('SELECT COUNT(*) n FROM ht_campaigns').get().n,1)}finally{d.close()}
});
test('device clock is never a substitute for missing/mismatched database time',()=>{
 assert.throws(()=>planRepair([{id:null,document:null}]),/trusted database time/);
 assert.throws(()=>planRepair([row(campaign()),{...row(campaign('other')),server_now:now+1}]),/inconsistent/);
 assert.throws(()=>planRepair([{server_now:now}]),/Malformed/);
});
test('CLI prepare/verify emits SKIPPED, writes no repair.sql and preserves failure causes',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jade-time-empty-'));
 const script=new URL('./repair_trials_time.mjs',import.meta.url);
 const run=args=>spawnSync(process.execPath,[fileURLToPath(script),...args],{encoding:'utf8'});
 try{
  const input=path.join(dir,'snapshot.json'),folder=path.join(dir,'receipt');
  const d=db([]);try{fs.writeFileSync(input,JSON.stringify([{success:true,results:d.prepare(SNAPSHOT_SQL).all()}]))}finally{d.close()}
  let result=run(['prepare',input,folder]);assert.equal(result.status,0,result.stderr);assert.match(result.stdout,/PLAN=SKIP/);assert.equal(fs.existsSync(path.join(folder,'repair.sql')),false);assert.equal(fs.readFileSync(path.join(folder,'verify.sql'),'utf8'),SNAPSHOT_SQL);
  result=run(['verify',input,folder]);assert.equal(result.status,0,result.stderr);assert.match(result.stdout,/TRIALS_TIME_SKIPPED=NO_CAMPAIGNS/);assert.doesNotMatch(result.stdout,/TRIALS_TIME_RESET=PASS/);assert.equal(JSON.parse(fs.readFileSync(path.join(folder,'done.json'))).status,'skipped');
  fs.writeFileSync(input,JSON.stringify([{success:true,results:[]}]));assert.deepEqual(readRows(input),[]);result=run(['prepare',input,path.join(dir,'bad')]);assert.notEqual(result.status,0);assert.match(result.stderr,/TRIALS_TIME_STOPPED: Snapshot has no clock row/);
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
});
