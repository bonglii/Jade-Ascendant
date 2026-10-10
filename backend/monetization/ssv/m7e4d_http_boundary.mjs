/**
 * M7E4D: HTTP SSV intake with an injected privileged Firestore and key source.
 * Only acknowledges after a durable verified ledger transaction. No payouts.
 */
import { acceptVerifiedSsvReceipt, LedgerRejection } from './m7e4c_receipt_ledger.mjs';
import { SsvRejection } from './m7e4b_ssv_verifier.mjs';

function send(res, status, body) {
  res.statusCode = status;
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.end(body);
}
function rawCallbackQuery(req) {
  const url = req.originalUrl ?? req.url;
  if (typeof url !== 'string' || url.length > 9000 || /[\r\n#]/.test(url)) return null;
  const mark = url.indexOf('?');
  if (mark <= 0 || mark === url.length - 1) return null;
  return url.slice(mark);
}

export function createSsvHttpHandler({ db, getTrustedGoogleKeys, now = Date.now, enabled = false } = {}) {
  if (!db || typeof db.runTransaction !== 'function' || typeof db.collection !== 'function' ||
      typeof getTrustedGoogleKeys !== 'function' || typeof now !== 'function') {
    throw new Error('SSV_HTTP_DEPENDENCY_INVALID');
  }
  return async function ssvHttpHandler(req, res) {
    // This flag must be supplied by a server-only environment, never the client.
    if (!enabled) return send(res, 503, 'DISABLED');
    if (req.method !== 'GET') return send(res, 405, 'METHOD_NOT_ALLOWED');
    const query = rawCallbackQuery(req);
    if (!query) return send(res, 400, 'MALFORMED_QUERY');
    try {
      const trustedGoogleKeys = await getTrustedGoogleKeys();
      const result = await acceptVerifiedSsvReceipt({
        rawQuery: query, trustedGoogleKeys, db, nowMs: now(),
      });
      // 200 means recorded or idempotently already recorded, NOT delivered.
      if (result.status !== 'VERIFIED_PENDING_DELIVERY' && result.status !== 'ALREADY_RECORDED') {
        return send(res, 503, 'NOT_RECORDED');
      }
      return send(res, 200, 'OK');
    } catch (error) {
      // No raw callback data, identities, signatures, or nonces in public output.
      if (error instanceof SsvRejection || error instanceof LedgerRejection) {
        return send(res, 403, 'REJECTED');
      }
      // Missing keys, timeouts and Firestore failures must not be acknowledged.
      return send(res, 503, 'RETRY_LATER');
    }
  };
}

/** Call only from an isolated emulator Firebase Functions entrypoint. */
export function isEmulatorOnlyEnabled(env = process.env) {
  return env.FUNCTIONS_EMULATOR === 'true' &&
    typeof env.FIRESTORE_EMULATOR_HOST === 'string' &&
    /^(127\.0\.0\.1|localhost|\[::1\]):\d{2,5}$/.test(env.FIRESTORE_EMULATOR_HOST) &&
    env.JADE_SSV_EMULATOR_TEST_ONLY === '1' &&
    typeof env.GCLOUD_PROJECT === 'string' && env.GCLOUD_PROJECT.startsWith('demo-');
}
