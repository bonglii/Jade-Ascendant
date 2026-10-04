import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../..");
const read = path => readFileSync(resolve(root, path), "utf8");

const account = read("scripts/managers/google_account_manager.gd");
const billing = read("scripts/monetization/google_play_billing_provider.gd");
const pavilion = read("scripts/managers/pavilion_manager.gd");
const boundary = JSON.parse(
  read("backend/monetization/m1b_client_boundary.json"),
);

test("Guest purchase identity is anonymous Firebase auth while visible UI remains Guest", () => {
  assert.match(account, /sign_in_anonymously/);
  assert.match(account, /get_monetization_account_binding/);
  assert.match(account, /Guest progress stays on this device/);
  assert.doesNotMatch(account, /"uid"\s*:\s*_firebase_uid/);
});

test("anonymous Guest links to Google instead of replacing the Firebase user", () => {
  assert.match(account, /link_anonymous_with_google/);
  assert.match(account, /linked_uid != expected_uid/);
});

test("Google Play account attribution uses only a SHA-256 Firebase UID binding", () => {
  assert.match(account, /HashingContext\.HASH_SHA256/);
  assert.match(billing, /set_obfuscated_account_id/);
  assert.match(billing, /_is_sha256_hex\(secure_account_binding\)/);
});

test("billing provider supports exactly the six server-approved consumables", () => {
  const match = billing.match(
    /const SECURE_CONSUMABLE_PRODUCT_IDS: Array = \[([\s\S]*?)\n\]/,
  );
  assert.ok(match);
  const ids = [...match[1].matchAll(/"([^"]+)"/g)].map(x => x[1]);
  assert.deepEqual(ids, [
    "jade_pouch_100",
    "jade_satchel_550",
    "jade_casket_1200",
    "jade_vault_2500",
    "jade_treasury_6500",
    "jade_ascendant_14000",
  ]);
});

test("client billing provider cannot consume, acknowledge or finalize a purchase", () => {
  assert.doesNotMatch(billing, /func finalize_purchase/);
  assert.doesNotMatch(billing, /consume_purchase/);
  assert.doesNotMatch(billing, /acknowledge_purchase/);
  assert.match(billing, /client_finalization_enabled": false/);
});

test("Pavilion no longer turns a Play token into local Jade", () => {
  assert.doesNotMatch(pavilion, /func apply_verified_iap_purchase/);
  assert.doesNotMatch(
    pavilion,
    /"iap:" \+ product_id \+ ":" \+ transaction_id/,
  );
  assert.match(pavilion, /_apply_server_authorized_iap_grant/);
  assert.match(pavilion, /_purchase_token: String/);
});

test("paid IAP replay ledger is separate, exact and legacy raw tokens are scrubbed", () => {
  assert.match(pavilion, /"processed_iap_grant_ids": \[\]/);
  assert.match(pavilion, /Paid IAP replay protection is exact and intentionally not truncated/);
  assert.match(pavilion, /"iapv1:" \+ _sha256_hex\(purchase_token\)/);
  assert.doesNotMatch(
    pavilion,
    /while processed_iap\.size\(\) >/,
  );
});

test("M1B-1 remains fail-closed until the secure native authority transport exists", () => {
  assert.equal(boundary.state, "CLIENT_FAIL_CLOSED_PRETRANSPORT");
  assert.equal(boundary.production_activation_approved, false);
  assert.equal(boundary.firebase_callable_runtime_approved, false);
  assert.equal(boundary.native_purchase_bridge_enabled, false);
  assert.equal(boundary.secure_purchase_authority_ready, false);
  assert.equal(boundary.play_checkout_allowed_without_secure_authority, false);
  assert.match(pavilion, /var secure_purchase_authority_ready: bool = false/);
  assert.match(pavilion, /if not secure_purchase_authority_ready:/);
});
