import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = path => readFileSync(resolve(repo, path), "utf8");

const surface = read("scripts/ui/cloud_restore_ux_surface_qa.gd");
const presenter = read("scripts/managers/cloud_restore_ux_presenter_qa.gd");
const runner = read("tests/cloud_restore_ux_integration_qa.gd");
const project = read("project.godot");
const settings = read("scripts/ui/settings_screen.gd");
const accountCard = read("scripts/ui/google_account_card.gd");
const workflow = read(".github/workflows/cloud-restore-ux-integration-qa.yml");

test("E3B is a disposable UI surface and remains disconnected from production runtime", () => {
  assert.match(surface, /^extends Control/m);
  assert.match(surface, /JADE_RESTORE_UX_INTEGRATION_TEST_ONLY/);
  assert.match(surface, /JADE_RESTORE_UX_INTEGRATION_ACK/);
  assert.match(surface, /DISPOSABLE_RUNNER_ONLY/);
  assert.match(surface, /GITHUB_ACTIONS/);
  assert.doesNotMatch(project, /cloud_restore_ux_surface_qa|JADE_CLOUD_RESTORE_UX_INTEGRATION_QA_PASS/);
  assert.doesNotMatch(settings, /cloud_restore_ux_surface_qa|RESTORE_UX_INTEGRATION/);
  assert.doesNotMatch(accountCard, /cloud_restore_ux_surface_qa|RESTORE_UX_INTEGRATION/);
});

test("E3B integrates only the locked E3A presenter and owns no execution authority", () => {
  assert.match(surface, /cloud_restore_ux_presenter_qa\.gd/);
  assert.match(surface, /present_review_for_qa/);
  assert.match(surface, /get_view_for_qa/);
  assert.match(surface, /choose_restore_cloud_for_qa/);
  assert.match(surface, /confirm_restore_cloud_for_qa/);
  assert.match(surface, /apply_execution_result_for_qa/);
  assert.match(surface, /choose_keep_restored_for_qa/);
  assert.match(surface, /choose_rollback_for_qa/);
  assert.match(surface, /apply_resolution_result_for_qa/);
  assert.doesNotMatch(surface, /cloud_restore_review_qa|build_restore_review_for_qa/);
  assert.doesNotMatch(surface, /cloud_restore_execution_qa|execute_review_decision_for_qa|resolve_applied_restore_for_qa/);
  assert.doesNotMatch(surface, /cloud_registered_path_restore|begin_registered_restore|confirm_registered_restore|rollback_registered_restore/);
  assert.doesNotMatch(surface, /FileAccess|DirAccess|SaveManager|write_save|write_barrier|user:\/\//);
  assert.doesNotMatch(surface, /Firebase|firestore|https?:\/\/|GoogleAccountManager|JadeCloudNativeBridge/i);
});

test("real Godot controls expose explicit two-stage restore and unresolved-restore resolution", () => {
  for (const marker of [
    "PanelContainer", "ScrollContainer", "KeepLocalButton", "RestoreCloudButton",
    "CancelConfirmationButton", "ConfirmRestoreButton", "KeepRestoredButton",
    "RollbackButton", "CloseButton",
  ]) assert.match(surface, new RegExp(marker));
  assert.match(surface, /signal command_requested/);
  assert.match(surface, /RESTORE_CONFIRMATION_REQUIRED/);
  assert.match(surface, /APPLIED_PENDING_CONFIRMATION/);
  assert.match(surface, /RESTORE_UX_INTEGRATION_DISMISS_BLOCKED/);
  assert.match(surface, /command_requested\.emit/);
  assert.doesNotMatch(surface, /print\s*\(.*command|push_(?:error|warning)\s*\(.*command/i);
});

test("surface renders only the E3A safe view and never exposes opaque bindings", () => {
  assert.match(surface, /owner_display/);
  assert.match(surface, /remote_revision/);
  assert.match(surface, /remote_digest_display/);
  assert.match(surface, /timestamp_note/);
  assert.match(surface, /domain_rows/);
  assert.match(surface, /raw_payload_included.*false/s);
  assert.match(surface, /production_execution_allowed.*false/s);
  const snapshotStart = surface.indexOf("func get_control_snapshot_for_qa");
  const buildStart = surface.indexOf("func _build_surface");
  const snapshotBody = surface.slice(snapshotStart, buildStart);
  assert.doesNotMatch(snapshotBody, /review_id|local_state_fingerprint|remote_digest"/);
  assert.doesNotMatch(surface, /celestial_jade|processed_grant_ids|item_counts|spirit_stone/);
});

test("locked E3A remains QA-only while E3B layers UI above it", () => {
  assert.match(presenter, /JADE_RESTORE_UX_TEST_ONLY/);
  assert.match(presenter, /GITHUB_ACTIONS/);
  assert.match(presenter, /^extends RefCounted/m);
  assert.doesNotMatch(presenter, /Control\.new|Button\.new|PanelContainer\.new/);
});

test("E3B runner exercises button emissions, dismiss fencing, safe rendering and fail closed", () => {
  for (const marker of [
    "First RESTORE CLOUD tap emits no command",
    "Second explicit confirm emits exactly one command",
    "APPLIED_PENDING_CONFIRMATION",
    "Pending restore cannot be silently dismissed",
    "KEEP LOCAL emits one explicit decision command",
    "Local issue blocks cloud restore choice",
    "ERROR_FAIL_CLOSED",
    "JADE_CLOUD_RESTORE_UX_INTEGRATION_QA_PASS",
  ]) assert.match(runner, new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.doesNotMatch(runner, /FileAccess|DirAccess|SaveManager|Firebase|firestore|https?:\/\/|\badb\b/i);
});

test("E3B workflow uses official Godot 4.7.2 and has no deploy/device/restore-engine authority", () => {
  assert.match(workflow, /Cloud Restore UX Integration QA/);
  assert.match(workflow, /windows-2022/);
  assert.match(workflow, /Godot_v4\.7\.2-stable_win64_console\.exe/);
  assert.match(workflow, /cloud_restore_ux_integration_source_boundary\.test\.mjs/);
  assert.match(workflow, /cloud_restore_ux_integration_qa\.gd/);
  assert.match(workflow, /JADE_RESTORE_UX_TEST_ONLY:\s*'1'/);
  assert.match(workflow, /JADE_RESTORE_UX_INTEGRATION_TEST_ONLY:\s*'1'/);
  assert.doesNotMatch(workflow, /JADE_REGISTERED_RESTORE_TEST_ONLY|JADE_GATE9_TEST_ONLY|firebase deploy|service\.account|firebase login|\badb\b/i);
});
