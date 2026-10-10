/**
 * M6 HYBRID CLIENT POLICY REFERENCE — source staging only, not a Worker route.
 * All amounts are *display/decision hints*; the server never trusts them for
 * paid credit or debit. Do not blend offline Jade into server wallet.
 *
 * earned: newly earned *local* currency (future explicit tracking)
 * legacy: existing pavilion.save celestial_jade, UNCLASSIFIED — may contain
 *         old test purchases; preserve, NEVER promote to paid automatically.
 * paid: immutable server-authorized operation (no local debit).
 */
export class HybridWalletPolicyError extends Error {
  constructor(code) { super(code); this.name = 'HybridWalletPolicyError'; this.code = code; }
}
const fail = code => { throw new HybridWalletPolicyError(code); };
const plain = x => x !== null && typeof x === 'object' && !Array.isArray(x) && (Object.getPrototypeOf(x) === Object.prototype || Object.getPrototypeOf(x) === null);
const validJade = x => Number.isSafeInteger(x) && x >= 0;
const COSTS = Object.freeze({ 1:100, 10:900 });

/** Preserves an old save untouched; never claims unverified old purchases. */
export function classifyLegacyJade(save) {
  if (!plain(save) || !validJade(save.celestial_jade)) fail('invalid_legacy_save');
  const grants = save.processed_iap_grant_ids ?? [];
  if (!Array.isArray(grants) || grants.length > 100000 || grants.some(x => typeof x !== 'string')) fail('invalid_legacy_grants');
  return Object.freeze({
    hybrid_policy_version: 1,
    legacy_unclassified_jade: save.celestial_jade,
    needs_reconciliation: save.celestial_jade > 0 || grants.length > 0,
    auto_paid_credit: 0,
    legacy_balance_mutated: false,
  });
}

function intent(source, cost, operation, localDebit = 0) {
  return Object.freeze({
    hybrid_policy_version:1, source, cost,
    operation, local_debit:localDebit,
    requires_server_authorization:source === 'paid',
  });
}

/**
 * Summon lane preview, NEVER commit. No combined local+server spends.
 * `paid` always requires an authenticated server operation even if a
 * client-side paid-balance cache reports sufficient funds.
 */
export function planHybridSummon({ source, pullCount, earnedJade, legacyJade, online }) {
  if (![1,10].includes(pullCount)) fail('invalid_pull_count');
  if (!validJade(earnedJade) || !validJade(legacyJade)) fail('invalid_local_balance');
  if (typeof online !== 'boolean') fail('invalid_network_state');
  if (!['earned','legacy','paid','auto'].includes(source)) fail('invalid_source');
  const cost = COSTS[pullCount];
  const selected = source === 'auto' ? (
    earnedJade >= cost ? 'earned' : legacyJade >= cost ? 'legacy' : online ? 'paid' : 'none'
  ) : source;
  if (selected === 'earned') return earnedJade >= cost
    ? intent('earned', cost, 'local_only_pending_game_atomic_commit', -cost)
    : intent('none', cost, 'insufficient_earned');
  if (selected === 'legacy') return legacyJade >= cost
    ? intent('legacy', cost, 'legacy_local_only_pending_game_atomic_commit', -cost)
    : intent('none', cost, 'insufficient_legacy');
  if (selected === 'paid') return online
    ? intent('paid', cost, 'server_authorization_required', 0)
    : intent('none', cost, 'paid_requires_network');
  return intent('none', cost, 'insufficient_single_lane');
}
