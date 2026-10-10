import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const read = p => fs.readFileSync(path.join(process.cwd(), p), 'utf8');
const method = (source, methodName) => {
  const at = source.search(new RegExp(`^(?:static )?func ${methodName}\\(`, 'm'));
  assert.ok(at >= 0, `Missing ${methodName}`);
  const tail = source.slice(at);
  const next = tail.slice(1).search(/\n(?:func|static func) /m);
  return next < 0 ? tail : tail.slice(0, next + 1);
};
const manager = read('scripts/managers/monetization_manager.gd');
const store = read('scripts/monetization/monetization_policy_store.gd');
const save = read('scripts/managers/save_manager.gd');
const reward = read('scripts/managers/reward_manager.gd');
const legacy = read('scripts/monetization/m7e2_legacy_security_gate.gd');
const newBridge = read('scripts/monetization/m7b_daily_reward_bridge.gd');
const daily = read('scripts/managers/daily_quest_manager.gd');
const level = read('scripts/ui/level_up.gd');
const journey = read('scripts/managers/journey_manager.gd');
const boundary = JSON.parse(read('backend/monetization/m7e4_recovery_contract.json'));

test('M7E4A documents release HOLD and does not claim server-signed SDK proof', () => {
  assert.equal(boundary.release_verdict, 'HOLD');
  assert.equal(boundary.server_side_verification_implemented, false);
  assert.equal(boundary.new_reward_grants_enabled, false);
});

test('M7E4A source: separate policy store is not a SaveManager transaction domain', () => {
  assert.match(store, /user:\/\/monetization_policy\.save/);
  assert.match(save, /const TRANSACTION_PATH:\s*String\s*=\s*"user:\/\/transaction\.journal"/);
  assert.doesNotMatch(save, /"monetization_policy"\s*:\s*\{/);
});

test('M7E4A source: policy primary/backup validation and fresh default fallback detected', () => {
  const f = method(store, 'load_state');
  assert.match(f, /_read_valid_state\(SAVE_PATH\)/);
  assert.match(f, /_read_valid_state\(SAVE_PATH \+ "\.backup"\)/);
  assert.match(f, /if state\.is_empty\(\):\s*\n\s*return _default_state/);
});

test('M7E4A source: SDK confirmation persists policy before owner callback, but may still emit after save fails', () => {
  const f = method(manager, '_on_reward_confirmed');
  const savePos = f.indexOf('if not _save_policy_state():');
  const emitPos = f.indexOf('verified_rewarded_completed.emit(');
  assert.ok(savePos >= 0 && emitPos > savePos);
  assert.doesNotMatch(f.slice(savePos, emitPos), /\n\s*return(?:\s|$)/);
});

test('M7E4A source: old and new owners perform local policy durability checks', () => {
  assert.match(method(legacy, 'earned_is_durable'), /load_state/);
  assert.match(method(legacy, 'earned_is_durable'), /placement_counts/);
  assert.match(method(newBridge, '_on_sdk_reward'), /policy_store\.call\("load_state"\)/);
});

test('M7E4A source: reward has crash-replayable batch journal; never assume SDK-earned grant is in same batch', () => {
  assert.match(method(save, 'write_save_batch'), /_finish_pending_transaction/);
  assert.match(method(save, '_recover_pending_transaction'), /_finish_pending_transaction/);
  assert.match(method(reward, 'grant_reward'), /SaveManager\.write_save_batch\(targets\)/);
});

test('M7E4A source: Dao final mode remains one rewarded reroll per run', () => {
  assert.match(daily, /m7d_used_run_id/);
  assert.match(journey, /m7d_run_id/);
  assert.match(level, /_m7d_on_sdk_reward/);
  assert.doesNotMatch(level, /dao_choice_reroll_slot_2|m7d_uses_in_run/);
});

test('M7E4A model: local policy save fail must block payout but leaves earned ad uncompensated', () => {
  const state = { watched: true, policyDurable: false, delivered: false };
  if (state.watched && state.policyDurable) state.delivered = true;
  assert.equal(state.delivered, false);
  assert.equal(state.watched, true);
  // Pure state-machine example, not an executed Godot/Android failure test.
});

test('M7E4A model: journal replay applies target snapshot, not an additive second payout', () => {
  const committedTarget = { stones: 135 };
  let onDisk = { stones: 110 };
  for (let retry = 0; retry < 3; retry++) onDisk = structuredClone(committedTarget);
  assert.equal(onDisk.stones, 135);
  // This tests a model. It does NOT prove Game SaveManager replay on Android.
});
