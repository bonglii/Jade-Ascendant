import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createCallableHandlers } from "../functions/src/callable_factory.mjs";

function setup() {
  const registered = [];
  class FakeHttpsError extends Error {
    constructor(code, message) { super(message); this.code = code; }
  }
  const onCall = (options, fn) => {
    registered.push({ options, fn });
    return fn;
  };
  return {
    ...createCallableHandlers({ onCall, HttpsError: FakeHttpsError }),
    registered,
  };
}

function request() {
  return {
    auth: {
      uid: "fake_qa_auth",
      token: {
        firebase: {
          sign_in_provider: "google.com",
          identities: { "google.com": ["fake_google_sub"] },
        },
      },
    },
    data: {},
  };
}

test("exactly one read-only callable route is registered", () => {
  const { registered, ...routes } = setup();
  assert.deepEqual(Object.keys(routes), ["jadeCloudSaveCapabilities"]);
  assert.equal(registered.length, 1);
  assert.equal(typeof routes.jadeCloudSaveCapabilities, "function");
  const opts = registered[0].options;
  assert.equal(opts.enforceAppCheck, true);
  assert.equal(opts.region, "asia-southeast2");
  assert.equal(opts.maxInstances, 1);
  assert.equal(opts.timeoutSeconds, 10);
  assert.equal(opts.memory, "256MiB");
});

test("callable success stays read-only and never returns verified economy claims", () => {
  const { jadeCloudSaveCapabilities: invoke } = setup();
  const data = invoke(request());
  assert.equal(data.cloud_write_enabled, false);
  assert.equal(data.cloud_restore_enabled, false);
  assert.equal(data.economy_verified, false);
  assert.equal(data.server_revision_verified, false);
  assert.equal(data.purchase_verification_enabled, false);
});

test("callable errors are mapped to Firebase HttpsError codes", () => {
  const { jadeCloudSaveCapabilities: invoke } = setup();
  assert.throws(() => invoke({ data: {} }), err => err.code === "unauthenticated");
  const anonymous = request();
  anonymous.auth.token.firebase.sign_in_provider = "anonymous";
  assert.throws(() => invoke(anonymous), err => err.code === "permission-denied");
  const payload = request();
  payload.data = { owner_uid: "other" };
  assert.throws(() => invoke(payload), err => err.code === "invalid-argument");
});

test("refuses a missing runtime adapter rather than creating a fake route", () => {
  assert.throws(() => createCallableHandlers({}), TypeError);
  assert.throws(() => createCallableHandlers({ onCall() {} }), TypeError);
});


test("production entrypoint exports only the read-only callable", () => {
  // Static export audit until the actual firebase-functions npm package is
  // installed and the Firebase emulator can instantiate the entrypoint.
  const source = readFileSync(new URL("../functions/index.mjs", import.meta.url), "utf8");
  assert.match(source, /export const \{ jadeCloudSaveCapabilities \}/);
  assert.equal((source.match(/\bexport\s+const\s*\{/g) ?? []).length, 1);
  assert.doesNotMatch(source, /\bexport\s+(?:function|async|class)\b/);
});

test("unexpected runtime errors are sanitized rather than leaked", () => {
  const { jadeCloudSaveCapabilities: invoke } = setup();
  const poisoned = { data: {} };
  Object.defineProperty(poisoned, "auth", {
    get() { throw new Error("private_token_never_return"); },
  });
  assert.throws(() => invoke(poisoned), error =>
    error.code === "internal"
    && !String(error.message).includes("private_token_never_return")
  );
});
