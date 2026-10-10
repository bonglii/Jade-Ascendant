/**
 * M8 CANDIDATE ONLY — authenticated, read-only paid wallet snapshot.
 * NOT imported by deployed index.mjs. Do not expose until remote wallet schema,
 * review of quotas/abuse, and Android+Godot sync safety pass.
 * Separate read gate means keeping purchase gate FALSE is not enough to enable.
 */
import { verifyFirebaseHeaders, InvalidIdentity } from './jwt_verify.mjs';
import { createD1Wallet } from './d1_wallet.mjs';
import { getVerifiedPaidWalletView, HybridPaidViewError } from './hybrid_paid_wallet_view_stage.mjs';

const HEADERS = Object.freeze({
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store, private',
  'pragma': 'no-cache',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer',
  'vary': 'Authorization, X-Firebase-AppCheck',
});
const reply = (status, data) => new Response(JSON.stringify(data), { status, headers: HEADERS });

export function createPaidWalletReadHandlerM8({
  verifyIdentity = verifyFirebaseHeaders,
  makeWallet = createD1Wallet,
  projectView = getVerifiedPaidWalletView,
} = {}) {
  return async (request, env) => {
    let url;
    try { url = new URL(request.url); } catch { return reply(400, { error: 'bad_request' }); }
    if (url.pathname !== '/v1/wallet/paid') return reply(404, { error: 'not_found' });
    if (request.method !== 'GET') return reply(405, { error: 'method_not_allowed' });
    // No caller-supplied UID, balance, token or operation is accepted.
    if (url.search || request.headers.get('content-length') !== null || request.body !== null) {
      return reply(400, { error: 'unexpected_request_data' });
    }
    // Never allow the read endpoint solely because the purchase endpoint is locked.
    if (!env || env.JADE_PAID_WALLET_READ_ENABLED !== 'true') {
      return reply(503, { error: 'paid_wallet_read_disabled' });
    }
    if (!env.DB) return reply(503, { error: 'paid_wallet_not_configured' });
    try {
      const verifiedIdentity = await verifyIdentity(request.headers, env);
      const wallet = makeWallet(env.DB);
      const view = await projectView({ verifiedIdentity, wallet });
      return reply(200, view);
    } catch (error) {
      if (error instanceof InvalidIdentity || error instanceof HybridPaidViewError && error.code === 'verified_identity_required') {
        return reply(401, { error: 'unauthenticated' });
      }
      // Do not leak DB errors, tokens or identity-provider responses to clients.
      return reply(503, { error: 'paid_wallet_temporarily_unavailable' });
    }
  };
}
