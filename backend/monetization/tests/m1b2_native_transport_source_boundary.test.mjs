import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../..");
const read = path => readFileSync(resolve(root, path), "utf8");
const blob = path => execFileSync("git", ["hash-object", path], { cwd: root, encoding: "utf8" }).trim();

const bridge = read("backend/monetization/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/JadeMonetizationNativeBridge.kt");
const grantContract = read("backend/monetization/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/SecurePurchaseGrantContract.kt");
const debugAppCheck = read("backend/monetization/android_bridge/bridge/src/debug/java/com/yungdevstudio/jadeascendant/monetizationbridge/AppCheckProviderInstall.kt");
const releaseAppCheck = read("backend/monetization/android_bridge/bridge/src/release/java/com/yungdevstudio/jadeascendant/monetizationbridge/AppCheckProviderInstall.kt");
const gradle = read("backend/monetization/android_bridge/bridge/build.gradle.kts");
const project = read("project.godot");
const boundary = JSON.parse(read("backend/monetization/m1b2_native_transport_boundary.json"));

test("native transport exposes only fixed purchase authority methods", () => {
  assert.equal((bridge.match(/getHttpsCallable\(CALLABLE, callableOptions\)/g) ?? []).length, 1);
  assert.match(bridge, /private const val CALLABLE = "jadeAuthorizePurchase"/);
  assert.match(bridge, /HttpsCallableOptions\.Builder\(\)/);
  assert.match(bridge, /setLimitedUseAppCheckTokens\(true\)/);
  assert.deepEqual(
    [...bridge.matchAll(/@UsedByGodot\s+fun\s+(\w+)\s*\(/g)].map(x => x[1]).sort(),
    ["authorizePurchase", "isSecurePurchaseTransportConfigured"],
  );
  assert.match(bridge, /\.call\(mapOf\("purchase_token" to purchaseTokenValue\)\)/);
  assert.doesNotMatch(
    bridge,
    /getIdToken\s*\(|serviceAccount|firebase\.deploy|Log\.|printStackTrace\s*\(|jadeCloudSave|requestUpload|requestRestore/,
  );
  assert.doesNotMatch(
    bridge,
    /mapOf\([^)]*(?:uid|product_id|celestial_jade|amount|finalize|consume)/s,
  );
});

test("Auth and App Check are SDK-owned and anonymous Firebase identity is allowed", () => {
  assert.match(bridge, /FirebaseAuth\.getInstance\(\)\.currentUser/);
  assert.match(bridge, /if \(user\.isAnonymous\) return true/);
  assert.match(bridge, /GoogleAuthProvider\.PROVIDER_ID/);
  assert.match(bridge, /current\.uid != requestUid/);
  assert.match(bridge, /AppCheckProviderInstall\.install\(app\)/);
});

test("raw purchase token never returns through the Godot signal", () => {
  assert.match(bridge, /emitSignal\("purchaseAuthorityResult", success, status, grantJson\)/);
  assert.doesNotMatch(bridge, /emitSignal\([^)]*purchaseTokenValue/);
  assert.match(bridge, /SecurePurchaseGrantContract\.decode\(task\.result\?\.data\)/);
});

test("server grant decoder is exact and matches the six active Jade packs", () => {
  assert.match(grantContract, /if \(data\.keys != required\) return null/);
  for (const item of [
    '"jade_pouch_100" to 100',
    '"jade_satchel_550" to 550',
    '"jade_casket_1200" to 1200',
    '"jade_vault_2500" to 2500',
    '"jade_treasury_6500" to 6500',
    '"jade_ascendant_14000" to 14000',
  ]) assert.ok(grantContract.includes(item), `missing ${item}`);
  assert.doesNotMatch(grantContract, /starter_support_pack|monthly_jade_blessing/);
});

test("debug App Check is isolated and release uses Play Integrity", () => {
  assert.match(gradle, /debugImplementation\("com\.google\.firebase:firebase-appcheck-debug"\)/);
  assert.match(debugAppCheck, /DebugAppCheckProviderFactory/);
  assert.match(releaseAppCheck, /PlayIntegrityAppCheckProviderFactory/);
  assert.doesNotMatch(releaseAppCheck, /DebugAppCheckProviderFactory/);
});

test("M1B2-A remains disabled and cannot open checkout by itself", () => {
  assert.equal(boundary.state, "NATIVE_TRANSPORT_CANDIDATE_DISABLED");
  for (const key of [
    "production_activation_approved",
    "firebase_callable_runtime_approved",
    "native_purchase_bridge_enabled",
    "tracked_aar_integrated",
    "client_wiring_enabled",
    "secure_purchase_authority_ready",
    "play_checkout_enabled",
    "cloud_save_backend_modification_approved",
    "cloud_bridge_reuse_for_monetization_allowed",
  ]) assert.equal(boundary[key], false, `${key} must remain false`);
  assert.deepEqual(boundary.request_keys, ["purchase_token"]);
  assert.doesNotMatch(project, /JadeMonetizationNativeBridge/);
});

test("locked Cloud Save and M1A production boundaries are unchanged", () => {
  assert.equal(blob("project.godot"), "fe7f658b1e6d4305fad287ce705dac77e7e44a1b");
  assert.equal(blob("backend/cloud_save/functions/index.mjs"), "49126327ec25f8a404a8fe3494424416d6047be6");
  assert.equal(blob("backend/cloud_save/production_approval_boundary.json"), "dcd92ca690dafca510385995e0f4d8a0dc46ba18");
  assert.equal(blob("backend/cloud_save/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/cloudbridge/JadeCloudNativeBridge.kt"), "41d29134205032f50b7886305b2020cf5e287afe");
  assert.equal(blob("backend/monetization/production_approval_boundary.json"), "02c249b931b10c21a90f8c03cc908e8fd0722602");
  assert.equal(blob("backend/monetization/m1b_client_boundary.json"), "b6c4053078d4ed4688177a8fbc5160c9026a002f");
});
