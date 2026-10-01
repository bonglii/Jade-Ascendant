import test from "node:test";
import assert from "node:assert/strict";
import {
  CloudBoundaryError,
  readCloudSaveCapabilities,
  rejectCloudMutation,
} from "../functions/src/read_only_policy.mjs";

function verifiedRequest(data = {}) {
  return {
    auth: {
      uid: "qa_google_user_A-123",
      token: {
        firebase: {
          sign_in_provider: "google.com",
          identities: { "google.com": ["fake_google_identity_1"] },
        },
      },
    },
    data,
  };
}

function rejectsBoundary(callback, code) {
  assert.throws(callback, error =>
    error instanceof CloudBoundaryError && error.code === code
  );
}

test("valid Google-authenticated empty request returns closed capabilities", () => {
  const result = readCloudSaveCapabilities(verifiedRequest());
  assert.equal(result.capabilities_contract_version, 1);
  assert.equal(result.state, "cloud_save_disabled");
  for (const field of [
    "cloud_write_enabled", "cloud_restore_enabled", "purchase_verification_enabled",
    "economy_verified", "server_revision_verified", "server_freshness_verified",
  ]) assert.equal(result[field], false, field);
  assert.equal("owner_uid" in result, false);
  assert.equal("uid" in result, false);
  assert.equal("auth" in result, false);
  assert.equal("token" in result, false);
});

test("auth context is mandatory and UID cannot be supplied by client JSON", () => {
  const invalid = [
    undefined, null, {},
    { data: {} },
    { auth: null, data: {} },
    { auth: { uid: "" }, data: {} },
    { auth: { uid: "bad/path" }, data: {} },
    { auth: { uid: "a".repeat(129) }, data: {} },
    { auth: { uid: 123 }, data: {} },
  ];
  for (const request of invalid) rejectsBoundary(
    () => readCloudSaveCapabilities(request), "unauthenticated"
  );
  rejectsBoundary(() => readCloudSaveCapabilities({ data: { uid: "qa_google_user_A-123" } }), "unauthenticated");
});

test("anonymous/non-Google/malformed Firebase provider claims are denied", () => {
  const variants = [
    null, undefined, {},
    { sign_in_provider: "anonymous", identities: { "google.com": ["fake"] } },
    { sign_in_provider: "password", identities: { "google.com": ["fake"] } },
    { sign_in_provider: "custom", identities: { "google.com": ["fake"] } },
    { sign_in_provider: "google.com" },
    { sign_in_provider: "google.com", identities: { "google.com": [] } },
    { sign_in_provider: "google.com", identities: { "google.com": [""] } },
    { sign_in_provider: "google.com", identities: { "google.com": "string" } },
    { sign_in_provider: "google.com", identities: { "google.com": [23] } },
  ];
  for (const claims of variants) {
    const request = verifiedRequest();
    request.auth.token.firebase = claims;
    rejectsBoundary(() => readCloudSaveCapabilities(request), "permission-denied");
  }
});

test("reject all payload fields even if account is correctly authenticated", () => {
  const fields = [
    { owner_uid: "qa_google_user_A-123" },
    { owner_uid: "other_account" },
    { uid: "qa_google_user_A-123" },
    { revision: 999 },
    { expected_revision: 1 },
    { snapshot: {} },
    { domains: {} },
    { checkpoint: {} },
    { currency: 999999999 },
    { celestial_jade: 999999999 },
    { spirit_stone: 999999999 },
    { entitlements: ["premium"] },
    { verified: true },
    { purchased: true },
    { purchase_token: "fake_token" },
    { operation: "restore" },
    { operation: "upload" },
    { operation: "grant" },
    { operation: "capabilities" },
    JSON.parse('{"__proto__":{"admin":true}}'),
  ];
  for (const data of fields) rejectsBoundary(
    () => readCloudSaveCapabilities(verifiedRequest(data)), "invalid-argument"
  );
});

test("reject invalid envelope types and inherited fields", () => {
  for (const payload of [undefined, null, 1, "", "{}", [], [1], false]) {
    const request = verifiedRequest();
    request.data = payload;
    rejectsBoundary(() => readCloudSaveCapabilities(request), "invalid-argument");
  }
  const inherited = Object.create({ uid: "spoof" });
  rejectsBoundary(
    () => readCloudSaveCapabilities(verifiedRequest(inherited)), "invalid-argument"
  );
  const nullPrototypeEmpty = Object.create(null);
  assert.equal(readCloudSaveCapabilities(verifiedRequest(nullPrototypeEmpty)).cloud_write_enabled, false);
});

test("response is isolated: mutation cannot enable Cloud Save for subsequent calls", () => {
  const first = readCloudSaveCapabilities(verifiedRequest());
  first.cloud_write_enabled = true;
  first.cloud_restore_enabled = true;
  const second = readCloudSaveCapabilities(verifiedRequest());
  assert.equal(second.cloud_write_enabled, false);
  assert.equal(second.cloud_restore_enabled, false);
});

test("explicit mutation guard always rejects, regardless of context", () => {
  for (const request of [undefined, verifiedRequest(), { auth: { uid: "admin" } }]) {
    rejectsBoundary(() => rejectCloudMutation(request), "failed-precondition");
  }
});
