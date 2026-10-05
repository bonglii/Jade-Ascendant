import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
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

const pavilion = read("scripts/managers/pavilion_manager.gd");
const billing = read("scripts/monetization/google_play_billing_provider.gd");
const project = read("project.godot");
const m1b2a = JSON.parse(
  read("backend/monetization/m1b2_native_transport_boundary.json"),
);
const m1b2b = JSON.parse(
  read("backend/monetization/m1b2_client_wiring_boundary.json"),
);
const boundary = JSON.parse(
  read("backend/monetization/m1b2_authority_recovery_gate.json"),
);

test("M1B2-C authority readiness is an explicit fail-closed conjunction", () => {
  assert.match(
    pavilion,
    /const SECURE_PURCHASE_ACTIVATION_APPROVED: bool = false/,
  );
  const compute = pavilion.match(
    /func _compute_secure_purchase_authority_ready\([\s\S]*?\n\nfunc _connect_secure_purchase_identity/,
  );
  assert.ok(compute);
  assert.match(compute[0], /SECURE_PURCHASE_ACTIVATION_APPROVED/);
  assert.match(compute[0], /not account_binding\.is_empty\(\)/);
  assert.match(compute[0], /_is_secure_purchase_transport_configured\(\)/);
  assert.match(
    pavilion,
    /purchase_authority_bridge\.call\(\s*"isSecurePurchaseTransportConfigured"\s*\)/s,
  );
  assert.match(
    pavilion,
    /func _refresh_secure_purchase_context\(\) -> bool:\s*secure_purchase_authority_ready = false/s,
  );
});

test("purchase recovery rechecks runtime readiness before querying Google Play", () => {
  const restore = pavilion.match(
    /func restore_iap_purchases\(\) -> void:[\s\S]*?\n\nfunc _connect_secure_purchase_transport/,
  );
  assert.ok(restore);
  assert.match(restore[0], /_refresh_secure_purchase_context\(\)/);
  assert.match(restore[0], /if not secure_purchase_authority_ready:/);
  assert.match(restore[0], /billing_provider\.call\("restore_purchases"\)/);
  assert.match(
    billing,
    /if secure_authority_ready and _client_ready\(\):\s*call_deferred\("restore_purchases"\)/s,
  );
  assert.match(
    billing,
    /func _on_connected\(\) -> void:[\s\S]*?if secure_authority_ready:\s*restore_purchases\(\)/,
  );
});

test("M1B2-C gate is wired but production activation remains closed", () => {
  assert.equal(boundary.state, "AUTHORITY_READINESS_RECOVERY_GATE_FAIL_CLOSED");
  assert.equal(boundary.base_locked_sha, "f884d6b1b7a456dc645fc0e3075ff6cc982b02ff");
  assert.equal(boundary.readiness_gate_wired, true);
  assert.deepEqual(boundary.readiness_requires, [
    "explicit_activation_approval",
    "firebase_account_binding",
    "fixed_native_transport",
    "native_app_check_configuration",
  ]);
  for (const key of [
    "explicit_activation_approval",
    "production_activation_approved",
    "firebase_callable_runtime_approved",
    "native_purchase_bridge_enabled",
    "tracked_aar_integrated",
    "secure_purchase_authority_ready",
    "play_checkout_enabled",
    "purchase_recovery_enabled",
    "client_consume_allowed",
    "client_acknowledge_allowed",
    "client_finalize_allowed",
    "raw_purchase_token_local_storage_allowed",
    "cloud_save_backend_modification_approved",
    "prior_boundary_mutation_allowed",
  ]) assert.equal(boundary[key], false, `${key} must remain false`);
  assert.equal(boundary.recovery_rechecks_runtime_readiness, true);
  assert.equal(boundary.recovery_requires_secure_authority, true);
  assert.doesNotMatch(project, /JadeMonetizationNativeBridge/);
});

test("M1B2-A/B, billing, native bridge and production locks are immutable", () => {
  assert.equal(m1b2a.state, "NATIVE_TRANSPORT_CANDIDATE_DISABLED");
  assert.equal(m1b2b.state, "CLIENT_TRANSPORT_WIRED_FAIL_CLOSED");
  assert.equal(blob("project.godot"), "fe7f658b1e6d4305fad287ce705dac77e7e44a1b");
  assert.equal(blob("backend/cloud_save/functions/index.mjs"), "49126327ec25f8a404a8fe3494424416d6047be6");
  assert.equal(blob("backend/cloud_save/production_approval_boundary.json"), "dcd92ca690dafca510385995e0f4d8a0dc46ba18");
  assert.equal(blob("backend/cloud_save/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/cloudbridge/JadeCloudNativeBridge.kt"), "41d29134205032f50b7886305b2020cf5e287afe");
  assert.equal(blob("backend/monetization/production_approval_boundary.json"), "02c249b931b10c21a90f8c03cc908e8fd0722602");
  assert.equal(blob("backend/monetization/m1b_client_boundary.json"), "b6c4053078d4ed4688177a8fbc5160c9026a002f");
  assert.equal(blob("backend/monetization/m1b2_native_transport_boundary.json"), "e532e899fc60b1d1f2934f2b5c391af7ef835b47");
  assert.equal(blob("backend/monetization/m1b2_client_wiring_boundary.json"), "84778dab0457eb545530e1c2eae13eb3f37a6882");
  assert.equal(blob("scripts/monetization/google_play_billing_provider.gd"), "8a7723d5c86836d0a4b20158b2f8783b38458f20");
  assert.equal(blob("backend/monetization/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/JadeMonetizationNativeBridge.kt"), "0318d9d3bf088a095d7d4cb4f3091cf3a9eae527");
  assert.doesNotMatch(billing, /func finalize_purchase|consume_purchase|acknowledge_purchase/);
});
