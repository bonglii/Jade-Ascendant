/**
 * Gate 8: DEMO-ONLY atomic integration fixture, NEVER a deployed economy service.
 * Unlike the separate Gate 5 / Gate 6 QA collections, this model puts a
 * verified-synthetic purchase fingerprint, immutable 8-domain revision,
 * account head, and audit event in ONE Firestore Emulator transaction.
 * It does not verify Google Play or reconcile non-purchase earnings. No client
 * may supply an authoritative purchase proof or cloud snapshot in production.
 */
import { assertGate5EmulatorOnly } from "../economy/firestore_gate5_emulator_model.mjs";
import { isVerifiedGate5Proof } from "../economy/play_purchase_v2.mjs";
import {
  inspectFullPermanentDraft, hashFullDraftForQa, FULL_DRAFT_VERSION,
  PERMANENT_DOMAIN_IDS,
} from "../snapshot/full_permanent_draft_v2.mjs";

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const FP = /^[a-f0-9]{64}$/;
// Test-only, process-local provenance: a Play fact must be linked to its owner.
// Production MUST derive this binding from verified Firebase Auth and Play.
const BOUND_SYNTHETIC = new WeakMap();
const REV = n => Number.isSafeInteger(n) && n >= 0;
const uidOk = x => typeof x === "string" && UID.test(x);
const okay = (code, extra = {}) => Object.freeze({ ok: true, code, ...extra });
const reject = code => Object.freeze({ ok: false, code });
const accountRef = (db, uid) => db.collection("gate8_qa_accounts_v1").doc(uid);
const snapshotRef = (db, uid, rev) => accountRef(db, uid).collection("qa_snapshots")
  .doc(`rev_${String(rev).padStart(14, "0")}`);
const ledgerRef = (db, fp) => db.collection("gate8_qa_global_purchase_ledger_v1").doc(fp);
const voidRef = (db, fp) => db.collection("gate8_qa_void_tombstones_v1").doc(fp);
const eventRef = (db, uid, fp) => accountRef(db, uid).collection("qa_events").doc(fp);

function buildSnapshot(draft, revision) {
  return {
    qaOnly: true,
    revision,
    draftVersion: FULL_DRAFT_VERSION,
    domainCount: PERMANENT_DOMAIN_IDS.length,
    domainIds: [...PERMANENT_DOMAIN_IDS],
    domainSchemaVersions: structuredClone(draft.domain_schema_versions),
    domains: structuredClone(draft.domains),
    untrustedCapturedAtUnix: draft.captured_at_unix,
    syntheticDigest: hashFullDraftForQa(draft),
  };
}

function inspectStoredSnapshot(doc, uid, revision, head) {
  if (!doc.exists) return reject("SNAPSHOT_NOT_FOUND");
  const p = doc.data();
  if (p?.qaOnly !== true || p?.revision !== revision
    || p?.draftVersion !== FULL_DRAFT_VERSION
    || p?.domainCount !== PERMANENT_DOMAIN_IDS.length
    || JSON.stringify(p?.domainIds) !== JSON.stringify(PERMANENT_DOMAIN_IDS)) {
    return reject("SNAPSHOT_METADATA_INVALID");
  }
  const draft = {
    draft_snapshot_version: p.draftVersion,
    owner_uid: uid,
    captured_at_unix: p.untrustedCapturedAtUnix,
    domain_schema_versions: p.domainSchemaVersions,
    domains: p.domains,
  };
  if (!inspectFullPermanentDraft(draft, uid).valid) return reject("SNAPSHOT_CONTENT_INVALID");
  const digest = hashFullDraftForQa(draft);
  if (p.syntheticDigest !== digest || head.headDigest !== digest) {
    return reject("SNAPSHOT_DIGEST_INVALID");
  }
  return { ok: true, draft };
}

/** Opaque synthetic account-binding issued solely by QA harness (no Android API). */
export function mintGate8SyntheticBoundProof(verifiedProof, ownerUid) {
  assertGate5EmulatorOnly();
  if (!uidOk(ownerUid)) return reject("INVALID_OWNER");
  if (!isVerifiedGate5Proof(verifiedProof)) return reject("UNVERIFIED_PURCHASE");
  const marker = Object.freeze({ qaOnly: true });
  BOUND_SYNTHETIC.set(marker, Object.freeze({ ownerUid, verifiedProof }));
  return marker;
}

/** Synthetic fixture: seeds revision zero (NOT an import of player data). */
export async function seedGate8SyntheticAccount(db, uid, syntheticDraft) {
  assertGate5EmulatorOnly();
  if (!uidOk(uid)) return reject("INVALID_TEST_ACCOUNT");
  if (!inspectFullPermanentDraft(syntheticDraft, uid).valid) return reject("INVALID_TEST_DRAFT");
  try {
    return await db.runTransaction(async tx => {
      const aRef = accountRef(db, uid);
      const sRef = snapshotRef(db, uid, 0);
      const [a, s] = await Promise.all([tx.get(aRef), tx.get(sRef)]);
      if (a.exists || s.exists) return reject("ACCOUNT_ALREADY_SEEDED");
      const initial = buildSnapshot(syntheticDraft, 0);
      tx.create(aRef, {
        revision: 0, economyHold: false, headDigest: initial.syntheticDigest,
        domainCount: PERMANENT_DOMAIN_IDS.length, celestialJade: initial.domains.pavilion.celestial_jade,
        qaOnly: true,
      });
      tx.create(sRef, initial);
      return okay("QA_ACCOUNT_SEEDED");
    });
  } catch { return reject("EMULATOR_TRANSACTION_UNAVAILABLE"); }
}

/**
 * Synthetic Play-proven input is minted by Gate 5 test reader, NOT an Android
 * payload. No fresh balances, item grants or snapshot body accepted from caller.
 * All global dedupe, CAS, premium balance, 8-domain state and audit event are
 * created together. The fault injection is a QA-only abort to prove rollback.
 */
export async function commitGate8SyntheticPurchase(db, {
  authenticatedUid, ownerUid, expectedRevision, proof,
  injectQaFailureAfterWrites = false,
} = {}) {
  assertGate5EmulatorOnly();
  if (!uidOk(authenticatedUid)) return reject("UNAUTHENTICATED");
  if (!uidOk(ownerUid) || authenticatedUid !== ownerUid) return reject("FOREIGN_ACCOUNT");
  if (!REV(expectedRevision)) return reject("INVALID_EXPECTED_REVISION");
  if (!proof || typeof proof !== "object" || !BOUND_SYNTHETIC.has(proof)) {
    return reject("UNVERIFIED_PURCHASE");
  }
  const bound = BOUND_SYNTHETIC.get(proof);
  if (bound.ownerUid !== ownerUid) return reject("PROOF_ACCOUNT_MISMATCH");
  proof = bound.verifiedProof;
  if (injectQaFailureAfterWrites !== false && injectQaFailureAfterWrites !== true) {
    return reject("INVALID_QA_INJECTION");
  }
  try {
    return await db.runTransaction(async tx => {
      const aRef = accountRef(db, ownerUid);
      const lRef = ledgerRef(db, proof.fingerprint);
      const vRef = voidRef(db, proof.fingerprint);
      const [a, l, v] = await Promise.all([tx.get(aRef), tx.get(lRef), tx.get(vRef)]);
      if (!a.exists) return reject("ACCOUNT_NOT_FOUND");
      const head = a.data();
      if (head?.qaOnly !== true || head?.domainCount !== PERMANENT_DOMAIN_IDS.length) {
        return reject("ACCOUNT_METADATA_INVALID");
      }
      if (head?.economyHold !== false || v.exists) return reject("ECONOMY_RECONCILIATION_HOLD");
      if (l.exists) {
        const prior = l.data();
        if (prior?.ownerUid !== ownerUid) return reject("TOKEN_BOUND_TO_OTHER_ACCOUNT");
        if (prior?.productId !== proof.productId) return reject("TOKEN_PRODUCT_MISMATCH");
        return okay("ALREADY_APPLIED", { revision: prior.revision, grant: 0 });
      }
      if (!REV(head.revision) || head.revision !== expectedRevision) {
        return reject("REVISION_CONFLICT");
      }
      if (head.revision >= Number.MAX_SAFE_INTEGER) return reject("REVISION_OVERFLOW");
      const old = await tx.get(snapshotRef(db, ownerUid, head.revision));
      const prior = inspectStoredSnapshot(old, ownerUid, head.revision, head);
      if (!prior.ok) return prior;
      const oldJade = prior.draft.domains.pavilion.celestial_jade;
      if (!REV(oldJade) || oldJade !== head.celestialJade) return reject("BALANCE_DIVERGENCE");
      const newJade = oldJade + proof.celestialJade;
      if (!Number.isSafeInteger(newJade)) return reject("BALANCE_OVERFLOW");
      if (proof.pavilionSeals !== 0 || proof.kind !== "consumable") {
        return reject("UNSUPPORTED_GRANT_TYPE");
      }
      const next = structuredClone(prior.draft);
      next.domains.pavilion.celestial_jade = newJade;
      if (!inspectFullPermanentDraft(next, ownerUid).valid) {
        return reject("NEXT_SNAPSHOT_INVALID");
      }
      const nextRevision = head.revision + 1;
      const newSnapshot = buildSnapshot(next, nextRevision);
      tx.create(ledgerRef(db, proof.fingerprint), {
        ownerUid, productId: proof.productId, playProductId: proof.playProductId,
        revision: nextRevision, grant: proof.celestialJade, qaOnly: true,
      });
      tx.create(snapshotRef(db, ownerUid, nextRevision), newSnapshot);
      tx.create(eventRef(db, ownerUid, proof.fingerprint), {
        kind: "synthetic_purchase_grant", productId: proof.productId,
        grant: proof.celestialJade, revision: nextRevision, qaOnly: true,
      });
      tx.update(aRef, {
        revision: nextRevision, celestialJade: newJade,
        headDigest: newSnapshot.syntheticDigest,
      });
      if (injectQaFailureAfterWrites) throw Error("QA_FAULT_ABORT_AFTER_WRITE_QUEUE");
      return okay("SYNTHETIC_PURCHASE_ATOMIC", {
        revision: nextRevision, grant: proof.celestialJade,
      });
    });
  } catch (e) {
    if (e?.message === "QA_FAULT_ABORT_AFTER_WRITE_QUEUE") return reject("QA_FAULT_ABORTED");
    return reject("EMULATOR_TRANSACTION_UNAVAILABLE");
  }
}

/** Synthetic verified-void fixture: prevents replay; no blind currency debit. */
export async function recordGate8SyntheticVoid(db, fingerprint) {
  assertGate5EmulatorOnly();
  if (typeof fingerprint !== "string" || !FP.test(fingerprint)) {
    return reject("INVALID_VOID_FINGERPRINT");
  }
  try {
    return await db.runTransaction(async tx => {
      const vRef = voidRef(db, fingerprint);
      const lRef = ledgerRef(db, fingerprint);
      const [v, l] = await Promise.all([tx.get(vRef), tx.get(lRef)]);
      if (v.exists) return okay("VOID_ALREADY_RECORDED");
      const uid = l.exists ? l.data()?.ownerUid : null;
      const aRef = uidOk(uid) ? accountRef(db, uid) : null;
      const account = aRef ? await tx.get(aRef) : null;
      tx.create(vRef, { kind: "synthetic_qa_void", ownerUid: uid ?? null, qaOnly: true });
      if (account?.exists) tx.update(aRef, { economyHold: true });
      return okay("RECONCILIATION_HOLD_RECORDED");
    });
  } catch { return reject("EMULATOR_TRANSACTION_UNAVAILABLE"); }
}

/** Current-head read ONLY. The output never authorizes Android restore. */
export async function reviewGate8SyntheticHead(db, { authenticatedUid, ownerUid,
  expectedRevision } = {}) {
  assertGate5EmulatorOnly();
  if (!uidOk(authenticatedUid)) return reject("UNAUTHENTICATED");
  if (!uidOk(ownerUid) || ownerUid !== authenticatedUid) return reject("FOREIGN_ACCOUNT");
  if (!REV(expectedRevision)) return reject("INVALID_EXPECTED_REVISION");
  try {
    return await db.runTransaction(async tx => {
      const a = await tx.get(accountRef(db, ownerUid));
      if (!a.exists) return reject("ACCOUNT_NOT_FOUND");
      const head = a.data();
      if (head?.economyHold !== false) return reject("ECONOMY_RECONCILIATION_HOLD");
      if (head?.revision !== expectedRevision) return reject("SERVER_REVISION_CHANGED");
      const old = await tx.get(snapshotRef(db, ownerUid, expectedRevision));
      const inspected = inspectStoredSnapshot(old, ownerUid, expectedRevision, head);
      if (!inspected.ok) return inspected;
      if (inspected.draft.domains.pavilion.celestial_jade !== head.celestialJade) {
        return reject("BALANCE_DIVERGENCE");
      }
      return okay("QA_HEAD_CONSISTENT", {
        revision: expectedRevision, celestialJade: head.celestialJade,
        restore_allowed: false, upload_allowed: false,
      });
    });
  } catch { return reject("EMULATOR_READ_UNAVAILABLE"); }
}
