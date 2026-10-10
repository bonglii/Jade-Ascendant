import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { createWorkerHandler } from '../src/index.mjs';
import { createPaidSummonWriteHandlerRC } from '../src/paid_summon_write_route_rc.mjs';
import { createPaidEntitlementsReadHandlerRC, readPaidEntitlementsRC } from '../src/paid_entitlements_read_route_rc.mjs';
import { createCanonicalSummonStage } from '../src/summon_canonical_stage.mjs';
import { createD1Wallet } from '../src/d1_wallet.mjs';
import { createTestOnlyTrustedResolver } from '../src/summon_trusted_resolver_stage.mjs';

const UID = 'firebaseuid01';
const SECOND = 'firebaseuid02';
const REQUEST = '9cc242ed-56cc-46bc-8f8d-fb2b83388d7a';
const owner = uid => 'u1:' + createHash('sha256').update(uid).digest('hex');
const ident = uid => ({auth: {uid, token: {firebase: {sign_in_provider: 'google.com'}}}, app: {appId:'app-test-verified'}});
const URL_BASE = 'https://candidate.example/v1/wallet/';
const summon = (payload = {request_id:REQUEST, pull_count:1}, opts={}) => new Request(URL_BASE+'summon', {
  method: 'POST', headers: {'content-type':'application/json'}, body: JSON.stringify(payload), ...opts,
});
const entitlementReq = () => new Request(URL_BASE+'entitlements');
const env = extra => ({JADE_IAP_BACKEND_ENABLED:'true',JADE_PAID_SUMMON_WRITE_ENABLED:'true',JADE_PAID_ENTITLEMENTS_READ_ENABLED:'true',DB:{prepare:()=>{},batch:()=>{}},...extra});
const fakeReceipt = () => ({spend_id:'spendv1:'+'a'.repeat(64),outcome:{outcome_contract_version:1,pull_count:1,results:[{item_id:'test_sword'}],next_pity:{rare_plus:0,epic_plus:0,legendary:0}},wallet:{wallet_contract_version:1,balance:1200,revision:2},applied:true});
function sampleCanonical(){return {state_contract_version:1,cleared_stage_keys:['1-5'],pity:{rare_plus:0,epic_plus:0,legendary:0},wish_item_id:'',wish_fate_guaranteed:false,lifetime_pulls:0,inventory:{},refinement_shards:0};}
class SqliteD1 {
  constructor(){
    this.sqlite = new DatabaseSync(':memory:');
    this.sqlite.exec('PRAGMA foreign_keys=ON');
    for(const filename of ['0001_iap_ledger.sql','0002_wallet_ledger.sql','0003_summon_outcomes.sql','0004_summon_canonical.sql']){
      this.sqlite.exec(readFileSync(new URL('../migrations/'+filename,import.meta.url),'utf8'));
    }
    this.queue = Promise.resolve();
  }
  withSession(mode){assert.equal(mode,'first-primary'); return this;}
  prepare(sql){return {bind:(...args)=>({first:async()=>this.sqlite.prepare(sql).get(...args)??null,run:async()=>this.sqlite.prepare(sql).run(...args)})};}
  batch(steps){
    const execute=async()=>{
      this.sqlite.exec('BEGIN IMMEDIATE');
      try { const result=[];for(const s of steps) result.push(await s.run());this.sqlite.exec('COMMIT');return result; }
      catch(err){this.sqlite.exec('ROLLBACK');throw err;}
    };
    const pending=this.queue.then(execute,execute);this.queue=pending.catch(()=>{});return pending;
  }
  seed(uid,state=sampleCanonical(),status='verified'){
    this.sqlite.prepare('INSERT INTO iap_wallet_accounts_v1 (owner_key,balance,revision) VALUES (?,0,0)').run(owner(uid));
    this.sqlite.prepare('INSERT INTO iap_summon_canonical_v1 (owner_key,revision,status,state_json) VALUES (?,0,?,?)').run(owner(uid),status,JSON.stringify(state));
  }
  count(table){if(!['iap_wallet_events_v1','iap_summon_outcomes_v1'].includes(table)) throw Error('bad table');return this.sqlite.prepare('SELECT COUNT(*) AS n FROM '+table).get().n;}
  close(){this.sqlite.close();}
}
const verifiedFn = async()=>ident(UID);

test('FastTrack Worker both new endpoints are locked by default without DB or auth',async()=>{
  let verified=0;
  const handler=createWorkerHandler({verifyIdentity:async()=>{verified++;throw Error('unexpected_auth');}});
  for(const request of [summon(),entitlementReq()]){
    const response=await handler(request,{});
    assert.equal(response.status,503);
  }
  assert.equal(verified,0);
});
test('Summon still locked if global IAP gate off even with write flag on',async()=>{
  const handler=createPaidSummonWriteHandlerRC({verifyIdentity:()=>{throw Error('auth_called');}});
  const res=await handler(summon(),env({JADE_IAP_BACKEND_ENABLED:'false'}));
  assert.equal(res.status,503);assert.deepEqual(await res.json(),{error:'paid_summon_disabled'});
});
test('Summon still locked if write gate off with IAP flag on',async()=>{
  const handler=createPaidSummonWriteHandlerRC({verifyIdentity:()=>{throw Error('auth_called');}});
  assert.equal((await handler(summon(),env({JADE_PAID_SUMMON_WRITE_ENABLED:'false'}))).status,503);
});
test('Read-only entitlement gate cannot be opened with global purchase flag alone',async()=>{
  const handler=createPaidEntitlementsReadHandlerRC({verifyIdentity:()=>{throw Error('auth_called');}});
  assert.equal((await handler(entitlementReq(),env({JADE_PAID_ENTITLEMENTS_READ_ENABLED:'false'}))).status,503);
});
test('Summon rejects client-supplied local balance, RNG, pity, item and extra fields',async()=>{
  let called=0;
  const handler=createPaidSummonWriteHandlerRC({verifyIdentity:verifiedFn,makeCoordinator:()=>({execute:()=>{called++;return fakeReceipt();}})});
  const malformed=[
    {request_id:REQUEST,pull_count:1,balance:99999},
    {request_id:REQUEST,pull_count:1,local_pity:0},
    {request_id:REQUEST,pull_count:1,item_id:'legendary_sword'},
    {request_id:REQUEST,pull_count:1,rng:42},
    {request_id:REQUEST,pull_count:11},
    {request_id:REQUEST,pull_count:'1'},
    {request_id:'invalid',pull_count:1},
    [],
    null,
  ];
  for(const data of malformed) assert.equal((await handler(summon(data),env())).status,400);
  assert.equal(called,0);
});
test('Summon rejects oversized payload before coordinator',async()=>{
  const handler=createPaidSummonWriteHandlerRC({verifyIdentity:verifiedFn,makeCoordinator:()=>({execute:()=>{throw Error('called');}})});
  assert.equal((await handler(summon({request_id:REQUEST,pull_count:1,padding:'x'.repeat(800)}),env())).status,400);
});
test('Summon identity comes from verified auth, not query or body',async()=>{
  let received;
  const handler=createPaidSummonWriteHandlerRC({verifyIdentity:async()=>ident(SECOND),makeCoordinator:()=>({execute:async args=>{received=args;return fakeReceipt();}})});
  const res=await handler(summon(),env());assert.equal(res.status,200);
  assert.equal(received.uid,SECOND);assert.equal(received.pullCount,1);assert.equal(received.requestId,REQUEST);
  const body=await res.json();assert.equal(body.state,'committed');assert.equal(body.wallet.balance,1200);
  assert.ok(!Object.hasOwn(body,'grant_id'));assert.ok(!Object.hasOwn(body,'celestial_jade'));
});
test('Summon missing signed identity is rejected and never calls coordinator',async()=>{
  const handler=createPaidSummonWriteHandlerRC({verifyIdentity:async()=>({auth:{uid:UID}}),makeCoordinator:()=>({execute:()=>{throw Error('unexpected');}})});
  assert.equal((await handler(summon(),env())).status,401);
});
test('Entitlement read rejects unverified identity before database read',async()=>{
  let queries=0;const db={prepare:()=>{queries++;throw Error('unexpected');}};
  await assert.rejects(readPaidEntitlementsRC({db,verifiedIdentity:{auth:{uid:SECOND}}}));
  assert.equal(queries,0);
});
test('Entitlement read returns NOT PROVISIONED, never creates a canonical state from local save',async()=>{
  const db=new SqliteD1();
  const handler=createPaidEntitlementsReadHandlerRC({verifyIdentity:verifiedFn});
  const r=await handler(entitlementReq(),env({DB:db}));
  assert.equal(r.status,409);assert.deepEqual(await r.json(),{error:'paid_progression_not_ready'});
  assert.equal(db.count('iap_wallet_events_v1'),0);db.close();
});
test('Entitlement read uses primary and rejects another UID inventory',async()=>{
  const db=new SqliteD1();const state=sampleCanonical();state.inventory={};db.seed(SECOND,state);
  const r=await readPaidEntitlementsRC({db,verifiedIdentity:ident(SECOND)});
  assert.equal(r.item_ids.length,0);
  await assert.rejects(readPaidEntitlementsRC({db,verifiedIdentity:ident(UID)}),{code:'not_provisioned'});
  db.close();
});
test('Entitlement read refuses unknown/tampered server inventory and no local grants',async()=>{
  const db=new SqliteD1();db.seed(UID);
  const bad=sampleCanonical();bad.inventory={'not_an_actual_catalog_item':1};
  db.sqlite.prepare('UPDATE iap_summon_canonical_v1 SET state_json=? WHERE owner_key=?').run(JSON.stringify(bad),owner(UID));
  await assert.rejects(readPaidEntitlementsRC({db,verifiedIdentity:ident(UID)}),{code:'invalid_server_state'});
  db.close();
});
test('Entitlement endpoint never accepts query/body and supports method guard',async()=>{
  const handler=createPaidEntitlementsReadHandlerRC({verifyIdentity:()=>{throw Error('called');}});
  assert.equal((await handler(new Request(URL_BASE+'entitlements?uid=x'),env())).status,400);
  assert.equal((await handler(new Request(URL_BASE+'entitlements',{method:'POST',body:'{}'}),env())).status,405);
});
test('Summon endpoint requires POST and disallows query-supplied UID',async()=>{
  const handler=createPaidSummonWriteHandlerRC({verifyIdentity:verifiedFn});
  assert.equal((await handler(new Request(URL_BASE+'summon'),env())).status,405);
  assert.equal((await handler(new Request(URL_BASE+'summon?uid=x',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({request_id:REQUEST,pull_count:1})}),env())).status,400);
});
test('Production handler routes both new endpoints while default disabled',async()=>{
  const handler=createWorkerHandler();
  for(const [request,code] of [[summon(),'paid_summon_disabled'],[entitlementReq(),'paid_entitlements_disabled']]){
    const reply=await handler(request,{DB:{}});
    assert.equal(reply.status,503);assert.equal((await reply.json()).error,code);
  }
});
test('Canonical DB: authenticated paid summon atomically debits, persists item and replays exactly once',async()=>{
  const db=new SqliteD1();db.seed(UID);
  // Authorized Play purchase is represented only by an internally verified grant.
  const wallet=createD1Wallet(db);
  await wallet.creditVerifiedPurchase(UID,{
    purchase_contract_version:1,state:'grant_ready',grant_id:'iapv1:'+'b'.repeat(64),
    internal_product_id:'jade_casket_1200',celestial_jade:1200,
  });
  let rngCalls=0;
  const rand=(low,high)=>{rngCalls++;return low;};
  const resolver=createTestOnlyTrustedResolver(rand);
  const handler=createPaidSummonWriteHandlerRC({
    verifyIdentity:verifiedFn,
    makeCoordinator:createCanonicalSummonStage,
    resolveTrustedTransition:resolver,
  });
  const first=await handler(summon(),env({DB:db}));assert.equal(first.status,200);
  const firstBody=await first.json();assert.equal(firstBody.wallet.balance,1100);
  assert.equal(db.count('iap_summon_outcomes_v1'),1);
  const rngAfterFirst=rngCalls;
  const again=await handler(summon(),env({DB:db}));assert.equal(again.status,200);
  const replayBody=await again.json();assert.deepEqual(replayBody,firstBody);
  assert.equal(rngCalls,rngAfterFirst);
  assert.equal(db.count('iap_summon_outcomes_v1'),1);
  assert.equal(db.count('iap_wallet_events_v1'),2); // One credit and one debit.
  const entitlements=await readPaidEntitlementsRC({db,verifiedIdentity:ident(UID)});
  assert.equal(entitlements.item_ids.length,1);
  assert.equal(entitlements.revision,1);
  assert.equal(entitlements.authority,'server_read_only');
  assert.ok(!Object.hasOwn(entitlements,'local_inventory_grant'));
  db.close();
});
test('Paid summon never provisions missing verified canonical state even with credited wallet',async()=>{
  const db=new SqliteD1();
  await createD1Wallet(db).creditVerifiedPurchase(UID,{
    purchase_contract_version:1,state:'grant_ready',grant_id:'iapv1:'+'c'.repeat(64),
    internal_product_id:'jade_casket_1200',celestial_jade:1200,
  });
  const handler=createPaidSummonWriteHandlerRC({verifyIdentity:verifiedFn});
  const reply=await handler(summon(),env({DB:db}));
  assert.equal(reply.status,409);assert.equal((await reply.json()).error,'paid_progression_not_ready');
  assert.equal(db.count('iap_summon_outcomes_v1'),0);
  assert.equal((await createD1Wallet(db).getSnapshot(UID)).balance,1200);
  db.close();
});
