/**
 * Wallet M4 -- staging ONLY. DO NOT expose this module through a Worker route.
 *
 * Atomic (single D1 batch) wallet debit + immutable summon outcome + canonical
 * server-owned pity/inventory transition with optimistic revision checking.
 * Unlike M3, this version updates canonical game state transactionally.
 *
 * Missing prerequisite: a real trusted server resolver with a pinned equipment
 * catalog, RNG, proof of cleared stages, and a secure migration path. NEVER
 * provision state from arbitrary client saves, nor pass client outcomes here.
 */
import { createHash } from 'node:crypto';
import { createD1Wallet } from './d1_wallet.mjs';

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const UUID4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ITEM = /^[a-z][a-z0-9_]{0,95}$/;
const STAGE = /^(?:[1-9][0-9]?)-(?:[1-9][0-9]?)$/;
const RARITIES = new Set(['common', 'rare', 'epic', 'legendary']);
const COSTS = Object.freeze({1:100,10:900});
const DUPLICATE_SHARDS = Object.freeze({common:5,rare:12,epic:30,legendary:75});
const STATE_KEYS = ['state_contract_version','cleared_stage_keys','pity','wish_item_id','wish_fate_guaranteed','lifetime_pulls','inventory','refinement_shards'];
const OUTCOME_KEYS = ['outcome_contract_version','pull_count','results','next_pity'];
const RESULT_KEYS = ['item_id','rarity','duplicate','duplicate_shards','hard_legendary_pity','wish_hit','wish_fate_activated','wish_fate_consumed'];
const PITY_KEYS = ['rare_plus','epic_plus','legendary'];
const MAX_COUNT = 1000000000;

export class CanonicalStageError extends Error {
  constructor(code) { super(code); this.name='CanonicalStageError'; this.code=code; }
}
const plain = v => v !== null && typeof v === 'object' && !Array.isArray(v) && (Object.getPrototypeOf(v) === Object.prototype || Object.getPrototypeOf(v) === null);
const exact = (v,keys) => plain(v) && Object.keys(v).length === keys.length && keys.every(k => Object.hasOwn(v,k));
const validInt = (v,min,max) => Number.isSafeInteger(v) && v>=min && v<=max;
const ownerKey = uid => {
  if (typeof uid !== 'string' || !UID.test(uid)) throw new CanonicalStageError('invalid_uid');
  return 'u1:' + createHash('sha256').update(uid).digest('hex');
};
const spendKey = (uid,requestId) => {
  if (typeof requestId !== 'string' || !UUID4.test(requestId)) throw new CanonicalStageError('invalid_request_id');
  return 'spendv1:' + createHash('sha256').update('summon:v1\0'+uid+'\0'+requestId.toLowerCase()).digest('hex');
};
const costFor = pullCount => {
  if (!Number.isInteger(pullCount) || !Object.hasOwn(COSTS,pullCount)) throw new CanonicalStageError('invalid_pull_count');
  return COSTS[pullCount];
};
const validPity = p => exact(p,PITY_KEYS) && validInt(p.rare_plus,0,9) && validInt(p.epic_plus,0,29) && validInt(p.legendary,0,49);
function validateState(s) {
  if (!exact(s,STATE_KEYS) || s.state_contract_version !== 1
    || !Array.isArray(s.cleared_stage_keys) || s.cleared_stage_keys.length>200
    || s.cleared_stage_keys.some(x=>typeof x!=='string'||!STAGE.test(x))
    || new Set(s.cleared_stage_keys).size!==s.cleared_stage_keys.length
    || !validPity(s.pity)
    || typeof s.wish_item_id !== 'string' || (s.wish_item_id!=='' && !ITEM.test(s.wish_item_id))
    || typeof s.wish_fate_guaranteed !== 'boolean'
    || (s.wish_fate_guaranteed && !s.wish_item_id)
    || !validInt(s.lifetime_pulls,0,MAX_COUNT)
    || !plain(s.inventory) || Object.keys(s.inventory).length>300
    || Object.entries(s.inventory).some(([k,v])=>!ITEM.test(k)||!validInt(v,1,1))
    || !validInt(s.refinement_shards,0,MAX_COUNT)) {
    throw new CanonicalStageError('invalid_canonical_state');
  }
  const data=JSON.stringify(s);
  if (data.length>65536) throw new CanonicalStageError('canonical_state_too_large');
  return data;
}
function parseState(json) {
  try { const parsed=JSON.parse(json); validateState(parsed); return parsed; }
  catch { throw new CanonicalStageError('corrupt_canonical_state'); }
}
function validateOutcome(o,pullCount) {
  if (!exact(o,OUTCOME_KEYS) || o.outcome_contract_version!==1 || o.pull_count!==pullCount
      || !Array.isArray(o.results) || o.results.length!==pullCount || !validPity(o.next_pity)
      || o.results.some(r=>!exact(r,RESULT_KEYS) || !ITEM.test(r.item_id) || !RARITIES.has(r.rarity)
        || ['duplicate','hard_legendary_pity','wish_hit','wish_fate_activated','wish_fate_consumed'].some(k=>typeof r[k]!=='boolean')
        || !validInt(r.duplicate_shards,0,75))) {
    throw new CanonicalStageError('invalid_trusted_outcome');
  }
  const serialized=JSON.stringify(o);
  if (serialized.length>16384) throw new CanonicalStageError('outcome_too_large');
  return serialized;
}
function validateTransition(before,after,outcome,pullCount) {
  validateState(after);
  if (JSON.stringify(before.cleared_stage_keys)!==JSON.stringify(after.cleared_stage_keys)
    || before.wish_item_id!==after.wish_item_id
    || after.lifetime_pulls!==before.lifetime_pulls+pullCount
    || JSON.stringify(outcome.next_pity)!==JSON.stringify(after.pity)) {
    throw new CanonicalStageError('invalid_state_transition');
  }
  const expected={...before.inventory};
  let shards=before.refinement_shards;
  for (const r of outcome.results) {
    const owned=(expected[r.item_id]??0)===1;
    const expectedShards=owned?DUPLICATE_SHARDS[r.rarity]:0;
    if (r.duplicate!==owned || r.duplicate_shards!==expectedShards) {
      throw new CanonicalStageError('invalid_duplicate_result');
    }
    expected[r.item_id]=1;
    shards+=expectedShards;
    if (!validInt(shards,0,MAX_COUNT)) throw new CanonicalStageError('shard_overflow');
  }
  const keys=Object.keys(expected);
  if (keys.length!==Object.keys(after.inventory).length
      || keys.some(k=>after.inventory[k]!==expected[k])
      || after.refinement_shards!==shards) {
    throw new CanonicalStageError('invalid_inventory_transition');
  }
}
const primary = db => typeof db.withSession==='function' ? db.withSession('first-primary') : db;
const readAccount=(db,key)=>db.prepare('SELECT revision,status,state_json FROM iap_summon_canonical_v1 WHERE owner_key = ?').bind(key).first();
const readOutcome=(db,key)=>db.prepare('SELECT owner_key,pull_count,jade_cost,outcome_json FROM iap_summon_outcomes_v1 WHERE spend_key = ?').bind(key).first();
function replay(row,owner,count,cost) {
  if (row.owner_key!==owner || row.pull_count!==count || row.jade_cost!==cost) throw new CanonicalStageError('operation_conflict');
  try { const o=JSON.parse(row.outcome_json); validateOutcome(o,count); return o; }
  catch { throw new CanonicalStageError('stored_outcome_invalid'); }
}
export function createCanonicalSummonStage(db) {
  if (!db || typeof db.prepare!=='function' || typeof db.batch!=='function') throw new CanonicalStageError('d1_required');
  const wallet=createD1Wallet(db);
  return {
    async execute({uid,requestId,pullCount,resolveTrustedTransition}) {
      const owner=ownerKey(uid),id=spendKey(uid,requestId),cost=costFor(pullCount);
      const existing=await readOutcome(primary(db),id);
      if (existing) return {spend_id:id,outcome:replay(existing,owner,pullCount,cost),wallet:await wallet.getSnapshot(uid),applied:false};
      const record=await readAccount(primary(db),owner);
      if (!record || record.status!=='verified') throw new CanonicalStageError('canonical_state_not_verified');
      if (!validInt(record.revision,0,Number.MAX_SAFE_INTEGER-1)) throw new CanonicalStageError('invalid_canonical_revision');
      const state=parseState(record.state_json);
      if (!state.cleared_stage_keys.includes('1-5')) throw new CanonicalStageError('summon_not_unlocked');
      if (typeof resolveTrustedTransition!=='function') throw new CanonicalStageError('trusted_server_resolver_required');
      // Trusted pure resolver must read only server-owned input; no client RNG,
      // item eligibility or pity arguments. It has NO direct DB write authority.
      const before=structuredClone(state);
      const candidate=await resolveTrustedTransition({uid,pullCount,spendId:id,canonicalState:structuredClone(state)});
      if (!exact(candidate,['outcome','nextState'])) throw new CanonicalStageError('invalid_trusted_transition');
      const outcomeJson=validateOutcome(candidate.outcome,pullCount);
      validateTransition(before,candidate.nextState,candidate.outcome,pullCount);
      const nextJson=validateState(candidate.nextState);
      try {
        await db.batch([
          db.prepare('INSERT INTO iap_wallet_events_v1 (event_key,owner_key,event_kind,item_key,delta) VALUES (?, ?, ?, ?, ?)')
            .bind(id,owner,'summon_debit','summon:'+pullCount,-cost),
          db.prepare('UPDATE iap_wallet_accounts_v1 SET balance=balance-?,revision=revision+1 WHERE owner_key=?')
            .bind(cost,owner),
          // CAS must ABORT, not silently update 0 rows, when revision changed.
          // The revision CHECK forces a transaction rollback on stale state.
          db.prepare('UPDATE iap_summon_canonical_v1 SET revision=CASE WHEN revision=? THEN revision+1 ELSE -1 END, state_json=CASE WHEN revision=? THEN ? ELSE state_json END,updated_at=CURRENT_TIMESTAMP WHERE owner_key=?')
            .bind(record.revision,record.revision,nextJson,owner),
          db.prepare('INSERT INTO iap_summon_outcomes_v1 (spend_key,owner_key,pull_count,jade_cost,outcome_json) VALUES (?, ?, ?, ?, ?)')
            .bind(id,owner,pullCount,cost,outcomeJson),
        ]);
        return {spend_id:id,outcome:JSON.parse(outcomeJson),wallet:await wallet.getSnapshot(uid),applied:true};
      } catch(e) {
        const after=await readOutcome(primary(db),id);
        if (after) return {spend_id:id,outcome:replay(after,owner,pullCount,cost),wallet:await wallet.getSnapshot(uid),applied:false};
        const orphan=await primary(db).prepare('SELECT event_key FROM iap_wallet_events_v1 WHERE event_key=?').bind(id).first();
        if (orphan) throw new CanonicalStageError('orphan_spend_event');
        const snapshot=await wallet.getSnapshot(uid);
        if (snapshot.balance<cost) throw new CanonicalStageError('insufficient_funds');
        const latest=await readAccount(primary(db),owner);
        if (!latest || latest.status!=='verified' || latest.revision!==record.revision) throw new CanonicalStageError('state_contention_retry');
        throw e;
      }
    },
    // No HTTP routes and no admin provisioning method by design.
    getStatus(){return 'STAGED_NOT_LIVE';},
  };
}
