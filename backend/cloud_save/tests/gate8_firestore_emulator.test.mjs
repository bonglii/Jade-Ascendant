/** Gate 8: strict DEMO Firestore Emulator only; no production IAM or Play API. */
import test, { after } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { createRequire } from "node:module";
import { assertGate5EmulatorOnly } from "../functions/src/economy/firestore_gate5_emulator_model.mjs";
import { verifyPlayPurchaseV2 } from "../functions/src/economy/play_purchase_v2.mjs";
import { makeGate7SyntheticDraft } from "./gate7_fixture.mjs";
import {
  seedGate8SyntheticAccount, commitGate8SyntheticPurchase,
  mintGate8SyntheticBoundProof,
  recordGate8SyntheticVoid, reviewGate8SyntheticHead,
} from "../functions/src/integration/firestore_gate8_closed_economy_emulator.mjs";

// Validate all four isolation markers BEFORE Firebase Admin SDK initialization.
assertGate5EmulatorOnly();
const require = createRequire(new URL("../functions/index.mjs", import.meta.url));
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const app = initializeApp({ projectId: "demo-jade-cloud-save-gate5" }, `gate8-ci-${process.pid}`);
const db = getFirestore(app);
after(() => deleteApp(app));

const BINDING = createHash("sha256").update("gate8-synthetic-binding").digest("hex");
const HMAC_KEY = Buffer.alloc(32, 0x73);
const acct = uid => db.collection("gate8_qa_accounts_v1").doc(uid);
const snap = (uid, rev) => acct(uid).collection("qa_snapshots")
  .doc(`rev_${String(rev).padStart(14, "0")}`);
const ledger = fp => db.collection("gate8_qa_global_purchase_ledger_v1").doc(fp);
const voided = fp => db.collection("gate8_qa_void_tombstones_v1").doc(fp);
const event = (uid, fp) => acct(uid).collection("qa_events").doc(fp);
const seed = (uid, jade = 0) => seedGate8SyntheticAccount(db, uid, makeGate7SyntheticDraft(uid, jade));
const commit = (uid, revision, playProof, auth = uid, extra = {}) =>
  commitGate8SyntheticPurchase(db, {
    authenticatedUid: auth, ownerUid: uid, expectedRevision: revision,
    proof: mintGate8SyntheticBoundProof(playProof, uid), ...extra,
  });
const review = (uid, rev, auth = uid) => reviewGate8SyntheticHead(db, {
  authenticatedUid: auth, ownerUid: uid, expectedRevision: rev,
});
async function proofFor(token, playId = "jade_pouch_100") {
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
      obfuscatedExternalAccountId: BINDING,
    }) },
    purchaseToken: token, playProductId: playId,
    expectedObfuscatedAccountId: BINDING, fingerprintSecret: HMAC_KEY,
  });
}

test("Gate 8 creates eight-domain baseline and cannot seed duplicate or malformed accounts", async () => {
  const uid = "gate8_initial";
  assert.equal((await seed(uid, 50)).code, "QA_ACCOUNT_SEEDED");
  assert.equal((await seed(uid, 75)).code, "ACCOUNT_ALREADY_SEEDED");
  const [head, first, summary] = await Promise.all([acct(uid).get(), snap(uid, 0).get(), review(uid, 0)]);
  assert.equal(head.data().revision, 0);
  assert.equal(head.data().celestialJade, 50);
  assert.equal(first.data().domainCount, 8);
  assert.equal(first.data().domains.idle_cultivation.last_claim_unix, 1000);
  assert.equal(summary.code, "QA_HEAD_CONSISTENT");
  assert.equal(summary.restore_allowed, false);
  assert.equal(summary.upload_allowed, false);
  const forged = makeGate7SyntheticDraft("gate8_bad");
  forged.domains.pavilion.processed_grant_ids = ["iap:sku:RAW_TOKEN_NEVER_SEND"];
  assert.equal((await seedGate8SyntheticAccount(db, "gate8_bad", forged)).code, "INVALID_TEST_DRAFT");
  assert.equal((await acct("gate8_bad").get()).exists, false);
});

test("Gate 8 commits global ledger, account head, immutable 8-domain snapshot, and event AT ONCE", async () => {
  const uid = "gate8_atomic";
  assert.equal((await seed(uid, 20)).ok, true);
  const proof = await proofFor("GATE8_SYNTHETIC_TOKEN_ATOMIC_00001", "jade_pouch_550");
  const result = await commit(uid, 0, proof);
  assert.deepEqual(result, { ok: true, code: "SYNTHETIC_PURCHASE_ATOMIC", revision: 1, grant: 550 });
  const [h, old, next, l, e] = await Promise.all([
    acct(uid).get(), snap(uid, 0).get(), snap(uid, 1).get(), ledger(proof.fingerprint).get(),
    event(uid, proof.fingerprint).get(),
  ]);
  assert.equal(h.data().celestialJade, 570);
  assert.equal(h.data().revision, 1);
  assert.equal(old.data().domains.pavilion.celestial_jade, 20);
  assert.equal(next.data().domains.pavilion.celestial_jade, 570);
  assert.equal(next.data().domains.idle_cultivation.last_observed_unix, 1000);
  assert.equal(next.data().domainCount, 8);
  assert.equal(next.data().syntheticDigest, h.data().headDigest);
  assert.equal(l.data().ownerUid, uid);
  assert.equal(l.data().revision, 1);
  assert.equal(e.data().grant, 550);
  for (const item of [h.data(), old.data(), next.data(), l.data(), e.data()]) {
    assert.doesNotMatch(JSON.stringify(item), /GATE8_SYNTHETIC_TOKEN_ATOMIC_00001/);
  }
  assert.equal((await review(uid, 1)).code, "QA_HEAD_CONSISTENT");
});

test("Gate 8 repeated same-token request is idempotent with STALE client revision", async () => {
  const uid = "gate8_idempotent";
  await seed(uid);
  const p = await proofFor("GATE8_SYNTHETIC_TOKEN_IDEMPOTENT_00002");
  assert.equal((await commit(uid, 0, p)).code, "SYNTHETIC_PURCHASE_ATOMIC");
  assert.deepEqual(await commit(uid, 0, p), {
    ok: true, code: "ALREADY_APPLIED", revision: 1, grant: 0,
  });
  assert.equal((await acct(uid).get()).data().celestialJade, 100);
  assert.equal((await acct(uid).collection("qa_snapshots").get()).size, 2);
  assert.equal((await acct(uid).collection("qa_events").get()).size, 1);
});

test("Gate 8 rejects a Play proof not bound to this synthetic account", async () => {
  const uid = "gate8_bound_owner", attacker = "gate8_bound_attacker";
  await Promise.all([seed(uid), seed(attacker)]);
  const raw = await proofFor("GATE8_SYNTHETIC_TOKEN_BOUND_OWNER_00013");
  const boundToOwner = mintGate8SyntheticBoundProof(raw, uid);
  assert.equal((await commitGate8SyntheticPurchase(db, {
    authenticatedUid: attacker, ownerUid: attacker, expectedRevision: 0,
    proof: boundToOwner,
  })).code, "PROOF_ACCOUNT_MISMATCH");
  assert.equal((await commitGate8SyntheticPurchase(db, {
    authenticatedUid: uid, ownerUid: uid, expectedRevision: 0,
    proof: raw,
  })).code, "UNVERIFIED_PURCHASE");
  assert.equal((await acct(uid).get()).data().revision, 0);
  assert.equal((await acct(attacker).get()).data().revision, 0);
});

test("Gate 8 global fingerprint cannot be granted to another account", async () => {
  const a = "gate8_x_owner", b = "gate8_x_intruder";
  await Promise.all([seed(a), seed(b)]);
  const p = await proofFor("GATE8_SYNTHETIC_TOKEN_CROSS_ACCOUNT_00003");
  assert.equal((await commit(a, 0, p)).code, "SYNTHETIC_PURCHASE_ATOMIC");
  assert.equal((await commit(b, 0, p)).code, "TOKEN_BOUND_TO_OTHER_ACCOUNT");
  assert.equal((await acct(b).get()).data().celestialJade, 0);
  assert.equal((await acct(b).get()).data().revision, 0);
});

test("Gate 8 other token with stale revision never reserves global ledger", async () => {
  const uid = "gate8_cas";
  await seed(uid);
  const p1 = await proofFor("GATE8_SYNTHETIC_TOKEN_CAS_00004");
  const p2 = await proofFor("GATE8_SYNTHETIC_TOKEN_CAS_00005");
  assert.equal((await commit(uid, 0, p1)).code, "SYNTHETIC_PURCHASE_ATOMIC");
  assert.equal((await commit(uid, 0, p2)).code, "REVISION_CONFLICT");
  assert.equal((await ledger(p2.fingerprint).get()).exists, false);
  assert.equal((await commit(uid, 1, p2)).code, "SYNTHETIC_PURCHASE_ATOMIC");
  assert.equal((await acct(uid).get()).data().revision, 2);
  assert.equal((await snap(uid, 2).get()).data().domains.pavilion.celestial_jade, 200);
});

test("Gate 8 deliberate throw AFTER all writes are queued rolls back all four writes", async () => {
  const uid = "gate8_transaction_abort";
  await seed(uid, 7);
  const p = await proofFor("GATE8_SYNTHETIC_TOKEN_ABORT_00006");
  const before = (await acct(uid).get()).data();
  assert.equal((await commit(uid, 0, p, uid, { injectQaFailureAfterWrites: true })).code,
    "QA_FAULT_ABORTED");
  assert.deepEqual((await acct(uid).get()).data(), before);
  for (const ref of [snap(uid, 1), ledger(p.fingerprint), event(uid, p.fingerprint)]) {
    assert.equal((await ref.get()).exists, false);
  }
  assert.equal((await commit(uid, 0, p)).code, "SYNTHETIC_PURCHASE_ATOMIC");
  assert.equal((await acct(uid).get()).data().celestialJade, 107);
});

test("Gate 8 synthetic void before grant blocks issuance; post-grant creates HOLD not blind debit", async () => {
  const beforeUid = "gate8_void_before", afterUid = "gate8_void_after";
  await Promise.all([seed(beforeUid), seed(afterUid, 10)]);
  const p1 = await proofFor("GATE8_SYNTHETIC_TOKEN_VOID_BEFORE_00007");
  assert.equal((await recordGate8SyntheticVoid(db, p1.fingerprint)).code, "RECONCILIATION_HOLD_RECORDED");
  assert.equal((await commit(beforeUid, 0, p1)).code, "ECONOMY_RECONCILIATION_HOLD");
  assert.equal((await ledger(p1.fingerprint).get()).exists, false);
  const p2 = await proofFor("GATE8_SYNTHETIC_TOKEN_VOID_AFTER_00008");
  assert.equal((await commit(afterUid, 0, p2)).code, "SYNTHETIC_PURCHASE_ATOMIC");
  assert.equal((await recordGate8SyntheticVoid(db, p2.fingerprint)).code, "RECONCILIATION_HOLD_RECORDED");
  assert.equal((await recordGate8SyntheticVoid(db, p2.fingerprint)).code, "VOID_ALREADY_RECORDED");
  assert.equal((await acct(afterUid).get()).data().economyHold, true);
  assert.equal((await acct(afterUid).get()).data().celestialJade, 110);
  assert.equal((await review(afterUid, 1)).code, "ECONOMY_RECONCILIATION_HOLD");
  assert.equal((await voided(p2.fingerprint).get()).exists, true);
});

test("Gate 8 forged proof, foreign auth, unknown account and account balance tamper fail closed", async () => {
  const uid = "gate8_tamper";
  await seed(uid);
  const p = await proofFor("GATE8_SYNTHETIC_TOKEN_TAMPER_00009");
  const untrusted = JSON.parse(JSON.stringify(p));
  assert.equal((await commit(uid, 0, untrusted)).code, "UNVERIFIED_PURCHASE");
  assert.equal((await commit(uid, 0, p, "")).code, "UNAUTHENTICATED");
  assert.equal((await commit(uid, 0, p, "intruder")).code, "FOREIGN_ACCOUNT");
  assert.equal((await commit("gate8_not_seeded", 0, p)).code, "ACCOUNT_NOT_FOUND");
  await acct(uid).update({ celestialJade: 999 });
  assert.equal((await commit(uid, 0, p)).code, "BALANCE_DIVERGENCE");
  assert.equal((await ledger(p.fingerprint).get()).exists, false);
  assert.equal((await review(uid, 0)).code, "BALANCE_DIVERGENCE");
});

test("Gate 8 stale head, tampered snapshot and overflow cannot mutate premium balances", async () => {
  const oldUid = "gate8_stale_head", tamperUid = "gate8_bad_digest", maxUid = "gate8_max_balance";
  await Promise.all([seed(oldUid), seed(tamperUid), seed(maxUid, Number.MAX_SAFE_INTEGER)]);
  const p1 = await proofFor("GATE8_SYNTHETIC_TOKEN_STALE_00010");
  assert.equal((await commit(oldUid, 0, p1)).code, "SYNTHETIC_PURCHASE_ATOMIC");
  assert.equal((await review(oldUid, 0)).code, "SERVER_REVISION_CHANGED");
  const p2 = await proofFor("GATE8_SYNTHETIC_TOKEN_DIGEST_00011");
  await snap(tamperUid, 0).update({ "domains.pavilion.celestial_jade": 500 });
  assert.equal((await commit(tamperUid, 0, p2)).code, "SNAPSHOT_DIGEST_INVALID");
  const p3 = await proofFor("GATE8_SYNTHETIC_TOKEN_OVERFLOW_00012");
  assert.equal((await commit(maxUid, 0, p3)).code, "BALANCE_OVERFLOW");
  assert.equal((await ledger(p3.fingerprint).get()).exists, false);
});

test("Gate 8 concurrent competing different purchases: only one account revision advances", async () => {
  const uid = "gate8_concurrent";
  await seed(uid);
  const items = await Promise.all(Array.from({ length: 4 }, (_, i) =>
    proofFor(`GATE8_SYNTHETIC_TOKEN_CONCURRENT_0001${i}`)));
  const results = await Promise.all(items.map(p => commit(uid, 0, p)));
  assert.equal(results.filter(x => x.code === "SYNTHETIC_PURCHASE_ATOMIC").length, 1);
  assert.ok(results.every(x => ["SYNTHETIC_PURCHASE_ATOMIC", "REVISION_CONFLICT",
    "EMULATOR_TRANSACTION_UNAVAILABLE"].includes(x.code)));
  const a = await acct(uid).get();
  assert.equal(a.data().revision, 1);
  assert.equal(a.data().celestialJade, 100);
  assert.equal((await acct(uid).collection("qa_snapshots").get()).size, 2);
  assert.equal((await acct(uid).collection("qa_events").get()).size, 1);
});
