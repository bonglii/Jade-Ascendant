import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {createDeliveryDryRunHarness as create, M7E4E3_RELEASE_GATES} from '../ssv/m7e4e3_crash_delivery_dryrun.mjs';

const sha = s => createHash('sha256').update(s).digest('hex');
const account = 'm7e4f_qa_test_A1';
const faults = [null,'before_commit','after_commit','before_ack','ack_timeout','after_ack'];
const newid = n => sha(`m7e4f-demo-only-${n}`);
function ctx(num,placement='victory_encore') {
  const entitlementId = newid(num), rewardAmount = (num % 99)+1;
  const e = Object.freeze({accountTag:account,entitlementId,placement,
    rewardAmount,rewardItem:'qa_tokens',createdAtMs:123000+num,state:'PENDING_DELIVERY'});
  let user = account;
  const shared = {fakeTrustedEntitlements:new Map([[entitlementId,e]]),
    local:{receipts:new Map(),currency:new Map()},server:{acknowledgements:new Map()},getAccountTag:()=>user};
  return {shared,entitlementId,rewardAmount,getUser:()=>user,switchUser:v=>{user=v;},
    restart:()=>create(shared),
    balance:()=>shared.local.currency.get(`${account}:qa_tokens`)??0};
}
test('production and client-grant gates remain disabled',()=>{
  assert.equal(M7E4E3_RELEASE_GATES.productionEnabled,false);
  assert.equal(M7E4E3_RELEASE_GATES.localAtomicGrantImplemented,false);
  assert.equal(M7E4E3_RELEASE_GATES.serverAckImplemented,false);
  assert.equal(M7E4E3_RELEASE_GATES.authenticatedDeliveryCallable,false);
  assert.equal(M7E4E3_RELEASE_GATES.legacyClientRewardMigrationApproved,false);
});
for (const fault of faults) {
  test(`restart twice and retry 30 times after ${fault??'success'} never duplicates`,async()=>{
    const x=ctx(faults.indexOf(fault)+100);
    if(fault) await assert.rejects(x.restart().attempt(x.entitlementId,{fault}));
    else await x.restart().attempt(x.entitlementId);
    const pre = x.balance();
    assert.equal(pre,fault==='before_commit'?0:x.rewardAmount);
    await x.restart().attempt(x.entitlementId);
    await Promise.all(Array.from({length:30},()=>x.restart().attempt(x.entitlementId)));
    assert.equal(x.balance(),x.rewardAmount);
    assert.equal(x.shared.local.receipts.size,1);
    assert.equal(x.shared.server.acknowledgements.size,1);
  });
}
test('deterministic 210-case crash matrix remains exactly once',async()=>{
  let state=0x9e3779b9;
  const next=()=>{state^=state<<13;state^=state>>>17;state^=state<<5;return state>>>0;};
  for(let n=1;n<=210;n++) {
    const x=ctx(n+1000); const fault=faults[next()%faults.length];
    const one=x.restart();
    if(fault) await assert.rejects(one.attempt(x.entitlementId,{fault}));
    else await one.attempt(x.entitlementId);
    assert.equal(x.balance(),fault==='before_commit'?0:x.rewardAmount);
    await x.restart().attempt(x.entitlementId);
    const rounds=next()%6+2;
    for(let k=0;k<rounds;k++) await x.restart().attempt(x.entitlementId);
    assert.equal(x.balance(),x.rewardAmount,`duplicate for seed ${n}, fault ${fault}`);
    assert.equal(x.shared.local.receipts.size,1);
    assert.equal(x.shared.server.acknowledgements.size,1);
  }
});
test('account switches fail closed and old account can resume',async()=>{
  const x=ctx(9191);
  await assert.rejects(x.restart().attempt(x.entitlementId,{fault:'account_changed_after_commit'}),e=>e.code==='ACCOUNT_CHANGED');
  assert.equal(x.balance(),x.rewardAmount);
  x.switchUser('m7e4f_qa_test_B2');
  await assert.rejects(x.restart().attempt(x.entitlementId),e=>e.code==='ACCOUNT_CHANGED');
  assert.equal(x.shared.server.acknowledgements.size,0);
  x.switchUser(account);await x.restart().attempt(x.entitlementId);
  assert.equal(x.balance(),x.rewardAmount);
});
test('corrupt persisted receipt must reject instead of grant or acknowledge',async()=>{
  const x=ctx(9292);
  await assert.rejects(x.restart().attempt(x.entitlementId,{fault:'after_commit'}));
  x.shared.local.receipts.set(x.entitlementId,{entitlementId:x.entitlementId,accountTag:account,digest:'invalid',state:'LOCAL_COMMITTED'});
  await assert.rejects(x.restart().attempt(x.entitlementId),e=>e.code==='LOCAL_RECEIPT_INTEGRITY_FAILURE');
  assert.equal(x.balance(),x.rewardAmount);
  assert.equal(x.shared.server.acknowledgements.size,0);
});
test('tampered entitlement payload cannot authorize second credit',async()=>{
  const x=ctx(9393);await x.restart().attempt(x.entitlementId);
  const old=x.shared.fakeTrustedEntitlements.get(x.entitlementId);
  x.shared.fakeTrustedEntitlements.set(x.entitlementId,{...old,rewardAmount:99999});
  await assert.rejects(x.restart().attempt(x.entitlementId),e=>e.code==='LOCAL_RECEIPT_INTEGRITY_FAILURE');
  assert.equal(x.balance(),x.rewardAmount);
});
test('concurrency bursts have exactly one simulated local grant',async()=>{
  const x=ctx(9494);
  await Promise.all(Array.from({length:75},()=>x.restart().attempt(x.entitlementId)));
  assert.equal(x.balance(),x.rewardAmount);
  assert.equal(x.shared.local.receipts.size,1);
  assert.equal(x.shared.server.acknowledgements.size,1);
});
