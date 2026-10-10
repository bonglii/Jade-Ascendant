/**
 * Jade Ascendant M7E4B — isolated Google AdMob SSV cryptographic boundary.
 * IMPORTANT: not an HTTP endpoint, not a ledger, and NEVER a reward grant.
 * Caller MUST supply a trusted Google public-key set and authoritative intent.
 * Do not accept public keys, expected reward values, or identity from the client.
 */
import { createPublicKey, verify as verifySignature } from 'node:crypto';

const REQUIRED = Object.freeze([
  'ad_network', 'ad_unit', 'reward_amount', 'reward_item',
  'timestamp', 'transaction_id',
]);
const OPTIONAL = new Set(['custom_data', 'user_id']);
const MAX_QUERY_BYTES = 8192;
// Only a result produced by this module's cryptographic verifier may enter the handoff.
const verifiedResults = new WeakSet();

export class SsvRejection extends Error {
  constructor(code) {
    super(code);
    this.name = 'SsvRejection';
    this.code = code;
  }
}

function reject(code) { throw new SsvRejection(code); }

/** Extract signed bytes WITHOUT URLSearchParams or canonical re-serialization. */
export function parseSignedCallback(rawQuery) {
  if (typeof rawQuery !== 'string' || !rawQuery.startsWith('?') ||
      Buffer.byteLength(rawQuery, 'utf8') > MAX_QUERY_BYTES ||
      /[\r\n#]/.test(rawQuery)) reject('MALFORMED_QUERY');
  const query = rawQuery.slice(1);
  // Google specifies signature and key_id as LAST parameters, in that order.
  const tail = query.match(/^(.*)&signature=([A-Za-z0-9_-]+={0,2})&key_id=([1-9][0-9]{0,15})$/);
  if (!tail || !tail[1]) reject('SIGNATURE_TAIL_INVALID');
  const signedPart = tail[1];
  const params = Object.create(null);
  for (const segment of signedPart.split('&')) {
    const eq = segment.indexOf('=');
    if (eq < 1 || /%(?![a-fA-F0-9]{2})/.test(segment)) reject('PARAMETER_ENCODING_INVALID');
    let name, value;
    try {
      name = decodeURIComponent(segment.slice(0, eq));
      value = decodeURIComponent(segment.slice(eq + 1).replace(/\+/g, ' '));
    } catch { reject('PARAMETER_ENCODING_INVALID'); }
    if (!REQUIRED.includes(name) && !OPTIONAL.has(name)) reject('UNKNOWN_PARAMETER');
    if (Object.hasOwn(params, name)) reject('DUPLICATE_PARAMETER');
    if (value.length === 0 || value.length > 1024) reject('PARAMETER_VALUE_INVALID');
    params[name] = value;
  }
  for (const name of REQUIRED) {
    if (!Object.hasOwn(params, name)) reject('MISSING_PARAMETER');
  }
  const signatureText = tail[2].replace(/=+$/, '');
  const signature = Buffer.from(signatureText, 'base64url');
  if (signature.length < 64 || signature.length > 80 ||
      signature.toString('base64url') !== signatureText) reject('SIGNATURE_ENCODING_INVALID');
  return Object.freeze({
    signedBytes: Buffer.from(signedPart, 'utf8'),
    signature,
    keyId: tail[3],
    params: Object.freeze(params),
  });
}

/** Accept only P-256 ECDSA public keys from the trusted Google key downloader. */
export function normalizeTrustedGoogleKeys(googleKeysJson) {
  const list = googleKeysJson?.keys;
  if (!Array.isArray(list) || list.length === 0 || list.length > 128) reject('KEYSET_INVALID');
  const result = Object.create(null);
  for (const entry of list) {
    const id = String(entry?.keyId ?? '');
    if (!/^[1-9][0-9]{0,15}$/.test(id) || Object.hasOwn(result, id) ||
        typeof entry?.pem !== 'string') reject('KEYSET_INVALID');
    let key;
    try { key = createPublicKey(entry.pem); } catch { reject('KEYSET_INVALID'); }
    if (key.asymmetricKeyType !== 'ec' ||
        key.asymmetricKeyDetails?.namedCurve !== 'prime256v1') reject('KEYSET_INVALID');
    result[id] = key;
  }
  return Object.freeze(result);
}

/**
 * Cryptographically verify callback + bind it to the server-issued offer.
 * Expected values MUST be loaded from a server-side intent and AdMob config.
 */
export function verifyGoogleSsv(rawQuery, {
  trustedGoogleKeys,
  expectedAdUnit,
  expectedCustomData,
  expectedRewardAmount,
  expectedRewardItem,
  nowMs = Date.now(),
  maxAgeMs = 24 * 60 * 60 * 1000,
  futureSkewMs = 5 * 60 * 1000,
} = {}) {
  if (!trustedGoogleKeys || typeof trustedGoogleKeys !== 'object' ||
      typeof expectedAdUnit !== 'string' || expectedAdUnit.length === 0 ||
      typeof expectedCustomData !== 'string' ||
      !/^[A-Za-z0-9_-]{24,128}$/.test(expectedCustomData) ||
      !Number.isSafeInteger(expectedRewardAmount) || expectedRewardAmount < 1 ||
      typeof expectedRewardItem !== 'string' || expectedRewardItem.length === 0 ||
      !Number.isSafeInteger(nowMs) ||
      !Number.isSafeInteger(maxAgeMs) || maxAgeMs < 0 ||
      !Number.isSafeInteger(futureSkewMs) || futureSkewMs < 0) {
    reject('SERVER_CONFIGURATION_INVALID');
  }
  const callback = parseSignedCallback(rawQuery);
  const key = trustedGoogleKeys[callback.keyId];
  if (!key || key.asymmetricKeyType !== 'ec' ||
      key.asymmetricKeyDetails?.namedCurve !== 'prime256v1') reject('UNTRUSTED_KEY_ID');
  let isValid = false;
  try { isValid = verifySignature('sha256', callback.signedBytes, key, callback.signature); }
  catch { reject('SIGNATURE_INVALID'); }
  if (!isValid) reject('SIGNATURE_INVALID');

  const p = callback.params;
  if (p.ad_unit !== expectedAdUnit ||
      p.custom_data !== expectedCustomData ||
      p.reward_item !== expectedRewardItem ||
      p.reward_amount !== String(expectedRewardAmount)) reject('INTENT_BINDING_MISMATCH');
  if (!/^[0-9a-fA-F]{16,128}$/.test(p.transaction_id)) reject('TRANSACTION_ID_INVALID');
  // Google docs show both millisecond and older microsecond-looking examples.
  // The deployment must confirm timestamp units; only signed values are used.
  if (!/^\d{13,16}$/.test(p.timestamp)) reject('TIMESTAMP_INVALID');
  const rawTime = Number(p.timestamp);
  if (!Number.isSafeInteger(rawTime)) reject('TIMESTAMP_INVALID');
  const timestampMs = rawTime >= 1e15 ? Math.floor(rawTime / 1000) : rawTime;
  if (timestampMs > nowMs + futureSkewMs || timestampMs < nowMs - maxAgeMs) reject('TIMESTAMP_OUT_OF_WINDOW');
  const verifiedResult = Object.freeze({
    verified: true,
    transactionId: p.transaction_id.toLowerCase(),
    keyId: callback.keyId,
    timestampMs,
    adUnit: p.ad_unit,
    customData: p.custom_data,
    rewardAmount: expectedRewardAmount,
    rewardItem: expectedRewardItem,
    // user_id is client-chosen and MUST NOT become server-side identity.
  });
  verifiedResults.add(verifiedResult);
  return verifiedResult;
}

/**
 * Produce a ledger CANDIDATE only. This module cannot write/grant rewards.
 * An authoritative database transaction must atomically check uniqueness of
 * transactionId, consume the pending intent, enforce caps, and issue reward.
 */
export function buildPendingLedgerCandidate(verified, serverIntent) {
  if (!verified || typeof verified !== 'object' ||
      !verifiedResults.has(verified) || verified.verified !== true ||
      !serverIntent ||
      typeof serverIntent.userId !== 'string' || !serverIntent.userId ||
      typeof serverIntent.intentId !== 'string' || !serverIntent.intentId ||
      typeof serverIntent.placement !== 'string' || !serverIntent.placement ||
      serverIntent.nonce !== verified.customData ||
      serverIntent.adUnit !== verified.adUnit ||
      serverIntent.rewardAmount !== verified.rewardAmount ||
      serverIntent.rewardItem !== verified.rewardItem) reject('PENDING_INTENT_MISMATCH');
  return Object.freeze({
    transactionId: verified.transactionId,
    intentId: serverIntent.intentId,
    userId: serverIntent.userId,
    placement: serverIntent.placement,
    rewardAmount: serverIntent.rewardAmount,
    rewardItem: serverIntent.rewardItem,
    timestampMs: verified.timestampMs,
    state: 'VERIFIED_PENDING_ATOMIC_LEDGER',
  });
}
