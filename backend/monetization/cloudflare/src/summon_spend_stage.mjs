/**
 * Wallet M3 - server-only, UNWIRED atomic summon spend + immutable outcome.
 * NEVER expose this function directly as a Worker route. A trusted server
 * fulfillment engine must first own authenticated progression, equipment
 * eligibility, RNG, pity, wish fate, inventory and delivery state. The
 * resolveTrustedOutcome callback MUST have zero side effects and MUST NOT
 * accept outcomes/pools/pity/costs supplied by the game client.
 *
 * Only requestId (a v4 UUID) and pullCount (1/10) may originate from the
 * authenticated client; verified Firebase UID comes from Auth/App Check.
 * Cost is fixed by this server policy, not a request parameter.
 */
import { createHash } from 'node:crypto';
import { createD1Wallet } from './d1_wallet.mjs';

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const UUID4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ITEM = /^[a-z][a-z0-9_]{0,95}$/;
const RARITIES = new Set(['common', 'rare', 'epic', 'legendary']);
const COSTS = Object.freeze({1:100,10:900});

export class SummonStageError extends Error {
  constructor(code) { super(code); this.code = code; this.name = 'SummonStageError'; }
}
function ownerKey(uid) {
  if (typeof uid !== 'string' || !UID.test(uid)) throw new SummonStageError('invalid_uid');
  return 'u1:' + createHash('sha256').update(uid).digest('hex');
}
function spendKey(uid, requestId) {
  if (typeof requestId !== 'string' || !UUID4.test(requestId)) {
    throw new SummonStageError('invalid_request_id');
  }
  return 'spendv1:' + createHash('sha256')
    .update('summon:v1\0' + uid + '\0' + requestId.toLowerCase()).digest('hex');
}
function costFor(pullCount) {
  if (!Number.isInteger(pullCount) || !Object.hasOwn(COSTS, pullCount)) {
    throw new SummonStageError('invalid_pull_count');
  }
  return COSTS[pullCount];
}
function exactKeys(value, keys) {
  return value && typeof value === 'object' && !Array.isArray(value)
    && Object.keys(value).length === keys.length
    && keys.every(key => Object.hasOwn(value, key));
}
function requireTrustedOutcome(raw, pullCount) {
  // Serialization and shape checks only. Eligibility and RNG cannot be
  // validated here without a canonical server gameplay/progression state.
  if (!exactKeys(raw, ['outcome_contract_version','pull_count','results','next_pity'])
    || raw.outcome_contract_version !== 1 || raw.pull_count !== pullCount
    || !Array.isArray(raw.results) || raw.results.length !== pullCount
    || raw.results.some(r => !exactKeys(r,['item_id','rarity'])
      || typeof r.item_id !== 'string' || !ITEM.test(r.item_id)
      || !RARITIES.has(r.rarity))
    || !exactKeys(raw.next_pity,['rare_plus','epic_plus','legendary'])
    || !Number.isInteger(raw.next_pity.rare_plus)
    || !Number.isInteger(raw.next_pity.epic_plus)
    || !Number.isInteger(raw.next_pity.legendary)
    || raw.next_pity.rare_plus < 0 || raw.next_pity.rare_plus > 9
    || raw.next_pity.epic_plus < 0 || raw.next_pity.epic_plus > 29
    || raw.next_pity.legendary < 0 || raw.next_pity.legendary > 49) {
    throw new SummonStageError('untrusted_outcome_invalid');
  }
  const serialized = JSON.stringify(raw);
  if (serialized.length > 16384) throw new SummonStageError('outcome_too_large');
  return serialized;
}
function primary(db) { return typeof db.withSession === 'function' ? db.withSession('first-primary') : db; }
function queryResult(db, id) {
  return db.prepare('SELECT owner_key, pull_count, jade_cost, outcome_json FROM iap_summon_outcomes_v1 WHERE spend_key = ?').bind(id).first();
}
function replay(row, owner, pullCount, cost) {
  if (row.owner_key !== owner || row.pull_count !== pullCount || row.jade_cost !== cost) {
    throw new SummonStageError('operation_conflict');
  }
  let outcome;
  try { outcome = JSON.parse(row.outcome_json); requireTrustedOutcome(outcome, pullCount); }
  catch { throw new SummonStageError('stored_outcome_invalid'); }
  return outcome;
}

export function createStagedSummonCoordinator(db) {
  if (!db || typeof db.prepare !== 'function' || typeof db.batch !== 'function') {
    throw new SummonStageError('d1_required');
  }
  const wallet = createD1Wallet(db);
  return {
    async execute({uid, requestId, pullCount, resolveTrustedOutcome}) {
      const owner = ownerKey(uid);
      const id = spendKey(uid, requestId);
      const cost = costFor(pullCount);
      const old = await queryResult(primary(db), id);
      if (old) {
        return { spend_id:id, outcome:replay(old,owner,pullCount,cost), wallet:await wallet.getSnapshot(uid), applied:false };
      }
      if (typeof resolveTrustedOutcome !== 'function') {
        throw new SummonStageError('trusted_server_resolver_required');
      }
      // SECURITY: resolveTrustedOutcome is intended to be a pure preview of a
      // canonical server-owned game state. Until the backend stores that state
      // transactionally with this spend, DO NOT wire this primitive to HTTP.
      const outcomeJson = requireTrustedOutcome(
        await resolveTrustedOutcome({uid, pullCount, spendId:id}), pullCount
      );
      try {
        // Entire batch is one SQLite/D1 transaction. A failed balance check,
        // duplicate event, or outcome insert rolls back ALL statements.
        await db.batch([
          db.prepare('INSERT OR IGNORE INTO iap_wallet_accounts_v1 (owner_key, balance, revision) VALUES (?, 0, 0)').bind(owner),
          db.prepare('INSERT INTO iap_wallet_events_v1 (event_key, owner_key, event_kind, item_key, delta) VALUES (?, ?, ?, ?, ?)')
            .bind(id, owner, 'summon_debit', 'summon:' + pullCount, -cost),
          db.prepare('UPDATE iap_wallet_accounts_v1 SET balance = balance - ?, revision = revision + 1 WHERE owner_key = ?')
            .bind(cost, owner),
          db.prepare('INSERT INTO iap_summon_outcomes_v1 (spend_key, owner_key, pull_count, jade_cost, outcome_json) VALUES (?, ?, ?, ?, ?)')
            .bind(id, owner, pullCount, cost, outcomeJson),
        ]);
        return { spend_id:id, outcome:JSON.parse(outcomeJson), wallet:await wallet.getSnapshot(uid), applied:true };
      } catch(err) {
        // Retry or race: only return the stored outcome for the same owner,
        // request ID, pull count and cost, regardless of this resolver's roll.
        const saved = await queryResult(primary(db), id);
        if (saved) {
          return { spend_id:id, outcome:replay(saved,owner,pullCount,cost), wallet:await wallet.getSnapshot(uid), applied:false };
        }
        // An orphan spend ledger entry is a corruption condition, not a
        // balance shortage; it must never be retried as a fresh roll.
        const orphan = await primary(db).prepare(
          'SELECT event_key FROM iap_wallet_events_v1 WHERE event_key = ?'
        ).bind(id).first();
        if (orphan) throw new SummonStageError('orphan_spend_event');
        const snapshot = await wallet.getSnapshot(uid);
        if (snapshot.balance < cost) throw new SummonStageError('insufficient_funds');
        throw err; // Unknown DB/network failure, fail closed.
      }
    },
    getStatus() { return 'STAGED_NOT_LIVE'; },
  };
}
