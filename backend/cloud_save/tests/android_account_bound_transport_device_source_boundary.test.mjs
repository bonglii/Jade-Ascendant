import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const read = path => readFileSync(resolve(repo, path), "utf8");
const bytes = path => readFileSync(resolve(repo, path));
const project = read("project.godot");
const preset = read("export_presets.cfg");
const native = read("backend/cloud_save/android_bridge/bridge/src/debug/java/com/yungdevstudio/jadeascendant/cloudbridge/JadeAccountBoundTransportDebugBridge.kt");
const debugManifest = read("backend/cloud_save/android_bridge/bridge/src/debug/AndroidManifest.xml");
const mainManifest = read("backend/cloud_save/android_bridge/bridge/src/main/AndroidManifest.xml");
const fixturePath = "backend/cloud_save/android_bridge/bridge/src/debug/assets/jade_account_bound_transport_device_record.json";
const fixture = read(fixturePath);
const stager = read("scripts/managers/cloud_account_bound_android_candidate_stager_qa.gd");
const runner = read("tests/android/android_account_bound_transport_device_qa.gd");
const stub = read("tests/android/android_account_bound_transport_external_services_stub_qa.gd");
const tool = read("tools/android_account_bound_transport_device_qa.ps1");
const buildTool = read("tools/android_account_bound_transport_device_build_qa.ps1");
const workflow = read(".github/workflows/cloud-account-bound-android-device-bridge-qa.yml");
const nativeWorkflow = read(".github/workflows/cloud-native-bridge-qa.yml");


test("production project and preset remain disconnected from Android transport device QA", () => {
  assert.doesNotMatch(project, /JadeAccountBoundTransportDebugBridge|jade_android_account_bound_transport_qa|android_account_bound_transport_device_qa/);
  assert.doesNotMatch(project, /res:\/\/addons\/JadeCloudNativeBridge\/plugin\.cfg/);
  assert.match(preset, /exclude_filter="[^"]*(?:^|,)tests\/\*(?:,|$)[^"]*"/m);
  assert.doesNotMatch(preset, /\.transportqa|jade_android_account_bound_transport_qa|AccountBoundTransportQA/);
});


test("debug-only native bridge has a zero-input immutable fixture API and no network authority", () => {
  assert.match(debugManifest, /org\.godotengine\.plugin\.v2\.JadeAccountBoundTransportDebugBridge/);
  assert.match(debugManifest, /\.JadeAccountBoundTransportDebugBridge/);
  assert.doesNotMatch(mainManifest, /JadeAccountBoundTransportDebugBridge/);
  const releaseManifest = resolve(repo, "backend/cloud_save/android_bridge/bridge/src/release/AndroidManifest.xml");
  if (existsSync(releaseManifest)) {
    assert.doesNotMatch(readFileSync(releaseManifest, "utf8"), /JadeAccountBoundTransportDebugBridge/);
  }
  assert.match(native, /class JadeAccountBoundTransportDebugBridge/);
  assert.match(native, /@UsedByGodot\s+fun requestQaAccountBoundTransport\(\)/);
  assert.equal((native.match(/@UsedByGodot/g) ?? []).length, 1);
  assert.match(native, /BuildConfig\.DEBUG/);
  assert.match(native, /context\.assets\.open\(ASSET_NAME\)/);
  assert.match(native, /MessageDigest\.getInstance\("SHA-256"\)/);
  assert.match(native, /QA_TRANSPORT_FIXTURE_READY/);
  assert.doesNotMatch(native, /import\s+com\.google\.firebase|HttpsCallable|getHttpsCallable|HttpURLConnection|OkHttp|https?:\/\//i);
  assert.doesNotMatch(native, /\b(?:requestRestore|requestUpload|purchaseToken|writeSave|FileOutputStream)\b/i);
  const actual = createHash("sha256").update(bytes(fixturePath)).digest("hex");
  assert.match(native, new RegExp(actual));
});


test("packaged device fixture is exact reviewed account-bound transport and remains restore-disabled", () => {
  const record = JSON.parse(fixture);
  assert.deepEqual(Object.keys(record).sort(), [
    "cloud_mutation_enabled", "code", "digest", "domain_count", "domain_ids", "draft",
    "explicit_restore_decision_required", "ok", "ownerUid", "qaOnly", "restore_allowed",
    "revision", "server_freshness_verified", "server_revision_verified", "transport_contract_version",
  ].sort());
  assert.equal(record.code, "QA_ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY");
  assert.equal(record.transport_contract_version, 1);
  assert.equal(record.ownerUid, "account_bound_android_debug_owner");
  assert.equal(record.revision, 2);
  assert.equal(record.domain_count, 8);
  assert.equal(record.draft.domains.pavilion.celestial_jade, 144);
  assert.equal(record.server_revision_verified, true);
  assert.equal(record.server_freshness_verified, true);
  assert.equal(record.explicit_restore_decision_required, true);
  assert.equal(record.restore_allowed, false);
  assert.equal(record.cloud_mutation_enabled, false);
});


test("Android candidate stager is debug/package scoped and cannot reach registered save paths or restore engine", () => {
  assert.match(stager, /user:\/\/jade_account_bound_android_transport_qa\//);
  assert.match(stager, /OS\.get_name\(\) == "Android"/);
  assert.match(stager, /OS\.is_debug_build\(\)/);
  assert.match(stager, /OS\.has_feature\(QA_FEATURE\)/);
  assert.match(stager, /android_account_bound_transport_device_qa\.tscn/);
  assert.match(stager, /cloud_full_permanent_snapshot_contract\.gd/);
  assert.match(stager, /restore_allowed": false/);
  assert.match(stager, /cloud_mutation_enabled": false/);
  assert.doesNotMatch(stager, /cloud_registered_path_restore_qa|begin_registered_restore|rollback_registered_restore|write_save_batch|write_save_data|get_save_path/);
  assert.doesNotMatch(stager, /Firebase|https?:\/\//i);
});


test("device runner uses only debug native bridge -> isolated candidate staging and fingerprints live save state", () => {
  assert.match(runner, /OS\.get_name\(\) == "Android"/);
  assert.match(runner, /OS\.is_debug_build\(\)/);
  assert.match(runner, /jade_android_account_bound_transport_qa/);
  assert.match(runner, /QA_HEAD_SHA_PLACEHOLDER/);
  assert.match(runner, /JadeAccountBoundTransportDebugBridge/);
  assert.match(runner, /requestQaAccountBoundTransport/);
  assert.match(runner, /accountBoundTransportQaResult/);
  assert.match(runner, /_registered_live_fingerprints/);
  assert.match(runner, /\.backup/);
  assert.match(runner, /\.rollback/);
  assert.match(runner, /ANDROID_ACCOUNT_BOUND_CANDIDATES_READY/);
  assert.match(runner, /JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_PASS/);
  assert.doesNotMatch(runner, /cloud_registered_path_restore_qa|begin_registered_restore|rollback_registered_restore|Firebase|firestore|https?:\/\//i);
  assert.match(stub, /offline-only/);
  assert.doesNotMatch(stub, /Firebase|firestore|https?:\/\//i);
});


test("PowerShell device runner uses exact git archive HEAD, exact CI AAR hash, isolated package and explicit ADB lifecycle", () => {
  assert.match(tool, /git -C \$ProjectRoot archive/);
  assert.match(tool, /rev-parse HEAD/);
  assert.match(tool, /GetTempPath/);
  assert.match(tool, /ExpectedBridgeAarSha256/);
  assert.match(tool, /Debug bridge AAR SHA256 mismatch/);
  assert.match(tool, /\.transportqa/);
  assert.match(tool, /jade_android_account_bound_transport_qa/);
  assert.match(tool, /res:\/\/addons\/JadeCloudNativeBridge\/plugin\.cfg/);
  assert.match(tool, /production_worktree_mutated=\$false/);
  assert.match(tool, /Audit mutated tracked locked\/production file/);
  assert.match(tool, /Invoke-NativeCaptured/);
  assert.match(tool, /PSNativeCommandUseErrorActionPreference/);
  assert.match(tool, /--install-android-build-template','--export-debug/);
  assert.match(tool, /cmd','package','resolve-activity','--brief/);
  assert.match(tool, /am','start','-W','-n/);
  assert.match(tool, /topResumedActivity\|mResumedActivity/);
  assert.match(tool, /mCurrentFocus\|mFocusedApp/);
  assert.match(tool, /\$processId/);
  assert.match(tool, /\$expectedHeadLine = 'const EXPECTED_HEAD_SHA: String = "'\+\[string\]\$Info\.head_sha\+'"'/);
  assert.match(tool, /\$placeholderDeclaration = 'const EXPECTED_HEAD_SHA: String = "'\+\$QaHeadPlaceholder\+'"'/);
  assert.doesNotMatch(tool, /\$runner -match \[regex\]::Escape\(\$QaHeadPlaceholder\)/);
  assert.match(runner, /EXPECTED_HEAD_SHA == "QA_HEAD_SHA_PLACEHOLDER"/);
  const forbiddenAutomaticNames = "Args|Input|Matches|Error|PID|Host|HOME|PWD|PSScriptRoot|PSCommandPath|PSHOME|PSVersionTable|ShellId";
  assert.doesNotMatch(tool, new RegExp(`function[^\\n]*\\$(?:${forbiddenAutomaticNames})\\b`, "i"));
  assert.doesNotMatch(tool, new RegExp(`^\\s*(?:\\[[^\\r\\n]+\\]\\s*)?\\$(?:${forbiddenAutomaticNames})\\s*=`, "im"));
  assert.match(tool, /JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_FAIL/);
  assert.match(tool, /JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_PASS/);
  assert.match(tool, /android-account-bound-transport-device-qa-summary\.json/);
  assert.match(tool, /uninstall/);
  assert.doesNotMatch(tool, /(?:^|\n)\s*(?:&\s*)?firebase(?:\.cmd|\.exe)?\s+(?:deploy|login)\b/im);
});


test("dedicated build harness keeps plugins OFF during import, enables only bridge afterward, and hard-times native processes", () => {
  assert.match(buildTool, /ValidateSet\('Audit','Smoke','ExportWatcherSelfTest','Build'\)/);
  assert.match(buildTool, /git -C \$ProjectRoot archive/);
  assert.match(buildTool, /rev-parse HEAD/);
  assert.match(buildTool, /ExpectedBridgeAarSha256/);
  assert.match(buildTool, /enabled=PackedStringArray\(\)/);
  assert.match(buildTool, /function Enable-QaExportPlugin/);
  assert.match(buildTool, /enabled=PackedStringArray\("'\+\$QaPlugin\+'"\)/);
  assert.match(buildTool, /ANDROID_ACCOUNT_BOUND_TRANSPORT_IMPORT_PHASE_PASS/);
  assert.match(buildTool, /ANDROID_ACCOUNT_BOUND_TRANSPORT_PLUGIN_SMOKE_PASS/);
  assert.match(buildTool, /ANDROID_ACCOUNT_BOUND_TRANSPORT_BUILD_SMOKE_PASS/);
  assert.match(buildTool, /ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_BUILD_PASS/);
  assert.match(buildTool, /WaitForExit\(\$TimeoutSeconds \* 1000\)/);
  assert.match(buildTool, /taskkill\.exe \/PID \$childProcessId \/T \/F/);
  assert.match(buildTool, /timed_out=\[bool\]\$timedOut/);
  assert.match(buildTool, /Godot disposable import timeout/);
  assert.match(buildTool, /Godot Android export timeout/);
  assert.match(buildTool, /function Invoke-ExportObserved/);
  assert.match(buildTool, /ANDROID_ACCOUNT_BOUND_TRANSPORT_EXPORT_COMPLETION_SEEN/);
  assert.match(buildTool, /ANDROID_ACCOUNT_BOUND_TRANSPORT_EXPORT_APK_VERIFIED/);
  assert.match(buildTool, /ANDROID_ACCOUNT_BOUND_TRANSPORT_EXPORT_SHUTDOWN_FORCED_AFTER_VERIFIED_APK/);
  assert.match(buildTool, /ANDROID_ACCOUNT_BOUND_TRANSPORT_EXPORT_WATCHER_SELFTEST_PASS/);
  assert.match(buildTool, /\[Console\]::Out\.WriteLine\('\[ DONE \] export'\)/);
  assert.match(buildTool, /\[Console\]::Out\.Flush\(\)/);
  assert.doesNotMatch(buildTool, /Write-Output '\[ DONE \] export'/);
  assert.match(buildTool, /function Wait-ApkStableAndValid/);
  assert.match(buildTool, /function Test-ApkArchive/);
  assert.match(buildTool, /AndroidManifest\.xml/);
  assert.match(buildTool, /arm64-v8a/);
  assert.match(buildTool, /export_shutdown_forced=\[bool\]\$exportResult\.forced_shutdown/);
  assert.doesNotMatch(buildTool, /begin_registered_restore|rollback_registered_restore/i);
  assert.doesNotMatch(buildTool, /(?:^|\n)\s*(?:&\s*)?(?:adb(?:\.exe)?|firebase(?:\.cmd|\.exe)?)\s+/im);

  const smokeStart = buildTool.indexOf("function Invoke-Smoke");
  const buildStart = buildTool.indexOf("function Invoke-Build");
  const switchStart = buildTool.indexOf("try {\n    Set-Location");
  assert.ok(smokeStart >= 0 && buildStart > smokeStart && switchStart > buildStart);
  const smokeBody = buildTool.slice(smokeStart, buildStart);
  const buildBody = buildTool.slice(buildStart, switchStart);
  assert.ok(smokeBody.indexOf("Invoke-ImportPhase") < smokeBody.indexOf("Invoke-PluginSmoke"));
  assert.ok(buildBody.indexOf("Invoke-ImportPhase") < buildBody.indexOf("Install-BridgeAar"));
  assert.ok(buildBody.indexOf("Install-BridgeAar") < buildBody.indexOf("Invoke-PluginSmoke"));
  assert.ok(buildBody.indexOf("Invoke-PluginSmoke") < buildBody.indexOf("--export-debug"));
  assert.match(buildBody, /Invoke-ExportObserved[\s\S]*--export-debug/);
  assert.doesNotMatch(buildBody, /Invoke-NativeTimed[\s\S]*--export-debug/);
  assert.match(buildBody, /completion_seen/);
  assert.match(buildBody, /apk_verified/);
  assert.match(buildBody, /forced_shutdown/);

  const forbiddenAutomaticNames = "Args|Input|Matches|Error|PID|Host|HOME|PWD|PSScriptRoot|PSCommandPath|PSHOME|PSVersionTable|ShellId";
  assert.doesNotMatch(buildTool, new RegExp(`function[^\\n]*\\$(?:${forbiddenAutomaticNames})\\b`, "i"));
  assert.doesNotMatch(buildTool, new RegExp(`^\\s*(?:\\[[^\\r\\n]+\\]\\s*)?\\$(?:${forbiddenAutomaticNames})\\s*=`, "im"));
});


test("CI reproduces disposable import/plugin smoke before physical-device build while native build proves debug-release separation", () => {
  assert.match(workflow, /Android Account-Bound Transport Device Bridge QA/);
  assert.match(workflow, /NO APK \/ NO DEVICE/);
  assert.match(workflow, /android_account_bound_transport_device_source_boundary\.test\.mjs/);
  assert.match(workflow, /System\.Management\.Automation\.Language\.Parser/);
  assert.match(workflow, /android_account_bound_transport_device_build_qa\.ps1/);
  assert.match(workflow, /-Action Audit/);
  assert.match(workflow, /-Action ExportWatcherSelfTest/);
  assert.match(workflow, /synthetic APK/);
  assert.match(workflow, /\$watcherExitCode = \$LASTEXITCODE/);
  assert.match(workflow, /-Action ExportWatcherSelfTest/);
  assert.match(workflow, /\'-Action\', \'Smoke\'/);
  assert.match(workflow, /Get-Command pwsh -CommandType Application/);
  assert.match(workflow, /'-NonInteractive'/);
  assert.match(workflow, /\$smokeExitCode = \$LASTEXITCODE/);
  assert.match(workflow, /1> \$smokeStdout 2> \$smokeStderr/);
  assert.doesNotMatch(workflow, /\$output\s*=\s*&\s*\.\/tools\/android_account_bound_transport_device_build_qa\.ps1/);
  assert.match(workflow, /ANDROID_ACCOUNT_BOUND_TRANSPORT_BUILD_SMOKE_PASS/);
  assert.match(workflow, /JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_PARSE_PASS/);
  assert.doesNotMatch(workflow, /--export-debug|\badb\s|firebase deploy|DEVICE_QA_PASS/i);

  assert.match(nativeWorkflow, /backend\/cloud_save\/tests\/android_account_bound_transport_device_source_boundary\.test\.mjs/);
  assert.match(nativeWorkflow, /tools\/android_account_bound_transport_device_build_qa\.ps1/);
  assert.match(nativeWorkflow, /JadeAccountBoundTransportDebugBridge\.class/);
  assert.match(nativeWorkflow, /jade_account_bound_transport_device_record\.json/);
  assert.match(nativeWorkflow, /release AAR contains account-bound DEBUG QA bridge/);
  assert.match(nativeWorkflow, /debug AAR missing account-bound QA bridge/);
});
