import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = path => readFileSync(resolve(repo, path), "utf8");
const json = path => JSON.parse(read(path));

const e4 = json("backend/cloud_save/production_approval_boundary.json");
const predeploy = json("backend/cloud_save/predeploy_gate.json");
const project = read("project.godot");
const index = read("backend/cloud_save/functions/index.mjs");
const factory = read("backend/cloud_save/functions/src/callable_factory.mjs");
const packageJson = json("backend/cloud_save/functions/package.json");
const exportPlugin = read("addons/JadeCloudNativeBridge/export_plugin.gd");
const nativeMain = read("backend/cloud_save/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/cloudbridge/JadeCloudNativeBridge.kt");
const clientContract = read("scripts/managers/cloud_account_bound_read_client_contract.gd");
const e3cbRunner = read("tests/android/android_account_bound_transport_device_qa.gd");
const snapshotContract = read("scripts/managers/cloud_full_permanent_snapshot_contract.gd");

const FALSE_APPROVAL_KEYS = [
  "production_activation_approved",
  "firebase_deployment_approved",
  "billing_upgrade_approved",
  "account_bound_read_endpoint_approved",
  "native_release_packaging_approved",
  "additional_callable_exports_approved",
  "cloud_write_approved",
  "restore_execution_approved",
  "automatic_restore_approved",
  "cloud_wins_approved",
  "economy_write_approved",
  "merge_to_main_approved",
];


test("E4 is an explicit human approval boundary, never an activation switch", () => {
  assert.equal(e4.contract_version, 1);
  assert.equal(e4.phase, "E4");
  assert.equal(e4.state, "EXPLICIT_APPROVAL_REQUIRED");
  assert.equal(e4.firebase_project_id, null);
  for (const key of FALSE_APPROVAL_KEYS) assert.equal(e4[key], false, `${key} must remain false`);
  assert.deepEqual(e4.allowed_preapproval_callable_exports, ["jadeCloudSaveCapabilities"]);
  assert.deepEqual(e4.required_locked_phases, ["E1", "E2", "E3A", "E3B", "E3C-A", "E3C-B"]);
  assert.equal(e4.permanent_domain_count, 8);
  assert.equal(e4.active_run_checkpoint_included, false);
  assert.equal(e4.spark_policy, "NO_BLAZE_UPGRADE_WITHOUT_EXPLICIT_OWNER_APPROVAL");
  assert.equal(e4.required_human_approvals.length, 9);
});


test("legacy predeploy gate remains blocked and agrees with E4 callable allowlist", () => {
  assert.equal(predeploy.state, "PRE_DEPLOYMENT_ONLY");
  assert.equal(predeploy.firebase_project_id, null);
  assert.equal(predeploy.deployment_approved, false);
  assert.equal(predeploy.cloud_mutations_approved, false);
  assert.equal(predeploy.firestore_rules_changes_approved, false);
  assert.deepEqual(predeploy.approved_callable_exports, e4.allowed_preapproval_callable_exports);
});


test("server runtime still exports only bounded disabled capabilities, not account-bound snapshot transport", () => {
  assert.match(index, /export const\s*\{\s*jadeCloudSaveCapabilities\s*\}/);
  assert.equal((index.match(/\bexport\s+const\s*\{/g) ?? []).length, 1);
  assert.equal((factory.match(/\bonCall\s*\(/g) ?? []).length, 1);
  assert.match(factory, /enforceAppCheck:\s*true/);
  assert.match(factory, /maxInstances:\s*1/);
  assert.match(factory, /memory:\s*"256MiB"/);
  assert.match(factory, /timeoutSeconds:\s*10/);
  assert.doesNotMatch(index + factory, /CurrentSnapshot|accountBound|requestRestore|requestUpload|cloudWrite|restoreCloud/i);
  assert.equal(packageJson.scripts?.deploy, undefined);
  assert.equal(packageJson.scripts?.postinstall, undefined);
});


test("release project still does not package or enable the candidate native bridge", () => {
  assert.doesNotMatch(project, /res:\/\/addons\/JadeCloudNativeBridge\/plugin\.cfg/);
  assert.match(exportPlugin, /Gate 4\.2B candidate only; DISABLED by default/);
  assert.match(exportPlugin, /firebase-functions:22\.1\.1/);
  assert.match(exportPlugin, /firebase-appcheck-playintegrity:19\.4\.1/);
  assert.doesNotMatch(exportPlugin, /requestUpload|requestRestore|cloud_write_enabled\s*[:=]\s*true/i);
  assert.match(nativeMain, /getHttpsCallable\("jadeCloudSaveCapabilities"\)/);
  assert.equal((nativeMain.match(/getHttpsCallable\(/g) ?? []).length, 1);
  assert.doesNotMatch(nativeMain, /requestCurrentSnapshot|requestRestore|requestUpload|writeSave/i);
});


test("E3C-A and E3C-B remain read-only explicit one-shot boundaries above the eight-domain contract", () => {
  assert.match(clientContract, /STATE_ENDPOINT_NOT_ENABLED/);
  assert.match(clientContract, /explicit_user_action_required/);
  assert.match(clientContract, /automatic_request": false/);
  assert.match(clientContract, /client_payload": \{\}/);
  assert.match(clientContract, /one_shot": true/);
  assert.match(clientContract, /production_execution_allowed": false/);
  assert.doesNotMatch(clientContract, /SaveManager|FileAccess|DirAccess|Engine\.get_singleton|Firebase|https?:\/\//i);

  assert.match(e3cbRunner, /ClientContractScript/);
  assert.match(e3cbRunner, /apply_native_result/);
  assert.match(e3cbRunner, /take_validated_transport_for_internal_handoff/);
  assert.match(e3cbRunner, /JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_E3CB_CONTRACT_PASS/);
  assert.doesNotMatch(e3cbRunner, /begin_registered_restore|rollback_registered_restore|confirm_registered_restore/);

  for (const id of [
    "achievements", "daily_quests", "equipment", "idle_cultivation",
    "inventory", "journey", "pavilion", "progression",
  ]) assert.match(snapshotContract, new RegExp(`"${id}"`));
  assert.doesNotMatch(snapshotContract, /active_run_checkpoint|checkpoint\.save/i);
});


test("cloud QA workflows contain no production deploy command or production credential binding", () => {
  const workflowDir = resolve(repo, ".github/workflows");
  const names = readdirSync(workflowDir).filter(name => /cloud|godot-smoke-qa/i.test(name) && /\.ya?ml$/i.test(name));
  assert.ok(names.length > 0);
  for (const name of names) {
    const source = read(`.github/workflows/${name}`);
    const executable = source.split(/\r?\n/)
      .map(line => line.trim())
      .filter(line => line && !line.startsWith("#"))
      .join("\n");
    assert.doesNotMatch(executable, /\b(?:firebase|gcloud)\s+(?:deploy|functions\s+deploy|run\s+deploy)\b/i, name);
    assert.doesNotMatch(executable, /\$\{\{\s*secrets\./i, name);
    assert.doesNotMatch(executable, /GOOGLE_APPLICATION_CREDENTIALS|serviceAccountKey/i, name);
  }
  assert.equal(existsSync(resolve(repo, ".firebaserc")), false);
});
