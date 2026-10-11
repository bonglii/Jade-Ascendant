/**
 * RC8 STAGING: fail-closed Google Play void + stale-refund-poll protection
 * for verified Play wallet credits.
 *
 * Wire this only inside the existing d1_wallet.mjs credit transaction.
 * No HTTP routes, permissions, migrations, account provisioning or grants.
 * Existing wallet event schemas and offline saves stay unchanged.
 */
const GRANT = /^iapv1:([a-f0-9]{64})$/;
const OWNER = /^u1:[a-f0-9]{64}$/;
const FRESH_WINDOW_MS = 2 * 60 * 60 * 1000;
const FUTURE_SKEW_MS = 60_000;

export class RefundCreditGateErrorRC8 extends Error {
  constructor(code) {
    super(code);
    this.name = 'RefundCreditGateErrorRC8';
    this.code = code;
  }
}
function fail(code) { throw new RefundCreditGateErrorRC8(code); }
function requireCreditInputs({ownerKey, eventKey, delta, nowMs}) {
  if (!OWNER.test(ownerKey) || typeof eventKey !== 'string' || !GRANT.test(eventKey) ||
      !Number.isSafeInteger(delta) || delta <= 0 ||
      !Number.isSafeInteger(nowMs) || nowMs <= FRESH_WINDOW_MS) fail('invalid_credit_arguments');
  return 'playtoken:' + eventKey.slice('iapv1:'.length);
}
function primary(db) { return typeof db.withSession === 'function' ? db.withSession('first-primary') : db; }

/**
 * Early fail-closed check for clearer error codes and safe replay behavior.
 * NOT a substitute for makeProtectedCreditUpdateRC8 in the SAME D1 batch.
 */
export async function assertRefundCreditEligibleRC8({db, ownerKey, eventKey, nowMs = Date.now()}) {
  const voidKey = requireCreditInputs({ownerKey,eventKey,delta:1,nowMs});
  if (!db || typeof db.prepare !== 'function') fail('refund_gate_unavailable');
  let row;
  try {
    row = await primary(db).prepare(`SELECT
      EXISTS (SELECT 1 FROM iap_play_void_events_v1 WHERE token_key=?) AS voided,
      EXISTS (SELECT 1 FROM iap_refund_account_holds_v1 WHERE owner_key=? AND status='held') AS held,
      (SELECT watermark_ms FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp') AS watermark_ms`
    ).bind(voidKey,ownerKey).first();
  } catch { fail('refund_gate_unavailable'); }
  if (!row || row.voided !== 0 && row.voided !== 0n || row.held !== 0 && row.held !== 0n)
    fail('refund_or_hold');
  const watermark = Number(row.watermark_ms);
  if (row.watermark_ms === null || row.watermark_ms === undefined ||
      !Number.isSafeInteger(watermark) || watermark < nowMs - FRESH_WINDOW_MS ||
      watermark > nowMs + FUTURE_SKEW_MS) fail('refund_monitor_stale');
  return true;
}

/**
 * One guarded SQL UPDATE. Invalid credit sets balance=-1, violating existing
 * CHECK(balance BETWEEN 0 AND MAX_SAFE_INTEGER) to force D1 batch rollback.
 * This prevents event INSERT surviving a concurrent void or held-account write.
 * D1's batch() must be transactional; never split this into separate run()s.
 */
export function makeProtectedCreditUpdateRC8({db, ownerKey, eventKey, delta, nowMs = Date.now()}) {
  const voidKey = requireCreditInputs({ownerKey,eventKey,delta,nowMs});
  if (!db || typeof db.prepare !== 'function') fail('refund_gate_unavailable');
  return db.prepare(`UPDATE iap_wallet_accounts_v1 SET
    balance = CASE WHEN
      EXISTS (SELECT 1 FROM iap_play_void_cursor_v1 c
        WHERE c.cursor_name='voided_inapp' AND c.watermark_ms BETWEEN ? AND ?)
      AND NOT EXISTS (SELECT 1 FROM iap_play_void_events_v1 v WHERE v.token_key=?)
      AND NOT EXISTS (SELECT 1 FROM iap_refund_account_holds_v1 h
        WHERE h.owner_key=iap_wallet_accounts_v1.owner_key AND h.status='held')
      THEN balance + ? ELSE -1 END,
    revision = revision + 1 WHERE owner_key=?`
  ).bind(nowMs - FRESH_WINDOW_MS, nowMs + FUTURE_SKEW_MS, voidKey, delta, ownerKey);
}
