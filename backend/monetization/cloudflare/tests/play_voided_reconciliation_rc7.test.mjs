import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import {
  recordPlayVoidRC7,reconcilePlayVoidsRC7,reconcileUnmatchedVoidsRC7,
  creditNotVoidedSqlRC7,VoidedReconciliationErrorRC7,
} from '../src/play_voided_reconciliation_rc7.mjs';

const token='TOKEN_from_google_verified_voided_record_123';
const hash = x => createHash('sha256').update(x).digest('hex');
const key='playtoken:'+hash(token);
const uid='Firebase_UID_1234';
const owner='u1:'+hash(uid);
const NOW=Date.parse('2026-10-10T08:00:00Z');
const voidItem=(overrides={})=>({purchaseToken:token,voidedTimeMillis:String(NOW-300000),voidedReason:7,voidedSource:2,...overrides});
function fakeD1(sqlite) {
  const db={
    prepare(sql){
      return {
        async first(){return sqlite.prepare(sql).get()??null;},
        async all(){return {results:sqlite.prepare(sql).all()};},
        bind(...args){
        return {
          async first(){return sqlite.prepare(sql).get(...args)??null;},
          async all(){return {results:sqlite.prepare(sql).all(...args)};},
          run(){return sqlite.prepare(sql).run(...args);},
        };
      }};
    },
    withSession(mode){assert.equal(mode,'first-primary');return this;},
    async batch(stmts){
      sqlite.exec('BEGIN IMMEDIATE');
      try{const r=stmts.map(s=>s.run());sqlite.exec('COMMIT');return r;}
      catch(e){sqlite.exec('ROLLBACK');throw e;}
    },
  };
  return db;
}
function fixture(withLedger=true){
  const sqlite=new DatabaseSync(':memory:');
  sqlite.exec('PRAGMA foreign_keys=ON');
  sqlite.exec(`CREATE TABLE iap_wallet_accounts_v1 (owner_key TEXT PRIMARY KEY,balance INTEGER NOT NULL DEFAULT 0 CHECK(balance >= 0),revision INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE iap_purchase_ledger_v1(token_key TEXT PRIMARY KEY,record_json TEXT NOT NULL);`);
  sqlite.exec(readFileSync(new URL('../migrations/0008_refund_account_holds.sql',import.meta.url),'utf8').replaceAll('CREATE TABLE IF NOT EXISTS','CREATE TABLE IF NOT EXISTS'));
  sqlite.exec(readFileSync(new URL('../migrations/0009_play_voided_reconciliation.sql',import.meta.url),'utf8'));
  if(withLedger) addLedger(sqlite);
  return {sqlite,db:fakeD1(sqlite)};
}
function addLedger(sqlite, custom={}) {
  const uid2=custom.uid||uid, raw={
    tokenKey:key, grantId:'iapv1:'+hash(token),ownerUid:uid2,ownerBinding:hash(uid2),
    state:'grant_ready',...custom,
  };
  sqlite.prepare('INSERT OR REPLACE INTO iap_purchase_ledger_v1 VALUES (?,?)').run(key,JSON.stringify(raw));
}
function table(sqlite,name){return sqlite.prepare(`SELECT * FROM ${name}`).all();}

test('trusted Google refund fingerprint creates account hold + audit atomically',async()=>{
 const {sqlite,db}=fixture();
 assert.deepEqual(await recordPlayVoidRC7({db,item:voidItem(),nowMs:NOW}),{matched:true});
 const holds=table(sqlite,'iap_refund_account_holds_v1');
 assert.equal(holds.length,1);assert.equal(holds[0].owner_key,owner);assert.equal(holds[0].status,'held');
 const rows=table(sqlite,'iap_play_void_events_v1');
 assert.equal(rows.length,1);assert.equal(rows[0].token_key,key);assert.equal(rows[0].owner_key,owner);
 assert.ok(!JSON.stringify(rows).includes(token));assert.ok(!JSON.stringify(holds).includes(uid));
 sqlite.close();
});
test('replay is idempotent; hold does not change revision while already held',async()=>{
 const {sqlite,db}=fixture();
 await recordPlayVoidRC7({db,item:voidItem(),nowMs:NOW});
 await recordPlayVoidRC7({db,item:voidItem(),nowMs:NOW});
 assert.equal(table(sqlite,'iap_play_void_events_v1').length,1);
 assert.equal(table(sqlite,'iap_refund_account_holds_v1')[0].revision,1);
 sqlite.close();
});
test('manual release cannot silently survive later observed void',async()=>{
 const {sqlite,db}=fixture();
 await recordPlayVoidRC7({db,item:voidItem(),nowMs:NOW});
 sqlite.prepare("UPDATE iap_refund_account_holds_v1 SET status='released' WHERE owner_key=?").run(owner);
 await recordPlayVoidRC7({db,item:voidItem(),nowMs:NOW});
 assert.equal(table(sqlite,'iap_refund_account_holds_v1')[0].status,'held');
 assert.equal(table(sqlite,'iap_refund_account_holds_v1')[0].revision,2);
 sqlite.close();
});
test('unknown token is audited; later purchase ledger association creates hold',async()=>{
 const {sqlite,db}=fixture(false);
 assert.deepEqual(await recordPlayVoidRC7({db,item:voidItem(),nowMs:NOW}),{matched:false});
 assert.equal(table(sqlite,'iap_refund_account_holds_v1').length,0);
 assert.equal(table(sqlite,'iap_play_void_events_v1')[0].owner_key,null);
 addLedger(sqlite);
 assert.deepEqual(await reconcileUnmatchedVoidsRC7({db}),{reviewed:1,matched:1});
 assert.equal(table(sqlite,'iap_refund_account_holds_v1')[0].status,'held');
 sqlite.close();
});
test('corrupted ledger identity fails closed; no audit or holds created',async()=>{
 const {sqlite,db}=fixture(false);addLedger(sqlite,{ownerBinding:'wrong'});
 await assert.rejects(recordPlayVoidRC7({db,item:voidItem(),nowMs:NOW}),
   {name:'VoidedReconciliationErrorRC7',code:'ledger_corrupted'});
 assert.equal(table(sqlite,'iap_play_void_events_v1').length,0);
 sqlite.close();
});
test('invalid Play response cannot advance watermark',async()=>{
 const {sqlite,db}=fixture();
 await assert.rejects(reconcilePlayVoidsRC7({db,nowMs:NOW,
   listVoidedPage:async()=>({voidedPurchases:[voidItem({purchaseToken:'bad'})]})}),
   VoidedReconciliationErrorRC7);
 assert.equal(table(sqlite,'iap_play_void_cursor_v1').length,0);
 sqlite.close();
});
test('pagination completes before cursor moves; replays are safe',async()=>{
 const {sqlite,db}=fixture();let n=0;
 const poll=()=>reconcilePlayVoidsRC7({db,nowMs:NOW,listVoidedPage:async ({pageToken})=>{
    n++;return pageToken===null?{voidedPurchases:[voidItem()],tokenPagination:{nextPageToken:'NEXT_page_2'}}:
      {voidedPurchases:[voidItem()],tokenPagination:{}};
 }});
 let out=await poll();assert.equal(out.pages,2);assert.equal(out.matched,2);
 assert.equal(table(sqlite,'iap_play_void_cursor_v1')[0].watermark_ms,NOW-60000);
 out=await poll();assert.equal(table(sqlite,'iap_play_void_events_v1').length,1);
 assert.equal(table(sqlite,'iap_play_void_cursor_v1')[0].revision,2);
 sqlite.close();
});
test('page failure preserves watermark and holds already seen items',async()=>{
 const {sqlite,db}=fixture();
 await assert.rejects(reconcilePlayVoidsRC7({db,nowMs:NOW,listVoidedPage:async({pageToken})=>{
   if(pageToken)throw new Error('play_503');
   return {voidedPurchases:[voidItem()],tokenPagination:{nextPageToken:'NEXT'}};
 }}),/play_503/);
 assert.equal(table(sqlite,'iap_play_void_cursor_v1').length,0);
 assert.equal(table(sqlite,'iap_refund_account_holds_v1')[0].status,'held');
 sqlite.close();
});
test('pagination token cycle detected; no cursor advancement',async()=>{
 const {sqlite,db}=fixture();
 await assert.rejects(reconcilePlayVoidsRC7({db,nowMs:NOW,listVoidedPage:async()=>({voidedPurchases:[],tokenPagination:{nextPageToken:'SAME'}})}),
   {name:'VoidedReconciliationErrorRC7',code:'invalid_pagination'});
 assert.equal(table(sqlite,'iap_play_void_cursor_v1').length,0);
 sqlite.close();
});
test('stale poll cursor >29 days refuses a misleading success',async()=>{
 const {sqlite,db}=fixture();
 sqlite.prepare("INSERT INTO iap_play_void_cursor_v1 VALUES ('voided_inapp',?,1,CURRENT_TIMESTAMP)").run(NOW-30*86400000);
 await assert.rejects(reconcilePlayVoidsRC7({db,nowMs:NOW,listVoidedPage:async()=>({voidedPurchases:[]})}),
   {name:'VoidedReconciliationErrorRC7',code:'reconciliation_gap'});
 sqlite.close();
});
test('atomic SQL credit guard rejects refunded grant and held account',async()=>{
 const {sqlite,db}=fixture();
 sqlite.prepare('INSERT INTO iap_wallet_accounts_v1 VALUES (?,0,0)').run(owner);
 const sql=`SELECT (${creditNotVoidedSqlRC7()}) AS eligible`;
 const credit='iapv1:'+hash(token);
 assert.equal(sqlite.prepare(sql).get(credit,owner).eligible,1);
 await recordPlayVoidRC7({db,item:voidItem(),nowMs:NOW});
 assert.equal(sqlite.prepare(sql).get(credit,owner).eligible,0);
 sqlite.close();
});
test('malformed partial quantity is fail closed',async()=>{
 const {sqlite,db}=fixture();
 await assert.rejects(recordPlayVoidRC7({db,item:voidItem({voidedQuantity:2}),nowMs:NOW}),
   {name:'VoidedReconciliationErrorRC7',code:'invalid_play_void'});
 sqlite.close();
});
