import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = p => readFileSync(resolve(repo, p), "utf8");
const project = read("project.godot");
const preset = read("export_presets.cfg");
const restore = read("scripts/managers/cloud_registered_path_restore_qa.gd");
const runner = read("tests/android/android_restore_device_qa.gd");
const bootstrap = read("tests/android/android_restore_device_bootstrap_qa.gd");
const stub = read("tests/android/android_restore_external_services_stub_qa.gd");
const tool = read("tools/android_restore_device_qa.ps1");
const workflow = read(".github/workflows/cloud-android-restore-device-bridge-qa.yml");


test("production project and export remain disconnected from Android destructive QA", () => {
  assert.doesNotMatch(project, /AndroidRestoreDeviceBootstrapQA|android_restore_device_qa\.tscn|jade_android_restore_qa/);
  assert.match(preset, /exclude_filter="[^"]*(?:^|,)tests\/\*(?:,|$)[^"]*"/m);
  assert.doesNotMatch(preset, /\.restoreqa|jade_android_restore_qa/);
  assert.match(restore, /OS\.has_feature\("editor"\)/);
  assert.doesNotMatch(restore, /jade_android_restore_qa|android_restore_device_qa\.tscn/);
});


test("device runner is Android debug only and never reaches cloud or monetization", () => {
  assert.match(runner, /OS\.get_name\(\)\s*!=\s*"Android"/);
  assert.match(bootstrap, /OS\.get_name\(\)\s*==\s*"Android"/);
  for (const source of [runner, bootstrap]) {
    assert.doesNotMatch(source, /OS\.has_feature\("android"\)/);
    assert.match(source, /OS\.is_debug_build\(\)/);
    assert.match(source, /jade_android_restore_qa/);
    assert.match(source, /application\/run\/main_scene/);
    assert.doesNotMatch(source, /Firebase|firestore|https?:\/\/|GoogleAccountManager|MonetizationManager/i);
  }
  assert.match(runner, /QA_HEAD_SHA_PLACEHOLDER/);
  assert.match(runner, /NOT_ANDROID_RUNTIME/);
  assert.match(runner, /QA_EXPORT_FEATURE_MISSING/);
  assert.match(runner, /QA_MAIN_SCENE_MISMATCH/);
  assert.match(runner, /HEAD_SHA_UNBOUND/);
  assert.doesNotMatch(runner, /restore_allowed\s*[:=]\s*true|upload_allowed\s*[:=]\s*true/i);
  assert.match(stub, /Android restore QA is offline-only/);
  assert.doesNotMatch(stub, /https?:\/\/|firestore/i);
});


test("runner exercises real restart, crash, rollback, account mismatch, corruption and checkpoint gates", () => {
  assert.match(runner, /apply_rollback_restart/);
  assert.match(runner, /apply_confirm_restart/);
  assert.match(runner, /after_primary_to_rollback:inventory/);
  assert.match(runner, /after_candidate_to_primary:inventory/);
  assert.match(runner, /after_all_domains/);
  assert.match(runner, /rollback_after_preimage_to_primary:inventory/);
  assert.match(runner, /rollback_after_target_to_discard:inventory/);
  assert.match(runner, /owner_mismatch_after_restart/);
  assert.match(runner, /corrupt_candidate_rejected/);
  assert.match(runner, /checkpoint_guard/);
  assert.match(runner, /\.backup/);
  assert.match(runner, /JADE_ANDROID_RESTORE_FORCE_STOP/);
  assert.match(runner, /JADE_ANDROID_RESTORE_DEVICE_PASS/);
  assert.match(runner, /_live_state\(\) == "preimage"/);
  assert.match(runner, /_live_state\(\) == "candidate"/);
});


test("startup bootstrap fences permanent managers before recovery", () => {
  assert.match(bootstrap, /OWNER_ID:\s*String\s*=\s*"registered_restore_bootstrap_qa"/);
  assert.match(bootstrap, /begin_save_write_barrier/);
  assert.match(bootstrap, /ACTIVE_TX/);
  assert.match(bootstrap, /CONFIRMED_MARKER/);
  assert.match(bootstrap, /ROLLED_BACK_MARKER/);
  assert.doesNotMatch(bootstrap, /FileAccess\.open|write_save_data|write_save_batch|recover_save_from_backup/);
});


test("PowerShell tool builds only from git archive HEAD and mutates only a temporary workspace", () => {
  assert.match(tool, /git -C \$ProjectRoot archive/);
  assert.match(tool, /rev-parse HEAD/);
  assert.match(tool, /GetTempPath/);
  assert.match(tool, /production_worktree_mutated=\$false/);
  assert.match(tool, /Audit mutated tracked project\.godot/);
  assert.match(tool, /Audit mutated tracked export_presets\.cfg/);
  assert.match(tool, /Audit mutated locked restore engine/);
  assert.match(tool, /\.restoreqa/);
  assert.match(tool, /gradle_build\/export_format=0/);
  assert.match(tool, /--install-android-build-template --export-debug Android \$apk/);
  assert.doesNotMatch(tool, /--install-android-build-template 2>&1 \| Out-Host/);
  assert.match(tool, /Godot import mengeksekusi Android QA scene di host Windows/);
  assert.match(tool, /Godot export mengeksekusi Android QA scene di host Windows/);
  assert.match(tool, /JADE_ANDROID_RESTORE_\(\?:DEVICE_\|ARMED\|CASE\|FORCE_STOP\|BOOT_BARRIER\)/);
  assert.match(tool, /AndroidRestoreDeviceBootstrapQA/);
  assert.match(tool, /SaveManager -> bootstrap -> permanent managers/);
  assert.match(tool, /tests\/android\/android_restore_external_services_stub_qa\.gd/);
  assert.match(tool, /enabled=PackedStringArray\(\)/);
  assert.match(tool, /custom_features/);
  assert.match(tool, /OS\.get_name\(\) == "Android"/);
  assert.doesNotMatch(tool, /OS\.has_feature\("android"\)/);
  assert.match(tool, /jade_android_restore_qa/);
  assert.match(tool, /QA_HEAD_SHA_PLACEHOLDER/);
  assert.match(tool, /exact HEAD/i);
  assert.doesNotMatch(tool, /\[jade_android_restore_qa\]/);
});


test("ADB controller performs actual force-stop and relaunch and stores evidence", () => {
  assert.match(tool, /logcat/);
  assert.match(tool, /am','force-stop/);
  assert.match(tool, /monkey','-p/);
  assert.match(tool, /JADE_ANDROID_RESTORE_FORCE_STOP/);
  assert.match(tool, /JADE_ANDROID_RESTORE_DEVICE_FAIL/);
  assert.match(tool, /JADE_ANDROID_RESTORE_DEVICE_PASS/);
  assert.match(tool, /android-restore-device-qa-summary\.json/);
  assert.match(tool, /android-restore-device-qa\.log/);
  assert.match(tool, /PASS marker berasal dari HEAD yang berbeda/);
  assert.match(tool, /uninstall/);
});


test("CI bridge QA never exports APK, deploys Firebase, or claims device PASS", () => {
  assert.match(workflow, /Android Restore Device Bridge QA/);
  assert.match(workflow, /NO APK \/ NO DEVICE/);
  assert.match(workflow, /android_restore_device_source_boundary\.test\.mjs/);
  assert.match(workflow, /-Action Audit/);
  assert.match(workflow, /JADE_ANDROID_RESTORE_DEVICE_PARSE_PASS/);
  assert.doesNotMatch(workflow, /--export-debug|adb\s|firebase deploy|service.account|firebase login/i);
  assert.doesNotMatch(workflow, /DEVICE_QA_PASS|device_status:\s*PASS/i);
});
