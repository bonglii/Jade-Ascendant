import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {execFileSync} from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const read = (p) => readFileSync(resolve(root,p), 'utf8');
const blob = (p) => execFileSync('git', ['hash-object',p], {cwd:root,encoding:'utf8'}).trim();
const bridge=read('scripts/monetization/m7b_daily_reward_bridge.gd');
const daily=read('scripts/managers/daily_quest_manager.gd');
const screen=read('scripts/ui/daily_quest_screen.gd');
const boundary=JSON.parse(read('backend/monetization/m7b_daily_rewards_boundary.json'));

test('M7B: only two exact voluntary placements, with local provider callback, no SSV claim',()=>{
 assert.match(bridge,/const REWARDS: Dictionary = \{[\s\S]*?daily_completion_cache[\s\S]*?refinement_supply/);
 assert.match(bridge,/func request_rewarded\(placement: String\) -> bool:/);
 assert.match(bridge,/MonetizationManager\.show_rewarded\(placement\)/);
 assert.match(bridge,/MonetizationManager\.verified_rewarded_completed\.connect/);
 assert.match(bridge,/grant_id == _pending_grant_id/);
 assert.match(bridge,/policy_is_durable/);
 assert.equal(boundary.sdk_earned_callback_not_server_ssv,true);
});

test('M7B: reward + receipt via one write batch, no direct UI grant',()=>{
 assert.match(daily,/func m7b_commit_sdk_reward\(/);
 assert.match(daily,/if grant_id\.is_empty\(\) or grant_id in m7b_processed_grant_ids:/);
 assert.match(daily,/if placement in m7b_claimed_placement_ids:/);
 assert.match(daily,/var next_daily: Dictionary = build_save_data\(\)/);
 assert.match(daily,/\{"daily_quests": next_daily\}/);
 assert.match(daily,/RewardManager\.grant_reward\(/);
 assert.match(daily,/if bool\(result\.get\("success", false\)\):\n\t\tm7b_claimed_placement_ids = next_claims/);
 assert.doesNotMatch(screen,/RewardManager\.grant_reward|InventoryManager\.add_item|ProgressionManager\.add_spirit_stone/);
});

test('M7B: bonus strictly opt-in, original free daily reward preserved',()=>{
 assert.match(screen,/func _on_m7b_reward_pressed\(placement: String\) -> void:/);
 assert.match(screen,/action\.pressed\.connect\(_on_m7b_reward_pressed\.bind\(placement\)\)/);
 assert.match(screen,/func _on_claim_pressed\(quest_id: String\)/);
 assert.match(daily,/func claim_reward\(quest_id: String\) -> bool:/);
 assert.match(bridge,/DAILY AD LIMIT/);
 assert.equal(boundary.global_five_day_cap_enforced_for_legacy_calls,false);
});

test('M7B: historical monetization code and M7A catalog untouched',()=>{
 assert.equal(blob('scripts/managers/monetization_manager.gd'),'83d491aef274edd8b9d7f9be3cbff734fcab0eb5');
 assert.equal(blob('scripts/monetization/admob_provider.gd'),'a2d72a5f6d358157d8b30677183dcaee3abc8512');
 assert.equal(blob('scripts/managers/live_ops_manager.gd'),'5857e9ac635d2bf0d0c3ed6cc2f18405affc4c60');
 assert.equal(blob('scripts/monetization/m7_rewarded_offer_catalog.gd'),'4c4610a25c3670a65fa87976cd660319a883b318');
 assert.equal(blob('backend/monetization/m7a_rewarded_expansion_boundary.json'),'9b17dac22fc5f92bba732d279d735929163a7fee');
 assert.equal(boundary.billing_activated,false);
 assert.equal(boundary.production_admob_release_validated,false);
});
