/** Static safety boundary for the disconnected synthetic restore transaction.
 * Real disk/restart behavior is exercised by the Windows Godot QA runner.
 */
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve, join } from "node:path";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = p => readFileSync(resolve(repo, p), "utf8");
const restore = read("scripts/managers/cloud_local_restore_transaction.gd");
const runner = read("tests/restore_transaction_restart_qa.gd");
const saver = read("scripts/managers/save_manager.gd");
const project = read("project.godot");
const workflow = read(".github/workflows/cloud-gate9-disk-vault-qa.yml");

function gdScripts(root) {
  const result = [];
  for (const item of readdirSync(root, { withFileTypes: true })) {
    const p = join(root, item.name);
    if (item.isDirectory()) result.push(...gdScripts(p));
    else if (item.isFile() && p.endsWith(".gd")) result.push(p);
  }
  return result;
}

test("transactional restore model stays disconnected from production runtime", () => {
  assert.match(restore, /^extends RefCounted/m);
  assert.match(restore, /JADE_GATE9_TEST_ONLY/);
  assert.match(restore, /user:\/\/jade_gate9_qa\//);
  assert.doesNotMatch(project, /cloud_local_restore_transaction/);
  const refs = gdScripts(resolve(repo, "scripts"))
    .filter(p => !p.endsWith("cloud_local_restore_transaction.gd"))
    .filter(p => /cloud_local_restore_transaction|begin_sandbox_restore_for_qa/.test(readFileSync(p, "utf8")));
  assert.deepEqual(refs, []);
});

test("synthetic restore cannot invoke production SaveManager mutation APIs", () => {
  assert.doesNotMatch(restore, /SaveManager\.write_save_data\s*\(/);
  assert.doesNotMatch(restore, /SaveManager\.write_save_batch\s*\(/);
  assert.doesNotMatch(restore, /SaveManager\.recover_save_from_backup\s*\(/);
  assert.doesNotMatch(restore, /GoogleAccountManager|Firebase|firestore|https?:\/\//i);
  assert.doesNotMatch(restore, /"restore_allowed"\s*:\s*true/);
  assert.doesNotMatch(restore, /"upload_allowed"\s*:\s*true/);
  assert.match(restore, /_exact_path_set\(source_paths, ids, QA_SOURCE_ROOT\)/);
  assert.match(restore, /_exact_path_set\(candidate_paths, ids, QA_CANDIDATE_ROOT\)/);
});

test("restore journal is separate from gameplay roll-forward transaction journal", () => {
  assert.match(saver, /const TRANSACTION_PATH:\s*String\s*=\s*"user:\/\/transaction\.journal"/);
  assert.match(restore, /const INTENT_PATH:\s*String\s*=\s*ACTIVE_TX \+ "\/intent\.bin"/);
  assert.doesNotMatch(restore, /transaction\.journal/);
  assert.match(restore, /COMMIT_MARKER/);
  assert.match(restore, /APPLIED_MARKER/);
  assert.match(restore, /ROLLED_BACK_MARKER/);
  assert.doesNotMatch(restore, /last_completed|progress_index|completed_index/i);
});

test("restart recovery derives truth from immutable hashes, not an ambiguous progress counter", () => {
  assert.match(restore, /source_hashes/);
  assert.match(restore, /candidate_hashes/);
  assert.match(restore, /_all_live_match\(intent, "candidate_hashes"\)/);
  assert.match(restore, /_rollback_from_vault\(intent, fault_point\)/);
  assert.match(restore, /RESTORE_RECOVERED_APPLIED/);
  assert.match(restore, /RESTORE_RECOVERED_ROLLED_BACK/);
  assert.match(restore, /PRECOMMIT_LOCAL_STATE_DIVERGED/);
  assert.match(restore, /APPLIED_STATE_DIVERGED/);
});

test("Gate 9A vault is retained through apply rollback and confirmation", () => {
  assert.match(restore, /inspect_sandbox_backup_for_qa/);
  assert.match(restore, /vault_retained/);
  assert.match(restore, /vault_cleanup_allowed/);
  assert.doesNotMatch(restore, /remove.*ready_|delete.*vault/i);
  assert.match(runner, /_valid_vault_count\(\) == 1/);
});

test("real Godot QA covers process restart and commit/rollback fault injection", () => {
  assert.match(runner, /JADE_RESTORE_TX_RESTART_RECOVERY_PASS/);
  assert.match(runner, /JADE_RESTORE_TX_ROLLBACK_PASS/);
  assert.match(runner, /JADE_RESTORE_TX_CONFIRM_PASS/);
  assert.match(runner, /JADE_RESTORE_TX_RECOVERY_FAULT_PASS/);
  assert.match(runner, /JADE_RESTORE_TX_MANUAL_ROLLBACK_FAULT_PASS/);
  assert.match(workflow, /restore_transaction_restart_qa\.gd/);
  assert.match(workflow, /after_primary_to_rollback:/);
  assert.match(workflow, /after_candidate_to_primary:/);
  assert.match(workflow, /rollback_after_target_to_discard:/);
  assert.match(workflow, /rollback_after_preimage_to_primary:/);
});
