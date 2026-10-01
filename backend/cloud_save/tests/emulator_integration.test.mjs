/**
 * Gate 4.1B — REAL local Auth + Functions Emulator HTTP boundary QA.
 * Only executes with JADE_CLOUD_EMULATOR_TEST=1 and a demo-* project.
 * It deliberately uses NO real Google account, App Check credential,
 * production project, billing token, Firestore, or player save.
 *
 * Emulator App Check tokens are NOT production attestations. This suite
 * verifies enforcement wiring only; Android + Play Integrity QA is separate.
 */
import test from "node:test";
import assert from "node:assert/strict";

const PROJECT_ID = "demo-jade-cloud-save-gate41";
const AUTH_ORIGIN = "http://127.0.0.1:9099";
const CALLABLE_URL =
  `http://127.0.0.1:5001/${PROJECT_ID}/asia-southeast2/jadeCloudSaveCapabilities`;
const EMULATOR_APP_CHECK = "gate41_emulator_test_only_no_attestation";

if (process.env.JADE_CLOUD_EMULATOR_TEST !== "1" ||
    process.env.GCLOUD_PROJECT !== PROJECT_ID ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== "127.0.0.1:9099") {
  throw new Error("Refusing Cloud Save emulator QA outside the explicit demo project.");
}

async function postJson(url, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(10_000),
  });
  return { status: response.status, payload: await response.json() };
}

async function fakeGoogleSignIn(sub) {
  // As documented by Firebase Auth Emulator: mock IdP credential is a JSON
  // literal rather than an actual Google OAuth token. Never use outside QA.
  const credential = JSON.stringify({
    sub,
    email: `${sub}@example.invalid`,
    email_verified: true,
  });
  const { status, payload } = await postJson(
    `${AUTH_ORIGIN}/identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=emulator-only`,
    {
      postBody: new URLSearchParams({
        id_token: credential,
        providerId: "google.com",
      }).toString(),
      requestUri: "http://localhost",
      returnSecureToken: true,
      returnIdpCredential: true,
    },
  );
  assert.equal(status, 200, `Auth Emulator mock Google session failed: ${JSON.stringify(payload.error ?? {})}`);
  assert.equal(typeof payload.idToken, "string");
  return payload.idToken;
}

async function fakeAnonymousSignIn() {
  const { status, payload } = await postJson(
    `${AUTH_ORIGIN}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-only`,
    { returnSecureToken: true },
  );
  assert.equal(status, 200, "Auth Emulator anonymous session failed");
  assert.equal(typeof payload.idToken, "string");
  return payload.idToken;
}

async function fakeEmailSignIn() {
  const { status, payload } = await postJson(
    `${AUTH_ORIGIN}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-only`,
    {
      email: "qa-password@example.invalid",
      password: "qa-test-password-only-12345",
      returnSecureToken: true,
    },
  );
  assert.equal(status, 200, "Auth Emulator password session failed");
  assert.equal(typeof payload.idToken, "string");
  return payload.idToken;
}

async function callable(data, { token, appCheck = true } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (token !== undefined) headers.Authorization = `Bearer ${token}`;
  if (appCheck) headers["X-Firebase-AppCheck"] = EMULATOR_APP_CHECK;
  const response = await fetch(CALLABLE_URL, {
    method: "POST",
    headers,
    body: JSON.stringify({ data }),
    signal: AbortSignal.timeout(15_000),
  });
  return { status: response.status, payload: await response.json() };
}

function expectCode(response, code) {
  assert.ok(response.status >= 400, `Expected ${code}, got HTTP ${response.status}`);
  assert.equal(response.payload?.error?.status, code);
  assert.equal(response.payload?.result, undefined);
}

function expectClosed(response) {
  assert.equal(response.status, 200, JSON.stringify(response.payload?.error ?? {}));
  const result = response.payload?.result;
  assert.equal(result?.capabilities_contract_version, 1);
  assert.equal(result?.state, "cloud_save_disabled");
  for (const field of [
    "cloud_write_enabled", "cloud_restore_enabled", "purchase_verification_enabled",
    "economy_verified", "server_revision_verified", "server_freshness_verified",
  ]) assert.equal(result?.[field], false, field);
  assert.ok(!("uid" in result) && !("owner_uid" in result));
  assert.ok(!("token" in result) && !("snapshot" in result));
}

test("real emulator: callable stays fail-closed across verified-runtime identity boundaries", async () => {
  const googleA = await fakeGoogleSignIn("gate41-google-a");
  const googleB = await fakeGoogleSignIn("gate41-google-b");
  const anonymous = await fakeAnonymousSignIn();
  const emailPassword = await fakeEmailSignIn();

  // Firebase runtime must reject missing/invalid auth regardless of claims in data.
  expectCode(await callable({}, { token: undefined }), "UNAUTHENTICATED");
  expectCode(await callable({}, { token: "not-a-firebase-token" }), "UNAUTHENTICATED");
  expectCode(await callable({ uid: "gate41-google-a" }), "UNAUTHENTICATED");

  // The emulator can confirm App Check header enforcement, NOT authenticity.
  expectCode(await callable({}, { token: googleA, appCheck: false }), "UNAUTHENTICATED");

  expectCode(await callable({}, { token: anonymous }), "PERMISSION_DENIED");
  expectCode(await callable({}, { token: emailPassword }), "PERMISSION_DENIED");

  // The authenticated Google context comes from emulator-verified Firebase Auth.
  expectClosed(await callable({}, { token: googleA }));
  expectClosed(await callable({}, { token: googleB }));
  expectClosed(await callable({}, { token: googleA }));

  for (const badData of [
    { uid: "gate41-google-b" },
    { owner_uid: "gate41-google-a" },
    { revision: 100 },
    { currency: 99999999 },
    { purchase_token: "fake-test-token" },
    { operation: "upload", snapshot: { domains: {} } },
    { operation: "restore" },
    { operation: "grant", entitlement: "premium" },
    null,
    [],
    "{}",
  ]) expectCode(await callable(badData, { token: googleA }), "INVALID_ARGUMENT");
});
