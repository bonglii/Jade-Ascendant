import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = path => readFileSync(resolve(repo, path), "utf8");
const runner = read("tests/android/android_account_bound_transport_device_qa.gd");
const workflow = read(".github/workflows/cloud-account-bound-android-device-bridge-qa.yml");


test("E3C-B device runner inserts the locked E3C-A client contract before candidate staging", () => {
  assert.match(runner, /cloud_account_bound_read_client_contract\.gd/);
  assert.match(runner, /begin_manual_request/);
  assert.match(runner, /REQUEST_ACCOUNT_BOUND_CURRENT_SNAPSHOT/);
  assert.match(runner, /client_payload/);
  assert.match(runner, /owner_argument_included/);
  assert.match(runner, /apply_native_result/);
  assert.match(runner, /ACCOUNT_BOUND_SNAPSHOT_READY/);
  assert.match(runner, /READY_FOR_REVIEW/);
  assert.match(runner, /get_safe_status/);
  assert.match(runner, /take_validated_transport_for_internal_handoff/);
  assert.match(runner, /ACCOUNT_BOUND_READ_HANDOFF_NOT_AVAILABLE/);

  const begin = runner.indexOf('begin_manual_request');
  const nativeCall = runner.indexOf('native.call(NATIVE_METHOD)');
  const apply = runner.indexOf('apply_native_result');
  const handoff = runner.indexOf('take_validated_transport_for_internal_handoff');
  const stage = runner.indexOf('stage_transport_json_for_device_qa');
  assert.ok(begin >= 0 && nativeCall > begin, "manual request must arm before native request");
  assert.ok(apply > nativeCall, "native callback must enter E3C-A before downstream work");
  assert.ok(handoff > apply, "raw bytes must leave E3C-A only after validation");
  assert.ok(stage > handoff, "candidate staging must occur only after one-shot handoff");
});


test("native fixture compatibility normalization is narrow, QA-only, and does not alter snapshot authority fields", () => {
  assert.match(runner, /func _normalize_debug_fixture_for_e3ca/);
  assert.match(runner, /record\.get\("qaOnly"\) != true/);
  assert.match(runner, /QA_ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY/);
  assert.match(runner, /record\.erase\("qaOnly"\)/);
  assert.match(runner, /record\["code"\] = "ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY"/);
  assert.doesNotMatch(runner, /record\[(?:"ownerUid"|"revision"|"digest"|"draft"|"domain_ids"|"domain_count")\]\s*=/);
});


test("safe status is checked before raw one-shot handoff and raw native bytes are never staged directly", () => {
  assert.match(runner, /raw_payload_included/);
  assert.match(runner, /owner_display/);
  assert.match(runner, /celestial_jade" not in safe_serialized/);
  assert.match(runner, /"domains" not in safe_serialized/);
  assert.match(runner, /production_execution_allowed/);
  assert.match(runner, /handoff_transport_json/);
  assert.doesNotMatch(
    runner,
    /stage_transport_json_for_device_qa"\s*,\s*transport_json/,
    "original native JSON must never bypass E3C-A into the stager",
  );
  assert.match(runner, /stage_transport_json_for_device_qa"\s*,\s*handoff_transport_json/);
});


test("E3C-B keeps restore, cloud mutation, network and production execution authority disabled", () => {
  assert.match(runner, /restore_allowed/);
  assert.match(runner, /cloud_mutation_enabled/);
  assert.match(runner, /production_execution_allowed/);
  assert.doesNotMatch(runner, /cloud_restore_execution_qa|cloud_registered_path_restore_qa|begin_registered_restore|confirm_registered_restore|rollback_registered_restore/);
  assert.doesNotMatch(runner, /Firebase|firestore|https?:\/\//i);
  assert.doesNotMatch(runner, /requestUpload|requestRestore|write_save_batch|write_save_data/i);
});


test("physical marker distinguishes E3C-B contract proof while preserving locked device PASS marker", () => {
  assert.match(runner, /JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_E3CB_CONTRACT_PASS/);
  assert.match(runner, /client_contract=E3C-A/);
  assert.match(runner, /one_shot=true/);
  assert.match(runner, /JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_PASS/);
  assert.match(runner, /EXPECTED_HEAD_SHA/);
});


test("existing Android account-bound CI runs the E3C-B regression before device execution is allowed", () => {
  assert.match(workflow, /e3cb_native_client_contract_device_source_boundary\.test\.mjs/);
  assert.match(workflow, /NO APK \/ NO DEVICE/);
  assert.doesNotMatch(workflow, /firebase deploy|\badb\s|--export-debug/i);
});
