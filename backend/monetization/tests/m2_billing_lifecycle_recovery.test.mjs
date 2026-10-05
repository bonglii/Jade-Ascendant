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
const nativeBridge = read(
  "backend/monetization/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/JadeMonetizationNativeBridge.kt",
);
const boundary = JSON.parse(
  read("backend/monetization/m2_billing_lifecycle_boundary.json"),
);

test("M2 serializes recovery without persisting or queueing raw Play tokens in GDScript state", () => {
  const runtimeState = pavilion.match(
    /var state: Dictionary[\s\S]*?\n\nfunc _ready\(\) -> void:/,
  );
  assert.ok(runtimeState);
  assert.match(
    runtimeState[0],
    /var secure_purchase_recovery_rescan_requested: bool = false/,
  );
  assert.doesNotMatch(
    runtimeState[0],
    /var\s+\w*(?:purchase_token|token_queue|pending_token|in_flight_token)\w*/i,
  );

  const purchase = pavilion.match(
    /func purchase_iap\([\s\S]*?\n\nfunc restore_iap_purchases/,
  );
  assert.ok(purchase);
  assert.match(
    purchase[0],
    /if not secure_purchase_in_flight_product_id\.is_empty\(\):[\s\S]*?"verification_in_progress"/,
  );

  const restore = pavilion.match(
    /func restore_iap_purchases\(\) -> void:[\s\S]*?\n\nfunc _connect_secure_purchase_transport/,
  );
  assert.ok(restore);
  assert.match(
    restore[0],
    /if not secure_purchase_in_flight_product_id\.is_empty\(\):[\s\S]*?secure_purchase_recovery_rescan_requested = true[\s\S]*?"recovery_deferred"/,
  );
});

test("M2 defers concurrent recovered purchases to a Google Play rescan instead of failing delivery", () => {
  const handler = pavilion.match(
    /func _on_billing_purchase_ready\([\s\S]*?\n\nfunc _on_purchase_authority_result/,
  );
  assert.ok(handler);
  assert.match(
    handler[0],
    /if not secure_purchase_in_flight_product_id\.is_empty\(\):[\s\S]*?secure_purchase_recovery_rescan_requested = true[\s\S]*?"verification_deferred"/,
  );
  const deferred = handler[0].match(
    /if not secure_purchase_in_flight_product_id\.is_empty\(\):[\s\S]*?\t\treturn/,
  );
  assert.ok(deferred);
  assert.doesNotMatch(deferred[0], /_fail_secure_purchase_delivery/);
  assert.match(
    pavilion,
    /func _continue_secure_purchase_recovery\(\) -> void:[\s\S]*?secure_purchase_recovery_rescan_requested = false[\s\S]*?call_deferred\("restore_iap_purchases"\)/,
  );
});

test("M2 accepts native results only for an active matching product and auto-rescans only after success", () => {
  const result = pavilion.match(
    /func _on_purchase_authority_result\([\s\S]*?\n\nfunc _fail_secure_purchase_delivery/,
  );
  assert.ok(result);
  assert.match(
    result[0],
    /if pending_product_id\.is_empty\(\):\s*secure_purchase_recovery_rescan_requested = false\s*return/s,
  );
  assert.match(
    result[0],
    /delivery_product_id\.is_empty\(\)\s*or delivery_product_id != pending_product_id/s,
  );
  assert.match(
    result[0],
    /if not success:\s*_cancel_secure_purchase_recovery_rescan\(\)/s,
  );
  assert.match(
    result[0],
    /if not \(parsed is Dictionary\):\s*_cancel_secure_purchase_recovery_rescan\(\)/s,
  );
  assert.match(
    result[0],
    /if not _apply_server_authorized_iap_grant\(grant\):\s*_cancel_secure_purchase_recovery_rescan\(\)/s,
  );
  assert.match(
    result[0],
    /purchase_delivery_finished\.emit\(\s*delivery_product_id,\s*true,[\s\S]*?\)\s*_continue_secure_purchase_recovery\(\)/s,
  );
});

test("M2 lifecycle boundary stays production fail-closed", () => {
  assert.equal(boundary.state, "BILLING_LIFECYCLE_RECOVERY_HARDENED_FAIL_CLOSED");
  assert.equal(boundary.base_locked_sha, "022f819c09d2e52510a6f897fcec0d6f96125fd6");
  assert.equal(boundary.single_authority_request_in_flight, true);
  assert.equal(boundary.deferred_recovery_uses_play_rescan, true);
  assert.equal(boundary.auto_rescan_after_success_only, true);
  assert.equal(boundary.unsolicited_native_result_grant_allowed, false);
  assert.equal(boundary.server_grant_product_must_match_pending_product, true);
  assert.equal(boundary.raw_token_queue_allowed, false);
  for (const key of [
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
    "raw_purchase_token_persistence_allowed",
    "cloud_save_backend_modification_approved",
    "prior_locked_boundary_mutation_allowed",
  ]) assert.equal(boundary[key], false, `${key} must remain false`);

  assert.match(
    pavilion,
    /const SECURE_PURCHASE_ACTIVATION_APPROVED: bool = false/,
  );
  assert.doesNotMatch(project, /JadeMonetizationNativeBridge/);
});

test("M2 preserves locked billing, native transport, M1B and Cloud boundaries", () => {
  assert.equal(blob("scripts/monetization/google_play_billing_provider.gd"), "8a7723d5c86836d0a4b20158b2f8783b38458f20");
  assert.equal(
    blob("backend/monetization/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/JadeMonetizationNativeBridge.kt"),
    "0318d9d3bf088a095d7d4cb4f3091cf3a9eae527",
  );
  assert.equal(blob("backend/monetization/m1b2_authority_recovery_gate.json"), "baccbd02a35a3672482f25cbf5d333f1dd2174fc");
  assert.equal(blob("backend/monetization/m1b2_client_wiring_boundary.json"), "84778dab0457eb545530e1c2eae13eb3f37a6882");
  assert.equal(blob("backend/monetization/m1b2_native_transport_boundary.json"), "e532e899fc60b1d1f2934f2b5c391af7ef835b47");
  assert.equal(blob("backend/monetization/m1b_client_boundary.json"), "b6c4053078d4ed4688177a8fbc5160c9026a002f");
  assert.equal(blob("backend/monetization/production_approval_boundary.json"), "02c249b931b10c21a90f8c03cc908e8fd0722602");
  assert.equal(blob("project.godot"), "fe7f658b1e6d4305fad287ce705dac77e7e44a1b");
  assert.equal(blob("backend/cloud_save/functions/index.mjs"), "49126327ec25f8a404a8fe3494424416d6047be6");
  assert.equal(blob("backend/cloud_save/production_approval_boundary.json"), "dcd92ca690dafca510385995e0f4d8a0dc46ba18");
  assert.doesNotMatch(billing, /func finalize_purchase|consume_purchase|acknowledge_purchase/);
  assert.match(nativeBridge, /private val busy = AtomicBoolean\(false\)/);
});
