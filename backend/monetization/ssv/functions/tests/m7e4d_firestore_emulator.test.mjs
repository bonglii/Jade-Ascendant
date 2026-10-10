/**
 * REQUIRED optional integration test: actual Firestore emulator transactions.
 * Intentionally FAILS instead of skipping if emulator/dependencies are missing.
 * Run with firebase emulators:exec --only firestore --project demo-jade-ssv.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { generateKeyPairSync, sign, randomBytes } from 'node:crypto';
import { normalizeTrustedGoogleKeys } from '../../m7e4b_ssv_verifier.mjs';
import { m7e4cStorageContract } from '../../m7e4c_receipt_ledger.mjs';
import { createSsvHttpHandler } from '../../m7e4d_http_boundary.mjs';

if (!process.env.FIRESTORE_EMULATOR_HOST ||
    !process.env.GCLOUD_PROJECT?.startsWith('demo-') ||
    !/^(localhost|127\.0\.0\.1|\[::1\]):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST)) {
  throw Error('M7E4D: FIRESTORE_EMULATOR_REQUIRED; never connect to production Firestore');
}
const require=createRequire(import.meta.url);
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const app=initializeApp({projectId:process.env.GCLOUD_PROJECT},'m7e4d-integration');
const db=getFirestore(app);
const now=Date.now();
const {privateKey,publicKey}=generateKeyPairSync('ec',{namedCurve:'prime256v1'});
const keys=normalizeTrustedGoogleKeys({keys:[{keyId:24680,pem:publicKey.export({type:'spki',format:'pem'})}]});
const nonce=randomBytes(24).toString('base64url');
const id=randomBytes(16).toString('hex');
const i={intentId:`intent_${id}`,userId:`emulator_account_${id}`,nonce,
  placement:'dao_choice_reroll',runId:`run_${id}`,
  adUnit:'1234567890',rewardAmount:1,rewardItem:'rewarded_grant',
  issuedAtMs:now-1000,expiresAtMs:now+60000,status:'PENDING'};
const params={ad_network:'123',ad_unit:i.adUnit,reward_amount:'1',reward_item:i.rewardItem,
  timestamp:String(now),transaction_id:id,custom_data:nonce,user_id:'fake_unsigned_identity'};
const signed=Object.entries(params).map(([k,v])=>`${k}=${encodeURIComponent(v)}`).join('&');
const query=`?${signed}&signature=${sign('sha256',Buffer.from(signed),privateKey).toString('base64url')}&key_id=24680`;
const handler=createSsvHttpHandler({db,now:()=>now,getTrustedGoogleKeys:async()=>keys,enabled:true});
async function request(){
  const srv=createServer(handler);await new Promise(r=>srv.listen(0,'127.0.0.1',r));
  try{return await fetch(`http://127.0.0.1:${srv.address().port}/callback${query}`);}
  finally{await new Promise(r=>srv.close(r));}
}

test('REAL Firestore emulator commit: 3 parallel signed requests -> 1 durable pending credit',async()=>{
  const intentRef=db.collection(m7e4cStorageContract.intentCollection).doc(
    m7e4cStorageContract.intentDocumentIdForNonce(nonce));
  await intentRef.create(i);
  const results=await Promise.all([request(),request(),request()]);
  assert.deepEqual(results.map(r=>r.status).sort(),[200,200,200]);
  const txDoc=await db.collection(m7e4cStorageContract.receiptCollection).doc(id).get();
  assert.equal(txDoc.exists,true);
  assert.equal(txDoc.data().state,'VERIFIED_PENDING_DELIVERY');
  assert.equal((await intentRef.get()).data().status,'CONSUMED');
  const credits=await db.collection(m7e4cStorageContract.creditCollection).where('transactionId','==',id).get();
  assert.equal(credits.size,1);
  assert.equal(credits.docs[0].data().state,'PENDING_DELIVERY');
  // Test only: documents live in demo emulator, not any cloud project.
});
test.after(async()=>{await deleteApp(app);});
