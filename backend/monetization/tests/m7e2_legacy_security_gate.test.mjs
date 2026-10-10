import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
const read = p => fs.readFileSync(path.join(process.cwd(),p),'utf8');
const get = n => read(`scripts/${n}.gd`);
const gate = get('monetization/m7e2_legacy_security_gate');
const live = get('managers/live_ops_manager');
const legacy = [
  ['ui/GameOverUI','game_over_revive'],
  ['ui/idle_cultivation_presenter','offline_cultivation_double'],
  ['ui/pavilion_runtime_screen','pavilion_seal'],
];
const bridges = [
  'monetization/game_over_rewarded_bridge',
  'monetization/offline_cultivation_rewarded_bridge',
  'monetization/pavilion_rewarded_bridge'
];
test('M7E2 only gates known five shipping placements; revive exempt from daily five',()=>{
  assert.match(gate,/Catalog\.is_shipping_placement\(placement\)/);
  assert.match(gate,/DAILY_NON_REVIVE_CAP:\s*int\s*=\s*5/);
  assert.match(gate,/placement != REVIVE_PLACEMENT and _non_revive_confirmed\(\) >= DAILY_NON_REVIVE_CAP/);
  assert.match(gate,/str\(key\) == REVIVE_PLACEMENT/);
  assert.match(gate,/SaveManager\.is_progress_read_only\(\)/);
});
test('M7E2 legacy UI routes use capped get status and request',()=>{
  for (const [file] of legacy){
    const source=get(file);
    assert.match(source,/M7E2Gate\.get_policy_status\(/,file);
    assert.match(source,/M7E2Gate\.request\(/,file);
    assert.doesNotMatch(source,/MonetizationManager\.show_rewarded\(/,file);
  }
});
test('M7E2 both LiveOps routes obey cap at status, availability and request',()=>{
  assert.equal((live.match(/M7E2Gate\.get_policy_status\(/g)||[]).length,2);
  assert.equal((live.match(/M7E2Gate\.can_request\(/g)||[]).length,2);
  assert.equal((live.match(/M7E2Gate\.request\(/g)||[]).length,2);
  assert.doesNotMatch(live,/MonetizationManager\.show_rewarded\(/);
});
test('M7E2 verifies specific active request and durable policy before reward',()=>{
  for (const needle of ['reward_consumed','active_placement','active_grant_id',
    'policy_store','load_state','day_bucket','last_reward_unix','placement_counts']){
    assert.ok(gate.includes(needle),needle);
  }
  for (const file of bridges) assert.match(get(file),/M7E2Gate\.earned_is_durable\(placement, grant_id\)/,file);
  assert.equal((live.match(/M7E2Gate\.earned_is_durable\(placement, grant_id\)/g)||[]).length,2);
});
test('M7E2 no paid IAP, AdMob provider or original manager modifications',()=>{
  const m6=JSON.parse(read('backend/monetization/m6_final_monetization_lock.json'));
  assert.equal(m6.purchase_activation_approved,false);
  assert.equal(m6.play_checkout_enabled,false);
  assert.equal(m6.prior_locked_boundary_mutation_allowed,false);
  const lock=JSON.parse(read('backend/monetization/m7e2_legacy_security_boundary.json'));
  assert.equal(lock.historical_manager_mutated,false);
  assert.equal(lock.admob_provider_mutated,false);
  assert.equal(lock.android_test_ads_required,true);
  assert.equal(lock.release_verdict,'HOLD');
});
