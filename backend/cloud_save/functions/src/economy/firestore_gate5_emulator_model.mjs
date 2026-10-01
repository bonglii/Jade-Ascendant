/**
 * Gate 5B — REAL Firestore Emulator transaction harness, NOT production code.
 * Hard-gated to a demo project, dedicated collections, localhost and explicit
 * test flag. No callable imports it and no live project can invoke it.
 */
import { isVerifiedGate5Proof } from "./play_purchase_v2.mjs";

const DEMO = "demo-jade-cloud-save-gate5";
const HOST = "127.0.0.1:8080";
const UID = /^[A-Za-z0-9_-]{1,128}$/;
const FP = /^[a-f0-9]{64}$/;
const positiveRevision = n => Number.isSafeInteger(n) && n >= 0;
const accountDoc = (db, uid) => db.collection("gate5_qa_accounts_v1").doc(uid);
const ledgerDoc = (db, fp) => db.collection("gate5_qa_global_ledger_v1").doc(fp);
const voidDoc = (db, fp) => db.collection("gate5_qa_void_tombstones_v1").doc(fp);
const eventDoc = (db, uid, fp) => accountDoc(db, uid).collection("qa_events").doc(fp);
const ok = (code, data = {}) => Object.freeze({ ok: true, code, ...data });
const no = code => Object.freeze({ ok: false, code });

export function assertGate5EmulatorOnly() {
  if (process.env.JADE_GATE5_EMULATOR_ONLY !== "1"
    || process.env.FIRESTORE_EMULATOR_HOST !== HOST
    || process.env.GCLOUD_PROJECT !== DEMO
    || process.env.GOOGLE_CLOUD_PROJECT !== DEMO) {
    throw new Error("GATE5_EMULATOR_ONLY");
  }
}

/** Strict mock-account initializer for emulator tests; never writes elsewhere. */
export async function seedGate5EmulatorAccount(db, uid, jade = 0) {
  assertGate5EmulatorOnly();
  if (typeof uid !== "string" || !UID.test(uid)
      || !Number.isSafeInteger(jade) || jade < 0) return no("INVALID_TEST_ACCOUNT");
  try {
    await accountDoc(db, uid).create({ revision: 0, celestialJade: jade, hold: false });
    return ok("ACCOUNT_SEEDED");
  } catch {
    return no("ACCOUNT_SEED_FAILED");
  }
}

/**
 * Run a global token dedupe + CAS + state revision + immutable event as a
 * single Firestore Admin SDK transaction against localhost emulator ONLY.
 * Does NOT integrate eight permanent save domains or verify the Play token.
 */
export async function applyGate5EmulatorVerifiedFixture(db, { ownerUid, expectedRevision, proof } = {}) {
  assertGate5EmulatorOnly();
  if (typeof ownerUid !== "string" || !UID.test(ownerUid)) return no("INVALID_OWNER");
  if (!isVerifiedGate5Proof(proof)) return no("UNVERIFIED_PURCHASE");
  if (!positiveRevision(expectedRevision)) return no("REVISION_CONFLICT");
  try {
    return await db.runTransaction(async tx => {
      const lRef = ledgerDoc(db, proof.fingerprint);
      const aRef = accountDoc(db, ownerUid);
      const vRef = voidDoc(db, proof.fingerprint);
      const [oldLedger, oldAccount, voidRecord] = await Promise.all([
        tx.get(lRef), tx.get(aRef), tx.get(vRef),
      ]);
      if (!oldAccount.exists) return no("ACCOUNT_NOT_FOUND");
      const a = oldAccount.data();
      if (a?.hold === true || voidRecord.exists) return no("ECONOMY_RECONCILIATION_HOLD");
      if (oldLedger.exists) {
        const old = oldLedger.data();
        if (old.ownerUid !== ownerUid) return no("TOKEN_BOUND_TO_OTHER_ACCOUNT");
        if (old.productId !== proof.productId) return no("TOKEN_PRODUCT_MISMATCH");
        return ok("ALREADY_APPLIED", { revision: old.revision, grant: 0 });
      }
      if (!positiveRevision(a?.revision) || a.revision !== expectedRevision) {
        return no("REVISION_CONFLICT");
      }
      if (!positiveRevision(a?.celestialJade)) return no("INVALID_ACCOUNT_BALANCE");
      const nextBalance = a.celestialJade + proof.celestialJade;
      const nextRevision = a.revision + 1;
      if (!Number.isSafeInteger(nextBalance) || !Number.isSafeInteger(nextRevision)) {
        return no("STATE_OVERFLOW");
      }
      tx.create(lRef, { ownerUid, productId: proof.productId, revision: nextRevision });
      tx.update(aRef, { celestialJade: nextBalance, revision: nextRevision });
      tx.create(eventDoc(db, ownerUid, proof.fingerprint), {
        eventKind: "synthetic_qa_purchase_grant", revision: nextRevision,
        productId: proof.productId, grant: proof.celestialJade,
      });
      return ok("APPLIED", { revision: nextRevision, grant: proof.celestialJade });
    });
  } catch {
    return no("EMULATOR_TRANSACTION_UNAVAILABLE");
  }
}

/** Synthetic verified void fact fixture, NOT live Google Play reconciliation. */
export async function recordGate5SyntheticVoid(db, fingerprint) {
  assertGate5EmulatorOnly();
  if (typeof fingerprint !== "string" || !FP.test(fingerprint)) {
    return no("INVALID_VOID_FINGERPRINT");
  }
  try {
    return await db.runTransaction(async tx => {
      const vRef = voidDoc(db, fingerprint);
      const lRef = ledgerDoc(db, fingerprint);
      const [priorVoid, oldLedger] = await Promise.all([tx.get(vRef), tx.get(lRef)]);
      if (priorVoid.exists) return ok("VOID_ALREADY_RECORDED");
      const ownerUid = oldLedger.exists ? oldLedger.data()?.ownerUid : null;
      const aRef = typeof ownerUid === "string" && UID.test(ownerUid) ? accountDoc(db, ownerUid) : null;
      const oldAccount = aRef ? await tx.get(aRef) : null;
      tx.create(vRef, { kind: "synthetic_qa_void", ownerUid: ownerUid ?? null });
      if (oldAccount?.exists) tx.update(aRef, { hold: true });
      return ok("VOID_RECONCILIATION_HOLD");
    });
  } catch {
    return no("EMULATOR_TRANSACTION_UNAVAILABLE");
  }
}
