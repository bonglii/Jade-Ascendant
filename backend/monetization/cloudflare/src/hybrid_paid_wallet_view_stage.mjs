/**
 * M6 SERVER-INTERNAL read-only paid-balance projection. Never accepts local
 * Jade amounts and never exposes a mutable/credit endpoint. The caller must
 * pass the *result* of Firebase Auth+App Check verification (NOT request body).
 * Not imported by the deployed Worker.
 */
const UID = /^[A-Za-z0-9_-]{1,128}$/;
const ALLOWED = new Set(['anonymous','google.com']);
export class HybridPaidViewError extends Error {
  constructor(code) { super(code); this.name='HybridPaidViewError'; this.code=code; }
}
const fail = code => { throw new HybridPaidViewError(code); };

export async function getVerifiedPaidWalletView({ verifiedIdentity, wallet }) {
  const uid=verifiedIdentity?.auth?.uid;
  const firebase=verifiedIdentity?.auth?.token?.firebase;
  const appId=verifiedIdentity?.app?.appId;
  if (typeof uid !== 'string' || !UID.test(uid) ||
      !ALLOWED.has(firebase?.sign_in_provider) ||
      typeof appId !== 'string' || appId.length < 6) fail('verified_identity_required');
  if (!wallet || typeof wallet.getSnapshot !== 'function') fail('authoritative_wallet_required');
  const snapshot=await wallet.getSnapshot(uid);
  if (!snapshot || snapshot.wallet_contract_version!==1 ||
      !Number.isSafeInteger(snapshot.balance) || snapshot.balance < 0 ||
      !Number.isSafeInteger(snapshot.revision) || snapshot.revision < 0 ||
      Object.keys(snapshot).some(k=>!['wallet_contract_version','balance','revision'].includes(k))) fail('invalid_paid_wallet_snapshot');
  return {
    hybrid_policy_version:1,
    paid_wallet:{currency:'celestial_jade',authority:'server',balance:snapshot.balance,revision:snapshot.revision},
    local_wallet_authority:'device_only_untrusted',
    legacy_wallet_migration:'requires_explicit_reconciliation',
  };
}
