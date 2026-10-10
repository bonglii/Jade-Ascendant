/**
 * M13 — A separate, fail-closed SERVER WALLET credit route.
 * Not enabled in deployed Worker until deliberate wallet migration and Android
 * client cutover. Never returns a grant that a device can add to local Jade.
 *
 * The trusted purchase authority first verifies Google Play and records the
 * consumed purchase token, then the wallet adapter idempotently credits D1.
 * On crash between consume and wallet write, replay with the SAME Play token
 * repairs the wallet credit. No client-provided UID/product/amount is accepted.
 */
import { authorizeAndCreditPurchase } from './purchase_wallet_authority.mjs';
import { createD1Wallet, WalletError } from './d1_wallet.mjs';
import { createD1Ledger } from './d1_ledger.mjs';
import { createPlayGateway } from './play_api.mjs';
import { InvalidIdentity, verifyFirebaseHeaders } from './jwt_verify.mjs';
import { PurchaseAuthorityError } from '../../src/purchase_authority.mjs';

const MAX_BODY = 8192;
const TOKEN = /^[\x21-\x7e]{16,4096}$/;
const HEADERS = Object.freeze({
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'private, no-store',
  'pragma': 'no-cache',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer',
  'vary': 'Authorization, X-Firebase-AppCheck',
});
const reply = (status, body) => new Response(JSON.stringify(body), { status, headers: HEADERS });

async function readPayload(request) {
  const type = request.headers.get('content-type') || '';
  if (!/^application\/json(?:\s*;|$)/i.test(type)) throw new TypeError('invalid_type');
  if (!request.body) throw new TypeError('missing_body');
  const len = request.headers.get('content-length');
  if (len !== null && (!/^\d+$/.test(len) || Number(len) > MAX_BODY)) throw new TypeError('invalid_length');
  const reader = request.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_BODY) {
        await reader.cancel();
        throw new TypeError('too_large');
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  const data = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
  if (!data || Object.getPrototypeOf(data) !== Object.prototype
      || Object.keys(data).length !== 1
      || !Object.hasOwn(data, 'purchase_token')
      || typeof data.purchase_token !== 'string'
      || !TOKEN.test(data.purchase_token)) throw new TypeError('invalid_payload');
  return data;
}

function safeWalletReceipt(receipt) {
  // Neither Play grant ID nor a local spendable credit is returned to Android.
  const wallet = receipt?.wallet;
  if (!wallet || wallet.wallet_contract_version !== 1
      || !Number.isSafeInteger(wallet.balance) || wallet.balance < 0
      || !Number.isSafeInteger(wallet.revision) || wallet.revision < 1) {
    throw new WalletError('invalid_authoritative_receipt');
  }
  return {
    purchase_receipt_version: 1,
    state: 'server_wallet_credited',
    wallet: {
      wallet_contract_version: 1,
      balance: wallet.balance,
      revision: wallet.revision,
    },
  };
}

export function createPaidPurchaseCreditHandlerM13({
  verifyIdentity = verifyFirebaseHeaders,
  authorizeAndCredit = authorizeAndCreditPurchase,
  makeWallet = createD1Wallet,
  makeLedger = createD1Ledger,
  makePlay = createPlayGateway,
} = {}) {
  return async function paidPurchaseCreditHandler(request, env) {
    if (request.method !== 'POST') return reply(405, { error: 'method_not_allowed' });
    // Both gates are mandatory. No auth checks, D1 writes or Play calls while locked.
    if (env?.JADE_IAP_BACKEND_ENABLED !== 'true'
        || env?.JADE_PAID_WALLET_CREDIT_V2_ENABLED !== 'true') {
      return reply(503, { error: 'paid_wallet_credit_disabled' });
    }
    if (!env.DB || !env.PLAY_SERVICE_ACCOUNT_JSON) return reply(503, { error: 'backend_not_configured' });
    try {
      const identity = await verifyIdentity(request.headers, env);
      const data = await readPayload(request);
      const authorized = await authorizeAndCredit({
        request: { ...identity, data },
        playGateway: makePlay(env.PLAY_SERVICE_ACCOUNT_JSON),
        ledger: makeLedger(env.DB),
        wallet: makeWallet(env.DB),
      });
      return reply(200, safeWalletReceipt(authorized));
    } catch (error) {
      if (error instanceof InvalidIdentity) return reply(401, { error: 'unauthenticated' });
      if (error instanceof PurchaseAuthorityError) {
        const status = error.code === 'unauthenticated' ? 401
          : error.code === 'permission-denied' ? 403
          : error.code === 'invalid-argument' ? 400
          : error.code === 'failed-precondition' ? 409 : 503;
        return reply(status, { error: status === 503 ? 'purchase_temporarily_unavailable' : error.code });
      }
      if (error instanceof WalletError) {
        const status = error.code === 'event_conflict' ? 409 : 503;
        return reply(status, { error: status === 409 ? 'wallet_event_conflict' : 'wallet_temporarily_unavailable' });
      }
      if (error instanceof SyntaxError || error instanceof TypeError) return reply(400, { error: 'invalid_argument' });
      // Do not leak tokens, credentials, Play API responses or SQL query bodies.
      return reply(503, { error: 'temporary_failure' });
    }
  };
}
