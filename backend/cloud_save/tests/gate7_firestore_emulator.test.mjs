/** Gate 7: read-only Restore QA against exact localhost DEMO Firestore Emulator. */
import test, { after } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { assertGate5EmulatorOnly } from "../functions/src/economy/firestore_gate5_emulator_model.mjs";
import {
  seedGate6EmulatorAccount, mintSyntheticServerReconciledFixture,
  commitGate6SyntheticSnapshot, setGate6SyntheticReconciliationHold,
} from "../functions/src/snapshot/firestore_gate6_emulator_model.mjs";
import { reviewGate7LatestSyntheticSnapshot } from "../functions/src/restore/firestore_gate7_readonly_model.mjs";
import { Gate7InMemoryRestoreSandbox } from "../functions/src/restore/reversible_restore_sandbox.mjs";
import { makeGate7SyntheticDraft as draft } from "./gate7_fixture.mjs";

// No Admin SDK import/initialization before verifying exact demo/localhost.
assertGate5EmulatorOnly();
const require = createRequire(new URL("../functions/index.mjs", import.meta.url));
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const app = initializeApp({ projectId: "demo-jade-cloud-save-gate5" }, `gate7-ci-${process.pid}`);
const db = getFirestore(app);
after(() => deleteApp(app));

const account = uid => db.collection("gate6_qa_accounts_v1").doc(uid);
const snap = (uid, rev) => account(uid).collection("qa_snapshots")
  .doc(`rev_${String(rev).padStart(14, "0")}`);
const review = (uid, rev, auth = uid) => reviewGate7LatestSyntheticSnapshot(db, {
  authenticatedUid: auth, ownerUid: uid, expectedRevision: rev,
});
async function seedAndCommit(uid, jade = 20) {
  assert.equal((await seedGate6EmulatorAccount(db, uid)).code, "QA_ACCOUNT_SEEDED");
  const proof = mintSyntheticServerReconciledFixture(draft(uid, jade), uid);
  assert.equal((await commitGate6SyntheticSnapshot(db, {
    authenticatedUid: uid, ownerUid: uid,
    expectedRevision: 0, syntheticProof: proof,
  })).code, "SYNTHETIC_SNAPSHOT_COMMITTED");
  return proof;
}

test("Gate 7 Firestore: consistent latest snapshot read does NOT mutate head/history", async () => {
  const uid = "gate7_emulator_readonly";
  await seedAndCommit(uid, 90);
  const [beforeHead, beforeSnaps] = await Promise.all([account(uid).get(), account(uid).collection("qa_snapshots").get()]);
  const result = await review(uid, 1);
  assert.equal(result.ok, true);
  assert.equal(result.code, "QA_LATEST_SNAPSHOT_REVIEWED");
  assert.equal(result.qaOnly, true);
  assert.equal(result.revision, 1);
  assert.equal(result.draft.domains.pavilion.celestial_jade, 90);
  assert.equal(result.draft.domains.idle_cultivation.last_claim_unix, 1000);
  assert.equal(result.restore_allowed, false);
  assert.equal(result.cloud_mutation_enabled, false);
  const [afterHead, afterSnaps] = await Promise.all([account(uid).get(), account(uid).collection("qa_snapshots").get()]);
  assert.deepEqual(afterHead.data(), beforeHead.data());
  assert.deepEqual(afterSnaps.docs.map(s => s.data()), beforeSnaps.docs.map(s => s.data()));
});

test("Gate 7 Firestore: unknown, fake-auth, cross-owner and zero revision blocked", async () => {
  const uid = "gate7_emulator_auth";
  await seedAndCommit(uid);
  assert.equal((await review(uid, 1, "")).code, "UNAUTHENTICATED");
  assert.equal((await review(uid, 1, "other_user")).code, "FOREIGN_ACCOUNT");
  assert.equal((await review(uid, 0)).code, "INVALID_EXPECTED_REVISION");
  assert.equal((await review("missing_uid", 1)).code, "ACCOUNT_NOT_FOUND");
});

test("Gate 7 Firestore: cannot restore history after concurrent newer server revision", async () => {
  const uid = "gate7_emulator_stale";
  await seedAndCommit(uid, 10);
  assert.equal((await review(uid, 1)).ok, true);
  const next = mintSyntheticServerReconciledFixture(draft(uid, 30), uid);
  assert.equal((await commitGate6SyntheticSnapshot(db, {
    authenticatedUid: uid, ownerUid: uid, expectedRevision: 1, syntheticProof: next,
  })).code, "SYNTHETIC_SNAPSHOT_COMMITTED");
  assert.equal((await review(uid, 1)).code, "SERVER_REVISION_CHANGED");
  assert.equal((await review(uid, 2)).ok, true);
  assert.equal((await account(uid).get()).data().revision, 2);
});

test("Gate 7 Firestore: reconciliation hold blocks restore even if snapshot exists", async () => {
  const uid = "gate7_emulator_hold";
  await seedAndCommit(uid);
  await setGate6SyntheticReconciliationHold(db, uid);
  assert.equal((await review(uid, 1)).code, "ECONOMY_RECONCILIATION_HOLD");
  assert.equal((await account(uid).get()).data().revision, 1);
});

test("Gate 7 Firestore: mismatched immutable digest or metadata refuses restore", async () => {
  const a = "gate7_emulator_digest", b = "gate7_emulator_metadata";
  await seedAndCommit(a);
  await seedAndCommit(b);
  await snap(a, 1).update({ syntheticDigest: "a".repeat(64) }); // Synthetic corruption ONLY.
  assert.equal((await review(a, 1)).code, "SNAPSHOT_DIGEST_MISMATCH");
  await snap(b, 1).update({ domainCount: 6 });
  assert.equal((await review(b, 1)).code, "INVALID_SNAPSHOT_METADATA");
});

test("Gate 7 Firestore: injected raw Play token and incomplete domain rejected before transfer", async () => {
  const a = "gate7_emulator_raw_token", b = "gate7_emulator_no_idle";
  await seedAndCommit(a);
  await seedAndCommit(b);
  await snap(a, 1).update({ "domains.pavilion.processed_grant_ids": [
    "iap:jade_pouch_100:SYNTHETIC_PRIVATE_TOKEN_NEVER_PRINT",
  ] });
  assert.equal((await review(a, 1)).code, "INVALID_SNAPSHOT_CONTENT");
  await snap(b, 1).update({ "domains.idle_cultivation": null });
  assert.equal((await review(b, 1)).code, "INVALID_SNAPSHOT_CONTENT");
});

test("Gate 7 Firestore: missing current snapshot is rejected, not replaced with older", async () => {
  const uid = "gate7_emulator_missing";
  await seedAndCommit(uid);
  await snap(uid, 1).delete(); // QA corruption only; not a game operation.
  assert.equal((await review(uid, 1)).code, "SNAPSHOT_NOT_FOUND");
  assert.equal((await account(uid).get()).data().revision, 1);
});

test("Gate 7 end-to-end emulator READ + local RAM rollback changes ZERO server writes", async () => {
  const uid = "gate7_emulator_device";
  await seedAndCommit(uid, 100);
  const reviewed = await review(uid, 1);
  assert.equal(reviewed.ok, true);
  const local = new Gate7InMemoryRestoreSandbox(uid, draft(uid, 25));
  const before = await account(uid).get();
  assert.equal(local.prepare({ authenticatedUid: uid, consent: true,
    serverReadOnlyRecord: reviewed }).code, "SANDBOX_REVIEW_PREPARED");
  assert.equal(local.apply({ authenticatedUid: uid, currentServerRevision: 1,
    currentServerDigest: reviewed.digest, faultAfterDomains: 9 }).code, "SANDBOX_ROLLED_BACK");
  assert.equal(local.inspectLocalForQa().domains.pavilion.celestial_jade, 25);
  assert.deepEqual((await account(uid).get()).data(), before.data());
  assert.equal((await account(uid).collection("qa_snapshots").get()).size, 1);
});
