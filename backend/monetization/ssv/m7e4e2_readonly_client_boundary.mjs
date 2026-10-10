/**
 * M7E4E2: fail-closed display-only client synchronisation contract.
 * NOT a grant, acknowledgement, SSV receipt proof, or Firebase login token.
 * Only the native SDK is permitted to fetch the remote inbox; injected functions
 * are test seams and must never be exposed as a GDScript arbitrary callable.
 */
export class InboxSyncRejection extends Error {
  constructor(code) { super(code); this.name = 'InboxSyncRejection'; this.code = code; }
}
const fail = code => { throw new InboxSyncRejection(code); };
const id = s => typeof s === 'string' && /^[0-9a-f]{64}$/.test(s);
const placement = s => typeof s === 'string' && [
  'game_over_revive', 'offline_cultivation_double', 'pavilion_seal',
  'liveops_boss_hunt_double', 'liveops_treasure_hunt_double',
  'daily_completion_cache', 'refinement_supply', 'victory_encore',
  'qi_focus', 'dao_choice_reroll',
].includes(s);
const itemName = s => typeof s === 'string' && /^[A-Za-z0-9:_-]{1,128}$/.test(s);
export function inspectReadOnlyInbox(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw) ||
      raw.status !== 'READ_ONLY_PENDING' || raw.creditAllowed !== false ||
      raw.clientAckAllowed !== false || typeof raw.hasMore !== 'boolean' ||
      !Array.isArray(raw.items) || raw.items.length > 20) fail('UNTRUSTED_INBOX_RESPONSE');
  const ids = new Set();
  for (const entry of raw.items) {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry) ||
        Object.keys(entry).sort().join('|') !==
          'createdAtMs|entitlementId|placement|rewardAmount|rewardItem|state' ||
        !id(entry.entitlementId) || !placement(entry.placement) ||
        !itemName(entry.rewardItem) || !Number.isSafeInteger(entry.rewardAmount) ||
        entry.rewardAmount <= 0 || !Number.isSafeInteger(entry.createdAtMs) ||
        entry.createdAtMs < 0 || entry.state !== 'PENDING_DELIVERY' ||
        ids.has(entry.entitlementId)) fail('UNTRUSTED_INBOX_ITEM');
    ids.add(entry.entitlementId);
  }
  // Deliberately do not return IDs, reward amounts, UIDs, transaction data, or tokens.
  return Object.freeze({ status: 'READ_ONLY_PENDING', pendingCount: raw.items.length,
    hasMore: raw.hasMore, canGrant: false, canAcknowledge: false });
}
function validSession(x) {
  return x && x.authenticated === true &&
    typeof x.sessionTag === 'string' && /^[A-Za-z0-9_-]{8,96}$/.test(x.sessionTag);
}
/**
 * A sessionTag is a PRIVATE locally-generated identity-generation marker. It is
 * NOT a Firebase UID/token. The native transport must recheck Firebase user UID.
 */
export async function observePendingInbox({ getSession, readNativeInbox, enabled = false } = {}) {
  if (!enabled) return Object.freeze({ status: 'DISABLED', pendingCount: 0,
    canGrant: false, canAcknowledge: false });
  if (typeof getSession !== 'function' || typeof readNativeInbox !== 'function')
    fail('TRUSTED_TRANSPORT_REQUIRED');
  const first = getSession();
  if (!validSession(first)) fail('AUTH_REQUIRED');
  let response;
  try { response = await readNativeInbox(); }
  catch (_) { fail('INBOX_UNAVAILABLE'); }
  const last = getSession();
  if (!validSession(last) || last.sessionTag !== first.sessionTag) fail('ACCOUNT_CHANGED');
  return inspectReadOnlyInbox(response);
}
export const M7E4E2_RELEASE_GATES = Object.freeze({
  transportRegistered: false, callableRegistered: false, AndroidRewardGrant: false,
  clientAckEnabled: false, productionEnabled: false,
  localReceiptJournalBuilt: false, authenticatedDeliveryEnabled: false,
});
