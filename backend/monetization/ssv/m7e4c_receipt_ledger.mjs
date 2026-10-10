/**
 * Jade Ascendant M7E4C — OFFLINE Firestore transaction ledger foundation.
 * Not a route, deploy, client entitlement, or local-save recovery mechanism.
 * Firestore is injected; callers MUST use a trusted server Admin SDK instance.
 * SSV keys, intents, and server time MUST NOT originate in client input.
 */
import { createHash } from 'node:crypto';
import {
  parseSignedCallback, verifyGoogleSsv, buildPendingLedgerCandidate,
} from './m7e4b_ssv_verifier.mjs';

export class LedgerRejection extends Error {
  constructor(code) { super(code); this.name = 'LedgerRejection'; this.code = code; }
}
const reject = code => { throw new LedgerRejection(code); };

const ALLOWED_PLACEMENTS = Object.freeze(new Set([
  'game_over_revive', 'offline_cultivation_double', 'pavilion_seal',
  'liveops_boss_hunt_double', 'liveops_treasure_hunt_double',
  'daily_completion_cache', 'refinement_supply', 'victory_encore',
  'qi_focus', 'dao_choice_reroll',
]));
const PER_RUN_REQUIRED = new Set(['game_over_revive', 'dao_choice_reroll']);
const REVIVE = 'game_over_revive';
export const MAX_DAILY_NON_REVIVE = 5;
const MAX_ID_LEN = 128;
const MAX_STRING = 256;

function validId(s) {
  return typeof s === 'string' && s.length > 0 && s.length <= MAX_ID_LEN &&
    /^[A-Za-z0-9:_-]+$/.test(s);
}
function validNonce(s) {
  return typeof s === 'string' && /^[A-Za-z0-9_-]{24,128}$/.test(s);
}
function key(...parts) {
  return createHash('sha256').update(JSON.stringify(parts)).digest('hex');
}
function safe(s) { return typeof s === 'string' && s.length > 0 && s.length <= MAX_STRING; }
function stamp(n) { return Number.isSafeInteger(n) && n >= 0; }
function currentDay(nowMs) { return String(Math.floor(nowMs / 86400000)); }

function inspectIntent(intent, nonce) {
  if (!intent || !validId(intent.intentId) || !validId(intent.userId) ||
      !validNonce(intent.nonce) || intent.nonce !== nonce ||
      !ALLOWED_PLACEMENTS.has(intent.placement) ||
      !safe(intent.adUnit) || !safe(intent.rewardItem) ||
      !Number.isSafeInteger(intent.rewardAmount) || intent.rewardAmount < 1 ||
      !stamp(intent.issuedAtMs) || !stamp(intent.expiresAtMs) ||
      intent.expiresAtMs <= intent.issuedAtMs ||
      !['PENDING', 'CONSUMED'].includes(intent.status) ||
      (intent.runId !== undefined && !validId(intent.runId)) ||
      (PER_RUN_REQUIRED.has(intent.placement) && !validId(intent.runId))) {
    reject('SERVER_INTENT_INVALID');
  }
}
function sameIntent(a, b) {
  return ['intentId', 'userId', 'nonce', 'placement', 'adUnit',
    'rewardItem', 'rewardAmount', 'issuedAtMs', 'expiresAtMs', 'runId']
    .every(k => a[k] === b[k]);
}
function requiredDb(db) {
  if (!db || typeof db.collection !== 'function' ||
      typeof db.runTransaction !== 'function') reject('TRUSTED_DATABASE_REQUIRED');
}

/**
 * Parse pre-signature nonce only for an untrusted lookup, then cryptographically
 * verify callback BEFORE any transaction or writes. Never trust callback user_id.
 * Caller supplies server-fetched Google keys and injected privileged Firestore.
 */
export async function acceptVerifiedSsvReceipt({
  rawQuery, trustedGoogleKeys, db, nowMs = Date.now(),
} = {}) {
  requiredDb(db);
  if (!stamp(nowMs)) reject('SERVER_TIME_INVALID');
  const preliminary = parseSignedCallback(rawQuery);
  const nonce = preliminary.params.custom_data;
  if (!validNonce(nonce)) reject('NONCE_INVALID');
  const intents = db.collection('m7e4c_ssv_intents');
  const intentRef = intents.doc(key('nonce', nonce));
  // Query-derived index is only a pointer; it is never an authorization proof.
  const intentSnap = await intentRef.get();
  if (!intentSnap.exists) reject('UNKNOWN_SERVER_INTENT');
  const intent = intentSnap.data();
  inspectIntent(intent, nonce);
  const verified = verifyGoogleSsv(rawQuery, {
    trustedGoogleKeys,
    expectedAdUnit: intent.adUnit,
    expectedCustomData: intent.nonce,
    expectedRewardAmount: intent.rewardAmount,
    expectedRewardItem: intent.rewardItem,
    nowMs,
  });
  const candidate = buildPendingLedgerCandidate(verified, intent);
  const day = currentDay(nowMs);
  const receiptRef = db.collection('m7e4c_ssv_receipts').doc(candidate.transactionId);
  const creditRef = db.collection('m7e4c_ssv_credits').doc(key('intent', intent.intentId));
  const usageRef = db.collection('m7e4c_ssv_daily').doc(key('day', candidate.userId, day));
  const runRef = intent.runId
    ? db.collection('m7e4c_ssv_runs').doc(key('run', candidate.userId, intent.runId, candidate.placement))
    : null;

  return await db.runTransaction(async tx => {
    // Firestore requires all reads before writes, including replay/limit checks.
    const readRefs = [receiptRef, intentRef, creditRef, usageRef, ...(runRef ? [runRef] : [])];
    const snaps = await Promise.all(readRefs.map(ref => tx.get(ref)));
    const [receiptSnap, liveIntentSnap, creditSnap, usageSnap, runSnap] = snaps;
    if (receiptSnap.exists) {
      const old = receiptSnap.data();
      if (old.transactionId !== candidate.transactionId ||
          old.intentId !== candidate.intentId || old.userId !== candidate.userId ||
          old.placement !== candidate.placement || old.state !== 'VERIFIED_PENDING_DELIVERY') {
        reject('TRANSACTION_ID_REPLAY_CONFLICT');
      }
      // A receipt without its atomic credit + consumed intent is NOT success.
      // Treat missing/mismatched records as integrity failure, never auto-grant.
      const oldCredit = creditSnap.exists ? creditSnap.data() : null;
      const oldIntent = liveIntentSnap.exists ? liveIntentSnap.data() : null;
      if (!oldCredit || !oldIntent ||
          oldCredit.transactionId !== candidate.transactionId ||
          oldCredit.intentId !== candidate.intentId ||
          oldCredit.userId !== candidate.userId ||
          oldCredit.state !== 'PENDING_DELIVERY' ||
          oldIntent.status !== 'CONSUMED' ||
          oldIntent.consumedTransactionId !== candidate.transactionId) {
        reject('DURABLE_LEDGER_INVARIANT_BROKEN');
      }
      // Already committed: acknowledge retry without adding a credit.
      return Object.freeze({ status: 'ALREADY_RECORDED', newlyRecorded: false, transactionId: candidate.transactionId });
    }
    if (!liveIntentSnap.exists) reject('SERVER_INTENT_DISAPPEARED');
    const liveIntent = liveIntentSnap.data();
    inspectIntent(liveIntent, nonce);
    if (!sameIntent(liveIntent, intent)) reject('SERVER_INTENT_CHANGED');
    if (liveIntent.status !== 'PENDING') reject('INTENT_ALREADY_CONSUMED');
    if (nowMs < liveIntent.issuedAtMs || nowMs > liveIntent.expiresAtMs) reject('INTENT_EXPIRED');
    if (creditSnap.exists) reject('CREDIT_ALREADY_EXISTS');
    if (runSnap?.exists) reject('RUN_PLACEMENT_ALREADY_USED');
    let nextUsage;
    if (candidate.placement !== REVIVE) {
      const usage = usageSnap.exists ? usageSnap.data() : { total: 0, placements: {} };
      if (!Number.isSafeInteger(usage.total) || usage.total < 0 ||
          !usage.placements || typeof usage.placements !== 'object' ||
          Array.isArray(usage.placements)) reject('DAILY_POLICY_CORRUPT');
      const count = usage.placements[candidate.placement] ?? 0;
      if (!Number.isSafeInteger(count) || count < 0) reject('DAILY_POLICY_CORRUPT');
      if (usage.total >= MAX_DAILY_NON_REVIVE) reject('GLOBAL_DAILY_CAP_REACHED');
      if (count >= 1) reject('PLACEMENT_DAILY_CAP_REACHED');
      nextUsage = {
        day, userId: candidate.userId, total: usage.total + 1,
        placements: { ...usage.placements, [candidate.placement]: count + 1 },
      };
    }
    const receipt = {
      transactionId: candidate.transactionId,
      intentId: candidate.intentId, userId: candidate.userId,
      placement: candidate.placement, rewardAmount: candidate.rewardAmount,
      rewardItem: candidate.rewardItem, signedTimestampMs: candidate.timestampMs,
      state: 'VERIFIED_PENDING_DELIVERY', recordedAtMs: nowMs,
    };
    const credit = {
      intentId: candidate.intentId, transactionId: candidate.transactionId,
      userId: candidate.userId, placement: candidate.placement,
      rewardAmount: candidate.rewardAmount, rewardItem: candidate.rewardItem,
      state: 'PENDING_DELIVERY', createdAtMs: nowMs,
    };
    tx.create(receiptRef, receipt);
    tx.create(creditRef, credit);
    tx.update(intentRef, { status: 'CONSUMED', consumedTransactionId: candidate.transactionId });
    if (nextUsage) tx.set(usageRef, nextUsage);
    if (runRef) tx.create(runRef, {
      userId: candidate.userId, runId: intent.runId,
      placement: candidate.placement, transactionId: candidate.transactionId,
    });
    return Object.freeze({ status: 'VERIFIED_PENDING_DELIVERY', newlyRecorded: true, transactionId: candidate.transactionId });
  });
}

export const m7e4cStorageContract = Object.freeze({
  intentCollection: 'm7e4c_ssv_intents',
  receiptCollection: 'm7e4c_ssv_receipts',
  creditCollection: 'm7e4c_ssv_credits',
  dailyCollection: 'm7e4c_ssv_daily',
  runCollection: 'm7e4c_ssv_runs',
  intentDocumentIdForNonce: nonce => validNonce(nonce) ? key('nonce', nonce) : reject('NONCE_INVALID'),
});
