import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,mkdtempSync,mkdirSync,copyFileSync,rmSync} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {CASE,reviewedPlan,settlementInsert,voidQuery} from '../../../player_identity/refund_resolution_contract.mjs';
const owner='u1:'+CASE.accountRef+'a'.repeat(52),token='playtoken:'+'b'.repeat(64),key='iapv1:'+'b'.repeat(64);
const sql=readFileSync(new URL('../migrations/0014_refund_resolution.sql',import.meta.url),'utf8');
function fixture(balance=100,credit=100){
 const db=new DatabaseSync(':memory:');db.exec('PRAGMA foreign_keys=ON');
 db.exec(`CREATE TABLE iap_wallet_accounts_v1(owner_key TEXT PRIMARY KEY,balance INTEGER NOT NULL CHECK(balance>=0),revision INTEGER NOT NULL);
 CREATE TABLE iap_wallet_events_v1(event_key TEXT PRIMARY KEY,owner_key TEXT,event_kind TEXT,item_key TEXT,delta INTEGER);
 CREATE TABLE iap_play_void_events_v1(token_key TEXT PRIMARY KEY,owner_key TEXT,voided_time_ms INTEGER,voided_reason INTEGER,voided_source INTEGER);
 CREATE TABLE iap_play_void_cursor_v1(cursor_name TEXT PRIMARY KEY,watermark_ms INTEGER);
 CREATE TABLE iap_refund_account_holds_v1(owner_key TEXT PRIMARY KEY,status TEXT,reason TEXT,revision INTEGER,updated_at TEXT);`);
 db.exec(sql);
 db.prepare('INSERT INTO iap_wallet_accounts_v1 VALUES(?,?,1)').run(owner,balance);
 db.prepare("INSERT INTO iap_refund_account_holds_v1 VALUES(?,'held','play_voided_purchase',1,CURRENT_TIMESTAMP)").run(owner);
 db.prepare("INSERT INTO iap_play_void_cursor_v1 VALUES('voided_inapp',?)").run(Date.now()-60000);
 db.prepare('INSERT INTO iap_play_void_events_v1 VALUES(?,?,?,?,?)').run(token,owner,CASE.voidedAtMs,6,1);
 if(credit)db.prepare("INSERT INTO iap_wallet_events_v1 VALUES(?,?,'play_credit','jade_pouch_100',?)").run(key,owner,credit);
 return db;
}
function account(db){return db.prepare('SELECT a.owner_key,a.balance,a.revision,h.status AS hold_status,h.reason AS hold_reason,h.revision AS hold_revision FROM iap_wallet_accounts_v1 a JOIN iap_refund_account_holds_v1 h ON h.owner_key=a.owner_key').all();}
function plan(db){return reviewedPlan(account(db),db.prepare(voidQuery(owner)).all());}
function count(db,table){return db.prepare('SELECT COUNT(*) AS n FROM '+table).get().n;}
function totals(db){return {wallet:db.prepare('SELECT balance,revision FROM iap_wallet_accounts_v1').get(),hold:db.prepare('SELECT status,revision FROM iap_refund_account_holds_v1').get(),headers:count(db,'iap_refund_resolutions_v1'),settled:count(db,'iap_refund_settlements_v1')};}
function hold(db,reason='play_voided_purchase'){db.prepare(`INSERT INTO iap_refund_account_holds_v1(owner_key,status,reason,revision) VALUES(?,'held',?,1) ON CONFLICT(owner_key) DO UPDATE SET status='held',reason=excluded.reason,revision=revision+1`).run(owner,reason);}
test('credited refund is debited once, audited and released in one statement',()=>{const db=fixture();const p=plan(db);db.exec(settlementInsert(p));assert.equal(totals(db).wallet.balance,0);assert.equal(totals(db).wallet.revision,2);assert.equal(totals(db).hold.status,'released');assert.equal(count(db,'iap_refund_resolutions_v1'),1);assert.equal(count(db,'iap_refund_settlements_v1'),1);assert.equal(count(db,'iap_wallet_events_v1'),1);assert.equal(plan(db).alreadyApplied,true);db.exec(settlementInsert(p));assert.equal(totals(db).wallet.revision,2);db.close();});
test('refund cron overlap and direct replay cannot re-hold a settled order',()=>{const db=fixture();db.exec(settlementInsert(plan(db)));for(let i=0;i<4;i++)hold(db);db.prepare("UPDATE iap_refund_account_holds_v1 SET status='held' WHERE owner_key=?").run(owner);assert.equal(totals(db).hold.status,'released');assert.equal(totals(db).wallet.balance,0);db.close();});
test('new refund after settlement creates a fresh hold',()=>{const db=fixture();db.exec(settlementInsert(plan(db)));db.prepare('INSERT INTO iap_play_void_events_v1 VALUES(?,?,?,?,?)').run('playtoken:'+'c'.repeat(64),owner,Date.now()-60000,0,1);hold(db);assert.equal(totals(db).hold.status,'held');db.close();});
test('manual review and chargeback holds are preserved',()=>{for(const reason of ['manual_review','chargeback_review']){const db=fixture();db.exec(settlementInsert(plan(db)));hold(db,reason);hold(db);const h=db.prepare('SELECT status,reason FROM iap_refund_account_holds_v1').get();assert.equal(h.status,'held');assert.equal(h.reason,reason);db.close();}});
test('concurrent wallet change aborts every resolution write',()=>{const db=fixture();const p=plan(db);db.exec('UPDATE iap_wallet_accounts_v1 SET balance=150,revision=2');const before=totals(db);assert.throws(()=>db.exec(settlementInsert(p)),/refund_wallet_changed/);assert.deepEqual(totals(db),before);db.close();});
test('concurrent hold change aborts settlement',()=>{const db=fixture();const p=plan(db);db.exec("UPDATE iap_refund_account_holds_v1 SET reason='manual_review',revision=2");const before=totals(db);assert.throws(()=>db.exec(settlementInsert(p)),/refund_hold_changed/);assert.deepEqual(totals(db),before);db.close();});
test('new void after review aborts instead of releasing incomplete debt',()=>{const db=fixture();const p=plan(db);db.prepare('INSERT INTO iap_play_void_events_v1 VALUES(?,?,?,?,?)').run('playtoken:'+'c'.repeat(64),owner,Date.now(),0,1);assert.throws(()=>db.exec(settlementInsert(p)),/refund_void_set_changed/);assert.equal(count(db,'iap_refund_resolutions_v1'),0);assert.equal(totals(db).wallet.balance,100);db.close();});
test('insufficient balance never goes negative or releases hold',()=>{const db=fixture(99);assert.throws(()=>plan(db),/Account changed/);const fake={...account(db)[0],balance:100};const p=reviewedPlan([fake],db.prepare(voidQuery(owner)).all());assert.throws(()=>db.exec(settlementInsert(p)),/refund_wallet_changed/);assert.equal(totals(db).hold.status,'held');db.close();});
test('stale refund monitor aborts reviewed settlement',()=>{const db=fixture();const p=plan(db);db.exec('UPDATE iap_play_void_cursor_v1 SET watermark_ms=1');assert.throws(()=>db.exec(settlementInsert(p)),/refund_monitor_stale/);assert.equal(count(db,'iap_refund_resolutions_v1'),0);db.close();});
test('wrong credit amount, product, account or extra void is rejected',()=>{const db=fixture();const a=account(db),v=db.prepare(voidQuery(owner)).all();for(const overrides of [{delta:101},{item_key:'jade_other'},{credit_owner:'u1:'+'d'.repeat(64)},{voided_reason:8}])assert.throws(()=>reviewedPlan(a,[{...v[0],...overrides}]),/differs/);assert.throws(()=>reviewedPlan(a,[v[0],v[0]]),/single-order/);assert.throws(()=>reviewedPlan([] ,v),/exactly one/);db.close();});
test('tampered token set, sum and duplicate evidence abort atomically',()=>{for(const mutate of [p=>{p.voids[0].credited_jade=99;p.debit=99;p.after=1;},p=>{p.voids[0].token_key='playtoken:'+'c'.repeat(64);},p=>{p.voids.push(p.voids[0]);}]){const db=fixture();const p=plan(db);mutate(p);assert.throws(()=>db.exec(settlementInsert(p)));assert.equal(count(db,'iap_refund_resolutions_v1'),0);assert.equal(totals(db).wallet.balance,100);db.close();}});
test('exception inside apply trigger rolls back header, debit and hold',()=>{const db=fixture();const p=plan(db);db.exec("CREATE TRIGGER reject_test AFTER UPDATE ON iap_wallet_accounts_v1 BEGIN SELECT RAISE(ABORT,'injected_failure'); END;");assert.throws(()=>db.exec(settlementInsert(p)),/injected_failure/);assert.equal(count(db,'iap_refund_resolutions_v1'),0);assert.equal(count(db,'iap_refund_settlements_v1'),0);assert.equal(totals(db).wallet.balance,100);assert.equal(totals(db).hold.status,'held');db.close();});
test('audit records are immutable and migration reruns are idempotent',()=>{const db=fixture();db.exec(sql);db.exec(settlementInsert(plan(db)));for(const table of ['iap_refund_resolutions_v1','iap_refund_settlements_v1']){assert.throws(()=>db.exec('DELETE FROM '+table),/refund_audit_immutable/);assert.throws(()=>db.exec('UPDATE '+table+' SET owner_key=owner_key'),/refund_audit_immutable/);}db.close();});

test('operator case recovery is isolated, verified and safe to rerun',async()=>{
 const require=createRequire(import.meta.url),{recover}=require('../../../player_identity/refund_resolution_remote.cjs');
 const temp=mkdtempSync(path.join(os.tmpdir(),'jade-refund-cli-'));
 const root=fileURLToPath(new URL('../../../../',import.meta.url));
 for(const file of ['backend/player_identity/refund_resolution_contract.mjs','backend/monetization/cloudflare/migrations/0014_refund_resolution.sql']){mkdirSync(path.dirname(path.join(temp,file)),{recursive:true});copyFileSync(path.join(root,file),path.join(temp,file));}
 const db=fixture(),log=console.log;console.log=()=>{};
 try{
  const execute=(sql,_label,{file=false}={})=>{if(file){db.exec(readFileSync(sql,'utf8'));return null;}return db.prepare(sql).all();};
  const first=await recover(temp,{execute}),second=await recover(temp,{execute});
  assert.equal(first.balance,0);assert.equal(first.alreadyApplied,false);assert.equal(second.alreadyApplied,true);assert.equal(count(db,'iap_refund_resolutions_v1'),1);assert.equal(totals(db).hold.status,'released');
 }finally{console.log=log;db.close();rmSync(temp,{recursive:true,force:true});}
});

test('review matches the observed UTC second without assuming hidden milliseconds',()=>{const db=fixture();db.prepare('UPDATE iap_play_void_events_v1 SET voided_time_ms=?').run(CASE.voidedAtMs+734);assert.equal(plan(db).debit,100);db.prepare('UPDATE iap_play_void_events_v1 SET voided_time_ms=?').run(CASE.voidedAtMs+1000);assert.throws(()=>plan(db),/differs/);db.close();});
