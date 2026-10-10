import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { inspectReadOnlyInbox, observePendingInbox, M7E4E2_RELEASE_GATES } from '../ssv/m7e4e2_readonly_client_boundary.mjs';
const path = new URL('../ssv/android_bridge/JadeSsvReadOnlyInboxCandidate.kt', import.meta.url);
const native = readFileSync(path, 'utf8');
const hash = (...x) => createHash('sha256').update(JSON.stringify(x)).digest('hex');
const a = { entitlementId: hash('intent', 'intent_abc'), placement: 'dao_choice_reroll',
  rewardItem: 'reroll', rewardAmount: 1, state: 'PENDING_DELIVERY', createdAtMs: 123 };
const ok = (items = [a]) => ({status:'READ_ONLY_PENDING', items, hasMore:false, creditAllowed:false, clientAckAllowed:false});
const session = tag => ({authenticated:true, sessionTag:tag});
const TAG='session_aa12345';
test('native probe is unregistered, disabled and fixed to read-only callable', () => {
  assert.match(native, /READ_ONLY_PROBE_ENABLED\s*=\s*false/);
  assert.match(native, /FIXED_CALLABLE\s*=\s*"jadePendingInboxEmulator"/);
  assert.match(native, /\.call\(emptyMap<String, Any>\(\)\)/);
  assert.match(native, /getAppCheckToken\(false\)/);
  assert.match(native, /FirebaseAuth\.getInstance\(\)\.currentUser/);
  assert.match(native, /current\.uid != requestedUid/);
  assert.doesNotMatch(native, /RewardManager|grant_reward|write_save_batch|acknowledgeDelivery|\.collection\(|\.runTransaction\(/);
  assert.equal(M7E4E2_RELEASE_GATES.productionEnabled, false);
  assert.equal(M7E4E2_RELEASE_GATES.AndroidRewardGrant, false);
});
test('default disabled and no request attempted', async () => {
  let called=false;
  const r=await observePendingInbox({getSession:()=>{called=true;return session(TAG);},readNativeInbox:()=>ok()});
  assert.deepEqual(r,{status:'DISABLED',pendingCount:0,canGrant:false,canAcknowledge:false});
  assert.equal(called,false);
});
test('read-only snapshot exposes count and no underlying identifiers', () => {
  const r=inspectReadOnlyInbox(ok());
  assert.deepEqual(r,{status:'READ_ONLY_PENDING',pendingCount:1,hasMore:false,canGrant:false,canAcknowledge:false});
  assert.equal(Object.isFrozen(r),true);
  assert.equal(JSON.stringify(r).includes(a.entitlementId),false);
});
test('active session and native transport may display counts only', async () => {
  const r=await observePendingInbox({enabled:true,getSession:()=>session(TAG),readNativeInbox:async()=>ok([a,a && {...a,entitlementId:hash('intent','other')}])});
  assert.equal(r.pendingCount,2);
  assert.equal(r.canGrant,false);
});
test('guest authenticated Firebase session can read without client UID', async()=>{
  const r=await observePendingInbox({enabled:true,getSession:()=>session(TAG),readNativeInbox:async()=>ok([])});
  assert.equal(r.pendingCount,0);
});
test('rejects session changed during asynchronous request', async()=>{
  let n=0;
  await assert.rejects(observePendingInbox({enabled:true,getSession:()=>session(++n===1?TAG:'session_bb54321'),readNativeInbox:async()=>ok()}),/ACCOUNT_CHANGED/);
});
test('requires authenticated session, not arbitrary UID',async()=>{
  await assert.rejects(observePendingInbox({enabled:true,getSession:()=>({authenticated:false,sessionTag:TAG}),readNativeInbox:async()=>ok()}),/AUTH_REQUIRED/);
});
test('transport error has generic unavailable status', async()=>{
  await assert.rejects(observePendingInbox({enabled:true,getSession:()=>session(TAG),readNativeInbox:async()=>{throw Error('private bearer token')}}),e=>e.code==='INBOX_UNAVAILABLE'&&!e.message.includes('private'));
});
test('rejects credit or ack authorization in response',()=>{
  for(const payload of [{...ok(),creditAllowed:true},{...ok(),clientAckAllowed:true},{...ok(),status:'DELIVERED'}])
    assert.throws(()=>inspectReadOnlyInbox(payload),/UNTRUSTED_INBOX_RESPONSE/);
});
test('rejects unapproved response item fields and amount',()=>{
  for(const item of [{...a,userId:'private_uid'},{...a,transactionId:'secret'},{...a,rewardAmount:0},{...a,entitlementId:'invalid'},{...a,state:'DELIVERED'}])
    assert.throws(()=>inspectReadOnlyInbox(ok([item])),/UNTRUSTED_INBOX_ITEM/);
});
test('rejects duplicate entitlement IDs and oversized inbox',()=>{
  assert.throws(()=>inspectReadOnlyInbox(ok([a,a])),/UNTRUSTED_INBOX_ITEM/);
  assert.throws(()=>inspectReadOnlyInbox(ok(Array(21).fill(a))),/UNTRUSTED_INBOX_RESPONSE/);
});
test('rejects unknown placement, unsafe item or malformed timestamp',()=>{
  for(const item of [{...a,placement:'paid_purchase'},{...a,rewardItem:'../wallet'},{...a,createdAtMs:-1}])
    assert.throws(()=>inspectReadOnlyInbox(ok([item])),/UNTRUSTED_INBOX_ITEM/);
});
