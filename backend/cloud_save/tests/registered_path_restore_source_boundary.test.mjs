import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve, join } from "node:path";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = p => readFileSync(resolve(repo, p), "utf8");
const qa = read("scripts/managers/cloud_registered_path_restore_qa.gd");
const runner = read("tests/registered_path_restore_qa.gd");
const project = read("project.godot");
const workflow = read(".github/workflows/cloud-registered-restore-qa.yml");

function gdScripts(root) {
  const result = [];
  for (const item of readdirSync(root, { withFileTypes: true })) {
    const p = join(root, item.name);
    if (item.isDirectory()) result.push(...gdScripts(p));
    else if (item.isFile() && p.endsWith(".gd")) result.push(p);
  }
  return result;
}

test("registered-path harness is editor-only, explicitly armed, and disconnected", () => {
  assert.match(qa, /OS\.has_feature\("editor"\)/);
  assert.match(qa, /JADE_GATE9_TEST_ONLY/);
  assert.match(qa, /JADE_REGISTERED_RESTORE_TEST_ONLY/);
  assert.match(qa, /JADE_REGISTERED_RESTORE_ACK/);
  assert.match(qa, /DISPOSABLE_RUNNER_ONLY/);
  assert.doesNotMatch(project, /cloud_registered_path_restore_qa/);
  const refs = gdScripts(resolve(repo, "scripts"))
    .filter(p => !p.endsWith("cloud_registered_path_restore_qa.gd"))
    .filter(p => /cloud_registered_path_restore_qa|begin_registered_restore_for_qa/.test(readFileSync(p, "utf8")));
  assert.deepEqual(refs, []);
});

test("registered targets come only from the exact SaveManager permanent registry", () => {
  assert.match(qa, /SaveManager\.get_save_domain_ids_for_scope\(SaveManager\.SCOPE_PERMANENT\)/);
  assert.match(qa, /SaveManager\.get_save_path\(id\)/);
  assert.match(qa, /str\(paths\[id\]\) != SaveManager\.get_save_path\(id\)/);
  assert.match(qa, /DOMAIN_COUNT:\s*int\s*=\s*8/);
  assert.doesNotMatch(qa, /user:\/\/(?:progression|journey|pavilion|idle_cultivation|equipment|inventory|achievements|daily_quests)\.save/);
});

test("registered mutation owns the SaveManager global barrier and bypasses no public writer", () => {
  assert.match(qa, /begin_save_write_barrier/);
  assert.match(qa, /end_save_write_barrier/);
  assert.match(qa, /SAVE_WRITE_BARRIER_UNAVAILABLE/);
  assert.match(qa, /SAVE_WRITE_BARRIER_RELEASE_FAILED/);
  assert.doesNotMatch(qa, /SaveManager\.write_save_data\s*\(/);
  assert.doesNotMatch(qa, /SaveManager\.write_save_batch\s*\(/);
  assert.doesNotMatch(qa, /SaveManager\.recover_save_from_backup\s*\(/);
});

test("harness remains local-only and cannot authorize production cloud transfer", () => {
  assert.doesNotMatch(qa, /GoogleAccountManager|Firebase|firestore|https?:\/\//i);
  assert.doesNotMatch(qa, /"restore_allowed"\s*:\s*true/);
  assert.doesNotMatch(qa, /"upload_allowed"\s*:\s*true/);
  assert.match(qa, /user:\/\/jade_registered_restore_qa\//);
  assert.match(qa, /vault_cleanup_allowed/);
});

test("real registered-path runner covers restart, rollback, confirmation and critical crash points", () => {
  assert.match(runner, /JADE_REGISTERED_RESTORE_ROLLBACK_PASS/);
  assert.match(runner, /JADE_REGISTERED_RESTORE_CONFIRM_PASS/);
  assert.match(runner, /JADE_REGISTERED_RESTORE_RESTART_RECOVERY_PASS/);
  assert.match(runner, /JADE_REGISTERED_RESTORE_RECOVERY_FAULT_PASS/);
  assert.match(runner, /JADE_REGISTERED_RESTORE_MANUAL_ROLLBACK_FAULT_PASS/);
  assert.match(runner, /\.backup sidecars/);
  assert.match(workflow, /after_primary_to_rollback:/);
  assert.match(workflow, /after_candidate_to_primary:/);
  assert.match(workflow, /rollback_after_target_to_discard:/);
  assert.match(workflow, /rollback_after_preimage_to_primary:/);
});

test("workflow uses official Godot 4.7.2 and never deploys", () => {
  assert.match(workflow, /windows-2022/);
  assert.match(workflow, /Godot_v4\.7\.2-stable_win64_console\.exe/);
  assert.match(workflow, /731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953/);
  assert.match(workflow, /JADE_REGISTERED_RESTORE_ACK:\s*'DISPOSABLE_RUNNER_ONLY'/);
  assert.doesNotMatch(workflow, /firebase deploy|service.account|firebase login/i);
});
