import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = path => readFileSync(resolve(repo, path), "utf8");

const coordinator = read("scripts/managers/cloud_restore_execution_qa.gd");
const runner = read("tests/cloud_restore_execution_qa.gd");
const project = read("project.godot");
const settings = read("scripts/ui/settings_screen.gd");
const workflow = read(".github/workflows/cloud-restore-execution-qa.yml");
const reviewBoundary = read("backend/cloud_save/tests/cloud_restore_review_source_boundary.test.mjs");
const restoreBoundary = read("backend/cloud_save/tests/registered_path_restore_source_boundary.test.mjs");

test("E2 coordinator is QA-only, disconnected, and has no network authority", () => {
  assert.doesNotMatch(project, /cloud_restore_execution_qa|RESTORE_EXECUTION_APPLIED_PENDING_CONFIRMATION/);
  assert.doesNotMatch(settings, /cloud_restore_execution_qa|RESTORE_EXECUTION_APPLIED_PENDING_CONFIRMATION/);
  assert.match(coordinator, /^extends RefCounted/m);
  assert.match(coordinator, /JADE_RESTORE_EXECUTION_TEST_ONLY/);
  assert.match(coordinator, /JADE_RESTORE_EXECUTION_ACK/);
  assert.match(coordinator, /DISPOSABLE_RUNNER_ONLY/);
  assert.match(coordinator, /GITHUB_ACTIONS/);
  assert.doesNotMatch(coordinator, /Firebase|firestore|https?:\/\/|GoogleAccountManager|JadeCloudNativeBridge/i);
  assert.doesNotMatch(coordinator, /firebase deploy|service\.account|purchaseToken/i);
});

test("E2 delegates live mutation only to locked registered restore engine", () => {
  assert.match(coordinator, /cloud_restore_review_qa\.gd/);
  assert.match(coordinator, /cloud_registered_path_restore_qa\.gd/);
  assert.match(coordinator, /build_restore_review_for_qa/);
  assert.match(coordinator, /candidate_paths_for_qa/);
  assert.match(coordinator, /prepare_registered_preimage_for_qa/);
  assert.match(coordinator, /begin_registered_restore_for_qa/);
  assert.match(coordinator, /inspect_registered_restore_for_qa/);
  assert.match(coordinator, /confirm_registered_restore_for_qa/);
  assert.match(coordinator, /rollback_registered_restore_for_qa/);
  assert.doesNotMatch(coordinator, /SaveManager\.get_save_path\s*\(/);
  assert.doesNotMatch(coordinator, /SaveManager\.(?:write_save_data|write_save_batch|recover_save_from_backup)\s*\(/);
  assert.doesNotMatch(coordinator, /begin_save_write_barrier|end_save_write_barrier/);
  assert.doesNotMatch(coordinator, /user:\/\/(?:progression|journey|pavilion|idle_cultivation|inventory|equipment|achievements|daily_quests)\.save/);
  assert.match(coordinator, /user:\/\/jade_restore_execution_qa\//);
  assert.match(coordinator, /target\.begins_with\(restore_root \+ "candidate\/"\)/);
  assert.match(coordinator, /_restore_candidates_match_ready/);
  assert.match(coordinator, /RESTORE_CANDIDATE_HANDOFF_DIVERGED/);
  assert.match(coordinator, /CONTROLLED_TRANSFER_ROOT/);
});

test("explicit decision order is review -> candidate handoff -> preimage -> re-review -> durable intent -> apply", () => {
  const start = coordinator.indexOf("func execute_review_decision_for_qa");
  const inspectStart = coordinator.indexOf("func inspect_execution_for_qa");
  assert.ok(start >= 0 && inspectStart > start);
  const body = coordinator.slice(start, inspectStart);

  const firstReview = body.indexOf("build_restore_review_for_qa");
  const keepLocal = body.indexOf("if decision == DECISION_KEEP_LOCAL");
  const handoff = body.indexOf("_install_restore_candidates");
  const preimage = body.indexOf("prepare_registered_preimage_for_qa");
  const secondReview = body.indexOf("build_restore_review_for_qa", firstReview + 1);
  const candidateRecheck = body.indexOf("_restore_candidates_match_ready");
  const durableIntent = body.indexOf("_write_var_atomic(SESSION_INTENT");
  const begin = body.indexOf("begin_registered_restore_for_qa");

  assert.ok(firstReview >= 0);
  assert.ok(keepLocal > firstReview);
  assert.ok(handoff > keepLocal);
  assert.ok(preimage > handoff);
  assert.ok(secondReview > preimage);
  assert.ok(candidateRecheck > secondReview);
  assert.ok(durableIntent > candidateRecheck);
  assert.ok(begin > durableIntent);

  assert.match(body, /_review_binding_issue/);
  assert.match(coordinator, /REVIEW_LOCAL_STATE_CHANGED/);
  assert.match(body, /LOCAL_STATE_CHANGED_AFTER_PREIMAGE/);
  assert.match(body, /preimage_source_files_ready/);
  assert.match(body, /local_issue_count/);
  assert.match(body, /NO_CLOUD_DIFFERENCE_TO_RESTORE/);
  assert.match(body, /RESTORE_APPLIED_PENDING_CONFIRMATION/);
  assert.match(body, /write_barrier_retained/);
});

test("E2 session binds review id and terminal confirm/rollback without production authorization", () => {
  assert.match(coordinator, /SESSION_INTENT/);
  assert.match(coordinator, /review_id/);
  assert.match(coordinator, /local_state_fingerprint/);
  assert.match(coordinator, /remote_revision/);
  assert.match(coordinator, /remote_digest/);
  assert.match(coordinator, /KEEP_LOCAL/);
  assert.match(coordinator, /RESTORE_CLOUD/);
  assert.match(coordinator, /CONFIRM/);
  assert.match(coordinator, /ROLLBACK/);
  assert.match(coordinator, /APPLIED_PENDING_CONFIRMATION/);
  assert.match(coordinator, /CONFIRMED/);
  assert.match(coordinator, /ROLLED_BACK/);
  assert.match(coordinator, /already_terminal/);
  assert.match(coordinator, /production_execution_allowed": false/);
  assert.doesNotMatch(coordinator, /"restore_allowed"\s*:\s*true/);
  assert.doesNotMatch(coordinator, /"upload_allowed"\s*:\s*true/);
  assert.doesNotMatch(coordinator, /"cloud_mutation_enabled"\s*:\s*true/);
});

test("E2 runner covers keep-local, stale-review rejection, rollback, confirm, and sidecar invariants", () => {
  for (const marker of [
    "KEEP_LOCAL", "RESTORE_CLOUD", "REVIEW_LOCAL_STATE_CHANGED",
    "RESTORE_EXECUTION_APPLIED_PENDING_CONFIRMATION",
    "RESTORE_EXECUTION_ROLLED_BACK", "RESTORE_EXECUTION_CONFIRMED",
    "preimage_backup_ready", "write_barrier_retained",
    ".backup sidecars", "JADE_CLOUD_RESTORE_EXECUTION_QA_PASS",
  ]) assert.match(runner, new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.match(runner, /Wrong review id cannot resolve an applied restore/);
  assert.match(runner, /Local preimage remains exact before confirm scenario/);
  assert.match(runner, /Repeated same terminal confirmation is idempotent/);
  assert.match(runner, /Opposite decision after confirmation is rejected/);
  assert.doesNotMatch(runner, /Firebase|firestore|https?:\/\/|\badb\b/i);
});

test("locked E1 and registered-restore source boundaries allow exactly the E2 coordinator reference", () => {
  assert.match(reviewBoundary, /cloud_restore_execution_qa\.gd/);
  assert.match(restoreBoundary, /cloud_restore_execution_qa\.gd/);
  assert.match(reviewBoundary, /allowedRefs/);
  assert.match(restoreBoundary, /allowedRefs/);
});

test("E2 workflow is disposable Godot 4.7.2 QA and never deploys", () => {
  assert.match(workflow, /Cloud Restore Execution QA/);
  assert.match(workflow, /windows-2022/);
  assert.match(workflow, /Godot_v4\.7\.2-stable_win64_console\.exe/);
  assert.match(workflow, /cloud_restore_execution_source_boundary\.test\.mjs/);
  assert.match(workflow, /cloud_restore_review_source_boundary\.test\.mjs/);
  assert.match(workflow, /registered_path_restore_source_boundary\.test\.mjs/);
  assert.match(workflow, /cloud_restore_execution_qa\.gd/);
  assert.match(workflow, /JADE_RESTORE_EXECUTION_TEST_ONLY:\s*'1'/);
  assert.match(workflow, /JADE_RESTORE_EXECUTION_ACK:\s*'DISPOSABLE_RUNNER_ONLY'/);
  assert.match(workflow, /JADE_GATE9_TEST_ONLY:\s*'1'/);
  assert.match(workflow, /JADE_REGISTERED_RESTORE_TEST_ONLY:\s*'1'/);
  assert.match(workflow, /JADE_RESTORE_REVIEW_TEST_ONLY:\s*'1'/);
  assert.doesNotMatch(workflow, /firebase deploy|service\.account|firebase login|\badb\b/i);
});
