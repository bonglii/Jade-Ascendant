import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createDeliveryDryRunHarness as make, M7E4E3_RELEASE_GATES as gates } from '../ssv/m7e4e3_crash_delivery_dryrun.mjs';
const ID = createHash('sha256').update('qa-intent').digest('hex');
const ITEM = 'qa_item';
const base = Object.freeze({ accountTag:'qa_account_A1', entitlementId:ID, placement:'victory_encore', rewardItem:ITEM, rewardAmount:50, createdAtMs: 120000, state:'PENDING_DELIVERY' });
function setup(initial=[base]) {
  let tag='qa_account_A1';
  const shared = {fakeTrustedEntitlements:new Map(initial.map(e=>[e.entitlementId,e])),local:{receipts:new Map(),currency:new Map()},server:{acknowledgements:new Map()},getAccountTag:()=>tag};
  return {shared, call:()=>make(shared), switchTo:t=>{tag=t;}};
}
const total = s=>s.currency.get('qa_account_A1:qa_item')??0;
const faultCodes={before_commit:'SIMULATED_CRASH_BEFORE_COMMIT',after_commit:'SIMULATED_CRASH_AFTER_COMMIT',before_ack:'SIMULATED_CRASH_BEFORE_ACK',ack_timeout:'SIMULATED_ACK_TIMEOUT',after_ack:'SIMULATED_CRASH_AFTER_ACK'};
test('all live, transport, local save, ack and production gates are disabled',()=>{
  assert.deepEqual(Object.values(gates).filter(x=>x===true),[true]);
  assert.equal(gates.localAtomicGrantImplemented,false); assert.equal(gates.productionEnabled,false);
});
test('dry run model applies one mock credit and stores local receipt before ack',async()=>{
  const x=setup(); await x.call().attempt(ID);
  const s=x.call().snapshotForTests();
  assert.equal(total(s),50); assert.equal(s.receipts.size,1); assert.equal(s.acknowledgements.size,1);
});
test('retry same entitlement never reapplies credits',async()=>{
  const x=setup(); const h=x.call();await h.attempt(ID); await h.attempt(ID);await x.call().attempt(ID);
  assert.equal(total(x.call().snapshotForTests()),50);
});
for(const [fault,code] of Object.entries(faultCodes)) {
  test(`recovery from ${fault} after harness restart is once-only`,async()=>{
    const x=setup(); await assert.rejects(x.call().attempt(ID,{fault}),e=>e.code===code);
    const mid=x.call().snapshotForTests();
    assert.equal(total(mid),fault==='before_commit'?0:50);
    assert.equal(mid.acknowledgements.size,fault==='after_ack'?1:0);
    await x.call().attempt(ID);
    const done=x.call().snapshotForTests(); assert.equal(total(done),50);
    assert.equal(done.receipts.size,1);assert.equal(done.acknowledgements.size,1);
  });
}
test('account mismatch before request prevents model credit and ack',async()=>{
  const x=setup();x.switchTo('qa_account_B2');
  await assert.rejects(x.call().attempt(ID),e=>e.code==='ACCOUNT_CHANGED');
  assert.equal(total(x.call().snapshotForTests()),0);
});
test('account changes after local write leave only unacked local receipt',async()=>{
  const x=setup(); await assert.rejects(x.call().attempt(ID,{fault:'account_changed_after_commit'}),e=>e.code==='ACCOUNT_CHANGED');
  assert.equal(total(x.call().snapshotForTests()),50);
  assert.equal(x.call().snapshotForTests().acknowledgements.size,0);
  x.switchTo('qa_account_B2');await assert.rejects(x.call().attempt(ID),e=>e.code==='ACCOUNT_CHANGED');
  x.switchTo('qa_account_A1');await x.call().attempt(ID);
  assert.equal(total(x.call().snapshotForTests()),50);
});
test('no acknowledgment after failed local commit',async()=>{
  const x=setup();await assert.rejects(x.call().attempt(ID,{fault:'before_commit'}));
  assert.equal(x.call().snapshotForTests().acknowledgements.size,0);
});
test('concurrent duplicate attempts serialize and cannot double grant',async()=>{
  const x=setup();const h=x.call();await Promise.all(Array.from({length:20},()=>h.attempt(ID)));
  assert.equal(total(x.call().snapshotForTests()),50);
  assert.equal(x.call().snapshotForTests().acknowledgements.size,1);
});
test('corrupted local receipt is rejected without regrant/ack',async()=>{
  const x=setup(); await x.call().attempt(ID); x.shared.local.receipts.set(ID,{entitlementId:ID,accountTag:'qa_account_A1',digest:'tampered',state:'LOCAL_COMMITTED'});
  await assert.rejects(x.call().attempt(ID),e=>e.code==='LOCAL_RECEIPT_INTEGRITY_FAILURE');
  assert.equal(total(x.call().snapshotForTests()),50);
});
test('tampered entitlement amount after commit rejected by receipt digest',async()=>{
  const x=setup();await x.call().attempt(ID);
  x.shared.fakeTrustedEntitlements.set(ID,{...base,rewardAmount:999});
  await assert.rejects(x.call().attempt(ID),e=>e.code==='LOCAL_RECEIPT_INTEGRITY_FAILURE');
  assert.equal(total(x.call().snapshotForTests()),50);
});
test('mismatched acknowledgment rejects without regrant',async()=>{
  const x=setup();await x.call().attempt(ID);x.shared.server.acknowledgements.set(ID,'bogus');
  await assert.rejects(x.call().attempt(ID),e=>e.code==='SERVER_ACK_INTEGRITY_FAILURE');
  assert.equal(total(x.call().snapshotForTests()),50);
});
test('fake server entitlement with arbitrary fields is rejected',async()=>{
  const x=setup([{...base,balanceOverride:100000}]);
  await assert.rejects(x.call().attempt(ID),e=>e.code==='INVALID_FAKE_SERVER_ENTITLEMENT');
  assert.equal(total(x.call().snapshotForTests()),0);
});
test('fake server entitlement with invalid or unsupported placement rejected',async()=>{
  const x=setup([{...base,placement:'purchase_token'}]);
  await assert.rejects(x.call().attempt(ID),e=>e.code==='INVALID_FAKE_SERVER_ENTITLEMENT');
});
test('invalid ID and unknown ID reject without ack or credit',async()=>{
  const x=setup();await assert.rejects(x.call().attempt('abc'),e=>e.code==='ENTITLEMENT_ID_INVALID');
  await assert.rejects(x.call().attempt('0'.repeat(64)),e=>e.code==='INVALID_FAKE_SERVER_ENTITLEMENT');
  assert.equal(total(x.call().snapshotForTests()),0);
});
test('fake server still does not touch real local saves or Google/Firebase',async()=>{
  const x=setup(); const s=x.call().snapshotForTests();
  assert.ok(s.receipts instanceof Map); assert.ok(s.currency instanceof Map);
  assert.equal(gates.authenticatedDeliveryCallable,false);
});
