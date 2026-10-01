/**
 * Gate 4.1A — this test MUST run after installing actual npm packages.
 * Unlike callable_factory.test.mjs, no mocked onCall/HttpsError is used.
 * This tests module resolution + v2 export registration, NOT a deployed route.
 */
import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";

// Resolve packages from the deployed Functions root (a sibling of /tests).
const require = createRequire(new URL("../functions/index.mjs", import.meta.url));

test("pinned real firebase-functions v2 and firebase-admin packages resolve", () => {
  // Many npm packages block require("pkg/package.json") via `exports`.
  // Read the installed files from this isolated package root instead.
  const functions = JSON.parse(readFileSync(
    new URL("../functions/node_modules/firebase-functions/package.json", import.meta.url),
    "utf8",
  ));
  const admin = JSON.parse(readFileSync(
    new URL("../functions/node_modules/firebase-admin/package.json", import.meta.url),
    "utf8",
  ));
  assert.equal(functions.version, "7.4.0");
  assert.equal(admin.version, "14.5.0");
  const https = require("firebase-functions/v2/https");
  assert.equal(typeof https.onCall, "function");
  assert.equal(typeof https.HttpsError, "function");
});

test("production ESM entrypoint loads with real SDK and exports one callable", async () => {
  const deployedModule = await import("../functions/index.mjs");
  assert.deepEqual(Object.keys(deployedModule), ["jadeCloudSaveCapabilities"]);
  const callable = deployedModule.jadeCloudSaveCapabilities;
  assert.equal(typeof callable, "function");
  // Firebase's v2 trigger metadata must be present, not a fake test adapter.
  assert.equal(typeof callable.__endpoint, "object");
  assert.ok(callable.__endpoint !== null);
  assert.equal(callable.__endpoint.platform, "gcfv2");
  assert.equal(typeof callable.run, "function");
});
