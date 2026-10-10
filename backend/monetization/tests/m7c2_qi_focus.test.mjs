import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../../..');
const read=(p)=>readFileSync(resolve(root,p),'utf8');
const bridge=read('scripts/monetization/m7c2_qi_focus_bridge.gd');
const manager=read('scripts/managers/daily_quest_manager.gd');
const player=read('scripts/player/player_1.gd');
const checkpoint=read('scripts/managers/checkpoint_manager.gd');
const ui=read('scripts/ui/daily_quest_screen.gd');
const contract=JSON.parse(read('backend/monetization/m7c2_qi_focus_boundary.json'));

test('M7C2 voluntary Qi Focus: no ad in gameplay and exact 10% EXP multiplier',()=>{
 assert.match(ui,/func _on_m7c2_focus_pressed\(\) -> void:/);
 assert.match(bridge,/const PLACEMENT_ID: String = "qi_focus"/);
 assert.match(player,/\* \(1\.10 if m7c2_qi_focus_active else 1\.0\)/);
 assert.match(player,/func add_experience\(amount: int\) -> void:/);
 assert.equal(contract.next_new_journey_run_exp_multiplier,1.1);
});
test('M7C2 SDK earned callback bound to pending request and durable policy',()=>{
 assert.match(bridge,/verified_rewarded_completed\.connect\(_on_sdk_reward\)/);
 assert.match(bridge,/grant_id != _pending_grant_id/);
 assert.match(bridge,/policy_is_durable/);
 assert.match(bridge,/MonetizationManager\.show_rewarded\(PLACEMENT_ID\)/);
 assert.equal(contract.sdk_earned_callback_not_server_side_ssv,true);
});
test('M7C2 pending token and replay receipts survive day rollover',()=>{
 assert.match(manager,/var m7c2_pending_focus: bool = false/);
 assert.match(manager,/"m7c2_pending_focus": m7c2_pending_focus/);
 assert.match(manager,/m7c2_pending_focus = save_data\.get\("m7c2_pending_focus", false\) == true/);
 assert.match(manager,/if m7c2_pending_focus or "qi_focus" in m7b_claimed_placement_ids:/);
 assert.match(manager,/next_daily\["m7b_processed_grant_ids"\] = next_grants/);
 assert.match(manager,/SaveManager\.write_save_data\("daily_quests", next_daily\)/);
 assert.equal(contract.claim_receipt_committed_with_token,true);
});
test('M7C2 new run consumes token once; Continue restores from checkpoint',()=>{
 assert.match(checkpoint,/if GameSession\.consume_continue_request\(\):\n\t\tcall_deferred\("_load_continue"\)\n\telif player != null and JourneyManager\.has_active_run\(\):/);
 assert.match(checkpoint,/DailyQuestManager\.m7c2_consume_for_new_run\(\)/);
 assert.match(checkpoint,/save_data\["m7c2_qi_focus_active"\] = bool\(player\.m7c2_qi_focus_active\)/);
 assert.match(checkpoint,/save_data\.get\("m7c2_qi_focus_active", false\)/);
 assert.match(checkpoint,/OPTIONAL_BOOL_SAVE_KEYS/);
 assert.equal(contract.continue_restores_flag_from_checkpoint,true);
});
test('M7C2 new reward routes do not grant materials directly and preserve paywall',()=>{
 assert.doesNotMatch(bridge,/RewardManager\.grant_reward|PavilionManager\.apply|ProgressionManager\.add_spirit_stone/);
 assert.equal(contract.purchase_billing_activated,false);
 assert.equal(contract.mutates_locked_historical_provider_or_m6,false);
 assert.equal(contract.legacy_global_cap_enforced,false);
});
