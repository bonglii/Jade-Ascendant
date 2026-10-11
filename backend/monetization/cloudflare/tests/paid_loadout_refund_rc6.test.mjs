import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { createPaidLoadoutHandlerRC6 } from '../src/paid_loadout_route_rc6.mjs';
const hash = uid => 'u1:' + createHash('sha256').update(uid).digest('hex');
const uid='rc6owner';
const requestId='1270edbf-243a-499b-8306-1c908f641ea4';
const origin='https://example.invalid/v1/wallet/paid-loadout';
const identity=()=>({auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}},app:{appId:'trusted-app-id-123'}});
const state=()=>({state_contract_version:1,cleared_stage_keys:['1-5'],pity:{rare_plus:0,epic_plus:0,legendary:0},wish_item_id:'',wish_fate_guaranteed:false,lifetime_pulls:0,inventory:{mistveil_jian:1},refinement_shards:0});
const slots=()=>({armament:'mistveil_jian',robe:'',bracer:'',boots:'',pendant:''});
const command=()=>new Request(origin,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({request_id:requestId,expected_loadout_revision:0,expected_entitlement_revision:0,paid_slots:slots()})});
class D1 {
 constructor(){this.db=new DatabaseSync(':memory:');this.db.exec('PRAGMA foreign_keys=ON');
  for(const f of ['0001_iap_ledger.sql','0002_wallet_ledger.sql','0003_summon_outcomes.sql','0004_summon_canonical.sql','0005_paid_loadout.sql','0008_refund_account_holds.sql'])
   this.db.exec(readFileSync(new URL('../migrations/'+f,import.meta.url),'utf8'));
  this.db.prepare('INSERT INTO iap_wallet_accounts_v1 (owner_key,balance,revision) VALUES (?,0,0)').run(hash(uid));
  this.db.prepare("INSERT INTO iap_summon_canonical_v1(owner_key,revision,status,state_json) VALUES (?,0,'verified',?)").run(hash(uid),JSON.stringify(state()));
  this.queue=Promise.resolve();this.beforeBatch=null;
 }
 withSession(mode){assert.equal(mode,'first-primary');return this;}
 prepare(sql){return {bind:(...args)=>({first:async()=>this.db.prepare(sql).get(...args)??null,run:async()=>this.db.prepare(sql).run(...args)})};}
 batch(steps){const tx=async()=>{
  if(this.beforeBatch){const fn=this.beforeBatch;this.beforeBatch=null;fn();}
  this.db.exec('BEGIN IMMEDIATE');try{const result=[];for(const step of steps)result.push(await step.run());this.db.exec('COMMIT');return result;}
  catch(e){this.db.exec('ROLLBACK');throw e;}
 };const promise=this.queue.then(tx,tx);this.queue=promise.catch(()=>{});return promise;}
 hold(status='held'){this.db.prepare('INSERT OR REPLACE INTO iap_refund_account_holds_v1(owner_key,status,reason) VALUES (?,?,?)').run(hash(uid),status,'play_voided_purchase');}
 count(){return this.db.prepare('SELECT COUNT(*) n FROM iap_paid_loadout_ops_v1').get().n;}
 close(){this.db.close();}
}
const env=(DB,more={})=>({DB,JADE_IAP_BACKEND_ENABLED:'true',JADE_PAID_LOADOUT_READ_ENABLED:'true',JADE_PAID_LOADOUT_WRITE_ENABLED:'true',JADE_REFUND_RECONCILIATION_READY:'true',...more});
const handler=()=>createPaidLoadoutHandlerRC6({verifyIdentity:async()=>identity()});
test('refund ingestion OFF blocks both loadout reads and writes before Auth/SQL',async()=>{
 let auth=0;const h=createPaidLoadoutHandlerRC6({verifyIdentity:()=>{auth++;throw Error('must_not_auth');}});
 for(const req of [new Request(origin),command()]){
  const res=await h(req,env({}, {JADE_REFUND_RECONCILIATION_READY:'false'}));
  assert.equal(res.status,503);assert.deepEqual(await res.json(),{error:'refund_reconciliation_not_ready'});
 }
 assert.equal(auth,0);
});
test('held refund denies both read and write; no paid loadout mutations',async()=>{
 const db=new D1();db.hold();const h=handler();
 for(const req of [new Request(origin),command()]){
  const res=await h(req,env(db));assert.equal(res.status,423);assert.equal((await res.json()).error,'paid_account_on_hold');
 }
 assert.equal(db.count(),0);db.close();
});
test('released account may read and write verified owned item without local grant',async()=>{
 const db=new D1();db.hold('released');const h=handler();
 const first=await h(command(),env(db));assert.equal(first.status,200);
 const result=await first.json();assert.equal(result.paid_slots.armament,'mistveil_jian');
 assert.equal(db.count(),1);
 assert.equal((await h(new Request(origin),env(db))).status,200);
 db.close();
});
test('refund hold race prevents write even after optimistic precheck',async()=>{
 const db=new D1();const h=handler();db.beforeBatch=()=>db.hold('held');
 const res=await h(command(),env(db));assert.equal(res.status,423);
 assert.equal(db.count(),0);assert.equal(db.db.prepare('SELECT COUNT(*) n FROM iap_paid_loadouts_v1').get().n,0);
 db.close();
});
test('no hold table fails closed, cannot return server ownership',async()=>{
 const db=new D1();db.db.exec('DROP TABLE iap_refund_account_holds_v1');
 assert.equal((await handler()(new Request(origin),env(db))).status,503);db.close();
});
