/**
 * RC5 server-side refund hold gate. NO HTTP route and NO client grant authority.
 * Only trusted Play refund/void verification may eventually write holds; that
 * ingestion path is intentionally NOT included here.
 *
 * A pre-read prevents expensive RNG on a held account; a second check in the
 * canonical D1 UPDATE prevents a hold from racing a paid summon commit.
 */
export class RefundHoldErrorRC5 extends Error {
  constructor(code) { super(code); this.name = 'RefundHoldErrorRC5'; this.code = code; }
}
const OWNER = /^u1:[a-f0-9]{64}$/;
function requireOwner(owner) {
  if (typeof owner !== 'string' || !OWNER.test(owner))
    throw new RefundHoldErrorRC5('invalid_owner');
  return owner;
}
export async function assertNoRefundHoldRC5({db, owner}) {
  requireOwner(owner);
  if (!db || typeof db.prepare !== 'function')
    throw new RefundHoldErrorRC5('refund_guard_unavailable');
  const primary = typeof db.withSession === 'function' ? db.withSession('first-primary') : db;
  const hold = await primary.prepare(
    'SELECT status FROM iap_refund_account_holds_v1 WHERE owner_key=?'
  ).bind(owner).first();
  if (hold && hold.status !== 'released' && hold.status !== 'held')
    throw new RefundHoldErrorRC5('corrupt_refund_hold');
  if (hold?.status === 'held') throw new RefundHoldErrorRC5('paid_account_on_hold');
  return true;
}
/** For use only in a canonical UPDATE executed INSIDE the same D1 batch as debit. */
export function refundHoldCasPredicateRC5() {
  return `AND NOT EXISTS (
    SELECT 1 FROM iap_refund_account_holds_v1 h
    WHERE h.owner_key=iap_summon_canonical_v1.owner_key AND h.status='held'
  )`;
}
