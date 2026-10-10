import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const catalog = read('scripts/monetization/m7_rewarded_offer_catalog.gd');
const gateway = read('scripts/monetization/m7_rewarded_offer_gateway.gd');
const contract = JSON.parse(read('backend/monetization/m7a_rewarded_expansion_boundary.json'));
const existing = [
  'game_over_revive',
  'offline_cultivation_double',
  'pavilion_seal',
  'liveops_boss_hunt_double',
  'liveops_treasure_hunt_double',
];
const planned = [
  'daily_completion_cache', 'refinement_supply', 'victory_encore',
  'qi_focus', 'dao_choice_reroll',
];

test('M7A preserves all five shipping reward routes (including LiveOps)', () => {
  const shipping = catalog.match(/const SHIPPING_PLACEMENTS: Dictionary = \{([\s\S]*?)\n\}/);
  assert.ok(shipping, 'shipping catalog block exists');
  for (const id of existing) assert.match(shipping[1], new RegExp(`"${id}":`));
  assert.equal((shipping[1].match(/"owner":/g) ?? []).length, 5);
  assert.equal(contract.existing_shipping_placements, 5);
});

test('M7A future offers remain catalog-only and fail closed', () => {
  const future = catalog.match(/const PLANNED_DISABLED_PLACEMENTS: Dictionary = \{([\s\S]*?)\n\}/);
  assert.ok(future);
  for (const id of planned) assert.match(future[1], new RegExp(`"${id}":`));
  assert.match(catalog, /static func is_future_offer_enabled\(_placement: String\) -> bool:\n\t#[^\n]*\n\treturn false/);
  assert.match(gateway, /if not Catalog\.is_shipping_placement\(placement\):\n\t\treturn false/g);
  assert.doesNotMatch(gateway, /PavilionManager|RewardManager|grant_reward|grant_currency/);
  assert.equal(contract.new_reward_delivery_enabled, false);
  assert.equal(contract.new_ad_placement_enabled, false);
  assert.equal(contract.global_cap_implemented, false);
});

test('M7A does not relax historical monetization security or enable purchase', () => {
  assert.equal(contract.prior_m4_m5_m6_hash_locks_preserved, true);
  assert.equal(contract.admob_sdk_callback_equals_ssv, false);
  assert.equal(contract.server_side_reward_verification_implemented, false);
  assert.equal(contract.google_play_purchases_activated, false);
  assert.equal(contract.paid_purchase_production_gate_passed, false);
  assert.equal(contract.no_new_save_domain, true);
  assert.equal(contract.planned_total_choices, existing.length + planned.length);
  assert.equal(contract.target_optional_ad_global_daily_cap, 5);
});
