import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const read = path => readFileSync(resolve(root, path), "utf8");
const blob = path => execFileSync(
  "git",
  ["hash-object", path],
  { cwd: root, encoding: "utf8" },
).trim();
const count = (source, needle) => source.split(needle).length - 1;

const cloud = read(".github/workflows/cloud-production-safety.yml");
const godot = read(".github/workflows/godot-smoke-qa.yml");
const monetization = read(".github/workflows/monetization-native-bridge-qa.yml");
const releaseDoc = read("release/GOOGLE_PLAY_IAP_SETUP.md");
const m6 = JSON.parse(
  read("backend/monetization/m6_final_monetization_lock.json"),
);
const pavilion = read("scripts/managers/pavilion_manager.gd");
const project = read("project.godot");

test("M6 pins and verifies all four critical CI checkouts against github.sha", () => {
  const all = cloud + godot + monetization;
  assert.equal(count(all, "uses: actions/checkout@v4"), 4);
  assert.equal(count(all, "ref: ${{ github.sha }}"), 4);
  assert.equal(count(all, "Verify exact CI revision"), 4);
  assert.equal(count(all, "EXACT_SHA_CI_PASS"), 4);
  assert.match(all, /git rev-parse HEAD/);
  assert.match(all, /GITHUB_SHA/);
  assert.match(
    monetization,
    /backend\/monetization\/tests\/m6_final_monetization_lock\.test\.mjs/,
  );
});

test("M6 final lock requires its own exact-SHA CI while commercial purchase remains blocked", () => {
  assert.equal(m6.state, "FINAL_MONETIZATION_LOCK_FAIL_CLOSED");
  assert.equal(
    m6.base_locked_sha,
    "bf14a8187586a32019d529cfb14e7de9bbe50932",
  );
  assert.equal(m6.m5_exact_sha_ci_evidence.all_completed_success, true);
  assert.equal(m6.required_exact_sha_job_count, 4);
  assert.equal(m6.explicit_checkout_ref_github_sha_required, true);
  assert.equal(m6.head_equals_github_sha_assertion_required, true);
  assert.equal(
    m6.current_commit_exact_sha_ci_green_required_to_finalize_lock,
    true,
  );
  assert.equal(m6.rewarded_ads_code_gate_passed, true);
  assert.equal(m6.paid_purchase_security_contract_gate_passed, true);
  assert.equal(m6.paid_purchase_production_gate_passed, false);
  assert.equal(m6.full_commercial_monetization_release_gate_passed, false);

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
    "client_consume_allowed",
    "client_acknowledge_allowed",
    "client_finalize_allowed",
    "raw_purchase_token_persistence_allowed",
    "cloud_save_backend_modification_approved",
    "runtime_monetization_modification_allowed_in_m6",
    "prior_locked_boundary_mutation_allowed",
  ]) {
    assert.equal(m6[key], false, `${key} must remain false`);
  }

  assert.match(
    pavilion,
    /const SECURE_PURCHASE_ACTIVATION_APPROVED: bool = false/,
  );
  assert.doesNotMatch(project, /JadeMonetizationNativeBridge/);
  assert.equal(
    existsSync(resolve(root, "addons/JadeMonetizationNativeBridge")),
    false,
  );
});

test("M6 preserves locked runtime, prior release gate and Cloud authority blobs", () => {
  const expected = {
    "backend/monetization/m5_monetization_release_gate.json":
      "d93bf61c9426de2d86b01215eca79fba1453cc3e",
    "backend/monetization/m4_admob_ump_production_boundary.json":
      "8593338491da99d95d3c610858fdd6aeec617986",
    "backend/monetization/m3_treasury_production_contract.json":
      "4e5b7bbecb1662c833edff6546c33bd20b5b1338",
    "backend/monetization/m2_billing_lifecycle_boundary.json":
      "037988a195867afd397a9b9e51afb86902a6c45f",
    "backend/monetization/m1b2_authority_recovery_gate.json":
      "baccbd02a35a3672482f25cbf5d333f1dd2174fc",
    "backend/monetization/production_approval_boundary.json":
      "02c249b931b10c21a90f8c03cc908e8fd0722602",
    "backend/monetization/src/purchase_authority.mjs":
      "13b0b76b2056740bd120dc2e1a8fda8aa65f1d86",
    "scripts/managers/pavilion_manager.gd":
      "b1133f887f836a74a69e188208c92e9338dce17e",
    "scripts/monetization/google_play_billing_provider.gd":
      "8a7723d5c86836d0a4b20158b2f8783b38458f20",
    "scripts/monetization/admob_provider.gd":
      "a2d72a5f6d358157d8b30677183dcaee3abc8512",
    "project.godot":
      "fe7f658b1e6d4305fad287ce705dac77e7e44a1b",
    "export_presets.cfg":
      "09fa1ade5c26a79e9a82d5a36c114161bd6f83d6",
    "backend/cloud_save/functions/index.mjs":
      "49126327ec25f8a404a8fe3494424416d6047be6",
    "backend/cloud_save/production_approval_boundary.json":
      "dcd92ca690dafca510385995e0f4d8a0dc46ba18",
  };
  for (const [path, expectedHash] of Object.entries(expected)) {
    assert.equal(blob(path), expectedHash, path);
  }
});

test("M6 docs distinguish final engineering lock from blocked commercial activation", () => {
  assert.match(
    releaseDoc,
    /## M6 exact-SHA CI and final monetization lock/,
  );
  assert.match(
    releaseDoc,
    /Monetization engineering\/security lock: \*\*FINAL\*\*/,
  );
  assert.match(
    releaseDoc,
    /Paid purchase production gate: \*\*BLOCKED\*\*/,
  );
  assert.match(
    releaseDoc,
    /Full commercial monetization release gate: \*\*BLOCKED\*\*/,
  );
});
