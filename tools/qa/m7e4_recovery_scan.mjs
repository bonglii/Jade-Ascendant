#!/usr/bin/env node
// JADE M7E4A — read-only source / release-boundary scan. Never writes saves.
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const functionBody = (source, methodName) => {
  const at = source.search(new RegExp(`^(?:static )?func ${methodName}\\(`, 'm'));
  if (at < 0) throw new Error(`Missing GDScript method: ${methodName}`);
  const tail = source.slice(at);
  const next = tail.slice(1).search(/\n(?:func|static func) /m);
  return next < 0 ? tail : tail.slice(0, next + 1);
};
const manager = read('scripts/managers/monetization_manager.gd');
const store = read('scripts/monetization/monetization_policy_store.gd');
const saves = read('scripts/managers/save_manager.gd');
const reward = read('scripts/managers/reward_manager.gd');
const gate = read('scripts/monetization/m7e2_legacy_security_gate.gd');
const m7b = read('scripts/monetization/m7b_daily_reward_bridge.gd');
const daily = read('scripts/managers/daily_quest_manager.gd');
const levels = read('scripts/ui/level_up.gd');
const journey = read('scripts/managers/journey_manager.gd');
const lock = JSON.parse(read('backend/monetization/m6_final_monetization_lock.json'));
const confirmed = functionBody(manager, '_on_reward_confirmed');
const policy = functionBody(store, 'load_state');
const batch = functionBody(saves, 'write_save_batch');
const grant = functionBody(reward, 'grant_reward');
const blockers = [];
const evidence = [];
const flag = (id, explanation, severity = 'RELEASE_BLOCKER') => blockers.push({id, severity, explanation});
const note = (id, present) => evidence.push({id, present: Boolean(present)});
const oldGuard = /static func earned_is_durable\(/.test(gate) && /policy_store/.test(gate) && /load_state/.test(gate);
const newGuard = /func _on_sdk_reward\(/.test(m7b) && /policy_store\.call\("load_state"\)/.test(m7b);
const atomicReward = /write_save_batch\(targets\)/.test(grant) && /TRANSACTION_PATH/.test(saves) && /_recover_pending_transaction/.test(saves) && /_finish_pending_transaction/.test(saves);
const policyValidation = /_read_valid_state\(SAVE_PATH\)/.test(policy) && /_read_valid_state\(SAVE_PATH \+ "\.backup"\)/.test(policy);
const policyUnknownIsDefault = /if state\.is_empty\(\):\s*\n\s*return _default_state\(/.test(policy);
const unsafeCallbackAfterFail = /if not _save_policy_state\(\):[\s\S]*verified_rewarded_completed\.emit/.test(confirmed) && !/if not _save_policy_state\(\):\s*\n\s*return/.test(confirmed);
const rerollSingle = /m7d_used_run_id/.test(daily) && /m7d_run_id/.test(journey) && /_m7d_on_sdk_reward/.test(levels) && !/dao_choice_reroll_slot_2/.test(levels);
note('legacy_durable_policy_owner_guard',oldGuard);
note('new_daily_durable_policy_owner_guard',newGuard);
note('reward_domain_batch_journal',atomicReward);
note('policy_primary_backup_validation',policyValidation);
note('dao_single_run_restored',rerollSingle);
if (!oldGuard || !newGuard) flag('MISSING_LOCAL_DURABILITY_GUARD','Expected M7E2 or M7B local-policy verification has drifted.');
if (!atomicReward) flag('SAVE_BATCH_CONTRACT_DRIFT','Progression/inventory journal path could not be established.');
if (!policyValidation) flag('POLICY_STORE_CONTRACT_DRIFT','Primary/backup read validation could not be established.');
if (!rerollSingle) flag('DAO_SINGLE_REROLL_CONTRACT_DRIFT','Dao Reroll 1-per-run final behavior could not be established.');
if (unsafeCallbackAfterFail) flag('POLICY_SAVE_FAIL_LOST_EARNED_REWARD','Ad SDK earned callback can proceed after policy save failure; owner guards fail closed without durable compensation.');
else flag('POLICY_FAILURE_PATH_NEEDS_FAULT_INJECTION','Policy-save failure handling has changed; rerun adversarial Android faults before approving release.');
if (policyUnknownIsDefault) flag('POLICY_BOTH_COPIES_INVALID_RESET','If both local policy files are invalid, state falls back to default; local counters may reset.');
else flag('POLICY_CORRUPTION_HANDLING_NOT_PROVEN','A fail-closed monotonic policy counter has not been independently verified.');
if (!/"monetization_policy"\s*:\s*\{/.test(saves)) {
  flag('NO_CROSS_DOMAIN_ATOMIC_AD_RECEIPT','Ad policy file is outside the SaveManager grant journal; SDK-earned ad and reward are not committed in one durable transaction.');
}
flag('SSV_SERVER_PROOF_MISSING','On-device earned callback is not an AdMob-signed server-side grant or authoritative ledger.', 'EXTERNAL');
flag('FAULT_INJECTION_ANDROID_PENDING','Need test-device fault injection: I/O failure before and after earned, killed process, corrupt primary and backup.', 'EXTERNAL');
flag('EXACT_SHA_CI_PENDING','Run repository CI on the exact patch commit SHA and inspect actual results.', 'EXTERNAL');
note('iap_production_disabled',lock.purchase_activation_approved === false && lock.play_checkout_enabled === false);
if (lock.purchase_activation_approved !== false || lock.play_checkout_enabled !== false) flag('IAP_LOCK_OPEN','Purchases unexpectedly enabled.');
const report = {
  phase: 'MONETIZATION_M7E4A', kind:'read_only_recovery_boundary_scan',
  verdict: 'RELEASE_HOLD',
  scope: 'Local source inspection, not backend proof, not Android fault injection',
  evidence, blockers,
  next: 'Design authenticated SSV backend/ledger and crash-safe pending-earned recovery; do not auto-grant unverified callbacks.'
};
console.log(JSON.stringify(report, null, 2));
console.error(`M7E4A: RELEASE_HOLD — ${blockers.map(x=>x.id).join(', ')}`);
process.exitCode = 2;
