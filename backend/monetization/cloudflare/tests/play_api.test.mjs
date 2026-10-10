import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { createPlayGateway } from '../src/play_api.mjs';
const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048, privateKeyEncoding: { type: 'pkcs8', format: 'pem' }, publicKeyEncoding: { type: 'spki', format: 'pem' } });
const secret = JSON.stringify({ type: 'service_account', client_email: 'test@foo.iam.gserviceaccount.com', private_key: privateKey });
const TOKEN = 'purchase.token.example.1234567';
test('Play API adapter signs OAuth assertion and calls verify/consume exact routes', async () => {
  const calls = [];
  const transport = async (url, opts) => {
    calls.push({ url, opts });
    if (url === 'https://oauth2.googleapis.com/token') return new Response(JSON.stringify({ access_token: 'fake-oauth', expires_in: 3600 }), { status: 200 });
    if (opts.method === 'GET') return new Response(JSON.stringify({ purchaseStateContext: { purchaseState: 'PURCHASED' } }), { status: 200 });
    return new Response(null, { status: 204 });
  };
  const gateway = createPlayGateway(secret, transport);
  const result = await gateway.getProductPurchaseV2('com.yungdevstudio.jadeascendant', TOKEN);
  assert.equal(result.purchaseStateContext.purchaseState, 'PURCHASED');
  await gateway.consumeProduct('com.yungdevstudio.jadeascendant', 'jade_pouch_100', TOKEN);
  assert.ok(calls.some(x => x.url.includes('productsv2/tokens/')));
  assert.ok(calls.some(x => x.url.includes(`purchases/products/jade_pouch_100/tokens/${TOKEN}:consume`) && x.opts.method === 'POST'));
  assert.ok(calls.every(x => !String(x.url).includes(privateKey)));
});
test('Play gateway rejects wrong package and unknown product', async () => {
  const gateway = createPlayGateway(secret, async () => { throw new Error('unexpected network'); });
  await assert.rejects(gateway.getProductPurchaseV2('evil.package', TOKEN), /Invalid Play/);
  await assert.rejects(gateway.consumeProduct('com.yungdevstudio.jadeascendant', 'unknown', TOKEN), /Invalid Play/);
});
