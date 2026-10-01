import test from "node:test";
import assert from "node:assert/strict";
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
