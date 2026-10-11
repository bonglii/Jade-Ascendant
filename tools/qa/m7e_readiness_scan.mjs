#!/usr/bin/env node
// Read-only M7E risk audit. Never creates or edits gameplay save/currency.
import fs from 'node:fs';
import path from 'node:path';
const root = process.cwd();
const read = p => fs.readFileSync(path.join(root,p),'utf8');
const method = (source, name) => {
 const match=source.match(new RegExp(`^func ${name}\\([\\s\\S]*?(?=^func |^static func |$(?![\\s\\S]))`, 'm'));
 return match?.[0] ?? '';
};
const manager = read('scripts/managers/monetization_manager.gd');
const catalog = read('scripts/monetization/m7_rewarded_offer_catalog.gd');
const m6 = JSON.parse(read('backend/monetization/m6_final_monetization_lock.json'));
const daily = read('scripts/managers/daily_quest_manager.gd');
const show = method(manager,'show_rewarded');
const available = method(manager,'rewarded_available');
const confirmed = method(manager,'_on_reward_confirmed');
const blockers = [];
const add = (id, details, kind = 'ENGINEERING') => blockers.push({id,kind,details});
const globallyCapped =
  /GLOBAL.*CAP|global.*limit|MAX.*DAILY.*REWARD/i.test(show+available) &&
  /placement_counts\.(?:keys|values)|for .*placement_counts/.test(show+available);
if (!globallyCapped) add('GLOBAL_DAILY_CAP_NOT_UNIVERSAL',
 'Historical placements call MonetizationManager directly; the five-ad daily target is only checked by M7-specific owners.');
if (/if not _save_policy_state\(\):[\s\S]*?verified_rewarded_completed\.emit/.test(confirmed) &&
    !/if not _save_policy_state\(\):\s*\n\s*return/.test(confirmed)) {
 add('LEGACY_POLICY_SAVE_FAILURE_CAN_STILL_DISPATCH',
 'Reward confirmation continues to emit earned events after policy persistence fails; new M7 bridges re-read policy, historical handlers must be audited and hardened.');
}
if (/is_future_offer_enabled\(_placement/.test(catalog)) {
 add('M7A_STATIC_CATALOG_NOT_RUNTIME_ACTIVATION',
 'M7A future-offer catalog still returns false for all planned IDs; M7B-D call their owner routes directly. Align documentation and registry at release.', 'CONSISTENCY');
}
if (!/m7b_processed_grant_ids/.test(daily) || !/m7d_used_run_id/.test(daily)) {
 add('NEW_REWARD_PERSISTENCE_NOT_DETECTED','M7 reward receipts or run marker missing: investigate before release.');
}
if (m6.purchase_activation_approved !== false || m6.play_checkout_enabled !== false) {
 add('PAID_PURCHASE_LOCK_CHANGED','Paid-purchase gate no longer fail-closed.');
}
// Human release validation is never inferred from Godot or static source checks.
add('ANDROID_TEST_DEVICE_END_TO_END_REQUIRED',
 'Test UMP consent, Google test ads / registered test device, award callbacks, ad dismissal, offline, restart, account state, and real-device performance.','EXTERNAL');
add('SSV_PRODUCTION_TRUST_REVIEW_REQUIRED',
 'Client SDK on_user_earned_reward is not a cryptographically verified AdMob SSV receipt; evaluate server-authoritative validation before production-value grants.','EXTERNAL');
const result={phase:'MONETIZATION_M7E',kind:'read_only_local_source_audit',
 checked_at:new Date().toISOString(), verdict:'RELEASE_HOLD',
 existing_placements:5,new_placements:5,known_blockers:blockers,
 note:'PASS on unit/static tests does not equal Android AdMob release approval.'};
console.log(JSON.stringify(result,null,2));
console.error(`M7E RELEASE HOLD: ${blockers.map(b=>b.id).join(', ')}`);
process.exitCode=blockers.length>0?2:0;
