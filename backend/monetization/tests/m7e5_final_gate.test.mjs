import test from 'node:test';
import assert from 'node:assert/strict';
import {assessRelease, REQUIRED_CONTRACTS, REQUIRED_IMPLEMENTATIONS} from '../../../tools/qa/m7e5_release_gate_lib.mjs';

function makeSafeFixture() {
  const present = Object.fromEntries([...REQUIRED_CONTRACTS,...REQUIRED_IMPLEMENTATIONS].map(f=>[f,true]));
  const contracts = {
    'backend/monetization/m6_final_monetization_lock.json':{
      state:'FINAL_MONETIZATION_LOCK_FAIL_CLOSED',
      paid_purchase_production_gate_passed:false,play_checkout_enabled:false,purchase_activation_approved:false,
      production_backend_deployment_approved:false,firebase_callable_runtime_approved:false,
      cloud_save_backend_modification_approved:false},
    'backend/monetization/m7d3_single_reroll_restore_contract.json':{
      max_successful_rerolls_per_run:1,max_successful_rerolls_per_local_day:1,
      m7d2_second_slot_disabled:true,production_release_allowed:false},
    'backend/monetization/m7e4e2_android_readonly_boundary.json':{
      native_bridge_registered:false,read_only_inbox_callable_registered:false,
      client_local_currency_grants:false,client_ack_enabled:false,
      server_delivery_enabled:false,ssv_intent_issuance_live:false},
    'backend/monetization/m7e4e3_crash_delivery_contract.json':{
      this_gate_only:{in_memory_qa_simulator:true,real_Godot_reward_grant:false,
        persistent_Godot_receipt_journal:false,server_ack_endpoint:false,
        android_native_bridge_registered:false,production_ssv_enabled:false,release_approved:false}},
    'backend/monetization/m7e4f_recovery_security_contract.json':{
      verdict:'RELEASE_HOLD',featureFlags:{productionEnabled:false,nativeBridgeActivated:false,
        localSaveReceiptImplemented:false,serverAckImplemented:false,serverAdIntentIssuanceImplemented:false,
        legacyRewardMigrationApproved:false}}
  };
  return {contracts,present,git:{head:'a'.repeat(40),ciSha:'a'.repeat(40),dirty:false},review:{currentShaCIGreen:true}};
}
const assess=fixture=>assessRelease(fixture);
test('valid static contracts still report RELEASE_HOLD, exit 2',()=>{
  const r=assess(makeSafeFixture());assert.equal(r.verdict,'RELEASE_HOLD');assert.equal(r.exitCode,2);
});
test('exact SHA CI green cannot grant production approval',()=>{
  const r=assess(makeSafeFixture());assert(r.blockers.includes('REAL_ANDROID_ATOMIC_REWARD_PLUS_RECEIPT_MISSING'));
});
test('SSV package lock unknown makes reproducibility blocker visible',()=>{
  const r=assess(makeSafeFixture());assert(r.blockers.includes('SSV_NPM_LOCKFILE_NOT_TRACKED_OR_UNKNOWN'));
});
test('missing required file is AUDIT_INVALID, exit 3',()=>{
  const x=makeSafeFixture();delete x.present[REQUIRED_IMPLEMENTATIONS[0]];
  const r=assess(x);assert.equal(r.exitCode,3);
});
test('removing the M6 production lock is invalid',()=>{
  const x=makeSafeFixture();x.contracts[REQUIRED_CONTRACTS[0]].state='SHIPPING';
  assert.equal(assess(x).exitCode,3);
});
test('enabling purchases is invalid',()=>{
  const x=makeSafeFixture();x.contracts[REQUIRED_CONTRACTS[0]].play_checkout_enabled=true;
  assert.equal(assess(x).exitCode,3);
});
test('dao reroll twice per run is invalid',()=>{
  const x=makeSafeFixture();x.contracts[REQUIRED_CONTRACTS[1]].max_successful_rerolls_per_run=2;
  assert.equal(assess(x).exitCode,3);
});
test('active native inbox is invalid before approval',()=>{
  const x=makeSafeFixture();x.contracts[REQUIRED_CONTRACTS[2]].native_bridge_registered=true;
  assert.equal(assess(x).exitCode,3);
});
test('delivery enabled ahead of migration is invalid',()=>{
  const x=makeSafeFixture();x.contracts[REQUIRED_CONTRACTS[2]].server_delivery_enabled=true;
  assert.equal(assess(x).exitCode,3);
});
test('simulated grant claimed as real Android grant is invalid',()=>{
  const x=makeSafeFixture();x.contracts[REQUIRED_CONTRACTS[3]].this_gate_only.real_Godot_reward_grant=true;
  assert.equal(assess(x).exitCode,3);
});
test('server ACK unexpectedly enabled is invalid',()=>{
  const x=makeSafeFixture();x.contracts[REQUIRED_CONTRACTS[4]].featureFlags.serverAckImplemented=true;
  assert.equal(assess(x).exitCode,3);
});
test('an absent flag fails closed, not inferred false',()=>{
  const x=makeSafeFixture();delete x.contracts[REQUIRED_CONTRACTS[4]].featureFlags.serverAckImplemented;
  assert.equal(assess(x).exitCode,3);
});
test('GitHub SHA mismatch invalidates audit',()=>{
  const x=makeSafeFixture();x.git.ciSha='b'.repeat(40);
  assert.equal(assess(x).exitCode,3);
});
test('uncommitted work keeps exact SHA blocker',()=>{
  const x=makeSafeFixture();x.git.dirty=true;
  assert(assess(x).blockers.includes('CURRENT_EXACT_SHA_CI_NOT_CERTIFIED'));
});
test('green CI not externally attested keeps exact SHA blocker',()=>{
  const x=makeSafeFixture();x.review.currentShaCIGreen=false;
  assert(assess(x).blockers.includes('CURRENT_EXACT_SHA_CI_NOT_CERTIFIED'));
});
