import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = path => readFileSync(resolve(repo, path), "utf8");

const presenter = read("scripts/managers/cloud_restore_ux_presenter_qa.gd");
const runner = read("tests/cloud_restore_ux_presenter_qa.gd");
const project = read("project.godot");
const settings = read("scripts/ui/settings_screen.gd");
const accountCard = read("scripts/ui/google_account_card.gd");
const workflow = read(".github/workflows/cloud-restore-ux-presenter-qa.yml");

test("E3A presenter stays QA-only and disconnected from production UI/runtime", () => {
  assert.match(presenter, /^extends RefCounted/m);
  assert.match(presenter, /JADE_RESTORE_UX_TEST_ONLY/);
  assert.match(presenter, /JADE_RESTORE_UX_ACK/);
  assert.match(presenter, /DISPOSABLE_RUNNER_ONLY/);
  assert.match(presenter, /GITHUB_ACTIONS/);
  assert.doesNotMatch(project, /cloud_restore_ux_presenter_qa|JADE_CLOUD_RESTORE_UX_PRESENTER_QA_PASS/);
  assert.doesNotMatch(settings, /cloud_restore_ux_presenter_qa|RESTORE_UX_COMMAND_READY/);
  assert.doesNotMatch(accountCard, /cloud_restore_ux_presenter_qa|RESTORE_UX_COMMAND_READY/);
});

test("E3A presenter is pure state/presentation and has zero save/network mutation authority", () => {
  assert.doesNotMatch(presenter, /FileAccess|DirAccess|SaveManager|write_save|write_barrier|user:\/\//);
  assert.doesNotMatch(presenter, /Firebase|firestore|https?:\/\/|GoogleAccountManager|JadeCloudNativeBridge/i);
  assert.doesNotMatch(presenter, /cloud_registered_path_restore|begin_registered_restore|rollback_registered_restore|confirm_registered_restore/);
  assert.doesNotMatch(presenter, /cloud_restore_review_qa|build_restore_review_for_qa|cloud_restore_execution_qa|execute_review_decision_for_qa|resolve_applied_restore_for_qa/);
  assert.doesNotMatch(presenter, /firebase deploy|service\.account|purchaseToken|\badb\b/i);
});

test("E3A accepts only safe reviewed metadata and never renders raw execution bindings", () => {
  for (const marker of [
    "owner_display", "remote_revision", "remote_digest", "captured_at_unix",
    "domain_states", "same_count", "changed_count", "local_issue_count",
    "review_id", "local_state_fingerprint", "preimage_source_files_ready",
    "raw_payload_included", "execution_preconditions_met",
  ]) assert.match(presenter, new RegExp(marker));
  assert.match(presenter, /RESTORE_UX_RAW_REVIEW_FIELD_REJECTED/);
  assert.match(presenter, /owner_uid/);
  assert.match(presenter, /candidate_paths/);
  assert.match(presenter, /remote_digest_display/);
  assert.match(presenter, /_short_digest/);
  const viewStart = presenter.indexOf("func get_view_for_qa");
  const choiceStart = presenter.indexOf("func choose_keep_local_for_qa");
  const viewBody = presenter.slice(viewStart, choiceStart);
  assert.doesNotMatch(viewBody, /review_id/);
  assert.doesNotMatch(viewBody, /local_state_fingerprint/);
  assert.match(viewBody, /raw_payload_included.*false/s);
  assert.match(viewBody, /production_execution_allowed.*false/s);
});

test("restore requires two explicit stages before any execution command is emitted", () => {
  const chooseStart = presenter.indexOf("func choose_restore_cloud_for_qa");
  const cancelStart = presenter.indexOf("func cancel_restore_confirmation_for_qa");
  const confirmStart = presenter.indexOf("func confirm_restore_cloud_for_qa");
  const applyStart = presenter.indexOf("func apply_execution_result_for_qa");
  assert.ok(chooseStart >= 0 && cancelStart > chooseStart && confirmStart > cancelStart && applyStart > confirmStart);
  const chooseBody = presenter.slice(chooseStart, cancelStart);
  const confirmBody = presenter.slice(confirmStart, applyStart);
  assert.match(chooseBody, /STATE_RESTORE_CONFIRMATION_REQUIRED/);
  assert.match(chooseBody, /command_ready.*false/s);
  assert.match(chooseBody, /mutation_requested.*false/s);
  assert.doesNotMatch(chooseBody, /_decision_command/);
  assert.match(confirmBody, /STATE_RESTORE_CONFIRMATION_REQUIRED/);
  assert.match(confirmBody, /_decision_command\(DECISION_RESTORE_CLOUD\)/);
  assert.match(presenter, /ACTION_SUBMIT_REVIEW_DECISION/);
  assert.match(presenter, /review_id/);
  assert.match(presenter, /remote_revision/);
  assert.match(presenter, /remote_digest/);
});

test("applied restore stays pending until explicit keep-restored or rollback resolution", () => {
  assert.match(presenter, /APPLIED_PENDING_CONFIRMATION/);
  assert.match(presenter, /choose_keep_restored_for_qa/);
  assert.match(presenter, /choose_rollback_for_qa/);
  assert.match(presenter, /RESOLUTION_CONFIRM/);
  assert.match(presenter, /RESOLUTION_ROLLBACK/);
  assert.match(presenter, /ACTION_RESOLVE_APPLIED_RESTORE/);
  assert.match(presenter, /USER_CONFIRMED_RESTORED/);
  assert.match(presenter, /USER_ROLLED_BACK/);
  assert.match(presenter, /ERROR_FAIL_CLOSED/);
  assert.doesNotMatch(presenter, /auto.?confirm|cloud.?wins/i);
});

test("UX copy treats timestamp as informational metadata and exposes safe domain status only", () => {
  assert.match(presenter, /Snapshot time is informational only/);
  assert.match(presenter, /Waktu snapshot hanya informasi/);
  assert.match(presenter, /Achievements/);
  assert.match(presenter, /Daily Quests/);
  assert.match(presenter, /Equipment/);
  assert.match(presenter, /Idle Cultivation/);
  assert.match(presenter, /Inventory/);
  assert.match(presenter, /Journey/);
  assert.match(presenter, /Pavilion/);
  assert.match(presenter, /Progression/);
  assert.doesNotMatch(presenter, /celestial_jade|processed_grant_ids|item_counts|spirit_stone/);
});

test("E3A runner covers review, second confirm, pending resolution, keep local, rollback and fail-closed binding", () => {
  for (const marker of [
    "NO_CANDIDATE", "REVIEW_READY", "RESTORE_CONFIRMATION_REQUIRED",
    "SUBMIT_REVIEW_DECISION", "RESTORE_CLOUD", "KEEP_LOCAL",
    "APPLIED_PENDING_CONFIRMATION", "RESOLVE_APPLIED_RESTORE", "CONFIRM",
    "ROLLBACK", "USER_CONFIRMED_RESTORED", "USER_ROLLED_BACK",
    "ERROR_FAIL_CLOSED", "RESTORE_UX_RESULT_BINDING_MISMATCH",
    "JADE_CLOUD_RESTORE_UX_PRESENTER_QA_PASS",
  ]) assert.match(runner, new RegExp(marker));
  assert.doesNotMatch(runner, /FileAccess|DirAccess|SaveManager|Firebase|firestore|https?:\/\/|\badb\b/i);
});

test("E3A workflow is isolated Godot 4.7.2 QA and never deploys or runs device restore", () => {
  assert.match(workflow, /Cloud Restore UX Presenter QA/);
  assert.match(workflow, /windows-2022/);
  assert.match(workflow, /Godot_v4\.7\.2-stable_win64_console\.exe/);
  assert.match(workflow, /cloud_restore_ux_presenter_source_boundary\.test\.mjs/);
  assert.match(workflow, /cloud_restore_ux_presenter_qa\.gd/);
  assert.match(workflow, /JADE_RESTORE_UX_TEST_ONLY:\s*'1'/);
  assert.match(workflow, /JADE_RESTORE_UX_ACK:\s*'DISPOSABLE_RUNNER_ONLY'/);
  assert.doesNotMatch(workflow, /JADE_REGISTERED_RESTORE_TEST_ONLY|JADE_GATE9_TEST_ONLY|firebase deploy|service\.account|firebase login|\badb\b/i);
});
