import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve, join } from "node:path";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = path => readFileSync(resolve(repo, path), "utf8");
const manager = read("scripts/managers/cloud_restore_review_qa.gd");
const runner = read("tests/cloud_restore_review_qa.gd");
const project = read("project.godot");
const settings = read("scripts/ui/settings_screen.gd");
const workflow = read(".github/workflows/cloud-restore-review-qa.yml");

function filesRecursive(root, suffix) {
  const result = [];
  for (const item of readdirSync(root, { withFileTypes: true })) {
    const p = join(root, item.name);
    if (item.isDirectory()) result.push(...filesRecursive(p, suffix));
    else if (item.isFile() && p.endsWith(suffix)) result.push(p);
  }
  return result;
}

test("restore review manager is QA-only and disconnected from production UI/runtime", () => {
  assert.doesNotMatch(project, /cloud_restore_review_qa|RESTORE_REVIEW_READY/);
  assert.doesNotMatch(settings, /cloud_restore_review_qa|RESTORE_REVIEW_READY/);
  const refs = filesRecursive(resolve(repo, "scripts"), ".gd")
    .filter(path => !path.endsWith("cloud_restore_review_qa.gd"))
    .filter(path => /cloud_restore_review_qa|build_restore_review_for_qa/.test(readFileSync(path, "utf8")));
  assert.deepEqual(refs, []);
  assert.match(manager, /OS\.has_feature\("editor"\)/);
  assert.match(manager, /GITHUB_ACTIONS/);
  assert.match(manager, /JADE_RESTORE_REVIEW_TEST_ONLY/);
  assert.match(manager, /JADE_RESTORE_REVIEW_ACK/);
  assert.match(manager, /DISPOSABLE_RUNNER_ONLY/);
});

test("restore review manager is read-only and cannot authorize restore or cloud mutation", () => {
  assert.match(manager, /FileAccess\.READ/);
  assert.match(manager, /SaveManager\.get_save_domain_ids_for_scope/);
  assert.match(manager, /SaveManager\.get_save_path/);
  assert.match(manager, /SaveManager\.get_save_schema_version/);
  assert.match(manager, /SaveManager\.get_save_required_keys/);
  assert.match(manager, /cloud_full_permanent_snapshot_contract\.gd/);
  assert.match(manager, /inspect_draft/);
  assert.match(manager, /hash_draft/);
  assert.match(manager, /CANDIDATE_CANONICAL_DIGEST_MISMATCH/);
  assert.doesNotMatch(manager, /FileAccess\.WRITE|store_var\(|store_buffer\(|make_dir|remove_absolute|rename_absolute/);
  assert.doesNotMatch(manager, /begin_save_write_barrier|end_save_write_barrier|write_save_data|write_save_batch|recover_save_from_backup/);
  assert.doesNotMatch(manager, /prepare_local_pre_restore_backup|begin_registered_restore|rollback_registered_restore|confirm_registered_restore/);
  assert.doesNotMatch(manager, /Firebase|firestore|https?:\/\/|JadeCloudNativeBridge|GoogleAccountManager/i);
  assert.doesNotMatch(manager, /"restore_allowed"\s*:\s*true|"upload_allowed"\s*:\s*true|"execution_allowed"\s*:\s*true/);
});

test("review contract exposes safe decision metadata but no raw save payload", () => {
  for (const marker of [
    "owner_verified", "owner_display", "remote_revision", "remote_digest",
    "captured_at_unix", "domain_count", "domain_states", "same_domains",
    "changed_domains", "local_missing_domains", "local_invalid_domains",
    "local_unsettled_domains", "local_backup_issue_domains",
    "local_state_fingerprint", "review_id", "decision_required", "decision_options",
    "preimage_backup_required", "preimage_source_files_ready", "preimage_runtime_guards_checked",
    "execution_preconditions_met", "raw_payload_included",
  ]) assert.match(manager, new RegExp(marker));
  assert.match(manager, /KEEP_LOCAL/);
  assert.match(manager, /RESTORE_CLOUD/);
  assert.match(manager, /SAME/);
  assert.match(manager, /DIFFERENT/);
  assert.match(manager, /LOCAL_MISSING/);
  assert.match(manager, /LOCAL_INVALID/);
  assert.match(manager, /raw_payload_included": false/);
  assert.doesNotMatch(manager, /"verified_owner_uid"/);
  assert.doesNotMatch(manager, /celestial_jade|processed_grant_ids|item_counts|spirit_stone/);
});

test("QA runner proves review-only behavior and future execution preconditions", () => {
  assert.match(runner, /stage_reviewed_snapshot_for_qa/);
  assert.match(runner, /inspect_ready_for_qa/);
  assert.match(runner, /build_restore_review_for_qa/);
  assert.match(runner, /mutates zero registered primaries or sidecars/);
  assert.match(runner, /local_missing_domains/);
  assert.match(runner, /local_invalid_domains/);
  assert.match(runner, /local_unsettled_domains/);
  assert.match(runner, /preimage_source_files_ready/);
  assert.match(runner, /preimage_backup_required/);
  assert.match(runner, /execution_preconditions_met/);
  assert.match(runner, /restore_allowed/);
  assert.match(runner, /execution_allowed/);
  assert.match(runner, /raw_payload_included/);
  assert.match(runner, /JADE_CLOUD_RESTORE_REVIEW_QA_PASS/);
  assert.doesNotMatch(runner, /cloud_registered_path_restore_qa|cloud_local_backup_vault|begin_registered_restore|rollback_registered_restore|confirm_registered_restore/);
  assert.doesNotMatch(runner, /Firebase|firestore|https?:\/\/|\badb\b/i);
});

test("workflow runs E1 without destructive restore gates or deploy authority", () => {
  assert.match(workflow, /Cloud Restore Review QA/);
  assert.match(workflow, /windows-2022/);
  assert.match(workflow, /Godot_v4\.7\.2-stable_win64_console\.exe/);
  assert.match(workflow, /cloud_restore_review_source_boundary\.test\.mjs/);
  assert.match(workflow, /cloud_restore_review_qa\.gd/);
  assert.match(workflow, /JADE_CONTROLLED_TRANSFER_TEST_ONLY:\s*'1'/);
  assert.match(workflow, /JADE_RESTORE_REVIEW_TEST_ONLY:\s*'1'/);
  assert.match(workflow, /JADE_RESTORE_REVIEW_ACK:\s*'DISPOSABLE_RUNNER_ONLY'/);
  assert.doesNotMatch(workflow, /JADE_GATE9_TEST_ONLY|JADE_REGISTERED_RESTORE_TEST_ONLY|firebase deploy|service\.account|firebase login|\badb\b/i);
});
