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
const boundary = JSON.parse(
  read("backend/monetization/m1b2_client_wiring_boundary.json"),
);

test("M1B2-B exposes only the fixed native purchase-token handoff", () => {
  assert.match(
    pavilion,
    /const PURCHASE_AUTHORITY_SINGLETON: String = "JadeMonetizationNativeBridge"/,
  );
  assert.match(
    pavilion,
    /Engine\.has_singleton\(PURCHASE_AUTHORITY_SINGLETON\)/,
  );
  assert.match(
    pavilion,
    /Engine\.get_singleton\(PURCHASE_AUTHORITY_SINGLETON\)/,
  );
  assert.match(
    pavilion,
    /purchase_authority_bridge\.call\(\s*"authorizePurchase",\s*_purchase_token\s*\)/s,
  );
  assert.doesNotMatch(
    pavilion,
    /purchase_authority_bridge\.call\(\s*"authorizePurchase",\s*(?:product_id|_order_id|account_binding)/s,
  );
});

test("raw Play token is forwarded transiently and never added to client state", () => {
  assert.match(
    pavilion,
    /func _on_billing_purchase_ready\(\s*product_id: String,\s*_purchase_token: String,\s*_order_id: String\s*\)/s,
  );
  assert.doesNotMatch(
    pavilion,
    /secure_purchase_(?:in_flight|pending)_token|pending_purchase_token/,
  );
  assert.doesNotMatch(
    pavilion,
    /state\[[^\]]*purchase_token[^\]]*\]\s*=/,
  );
  assert.equal(boundary.raw_purchase_token_local_storage_allowed, false);
});

test("only canonical native server grant JSON can reach the Pavilion grant gate", () => {
  assert.match(
    pavilion,
    /JSON\.parse_string\(grant_json\)/,
  );
  assert.match(
    pavilion,
    /_apply_server_authorized_iap_grant\(grant\)/,
  );
  assert.match(
    pavilion,
    /func _apply_server_authorized_iap_grant\(grant: Dictionary\) -> bool:/,
  );

  const handler = pavilion.match(
    /func _on_billing_purchase_ready\([\s\S]*?\n\nfunc _on_purchase_authority_result/,
  );
  assert.ok(handler);
  assert.doesNotMatch(handler[0], /_apply_server_authorized_iap_grant/);
  assert.doesNotMatch(handler[0], /celestial_jade/);
});

test("M1B2-B wiring remains fail-closed until a later activation gate", () => {
  assert.equal(boundary.state, "CLIENT_TRANSPORT_WIRED_FAIL_CLOSED");
  assert.equal(boundary.client_wiring_enabled, true);
  for (const key of [
    "production_activation_approved",
    "firebase_callable_runtime_approved",
    "native_purchase_bridge_enabled",
    "tracked_aar_integrated",
    "secure_purchase_authority_ready",
    "play_checkout_enabled",
    "purchase_recovery_enabled",
    "cloud_save_backend_modification_approved",
    "m1b2a_boundary_mutation_allowed",
  ]) assert.equal(boundary[key], false, `${key} must remain false`);

  assert.equal(boundary.fixed_native_singleton, "JadeMonetizationNativeBridge");
  assert.equal(boundary.fixed_native_method, "authorizePurchase");
  assert.equal(boundary.fixed_native_signal, "purchaseAuthorityResult");
  assert.deepEqual(boundary.request_keys, ["purchase_token"]);

  assert.match(pavilion, /var secure_purchase_authority_ready: bool = false/);
  assert.match(pavilion, /if not secure_purchase_authority_ready:/);
  assert.doesNotMatch(project, /JadeMonetizationNativeBridge/);

  assert.equal(m1b2a.state, "NATIVE_TRANSPORT_CANDIDATE_DISABLED");
  assert.equal(m1b2a.client_wiring_enabled, false);
  assert.equal(m1b2a.native_purchase_bridge_enabled, false);
});

test("billing and locked production boundaries stay fail-closed", () => {
  assert.doesNotMatch(billing, /func finalize_purchase/);
  assert.doesNotMatch(billing, /consume_purchase/);
  assert.doesNotMatch(billing, /acknowledge_purchase/);

  assert.equal(
    blob("project.godot"),
    "fe7f658b1e6d4305fad287ce705dac77e7e44a1b",
  );
  assert.equal(
    blob("backend/cloud_save/functions/index.mjs"),
    "49126327ec25f8a404a8fe3494424416d6047be6",
  );
  assert.equal(
    blob("backend/cloud_save/production_approval_boundary.json"),
    "dcd92ca690dafca510385995e0f4d8a0dc46ba18",
  );
  assert.equal(
    blob("backend/monetization/production_approval_boundary.json"),
    "02c249b931b10c21a90f8c03cc908e8fd0722602",
  );
  assert.equal(
    blob("backend/monetization/m1b_client_boundary.json"),
    "b6c4053078d4ed4688177a8fbc5160c9026a002f",
  );
  assert.equal(
    blob("backend/monetization/m1b2_native_transport_boundary.json"),
    "e532e899fc60b1d1f2934f2b5c391af7ef835b47",
  );
});
