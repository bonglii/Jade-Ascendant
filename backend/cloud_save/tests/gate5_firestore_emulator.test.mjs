/**
 * Real Firestore Emulator-only transaction regression. No actual Firebase
 * project, user, payment, service account key or deployment. Admin client is
 * loaded ONLY after verifying explicit localhost demo-project isolation.
 */
import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { createRequire } from "node:module";
import {
  assertGate5EmulatorOnly, seedGate5EmulatorAccount,
  applyGate5EmulatorVerifiedFixture, recordGate5SyntheticVoid,
} from "../functions/src/economy/firestore_gate5_emulator_model.mjs";
import { verifyPlayPurchaseV2 } from "../functions/src/economy/play_purchase_v2.mjs";

// GUARANTEE no Admin SDK initialization or network attempt on wrong environment.
assertGate5EmulatorOnly();
const require = createRequire(new URL("../functions/index.mjs", import.meta.url));
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const app = initializeApp({ projectId: "demo-jade-cloud-save-gate5" }, `gate5-ci-${process.pid}`);
const db = getFirestore(app);
const HASH = createHash("sha256").update("fixture_a").digest("hex");
const KEY = Buffer.alloc(32, 0x33); // synthetic test fixture ONLY

async function makeProof(token, playId = "jade_pouch_100", jade = 100) {
  return verifyPlayPurchaseV2({
    reader: { getPurchase: async () => ({
      kind: "androidpublisher#productPurchaseV2",
      purchaseStateContext: { purchaseState: "PURCHASED" },
      productLineItem: [{ productId: playId, productOfferDetails: {
        quantity: 1, refundableQuantity: 1,
        consumptionState: "CONSUMPTION_STATE_YET_TO_BE_CONSUMED",
      } }],
      purchaseCompletionTime: "2026-10-01T12:00:00Z",
      acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
      obfuscatedExternalAccountId: HASH,
    }) },
    purchaseToken: token, playProductId: playId,
    expectedObfuscatedAccountId: HASH, fingerprintSecret: KEY,
  });
}

const readAccount = uid => db.collection("gate5_qa_accounts_v1").doc(uid).get().then(s => s.data());
const ledger = fp => db.collection("gate5_qa_global_ledger_v1").doc(fp).get();
const event = (uid, fp) => db.collection("gate5_qa_accounts_v1").doc(uid)
  .collection("qa_events").doc(fp).get();

test("Gate 5 Firestore transaction: account + ledger + event move atomically once", async () => {
  const uid = "test_emulator_first";
  assert.equal((await seedGate5EmulatorAccount(db, uid)).ok, true);
  const proof = await makeProof("emulator_synthetic_purchase_first");
  assert.deepEqual(await applyGate5EmulatorVerifiedFixture(db, {
    ownerUid: uid, expectedRevision: 0, proof,
  }), { ok: true, code: "APPLIED", revision: 1, grant: 100 });
  assert.deepEqual(await readAccount(uid), { revision: 1, celestialJade: 100, hold: false });
  assert.equal((await ledger(proof.fingerprint)).data().ownerUid, uid);
  assert.equal((await event(uid, proof.fingerprint)).data().grant, 100);
  assert.deepEqual(await applyGate5EmulatorVerifiedFixture(db, {
    ownerUid: uid, expectedRevision: 0, proof,
  }), { ok: true, code: "ALREADY_APPLIED", revision: 1, grant: 0 });
  assert.deepEqual(await readAccount(uid), { revision: 1, celestialJade: 100, hold: false });
});

test("Gate 5 Firestore: global duplicate token cannot credit second user", async () => {
  const a = "test_emulator_second_a", b = "test_emulator_second_b";
  await seedGate5EmulatorAccount(db, a);
  await seedGate5EmulatorAccount(db, b);
  const proof = await makeProof("emulator_synthetic_purchase_cross_user");
  assert.equal((await applyGate5EmulatorVerifiedFixture(db, { ownerUid: a, expectedRevision: 0, proof })).code, "APPLIED");
  assert.equal((await applyGate5EmulatorVerifiedFixture(db, { ownerUid: b, expectedRevision: 0, proof })).code, "TOKEN_BOUND_TO_OTHER_ACCOUNT");
  assert.equal((await readAccount(b)).celestialJade, 0);
});

test("Gate 5 Firestore: two-device stale revision rejected without ledger reservation", async () => {
  const uid = "test_emulator_cas";
  await seedGate5EmulatorAccount(db, uid);
  const first = await makeProof("emulator_synthetic_purchase_cas_01");
  const second = await makeProof("emulator_synthetic_purchase_cas_02");
  assert.equal((await applyGate5EmulatorVerifiedFixture(db, { ownerUid: uid, expectedRevision: 0, proof: first })).code, "APPLIED");
  assert.equal((await applyGate5EmulatorVerifiedFixture(db, { ownerUid: uid, expectedRevision: 0, proof: second })).code, "REVISION_CONFLICT");
  assert.equal((await ledger(second.fingerprint)).exists, false);
  assert.equal((await applyGate5EmulatorVerifiedFixture(db, { ownerUid: uid, expectedRevision: 1, proof: second })).code, "APPLIED");
  assert.equal((await readAccount(uid)).revision, 2);
});

test("Gate 5 Firestore: concurrent same-token requests cannot double-grant", async () => {
  const uid = "test_emulator_concurrent";
  await seedGate5EmulatorAccount(db, uid);
  const p = await makeProof("emulator_synthetic_purchase_concurrency");
  const calls = Array.from({ length: 5 }, () => applyGate5EmulatorVerifiedFixture(db, {
    ownerUid: uid, expectedRevision: 0, proof: p,
  }));
  const results = await Promise.all(calls);
  assert.equal(results.filter(r => r.code === "APPLIED").length, 1);
  assert.ok(results.every(r => ["APPLIED", "ALREADY_APPLIED", "EMULATOR_TRANSACTION_UNAVAILABLE"].includes(r.code)));
  assert.equal((await readAccount(uid)).celestialJade, 100);
  assert.equal((await readAccount(uid)).revision, 1);
  assert.equal((await event(uid, p.fingerprint)).exists, true);
});

test("Gate 5 Firestore: tombstone prevents replay and puts credited account on HOLD", async () => {
  const uid = "test_emulator_void";
  await seedGate5EmulatorAccount(db, uid);
  const early = await makeProof("emulator_synthetic_purchase_void_future");
  assert.equal((await recordGate5SyntheticVoid(db, early.fingerprint)).code, "VOID_RECONCILIATION_HOLD");
  assert.equal((await applyGate5EmulatorVerifiedFixture(db, { ownerUid: uid, expectedRevision: 0, proof: early })).code, "ECONOMY_RECONCILIATION_HOLD");
  const paid = await makeProof("emulator_synthetic_purchase_void_paid");
  assert.equal((await applyGate5EmulatorVerifiedFixture(db, { ownerUid: uid, expectedRevision: 0, proof: paid })).code, "APPLIED");
  assert.equal((await recordGate5SyntheticVoid(db, paid.fingerprint)).code, "VOID_RECONCILIATION_HOLD");
  assert.equal((await recordGate5SyntheticVoid(db, paid.fingerprint)).code, "VOID_ALREADY_RECORDED");
  const a = await readAccount(uid);
  assert.equal(a.celestialJade, 100); // not blindly subtracted
  assert.equal(a.hold, true);
  assert.equal((await applyGate5EmulatorVerifiedFixture(db, { ownerUid: uid, expectedRevision: 1, proof: await makeProof("emulator_synthetic_purchase_void_third") })).code, "ECONOMY_RECONCILIATION_HOLD");
});

test("Gate 5 Firestore: client-shaped fake proof and non-existing user remain denied", async () => {
  const uid = "test_emulator_forged";
  await seedGate5EmulatorAccount(db, uid);
  const p = await makeProof("emulator_synthetic_purchase_rogue");
  assert.equal((await applyGate5EmulatorVerifiedFixture(db, { ownerUid: uid, expectedRevision: 0, proof: { ...p } })).code, "UNVERIFIED_PURCHASE");
  assert.equal((await applyGate5EmulatorVerifiedFixture(db, { ownerUid: "missing", expectedRevision: 0, proof: p })).code, "ACCOUNT_NOT_FOUND");
  assert.equal((await ledger(p.fingerprint)).exists, false);
});
