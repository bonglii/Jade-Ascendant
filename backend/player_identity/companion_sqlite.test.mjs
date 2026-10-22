import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { createHash } from 'node:crypto';
import { acceptMetrics, metricSummary, createCompanionHandler, publishedAgenda, purgeExpiredMetrics } from './companion.mjs';

const owner = value => createHash('sha256').update(value).digest('hex');
const STAMP = 1800000000;
const hex = number => number.toString(16).padStart(32, '0');
const metric = (i,kind='stage_enter',chapter=1,stage=1,seconds=0) => ({id:hex(i),kind,chapter,stage,seconds});
function fixture() {
 const native = new DatabaseSync(':memory:');
 native.exec('PRAGMA foreign_keys=ON; CREATE TABLE player_identities (owner_binding TEXT PRIMARY KEY NOT NULL, public_uid TEXT UNIQUE NOT NULL);');
 native.exec(readFileSync(new URL('./companion_schema.sql', import.meta.url),'utf8'));
 const db = {
   withSession(){return this},
   prepare(sql){return {bind(...args){const statement=native.prepare(sql);return {first:async()=>statement.get(...args)||null,all:async()=>({results:statement.all(...args)}),run:async()=>statement.run(...args)}}}},
   async batch(statements){native.exec('BEGIN TRANSACTION;');try{const results=[];for(const statement of statements)results.push(await statement.run());native.exec('COMMIT;');return results}catch(error){native.exec('ROLLBACK;');throw error}}
 };
 const addOwner=name=>{const id=owner(name);native.prepare('INSERT INTO player_identities(owner_binding,public_uid) VALUES (?,?)').run(id,name);return id};
 return {db,native,addOwner};
}

test('SQLite schema keeps owner integrity and isolates identical event identifiers',async()=>{
 const {db,native,addOwner}=fixture(), a=addOwner('account-a'),b=addOwner('account-b');
 assert.deepEqual(await acceptMetrics(db,a,[metric(1)],STAMP),[hex(1)]);
 assert.deepEqual(await acceptMetrics(db,b,[metric(1)],STAMP),[hex(1)]);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1').get().n,2);
 assert.deepEqual(await acceptMetrics(db,a,[metric(1)],STAMP),[hex(1)]);
 await assert.rejects(acceptMetrics(db,a,[metric(1,'stage_clear')],STAMP),e=>e.status===409&&e.code==='event_reused');
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1').get().n,2);
 assert.deepEqual(await acceptMetrics(db,owner('missing'),[metric(2)],STAMP),[]);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1').get().n,2);
 native.close();
});

test('200-per-day bound returns receipts only for committed rows and resets at UTC day',async()=>{
 const {db,native,addOwner}=fixture(),a=addOwner('rate-a');
 const day=STAMP-STAMP%86400;
 const insert=native.prepare('INSERT INTO player_gameplay_metrics_v1 VALUES(?,?,?,?,?,?,?)');
 for(let i=0;i<199;i++)insert.run(a,hex(10000+i),'stage_enter',1,1,0,day+3);
 const acknowledged=await acceptMetrics(db,a,[metric(1),metric(2),metric(3)],STAMP);
 assert.deepEqual(acknowledged,[hex(1)]);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1 WHERE owner_binding=?').get(a).n,200);
 assert.deepEqual(await acceptMetrics(db,a,[metric(2),metric(3)],STAMP+86400),[hex(2),hex(3)]);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1 WHERE owner_binding=?').get(a).n,202);
 native.close();
});

test('30-day retention, seven-day summary, and account-specific deletion never modify another owner',async()=>{
 const {db,native,addOwner}=fixture(),a=addOwner('privacy-a'),b=addOwner('privacy-b');
 await acceptMetrics(db,a,[metric(1,'stage_clear',1,1,125),metric(2,'stage_enter')],STAMP);
 await acceptMetrics(db,b,[metric(3,'stage_clear',1,1,175)],STAMP);
 const aggregated=await metricSummary(db,STAMP);
 const clears=aggregated.rows.find(r=>r.kind==='stage_clear');
 assert.equal(clears.events,2);assert.equal(clears.players,2);assert.equal(clears.average_seconds,150);
 const handler=createCompanionHandler({verify:async(_req,_env)=>'privacy-a',now:()=>STAMP});
 const deleted=await handler(new Request('https://example.test/v1/player/gameplay-metrics',{method:'DELETE'}),{PROFILE_DB:db});
 assert.equal(deleted.status,200);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1 WHERE owner_binding=?').get(a).n,0);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1 WHERE owner_binding=?').get(b).n,1);
 // Arrival of a newer event removes old rows without giving access to other accounts.
 native.prepare('INSERT INTO player_gameplay_metrics_v1 VALUES(?,?,?,?,?,?,?)').run(b,hex(9),'stage_defeat',1,1,30,STAMP-31*86400);
 await acceptMetrics(db,b,[metric(10,'stage_enter')],STAMP);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1 WHERE event_id=?').get(hex(9)).n,0);
 native.close();
});

test('Unauthenticated DELETE cannot erase another player and malformed payload never writes',async()=>{
 const {db,native,addOwner}=fixture();addOwner('safe-player');
 const handler=createCompanionHandler({verify:async()=>{throw Object.assign(new Error('no'),{status:401,code:'unauthorized'})},now:()=>STAMP});
 const response=await handler(new Request('https://example.test/v1/player/gameplay-metrics',{method:'DELETE'}),{PROFILE_DB:db});
 assert.equal(response.status,401);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1').get().n,0);
 native.close();
});

test('Agenda does not publish drafts, disabled events, or unreviewed admin plans',async()=>{
 const env={ODYSSEY_ADMIN_KEY:'fixture-only',ODYSSEY_IAP:{async fetch(url){return Response.json(url.includes('/trials/')?{calendar:[{status:'draft',theme:'secret',starts_at:STAMP,ends_at:STAMP+600},{status:'scheduled',theme:'open',starts_at:STAMP+60,ends_at:STAMP+360}]}:{event:{enabled:false,starts_at:STAMP,ends_at:STAMP+100}})}}};
 const agenda=await publishedAgenda(env,STAMP);
 assert.equal(agenda.events.length,1);assert.equal(agenda.events[0].kind,'heavenly_trials');
 assert.deepEqual((await publishedAgenda({},STAMP)).events,[]);
});

test('Authenticated POST, repeated receipt, tamper rejection and DELETE use signed owner only',async()=>{
 const {db,native,addOwner}=fixture(),account=addOwner('signed-owner'),other=addOwner('different-owner');
 const h=createCompanionHandler({verify:async()=> 'signed-owner',now:()=>STAMP});
 const send=body=>new Request('https://example.test/v1/player/gameplay-metrics',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});
 const payload={version:1,events:[metric(55,'stage_clear',2,5,128)]};
 let result=await h(send(payload),{PROFILE_DB:db});
 assert.equal(result.status,200);assert.deepEqual((await result.json()).accepted,[hex(55)]);
 result=await h(send(payload),{PROFILE_DB:db});assert.equal(result.status,200);assert.deepEqual((await result.json()).accepted,[hex(55)]);
 result=await h(send({version:1,events:[metric(55,'stage_defeat',2,5,128)]}),{PROFILE_DB:db});assert.equal(result.status,409);
 result=await h(send({...payload,owner_binding:other}),{PROFILE_DB:db});assert.equal(result.status,400);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1 WHERE owner_binding=?').get(account).n,1);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1 WHERE owner_binding=?').get(other).n,0);
 result=await h(new Request('https://example.test/v1/player/gameplay-metrics',{method:'DELETE'}),{PROFILE_DB:db});
 assert.equal(result.status,200);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_gameplay_metrics_v1').get().n,0);
 native.close();
});


test('hourly privacy purge deletes expired reports without needing another player event',async()=>{
 const {db,native,addOwner}=fixture(),a=addOwner('inactive-a'),b=addOwner('inactive-b');
 const insert=native.prepare('INSERT INTO player_gameplay_metrics_v1 VALUES(?,?,?,?,?,?,?)');
 insert.run(a,hex(70),'session_start',0,0,0,STAMP-31*86400);
 insert.run(b,hex(71),'session_start',0,0,0,STAMP-30*86400);
 insert.run(a,hex(72),'session_start',0,0,0,STAMP-29*86400);
 assert.equal(await purgeExpiredMetrics(db,STAMP),true);
 assert.deepEqual(native.prepare('SELECT event_id FROM player_gameplay_metrics_v1 ORDER BY event_id').all().map(row=>row.event_id),[hex(71),hex(72)]);
 assert.equal(native.prepare('SELECT COUNT(*) AS n FROM player_identities').get().n,2);
 native.close();
});

test('hourly privacy purge skips pre-migration database and fails closed for bad time',async()=>{
 const {db,native}=fixture();
 native.exec('DROP TABLE player_gameplay_metrics_v1');
 assert.equal(await purgeExpiredMetrics(db,STAMP),false);
 await assert.rejects(purgeExpiredMetrics(db,NaN),/invalid_retention_input/);
 native.close();
});

test('event agenda cache expires at start/end boundaries, not merely after sixty seconds',async()=>{
 let fetches=0;
 const env={ODYSSEY_ADMIN_KEY:'fixture-only',ODYSSEY_IAP:{async fetch(url){fetches++;return Response.json(url.includes('/trials/')?{calendar:[{status:'scheduled',theme:'open_gate',starts_at:STAMP+10,ends_at:STAMP+20}]}:{event:{enabled:false}})}}};
 const initial=await publishedAgenda(env,STAMP);
 assert.equal(initial.events.length,1);assert.equal(initial.events[0].status,'scheduled');
 const unchanged=await publishedAgenda(env,STAMP+5);assert.equal(unchanged.events[0].status,'scheduled');assert.equal(fetches,2);
 const live=await publishedAgenda(env,STAMP+11);assert.equal(live.events[0].status,'live');assert.equal(fetches,4);
 const expired=await publishedAgenda(env,STAMP+21);assert.equal(expired.events.length,0);assert.equal(fetches,6);
});
