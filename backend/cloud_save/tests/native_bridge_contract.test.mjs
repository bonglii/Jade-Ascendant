import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

const root = new URL("../android_bridge/", import.meta.url);
const read = (path) => readFileSync(new URL(path, root), "utf8");

test("isolated native bridge exports ONLY a fixed read-only callable", () => {
  const source = read("bridge/src/main/java/com/yungdevstudio/jadeascendant/cloudbridge/JadeCloudNativeBridge.kt");
  assert.match(source, /getHttpsCallable\("jadeCloudSaveCapabilities"\)/);
  assert.equal((source.match(/getHttpsCallable\(/g) ?? []).length, 1);
  assert.match(source, /\.call\(emptyMap<String, Any>\(\)\)/);
  assert.deepEqual(
    [...source.matchAll(/@UsedByGodot\s+fun\s+(\w+)\s*\(/g)].map(x => x[1]).sort(),
    ["isAppCheckConfigured", "requestReadOnlyCapabilities"]
  );
  assert.doesNotMatch(source, /getIdToken\s*\(|(?:put|set|add|write|delete)Document\s*\(/);
  assert.doesNotMatch(source, /Log\.|printStackTrace\s*\(/);
  const contract = read("bridge/src/main/java/com/yungdevstudio/jadeascendant/cloudbridge/ClosedCapabilitiesContract.kt");
  assert.match(source, /ClosedCapabilitiesContract\.accepts\(data\)/);
  assert.match(contract, /"cloud_write_enabled"/);
  assert.match(contract, /"cloud_restore_enabled"/);
  assert.match(contract, /"purchase_verification_enabled"/);
  assert.match(contract, /"server_freshness_verified"/);
  assert.match(contract, /data\.keys != required/);
  assert.match(source, /user\.isAnonymous/);
  assert.match(source, /GOOGLE_SIGN_IN_REQUIRED/);
  assert.match(source, /current\.uid != requestUid/);
});

test("debug App Check classes/deps are isolated from release Kotlin sources", () => {
  const gradle = read("bridge/build.gradle.kts");
  const debug = read("bridge/src/debug/java/com/yungdevstudio/jadeascendant/cloudbridge/AppCheckProviderInstall.kt");
  const release = read("bridge/src/release/java/com/yungdevstudio/jadeascendant/cloudbridge/AppCheckProviderInstall.kt");
  const common = read("bridge/src/main/java/com/yungdevstudio/jadeascendant/cloudbridge/JadeCloudNativeBridge.kt");
  assert.match(gradle, /debugImplementation\("com\.google\.firebase:firebase-appcheck-debug"\)/);
  assert.match(gradle, /implementation\("com\.google\.firebase:firebase-appcheck-playintegrity"\)/);
  assert.match(debug, /DebugAppCheckProviderFactory/);
  assert.match(release, /PlayIntegrityAppCheckProviderFactory/);
  assert.doesNotMatch(release, /DebugAppCheckProviderFactory/);
  assert.doesNotMatch(common, /DebugAppCheckProviderFactory|PlayIntegrityAppCheckProviderFactory/);
});

test("native QA build cannot silently register Firebase production projects or deploy routes", () => {
  const settings = read("settings.gradle.kts");
  const manifest = read("bridge/src/main/AndroidManifest.xml");
  const shared = read("bridge/build.gradle.kts");
  assert.match(settings, /include\(":bridge"\)/);
  assert.match(manifest, /org\.godotengine\.plugin\.v2\.\$\{godotPluginName\}/);
  assert.match(manifest, /\$\{godotPluginPackageName\}\.JadeCloudNativeBridge/);
  assert.match(shared, /org\.godotengine:godot:4\.7\.2\.stable/);
  assert.doesNotMatch(settings + manifest + shared, /firebase\.deploy|serviceAccount|google-services\.json|firebase\.json/);
});

// Candidate exporter is deliberately not enabled until combined Gradle and
// Android sign-in regression QA. No project/Autoload mutation in this patch.
test("candidate exporter pins read-only dependencies and keeps debug provider out of release", () => {
  const project = readFileSync(new URL("../../../project.godot", import.meta.url), "utf8");
  const legacy = readFileSync(new URL("../../../addons/GodotFirebaseAndroid/export_plugin.gd", import.meta.url), "utf8");
  const candidate = readFileSync(new URL("../../../addons/JadeCloudNativeBridge/export_plugin.gd", import.meta.url), "utf8");
  for (const dep of [
    "com.google.firebase:firebase-auth:23.2.0",
    "com.google.android.gms:play-services-auth:21.3.0",
    "com.google.firebase:firebase-firestore:25.1.4",
  ]) assert.ok(legacy.includes(dep), `legacy dependency drift: ${dep}`);
  assert.ok(!project.includes("res://addons/JadeCloudNativeBridge/plugin.cfg"));
  assert.match(candidate, /class AndroidExportPlugin extends EditorExportPlugin/);
  assert.match(candidate, /firebase-functions:22\.1\.1/);
  assert.match(candidate, /firebase-appcheck-playintegrity:19\.4\.1/);
  assert.match(candidate, /firebase-auth:24\.2\.0/);
  assert.match(candidate, /if debug:\s*dependencies\.append\("com\.google\.firebase:firebase-appcheck-debug:19\.4\.1"\)/);
  assert.doesNotMatch(candidate, /add_autoload_singleton|cloud_write_enabled\s*[:=]\s*true|requestUpload|requestRestore/);
});

test("tracked QA AARs match inspected GitHub Actions artifact", () => {
  const expected = {
    debug: "1f81b5cd3bce6ca2522517c4a517d899cba8693f28a34bfd53d4dcc6cb397c5e",
    release: "7a26620b5342e64636949be8c13b68a0256015222d67d21500f09af53357696b",
  };
  for (const variant of ["debug", "release"]) {
    const bytes = readFileSync(new URL(`../../../addons/JadeCloudNativeBridge/bin/${variant}/JadeCloudNativeBridge-${variant}.aar`, import.meta.url));
    assert.equal(createHash("sha256").update(bytes).digest("hex"), expected[variant]);
  }
});
