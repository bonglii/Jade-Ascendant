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

const treasury = read("scripts/ui/liveops/celestial_treasury_screen.gd");
const billing = read("scripts/monetization/google_play_billing_provider.gd");
const pavilion = read("scripts/managers/pavilion_manager.gd");
const economy = read("scripts/data/economy_catalog.gd");
const releaseDoc = read("release/GOOGLE_PLAY_IAP_SETUP.md");
const project = read("project.godot");
const boundary = JSON.parse(
  read("backend/monetization/m3_treasury_production_contract.json"),
);

const activeIds = [
  "jade_pouch_100",
  "jade_satchel_550",
  "jade_casket_1200",
  "jade_vault_2500",
  "jade_treasury_6500",
  "jade_ascendant_14000",
];

test("M3 Treasury presents exactly the six active Celestial Jade packs", () => {
  const offerBlock = treasury.match(
    /const OFFER_IDS: Array\[String\] = \[[\s\S]*?\n\]/,
  );
  assert.ok(offerBlock);
  for (const id of activeIds) {
    assert.match(offerBlock[0], new RegExp(`"${id}"`));
  }
  assert.equal(
    [...offerBlock[0].matchAll(/"([^"]+)"/g)].map(match => match[1]).length,
    6,
  );
  assert.doesNotMatch(offerBlock[0], /starter_support_pack|monthly_jade_blessing/);

  for (const id of activeIds) {
    assert.match(economy, new RegExp(`"${id}"`));
  }
});

test("M3 Treasury can only display and checkout with live positive Google Play prices", () => {
  const price = treasury.match(
    /func _available_formatted_price\([\s\S]*?\n\nfunc _apply_play_price_order/,
  );
  assert.ok(price);
  assert.match(price[0], /if not _billing_ready/);
  assert.match(price[0], /PavilionManager\.is_iap_purchase_supported\(product_id\)/);
  assert.match(price[0], /price_amount_micros", 0\)\) <= 0/);
  assert.match(price[0], /formatted_price/);

  const purchase = treasury.match(
    /func _request_purchase\(\) -> void:[\s\S]*?\n\nfunc _restore_purchases/,
  );
  assert.ok(purchase);
  assert.match(
    purchase[0],
    /if _available_formatted_price\(_selected_id\)\.is_empty\(\):/,
  );
  assert.match(purchase[0], /No purchase started/);
  assert.match(purchase[0], /PavilionManager\.purchase_iap\(_active_purchase_id\)/);
});

test("M3 Treasury recognizes secure lifecycle states and never stays busy after delivery", () => {
  const lifecycle = treasury.match(
    /func _on_purchase_state_changed\([\s\S]*?\n\nfunc _on_purchase_delivery_finished/,
  );
  assert.ok(lifecycle);
  for (const status of [
    "opening",
    "pending",
    "verification_required",
    "verification_in_progress",
    "verification_deferred",
    "recovery_deferred",
    "cancelled",
    "failed",
    "launch_failed",
    "unavailable",
    "unsupported",
    "price_unavailable",
    "invalid",
    "identity_preparing",
    "identity_unavailable",
    "secure_verification_unavailable",
    "secure_verification_failed",
    "delivered",
  ]) {
    assert.match(lifecycle[0], new RegExp(`"${status}"`));
  }
  assert.doesNotMatch(lifecycle[0], /"granting"|"completed"|"save_failed"|"finalization_failed"/);

  const delivery = treasury.match(
    /func _on_purchase_delivery_finished\([\s\S]*?\n\nfunc _on_entitlements_changed/,
  );
  assert.ok(delivery);
  assert.match(delivery[0], /_purchase_busy = false/);
  assert.match(delivery[0], /_active_purchase_id = ""/);
  assert.doesNotMatch(
    delivery[0],
    /if not success:[\s\S]*?_purchase_busy = false/,
  );
});

test("M3 Treasury remains presentation-only and documents server authority truthfully", () => {
  assert.doesNotMatch(
    treasury,
    /purchase_token|consume_purchase|acknowledge_purchase|finalize_purchase|apply_verified_economy_grant|_apply_server_authorized_iap_grant/,
  );
  assert.match(releaseDoc, /server authority verifies package, product, purchase state and account/i);
  assert.match(releaseDoc, /consumes[\s\S]*before exposing a client grant/i);
  assert.match(releaseDoc, /client does NOT consume, acknowledge, finalize/i);
  assert.match(releaseDoc, /not persisted in GDScript\/save state/i);
  assert.doesNotMatch(
    releaseDoc,
    /Jade packs consume only after the game save succeeds|trusts purchase state\/token returned by the Google Play Billing client/i,
  );
});

test("M3 production contract stays fail-closed", () => {
  assert.equal(boundary.state, "TREASURY_PRODUCTION_CONTRACT_FAIL_CLOSED");
  assert.equal(boundary.base_locked_sha, "716b0d4353a347ef2d99be26c1dddbc2d489fae3");
  assert.deepEqual(boundary.active_internal_product_ids, activeIds);
  assert.equal(boundary.treasury_presentation_only, true);
  assert.equal(boundary.localized_price_source, "google_play_product_details");
  assert.equal(boundary.checkout_requires_live_positive_price, true);
  assert.equal(boundary.server_consume_before_client_grant_required, true);
  assert.equal(boundary.delivery_terminal_clears_ui_busy, true);
  assert.equal(boundary.secure_lifecycle_statuses_recognized, true);

  for (const key of [
    "purchase_token_visible_to_treasury",
    "client_paid_currency_grant_authority",
    "client_consume_allowed",
    "client_acknowledge_allowed",
    "client_finalize_allowed",
    "starter_support_pack_active",
    "monthly_jade_blessing_active",
    "production_activation_approved",
    "firebase_callable_runtime_approved",
    "native_purchase_bridge_enabled",
    "tracked_aar_integrated",
    "secure_purchase_authority_ready",
    "play_checkout_enabled",
    "purchase_recovery_enabled",
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

test("M3 preserves M2 authority, billing, native transport and Cloud locks", () => {
  assert.equal(blob("scripts/managers/pavilion_manager.gd"), "b1133f887f836a74a69e188208c92e9338dce17e");
  assert.equal(blob("scripts/monetization/google_play_billing_provider.gd"), "8a7723d5c86836d0a4b20158b2f8783b38458f20");
  assert.equal(blob("scripts/data/economy_catalog.gd"), "2928930c8993af8a17eeaa6666b55ce8f23ebbdb");
  assert.equal(blob("backend/monetization/m2_billing_lifecycle_boundary.json"), "037988a195867afd397a9b9e51afb86902a6c45f");
  assert.equal(blob("backend/monetization/m1b2_authority_recovery_gate.json"), "baccbd02a35a3672482f25cbf5d333f1dd2174fc");
  assert.equal(blob("backend/monetization/production_approval_boundary.json"), "02c249b931b10c21a90f8c03cc908e8fd0722602");
  assert.equal(blob("backend/monetization/src/purchase_authority.mjs"), "13b0b76b2056740bd120dc2e1a8fda8aa65f1d86");
  assert.equal(
    blob("backend/monetization/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/JadeMonetizationNativeBridge.kt"),
    "0318d9d3bf088a095d7d4cb4f3091cf3a9eae527",
  );
  assert.equal(blob("project.godot"), "fe7f658b1e6d4305fad287ce705dac77e7e44a1b");
  assert.equal(blob("backend/cloud_save/functions/index.mjs"), "49126327ec25f8a404a8fe3494424416d6047be6");
  assert.equal(blob("backend/cloud_save/production_approval_boundary.json"), "dcd92ca690dafca510385995e0f4d8a0dc46ba18");
  assert.doesNotMatch(billing, /func finalize_purchase|consume_purchase|acknowledge_purchase/);
});
