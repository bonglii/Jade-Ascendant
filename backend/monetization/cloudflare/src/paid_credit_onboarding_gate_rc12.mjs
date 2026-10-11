/** RC12 — candidate Worker wrapper, never a separate purchase verifier.
 * M13 remains the only Play verification, consume and wallet-credit authority.
 * Canonical initialization after M13 status 200 is idempotent. On failure,
 * return 503: replaying the SAME purchase token repairs initialization without
 * crediting again. No local save or item mutation.
 */
import { InvalidIdentity, verifyFirebaseHeaders } from './jwt_verify.mjs';
import { ensureCanonicalAccountAfterVerifiedCreditRC12 } from './canonical_onboarding_rc12.mjs';
const NO_STORE = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'private, no-store',
  'x-content-type-options': 'nosniff',
};
const errorReply = (status, error) => new Response(JSON.stringify({error}), {status, headers: NO_STORE});
export function createPaidCreditOnboardingGateRC12({
  baseFetch, verifyIdentity = verifyFirebaseHeaders,
  initialize = ensureCanonicalAccountAfterVerifiedCreditRC12,
} = {}) {
  if (typeof baseFetch !== 'function' || typeof verifyIdentity !== 'function'
      || typeof initialize !== 'function') throw new TypeError('invalid_onboarding_wiring');
  return async (request, env, ctx) => {
    const path = new URL(request.url).pathname;
    if (path !== '/v1/iap/authorize-v2') return baseFetch(request, env, ctx);
    // New gate OFF by default, even if somebody accidentally enables M13 alone.
    // Must not contact Play, perform Auth calls, or credit D1 until approved.
    if (env?.JADE_IAP_BACKEND_ENABLED !== 'true'
        || env?.JADE_PAID_WALLET_CREDIT_V2_ENABLED !== 'true'
        || env?.JADE_CANONICAL_ONBOARDING_RC12_ENABLED !== 'true')
      return errorReply(503, 'paid_credit_onboarding_locked');
    if (!env?.DB) return errorReply(503, 'backend_not_configured');
    // Do not process payments for an identity that cannot be re-verified for
    // canonical initialization after M13's successful credit.
    let identity;
    try { identity = await verifyIdentity(request.headers, env); }
    catch { return errorReply(401, 'unauthenticated'); }
    if (!identity?.auth?.uid) return errorReply(401, 'unauthenticated');
    // Original M13 independently authenticates the same signed request.
    const upstream = await baseFetch(request, env, ctx);
    if (upstream.status !== 200) return upstream;
    try {
      await initialize({db: env.DB, verifiedUid: identity.auth.uid});
      return upstream;
    } catch {
      return errorReply(503, 'canonical_onboarding_retry_same_purchase');
    }
  };
}
