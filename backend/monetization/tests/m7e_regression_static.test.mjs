import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const method = (src, name) => {
  const match = src.match(new RegExp(`^func ${name}\\([\\s\\S]*?(?=^func |^static func |$(?![\\s\\S]))`, 'm'));
  assert.ok(match, `Missing method ${name}`);
  return match[0];
};
const catalog = read('scripts/monetization/m7_rewarded_offer_catalog.gd');
const gate = read('scripts/monetization/m7_rewarded_offer_gateway.gd');
const manager = read('scripts/managers/monetization_manager.gd');
const daily = read('scripts/managers/daily_quest_manager.gd');
const m7b = read('scripts/monetization/m7b_daily_reward_bridge.gd');
const m7c = read('scripts/monetization/m7c_victory_encore_bridge.gd');
const m7c2 = read('scripts/monetization/m7c2_qi_focus_bridge.gd');
const level = read('scripts/ui/level_up.gd');
const journey = read('scripts/managers/journey_manager.gd');
const player = read('scripts/player/player_1.gd');
const checkpoint = read('scripts/managers/checkpoint_manager.gd');
const lock = JSON.parse(read('backend/monetization/m6_final_monetization_lock.json'));

const legacy = ['game_over_revive', 'offline_cultivation_double', 'pavilion_seal',
  'liveops_boss_hunt_double', 'liveops_treasure_hunt_double'];
const added = ['daily_completion_cache', 'refinement_supply', 'victory_encore',
  'qi_focus', 'dao_choice_reroll'];

test('M7E inventory: all five legacy and five new placement identifiers present', () => {
  for (const id of [...legacy, ...added]) assert.ok(catalog.includes(`"${id}"`), id);
  assert.match(catalog, /GLOBAL_OPTIONAL_AD_DAILY_CAP_TARGET:\s*int\s*=\s*5/);
  assert.match(gate, /Catalog\.is_shipping_placement\(placement\)/);
});

test('M7E: SDK earned delivery is not confused with dismissal or button press', () => {
  for (const [id, source] of [
    ['daily', m7b], ['victory', m7c], ['focus', m7c2], ['reroll', level]
  ]) {
    assert.match(source, /verified_rewarded_completed/, `${id} missing SDK callback`);
    assert.match(source, /rewarded_request_finished/, `${id} missing cancel callback`);
    assert.match(source, /active_grant_id/, `${id} missing nonce snapshot`);
  }
  assert.doesNotMatch(method(m7b, '_on_ad_finished'), /m7b_commit_sdk_reward/);
  assert.doesNotMatch(method(m7c2, '_on_ad_finished'), /m7c2_commit_sdk_reward/);
  assert.doesNotMatch(method(level, '_m7d_on_ad_finished'), /m7d_commit_sdk_reroll/);
});

test('M7E: M7B daily owner uses atomic progression/inventory and receipt checkpoint', () => {
  const grant = method(daily, 'm7b_commit_sdk_reward');
  assert.match(grant, /m7b_processed_grant_ids/);
  assert.match(grant, /m7b_claimed_placement_ids/);
  assert.match(grant, /RewardManager\.grant_reward/);
  assert.match(grant, /additional_domains|\{"daily_quests"|daily_quests/);
  assert.match(method(m7b, '_on_sdk_reward'), /policy_store\.call\("load_state"\)/);
});

test('M7E: Victory Encore is repeat-clear only, 50% bonus capped at 100', () => {
  const armed = method(m7c, '_on_reward_granted');
  assert.match(armed, /SOURCE_STAGE_CLEAR/);
  assert.match(armed, /_repeat_clear/);
  assert.match(armed, /get_stage_clear_reward/);
  assert.match(armed, /0\.5/);
  assert.match(m7c, /MAX_BONUS_STONES:\s*int\s*=\s*100/);
  assert.match(method(m7c, '_commit_reward'), /RewardManager\.grant_reward/);
  assert.match(method(m7c, '_commit_reward'), /m7b_processed_grant_ids/);
});

test('M7E: Qi Focus consumes an entitlement once and checkpoint carries run effect', () => {
  assert.match(method(daily, 'm7c2_commit_sdk_reward'), /m7b_processed_grant_ids/);
  assert.match(method(daily, 'm7c2_consume_for_new_run'), /m7c2_pending_focus/);
  assert.match(player, /m7c2_qi_focus_active/);
  assert.match(checkpoint, /m7c2_qi_focus_active/);
  assert.match(m7c2, /get_offer_status/);
});

test('M7E: Dao Reroll keeps original upgrade authority and persistent per-run limit', () => {
  assert.match(method(level, '_m7d_find_alternative_choices'), /is_upgrade_available/);
  assert.doesNotMatch(method(level, '_m7d_on_sdk_reward'), /apply_upgrade\(/);
  assert.match(method(daily, 'm7d_commit_sdk_reroll'), /m7d_used_run_id/);
  assert.match(journey, /m7d_run_id/);
  assert.match(method(level, '_m7d_on_sdk_reward'), /policy_store\.call\("load_state"\)/);
});

test('M7E: locked paid-purchase features remain disabled', () => {
  for (const key of [
    'paid_purchase_production_gate_passed', 'production_backend_deployment_approved',
    'purchase_activation_approved', 'play_checkout_enabled', 'client_consume_allowed'
  ]) assert.equal(lock[key], false, `${key} must remain false`);
  assert.match(manager, /func purchase\(_product_id: String\) -> bool:/);
});

test('M7E: audit deliberately does not claim the global cap is shipping', () => {
  assert.match(catalog, /design target, not an active daily cap/);
  const status = method(manager, 'rewarded_available');
  assert.match(status, /placement_counts\.get\(placement/);
  // This checks scope, not that global five-per-day is ready; release scanner
  // independently marks old-path global-cap enforcement as HOLD.
  assert.match(read('tools/qa/m7e_readiness_scan.mjs'), /GLOBAL_DAILY_CAP_NOT_UNIVERSAL/);
});
