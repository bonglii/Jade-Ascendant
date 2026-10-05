import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import test from "node:test";

const read = (path) => readFileSync(path, "utf8");
const json = (path) => JSON.parse(read(path));
const blob = (path) =>
  execFileSync("git", ["hash-object", path], { encoding: "utf8" }).trim();

const gate = json("release/production_baseline_p0.json");
const workflows = [
  ".github/workflows/cloud-production-safety.yml",
  ".github/workflows/godot-smoke-qa.yml",
  ".github/workflows/monetization-native-bridge-qa.yml",
];

test("P0 records owner-approved source promotion without runtime activation", () => {
  assert.equal(gate.contract_version, 1);
  assert.equal(gate.phase, "PRODUCTION_BASELINE_P0");
  assert.equal(gate.state, "SOURCE_PROMOTION_APPROVED_RUNTIME_FAIL_CLOSED");
  assert.equal(gate.production_definition, "repository_main_baseline_only");
  assert.equal(gate.source_branch, "qa/cloud-save-gate2-ci");
  assert.equal(gate.pre_p0_qa_sha, "2c8bc71ecf162cac1f2081484a8bf95faab1bb84");
  assert.equal(gate.target_branch, "main");
  assert.equal(gate.target_base_sha, "7c9c5e7abcd82618635a410396af0edc5ebd8134");
  assert.equal(gate.pre_p0_ahead_by, 79);
  assert.equal(gate.pre_p0_behind_by, 0);
  assert.equal(gate.repository_source_promotion_approved, true);
  assert.equal(gate.source_promotion_supersedes_historical_e4_merge_flag, true);
  assert.equal(gate.historical_e4_merge_to_main_approved, false);
  assert.equal(gate.fast_forward_promotion_required, true);
  assert.equal(gate.post_main_exact_sha_ci_required, true);
  assert.equal(gate.main_push_workflows_armed, true);
  assert.equal(gate.qa_to_main_merge_before_p0_gate_pass_allowed, false);
  assert.equal(gate.qa_to_main_merge_after_p0_gate_pass_allowed, true);

  for (const key of [
    "cloud_save_runtime_activation_approved",
    "cloud_save_backend_deployment_approved",
    "cloud_save_write_approved",
    "cloud_save_restore_approved",
    "monetization_paid_purchase_activation_approved",
    "monetization_backend_deployment_approved",
    "production_credentials_approved",
    "google_play_release_approved",
    "firebase_deployment_approved",
  ]) {
    assert.equal(gate[key], false, `${key} must remain false`);
  }

  assert.equal(gate.qa_exact_sha_ci.head_sha, gate.pre_p0_qa_sha);
  assert.equal(gate.qa_exact_sha_ci.godot_qa_run_id, 37292385096);
  assert.equal(gate.qa_exact_sha_ci.monetization_native_bridge_qa_run_id, 37292385080);
  assert.equal(gate.qa_exact_sha_ci.cloud_production_safety_run_id, 37292385056);
  assert.equal(gate.qa_exact_sha_ci.all_completed_success, true);
  assert.equal(gate.e2_script_uid_backfilled, true);
  assert.equal(gate.historical_e4_boundary_must_remain_immutable, true);
  assert.equal(gate.historical_m6_lock_must_remain_immutable, true);
});

test("P0 preserves historical E4 and M6 evidence blobs exactly", () => {
  assert.equal(
    blob("backend/cloud_save/production_approval_boundary.json"),
    "dcd92ca690dafca510385995e0f4d8a0dc46ba18",
  );
  assert.equal(
    blob("backend/monetization/m6_final_monetization_lock.json"),
    "870187442ac5a97f337d1ff0e625e39f2ee11beb",
  );
});

test("P0 backfills the stable Godot UID for the E2 event screen", () => {
  assert.equal(
    read("scripts/ui/liveops/jade_valley_pilgrimage_screen.gd.uid").trim(),
    "uid://2qrp1nmyovb5",
  );
});

test("P0 makes all permanent safety workflows verify main pushes at exact SHA", () => {
  for (const path of workflows) {
    const source = read(path);
    assert.match(
      source,
      /push:\s*\n\s*branches:\s*\n\s*-\s*'qa\/\*\*'\s*\n\s*-\s*main/,
      `${path} must run on QA and main pushes`,
    );
    assert.match(source, /ref:\s*\$\{\{\s*github\.sha\s*\}\}/);
    assert.match(source, /EXACT_SHA_CI_PASS/);

    const executable = source
      .split(/\r?\n/)
      .filter((line) => !line.trimStart().startsWith("#"))
      .join("\n");
    assert.doesNotMatch(
      executable,
      /\b(?:firebase|gcloud)\s+(?:deploy|functions\s+deploy|run\s+deploy)\b/i,
      `${path} must remain NO DEPLOY`,
    );
  }
});

test("Cloud production safety executes the P0 promotion contract test", () => {
  const cloud = read(".github/workflows/cloud-production-safety.yml");
  assert.match(
    cloud,
    /node --test tests\/production_baseline_p0\.test\.mjs/,
  );
});
