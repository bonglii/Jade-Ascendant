/** Emulator-only direct ledger fault injection; never run against production Firestore. */
import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {createHash,generateKeyPairSync,randomBytes,sign} from 'node:crypto';
import {acceptVerifiedSsvReceipt,m7e4cStorageContract as contract} from '../../m7e4c_receipt_ledger.mjs';
import {normalizeTrustedGoogleKeys} from '../../m7e4b_ssv_verifier.mjs';
const host=process.env.FIRESTORE_EMULATOR_HOST??'';
if(!/^(localhost|127\.0\.0\.1|\[::1\]):\d{2,5}$/.test(host) || process.env.GCLOUD_PROJECT!=='demo-jade-ssv') {
  throw Error('M7E4F: ONLY demo-jade-ssv localhost Firestore emulator allowed');
}
const require=createRequire(import.meta.url);
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const app=initializeApp({projectId:'demo-jade-ssv'},`m7e4f-${randomBytes(8).toString('hex')}`);
const db=getFirestore(app);
const {privateKey,publicKey}=generateKeyPairSync('ec',{namedCurve:'prime256v1'});
const keys=normalizeTrustedGoogleKeys({keys:[{keyId:23574,pem:publicKey.export({type:'spki',format:'pem'})}]});
const now=Date.now();
const digest=(...v)=>createHash('sha256').update(JSON.stringify(v)).digest('hex');
const owned=[];
const adUnit='1234567890';
function createCase({placement='victory_encore',userId=null,runId=null,txId=null}={}){
  const uid=userId??`qa_${randomBytes(12).toString('hex')}`;
  const nonce=randomBytes(24).toString('base64url');
  const suffix=randomBytes(16).toString('hex');
  const transactionId=txId??suffix;
  const intent={intentId:`intent_${suffix}`,userId:uid,nonce,placement,adUnit,
    rewardAmount:1,rewardItem:'test_reward',issuedAtMs:now-1000,expiresAtMs:now+120000,status:'PENDING',
    ...(runId?{runId}:{})};
  const params={ad_network:'123',ad_unit:adUnit,reward_amount:'1',reward_item:'test_reward',
    timestamp:String(now),transaction_id:transactionId,custom_data:nonce,user_id:'untrusted_client_value'};
  const bytes=Object.entries(params).map(([k,v])=>`${k}=${encodeURIComponent(v)}`).join('&');
  const query=`?${bytes}&signature=${sign('sha256',Buffer.from(bytes),privateKey).toString('base64url')}&key_id=23574`;
  return {intent,query,transactionId};
}
async function stage(c){
  const ref=db.collection(contract.intentCollection).doc(contract.intentDocumentIdForNonce(c.intent.nonce));
  await ref.create(c.intent);owned.push(ref);
  return ref;
}
async function accept(c,handler=db){return acceptVerifiedSsvReceipt({rawQuery:c.query,trustedGoogleKeys:keys,db:handler,nowMs:now});}
async function refFor(collection,id){return db.collection(collection).doc(id);}
async function cleanup(){
  // Emulator-only documents are namespaced by randomized IDs. Do not delete collections.
  await Promise.allSettled(owned.map(ref=>ref.delete()));
  await deleteApp(app);
}
test.after(cleanup);
test('bad signed callback cannot consume an intent or issue receipt',async()=>{
  const c=createCase();const intentRef=await stage(c);
  const tampered=c.query.replace('reward_amount=1','reward_amount=2');
  await assert.rejects(accept({...c,query:tampered}),/SIGNATURE_INVALID/);
  assert.equal((await intentRef.get()).data().status,'PENDING');
  assert.equal((await (await refFor(contract.receiptCollection,c.transactionId)).get()).exists,false);
});
test('failed transaction before commit never writes receipt, credit or consumes intent',async()=>{
  const c=createCase();const intentRef=await stage(c);
  const failOnce={collection:(...a)=>db.collection(...a),runTransaction:async()=>{throw Error('QA_FORCED_TRANSACTION_FAILURE');}};
  await assert.rejects(accept(c,failOnce),/QA_FORCED_TRANSACTION_FAILURE/);
  assert.equal((await intentRef.get()).data().status,'PENDING');
  assert.equal((await (await refFor(contract.receiptCollection,c.transactionId)).get()).exists,false);
  const successful=await accept(c);assert.equal(successful.newlyRecorded,true);
  assert.equal((await intentRef.get()).data().status,'CONSUMED');
  owned.push(db.collection(contract.receiptCollection).doc(c.transactionId));
  owned.push(db.collection(contract.creditCollection).doc(digest('intent',c.intent.intentId)));
  owned.push(db.collection(contract.dailyCollection).doc(digest('day',c.intent.userId,String(Math.floor(now/86400000)))));
});
test('parallel signed callbacks and retry after new handler produce one durable credit',async()=>{
  const c=createCase();await stage(c);
  const replies=await Promise.all(Array.from({length:3},()=>accept(c)));
  assert.equal(replies.filter(x=>x.newlyRecorded===true).length,1);
  assert.equal(replies.filter(x=>x.status==='ALREADY_RECORDED').length,2);
  const retry=await accept(c);
  assert.equal(retry.status,'ALREADY_RECORDED');
  const ref=await refFor(contract.creditCollection,digest('intent',c.intent.intentId));
  assert.equal((await ref.get()).data().state,'PENDING_DELIVERY');
  owned.push(ref,db.collection(contract.receiptCollection).doc(c.transactionId),db.collection(contract.dailyCollection).doc(digest('day',c.intent.userId,String(Math.floor(now/86400000)))));
});
test('same transaction ID bound to second signed intent is rejected and cannot consume',async()=>{
  const userId=`qa_${randomBytes(12).toString('hex')}`;
  const a=createCase({userId}), b=createCase({userId,txId:a.transactionId});
  await stage(a);const bRef=await stage(b);
  assert.equal((await accept(a)).newlyRecorded,true);
  await assert.rejects(accept(b),/TRANSACTION_ID_REPLAY_CONFLICT/);
  assert.equal((await bRef.get()).data().status,'PENDING');
  owned.push(db.collection(contract.creditCollection).doc(digest('intent',a.intent.intentId)),db.collection(contract.receiptCollection).doc(a.transactionId),db.collection(contract.dailyCollection).doc(digest('day',userId,String(Math.floor(now/86400000)))));
});
test('five non-revive receipts for same account cap the sixth (real transactions)',async()=>{
  const userId=`qa_${randomBytes(12).toString('hex')}`;
  const day=String(Math.floor(now/86400000));
  const placements=['daily_completion_cache','refinement_supply','victory_encore','qi_focus','pavilion_seal','offline_cultivation_double'];
  for(let n=0;n<placements.length;n++){
    const c=createCase({userId,placement:placements[n]});const ref=await stage(c);
    if(n===5){await assert.rejects(accept(c),/GLOBAL_DAILY_CAP_REACHED/);assert.equal((await ref.get()).data().status,'PENDING');}
    else {
      assert.equal((await accept(c)).newlyRecorded,true);
      owned.push(db.collection(contract.receiptCollection).doc(c.transactionId),db.collection(contract.creditCollection).doc(digest('intent',c.intent.intentId)));
    }
  }
  const usage=db.collection(contract.dailyCollection).doc(digest('day',userId,day));
  assert.equal((await usage.get()).data().total,5);owned.push(usage);
});
test('Dao reroll second attempt same run rejected with server run guard',async()=>{
  const userId=`qa_${randomBytes(12).toString('hex')}`, runId=`run_${randomBytes(10).toString('hex')}`;
  const a=createCase({userId,runId,placement:'dao_choice_reroll'}),b=createCase({userId,runId,placement:'dao_choice_reroll'});
  await stage(a);const bRef=await stage(b);
  await accept(a);await assert.rejects(accept(b),/RUN_PLACEMENT_ALREADY_USED/);
  assert.equal((await bRef.get()).data().status,'PENDING');
  owned.push(db.collection(contract.receiptCollection).doc(a.transactionId),db.collection(contract.creditCollection).doc(digest('intent',a.intent.intentId)),db.collection(contract.dailyCollection).doc(digest('day',userId,String(Math.floor(now/86400000)))),db.collection(contract.runCollection).doc(digest('run',userId,runId,'dao_choice_reroll')));
});
