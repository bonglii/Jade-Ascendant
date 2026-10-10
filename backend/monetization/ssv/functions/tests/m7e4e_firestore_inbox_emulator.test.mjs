/** Real Firestore Emulator read-only inbox QA. This test writes ONLY to emulator. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { createHash, randomBytes } from 'node:crypto';
import { readPendingEntitlements } from '../../m7e4e_pending_inbox.mjs';

const host=process.env.FIRESTORE_EMULATOR_HOST ?? '';
if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d{2,5}$/.test(host)) {
  throw new Error('M7E4E1 refuses database access outside localhost Firestore Emulator');
}
const project='demo-jade-ssv';
if (process.env.GCLOUD_PROJECT && process.env.GCLOUD_PROJECT !== project) {
  throw new Error('M7E4E1 requires demo-jade-ssv emulator project');
}
const require=createRequire(import.meta.url);
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const app=initializeApp({projectId:project},`m7e4e-${randomBytes(6).toString('hex')}`);
const db=getFirestore(app);
const key=(...x)=>createHash('sha256').update(JSON.stringify(x)).digest('hex');
const nonce=randomBytes(7).toString('hex');
const uid=`qa_user_${nonce}`;
const otherUid=`qa_other_${nonce}`;
const intentId=`qa_intent_${nonce}`;
const transactionId=`qa_transaction_${nonce}`;
const creditId=key('intent',intentId);
const credit={intentId,transactionId,userId:uid,placement:'dao_choice_reroll',rewardAmount:1,rewardItem:'reroll',state:'PENDING_DELIVERY',createdAtMs:Date.now()};
const receipt={...credit,state:'VERIFIED_PENDING_DELIVERY'};
const creditRef=db.collection('m7e4c_ssv_credits').doc(creditId);
const receiptRef=db.collection('m7e4c_ssv_receipts').doc(transactionId);
test.after(async()=>{
  try { await Promise.all([creditRef.delete(),receiptRef.delete()]); }
  finally { await deleteApp(app); }
});
test('real Firestore Emulator: UID read filter, durable receipt and missing receipt fail-closed',async()=>{
  await Promise.all([creditRef.set(credit),receiptRef.set(receipt)]);
  const pending=await readPendingEntitlements({db,authenticatedUid:uid});
  assert.equal(pending.status,'READ_ONLY_PENDING');
  assert.equal(pending.items.length,1);
  assert.equal(pending.items[0].entitlementId,creditId);
  assert.equal(pending.creditAllowed,false);
  const other=await readPendingEntitlements({db,authenticatedUid:otherUid});
  assert.equal(other.items.length,0);
  await receiptRef.delete();
  await assert.rejects(readPendingEntitlements({db,authenticatedUid:uid}),/DURABLE_LEDGER_INVARIANT_BROKEN/);
});
