/**
 * FastTrack RC: read-only, account-bound view of durable paid summon ownership.
 * NOT a command to mutate local inventory, pity, shards or user:// saves.
 * No account creation, no import of an unverified offline save.
 */
import { createHash } from 'node:crypto';
import { InvalidIdentity, verifyFirebaseHeaders } from './jwt_verify.mjs';
import { CATALOG_V1 } from './summon_catalog_pinned.mjs';

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const PROVIDERS = new Set(['anonymous', 'google.com']);
const KNOWN_ITEMS = new Set(CATALOG_V1.map(x => x.id));
const INT_MAX = 1_000_000_000;
const HEADERS = Object.freeze({
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store, private',
  'pragma': 'no-cache',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer',
  'vary': 'Authorization, X-Firebase-AppCheck',
});
const reply = (status, value) => new Response(JSON.stringify(value), { status, headers: HEADERS });
export class PaidEntitlementsError extends Error {
  constructor(code) { super(code); this.name = 'PaidEntitlementsError'; this.code = code; }
}
function ownerKey(identity) {
  const uid = identity?.auth?.uid;
  if (typeof uid !== 'string' || !UID.test(uid)
      || !PROVIDERS.has(identity?.auth?.token?.firebase?.sign_in_provider)
      || typeof identity?.app?.appId !== 'string' || identity.app.appId.length < 6) throw new InvalidIdentity();
  return `u1:${createHash('sha256').update(uid, 'utf8').digest('hex')}`;
}
function safeInt(n, low, high) { return Number.isSafeInteger(n) && n >= low && n <= high; }
export async function readPaidEntitlementsRC({ db, verifiedIdentity }) {
  if (!db || typeof db.prepare !== 'function') throw new PaidEntitlementsError('db_missing');
  const owner = ownerKey(verifiedIdentity);
  const primary = typeof db.withSession === 'function' ? db.withSession('first-primary') : db;
  const row = await primary.prepare(
    'SELECT status, revision, state_json FROM iap_summon_canonical_v1 WHERE owner_key = ?'
  ).bind(owner).first();
  if (!row || row.status !== 'verified') throw new PaidEntitlementsError('not_provisioned');
  if (!safeInt(row.revision, 0, Number.MAX_SAFE_INTEGER - 1)
      || typeof row.state_json !== 'string' || row.state_json.length > 65536) {
    throw new PaidEntitlementsError('invalid_server_state');
  }
  let state;
  try { state = JSON.parse(row.state_json); } catch { throw new PaidEntitlementsError('invalid_server_state'); }
  const expected = [
    'state_contract_version', 'cleared_stage_keys', 'pity', 'wish_item_id',
    'wish_fate_guaranteed', 'lifetime_pulls', 'inventory', 'refinement_shards',
  ];
  if (!state || typeof state !== 'object' || Array.isArray(state)
      || Object.keys(state).length !== expected.length || expected.some(k => !Object.hasOwn(state, k))
      || state.state_contract_version !== 1 || !safeInt(state.lifetime_pulls, 0, INT_MAX)
      || !safeInt(state.refinement_shards, 0, INT_MAX)
      || !state.inventory || typeof state.inventory !== 'object' || Array.isArray(state.inventory)
      || Object.keys(state.inventory).length > 300) throw new PaidEntitlementsError('invalid_server_state');
  const entries = Object.entries(state.inventory);
  if (entries.some(([id, n]) => !KNOWN_ITEMS.has(id) || n !== 1)) {
    throw new PaidEntitlementsError('invalid_server_state');
  }
  return {
    paid_entitlements_contract_version: 1,
    state: 'verified',
    revision: row.revision,
    item_ids: entries.map(([id]) => id).sort(),
    refinement_shards: state.refinement_shards,
    // Provenance is server-owned, independent of mutable offline inventory.
    authority: 'server_read_only',
  };
}
export function createPaidEntitlementsReadHandlerRC({
  verifyIdentity = verifyFirebaseHeaders,
  readEntitlements = readPaidEntitlementsRC,
} = {}) {
  return async (request, env) => {
    if (request.method !== 'GET') return reply(405, { error: 'method_not_allowed' });
    const url = new URL(request.url);
    if (url.search || request.body !== null || request.headers.has('content-length')) {
      return reply(400, { error: 'unexpected_request_data' });
    }
    // Independent flag allows staging view without ever enabling purchases/spend.
    if (env?.JADE_PAID_ENTITLEMENTS_READ_ENABLED !== 'true') {
      return reply(503, { error: 'paid_entitlements_disabled' });
    }
    if (!env.DB) return reply(503, { error: 'paid_entitlements_not_configured' });
    try {
      const verifiedIdentity = await verifyIdentity(request.headers, env);
      const data = await readEntitlements({ db: env.DB, verifiedIdentity });
      return reply(200, data);
    } catch (err) {
      if (err instanceof InvalidIdentity) return reply(401, { error: 'unauthenticated' });
      if (err instanceof PaidEntitlementsError && err.code === 'not_provisioned') {
        return reply(409, { error: 'paid_progression_not_ready' });
      }
      return reply(503, { error: 'paid_entitlements_temporarily_unavailable' });
    }
  };
}
