/**
 * Wallet M2 — SERVER-INTERNAL adapter. Not exposed in index.mjs.
 * Only an authoritative Google Play grant from authorizePurchase can be credited.
 * Crash/replay recovery: authorizePurchase may return an existing grant_ready;
 * wallet credit is idempotent and repairs the missed credit exactly once.
 *
 * IMPORTANT: The current Godot client still adds the grant to local save.
 * DO NOT connect this to live Worker or enable checkout before completing
 * server-authoritative spend/fulfillment and client wallet cutover.
 */
import { authorizePurchase } from '../../src/purchase_authority.mjs';

function requireWallet(wallet) {
  if (!wallet || typeof wallet.creditVerifiedPurchase !== 'function') {
    throw new TypeError('Authoritative wallet required');
  }
}

function validateWalletReceipt(receipt) {
  if (!receipt || typeof receipt !== 'object' || Array.isArray(receipt)
      || receipt.wallet_contract_version !== 1
      || !Number.isSafeInteger(receipt.balance) || receipt.balance < 0
      || !Number.isSafeInteger(receipt.revision) || receipt.revision < 1
      || typeof receipt.applied !== 'boolean') {
    throw new TypeError('Invalid durable wallet receipt');
  }
  return {
    wallet_contract_version: 1,
    balance: receipt.balance,
    revision: receipt.revision,
  };
}

export async function authorizeAndCreditPurchase({ request, playGateway, ledger, wallet }) {
  requireWallet(wallet);
  // authorizePurchase validates Auth, App Check, token, Google Play purchase,
  // UID account-binding, product, and the durable per-token consume ledger.
  const grant = await authorizePurchase({ request, playGateway, ledger });
  const uid = request.auth.uid; // Safe only after successful authorizePurchase().
  // Never respond with a grant if a wallet write fails. Retry repairs safely.
  const receipt = await wallet.creditVerifiedPurchase(uid, grant);
  return { grant, wallet: validateWalletReceipt(receipt) };
}
