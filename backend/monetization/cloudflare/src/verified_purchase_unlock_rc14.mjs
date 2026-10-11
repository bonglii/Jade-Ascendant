/**
 * Optional product policy for a paid-only summon pool.
 *
 * This is NOT proof of campaign victory. It permits a separate paid summon only
 * after the same Firebase account received at least one genuinely Play-verified
 * credit, with every debit still guarded by refund hold and server wallet CAS.
 * Offline Story/Pavilion stage unlocks and all local saves stay unchanged.
 *
 * Disabled unless three Worker gates plus this policy gate are explicitly true.
 */
const OWNER = /^u1:[0-9a-f]{64}$/;
const PURCHASE_GUARD_SQL = "EXISTS (SELECT 1 FROM iap_wallet_events_v1 WHERE owner_key=? AND event_kind='play_credit')";

export class VerifiedPurchaseUnlockErrorRC14 extends Error {
  constructor(code) { super(code); this.name = 'VerifiedPurchaseUnlockErrorRC14'; this.code = code; }
}

function checkOwner(owner) {
  if (typeof owner !== 'string' || !OWNER.test(owner)) {
    throw new VerifiedPurchaseUnlockErrorRC14('invalid_owner');
  }
}

function primary(db) {
  if (!db || typeof db.prepare !== 'function') throw new VerifiedPurchaseUnlockErrorRC14('missing_d1');
  return typeof db.withSession === 'function' ? db.withSession('first-primary') : db;
}

/** Fail-closed read before expensive RNG resolution; NOT sufficient on its own. */
export async function assertVerifiedPlayCreditRC14(db, owner) {
  checkOwner(owner);
  const row = await primary(db).prepare(
    "SELECT 1 AS eligible FROM iap_wallet_events_v1 WHERE owner_key=? AND event_kind='play_credit' LIMIT 1"
  ).bind(owner).first();
  if (row?.eligible !== 1) throw new VerifiedPurchaseUnlockErrorRC14('no_verified_play_credit');
  return true;
}

/** Used inside the SAME D1 batch that writes debit, outcome and canonical CAS.
 * CAS failure must abort the entire batch via the canonical revision CHECK.
 * The refund hold predicate must be included independently and unconditionally.
 */
export function verifiedPlayCreditCasGuardRC14(owner) {
  checkOwner(owner);
  return {sql: PURCHASE_GUARD_SQL, bindings: [owner]};
}

export function paidPurchaseUnlockEnabledRC14(env) {
  return env?.JADE_IAP_BACKEND_ENABLED === 'true'
    && env?.JADE_PAID_SUMMON_WRITE_ENABLED === 'true'
    && env?.JADE_REFUND_RECONCILIATION_READY === 'true'
    && env?.JADE_PAID_SUMMON_PURCHASE_UNLOCK_ENABLED === 'true';
}
