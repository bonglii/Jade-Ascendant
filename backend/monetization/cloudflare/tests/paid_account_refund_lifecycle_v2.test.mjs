/** Lifecycle integration against real SQLite, wallet/gameplay and refund reconciliation.
 * Fake identity/Play event input only: no live Google verification or purchase claimed. */
import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash,randomUUID} from 'node:crypto';
import {fixture,command,UID,owner,NOW} from './fixtures/paid_gameplay_v2.mjs';
import {createPaidGameplayV2,createPaidGameplayHandlerV2} from '../src/paid_gameplay_v2.mjs';
import {createProductionWorkerV2,PRODUCTION_GATES_V2} from '../src/worker_paid_production_v2.mjs';
import {createD1Wallet} from '../src/d1_wallet.mjs';
import {recordPlayVoidRC7} from '../src/play_voided_reconciliation_rc7.mjs';
import {repairVerifiedPurchases} from '../src/verified_purchase_repair.mjs';
const B='paid-independent-google-b';
const sha=s=>createHash('sha256').update(s).digest('hex');
const identity=uid=>({auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}},app:{appId:'fixture'}});

test('production HTTP composition uses verified identity for each account, never supplied owner fields',async()=>{
 const f=fixture();try{
  f.seed(B,550);await f.init();await f.init(B);
  const verifyIdentity=headers=>{
   const id=headers.get('Authorization');
   if(!['Bearer fixture-a','Bearer fixture-b'].includes(id))throw Error('unverified');
   return identity(id==='Bearer fixture-a'?UID:B);
  };
  const handler=createPaidGameplayHandlerV2({verifyIdentity,createService:db=>createPaidGameplayV2(db,{now:()=>NOW})});
  const worker=createProductionWorkerV2({verifyIdentity,base:{fetch:handler}});
  const env={...Object.fromEntries(PRODUCTION_GATES_V2.map(k=>[k,'true'])),DB:f.db};
  const url='https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/v1/wallet/gameplay-v2';
  for(const [account,balance] of [['a',2400],['b',550]]){
   const response=await worker.fetch(new Request(url,{headers:{Authorization:'Bearer fixture-'+account}}),env);
   assert.equal(response.status,200);const data=await response.json();assert.equal(data.snapshot.wallet.balance,balance);
   assert.equal(data.snapshot.account_binding,sha(account==='a'?UID:B));
   assert.match(response.headers.get('cache-control'),/no-store/);
  }
  assert.equal((await worker.fetch(new Request(url),env)).status,401);
  assert.equal((await worker.fetch(new Request(url+'?uid='+UID,{headers:{Authorization:'Bearer fixture-b'}}),env)).status,400);
  const forged={...command('summon',0,{pull_count:1}),owner_uid:UID};
  assert.equal((await worker.fetch(new Request(url,{method:'POST',headers:{Authorization:'Bearer fixture-b','Content-Type':'application/json'},body:JSON.stringify(forged)}),env)).status,400);
  assert.equal((await f.service.read(B)).wallet.balance,550);assert.equal((await f.service.read(UID)).wallet.balance,2400);
 }finally{f.close();}
});

test('credited order -> summon -> Play void holds only its owner and blocks replay/repair',async()=>{
 const f=fixture({funds:0});try{
  // Real clock needed by the wallet refund freshness guard.
  const now=Date.now();const service=createPaidGameplayV2(f.db,{now:()=>now,rng:lo=>lo});f.sql.prepare('UPDATE iap_play_void_cursor_v1 SET watermark_ms=?').run(now);
  f.seed(B,550);await service.execute(UID,command('initialize'));await service.execute(B,command('initialize'));
  const token='fixture-play-token-after-credit-14000',fingerprint=sha(token);
  const grant={purchase_contract_version:1,state:'grant_ready',grant_id:'iapv1:'+fingerprint,
   internal_product_id:'jade_ascendant_14000',celestial_jade:14000};
  const record={contractVersion:1,tokenKey:'playtoken:'+fingerprint,grantId:grant.grant_id,
   ownerUid:UID,ownerBinding:sha(UID),internalProductId:grant.internal_product_id,
   playProductId:'jade_pouch_14000',celestialJade:14000,state:'grant_ready'};
  f.sql.prepare('INSERT INTO iap_purchase_ledger_v1(token_key,record_json) VALUES(?,?)').run(record.tokenKey,JSON.stringify(record));
  const wallet=createD1Wallet(f.db);
  assert.equal((await wallet.creditVerifiedPurchase(UID,grant)).balance,14000);
  assert.equal((await wallet.creditVerifiedPurchase(UID,grant)).applied,false);
  await assert.rejects(wallet.creditVerifiedPurchase(B,grant));
  const pull=command('summon',0,{pull_count:10});
  const result=await service.execute(UID,pull);assert.equal(result.snapshot.wallet.balance,13100);
  const bBefore=await service.read(B);assert.equal(bBefore.wallet.balance,550);assert.deepEqual(bBefore.inventory,{});
  // Reusing another account's UUID executes B's own command; it never returns A's receipt.
  const bPull=await service.execute(B,{...pull,pull_count:1});
  assert.equal(bPull.snapshot.wallet.balance,450);assert.equal(bPull.operation.outcome.results.length,1);
  const run=command('run_start',1,{run_id:randomUUID(),weapon_level:0});await service.execute(UID,run);
  assert.equal((await service.execute(B,command('run_resume',1,{run_id:run.run_id}))).operation.kind,'not_committed');
  const event={purchaseToken:token,voidedTimeMillis:String(now-1000),voidedReason:1,voidedSource:0};
  assert.equal((await recordPlayVoidRC7({db:f.db,item:event,nowMs:now})).matched,true);
  await recordPlayVoidRC7({db:f.db,item:event,nowMs:now});
  assert.equal(f.sql.prepare('SELECT COUNT(*) n FROM iap_play_void_events_v1').get().n,1);
  assert.equal(f.sql.prepare('SELECT owner_key FROM iap_refund_account_holds_v1').get().owner_key,owner(UID));
  await assert.rejects(service.read(UID),{code:'paid_account_on_hold'});
  for(const c of [pull,run,command('summon',2,{pull_count:1}),command('run_resume',2,{run_id:run.run_id})])
   await assert.rejects(service.execute(UID,c),{code:'paid_account_on_hold'});
  await assert.rejects(wallet.creditVerifiedPurchase(UID,grant),{code:'refund_or_hold'});
  await assert.rejects(repairVerifiedPurchases({db:f.db,verifiedIdentity:identity(UID)}));
  const bAfter=await service.read(B);assert.equal(bAfter.wallet.balance,450);
  assert.equal((await service.execute(B,command('summon',1,{pull_count:1}))).snapshot.wallet.balance,350);
  // Policy is hold/review, not fabricated negative balance or automatic gear destruction.
  assert.equal(f.sql.prepare('SELECT balance FROM iap_wallet_accounts_v1 WHERE owner_key=?').get(owner(UID)).balance,13100);
  assert.equal(f.sql.prepare("SELECT COUNT(*) n FROM iap_wallet_events_v1 WHERE event_key=?").get(grant.grant_id).n,1);
 }finally{f.close();}
});
