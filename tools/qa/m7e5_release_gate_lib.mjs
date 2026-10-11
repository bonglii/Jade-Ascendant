/** M7E5 read-only, fail-closed release readiness assessment. */
export const BASELINE_SHA = 'ff5b6152151eee9b1a2f7f4e75e896dea4b9564c';

export const REQUIRED_CONTRACTS = Object.freeze([
  'backend/monetization/m6_final_monetization_lock.json',
  'backend/monetization/m7d3_single_reroll_restore_contract.json',
  'backend/monetization/m7e4e2_android_readonly_boundary.json',
  'backend/monetization/m7e4e3_crash_delivery_contract.json',
  'backend/monetization/m7e4f_recovery_security_contract.json',
]);

export const REQUIRED_IMPLEMENTATIONS = Object.freeze([
  'backend/monetization/ssv/m7e4b_ssv_verifier.mjs',
  'backend/monetization/ssv/m7e4c_receipt_ledger.mjs',
  'backend/monetization/ssv/m7e4d_http_boundary.mjs',
  'backend/monetization/ssv/m7e4e_pending_inbox.mjs',
  'backend/monetization/ssv/m7e4e2_readonly_client_boundary.mjs',
  'backend/monetization/ssv/m7e4e3_crash_delivery_dryrun.mjs',
  'backend/monetization/ssv/functions/index.mjs',
  'backend/monetization/ssv/functions/tests/m7e4d_firestore_emulator.test.mjs',
  'backend/monetization/ssv/functions/tests/m7e4e_firestore_inbox_emulator.test.mjs',
  'backend/monetization/ssv/functions/tests/m7e4f_firestore_recovery_emulator.test.mjs',
  'scripts/managers/monetization_manager.gd',
  'scripts/monetization/admob_provider.gd',
  'scripts/managers/google_account_manager.gd',
  '.github/workflows/monetization-m7e5-exact-sha-qa.yml',
]);

const requiredFalse = (obj, keys, label, checks) => {
  for (const key of keys) checks[`${label}.${key}`] = obj?.[key] === false;
};

/** Pure evaluator: only the provided facts are trusted. A green test is never release approval. */
export function assessRelease({contracts = {}, present = {}, git = {}, review = {}} = {}) {
  const checks = {};
  for (const path of REQUIRED_CONTRACTS) checks[`file:${path}`] = present[path] === true;
  for (const path of REQUIRED_IMPLEMENTATIONS) checks[`file:${path}`] = present[path] === true;

  const m6 = contracts['backend/monetization/m6_final_monetization_lock.json'];
  const reroll = contracts['backend/monetization/m7d3_single_reroll_restore_contract.json'];
  const android = contracts['backend/monetization/m7e4e2_android_readonly_boundary.json'];
  const dryrun = contracts['backend/monetization/m7e4e3_crash_delivery_contract.json'];
  const faults = contracts['backend/monetization/m7e4f_recovery_security_contract.json'];
  checks['m6.production lock'] = m6?.state === 'FINAL_MONETIZATION_LOCK_FAIL_CLOSED';
  requiredFalse(m6, ['paid_purchase_production_gate_passed', 'play_checkout_enabled', 'purchase_activation_approved',
    'production_backend_deployment_approved', 'firebase_callable_runtime_approved', 'cloud_save_backend_modification_approved'], 'm6', checks);
  checks['dao.one per run'] = reroll?.max_successful_rerolls_per_run === 1;
  checks['dao.one per day'] = reroll?.max_successful_rerolls_per_local_day === 1;
  checks['dao.second slot disabled'] = reroll?.m7d2_second_slot_disabled === true;
  checks['dao.production off'] = reroll?.production_release_allowed === false;
  requiredFalse(android, ['native_bridge_registered', 'read_only_inbox_callable_registered',
    'client_local_currency_grants', 'client_ack_enabled', 'server_delivery_enabled',
    'ssv_intent_issuance_live'], 'android', checks);
  checks['dryrun model only'] = dryrun?.this_gate_only?.in_memory_qa_simulator === true;
  requiredFalse(dryrun?.this_gate_only, ['real_Godot_reward_grant', 'persistent_Godot_receipt_journal',
    'server_ack_endpoint', 'android_native_bridge_registered', 'production_ssv_enabled',
    'release_approved'], 'dryrun', checks);
  requiredFalse(faults?.featureFlags, ['productionEnabled', 'nativeBridgeActivated',
    'localSaveReceiptImplemented', 'serverAckImplemented', 'serverAdIntentIssuanceImplemented',
    'legacyRewardMigrationApproved'], 'faults', checks);
  checks['faults release hold contract'] = faults?.verdict === 'RELEASE_HOLD';
  checks['exact sha run binding'] = Boolean(git.head) && (!git.ciSha || git.head === git.ciSha);
  checks['m6 purchase not activated'] = m6?.play_checkout_enabled === false;
  const violations = Object.entries(checks).filter(([,ok]) => !ok).map(([key]) => key);

  const blockers = [
    'REAL_ANDROID_ATOMIC_REWARD_PLUS_RECEIPT_MISSING',
    'SSV_AUTHENTICATED_ACK_ENDPOINT_MISSING',
    'SERVER_ISSUED_AD_INTENT_NOT_CONNECTED',
    'LEGACY_LOCAL_AD_REWARD_TO_SSV_MIGRATION_UNPROVEN',
    'ANDROID_NATIVE_INBOX_ACTIVATION_PENDING',
    'GUEST_TO_GOOGLE_UID_CONTINUITY_NOT_CERTIFIED',
    'REAL_DEVICE_FAULT_INJECTION_NOT_CERTIFIED',
    'PRODUCTION_DEPLOYMENT_AND_GOOGLE_ADMOB_CONFIGURATION_NOT_APPROVED',
  ];
  if (!git.ciSha || !git.head || git.head !== git.ciSha || git.dirty === true || review.currentShaCIGreen !== true)
    blockers.push('CURRENT_EXACT_SHA_CI_NOT_CERTIFIED');
  if (present['backend/monetization/ssv/functions/package-lock.json'] !== true)
    blockers.push('SSV_NPM_LOCKFILE_NOT_TRACKED_OR_UNKNOWN');
  return {
    phase: 'MONETIZATION_M7E5', kind: 'READ_ONLY_NO_DEPLOY',
    verdict: violations.length ? 'AUDIT_INVALID' : 'RELEASE_HOLD',
    auditedHead: git.head || null, ciSha: git.ciSha || null,
    checks, violations, blockers,
    summary: 'QA success is not production release approval. No source changes, commits, pushes or deploys performed.',
    exitCode: violations.length ? 3 : 2,
  };
}
