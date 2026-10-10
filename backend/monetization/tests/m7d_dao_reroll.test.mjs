import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
const root = process.cwd();
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
const level = read('scripts/ui/level_up.gd');
const journey = read('scripts/managers/journey_manager.gd');
const daily = read('scripts/managers/daily_quest_manager.gd');
const lock = JSON.parse(read('backend/monetization/m7d_dao_choice_reroll_contract.json'));

function method(src, name) {
  const pattern = new RegExp(`^func ${name}\\([\\s\\S]*?(?=^func |^static func |$(?![\\s\\S]))`, 'm');
  const m = src.match(pattern);
  assert.ok(m, `Missing method ${name}`);
  return m[0];
}

test('M7D preserves one voluntary placement and keeps purchases/provider untouched', () => {
  assert.equal(lock.placement, 'dao_choice_reroll');
  assert.equal(lock.per_run_limit, 1);
  assert.equal(lock.per_local_day_limit, 1);
  assert.equal(lock.permanent_currency_granted, false);
  assert.equal(lock.new_save_domain, false);
  assert.equal(lock.new_autoload, false);
  assert.equal(lock.iaps_or_historical_monetiation_provider_mutated, false);
});

test('run nonce generated only at new run, persisted in existing journey domain', () => {
  const begin = method(journey, 'begin_selected_stage');
  assert.match(begin, /_m7d_new_run_nonce\(\)/);
  assert.match(journey, /m7d_run_id\s*=\s*str\(save_data\.get\("m7d_run_id", ""\)\)/);
  assert.match(journey, /"m7d_run_id": m7d_run_id/);
  assert.match(method(journey, '_m7d_new_run_nonce'), /generate_random_bytes\(16\)/);
  assert.doesNotMatch(method(journey, 'restore_active_run'), /_m7d_new_run_nonce/);
});

test('LevelUp offers reroll only for three currently pending eligible choices', () => {
  const find = method(level, '_m7d_find_alternative_choices');
  assert.match(find, /is_upgrade_available\(upgrade_id\)/);
  assert.match(find, /if candidates\.is_empty\(\)/);
  assert.match(find, /selected\.size\(\) != option_count/);
  const received = method(level, '_m7d_on_sdk_reward');
  assert.match(received, /current_upgrades != _m7d_original_choices/);
  assert.match(received, /_m7d_future_choices/);
  assert.match(received, /update_buttons\(\)/);
  assert.doesNotMatch(received, /apply_upgrade\(/);
});

test('request only starts from visible paused level-up and locks selection while ad runs', () => {
  const request = method(level, '_m7d_on_pressed');
  assert.match(request, /not visible or not get_tree\(\)\.paused or selection_locked/);
  assert.match(request, /MonetizationManager\.show_rewarded\("dao_choice_reroll"\)/);
  assert.match(request, /selection_locked = true/);
  const select = method(level, '_on_upgrade_button_pressed');
  assert.match(select, /if selection_locked:/);
});

test('no reroll grant via dismissal, empty nonce, changed day, legacy run, replay or save failure', () => {
  const earned = method(level, '_m7d_on_sdk_reward');
  assert.match(earned, /grant_id != _m7d_request_grant_id/);
  assert.match(earned, /last_reward_unix/);
  const dismissed = method(level, '_m7d_on_ad_finished');
  assert.doesNotMatch(dismissed, /m7d_commit_sdk_reroll/);
  const commit = method(daily, 'm7d_commit_sdk_reroll');
  assert.match(commit, /expected_day != active_date_key/);
  assert.match(commit, /m7d_used_run_id == expected_run_id/);
  assert.match(commit, /grant_id in m7b_processed_grant_ids/);
  assert.match(commit, /_m7d_is_run_id_durable\(expected_run_id\)/);
  assert.match(commit, /SaveManager\.write_save_data\("daily_quests", next_daily\)/);
});

test('run claim and receipt use one persistent save before any visual reroll', () => {
  const commit = method(daily, 'm7d_commit_sdk_reroll');
  assert.match(commit, /next_daily\["m7d_used_run_id"\] = expected_run_id/);
  assert.match(commit, /next_daily\["m7b_claimed_placement_ids"\] = next_claims/);
  assert.match(commit, /next_daily\["m7b_processed_grant_ids"\] = next_grants/);
  assert.ok(commit.indexOf('SaveManager.write_save_data') < commit.indexOf('m7d_used_run_id = expected_run_id'));
  const levelCallback = method(level, '_m7d_on_sdk_reward');
  assert.ok(levelCallback.indexOf('m7d_commit_sdk_reroll') < levelCallback.indexOf('current_upgrades = _m7d_future_choices.duplicate()'));
});

test('per-run marker survives next calendar day while daily claim resets normally', () => {
  assert.match(daily, /"m7d_used_run_id": m7d_used_run_id/);
  assert.match(daily, /m7d_used_run_id = str\(save_data\.get\("m7d_used_run_id", ""\)\)/);
  const reset = method(daily, '_apply_daily_reset_if_needed');
  assert.doesNotMatch(reset, /m7d_used_run_id\s*=/);
  const status = method(daily, 'm7d_get_offer_status');
  assert.match(status, /m7d_used_run_id == run_id/);
  assert.match(status, /watched_today >= 5/);
});
