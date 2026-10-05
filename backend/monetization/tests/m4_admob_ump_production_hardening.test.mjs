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

const admob = read("scripts/monetization/admob_provider.gd");
const manager = read("scripts/managers/monetization_manager.gd");
const privacy = read("scripts/ui/privacy_screen.gd");
const settings = read("scripts/ui/settings_screen.gd");
const project = read("project.godot");
const exportPreset = read("export_presets.cfg");
const boundary = JSON.parse(
  read("backend/monetization/m4_admob_ump_production_boundary.json"),
);

test("M4 release AdMob IDs are production IDs with matching publisher prefix", () => {
  const appMatch = project.match(
    /general\/android\/app_id="(ca-app-pub-[0-9]{16}~[0-9]{10})"/,
  );
  const rewardedMatch = project.match(
    /admob\/rewarded_ad_unit_id="(ca-app-pub-[0-9]{16}\/[0-9]{10})"/,
  );
  assert.ok(appMatch);
  assert.ok(rewardedMatch);
  assert.equal(appMatch[1], "ca-app-pub-3082528078187093~9576090733");
  assert.equal(rewardedMatch[1], "ca-app-pub-3082528078187093/8339864838");
  assert.equal(appMatch[1].split("~")[0], rewardedMatch[1].split("/")[0]);

  assert.match(
    admob,
    /const TEST_REWARDED_AD_UNIT_ID: String = "ca-app-pub-3940256099942544\/5224354917"/,
  );
  assert.match(
    admob,
    /const GOOGLE_SAMPLE_ANDROID_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"/,
  );
  assert.match(admob, /if app_id == GOOGLE_SAMPLE_ANDROID_APP_ID:/);
  assert.match(admob, /if rewarded_id == TEST_REWARDED_AD_UNIT_ID:/);
  assert.match(
    admob,
    /_publisher_prefix\(app_id, "~"\) != _publisher_prefix\(rewarded_id, "\/"\)/,
  );
  assert.match(
    admob,
    /if OS\.is_debug_build\(\):\s*return TEST_REWARDED_AD_UNIT_ID/s,
  );
});

test("M4 UMP refreshes each provider launch and ads stay closed until allowed consent status", () => {
  const ready = admob.match(
    /func _ready\(\) -> void:[\s\S]*?\n\nfunc _exit_tree/,
  );
  assert.ok(ready);
  assert.match(ready[0], /_begin_consent_update\(\)/);

  const allowed = admob.match(
    /func _consent_allows_ads\([\s\S]*?\n\nfunc _schedule_consent_retry/,
  );
  assert.ok(allowed);
  assert.match(
    allowed[0],
    /ConsentInformation\.ConsentStatus\.NOT_REQUIRED/,
  );
  assert.match(
    allowed[0],
    /ConsentInformation\.ConsentStatus\.OBTAINED/,
  );
  assert.doesNotMatch(
    allowed[0],
    /ConsentInformation\.ConsentStatus\.UNKNOWN[\s\S]*?return true/,
  );

  const initialize = admob.match(
    /func _initialize_mobile_ads\(\) -> void:[\s\S]*?\n\nfunc _on_mobile_ads_initialized/,
  );
  assert.ok(initialize);
  assert.match(initialize[0], /if not _consent_gate_open:\s*return/s);

  const load = admob.match(
    /func _load_rewarded_ad\(\) -> void:[\s\S]*?\n\nfunc _on_rewarded_loaded/,
  );
  assert.ok(load);
  assert.match(load[0], /not _consent_gate_open/);
  assert.match(load[0], /not _ads_initialized/);
});

test("M4 consent failures retry with bounded backoff while remaining fail-closed", () => {
  assert.match(
    admob,
    /const CONSENT_RETRY_INITIAL_SECONDS: float = 5\.0/,
  );
  assert.match(
    admob,
    /const CONSENT_RETRY_MAX_SECONDS: float = 60\.0/,
  );

  const failure = admob.match(
    /func _on_consent_update_failure\([\s\S]*?\n\nfunc _evaluate_consent_after_update/,
  );
  assert.ok(failure);
  assert.match(failure[0], /_consent_gate_open = false/);
  assert.match(failure[0], /_destroy_rewarded_ad\(\)/);
  assert.match(failure[0], /_schedule_consent_retry\(\)/);

  const evaluate = admob.match(
    /func _evaluate_consent_after_update\([\s\S]*?\n\nfunc _on_consent_form_loaded/,
  );
  assert.ok(evaluate);
  assert.match(
    evaluate[0],
    /_state = "consent_unresolved"[\s\S]*?_consent_gate_open = false[\s\S]*?_schedule_consent_retry\(\)/,
  );

  const loaded = admob.match(
    /func _on_consent_form_loaded\([\s\S]*?\n\nfunc _on_consent_form_load_failure/,
  );
  assert.ok(loaded);
  assert.match(
    loaded[0],
    /consent_form == null[\s\S]*?_consent_gate_open = false[\s\S]*?_schedule_consent_retry\(\)/,
  );

  const loadFailure = admob.match(
    /func _on_consent_form_load_failure\([\s\S]*?\n\nfunc _on_consent_form_dismissed/,
  );
  assert.ok(loadFailure);
  assert.match(loadFailure[0], /_schedule_consent_retry\(\)/);

  const dismiss = admob.match(
    /func _on_consent_form_dismissed\([\s\S]*?\n\nfunc _on_privacy_options_dismissed/,
  );
  assert.ok(dismiss);
  assert.match(
    dismiss[0],
    /if form_error != null:[\s\S]*?_consent_gate_open = false[\s\S]*?_schedule_consent_retry\(\)/,
  );

  const retry = admob.match(
    /func _schedule_consent_retry\(\) -> void:[\s\S]*?\n\nfunc _reset_consent_retry/,
  );
  assert.ok(retry);
  assert.match(retry[0], /or _consent_gate_open/);
  assert.match(retry[0], /_consent_retry_timer\.start\(\)/);
  assert.match(
    retry[0],
    /minf\([\s\S]*?CONSENT_RETRY_MAX_SECONDS[\s\S]*?\)/,
  );
});

test("M4 keeps release privacy options available when UMP requires them", () => {
  assert.match(
    privacy,
    /if MonetizationManager\.privacy_options_required\(\):/,
  );
  assert.match(privacy, /tr\("AD PRIVACY OPTIONS"\)/);
  assert.match(
    privacy,
    /MonetizationManager\.show_privacy_options\(\)/,
  );

  const qa = settings.match(
    /func _build_monetization_qa\([\s\S]*?\n\nfunc _refresh_monetization_qa/,
  );
  assert.ok(qa);
  assert.match(qa[0], /if not OS\.is_debug_build\(\):\s*return/s);
});

test("M4 rewarded grant remains SDK-callback-only and replay guarded", () => {
  const earned = admob.match(
    /func _on_user_earned_reward\([\s\S]*?\n\nfunc _on_rewarded_dismissed/,
  );
  assert.ok(earned);
  assert.match(
    earned[0],
    /if _active_request_id < 0 or _reward_earned_for_request:\s*return/s,
  );
  assert.match(earned[0], /_reward_earned_for_request = true/);
  assert.match(earned[0], /_emit_reward_confirmed\(_active_request_id\)/);

  const dismissed = admob.match(
    /func _on_rewarded_dismissed\([\s\S]*?\n\nfunc _on_rewarded_failed_to_show/,
  );
  assert.ok(dismissed);
  assert.doesNotMatch(dismissed[0], /_emit_reward_confirmed/);

  assert.match(
    manager,
    /if request_id != active_request or active_request < 0 or reward_consumed:\s*return/s,
  );
  assert.match(manager, /reward_consumed = true/);
  assert.match(manager, /crypto\.generate_random_bytes\(16\)/);
});

test("M4 production boundary matches release configuration and stays isolated from purchases/Cloud", () => {
  assert.equal(boundary.state, "ADMOB_UMP_PRODUCTION_HARDENED");
  assert.equal(boundary.base_locked_sha, "3f3f62fa951f3f19d383a42f23293468deea0195");
  assert.equal(boundary.production_android_app_id, "ca-app-pub-3082528078187093~9576090733");
  assert.equal(boundary.production_rewarded_ad_unit_id, "ca-app-pub-3082528078187093/8339864838");
  assert.equal(boundary.debug_rewarded_ad_unit_id, "ca-app-pub-3940256099942544/5224354917");
  assert.deepEqual(boundary.consent_gate_allowed_statuses, ["NOT_REQUIRED", "OBTAINED"]);
  assert.equal(boundary.ump_consent_update_each_launch, true);
  assert.equal(boundary.consent_failure_fail_closed, true);
  assert.equal(boundary.consent_retry_enabled, true);
  assert.equal(boundary.consent_retry_initial_seconds, 5);
  assert.equal(boundary.consent_retry_max_seconds, 60);
  assert.equal(boundary.rewarded_load_retry_enabled, true);
  assert.equal(boundary.privacy_options_release_surface, true);
  assert.equal(boundary.reward_grant_requires_sdk_reward_callback, true);
  assert.equal(boundary.reward_callback_replay_allowed, false);
  assert.equal(boundary.purchase_authority_modified, false);
  assert.equal(boundary.cloud_save_backend_modification_approved, false);
  assert.equal(boundary.prior_locked_boundary_mutation_allowed, false);

  assert.match(exportPreset, /permissions\/internet=true/);
  assert.equal(blob("scripts/managers/monetization_manager.gd"), "83d491aef274edd8b9d7f9be3cbff734fcab0eb5");
  assert.equal(blob("scripts/ui/privacy_screen.gd"), "82a68440edf6f9006ec54d59c870fb94468548ab");
  assert.equal(blob("scripts/ui/settings_screen.gd"), "dfedf592a792bd8a00f57f37375c126e34b62721");
  assert.equal(blob("scripts/monetization/offline_provider.gd"), "a86d73d23524db47ed0e78fdd98c238c01e874d0");
  assert.equal(blob("project.godot"), "fe7f658b1e6d4305fad287ce705dac77e7e44a1b");
  assert.equal(blob("export_presets.cfg"), "09fa1ade5c26a79e9a82d5a36c114161bd6f83d6");
  assert.equal(blob("backend/monetization/m3_treasury_production_contract.json"), "4e5b7bbecb1662c833edff6546c33bd20b5b1338");
  assert.equal(blob("backend/monetization/m2_billing_lifecycle_boundary.json"), "037988a195867afd397a9b9e51afb86902a6c45f");
  assert.equal(blob("backend/monetization/production_approval_boundary.json"), "02c249b931b10c21a90f8c03cc908e8fd0722602");
  assert.equal(blob("backend/cloud_save/functions/index.mjs"), "49126327ec25f8a404a8fe3494424416d6047be6");
  assert.equal(blob("backend/cloud_save/production_approval_boundary.json"), "dcd92ca690dafca510385995e0f4d8a0dc46ba18");
});
