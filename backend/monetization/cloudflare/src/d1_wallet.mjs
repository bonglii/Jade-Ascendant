/**
 * Stage-only, not connected to the deployed Worker or the game client.
 *
 * Wallet M1: atomic, idempotent, per-Firebase-UID D1 wallet.
 * IMPORTANT: the caller MUST have verified Firebase Auth + App Check, and
 * MUST call creditVerifiedPurchase only with the returned authorizePurchase
 * grant (after Google Play verification & consume). Never expose raw credit or
 * debit arguments to an HTTP client. A summon endpoint also requires trusted
 * SERVER validation and idempotent fulfillment; it is not implemented here.
 */
import { createHash } from 'node:crypto';
import { PURCHASE_CONTRACT_VERSION, productByInternalId } from '../../src/product_catalog.mjs';

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const GRANT_ID = /^iapv1:[a-f0-9]{64}$/;
const SPEND_ID = /^spendv1:[a-f0-9]{64}$/;
const INTENT = /^summon:(?:1|10)$/;
const MAX_BALANCE = Number.MAX_SAFE_INTEGER;

export class WalletError extends Error {
  constructor(code) {
    super(code);
    this.name = 'WalletError';
    this.code = code;
  }
}

function requireUid(uid) {
  if (typeof uid !== 'string' || !UID.test(uid)) throw new WalletError('invalid_uid');
  return `u1:${createHash('sha256').update(uid, 'utf8').digest('hex')}`;
}

function creditEvent(grant) {
  if (!grant || typeof grant !== 'object' || Array.isArray(grant)
    || Object.keys(grant).length !== 5
    || grant.purchase_contract_version !== PURCHASE_CONTRACT_VERSION
    || grant.state !== 'grant_ready'
    || typeof grant.grant_id !== 'string' || !GRANT_ID.test(grant.grant_id)
    || typeof grant.internal_product_id !== 'string'
    || !Number.isSafeInteger(grant.celestial_jade)) {
    throw new WalletError('invalid_grant');
  }
  const product = productByInternalId(grant.internal_product_id);
  if (!product || product.celestialJade !== grant.celestial_jade) {
    throw new WalletError('invalid_product_amount');
  }
  return { eventKey: grant.grant_id, kind: 'play_credit', itemKey: product.internalProductId,
    delta: product.celestialJade };
}

function internalSpendEvent({ spendId, intent, jadeCost }) {
  if (typeof spendId !== 'string' || !SPEND_ID.test(spendId)
      || typeof intent !== 'string' || !INTENT.test(intent)
      || !Number.isSafeInteger(jadeCost) || jadeCost <= 0) {
    throw new WalletError('invalid_spend');
  }
  return { eventKey: spendId, kind: 'summon_debit', itemKey: intent, delta: -jadeCost };
}

function selectAccount(db, ownerKey) {
  return db.prepare(
    'SELECT balance, revision FROM iap_wallet_accounts_v1 WHERE owner_key = ?'
  ).bind(ownerKey).first();
}

function selectEvent(db, eventKey) {
  return db.prepare(
    'SELECT owner_key, event_kind, item_key, delta FROM iap_wallet_events_v1 WHERE event_key = ?'
  ).bind(eventKey).first();
}

function verifiedEventMatches(row, ownerKey, event) {
  return row && row.owner_key === ownerKey && row.event_kind === event.kind
    && row.item_key === event.itemKey && row.delta === event.delta;
}

export function createD1Wallet(d1) {
  if (!d1 || typeof d1.prepare !== 'function' || typeof d1.batch !== 'function') {
    throw new WalletError('d1_batch_required');
  }
  // Primary-consistent read: D1 replica lag must never determine spendability.
  const primary = () => typeof d1.withSession === 'function' ? d1.withSession('first-primary') : d1;

  async function snapshotForKey(ownerKey) {
    const record = await selectAccount(primary(), ownerKey);
    const balance = record?.balance ?? 0;
    const revision = record?.revision ?? 0;
    if (!Number.isSafeInteger(balance) || balance < 0 ||
        !Number.isSafeInteger(revision) || revision < 0) {
      throw new WalletError('invalid_stored_wallet');
    }
    return { wallet_contract_version: 1, balance, revision };
  }

  async function apply(uid, event) {
    const ownerKey = requireUid(uid);
    // D1 batch is transactional: if INSERT event duplicates or UPDATE violates
    // nonnegative/overflow CHECK, the entire batch rolls back.
    // In particular, do NOT replace this with independent .run() statements.
    try {
      await d1.batch([
        d1.prepare('INSERT OR IGNORE INTO iap_wallet_accounts_v1 (owner_key, balance, revision) VALUES (?, 0, 0)').bind(ownerKey),
        d1.prepare('INSERT INTO iap_wallet_events_v1 (event_key, owner_key, event_kind, item_key, delta) VALUES (?, ?, ?, ?, ?)')
          .bind(event.eventKey, ownerKey, event.kind, event.itemKey, event.delta),
        d1.prepare('UPDATE iap_wallet_accounts_v1 SET balance = balance + ?, revision = revision + 1 WHERE owner_key = ?')
          .bind(event.delta, ownerKey),
      ]);
      return { ...(await snapshotForKey(ownerKey)), applied: true };
    } catch (error) {
      // A replay must be checked by its immutable event contents and owner.
      // Do not treat an arbitrary SQL/network failure as a successful replay.
      const existing = await selectEvent(primary(), event.eventKey);
      if (existing) {
        if (!verifiedEventMatches(existing, ownerKey, event)) {
          throw new WalletError('event_conflict');
        }
        return { ...(await snapshotForKey(ownerKey)), applied: false };
      }
      if (event.delta < 0) {
        const current = await snapshotForKey(ownerKey);
        if (current.balance < -event.delta) throw new WalletError('insufficient_funds');
      }
      throw error;
    }
  }

  return {
    getSnapshot(uid) { return snapshotForKey(requireUid(uid)); },
    creditVerifiedPurchase(uid, verifiedGrant) { return apply(uid, creditEvent(verifiedGrant)); },
    /** INTERNAL only. Cost, outcome & item grant require trusted server authority.
     * This is intentionally NOT exposed as an HTTP route. */
    debitServerAuthorizedSummon(uid, serverAuthorizedSpend) {
      return apply(uid, internalSpendEvent(serverAuthorizedSpend));
    },
  };
}
