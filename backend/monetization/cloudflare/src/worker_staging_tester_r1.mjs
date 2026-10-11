/** STAGING ONLY. Never set this entrypoint in wrangler.toml (production). */
import candidate from './worker_release_candidate.mjs';
import { verifyFirebaseHeaders } from './jwt_verify.mjs';
import { createStagingTesterGuardR1 } from './staging_tester_guard_r1.mjs';
const guardedFetch = createStagingTesterGuardR1({
  baseFetch: (request, env, ctx) => candidate.fetch(request, env, ctx),
  verifyIdentity: verifyFirebaseHeaders,
});
const headers = {'content-type':'application/json; charset=utf-8','cache-control':'no-store'};
function fetch(request, env, ctx) {
  const url = new URL(request.url);
  if (url.hostname !== 'jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev')
    return new Response(JSON.stringify({error:'invalid_staging_host'}), {status:421,headers});
  if (request.method === 'GET' && url.pathname === '/health') {
    const credit = env?.JADE_IAP_BACKEND_ENABLED === 'true'
      && env?.JADE_PAID_WALLET_CREDIT_V2_ENABLED === 'true'
      && env?.JADE_CANONICAL_ONBOARDING_RC12_ENABLED === 'true';
    return new Response(JSON.stringify({
      service:'jade-iap-staging',
      activation: credit ? 'tester_credit_only' : 'locked',
      tester_guard: env?.JADE_STAGING_ACCOUNT_GUARD === 'true',
    }), {status:200,headers});
  }
  return guardedFetch(request, env, ctx);
}
export default { fetch, scheduled: candidate.scheduled };
