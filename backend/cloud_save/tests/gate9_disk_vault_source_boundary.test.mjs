/** Static release boundary for the disconnected Gate 9 Godot file-vault code.
 * Actual disk atomicity / fault injection is exercised by the Windows Godot QA.
 */
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve, join } from "node:path";
const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = p => readFileSync(resolve(repo, p), "utf8");
const vault = read("scripts/managers/cloud_local_backup_vault.gd");
const saver = read("scripts/managers/save_manager.gd");
const qa = read("tests/gate9_disk_vault_qa.gd");
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

test("Gate 9 source registry is eight permanent domains plus device-only checkpoint", () => {
  const entries = [...saver.matchAll(/\n\t"([a-z_]+)": \{([\s\S]*?)\n\t\},?/g)]
    .filter(m => m[2].includes('"schema_version":'));
  assert.equal(entries.length, 9);
  assert.equal(entries.filter(x => x[2].includes("SCOPE_PERMANENT")).length, 8);
  assert.deepEqual(entries.filter(x => x[2].includes("SCOPE_ACTIVE_RUN")).map(x => x[1]), ["checkpoint"]);
  assert.match(vault, /get_save_domain_ids_for_scope\(\s*SaveManager\.SCOPE_PERMANENT/);
  assert.match(vault, /DOMAIN_COUNT:\s*int\s*=\s*8/);
});

test("Gate 9 production entrypoint is not wired into scenes or autoloads", () => {
  const refs = gdScripts(resolve(repo, "scripts"))
    .filter(p => !p.endsWith("cloud_local_backup_vault.gd"))
    .filter(p => /cloud_local_backup_vault|prepare_local_pre_restore_backup/.test(readFileSync(p,"utf8")));
  assert.deepEqual(refs, []);
  assert.doesNotMatch(read("project.godot"), /cloud_local_backup_vault/);
  assert.match(vault, /^extends RefCounted/m);
});

test("Gate 9 refuses implicit consent and the unsafe restore transaction boundary", () => {
  assert.match(vault, /if not explicit_consent/);
  assert.match(vault, /SaveManager\.has_pending_transaction\(\)/);
  assert.match(vault, /SaveManager\.is_progress_read_only\(\)/);
  assert.match(vault, /SaveManager\.has_save_file\("checkpoint"\)/);
  assert.match(vault, /JourneyManager\.has_active_run\(\)/);
  assert.match(vault, /SceneTransitionManager\.is_transitioning/);
  assert.match(vault, /active_run_loadout_snapshot/);
  assert.doesNotMatch(vault, /SaveManager\.write_save_data\(/);
  assert.doesNotMatch(vault, /SaveManager\.write_save_batch\(/);
  assert.doesNotMatch(vault, /SaveManager\.read_save_data\(/);
  assert.doesNotMatch(vault, /SaveManager\.recover_save_from_backup\(/);
  assert.doesNotMatch(vault, /DirAccess\.remove_absolute\(/);
  assert.match(vault, /"upload_allowed": false, "restore_allowed": false/);
});

test("Gate 9 on-disk vault has immutable ready marker and per-file SHA256 integrity", () => {
  assert.match(vault, /Crypto\.new\(\)\.generate_random_bytes\(16\)\.hex_encode\(\)/);
  assert.match(vault, /"\/pending_"/);
  assert.match(vault, /"\/ready_"/);
  assert.match(vault, /DirAccess\.rename_absolute/);
  assert.match(vault, /FileAccess\.get_sha256\(/);
  assert.match(vault, /out\.flush\(\)/);
  assert.match(vault, /mf\.flush\(\)/);
  assert.match(vault, /\.rollback/);
  assert.match(vault, /\.backup/);
  assert.match(vault, /SOURCE_CHANGED_BEFORE_SEAL/);
  assert.doesNotMatch(vault, /"restore_allowed": true/);
});

test("Gate 9 test-only controls disallow user primary / production vault access", () => {
  assert.match(vault, /OS\.get_environment\("JADE_GATE9_TEST_ONLY"\) != "1"/);
  assert.match(vault, /QA_ROOT \+ "source\/"/);
  assert.match(vault, /QA_ROOT \+ "vault"/);
  assert.match(qa, /JADE_GATE9_DISK_VAULT_PASS/);
  assert.match(qa, /fault_at in range\(1, 11\)/);
  assert.match(qa, /read.*backup/i);
  assert.match(qa, /consent/i);
  assert.match(workflow, /windows-2022/);
  assert.match(workflow, /Godot_v4\.7\.2-stable_win64_console\.exe/);
  assert.match(workflow, /731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953/);
  assert.match(workflow, /JADE_GATE9_TEST_ONLY: '1'/);
  assert.doesNotMatch(workflow, /firebase deploy|service.account|firebase login/i);
});

test("Gate 9 cannot activate backend mutations, even after the new files are staged", () => {
  const entry = read("backend/cloud_save/functions/index.mjs");
  const gate = JSON.parse(read("backend/cloud_save/predeploy_gate.json"));
  assert.match(entry, /export const \{ jadeCloudSaveCapabilities \}/);
  assert.doesNotMatch(entry, /gate9|cloud_local_backup_vault|cloudUpload|cloudRestore/);
  assert.equal(gate.state, "PRE_DEPLOYMENT_ONLY");
  assert.equal(gate.deployment_approved, false);
  assert.equal(gate.cloud_mutations_approved, false);
});
