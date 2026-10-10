/**
 * JADE M7E4E3: isolated, in-memory crash/fault model. NOT a Firebase endpoint,
 * Android delivery implementation, entitlement authority, or game economy API.
 * Mock credits are numbers in a test object ONLY; no player save can be touched.
 */
import { createHash } from 'node:crypto';

export const M7E4E3_RELEASE_GATES = Object.freeze({
  phase: 'M7E4E3', modelOnly: true, productionEnabled: false,
  nativeTransportRegistered: false, authenticatedDeliveryCallable: false,
  localAtomicGrantImplemented: false, serverAckImplemented: false,
  legacyClientRewardMigrationApproved: false, exactShaCiGreen: false,
});

export class DeliveryDryRunError extends Error {
  constructor(code) { super(code); this.name = 'DeliveryDryRunError'; this.code = code; }
}
const reject = code => { throw new DeliveryDryRunError(code); };
const ID = /^[0-9a-f]{64}$/;
const NAME = /^[A-Za-z0-9:_-]{1,128}$/;
const ACC = /^[A-Za-z0-9_-]{8,96}$/;
const PLACEMENTS = new Set([
  'game_over_revive', 'offline_cultivation_double', 'pavilion_seal',
  'liveops_boss_hunt_double', 'liveops_treasure_hunt_double',
  'daily_completion_cache', 'refinement_supply', 'victory_encore',
  'qi_focus', 'dao_choice_reroll',
]);
const FIELDS = 'accountTag|createdAtMs|entitlementId|placement|rewardAmount|rewardItem|state';
function envelope(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw) ||
      Object.keys(raw).sort().join('|') !== FIELDS ||
      !ACC.test(raw.accountTag) || !ID.test(raw.entitlementId) ||
      !PLACEMENTS.has(raw.placement) || !NAME.test(raw.rewardItem) ||
      !Number.isSafeInteger(raw.rewardAmount) || raw.rewardAmount <= 0 || raw.rewardAmount > 100000 ||
      !Number.isSafeInteger(raw.createdAtMs) || raw.createdAtMs < 0 ||
      raw.state !== 'PENDING_DELIVERY') reject('INVALID_FAKE_SERVER_ENTITLEMENT');
  return Object.freeze({ ...raw });
}
function digest(e) {
  return createHash('sha256').update(JSON.stringify([
    e.accountTag, e.entitlementId, e.placement, e.rewardItem,
    e.rewardAmount, e.createdAtMs,
  ])).digest('hex');
}
function store() { return { receipts: new Map(), currency: new Map() }; }
const FAIL_POINTS = new Set(['before_commit', 'after_commit', 'before_ack', 'ack_timeout', 'after_ack', 'account_changed_before_commit', 'account_changed_after_commit']);
function receiptValid(e, receipt) {
  return receipt && receipt.entitlementId === e.entitlementId &&
    receipt.accountTag === e.accountTag && receipt.digest === digest(e) &&
    receipt.state === 'LOCAL_COMMITTED';
}

/**
 * All dependencies are TEST IN-MEMORY OBJECTS supplied by a Node unit test.
 * reset/restart = construct a new harness with the same {local, server} objects.
 * Never adapt this harness to a real Android save or live Firebase callable.
 */
export function createDeliveryDryRunHarness({ fakeTrustedEntitlements, local = store(), server = { acknowledgements: new Map() }, getAccountTag } = {}) {
  if (!(fakeTrustedEntitlements instanceof Map) || !(local.receipts instanceof Map) ||
      !(local.currency instanceof Map) || !(server.acknowledgements instanceof Map) ||
      typeof getAccountTag !== 'function') reject('QA_HARNESS_REQUIRED');
  const pending = new Map();
  async function attempt(entitlementId, { fault = null } = {}) {
    if (!ID.test(entitlementId)) reject('ENTITLEMENT_ID_INVALID');
    if (fault !== null && !FAIL_POINTS.has(fault)) reject('UNKNOWN_FAULT');
    // Serialize concurrent retries by entitlement. Never use in-memory locks as
    // production reliability evidence; real implementation needs atomic journals.
    const last = pending.get(entitlementId) ?? Promise.resolve();
    const task = last.catch(() => {}).then(async () => {
      const e = envelope(fakeTrustedEntitlements.get(entitlementId));
      const before = getAccountTag();
      if (before !== e.accountTag) reject('ACCOUNT_CHANGED');
      await Promise.resolve();
      if (getAccountTag() !== before) reject('ACCOUNT_CHANGED');
      let old = local.receipts.get(entitlementId);
      const newlyCommittedInThisAttempt = !old;
      if (old && !receiptValid(e, old)) reject('LOCAL_RECEIPT_INTEGRITY_FAILURE');
      if (!old) {
        if (fault === 'before_commit') reject('SIMULATED_CRASH_BEFORE_COMMIT');
        if (fault === 'account_changed_before_commit') reject('ACCOUNT_CHANGED');
        const itemKey = `${e.accountTag}:${e.rewardItem}`;
        const previous = local.currency.get(itemKey) ?? 0;
        if (!Number.isSafeInteger(previous) || previous < 0 ||
            !Number.isSafeInteger(previous + e.rewardAmount)) reject('LOCAL_BALANCE_CORRUPT');
        // Single model step stands in for SaveManager's future atomic journal.
        // It is NOT a real filesystem/database transaction.
        const nextCurrency = new Map(local.currency);
        const nextReceipts = new Map(local.receipts);
        nextCurrency.set(itemKey, previous + e.rewardAmount);
        nextReceipts.set(entitlementId, Object.freeze({
          accountTag: e.accountTag, entitlementId, digest: digest(e), state: 'LOCAL_COMMITTED',
        }));
        local.currency = nextCurrency;
        local.receipts = nextReceipts;
        old = local.receipts.get(entitlementId);
      }
      if (!receiptValid(e, old)) reject('LOCAL_RECEIPT_INTEGRITY_FAILURE');
      if (fault === 'after_commit') reject('SIMULATED_CRASH_AFTER_COMMIT');
      if (fault === 'account_changed_after_commit') reject('ACCOUNT_CHANGED');
      if (getAccountTag() !== before) reject('ACCOUNT_CHANGED');
      if (fault === 'before_ack') reject('SIMULATED_CRASH_BEFORE_ACK');
      if (fault === 'ack_timeout') reject('SIMULATED_ACK_TIMEOUT');
      const priorAck = server.acknowledgements.get(entitlementId);
      if (priorAck && priorAck !== digest(e)) reject('SERVER_ACK_INTEGRITY_FAILURE');
      if (!priorAck) server.acknowledgements.set(entitlementId, digest(e));
      if (fault === 'after_ack') reject('SIMULATED_CRASH_AFTER_ACK');
      return Object.freeze({
        status: priorAck ? 'ALREADY_ACKNOWLEDGED' : 'ACKNOWLEDGED_IN_FAKE_SERVER',
        localGrantNew: newlyCommittedInThisAttempt,
      });
    });
    pending.set(entitlementId, task);
    try { return await task; }
    finally { if (pending.get(entitlementId) === task) pending.delete(entitlementId); }
  }
  return Object.freeze({ attempt, snapshotForTests: () => ({
    receipts: new Map(local.receipts), currency: new Map(local.currency),
    acknowledgements: new Map(server.acknowledgements),
  }) });
}
