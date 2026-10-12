/** Staging credit readiness BEFORE contacting/consuming Google Play.
 * This is NOT purchase authorization: it never grants, consumes or stores money.
 * The original atomic refund/hold check in d1_wallet remains mandatory.
 */
import { createHash } from 'node:crypto';
import { assertRefundCreditEligibleRC8 } from './wallet_refund_credit_rc8.mjs';

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const TOKEN = /^[\x21-\x7e]{16,4096}$/;
const digest = value => createHash('sha256').update(value,'utf8').digest('hex');

export async function assertPreconsumeCreditReadinessR1({db, verifiedUid, purchaseToken, nowMs} = {}) {
  if (typeof verifiedUid !== 'string' || !UID.test(verifiedUid) ||
      typeof purchaseToken !== 'string' || !TOKEN.test(purchaseToken))
    throw new TypeError('invalid_signed_purchase_input');
  const ownerKey = 'u1:' + digest(verifiedUid);
  const eventKey = 'iapv1:' + digest(purchaseToken);
  return assertRefundCreditEligibleRC8({db,ownerKey,eventKey,nowMs});
}
