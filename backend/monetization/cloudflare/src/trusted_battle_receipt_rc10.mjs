/**
 * RC10 source-only: trusted, signed battle outcome -> atomic canonical stage proof.
 * No public HTTP route. A REAL server-authoritative combat verifier must issue
 * these JWTs after adjudicating a battle. The Android/Godot client never signs.
 * Does not provision accounts or trust local progression.save / Play Integrity.
 */
import { createHash } from 'node:crypto';

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const STAGE = /^[1-3]-[1-5]$/;
const UUID4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const B64 = /^[A-Za-z0-9_-]+$/;
const ISSUER = 'jade-server-combat-verifier';
const AUDIENCE = 'jade-ascendant-iap-trusted-progress';
const canonicalKeys = ['state_contract_version','cleared_stage_keys','pity','wish_item_id','wish_fate_guaranteed','lifetime_pulls','inventory','refinement_shards'];
const claimsKeys = ['iss','aud','sub','stage_key','battle_id','result','iat','exp','receipt_version'];
const plain = x => x !== null && typeof x === 'object' && !Array.isArray(x) && (Object.getPrototypeOf(x) === Object.prototype || Object.getPrototypeOf(x) === null);
const exact = (x, keys) => plain(x) && Object.keys(x).length === keys.length && keys.every(key => Object.hasOwn(x,key));
const hasInteger = (x,low,high) => Number.isSafeInteger(x) && x >= low && x <= high;
const stageList = Object.freeze(Array.from({length:3},(_,chapter)=>Array.from({length:5},(_,stage)=>`${chapter+1}-${stage+1}`)).flat());
const ownerKey = uid => 'u1:' + createHash('sha256').update(uid,'utf8').digest('hex');
const evidenceKey = (uid,stage,battleId) => 'stagev1:' + createHash('sha256').update('jade-battle:v1\0'+uid+'\0'+stage+'\0'+battleId,'utf8').digest('hex');
const primary = db => typeof db.withSession === 'function' ? db.withSession('first-primary') : db;

export class TrustedBattleErrorRC10 extends Error {
  constructor(code) { super(code); this.name='TrustedBattleErrorRC10'; this.code=code; }
}
const fail = code => { throw new TrustedBattleErrorRC10(code); };
function parsePart(part) {
  if (typeof part !== 'string' || !B64.test(part)) fail('invalid_receipt');
  try {
    const base=part.replace(/-/g,'+').replace(/_/g,'/');
    const bytes=Uint8Array.from(atob(base+'='.repeat((4-base.length%4)%4)),c=>c.charCodeAt(0));
    const data=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
    if(!plain(data))fail('invalid_receipt');
    return data;
  } catch { fail('invalid_receipt'); }
}
function decodeSignature(part) {
  if (typeof part !== 'string' || !B64.test(part)) fail('invalid_receipt');
  try {
    const base=part.replace(/-/g,'+').replace(/_/g,'/');
    return Uint8Array.from(atob(base+'='.repeat((4-base.length%4)%4)),c=>c.charCodeAt(0));
  }catch{fail('invalid_receipt');}
}

/**
 * The supplied JWK is pinned server configuration, NEVER fetched from a token
 * header, a client request, or arbitrary URL. The combat verifier's private key
 * must not be deployed with the game or the IAP Worker.
 */
export async function verifyTrustedBattleReceiptRC10(jwt, {pinnedPublicJwk,kid,nowMs=Date.now(),subtle=crypto.subtle}={}) {
  if(typeof jwt!=='string'||jwt.length<150||jwt.length>8192||jwt.split('.').length!==3||
    typeof kid!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(kid)||!plain(pinnedPublicJwk)||
    pinnedPublicJwk.kty!=='RSA'||pinnedPublicJwk.kid!==kid||
    (pinnedPublicJwk.alg && pinnedPublicJwk.alg!=='RS256')||
    (pinnedPublicJwk.use && pinnedPublicJwk.use!=='sig')||
    !hasInteger(nowMs,1,Number.MAX_SAFE_INTEGER)) fail('receipt_not_configured');
  const [first,second,third]=jwt.split('.');
  const header=parsePart(first),claims=parsePart(second);
  if(!exact(header,['alg','typ','kid'])||header.alg!=='RS256'||header.typ!=='JWT'||header.kid!==kid||
    !exact(claims,claimsKeys)||claims.receipt_version!==1||claims.iss!==ISSUER||claims.aud!==AUDIENCE||
    typeof claims.sub!=='string'||!UID.test(claims.sub)||
    typeof claims.stage_key!=='string'||!STAGE.test(claims.stage_key)||
    typeof claims.battle_id!=='string'||!UUID4.test(claims.battle_id)||
    claims.result!=='cleared') fail('invalid_receipt');
  const now=Math.floor(nowMs/1000);
  if(!hasInteger(claims.iat,now-300,now+30)||!hasInteger(claims.exp,now+1,now+600)||
    claims.exp-claims.iat>300)fail('expired_receipt');
  let valid=false;
  try {
    const publicKey=await subtle.importKey('jwk',pinnedPublicJwk,{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['verify']);
    valid=await subtle.verify('RSASSA-PKCS1-v1_5',publicKey,decodeSignature(third),new TextEncoder().encode(first+'.'+second));
  }catch{fail('invalid_receipt');}
  if(!valid)fail('invalid_receipt');
  return Object.freeze({uid:claims.sub,stage:claims.stage_key,battleId:claims.battle_id,
    proof:evidenceKey(claims.sub,claims.stage_key,claims.battle_id)});
}
function validateCanonical(json) {
  if(typeof json!=='string'||json.length>65536)fail('canonical_invalid');
  let state;try{state=JSON.parse(json);}catch{fail('canonical_invalid');}
  if(!exact(state,canonicalKeys)||state.state_contract_version!==1||
    !Array.isArray(state.cleared_stage_keys)||state.cleared_stage_keys.length>15||
    state.cleared_stage_keys.some(stage=>typeof stage!=='string'||!STAGE.test(stage))||
    new Set(state.cleared_stage_keys).size!==state.cleared_stage_keys.length||
    !plain(state.pity)||!plain(state.inventory))fail('canonical_invalid');
  return state;
}
function exactProofs(rows,stages) {
  if(!Array.isArray(rows)||rows.length!==stages.length)return false;
  const proofs=new Set();
  for(const row of rows) {
    if(!STAGE.test(row.stage_key)||row.status!=='verified'||row.origin!=='server_verified_gameplay')return false;
    proofs.add(row.stage_key);
  }
  return proofs.size===stages.length&&stages.every(stage=>proofs.has(stage));
}
/** Commit ONLY a cryptographically verified server battle receipt. */
export async function commitTrustedBattleStageRC10({db,receipt,pinnedPublicJwk,kid,nowMs=Date.now(),subtle=crypto.subtle}={}) {
  if(!db||typeof db.prepare!=='function'||typeof db.batch!=='function')fail('db_unavailable');
  const verified=await verifyTrustedBattleReceiptRC10(receipt,{pinnedPublicJwk,kid,nowMs,subtle});
  const owner=ownerKey(verified.uid);
  const session=primary(db);
  const row=await session.prepare('SELECT status,revision,state_json FROM iap_summon_canonical_v1 WHERE owner_key=?').bind(owner).first();
  if(!row||row.status!=='verified')fail('account_not_provisioned');
  if(!hasInteger(row.revision,0,Number.MAX_SAFE_INTEGER-2))fail('canonical_invalid');
  const state=validateCanonical(row.state_json);
  const stages=state.cleared_stage_keys;
  if(stages.some((stage,i)=>stage!==stageList[i]))fail('canonical_stage_order_invalid');
  const proofReply=await session.prepare('SELECT stage_key,status,origin FROM iap_trusted_stage_evidence_v1 WHERE owner_key=?').bind(owner).all();
  // Match the actual D1 API; proof of prior victories must be authoritative.
  if(!exactProofs(proofReply?.results,stages))fail('prior_evidence_mismatch');
  const nextRank=stages.length;
  if(nextRank>=stageList.length || verified.stage!==stageList[nextRank]) {
    // Replay is idempotent ONLY for its original committed receipt.
    if(stages.includes(verified.stage)) {
      const existing=await session.prepare('SELECT evidence_key,status,origin FROM iap_trusted_stage_evidence_v1 WHERE owner_key=? AND stage_key=?')
        .bind(owner,verified.stage).first();
      if(existing?.evidence_key===verified.proof&&existing.status==='verified'&&existing.origin==='server_verified_gameplay')
        return {applied:false,canonical_revision:row.revision,stage:verified.stage};
    }
    fail('out_of_order_stage');
  }
  const next={...state,cleared_stage_keys:[...stages,verified.stage]};
  const encoded=JSON.stringify(next);
  if(encoded.length>65536)fail('canonical_invalid');
  const prevSql=`(SELECT COUNT(*) FROM iap_trusted_stage_evidence_v1
    WHERE owner_key=? AND origin='server_verified_gameplay' AND status='verified')=?`;
  // Use revision CHECK to ABORT (rather than silently updating 0 rows) when
  // stage proof or canonical state changes between preflight and D1 commit.
  try {
    await db.batch([
      db.prepare(`UPDATE iap_summon_canonical_v1 SET
        revision=CASE WHEN revision=? AND status='verified' AND ${prevSql} THEN revision+1 ELSE -1 END,
        state_json=CASE WHEN revision=? THEN ? ELSE state_json END,
        updated_at=CURRENT_TIMESTAMP WHERE owner_key=?`)
        .bind(row.revision,owner,stages.length,row.revision,encoded,owner),
      db.prepare(`INSERT INTO iap_trusted_stage_evidence_v1
        (owner_key,stage_key,evidence_key,origin,status) VALUES (?,?,?,?,?)`)
        .bind(owner,verified.stage,verified.proof,'server_verified_gameplay','verified'),
    ]);
    return {applied:true,canonical_revision:row.revision+1,stage:verified.stage};
  }catch {
    // Only return idempotency when BOTH canonical state + exact original proof
    // have durably committed. Never turn generic SQL failures into success.
    const [after,proof]=await Promise.all([
      session.prepare('SELECT status,revision,state_json FROM iap_summon_canonical_v1 WHERE owner_key=?').bind(owner).first(),
      session.prepare('SELECT evidence_key,status,origin FROM iap_trusted_stage_evidence_v1 WHERE owner_key=? AND stage_key=?')
        .bind(owner,verified.stage).first(),
    ]);
    if(after?.status==='verified'&&proof?.evidence_key===verified.proof&&proof?.status==='verified'&&proof?.origin==='server_verified_gameplay'&&
      validateCanonical(after.state_json).cleared_stage_keys.includes(verified.stage))
      return {applied:false,canonical_revision:after.revision,stage:verified.stage};
    fail('stage_commit_unavailable');
  }
}
