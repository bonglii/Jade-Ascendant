/** Runs against actual patched d1_wallet.mjs, NOT a mock wallet implementation. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { createD1Wallet } from '../src/d1_wallet.mjs';
const h = value => createHash('sha256').update(value).digest('hex');
const uid='firebase-person-1', ownerKey='u1:'+h(uid);
const tokenFingerprint=h('purchase-receipt-1'), grantId='iapv1:'+tokenFingerprint;
const now=Date.now();
function grant(id=grantId){return {
  purchase_contract_version:1,state:'grant_ready',grant_id:id,
  internal_product_id:'jade_pouch_100',celestial_jade:100,
};}
function fixture(){
  const sql=new DatabaseSync(':memory:');
  sql.exec(`PRAGMA foreign_keys=ON;
    CREATE TABLE iap_wallet_accounts_v1 (
      owner_key TEXT PRIMARY KEY NOT NULL, balance INTEGER NOT NULL DEFAULT 0 CHECK(balance BETWEEN 0 AND 9007199254740991),
      revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0));
    CREATE TABLE iap_wallet_events_v1 (event_key TEXT PRIMARY KEY,owner_key TEXT NOT NULL,event_kind TEXT NOT NULL,item_key TEXT NOT NULL,delta INTEGER NOT NULL,
      FOREIGN KEY(owner_key) REFERENCES iap_wallet_accounts_v1(owner_key));
    CREATE TABLE iap_refund_account_holds_v1 (owner_key TEXT PRIMARY KEY,status TEXT NOT NULL CHECK(status IN ('held','released')));
    CREATE TABLE iap_play_void_events_v1 (token_key TEXT PRIMARY KEY,owner_key TEXT);
    CREATE TABLE iap_play_void_cursor_v1 (cursor_name TEXT PRIMARY KEY,watermark_ms INTEGER NOT NULL);`);
  const db={
    prepare(stmt){return {
      bind(...args){return {
        async first(){return sql.prepare(stmt).get(...args)??null;},
        async all(){return {results:sql.prepare(stmt).all(...args)};},
        run(){return sql.prepare(stmt).run(...args);},
      };}
    };},
    withSession(mode){assert.equal(mode,'first-primary');return this;},
    async batch(items){sql.exec('BEGIN IMMEDIATE');try{
      const out=items.map(s=>s.run());sql.exec('COMMIT');return out;
    }catch(e){sql.exec('ROLLBACK');throw e;}}
  };
  return {
    sql,db,wallet:createD1Wallet(db),
    fresh(){sql.prepare("INSERT OR REPLACE INTO iap_play_void_cursor_v1 VALUES ('voided_inapp',?)").run(now-10000);},
    stale(){sql.prepare("INSERT OR REPLACE INTO iap_play_void_cursor_v1 VALUES ('voided_inapp',?)").run(now-3*3600000);},
    void(){sql.prepare('INSERT INTO iap_play_void_events_v1 VALUES (?,?)').run('playtoken:'+tokenFingerprint,ownerKey);},
    hold(){sql.prepare("INSERT INTO iap_refund_account_holds_v1 VALUES (?,'held')").run(ownerKey);},
    balance(){return {...sql.prepare('SELECT balance, revision FROM iap_wallet_accounts_v1 WHERE owner_key=?').get(ownerKey)};},
    events(){return sql.prepare('SELECT * FROM iap_wallet_events_v1').all();},
    close(){sql.close();}
  };
}
test('actual D1Wallet original API credits exactly once and retains original balance schema',async()=>{
 const f=fixture();try{f.fresh();let a=await f.wallet.creditVerifiedPurchase(uid,grant());assert.deepEqual(a,{wallet_contract_version:1,balance:100,revision:1,applied:true});
 a=await f.wallet.creditVerifiedPurchase(uid,grant());assert.deepEqual(a,{wallet_contract_version:1,balance:100,revision:1,applied:false});
 assert.equal(f.events().length,1);}finally{f.close();}
});
test('already credited refund is NOT reported as successful purchase replay',async()=>{
 const f=fixture();try{f.fresh();await f.wallet.creditVerifiedPurchase(uid,grant());f.void();
 await assert.rejects(f.wallet.creditVerifiedPurchase(uid,grant()),{name:'RefundCreditGateErrorRC8',code:'refund_or_hold'});
 assert.deepEqual(f.balance(),{balance:100,revision:1});assert.equal(f.events().length,1);}finally{f.close();}
});
test('new voided Play purchase fails before creating wallet or events',async()=>{
 const f=fixture();try{f.fresh();f.void();await assert.rejects(f.wallet.creditVerifiedPurchase(uid,grant()),{name:'RefundCreditGateErrorRC8',code:'refund_or_hold'});
 assert.equal(f.events().length,0);}finally{f.close();}
});
test('new purchase is rejected during account hold',async()=>{
 const f=fixture();try{f.fresh();f.hold();await assert.rejects(f.wallet.creditVerifiedPurchase(uid,grant()),{name:'RefundCreditGateErrorRC8',code:'refund_or_hold'});
 assert.equal(f.events().length,0);}finally{f.close();}
});
test('missing/stale refund poll fails closed on new and replay purchases',async()=>{
 const f=fixture();try{
 await assert.rejects(f.wallet.creditVerifiedPurchase(uid,grant()),{name:'RefundCreditGateErrorRC8',code:'refund_monitor_stale'});
 f.fresh();await f.wallet.creditVerifiedPurchase(uid,grant());f.stale();
 await assert.rejects(f.wallet.creditVerifiedPurchase(uid,grant()),{name:'RefundCreditGateErrorRC8',code:'refund_monitor_stale'});
 assert.deepEqual(f.balance(),{balance:100,revision:1});
 }finally{f.close();}
});
test('valid grant cannot be credited across Firebase owner without a second event',async()=>{
 const f=fixture();try{f.fresh();await f.wallet.creditVerifiedPurchase(uid,grant());
 await assert.rejects(f.wallet.creditVerifiedPurchase('firebase-person-2',grant()));
 assert.equal(f.events().length,1);assert.equal(f.balance().balance,100);
 }finally{f.close();}
});
test('non-Play internal server debit follows existing wallet implementation',async()=>{
 const f=fixture();try{f.fresh();await f.wallet.creditVerifiedPurchase(uid,grant());
 const paid=await f.wallet.debitServerAuthorizedSummon(uid,{spendId:'spendv1:'+h('server-spend'),intent:'summon:1',jadeCost:25});
 assert.deepEqual(paid,{wallet_contract_version:1,balance:75,revision:2,applied:true});assert.equal(f.events().length,2);
 }finally{f.close();}
});
