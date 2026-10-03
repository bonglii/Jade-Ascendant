import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = path => readFileSync(resolve(repo, path), "utf8");

const contract = read("scripts/managers/cloud_account_bound_read_client_contract.gd");
const runner = read("tests/cloud_account_bound_read_client_contract_qa.gd");
const workflow = read(".github/workflows/cloud-account-bound-read-client-contract-qa.yml");
const project = read("project.godot");
const accountManager = read("scripts/managers/google_account_manager.gd");
const accountCard = read("scripts/ui/google_account_card.gd");
const nativeBridge = read("backend/cloud_save/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/cloudbridge/JadeCloudNativeBridge.kt");
const functionsIndex = read("backend/cloud_save/functions/index.mjs");

test("E3C-A contract is reusable production-shaped logic but activates no runtime path", () => {
  assert.match(contract, /^extends RefCounted/m);
  assert.match(contract, /ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY/);
  assert.match(contract, /REQUEST_ACCOUNT_BOUND_CURRENT_SNAPSHOT/);
  assert.doesNotMatch(contract, /GITHUB_ACTIONS|DISPOSABLE_RUNNER_ONLY|_qa_enabled/);
  assert.doesNotMatch(project, /cloud_account_bound_read_client_contract/);
  assert.doesNotMatch(accountManager, /cloud_account_bound_read_client_contract|REQUEST_ACCOUNT_BOUND_CURRENT_SNAPSHOT/);
  assert.doesNotMatch(accountCard, /cloud_account_bound_read_client_contract|REQUEST_ACCOUNT_BOUND_CURRENT_SNAPSHOT/);
});

test("E3C-A contract owns zero network save disk native or restore authority", () => {
  assert.doesNotMatch(contract, /FileAccess|DirAccess|SaveManager|write_save|write_barrier|user:\/\//);
  assert.doesNotMatch(contract, /Firebase|firestore|https?:\/\/|GoogleAccountManager|JadeCloudNativeBridge|Engine\.get_singleton/i);
  assert.doesNotMatch(contract, /cloud_restore_execution|cloud_registered_path_restore|begin_registered_restore|rollback_registered_restore|confirm_registered_restore/);
  assert.doesNotMatch(contract, /firebase deploy|service\.account|purchaseToken|\badb\b/i);
  assert.match(contract, /cloud_full_permanent_snapshot_contract\.gd/);
});

test("manual read command is fixed empty-payload explicit-user-action only", () => {
  const start = contract.indexOf("func begin_manual_request");
  const end = contract.indexOf("func apply_native_result");
  assert.ok(start >= 0 && end > start);
  const body = contract.slice(start, end);
  assert.match(body, /ACTION_REQUEST_CURRENT_SNAPSHOT/);
  assert.match(body, /"client_payload": \{\}/);
  assert.match(body, /"owner_argument_included": false/);
  assert.match(body, /"automatic_request": false/);
  assert.match(body, /"explicit_user_action_required": true/);
  assert.doesNotMatch(body, /remote_revision|remote_digest|currency|purchase/i);
});

test("production transport is strict eight-domain server-verified restore-disabled data", () => {
  for (const marker of [
    "transport_contract_version", "ownerUid", "revision", "digest",
    "domain_count", "domain_ids", "draft", "server_revision_verified",
    "server_freshness_verified", "explicit_restore_decision_required",
    "restore_allowed", "cloud_mutation_enabled",
  ]) assert.match(contract, new RegExp(marker));
  assert.doesNotMatch(contract, /"qaOnly"/);
  assert.match(contract, /DOMAIN_COUNT: int = 8/);
  assert.match(contract, /SNAPSHOT_DIGEST_MISMATCH/);
  assert.match(contract, /TRANSPORT_SERVER_VERIFICATION_MISSING/);
  assert.match(contract, /TRANSPORT_RECORD_UNSAFE_FLAGS/);
});

test("UI-safe status cannot leak raw owner digest draft or domains", () => {
  const summaryStart = contract.indexOf("func _build_safe_summary");
  const normalizeStart = contract.indexOf("func _normalize_json_value");
  assert.ok(summaryStart >= 0 && normalizeStart > summaryStart);
  const summaryBody = contract.slice(summaryStart, normalizeStart);
  assert.match(summaryBody, /owner_display/);
  assert.match(summaryBody, /remote_digest_display/);
  assert.match(summaryBody, /_masked_uid/);
  assert.match(summaryBody, /_short_digest/);
  assert.match(summaryBody, /raw_payload_included.*false/s);
  assert.doesNotMatch(summaryBody, /"ownerUid"\s*:/);
  assert.doesNotMatch(summaryBody, /"digest"\s*:/);
  assert.doesNotMatch(summaryBody, /"draft"\s*:/);
  assert.doesNotMatch(summaryBody, /"domains"\s*:/);
});

test("raw transport handoff is identity-rechecked one-shot internal-only and still powerless", () => {
  const start = contract.indexOf("func take_validated_transport_for_internal_handoff");
  const end = contract.indexOf("func discard");
  assert.ok(start >= 0 && end > start);
  const body = contract.slice(start, end);
  assert.match(body, /current_authenticated_uid != _request_owner_uid/);
  assert.match(body, /ACCOUNT_CHANGED_BEFORE_HANDOFF/);
  assert.match(body, /"internal_only": true/);
  assert.match(body, /"ui_safe": false/);
  assert.match(body, /"raw_payload_included": true/);
  assert.match(body, /"one_shot": true/);
  assert.match(body, /_clear_validated_transport\(\)/);
  assert.match(contract, /"restore_allowed": false/);
  assert.match(contract, /"cloud_mutation_enabled": false/);
  assert.match(contract, /"production_execution_allowed": false/);
});

test("E3C-A deliberately does not activate native callable or Firebase export yet", () => {
  assert.doesNotMatch(nativeBridge, /requestCurrentAccountBoundSnapshot|accountBoundSnapshotResult/);
  assert.doesNotMatch(functionsIndex, /jadeCloudReadCurrentSnapshot|ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY/);
  assert.match(workflow, /E3C-A/);
  assert.doesNotMatch(workflow, /firebase deploy|firebase login|service\.account|gradle -p backend\/cloud_save\/android_bridge|\badb\b/i);
});

test("E3C-A runner covers safe summary one-shot identity binding unsafe flags and endpoint-off state", () => {
  for (const marker of [
    "Manual account-bound read request can be armed",
    "Safe summary masks owner identity",
    "Raw transport cannot be consumed twice",
    "Account change during async read fails closed",
    "Transport attempting to authorize restore is rejected",
    "Missing server revision/freshness evidence fails closed",
    "Full eight-domain draft remains bound to canonical digest",
    "Undeployed endpoint is represented explicitly",
    "Unknown native/server status fails closed",
    "JADE_ACCOUNT_BOUND_READ_CLIENT_CONTRACT_QA_PASS",
  ]) assert.match(runner, new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
});
