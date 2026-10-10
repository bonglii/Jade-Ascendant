/**
 * M11 — read-only recovery of an already COMMITTED canonical paid summon.
 * This route cannot create an outcome, provision progress, roll RNG or debit Jade.
 * Deployment stays independently fail-closed until D1 wallet migrations and
 * Android once-only inventory reconciliation are reviewed.
 */
import { createHash } from 'node:crypto';
import { InvalidIdentity, verifyFirebaseHeaders } from './jwt_verify.mjs';

const UUID4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const UID = /^[A-Za-z0-9_-]{1,128}$/;
const ITEM = /^[a-z][a-z0-9_]{0,95}$/;
const RARITIES = new Set(['common', 'rare', 'epic', 'legendary']);
const ALLOWED_PROVIDERS = new Set(['anonymous', 'google.com']);
const EXACT_OUTCOME = ['outcome_contract_version', 'pull_count', 'results', 'next_pity'];
const EXACT_RESULT = ['item_id', 'rarity', 'duplicate', 'duplicate_shards', 'hard_legendary_pity', 'wish_hit', 'wish_fate_activated', 'wish_fate_consumed'];
const EXACT_PITY = ['rare_plus', 'epic_plus', 'legendary'];
const HEADERS = Object.freeze({
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store, private',
  'pragma': 'no-cache',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer',
  'vary': 'Authorization, X-Firebase-AppCheck',
});
const reply = (status, data) => new Response(JSON.stringify(data), { status, headers: HEADERS });
const plain = v => v !== null && typeof v === 'object' && !Array.isArray(v) && (Object.getPrototypeOf(v) === Object.prototype || Object.getPrototypeOf(v) === null);
const exact = (v, keys) => plain(v) && Object.keys(v).length === keys.length && keys.every(k => Object.hasOwn(v, k));
const goodInt = (v, min, max) => Number.isSafeInteger(v) && v >= min && v <= max;

export function recoveryKeysM11(uid, requestId) {
  if (typeof uid !== 'string' || !UID.test(uid)) throw new TypeError('invalid_identity');
  if (typeof requestId !== 'string' || !UUID4.test(requestId)) throw new TypeError('invalid_request_id');
  const owner = 'u1:' + createHash('sha256').update(uid).digest('hex');
  const spend = 'spendv1:' + createHash('sha256').update('summon:v1\0' + uid + '\0' + requestId.toLowerCase()).digest('hex');
  return { owner, spend };
}
function requireVerifiedIdentity(identity) {
  const uid = identity?.auth?.uid;
  if (typeof uid !== 'string' || !UID.test(uid)
    || !ALLOWED_PROVIDERS.has(identity?.auth?.token?.firebase?.sign_in_provider)
    || typeof identity?.app?.appId !== 'string' || identity.app.appId.length < 6) {
    throw new TypeError('invalid_identity');
  }
  return uid;
}
function requireStoredOutcome(row) {
  if (!row || !goodInt(row.pull_count, 1, 10) || ![1, 10].includes(row.pull_count)
      || row.jade_cost !== (row.pull_count === 1 ? 100 : 900)
      || typeof row.outcome_json !== 'string'
      || row.outcome_json.length > 16384) throw new TypeError('invalid_stored_outcome');
  const o = JSON.parse(row.outcome_json);
  if (!exact(o, EXACT_OUTCOME) || o.outcome_contract_version !== 1
    || o.pull_count !== row.pull_count
    || !Array.isArray(o.results) || o.results.length !== row.pull_count
    || !exact(o.next_pity, EXACT_PITY)
    || !goodInt(o.next_pity.rare_plus, 0, 9)
    || !goodInt(o.next_pity.epic_plus, 0, 29)
    || !goodInt(o.next_pity.legendary, 0, 49)
    || o.results.some(x => !exact(x, EXACT_RESULT) || typeof x.item_id !== 'string'
      || !ITEM.test(x.item_id) || !RARITIES.has(x.rarity)
      || !goodInt(x.duplicate_shards, 0, 75)
      || ['duplicate', 'hard_legendary_pity', 'wish_hit', 'wish_fate_activated', 'wish_fate_consumed']
        .some(k => typeof x[k] !== 'boolean'))) throw new TypeError('invalid_stored_outcome');
  return o;
}

/** Return a snapshot only for the caller's VERIFIED Firebase UID. */
export async function readCommittedSummonM11({ db, verifiedIdentity, requestId }) {
  const uid = requireVerifiedIdentity(verifiedIdentity);
  const { owner, spend } = recoveryKeysM11(uid, requestId);
  if (!db || typeof db.prepare !== 'function') throw new TypeError('d1_required');
  // First-primary: never trust an eventually lagging replica for recovery.
  const primary = typeof db.withSession === 'function' ? db.withSession('first-primary') : db;
  const record = await primary.prepare(
    'SELECT owner_key,pull_count,jade_cost,outcome_json FROM iap_summon_outcomes_v1 WHERE spend_key = ?'
  ).bind(spend).first();
  if (!record) return null;
  if (record.owner_key !== owner) throw new TypeError('stored_owner_mismatch');
  const outcome = requireStoredOutcome(record);
  return {
    recovery_contract_version: 1,
    request_id: requestId.toLowerCase(),
    state: 'committed',
    spend_id: spend,
    outcome,
  };
}

export function createSummonRecoveryHandlerM11({
  verifyIdentity = verifyFirebaseHeaders,
  readOutcome = readCommittedSummonM11,
} = {}) {
  return async (request, env) => {
    const url = new URL(request.url);
    const prefix = '/v1/wallet/summon-recovery/';
    if (!url.pathname.startsWith(prefix)) return reply(404, { error: 'not_found' });
    if (request.method !== 'GET') return reply(405, { error: 'method_not_allowed' });
    if (url.search || request.body !== null || request.headers.has('content-length')) {
      return reply(400, { error: 'unexpected_request_data' });
    }
    const requestId = url.pathname.slice(prefix.length);
    if (!UUID4.test(requestId)) return reply(400, { error: 'invalid_request_id' });
    // Route must NOT touch auth, Play or D1 while locked.
    if (!env || env.JADE_SUMMON_RECOVERY_READ_ENABLED !== 'true') {
      return reply(503, { error: 'summon_recovery_disabled' });
    }
    if (!env.DB) return reply(503, { error: 'summon_recovery_not_configured' });
    try {
      const verifiedIdentity = await verifyIdentity(request.headers, env);
      const result = await readOutcome({ db: env.DB, verifiedIdentity, requestId });
      return result ? reply(200, result) : reply(404, { error: 'summon_not_found' });
    } catch (e) {
      if (e instanceof InvalidIdentity || e instanceof TypeError && e.message === 'invalid_identity') {
        return reply(401, { error: 'unauthenticated' });
      }
      return reply(503, { error: 'summon_recovery_temporarily_unavailable' });
    }
  };
}
