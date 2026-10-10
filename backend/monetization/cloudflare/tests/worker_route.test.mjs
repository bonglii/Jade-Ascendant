import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, copyFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

// Test HTTP route using a minimal fake policy only in TEMP files. Production import
// continues to use backend/monetization/src/purchase_authority.mjs, never this fake.
const fixture = mkdtempSync(join(tmpdir(), 'jade-iap-worker-route-'));
const monet = join(fixture, 'backend', 'monetization');
const src = join(monet, 'cloudflare', 'src');
mkdirSync(src, { recursive: true });
mkdirSync(join(monet, 'src'), { recursive: true });
writeFileSync(join(fixture, 'package.json'), '{"type":"module"}');
for (const name of ['index.mjs', 'd1_ledger.mjs', 'play_api.mjs', 'jwt_verify.mjs', 'paid_wallet_read_route_m8.mjs', 'd1_wallet.mjs', 'hybrid_paid_wallet_view_stage.mjs', 'summon_recovery_route_m11.mjs', 'paid_purchase_credit_route_m13.mjs', 'purchase_wallet_authority.mjs', 'paid_summon_write_route_rc.mjs', 'paid_entitlements_read_route_rc.mjs', 'summon_canonical_stage.mjs', 'summon_trusted_resolver_stage.mjs', 'summon_catalog_pinned.mjs']) {
  copyFileSync(resolve(fileURLToPath(import.meta.url), '..', '..', 'src', name), join(src, name));
}
copyFileSync(resolve(fileURLToPath(import.meta.url), '..', '..', '..', 'src', 'product_catalog.mjs'), join(monet, 'src', 'product_catalog.mjs'));
writeFileSync(join(monet, 'src', 'purchase_authority.mjs'), `
export class PurchaseAuthorityError extends Error { constructor(code) { super(code); this.code = code; } }
export async function authorizePurchase({ request }) {
  if (!request.data || Object.keys(request.data).join(',') !== 'purchase_token') throw new PurchaseAuthorityError('invalid-argument');
  return { state: 'grant_ready', grant_id: 'fake_test_grant', celestial_jade: 100 };
}
`);
const worker = await import(pathToFileURL(join(src, 'index.mjs')).href);
const endpoint = 'https://jade-example.workers.dev/v1/iap/authorize';
const makeReq = (body = { purchase_token: 'test-purchase-token-123456789' }, method = 'POST') =>
  new Request(endpoint, { method, headers: { 'Content-Type': 'application/json' }, body: method === 'POST' ? JSON.stringify(body) : undefined });

test('Worker starts locked (503) with no secrets and no external requests', async () => {
  const result = await worker.default.fetch(makeReq(), { JADE_IAP_BACKEND_ENABLED: 'false' });
  assert.equal(result.status, 503);
  assert.deepEqual(await result.json(), { error: 'purchase_backend_disabled' });
});
test('Legacy Worker route retires when global IAP flag accidentally enabled', async () => {
  const result = await worker.default.fetch(makeReq(), { JADE_IAP_BACKEND_ENABLED: 'true' });
  assert.equal(result.status, 410);
});
test('Old purchase route never returns a locally-creditable grant even if enabled', async () => {
  let authorized = 0;
  const handler = worker.createWorkerHandler({
    verifyIdentity: async () => { authorized++; return { auth: { uid: 'uid_test' } }; },
  });
  const env = { JADE_IAP_BACKEND_ENABLED: 'true', JADE_PAID_WALLET_CREDIT_V2_ENABLED: 'true',
    DB: {}, PLAY_SERVICE_ACCOUNT_JSON: 'dummy' };
  const result = await handler(makeReq(), env);
  assert.equal(result.status, 410);
  assert.deepEqual(await result.json(), { error: 'legacy_purchase_route_retired' });
  assert.equal(authorized, 0);
});
