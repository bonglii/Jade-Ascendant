import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {createD1Wallet} from '../src/d1_wallet.mjs';
import {repairVerifiedPurchases} from '../src/verified_purchase_repair.mjs';
import {firstTopupProduct,productByPlayId,productByInternalId,FIRST_TOPUP_PRODUCTS} from '../../src/product_catalog.mjs';
import {authorizePurchase,accountBindingForUid} from '../../src/purchase_authority.mjs';
const h=s=>createHash('sha256').update(s).digest('hex');
const uid='first-topup-owner';
function fixture(){
 const sql=new DatabaseSync(':memory:');
 sql.exec(readFileSync(new URL('../migrations/0002_wallet_ledger.sql',import.meta.url),'utf8'));
 sql.exec(`CREATE TABLE iap_purchase_ledger_v1(token_key TEXT PRIMARY KEY,record_json TEXT NOT NULL,revision INTEGER DEFAULT 1);
  CREATE TABLE iap_refund_account_holds_v1(owner_key TEXT PRIMARY KEY,status TEXT);
  CREATE TABLE iap_play_void_events_v1(token_key TEXT PRIMARY KEY,owner_key TEXT);
  CREATE TABLE iap_play_void_cursor_v1(cursor_name TEXT PRIMARY KEY,watermark_ms INTEGER);
  INSERT INTO iap_play_void_cursor_v1 VALUES('voided_inapp',${Date.now()});`);
 let beforeBatch=()=>{};
 const db={prepare(query){const stmt={bind(...args){return {first:async()=>sql.prepare(query).get(...args)??null,all:async()=>({results:sql.prepare(query).all(...args)}),run:()=>sql.prepare(query).run(...args)};}};return stmt;},withSession(){return this;},async batch(items){beforeBatch();sql.exec('BEGIN IMMEDIATE');try{const out=items.map(x=>x.run());sql.exec('COMMIT');return out;}catch(e){sql.exec('ROLLBACK');throw e;}}};
 const wallet=createD1Wallet(db);
 function grant(token='first',owner=uid,id='jade_pouch_100',legacy=false){
  const p=legacy?productByInternalId(id):firstTopupProduct(id),fingerprint=h(token),ownerKey='u1:'+h(owner);
  sql.prepare('INSERT OR IGNORE INTO iap_purchase_ledger_v1(token_key,record_json) VALUES(?,?)').run('playtoken:'+fingerprint,JSON.stringify({playProductId:p.playProductId,internalProductId:id,ownerUid:owner}));
  return {purchase_contract_version:1,state:'grant_ready',grant_id:'iapv1:'+fingerprint,internal_product_id:id,celestial_jade:p.celestialJade};
 }
 return {sql,db,wallet,grant,before(fn){beforeBatch=fn;},close(){sql.close();},events(){return sql.prepare('SELECT * FROM iap_wallet_events_v1').all();}};
}
test('all six new Play SKUs halve base and preserve immutable legacy quantities',()=>{
 assert.deepEqual(FIRST_TOPUP_PRODUCTS.map(p=>p.celestialJade),[50,275,600,1250,3250,7000]);
 for(const p of FIRST_TOPUP_PRODUCTS){assert.equal(productByPlayId(p.playProductId).celestialJade,p.firstTopupBonus);assert.equal(productByInternalId(p.internalProductId).celestialJade,p.celestialJade*2);}
});
test('legacy promise retained; first v2 double, later base; restore never credits twice',async()=>{
 const f=fixture();try{
  const old=f.grant('old',uid,'jade_pouch_100',true),first=f.grant('first'),second=f.grant('second');
  assert.equal((await f.wallet.creditVerifiedPurchase(uid,old)).balance,100);
  assert.equal((await f.wallet.creditVerifiedPurchase(uid,first)).balance,200);
  assert.equal((await f.wallet.creditVerifiedPurchase(uid,second)).balance,250);
  for(const g of [old,first,second])assert.equal((await f.wallet.creditVerifiedPurchase(uid,g)).applied,false);
  assert.deepEqual(f.events().map(e=>e.delta),[100,100,50]);
 }finally{f.close();}
});
test('concurrent first requests share one bonus per account and pack',async()=>{
 const f=fixture();try{
  const results=await Promise.all([1,2,3].map(n=>f.wallet.creditVerifiedPurchase(uid,f.grant('race'+n))));
  assert.equal(Math.max(...results.map(r=>r.balance)),200);
  assert.deepEqual(f.events().map(e=>e.delta).sort((a,b)=>a-b),[50,50,100]);
  assert.equal((await f.wallet.creditVerifiedPurchase(uid,f.grant('tier',uid,'jade_satchel_550'))).balance,750);
  assert.equal((await f.wallet.creditVerifiedPurchase('another-owner',f.grant('owner','another-owner'))).balance,100);
 }finally{f.close();}
});
test('failed atomic credit cannot consume first bonus; refund gate rolls back the entire batch',async()=>{
 const f=fixture();try{
  const g=f.grant();let fired=false;
  f.before(()=>{if(!fired){fired=true;f.sql.prepare('INSERT INTO iap_play_void_events_v1 VALUES(?,?)').run('playtoken:'+h('first'),'u1:'+h(uid));}});
  await assert.rejects(f.wallet.creditVerifiedPurchase(uid,g));assert.equal(f.events().length,0);
  f.sql.exec('DELETE FROM iap_play_void_events_v1');f.before(()=>{});
  assert.equal((await f.wallet.creditVerifiedPurchase(uid,g)).balance,100);
 }finally{f.close();}
});
test('voided/held credits fail closed and a reversal never resets first eligibility',async()=>{
 const f=fixture();try{
  const g=f.grant();await f.wallet.creditVerifiedPurchase(uid,g);
  f.sql.prepare('INSERT INTO iap_play_void_events_v1 VALUES(?,?)').run('playtoken:'+h('first'),'u1:'+h(uid));
  f.sql.prepare('INSERT INTO iap_refund_account_holds_v1 VALUES(?,?)').run('u1:'+h(uid),'held');
  await assert.rejects(f.wallet.creditVerifiedPurchase(uid,f.grant('blocked')));
  // Separate audited refund resolution owns release; this only verifies eligibility persistence afterwards.
  f.sql.exec("UPDATE iap_refund_account_holds_v1 SET status='released'");
  assert.equal((await f.wallet.creditVerifiedPurchase(uid,f.grant('after-review'))).balance,150);
  await assert.rejects(f.wallet.creditVerifiedPurchase(uid,g));
  await assert.rejects(f.wallet.creditVerifiedPurchase('other',f.grant('after-review')));
 }finally{f.close();}
});
test('actual purchase authority validates new Play alias and immutable ledger replay',async()=>{
 const records=new Map();let consumes=0;
 const ledger={async runTransaction(key,fn){const d=await fn(records.get(key)??null);if(Object.hasOwn(d,'nextRecord'))records.set(key,d.nextRecord);return d.result;}};
 const p=firstTopupProduct('jade_pouch_100'),token='new-play-topup-purchase-token';
 const play={async getProductPurchaseV2(){return{purchaseStateContext:{purchaseState:'PURCHASED'},obfuscatedExternalAccountId:accountBindingForUid(uid),productLineItem:[{productId:p.playProductId,productOfferDetails:{quantity:1,refundableQuantity:1,consumptionState:'CONSUMPTION_STATE_YET_TO_BE_CONSUMED'}}]};},async consumeProduct(){consumes++;}};
 const request={auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}},app:{appId:'verified-app'},data:{purchase_token:token}};
 const first=await authorizePurchase({request,playGateway:play,ledger});
 assert.equal(first.celestial_jade,50);assert.equal(first.internal_product_id,'jade_pouch_100');
 assert.deepEqual(await authorizePurchase({request,playGateway:play,ledger}),first);assert.equal(consumes,1);
});

test('verified recovery of a new SKU repairs one doubled credit without repeating it',async()=>{
 const f=fixture();try{
  const g=f.grant('repair'),p=firstTopupProduct('jade_pouch_100'),fingerprint=h('repair');
  const record={contractVersion:1,tokenKey:'playtoken:'+fingerprint,grantId:g.grant_id,ownerUid:uid,
    ownerBinding:h(uid),internalProductId:p.internalProductId,playProductId:p.playProductId,
    celestialJade:p.celestialJade,state:'grant_ready'};
  f.sql.prepare('UPDATE iap_purchase_ledger_v1 SET record_json=? WHERE token_key=?').run(JSON.stringify(record),record.tokenKey);
  const args={db:f.db,verifiedIdentity:{auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}},app:{appId:'verified-app'}},initialize:async()=>{}};
  assert.equal((await repairVerifiedPurchases(args)).new_wallet_credits,1);
  assert.equal((await repairVerifiedPurchases(args)).new_wallet_credits,0);
  assert.equal((await f.wallet.getSnapshot(uid)).balance,100);
  assert.equal((await f.wallet.creditVerifiedPurchase(uid,f.grant('after-repair'))).balance,150);
 }finally{f.close();}
});
