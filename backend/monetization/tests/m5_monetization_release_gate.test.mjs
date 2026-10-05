import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../..");
const read = path => readFileSync(resolve(root, path), "utf8");
const blob = path => execFileSync(
  "git",
  ["hash-object", path],
  { cwd: root, encoding: "utf8" },
).trim();

const gate = JSON.parse(
  read("backend/monetization/m5_monetization_release_gate.json"),
);
const production = JSON.parse(
  read("backend/monetization/production_approval_boundary.json"),
);
const m1b2c = JSON.parse(
  read("backend/monetization/m1b2_authority_recovery_gate.json"),
);
const m2 = JSON.parse(
  read("backend/monetization/m2_billing_lifecycle_boundary.json"),
);
const m3 = JSON.parse(
  read("backend/monetization/m3_treasury_production_contract.json"),
);
const m4 = JSON.parse(
  read("backend/monetization/m4_admob_ump_production_boundary.json"),
);
const pavilion = read("scripts/managers/pavilion_manager.gd");
const project = read("project.godot");
const releaseDoc = read("release/GOOGLE_PLAY_IAP_SETUP.md");
const workflow = read(".github/workflows/monetization-native-bridge-qa.yml");

const activeIds = [
  "jade_pouch_100",
  "jade_satchel_550",
  "jade_casket_1200",
  "jade_vault_2500",
  "jade_treasury_6500",
  "jade_ascendant_14000",
];

test("M5 splits ads code readiness from paid-purchase production readiness", () => {
  assert.equal(gate.state, "MONETIZATION_RELEASE_GATES_FAIL_CLOSED");
  assert.equal(
    gate.base_locked_sha,
    "68a92b8083a2c65067ab06f9ea459faf314f4b6f",
  );
  assert.equal(gate.rewarded_ads_code_gate_passed, true);
  assert.equal(gate.rewarded_ads_external_release_validation_required, true);
  assert.equal(gate.paid_purchase_security_contract_gate_passed, true);
  assert.equal(gate.paid_purchase_production_gate_passed, false);
  assert.equal(gate.full_monetization_release_gate_passed, false);
  assert.equal(gate.exact_sha_ci_required, true);
  assert.equal(gate.explicit_human_release_approval_required, true);
  assert.deepEqual(gate.active_internal_product_ids, activeIds);
});

test("M5 paid-purchase production gate remains fail-closed at every activation boundary", () => {
  for (const key of [
    "production_backend_deployment_approved",
    "production_credentials_approved",
    "google_play_api_access_approved",
    "persistent_ledger_approved",
    "firebase_callable_runtime_approved",
    "native_purchase_bridge_shipping_integrated",
    "native_purchase_bridge_project_enabled",
    "purchase_activation_approved",
    "secure_purchase_authority_ready",
    "play_checkout_enabled",
    "purchase_recovery_enabled",
    "raw_purchase_token_persistence_allowed",
    "client_consume_allowed",
    "client_acknowledge_allowed",
    "client_finalize_allowed",
    "cloud_save_backend_modification_approved",
    "prior_locked_boundary_mutation_allowed",
  ]) {
    assert.equal(gate[key], false, `${key} must remain false`);
  }

  for (const key of [
    "deployment_approved",
    "production_credentials_approved",
    "google_play_api_access_approved",
    "persistent_ledger_approved",
    "firebase_callable_runtime_approved",
    "production_purchase_grants_approved",
  ]) {
    assert.equal(production[key], false, `M1A ${key} must remain false`);
  }

  assert.equal(m1b2c.production_activation_approved, false);
  assert.equal(m1b2c.firebase_callable_runtime_approved, false);
  assert.equal(m1b2c.native_purchase_bridge_enabled, false);
  assert.equal(m1b2c.tracked_aar_integrated, false);
  assert.equal(m1b2c.secure_purchase_authority_ready, false);
  assert.equal(m1b2c.play_checkout_enabled, false);
  assert.equal(m1b2c.purchase_recovery_enabled, false);

  assert.equal(m2.production_activation_approved, false);
  assert.equal(m2.secure_purchase_authority_ready, false);
  assert.equal(m2.play_checkout_enabled, false);
  assert.equal(m2.purchase_recovery_enabled, false);

  assert.equal(m3.production_activation_approved, false);
  assert.equal(m3.secure_purchase_authority_ready, false);
  assert.equal(m3.play_checkout_enabled, false);
  assert.equal(m3.purchase_recovery_enabled, false);

  assert.match(
    pavilion,
    /const SECURE_PURCHASE_ACTIVATION_APPROVED: bool = false/,
  );
  assert.doesNotMatch(project, /JadeMonetizationNativeBridge/);

  assert.equal(
    existsSync(resolve(
      root,
      "addons/JadeMonetizationNativeBridge/bin/debug/JadeMonetizationNativeBridge-debug.aar",
    )),
    false,
  );
  assert.equal(
    existsSync(resolve(
      root,
      "addons/JadeMonetizationNativeBridge/bin/release/JadeMonetizationNativeBridge-release.aar",
    )),
    false,
  );
});

test("M5 keeps the M4 rewarded-ads code gate locked while requiring external release validation", () => {
  assert.equal(m4.state, "ADMOB_UMP_PRODUCTION_HARDENED");
  assert.equal(m4.android_release_rewarded_ads_enabled_when_policy_allows, true);
  assert.equal(m4.rewarded_ads_optional, true);
  assert.equal(m4.release_requires_valid_production_ids, true);
  assert.equal(m4.release_rejects_google_sample_and_test_ids, true);
  assert.equal(m4.ump_consent_update_each_launch, true);
  assert.equal(m4.ads_before_consent_gate_allowed, false);
  assert.equal(m4.consent_failure_fail_closed, true);
  assert.equal(m4.consent_retry_enabled, true);
  assert.equal(m4.privacy_options_release_surface, true);
  assert.equal(m4.reward_grant_requires_sdk_reward_callback, true);
  assert.equal(m4.reward_callback_replay_allowed, false);
});

test("M5 active purchase catalog remains the exact six locked Treasury products", () => {
  assert.deepEqual(production.active_internal_product_ids, activeIds);
  assert.deepEqual(m3.active_internal_product_ids, activeIds);
  assert.deepEqual(gate.active_internal_product_ids, activeIds);
  assert.equal(m3.starter_support_pack_active, false);
  assert.equal(m3.monthly_jade_blessing_active, false);
});

test("M5 release documentation and CI state the fail-closed release decision", () => {
  assert.match(releaseDoc, /## M5 monetization release gates/);
  assert.match(releaseDoc, /Rewarded ads code gate: \*\*PASS\*\*/);
  assert.match(releaseDoc, /Paid purchase production gate: \*\*BLOCKED\*\*/);
  assert.match(releaseDoc, /Full monetization release gate: \*\*BLOCKED\*\*/);
  assert.match(
    releaseDoc,
    /M5 itself does not change[\s\S]*`SECURE_PURCHASE_ACTIVATION_APPROVED`/,
  );
  assert.match(
    workflow,
    /backend\/monetization\/tests\/m5_monetization_release_gate\.test\.mjs/,
  );
});

test("M5 preserves every locked runtime and backend authority blob", () => {
  assert.equal(
    blob("scripts/managers/pavilion_manager.gd"),
    "b1133f887f836a74a69e188208c92e9338dce17e",
  );
  assert.equal(
    blob("scripts/monetization/google_play_billing_provider.gd"),
    "8a7723d5c86836d0a4b20158b2f8783b38458f20",
  );
  assert.equal(
    blob("scripts/monetization/admob_provider.gd"),
    "a2d72a5f6d358157d8b30677183dcaee3abc8512",
  );
  assert.equal(
    blob("backend/monetization/production_approval_boundary.json"),
    "02c249b931b10c21a90f8c03cc908e8fd0722602",
  );
  assert.equal(
    blob("backend/monetization/m1b2_authority_recovery_gate.json"),
    "baccbd02a35a3672482f25cbf5d333f1dd2174fc",
  );
  assert.equal(
    blob("backend/monetization/m2_billing_lifecycle_boundary.json"),
    "037988a195867afd397a9b9e51afb86902a6c45f",
  );
  assert.equal(
    blob("backend/monetization/m3_treasury_production_contract.json"),
    "4e5b7bbecb1662c833edff6546c33bd20b5b1338",
  );
  assert.equal(
    blob("backend/monetization/m4_admob_ump_production_boundary.json"),
    "8593338491da99d95d3c610858fdd6aeec617986",
  );
  assert.equal(
    blob("backend/monetization/src/purchase_authority.mjs"),
    "13b0b76b2056740bd120dc2e1a8fda8aa65f1d86",
  );
  assert.equal(
    blob("project.godot"),
    "fe7f658b1e6d4305fad287ce705dac77e7e44a1b",
  );
  assert.equal(
    blob("export_presets.cfg"),
    "09fa1ade5c26a79e9a82d5a36c114161bd6f83d6",
  );
  assert.equal(
    blob("backend/cloud_save/functions/index.mjs"),
    "49126327ec25f8a404a8fe3494424416d6047be6",
  );
  assert.equal(
    blob("backend/cloud_save/production_approval_boundary.json"),
    "dcd92ca690dafca510385995e0f4d8a0dc46ba18",
  );
});
