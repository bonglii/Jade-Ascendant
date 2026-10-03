import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const adapter = readFileSync(new URL("../../../scripts/managers/cloud_account_bound_transport_adapter_qa.gd", import.meta.url), "utf8");
const runner = readFileSync(new URL("../../../tests/account_bound_transport_to_candidate_qa.gd", import.meta.url), "utf8");
const exporter = readFileSync(new URL("./export_account_bound_transport_fixture_qa.mjs", import.meta.url), "utf8");
const workflow = readFileSync(new URL("../../../.github/workflows/cloud-account-bound-to-godot-qa.yml", import.meta.url), "utf8");

// Guard the new bridge itself rather than changing already-locked restore code.
test("Godot bridge remains QA-only and does not invoke transactional restore", () => {
  assert.match(adapter, /JADE_ACCOUNT_BOUND_TO_GODOT_TEST_ONLY/);
  assert.match(adapter, /JADE_ACCOUNT_BOUND_TO_GODOT_ACK/);
  assert.match(adapter, /server_revision_verified/);
  assert.match(adapter, /server_freshness_verified/);
  assert.match(adapter, /restore_allowed.*false/s);
  assert.match(adapter, /cloud_mutation_enabled.*false/s);
  assert.match(runner, /cloud_transfer_candidate_stager_qa\.gd/);
  assert.doesNotMatch(runner, /cloud_registered_path_restore_qa\.gd/);
  assert.doesNotMatch(runner, /begin_registered_restore|rollback_registered_restore|confirm_registered_restore/);
});

test("emulator producer exports synthetic current record only and never deploys", () => {
  assert.match(exporter, /assertGate5EmulatorOnly\(\)/);
  assert.match(exporter, /readCurrentAccountBoundSnapshotForQa/);
  assert.match(exporter, /account_bound_transport_record\.json/);
  assert.doesNotMatch(exporter, /firebase-functions|onCall\s*\(|firebase\s+deploy|gcloud\s+/i);
  assert.doesNotMatch(workflow, /firebase\s+deploy|gcloud\s+|GOOGLE_APPLICATION_CREDENTIALS|FIREBASE_TOKEN/i);
});

test("workflow uses artifact handoff and Godot candidate staging without restore gates", () => {
  assert.match(workflow, /actions\/upload-artifact@v4/);
  assert.match(workflow, /actions\/download-artifact@v4/);
  assert.match(workflow, /account_bound_transport_record\.json/);
  assert.match(workflow, /account_bound_transport_to_candidate_qa\.gd/);
  assert.match(workflow, /JADE_CONTROLLED_TRANSFER_TEST_ONLY/);
  assert.doesNotMatch(workflow, /JADE_GATE9_TEST_ONLY|JADE_REGISTERED_RESTORE_TEST_ONLY/);
  assert.doesNotMatch(workflow, /cloud_registered_path_restore_qa|begin_registered_restore|rollback_registered_restore/);
});
