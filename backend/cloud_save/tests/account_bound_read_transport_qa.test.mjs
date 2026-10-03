/** Account-bound current-snapshot transport QA against localhost DEMO Firestore. */
import test, { after } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { assertGate5EmulatorOnly } from "../functions/src/economy/firestore_gate5_emulator_model.mjs";
import {
  seedGate6EmulatorAccount,
  mintSyntheticServerReconciledFixture,
  commitGate6SyntheticSnapshot,
  setGate6SyntheticReconciliationHold,
} from "../functions/src/snapshot/firestore_gate6_emulator_model.mjs";
import {
  readCurrentAccountBoundSnapshotForQa,
  ACCOUNT_BOUND_READ_TRANSPORT_VERSION,
} from "../functions/src/transport/account_bound_read_transport_qa.mjs";
import { makeGate7SyntheticDraft } from "./gate7_fixture.mjs";

assertGate5EmulatorOnly();
const require = createRequire(new URL("../functions/index.mjs", import.meta.url));
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const app = initializeApp({ projectId: "demo-jade-cloud-save-gate5" }, `account-bound-read-${process.pid}`);
const db = getFirestore(app);
after(() => deleteApp(app));

const account = uid => db.collection("gate6_qa_accounts_v1").doc(uid);
const snap = (uid, rev) => account(uid).collection("qa_snapshots")
  .doc(`rev_${String(rev).padStart(14, "0")}`);
const request = (uid, data = {}) => ({
  auth: {
    uid,
    token: { firebase: {
      sign_in_provider: "google.com",
      identities: { "google.com": ["synthetic_google_subject"] },
    } },
  },
  data,
});
async function seedAndCommit(uid, jade = 1) {
  assert.equal((await seedGate6EmulatorAccount(db, uid)).code, "QA_ACCOUNT_SEEDED");
  const draft = makeGate7SyntheticDraft(uid, jade);
  const proof = mintSyntheticServerReconciledFixture(draft, uid);
  assert.equal((await commitGate6SyntheticSnapshot(db, {
    authenticatedUid: uid, ownerUid: uid, expectedRevision: 0, syntheticProof: proof,
  })).code, "SYNTHETIC_SNAPSHOT_COMMITTED");
}

test("account-bound transport derives owner from auth and returns exact current revision", async () => {
  const uid = "transport_current_owner";
  await seedAndCommit(uid, 10);
  const second = mintSyntheticServerReconciledFixture(makeGate7SyntheticDraft(uid, 25), uid);
  assert.equal((await commitGate6SyntheticSnapshot(db, {
    authenticatedUid: uid, ownerUid: uid, expectedRevision: 1, syntheticProof: second,
  })).code, "SYNTHETIC_SNAPSHOT_COMMITTED");

  const beforeHead = (await account(uid).get()).data();
  const beforeHistory = (await account(uid).collection("qa_snapshots").get()).docs.map(d => d.data());
  const result = await readCurrentAccountBoundSnapshotForQa(db, request(uid));

  assert.equal(result.ok, true);
  assert.equal(result.code, "QA_ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY");
  assert.equal(result.transport_contract_version, ACCOUNT_BOUND_READ_TRANSPORT_VERSION);
  assert.equal(result.ownerUid, uid);
  assert.equal(result.revision, 2);
  assert.equal(result.domain_count, 8);
  assert.equal(result.draft.owner_uid, uid);
  assert.equal(result.draft.domains.pavilion.celestial_jade, 25);
  assert.equal(result.server_revision_verified, true);
  assert.equal(result.server_freshness_verified, true);
  assert.equal(result.explicit_restore_decision_required, true);
  assert.equal(result.restore_allowed, false);
  assert.equal(result.cloud_mutation_enabled, false);
  assert.deepEqual((await account(uid).get()).data(), beforeHead);
  assert.deepEqual((await account(uid).collection("qa_snapshots").get()).docs.map(d => d.data()), beforeHistory);
});

test("client cannot claim owner, revision, digest, currency, token, or restore operation", async () => {
  const uid = "transport_no_client_claims";
  await seedAndCommit(uid);
  const payloads = [
    { owner_uid: uid }, { ownerUid: uid }, { revision: 1 }, { expected_revision: 1 },
    { digest: "a".repeat(64) }, { celestial_jade: 999999 }, { purchase_token: "private" },
    { restore_allowed: true }, { operation: "restore" },
  ];
  for (const data of payloads) {
    const result = await readCurrentAccountBoundSnapshotForQa(db, request(uid, data));
    assert.equal(result.code, "UNSUPPORTED_CLIENT_PAYLOAD");
    assert.equal(result.restore_allowed, false);
    assert.equal(result.cloud_mutation_enabled, false);
  }
});

test("missing or non-Google auth is fail-closed before account read", async () => {
  assert.equal((await readCurrentAccountBoundSnapshotForQa(db, { data: {} })).code,
    "UNAUTHENTICATED_GOOGLE_ACCOUNT");
  const bad = request("transport_bad_provider");
  bad.auth.token.firebase.sign_in_provider = "anonymous";
  assert.equal((await readCurrentAccountBoundSnapshotForQa(db, bad)).code,
    "UNAUTHENTICATED_GOOGLE_ACCOUNT");
});

test("reconciliation hold refuses current snapshot transport", async () => {
  const uid = "transport_hold";
  await seedAndCommit(uid);
  await setGate6SyntheticReconciliationHold(db, uid);
  assert.equal((await readCurrentAccountBoundSnapshotForQa(db, request(uid))).code,
    "ECONOMY_RECONCILIATION_HOLD");
});

test("missing current snapshot never falls back to older history", async () => {
  const uid = "transport_no_history_fallback";
  await seedAndCommit(uid, 10);
  const second = mintSyntheticServerReconciledFixture(makeGate7SyntheticDraft(uid, 20), uid);
  assert.equal((await commitGate6SyntheticSnapshot(db, {
    authenticatedUid: uid, ownerUid: uid, expectedRevision: 1, syntheticProof: second,
  })).code, "SYNTHETIC_SNAPSHOT_COMMITTED");
  await snap(uid, 2).delete();
  assert.equal((await snap(uid, 1).get()).exists, true);
  assert.equal((await readCurrentAccountBoundSnapshotForQa(db, request(uid))).code,
    "CURRENT_SNAPSHOT_NOT_FOUND");
});

test("metadata, digest, incomplete domains and raw Play tokens are refused", async () => {
  const metadata = "transport_bad_metadata";
  await seedAndCommit(metadata);
  await snap(metadata, 1).update({ domainCount: 6 });
  assert.equal((await readCurrentAccountBoundSnapshotForQa(db, request(metadata))).code,
    "INVALID_CURRENT_SNAPSHOT_METADATA");

  const digest = "transport_bad_digest";
  await seedAndCommit(digest);
  await snap(digest, 1).update({ syntheticDigest: "a".repeat(64) });
  assert.equal((await readCurrentAccountBoundSnapshotForQa(db, request(digest))).code,
    "CURRENT_SNAPSHOT_DIGEST_MISMATCH");

  const incomplete = "transport_incomplete";
  await seedAndCommit(incomplete);
  await snap(incomplete, 1).update({ "domains.idle_cultivation": null });
  assert.equal((await readCurrentAccountBoundSnapshotForQa(db, request(incomplete))).code,
    "INVALID_CURRENT_SNAPSHOT_CONTENT");

  const token = "transport_raw_play_token";
  await seedAndCommit(token);
  await snap(token, 1).update({ "domains.pavilion.processed_grant_ids": [
    "iap:jade_pouch_100:SYNTHETIC_PRIVATE_TOKEN_NEVER_TRANSFER",
  ] });
  assert.equal((await readCurrentAccountBoundSnapshotForQa(db, request(token))).code,
    "INVALID_CURRENT_SNAPSHOT_CONTENT");
});
