/**
 * M7E4E1: authenticated READ-ONLY SSV entitlement inbox.
 * This NEVER credits local gameplay, acks delivery, issues intents or accepts
 * account IDs supplied by the client. Requires a trusted Admin Firestore handle.
 */
import { createHash } from 'node:crypto';

const CREDIT_COLLECTION = 'm7e4c_ssv_credits';
const RECEIPT_COLLECTION = 'm7e4c_ssv_receipts';
const MAX_PAGE = 20;
const MAX_UID_LENGTH = 128;
const MAX_ID_LENGTH = 128;
const ALLOWED_PLACEMENTS = new Set([
  'game_over_revive', 'offline_cultivation_double', 'pavilion_seal',
  'liveops_boss_hunt_double', 'liveops_treasure_hunt_double',
  'daily_completion_cache', 'refinement_supply', 'victory_encore',
  'qi_focus', 'dao_choice_reroll',
]);

export class PendingInboxError extends Error {
  constructor(code) { super(code); this.name = 'PendingInboxError'; this.code = code; }
}
function reject(code) { throw new PendingInboxError(code); }
function validId(value, max = MAX_ID_LENGTH) {
  return typeof value === 'string' && value.length >= 1 && value.length <= max &&
    /^[A-Za-z0-9:_-]+$/.test(value);
}
function validUid(value) {
  // Firebase UIDs may contain provider-specific chars: no path separators or controls.
  return typeof value === 'string' && value.length >= 1 && value.length <= MAX_UID_LENGTH &&
    !/[\\/\u0000-\u001f\u007f]/.test(value) && value.trim() === value;
}
function hashKey(...parts) {
  return createHash('sha256').update(JSON.stringify(parts)).digest('hex');
}
function validAmount(v) { return Number.isSafeInteger(v) && v > 0; }
function validTimestamp(v) { return Number.isSafeInteger(v) && v >= 0; }
function ensureDb(db) {
  if (!db || typeof db.collection !== 'function') reject('TRUSTED_DATABASE_REQUIRED');
}

/**
 * authenticatedUid MUST come from a verified Firebase Authentication server
 * context (request.auth.uid), never a request body, query, or locally hashed UID.
 */
export async function readPendingEntitlements({ db, authenticatedUid } = {}) {
  ensureDb(db);
  if (!validUid(authenticatedUid)) reject('AUTH_REQUIRED');
  // Query is entirely server-owned. No client-supplied collection, filters, ID, or pagination.
  const query = db.collection(CREDIT_COLLECTION)
    .where('userId', '==', authenticatedUid)
    .where('state', '==', 'PENDING_DELIVERY')
    .limit(MAX_PAGE + 1);
  const snapshot = await query.get();
  if (!snapshot || !Array.isArray(snapshot.docs)) reject('DATABASE_RESULT_INVALID');
  const found = [];
  for (const doc of snapshot.docs.slice(0, MAX_PAGE)) {
    const credit = doc.data();
    if (!credit || typeof credit !== 'object' ||
        !validId(credit.intentId) ||
        !validId(credit.transactionId) ||
        !validId(credit.userId, MAX_UID_LENGTH) ||
        credit.userId !== authenticatedUid ||
        credit.state !== 'PENDING_DELIVERY' ||
        !validId(credit.rewardItem) ||
        !validAmount(credit.rewardAmount) ||
        !validTimestamp(credit.createdAtMs) ||
        !ALLOWED_PLACEMENTS.has(credit.placement) ||
        doc.id !== hashKey('intent', credit.intentId)) {
      reject('DURABLE_CREDIT_INVALID');
    }
    // Fail closed if ledger receipt was lost/corrupted, even though inbox is read-only.
    const receiptDoc = await db.collection(RECEIPT_COLLECTION).doc(credit.transactionId).get();
    const receipt = receiptDoc.exists ? receiptDoc.data() : null;
    if (!receipt || receipt.state !== 'VERIFIED_PENDING_DELIVERY' ||
        receipt.transactionId !== credit.transactionId ||
        receipt.intentId !== credit.intentId ||
        receipt.userId !== credit.userId ||
        receipt.placement !== credit.placement ||
        receipt.rewardItem !== credit.rewardItem ||
        receipt.rewardAmount !== credit.rewardAmount) {
      reject('DURABLE_LEDGER_INVARIANT_BROKEN');
    }
    found.push({
      // Opaque index for future recovery lookup, NOT grant authority.
      entitlementId: doc.id,
      placement: credit.placement,
      rewardItem: credit.rewardItem,
      rewardAmount: credit.rewardAmount,
      state: 'PENDING_DELIVERY',
      createdAtMs: credit.createdAtMs,
    });
  }
  found.sort((a, b) => a.createdAtMs - b.createdAtMs || a.entitlementId.localeCompare(b.entitlementId));
  return Object.freeze({
    status: 'READ_ONLY_PENDING',
    items: found.map(x => Object.freeze(x)),
    hasMore: snapshot.docs.length > MAX_PAGE,
    creditAllowed: false,
    clientAckAllowed: false,
  });
}

/**
 * Unregistered Firebase onCall factory. Isolated integration can opt in at a
 * later gate, but the default/production path ALWAYS fails closed.
 */
export function createPendingInboxCallable({ onCall, HttpsError, getDb, enabled = false } = {}) {
  if (typeof onCall !== 'function' || typeof HttpsError !== 'function' ||
      typeof getDb !== 'function') throw new TypeError('CALLABLE_DEPENDENCIES_INVALID');
  return onCall({ region: 'us-central1', enforceAppCheck: true, maxInstances: 1 }, async request => {
    if (!enabled) throw new HttpsError('unavailable', 'INBOX_DISABLED');
    // Do not process any caller-provided UID, token or entitlement ID.
    if (request?.data == null || Array.isArray(request.data) ||
        typeof request.data !== 'object' || Object.keys(request.data).length > 0) {
      throw new HttpsError('invalid-argument', 'EMPTY_PAYLOAD_REQUIRED');
    }
    const verifiedUid = request?.auth?.uid;
    if (!validUid(verifiedUid)) throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    try {
      return await readPendingEntitlements({ db: getDb(), authenticatedUid: verifiedUid });
    } catch (err) {
      if (err instanceof PendingInboxError && err.code === 'AUTH_REQUIRED') {
        throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
      }
      // No PII, raw receipt, or grant tokens in error responses.
      throw new HttpsError('unavailable', 'INBOX_UNAVAILABLE');
    }
  });
}

export const m7e4eInboxContract = Object.freeze({
  phase: 'MONETIZATION_M7E4E1',
  credits: CREDIT_COLLECTION,
  receipts: RECEIPT_COLLECTION,
  maxPage: MAX_PAGE,
  writesAllowed: false,
  gameplayGrantAllowed: false,
  serverIntentIssuerEnabled: false,
  clientAckAllowed: false,
  callableRegistered: false,
  productionEnabled: false,
});
