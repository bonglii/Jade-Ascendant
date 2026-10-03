import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { execFileSync } from "node:child_process";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = path => readFileSync(resolve(repo, path), "utf8");
const tracked = path => execFileSync("git", ["show", `:${path}`], { cwd: repo, encoding: "utf8" });
const json = path => JSON.parse(read(path));

const approval = json("backend/cloud_save/production_approval_boundary.json");
const predeploy = json("backend/cloud_save/predeploy_gate.json");
const project = tracked("project.godot");
const index = read("backend/cloud_save/functions/index.mjs");
const factory = read("backend/cloud_save/functions/src/callable_factory.mjs");
const client = read("scripts/managers/cloud_account_bound_read_client_contract.gd");
const snapshot = read("scripts/managers/cloud_full_permanent_snapshot_contract.gd");
const localVault = read("scripts/managers/cloud_local_backup_vault.gd");
const accountManager = read("scripts/managers/google_account_manager.gd");
const accountCard = read("scripts/ui/google_account_card.gd");
const debugManifest = read("backend/cloud_save/android_bridge/bridge/src/debug/AndroidManifest.xml");
const bridgeGradle = read("backend/cloud_save/android_bridge/bridge/build.gradle.kts");

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

const RETIRED_WORKFLOWS = [
  "cloud-account-bound-android-device-bridge-qa.yml",
  "cloud-account-bound-read-client-contract-qa.yml",
  "cloud-account-bound-read-transport-qa.yml",
  "cloud-account-bound-to-godot-qa.yml",
  "cloud-android-restore-device-bridge-qa.yml",
  "cloud-controlled-transfer-qa.yml",
  "cloud-economy-gate5-qa.yml",
  "cloud-gate9-disk-vault-qa.yml",
  "cloud-native-bridge-qa.yml",
  "cloud-production-approval-boundary-qa.yml",
  "cloud-registered-restore-qa.yml",
  "cloud-restore-execution-qa.yml",
  "cloud-restore-review-qa.yml",
  "cloud-restore-ux-integration-qa.yml",
  "cloud-restore-ux-presenter-qa.yml",
];

const RETIRED_BACKEND_QA = [
  "account_bound_read_transport_qa.test.mjs",
  "account_bound_read_transport_source_boundary.test.mjs",
  "account_bound_transport_to_godot_source_boundary.test.mjs",
  "android_account_bound_transport_device_fixture.test.mjs",
  "android_account_bound_transport_device_source_boundary.test.mjs",
  "android_restore_device_source_boundary.test.mjs",
  "cloud_account_bound_read_client_contract_source_boundary.test.mjs",
  "cloud_production_approval_boundary_source_boundary.test.mjs",
  "cloud_restore_execution_source_boundary.test.mjs",
  "cloud_restore_review_source_boundary.test.mjs",
  "cloud_restore_ux_integration_source_boundary.test.mjs",
  "cloud_restore_ux_presenter_source_boundary.test.mjs",
  "controlled_transfer_source_boundary.test.mjs",
  "e3cb_native_client_contract_device_source_boundary.test.mjs",
  "export_account_bound_transport_fixture_qa.mjs",
  "gate5_emulator_deny.rules",
  "gate5_firestore_emulator.test.mjs",
  "gate5_trusted_economy.test.mjs",
  "gate6_firestore_emulator.test.mjs",
  "gate6_full_permanent_draft.test.mjs",
  "gate7_firestore_emulator.test.mjs",
  "gate7_fixture.mjs",
  "gate7_reversible_restore_sandbox.test.mjs",
  "gate8_atomic_economy_contract.test.mjs",
  "gate8_firestore_emulator.test.mjs",
  "gate9_disk_vault_source_boundary.test.mjs",
  "registered_path_restore_source_boundary.test.mjs",
  "restore_transaction_source_boundary.test.mjs",
];

const RETIRED_GODOT_RUNNERS = [
  "tests/account_bound_transport_to_candidate_qa.gd",
  "tests/android/android_account_bound_transport_device_parse_qa.gd",
  "tests/android/android_account_bound_transport_device_qa.gd",
  "tests/android/android_account_bound_transport_device_qa.tscn",
  "tests/android/android_account_bound_transport_external_services_stub_qa.gd",
  "tests/android/android_restore_device_bootstrap_qa.gd",
  "tests/android/android_restore_device_parse_qa.gd",
  "tests/android/android_restore_device_qa.gd",
  "tests/android/android_restore_device_qa.tscn",
  "tests/android/android_restore_external_services_stub_qa.gd",
  "tests/cloud_account_bound_read_client_contract_qa.gd",
  "tests/cloud_restore_execution_qa.gd",
  "tests/cloud_restore_review_qa.gd",
  "tests/cloud_restore_ux_integration_qa.gd",
  "tests/cloud_restore_ux_presenter_qa.gd",
  "tests/controlled_transfer_candidate_qa.gd",
  "tests/gate9_disk_vault_qa.gd",
  "tests/gate9_write_barrier_qa.gd",
  "tests/registered_path_restore_qa.gd",
  "tests/restore_transaction_restart_qa.gd",
];

const RETIRED_DEVICE_TOOLS = [
  "tools/android_account_bound_transport_device_build_qa.ps1",
  "tools/android_account_bound_transport_device_qa.ps1",
  "tools/android_restore_device_qa.ps1",
];

const RETIRED_RUNTIME_QA = [
  "scripts/managers/cloud_account_bound_android_candidate_stager_qa.gd",
  "scripts/managers/cloud_account_bound_transport_adapter_qa.gd",
  "scripts/managers/cloud_local_restore_transaction.gd",
  "scripts/managers/cloud_registered_path_restore_qa.gd",
  "scripts/managers/cloud_registered_restore_bootstrap_qa.gd",
  "scripts/managers/cloud_restore_execution_qa.gd",
  "scripts/managers/cloud_restore_review_qa.gd",
  "scripts/managers/cloud_restore_ux_presenter_qa.gd",
  "scripts/managers/cloud_transfer_candidate_stager_qa.gd",
  "scripts/managers/cloud_save_economy_consistency.gd",
  "scripts/managers/cloud_save_manifest_inspector.gd",
  "scripts/managers/cloud_save_manifest_inspector.gd.uid",
  "scripts/managers/cloud_save_readonly_manager.gd",
  "scripts/managers/cloud_save_readonly_manager.gd.uid",
  "scripts/managers/cloud_save_snapshot_capture.gd",
  "scripts/managers/cloud_save_snapshot_capture.gd.uid",
  "scripts/managers/cloud_save_snapshot_contract.gd",
  "scripts/managers/cloud_save_snapshot_contract.gd.uid",
  "scripts/managers/cloud_save_snapshot_integrity.gd",
  "scripts/ui/cloud_native_readonly_qa_card.gd",
  "scripts/ui/cloud_native_readonly_qa_card.gd.uid",
  "scripts/ui/cloud_restore_ux_surface_qa.gd",
  "tests/cloud_save_server_reference_model.gd",
];

const RETIRED_BACKEND_GATE_SOURCES = [
  "backend/cloud_save/firebase-gate5-emulator.json",
  "backend/cloud_save/android_bridge/bridge/src/debug/assets/jade_account_bound_transport_device_record.json",
  "backend/cloud_save/android_bridge/bridge/src/debug/java/com/yungdevstudio/jadeascendant/cloudbridge/JadeAccountBoundTransportDebugBridge.kt",
  "backend/cloud_save/functions/src/economy/firestore_gate5_emulator_model.mjs",
  "backend/cloud_save/functions/src/integration/firestore_gate8_closed_economy_emulator.mjs",
  "backend/cloud_save/functions/src/restore/firestore_gate7_readonly_model.mjs",
  "backend/cloud_save/functions/src/restore/reversible_restore_sandbox.mjs",
  "backend/cloud_save/functions/src/snapshot/firestore_gate6_emulator_model.mjs",
  "backend/cloud_save/functions/src/transport/account_bound_read_transport_qa.mjs",
];

test("final production approval fuse remains explicitly closed", () => {
  assert.equal(approval.contract_version, 1);
  assert.equal(approval.phase, "E4");
  assert.equal(approval.state, "EXPLICIT_APPROVAL_REQUIRED");
  assert.equal(approval.firebase_project_id, null);
  for (const key of FALSE_APPROVAL_KEYS) assert.equal(approval[key], false, `${key} must remain false`);
  assert.deepEqual(approval.allowed_preapproval_callable_exports, ["jadeCloudSaveCapabilities"]);
  assert.equal(approval.permanent_domain_count, 8);
  assert.equal(approval.active_run_checkpoint_included, false);
  assert.equal(approval.spark_policy, "NO_BLAZE_UPGRADE_WITHOUT_EXPLICIT_OWNER_APPROVAL");
});

test("legacy predeploy policy agrees with the final fail-closed boundary", () => {
  assert.equal(predeploy.state, "PRE_DEPLOYMENT_ONLY");
  assert.equal(predeploy.firebase_project_id, null);
  assert.equal(predeploy.deployment_approved, false);
  assert.equal(predeploy.cloud_mutations_approved, false);
  assert.equal(predeploy.firestore_rules_changes_approved, false);
  assert.deepEqual(predeploy.approved_callable_exports, approval.allowed_preapproval_callable_exports);
});

test("server runtime still exports only the disabled capabilities callable", () => {
  assert.match(index, /export const\s*\{\s*jadeCloudSaveCapabilities\s*\}/);
  assert.equal((index.match(/\bexport\s+const\s*\{/g) ?? []).length, 1);
  assert.equal((factory.match(/\bonCall\s*\(/g) ?? []).length, 1);
  assert.match(factory, /enforceAppCheck:\s*true/);
  assert.match(factory, /maxInstances:\s*1/);
  assert.match(factory, /memory:\s*"256MiB"/);
  assert.match(factory, /timeoutSeconds:\s*10/);
  assert.doesNotMatch(index + factory, /CurrentSnapshot|accountBound|requestRestore|requestUpload|cloudWrite|restoreCloud/i);
});

test("retained client boundary is manual one-shot and has no execution authority", () => {
  assert.match(client, /ACTION_REQUEST_CURRENT_SNAPSHOT/);
  assert.match(client, /explicit_user_action_required/);
  assert.match(client, /automatic_request": false/);
  assert.match(client, /client_payload": \{\}/);
  assert.match(client, /one_shot": true/);
  assert.match(client, /production_execution_allowed": false/);
  assert.doesNotMatch(client, /SaveManager|FileAccess|DirAccess|Engine\.get_singleton|Firebase|https?:\/\//i);
});

test("retained permanent snapshot contract is exactly eight domains and excludes active-run checkpoint", () => {
  for (const id of [
    "achievements", "daily_quests", "equipment", "idle_cultivation",
    "inventory", "journey", "pavilion", "progression",
  ]) assert.match(snapshot, new RegExp(`"${id}"`));
  assert.match(snapshot, /DOMAIN_COUNT:\s*int\s*=\s*8/);
  assert.doesNotMatch(snapshot, /active_run_checkpoint|checkpoint\.save/i);
});

test("candidate native bridge remains disabled in the production project", () => {
  assert.doesNotMatch(project, /res:\/\/addons\/JadeCloudNativeBridge\/plugin\.cfg/);
});

test("gate-era executable QA harnesses are retired after the locked E-series", () => {
  for (const name of RETIRED_WORKFLOWS) {
    assert.equal(existsSync(resolve(repo, ".github/workflows", name)), false, name);
  }
  for (const name of RETIRED_BACKEND_QA) {
    assert.equal(existsSync(resolve(repo, "backend/cloud_save/tests", name)), false, name);
  }
  for (const path of RETIRED_GODOT_RUNNERS) assert.equal(existsSync(resolve(repo, path)), false, path);
  for (const path of RETIRED_DEVICE_TOOLS) assert.equal(existsSync(resolve(repo, path)), false, path);
  assert.equal(existsSync(resolve(repo, ".github/workflows/cloud-production-safety.yml")), true);
});

test("runtime and backend gate residues are retired while safety primitives remain", () => {
  for (const path of RETIRED_RUNTIME_QA) assert.equal(existsSync(resolve(repo, path)), false, path);
  for (const path of RETIRED_BACKEND_GATE_SOURCES) assert.equal(existsSync(resolve(repo, path)), false, path);

  assert.match(localVault, /VAULT_ROOT:\s*String\s*=\s*"user:\/\/jade_cloud_pre_restore_vault_v1"/);
  assert.match(localVault, /func prepare_local_pre_restore_backup\(/);

  assert.doesNotMatch(accountManager, /NATIVE_QA_CARD_PATH|CloudSaveProbeScript|get_cloud_save_probe|CloudNativeReadOnlyQACard|cloud_save_readonly_manager/i);
  assert.doesNotMatch(accountCard, /SnapshotCaptureScript|_cloud_qa|_capture_qa|CHECK FIRESTORE|LOCAL SNAPSHOT CHECK|cloud_save_snapshot_capture/i);
  assert.doesNotMatch(debugManifest, /JadeAccountBoundTransportDebugBridge/);
  assert.doesNotMatch(bridgeGradle, /qaMergedFirebaseRuntime|Gate 4\.2B diagnostic/i);
  assert.match(bridgeGradle, /debugImplementation\("com\.google\.firebase:firebase-appcheck-debug"\)/);
  assert.match(bridgeGradle, /implementation\("com\.google\.firebase:firebase-appcheck-playintegrity"\)/);
});

test("remaining workflows cannot deploy or bind production credentials", () => {
  const workflowDir = resolve(repo, ".github/workflows");
  const names = readdirSync(workflowDir).filter(name => /(?:cloud|godot-smoke-qa).*\.ya?ml$/i.test(name));
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
