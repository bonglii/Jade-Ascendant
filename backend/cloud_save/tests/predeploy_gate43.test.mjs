/**
 * Gate 4.3: executable PRE-DEPLOYMENT drift checks.
 * This suite runs without Firebase credentials, outbound network or a live
 * project. Passing tests never authorizes a deploy or validates App Check.
 */
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { createCallableHandlers } from "../functions/src/callable_factory.mjs";

const REPO_ROOT = fileURLToPath(new URL("../../../", import.meta.url));
const source = path => readFileSync(resolve(REPO_ROOT, path), "utf8");
const json = path => JSON.parse(source(path));
const gate = json("backend/cloud_save/predeploy_gate.json");

function instrumentedCallable() {
  const routes = [];
  class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  const exports = createCallableHandlers({
    onCall(options, handler) {
      routes.push({ options, handler });
      return handler;
    },
    HttpsError,
  });
  return { exports, routes };
}

function verifiedTestGoogle() {
  // TEST FIXTURE ONLY: Firebase production MUST verify this context itself.
  return {
    auth: {
      uid: "synthetic_google_user",
      token: {
        firebase: {
          sign_in_provider: "google.com",
          identities: { "google.com": ["synthetic_google_subject"] },
        },
      },
    },
    data: {},
  };
}

test("4.3 deployment remains explicitly blocked pending owner sign-off", () => {
  assert.equal(gate.contract_version, 1);
  assert.equal(gate.state, "PRE_DEPLOYMENT_ONLY");
  assert.equal(gate.firebase_project_id, null);
  assert.equal(gate.deployment_approved, false);
  assert.equal(gate.cloud_mutations_approved, false);
  assert.equal(gate.firestore_rules_changes_approved, false);
  const required = [
    "explicit_firebase_project_id_and_separate_test_environment",
    "billing_plan_and_cost_estimate",
    "billing_alerts_and_eligible_spend_cap_review",
    "dedicated_least_privilege_runtime_service_account",
    "android_app_check_registration_and_signing_fingerprints",
    "live_firestore_rules_readback_and_iam_audit",
    "android_debug_token_test_only_and_secret_handling",
    "logging_monitoring_alerts_and_manual_rollback",
    "named_owner_deploy_approval",
  ];
  assert.deepEqual(gate.required_human_checks, required);
});

test("4.3 runtime exposes only one bounded App Check callable", () => {
  const { exports, routes } = instrumentedCallable();
  assert.deepEqual(Object.keys(exports), gate.approved_callable_exports);
  assert.deepEqual(gate.approved_callable_exports, ["jadeCloudSaveCapabilities"]);
  assert.equal(routes.length, 1);
  const opts = routes[0].options;
  assert.equal(opts.enforceAppCheck, gate.enforce_app_check);
  assert.equal(opts.enforceAppCheck, true);
  assert.equal(opts.region, gate.region);
  assert.equal(opts.region, "asia-southeast2");
  assert.equal(opts.maxInstances, gate.max_instances);
  assert.equal(opts.maxInstances, 1);
  assert.equal(opts.minInstances ?? 0, 0); // No always-on idle instances.
  assert.equal(opts.memory, `${gate.max_memory_mib}MiB`);
  assert.equal(opts.timeoutSeconds, gate.max_timeout_seconds);
  assert.equal(opts.preserveExternalChanges ?? false, false);
  // maxInstances is a scaling limit, NOT a Cloud Billing hard spending cap.
});

test("4.3 runtime rejects caller financial claims and never signals cloud enabled", () => {
  const { routes } = instrumentedCallable();
  const invoke = routes[0].handler;
  const response = invoke(verifiedTestGoogle());
  assert.deepEqual(response, {
    capabilities_contract_version: 1,
    state: "cloud_save_disabled",
    cloud_write_enabled: false,
    cloud_restore_enabled: false,
    purchase_verification_enabled: false,
    economy_verified: false,
    server_revision_verified: false,
    server_freshness_verified: false,
  });
  for (const value of [
    { uid: "synthetic_google_user" },
    { balance: 1000000 },
    { purchase_token: "forged" },
    { snapshot: {} },
    { revision: 999 },
    { upload: true },
    { restore: true },
  ]) {
    const request = verifiedTestGoogle();
    request.data = value;
    assert.throws(() => invoke(request), error => error.code === "invalid-argument");
  }
  const noGoogle = verifiedTestGoogle();
  noGoogle.auth.token.firebase.sign_in_provider = "anonymous";
  assert.throws(() => invoke(noGoogle), error => error.code === "permission-denied");
});

test("4.3 Firebase project config is emulator-only and cannot select a live target", () => {
  const cfg = json("backend/cloud_save/firebase.json");
  assert.deepEqual(Object.keys(cfg).sort(), ["emulators", "functions", "singleProjectMode"]);
  assert.equal(cfg.singleProjectMode, true);
  assert.deepEqual(cfg.functions, [{
    source: "functions",
    codebase: gate.approved_codebase,
  }]);
  assert.deepEqual(cfg.emulators.auth, { host: "127.0.0.1", port: 9099 });
  assert.deepEqual(cfg.emulators.functions, { host: "127.0.0.1", port: 5001 });
  assert.equal(cfg.emulators.ui.enabled, false);
  assert.equal(cfg.firestore, undefined);
  assert.equal(cfg.storage, undefined);
});

test("4.3 pinned Node dependencies and import boundary remain unchanged", () => {
  const pkg = json("backend/cloud_save/functions/package.json");
  const lock = json("backend/cloud_save/functions/package-lock.json");
  assert.equal(pkg.engines.node, "22");
  assert.equal(pkg.type, "module");
  assert.equal(pkg.main, "index.mjs");
  assert.deepEqual(pkg.dependencies, {
    "firebase-functions": "7.4.0",
    "firebase-admin": "14.5.0",
  });
  assert.equal(lock.lockfileVersion, 3);
  assert.deepEqual(lock.packages[""].dependencies, pkg.dependencies);
  assert.equal(lock.packages["node_modules/firebase-functions"].version, "7.4.0");
  assert.equal(lock.packages["node_modules/firebase-admin"].version, "14.5.0");
  assert.equal(pkg.scripts?.deploy, undefined);
  assert.equal(pkg.scripts?.postinstall, undefined);

  const entry = source("backend/cloud_save/functions/index.mjs");
  assert.match(entry, /export const\s*\{\s*jadeCloudSaveCapabilities\s*\}/);
  assert.equal((entry.match(/\bexport\s+const\s*\{/g) ?? []).length, 1);
  const runtimeSources = [
    entry,
    source("backend/cloud_save/functions/src/callable_factory.mjs"),
    source("backend/cloud_save/functions/src/read_only_policy.mjs"),
  ].join("\n");
  // The installed firebase-admin package is not evidence of permission to use it.
  assert.doesNotMatch(runtimeSources, /\b(?:from\s*|require\(\s*|import\s*\(\s*)["']firebase-admin(?:\/[^"']*)?["']/);
  assert.doesNotMatch(runtimeSources, /\b(?:set|update|delete)Doc\s*\(|\bbatch\.commit\s*\(/);
});

test("4.3 workflows cannot auto-deploy or access production credentials", () => {
  const workflows = [
    source(".github/workflows/godot-smoke-qa.yml"),
    source(".github/workflows/cloud-native-bridge-qa.yml"),
  ];
  for (const workflow of workflows) {
    const nonCommentLines = workflow.split(/\r?\n/)
      .map(line => line.trim())
      .filter(line => line !== "" && !line.startsWith("#"));
    const executableText = nonCommentLines.join("\n");
    assert.doesNotMatch(executableText, /\b(?:firebase|gcloud)\s+(?:deploy|functions\s+deploy|run\s+deploy)\b/);
    assert.doesNotMatch(executableText, /\$\{\{\s*secrets\./);
    assert.doesNotMatch(executableText, /\b(?:serviceAccountKey|GOOGLE_APPLICATION_CREDENTIALS)\s*[:=]/);
    assert.match(workflow, /qa\/\*\*/);
  }
  assert.match(workflows[0], /demo-jade-cloud-save-gate41/);
  assert.match(workflows[0], /firebase-tools@15\.28\.2\s+emulators:exec/);
  assert.match(workflows[0], /npm\s+--prefix\s+backend\/cloud_save\/functions\s+ci\s+--ignore-scripts/);
});

test("4.3 App Check Android provider remains variant-isolated", () => {
  const debug = source("backend/cloud_save/android_bridge/bridge/src/debug/java/com/yungdevstudio/jadeascendant/cloudbridge/AppCheckProviderInstall.kt");
  const release = source("backend/cloud_save/android_bridge/bridge/src/release/java/com/yungdevstudio/jadeascendant/cloudbridge/AppCheckProviderInstall.kt");
  const exported = source("addons/JadeCloudNativeBridge/export_plugin.gd");
  assert.match(debug, /DebugAppCheckProviderFactory/);
  assert.doesNotMatch(debug, /PlayIntegrityAppCheckProviderFactory/);
  assert.match(release, /PlayIntegrityAppCheckProviderFactory/);
  assert.doesNotMatch(release, /DebugAppCheckProviderFactory/);
  assert.match(exported, /if debug:\s*\n\s*dependencies\.append\("com\.google\.firebase:firebase-appcheck-debug:19\.4\.1"\)/);
  assert.match(exported, /firebase-appcheck-playintegrity:19\.4\.1/);
});
