import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
const read = (p) => fs.readFileSync(path.join(process.cwd(),p),'utf8');
const level=read('scripts/ui/level_up.gd');
const daily=read('scripts/managers/daily_quest_manager.gd');
const catalog=read('scripts/monetization/m7_rewarded_offer_catalog.gd');
const contract=JSON.parse(read('backend/monetization/m7d3_single_reroll_restore_contract.json'));
function method(src,name){
 const marker='func '+name+'(';
 const start=src.indexOf(marker);
 assert.ok(start>=0,'missing method: '+name);
 const next=src.indexOf('\nfunc ',start+marker.length);
 return src.slice(start,next>=0?next:undefined);
}
test('policy restored to only one rewarded Dao Choice Reroll per run/day',()=>{
 assert.equal(contract.max_successful_rerolls_per_run,1);
 assert.equal(contract.max_successful_rerolls_per_local_day,1);
 assert.equal(contract.active_placement,'dao_choice_reroll');
 assert.match(catalog,/"dao_choice_reroll"\s*:\s*\{[^}]*"uses_per_run": 1,[^}]*"daily_limit": 1/s);
 assert.doesNotMatch(catalog,/dao_choice_reroll_second/);
});
test('UI requests only the first placement; on-success reroll remains single-use',()=>{
 assert.match(level,/DAO REROLL • 1 \/ RUN/);
 assert.doesNotMatch(level,/dao_choice_reroll_second/);
 const requested=method(level,'_m7d_on_pressed');
 assert.match(requested,/MonetizationManager.show_rewarded\("dao_choice_reroll"\)/);
 const earned=method(level,'_m7d_on_sdk_reward');
 assert.match(earned,/grant_id != _m7d_request_grant_id/);
 assert.ok(earned.indexOf('m7d_commit_sdk_reroll')<earned.indexOf('current_upgrades = _m7d_future_choices.duplicate()'));
 assert.doesNotMatch(earned,/apply_upgrade\(/);
});
test('run-spent marker still persists after Continue/day rollover',()=>{
 assert.doesNotMatch(daily,/m7d_uses_in_run/);
 assert.match(daily,/m7d_used_run_id = str\(save_data.get\("m7d_used_run_id", ""\)\)/);
 assert.match(daily,/"m7d_used_run_id": m7d_used_run_id/);
 const s=method(daily,'m7d_get_offer_status');
 assert.match(s,/m7d_used_run_id == run_id/);
 assert.match(s,/watched_today >= 5/);
 const commit=method(daily,'m7d_commit_sdk_reroll');
 assert.match(commit,/SaveManager.write_save_data\("daily_quests", next_daily\)/);
 assert.match(commit,/grant_id in m7b_processed_grant_ids/);
});
test('historical M7D2 policy test and contract removed to avoid false regression failures',()=>{
 for (const p of ['backend/monetization/tests/m7d2_two_rerolls_per_run.test.mjs','backend/monetization/m7d2_two_rerolls_per_run_contract.json']) {
  assert.equal(fs.existsSync(p),false,'retired policy still present: '+p);
 }
});
test('release gates and security boundary remain unchanged',()=>{
 assert.equal(contract.m7b_m7c_m7e2_runtime_modified,false);
 assert.equal(contract.monetization_manager_modified,false);
 assert.equal(contract.admob_provider_modified,false);
 assert.equal(contract.ssv_implemented,false);
 assert.equal(contract.production_release_allowed,false);
});
