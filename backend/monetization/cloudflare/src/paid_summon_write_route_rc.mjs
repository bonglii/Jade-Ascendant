/**
 * FastTrack RC: server-authoritative paid summon HTTP boundary.
 * Never accepts local wallet balances, equipment pool, progression, RNG or pity.
 * WITHOUT separately verified canonical progression and client entitlement overlay,
 * the independent gate MUST remain false. No auto-provisioning path exists.
 */
import { InvalidIdentity, verifyFirebaseHeaders } from './jwt_verify.mjs';
import { createCanonicalSummonStage, CanonicalStageError } from './summon_canonical_stage.mjs';
import { resolveTrustedSummonStage } from './summon_trusted_resolver_stage.mjs';

const UUID4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const UID = /^[A-Za-z0-9_-]{1,128}$/;
const PROVIDERS = new Set(['anonymous', 'google.com']);
const MAX_BODY = 512;
const HEADERS = Object.freeze({
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store, private',
  'pragma': 'no-cache',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer',
  'vary': 'Authorization, X-Firebase-AppCheck',
});
const reply = (status, body) => new Response(JSON.stringify(body), { status, headers: HEADERS });
function requireUid(identity) {
  const uid = identity?.auth?.uid;
  if (typeof uid !== 'string' || !UID.test(uid)
      || !PROVIDERS.has(identity?.auth?.token?.firebase?.sign_in_provider)
      || typeof identity?.app?.appId !== 'string' || identity.app.appId.length < 6) {
    throw new InvalidIdentity();
  }
  return uid;
}
async function parseBody(request) {
  if (!/^application\/json(?:\s*;|$)/i.test(request.headers.get('content-type') ?? '')) throw new TypeError('invalid_type');
  if (!request.body) throw new TypeError('missing_body');
  const length = request.headers.get('content-length');
  if (length !== null && (!/^\d+$/.test(length) || Number(length) > MAX_BODY)) throw new TypeError('invalid_length');
  const reader = request.body.getReader();
  const parts = [];
  let n = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      n += value.byteLength;
      if (n > MAX_BODY) { await reader.cancel(); throw new TypeError('too_large'); }
      parts.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(n);
  let at = 0;
  for (const part of parts) { bytes.set(part, at); at += part.byteLength; }
  const payload = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
  if (payload === null || typeof payload !== 'object' || Array.isArray(payload)
      || Object.keys(payload).length !== 2 || !Object.hasOwn(payload, 'request_id')
      || !Object.hasOwn(payload, 'pull_count') || typeof payload.request_id !== 'string'
      || !UUID4.test(payload.request_id) || ![1, 10].includes(payload.pull_count)) {
    throw new TypeError('invalid_payload');
  }
  return { requestId: payload.request_id.toLowerCase(), pullCount: payload.pull_count };
}
function receipt(result, requestId, pullCount) {
  if (!result || typeof result.spend_id !== 'string' || !/^spendv1:[a-f0-9]{64}$/.test(result.spend_id)
      || result.outcome?.outcome_contract_version !== 1
      || result.outcome.pull_count !== pullCount
      || !Array.isArray(result.outcome.results) || result.outcome.results.length !== pullCount
      || result.wallet?.wallet_contract_version !== 1
      || !Number.isSafeInteger(result.wallet.balance) || result.wallet.balance < 0
      || !Number.isSafeInteger(result.wallet.revision) || result.wallet.revision < 0) {
    throw new TypeError('invalid_server_receipt');
  }
  // Replay uses the same request ID and immutable server outcome; never expose
  // a client-usable amount, grant, or local inventory mutation instruction.
  return {
    paid_summon_contract_version: 1,
    state: 'committed',
    request_id: requestId,
    spend_id: result.spend_id,
    outcome: result.outcome,
    wallet: { wallet_contract_version: 1, balance: result.wallet.balance, revision: result.wallet.revision },
  };
}
export function createPaidSummonWriteHandlerRC({
  verifyIdentity = verifyFirebaseHeaders,
  makeCoordinator = createCanonicalSummonStage,
  resolveTrustedTransition = resolveTrustedSummonStage,
} = {}) {
  return async (request, env) => {
    if (request.method !== 'POST') return reply(405, { error: 'method_not_allowed' });
    // Two independent backend locks; do not touch Auth, D1, or RNG if disabled.
    if (env?.JADE_IAP_BACKEND_ENABLED !== 'true' || env?.JADE_PAID_SUMMON_WRITE_ENABLED !== 'true') {
      return reply(503, { error: 'paid_summon_disabled' });
    }
    if (!env.DB || typeof env.DB.prepare !== 'function' || typeof env.DB.batch !== 'function') {
      return reply(503, { error: 'paid_summon_not_configured' });
    }
    try {
      if (new URL(request.url).search) throw new TypeError('invalid_query');
      const uid = requireUid(await verifyIdentity(request.headers, env));
      const { requestId, pullCount } = await parseBody(request);
      const transaction = await makeCoordinator(env.DB).execute({ uid, requestId, pullCount, resolveTrustedTransition });
      return reply(200, receipt(transaction, requestId, pullCount));
    } catch (err) {
      if (err instanceof InvalidIdentity) return reply(401, { error: 'unauthenticated' });
      if (err instanceof CanonicalStageError) {
        if (['canonical_state_not_verified', 'summon_not_unlocked'].includes(err.code)) {
          return reply(409, { error: 'paid_progression_not_ready' });
        }
        if (err.code === 'insufficient_funds') return reply(409, { error: 'insufficient_paid_jade' });
        if (err.code === 'operation_conflict') return reply(409, { error: 'idempotency_conflict' });
        if (err.code === 'state_contention_retry') return reply(409, { error: 'retry_with_same_request_id' });
      }
      if (err instanceof TypeError || err instanceof SyntaxError) return reply(400, { error: 'invalid_argument' });
      return reply(503, { error: 'paid_summon_temporarily_unavailable' });
    }
  };
}
