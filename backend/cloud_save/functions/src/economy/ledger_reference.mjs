/**
 * Gate 5 — OFFLINE IN-MEMORY REFERENCE MODEL ONLY.
 * NOT a datastore, not concurrency-safe across processes, and NEVER used as
 * an authority for player purchases. Port the transitions to one atomic
 * Firestore server transaction + a permanent global purchase ledger later.
 */
import { isVerifiedGate5Proof } from "./play_purchase_v2.mjs";

const UID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const FP_PATTERN = /^[a-f0-9]{64}$/;
const MAX_BALANCE = Number.MAX_SAFE_INTEGER;
const ok = (code, extras = {}) => Object.freeze({ ok: true, code, ...extras });
const no = code => Object.freeze({ ok: false, code });

export class SimulatedPurchaseLedger {
  #accounts = new Map();
  #ledger = new Map();
  #voids = new Set();
  #events = [];

  /** QA fixture only. No real user identity or save file is read. */
  seedAccount(uid, celestialJade = 0) {
    if (!UID_PATTERN.test(uid) || !Number.isSafeInteger(celestialJade)
        || celestialJade < 0 || this.#accounts.has(uid)) {
      return no("INVALID_TEST_ACCOUNT");
    }
    this.#accounts.set(uid, { revision: 0, celestialJade, hold: false });
    return ok("TEST_ACCOUNT_CREATED");
  }

  readAccount(uid) {
    const a = this.#accounts.get(uid);
    return a ? Object.freeze({ ...a }) : null;
  }

  get ledgerSize() { return this.#ledger.size; }
  get eventCount() { return this.#events.length; }

  /**
   * Proof must come from `verifyPlayPurchaseV2`; this model never creates one.
   * Synchronous transitions simulate atomicity but do not implement it.
   */
  applyVerifiedFixture({ ownerUid, expectedRevision, proof } = {}) {
    if (typeof ownerUid !== "string" || !UID_PATTERN.test(ownerUid)) return no("INVALID_OWNER");
    if (!isVerifiedGate5Proof(proof)) return no("UNVERIFIED_PURCHASE");
    const account = this.#accounts.get(ownerUid);
    if (!account) return no("ACCOUNT_NOT_FOUND");
    if (account.hold || this.#voids.has(proof.fingerprint)) return no("ECONOMY_RECONCILIATION_HOLD");

    // Durable/global dedupe must beat stale revision checks and precede grants.
    const prior = this.#ledger.get(proof.fingerprint);
    if (prior) {
      if (prior.ownerUid !== ownerUid) return no("TOKEN_BOUND_TO_OTHER_ACCOUNT");
      if (prior.productId !== proof.productId) return no("TOKEN_PRODUCT_MISMATCH");
      return ok("ALREADY_APPLIED", { revision: prior.revision, grant: 0 });
    }
    if (!Number.isSafeInteger(expectedRevision) || expectedRevision < 0
        || account.revision !== expectedRevision) {
      return no("REVISION_CONFLICT");
    }
    const nextJade = account.celestialJade + proof.celestialJade;
    if (!Number.isSafeInteger(nextJade) || nextJade > MAX_BALANCE) {
      return no("BALANCE_OVERFLOW");
    }
    if (account.revision >= Number.MAX_SAFE_INTEGER) return no("REVISION_OVERFLOW");
    const nextRevision = account.revision + 1;
    this.#ledger.set(proof.fingerprint, Object.freeze({
      ownerUid,
      productId: proof.productId,
      revision: nextRevision,
    }));
    this.#accounts.set(ownerUid, { ...account, revision: nextRevision, celestialJade: nextJade });
    this.#events.push(Object.freeze({ ownerUid, revision: nextRevision, kind: "purchase_grant" }));
    return ok("APPLIED", { revision: nextRevision, grant: proof.celestialJade });
  }

  /**
   * Synthetic verified-void event fixture, NOT Google Play Voided Purchases
   * verification. Unknown fingerprints also block future grants (tombstone).
   * Never subtract currency blindly: a real service must reconcile spending.
   */
  recordSyntheticVerifiedVoid(fingerprint) {
    if (typeof fingerprint !== "string" || !FP_PATTERN.test(fingerprint)) {
      return no("INVALID_VOID_FINGERPRINT");
    }
    if (this.#voids.has(fingerprint)) return ok("VOID_ALREADY_RECORDED");
    this.#voids.add(fingerprint);
    const existing = this.#ledger.get(fingerprint);
    if (existing) {
      const a = this.#accounts.get(existing.ownerUid);
      if (a) this.#accounts.set(existing.ownerUid, { ...a, hold: true });
    }
    return ok("VOID_RECONCILIATION_HOLD");
  }
}
