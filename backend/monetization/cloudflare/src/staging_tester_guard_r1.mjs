/** Jade Ascendant: server-side staging tester gate. Source is STAGING ONLY.
 * All /v1 HTTP surfaces are identity-allowlisted if ANY paid backend flag is on.
 * The hash of a verified Firebase UID is stored as a Worker secret. No raw UID,
 * Play token, or Google Play account email is accepted in HTTP payloads.
 */
const STAGE_HOST = 'jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev';
const NO_STORE = Object.freeze({
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'private, no-store',
  'x-content-type-options': 'nosniff',
});
const error = (code, status) => new Response(JSON.stringify({error: code}), {status, headers: NO_STORE});
const isSha256 = s => typeof s === 'string' && /^[0-9a-f]{64}$/.test(s);
const relevantFlag = k => /^JADE_[A-Z0-9_]+$/.test(k)
  && !k.startsWith('JADE_STAGING_') && /(ENABLED|READY|APPROVED)$/.test(k);
const paidActive = env => env && Object.keys(env).some(k => relevantFlag(k) && env[k] === 'true');

export function createStagingTesterGuardR1({baseFetch, verifyIdentity}) {
  if (typeof baseFetch !== 'function' || typeof verifyIdentity !== 'function')
    throw new TypeError('staging_guard_requires_verified_identity_and_base');
  return async function stagingTesterGuard(request, env, ctx) {
    const url = new URL(request.url);
    if (url.hostname !== STAGE_HOST) return error('invalid_staging_host', 421);
    // Keep locked Worker responses identical until the first payment gate is enabled.
    if (!url.pathname.startsWith('/v1/') || !paidActive(env)) return baseFetch(request, env, ctx);
    if (env?.JADE_STAGING_ACCOUNT_GUARD !== 'true'
        || !isSha256(env?.JADE_STAGING_TESTER_UID_SHA256)
        || (env?.JADE_STAGING_SECOND_TESTER_UID_SHA256 !== undefined
          && !isSha256(env.JADE_STAGING_SECOND_TESTER_UID_SHA256))
        || !env?.DB) return error('staging_tester_guard_unconfigured', 503);
    // No client-supplied UID or email. Verify signed Firebase Auth AND App Check.
    let identity;
    try { identity = await verifyIdentity(request.headers, env); }
    catch { return error('unauthenticated', 401); }
    const uid = identity?.auth?.uid;
    if (typeof uid !== 'string' || uid.length < 6 || uid.length > 128)
      return error('unauthenticated', 401);
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(uid));
    const hex = [...new Uint8Array(digest)].map(x => x.toString(16).padStart(2, '0')).join('');
    if (hex !== env.JADE_STAGING_TESTER_UID_SHA256
        && hex !== env.JADE_STAGING_SECOND_TESTER_UID_SHA256)
      return error('staging_tester_not_allowed', 403);
    return baseFetch(request, env, ctx);
  };
}
