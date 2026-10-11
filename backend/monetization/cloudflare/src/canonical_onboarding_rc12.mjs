/** RC12 — INTERNAL ONLY. Initialize a paid account AFTER verified Play wallet credit.
 * Never import local saves, stage clears, or client-provided inventories.
 * This module is not a public endpoint and never creates wallet currency.
 */
import { createHash } from 'node:crypto';

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const OWNER = /^u1:[a-f0-9]{64}$/;
const MAX_REV = Number.MAX_SAFE_INTEGER - 1;
export class CanonicalOnboardingErrorRC12 extends Error {
  constructor(code) { super(code); this.name = 'CanonicalOnboardingErrorRC12'; this.code = code; }
}
const fail = code => { throw new CanonicalOnboardingErrorRC12(code); };
export function canonicalDefaultRC12() {
  return {
    state_contract_version: 1,
    cleared_stage_keys: [],
    pity: {rare_plus: 0, epic_plus: 0, legendary: 0},
    wish_item_id: '',
    wish_fate_guaranteed: false,
    lifetime_pulls: 0,
    inventory: {},
    refinement_shards: 0,
  };
}
function validateReadRow(row) {
  if (!row || row.status !== 'verified' || !Number.isSafeInteger(row.revision)
      || row.revision < 0 || row.revision > MAX_REV || typeof row.state_json !== 'string'
      || row.state_json.length < 20 || row.state_json.length > 65536) fail('canonical_onboarding_not_ready');
  let data;
  try { data = JSON.parse(row.state_json); } catch { fail('canonical_onboarding_not_ready'); }
  const required=['state_contract_version','cleared_stage_keys','pity','wish_item_id',
    'wish_fate_guaranteed','lifetime_pulls','inventory','refinement_shards'];
  const goodInt = (v,low,high) => Number.isSafeInteger(v) && v >= low && v <= high;
  const isPlain = v => v !== null && typeof v === 'object' && !Array.isArray(v);
  const stages = data?.cleared_stage_keys;
  const pity = data?.pity;
  const inventory = data?.inventory;
  if (!isPlain(data) || Object.keys(data).length !== required.length
      || required.some(key => !Object.hasOwn(data,key)) || data.state_contract_version !== 1
      || !Array.isArray(stages) || stages.length > 200
      || stages.some(v => typeof v !== 'string' || !/^[1-9][0-9]?-[1-9][0-9]?$/.test(v))
      || new Set(stages).size !== stages.length
      || !isPlain(pity) || Object.keys(pity).length !== 3
      || !goodInt(pity.rare_plus,0,9) || !goodInt(pity.epic_plus,0,29)
      || !goodInt(pity.legendary,0,49)
      || typeof data.wish_item_id !== 'string' || (data.wish_item_id !== '' && !/^[a-z][a-z0-9_]{0,95}$/.test(data.wish_item_id))
      || typeof data.wish_fate_guaranteed !== 'boolean'
      || (data.wish_fate_guaranteed && !data.wish_item_id)
      || !goodInt(data.lifetime_pulls,0,1_000_000_000)
      || !isPlain(inventory) || Object.keys(inventory).length > 300
      || Object.entries(inventory).some(([key,value]) => !/^[a-z][a-z0-9_]{0,95}$/.test(key) || value !== 1)
      || !goodInt(data.refinement_shards,0,1_000_000_000))
    fail('canonical_onboarding_not_ready');
  return row;
}

export async function ensureCanonicalAccountAfterVerifiedCreditRC12({db, verifiedUid}) {
  // The caller MUST use the Firebase UID it verified for a successful M13
  // server-wallet credit, not a value taken from JSON or a local game save.
  if (typeof verifiedUid !== 'string' || !UID.test(verifiedUid)) fail('invalid_trusted_uid');
  if (!db || typeof db.prepare !== 'function') fail('db_unavailable');
  const owner = 'u1:' + createHash('sha256').update(verifiedUid, 'utf8').digest('hex');
  if (!OWNER.test(owner)) fail('invalid_trusted_uid');
  const fresh = JSON.stringify(canonicalDefaultRC12());
  // Wallet must ALREADY exist. SELECT FROM the wallet table avoids creating
  // canonical accounts for forged/uncredited UIDs. Immutable existing rows
  // (including a live stage/progress state) are never overwritten.
  try {
    await db.prepare(`INSERT OR IGNORE INTO iap_summon_canonical_v1
      (owner_key,revision,status,state_json)
      SELECT owner_key,0,'verified',? FROM iap_wallet_accounts_v1 WHERE owner_key=?`)
      .bind(fresh, owner).run();
    const session = typeof db.withSession === 'function' ? db.withSession('first-primary') : db;
    const row = await session.prepare(`SELECT revision,status,state_json
      FROM iap_summon_canonical_v1 WHERE owner_key=?`).bind(owner).first();
    validateReadRow(row);
    return {ready: true}; // no client grant, no stage claim
  } catch (error) {
    if (error instanceof CanonicalOnboardingErrorRC12) throw error;
    fail('canonical_onboarding_not_ready');
  }
}
