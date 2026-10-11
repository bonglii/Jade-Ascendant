/** RC3 read-only proof reconciliation. NOT a gameplay proof issuer.
 * The presence of a row with origin='server_verified_gameplay' is insufficient
 * by itself: no rows may be inserted until an independent trusted verifier exists.
 * No caller-supplied progression, saves or cleared-stage claims are accepted.
 */
import { createHash } from 'node:crypto';
import { InvalidIdentity, verifyFirebaseHeaders } from './jwt_verify.mjs';

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const STAGE = /^[1-3]-[1-5]$/;
const PROVIDERS = new Set(['google.com','anonymous']);
const HEADERS = Object.freeze({
  'content-type':'application/json; charset=utf-8','cache-control':'no-store, private',
  'pragma':'no-cache','x-content-type-options':'nosniff','referrer-policy':'no-referrer',
  'vary':'Authorization, X-Firebase-AppCheck',
});
const respond = (status,body)=>new Response(JSON.stringify(body),{status,headers:HEADERS});
export class TrustedProgressionErrorRC3 extends Error {
  constructor(code){super(code);this.name='TrustedProgressionErrorRC3';this.code=code;}
}
const fail = code=>{throw new TrustedProgressionErrorRC3(code);};
const primary = db=>typeof db.withSession==='function'?db.withSession('first-primary'):db;
function ownerKey(identity){
  const uid=identity?.auth?.uid;
  if(typeof uid!=='string'||!UID.test(uid)||
      !PROVIDERS.has(identity?.auth?.token?.firebase?.sign_in_provider)||
      typeof identity?.app?.appId!=='string'||identity.app.appId.length<6)throw new InvalidIdentity();
  return 'u1:'+createHash('sha256').update(uid,'utf8').digest('hex');
}
function verifiedStageKeys(stateJson){
  if(typeof stateJson!=='string'||stateJson.length>65536)fail('invalid_canonical');
  let state;try{state=JSON.parse(stateJson);}catch{fail('invalid_canonical');}
  if(!state||typeof state!=='object'||Array.isArray(state)||state.state_contract_version!==1||
    !Array.isArray(state.cleared_stage_keys)||state.cleared_stage_keys.length>15||
    state.cleared_stage_keys.some(x=>typeof x!=='string'||!STAGE.test(x))||
    new Set(state.cleared_stage_keys).size!==state.cleared_stage_keys.length)fail('invalid_canonical');
  return [...state.cleared_stage_keys].sort();
}
/** Internal-only staged proof requirement. Never accept a stage list from HTTP. */
export async function assertTrustedStageEvidenceRC3({db,owner,stageKeys}){
  if(typeof owner!=='string'||!/^u1:[0-9a-f]{64}$/.test(owner)||
     !Array.isArray(stageKeys)||stageKeys.length<1||stageKeys.length>15||
     stageKeys.some(x=>typeof x!=='string'||!STAGE.test(x))||
     new Set(stageKeys).size!==stageKeys.length)fail('invalid_canonical');
  if(!db||typeof db.prepare!=='function')fail('db_unavailable');
  // Cloudflare D1 .all() returns {results:[...]}, NOT an array.
  // Reject malformed replies; never reinterpret missing proof rows as verified.
  const evidenceReply=await primary(db).prepare(
    'SELECT stage_key,status,origin FROM iap_trusted_stage_evidence_v1 WHERE owner_key=?'
  ).bind(owner).all();
  const evidence=evidenceReply?.results;
  if(!Array.isArray(evidence)||evidence.length>15)fail('invalid_evidence');
  const verified=new Set();
  for(const row of evidence){
    if(typeof row.stage_key!=='string'||!STAGE.test(row.stage_key)||
       row.origin!=='server_verified_gameplay'||!['verified','revoked'].includes(row.status))fail('invalid_evidence');
    if(row.status==='verified')verified.add(row.stage_key);
  }
  if(stageKeys.length!==verified.size||stageKeys.some(x=>!verified.has(x))||
      !verified.has('1-5'))fail('unverified_progress');
  return {stageKeys:[...stageKeys].sort()};
}
/** Build an atomic D1 revision CAS predicate. Ownership can be revoked between
 * preflight and spend; this predicate must evaluate inside the SAME D1 batch. */
export function trustedStageRevisionGuardRC3(owner,stageKeys){
  if(typeof owner!=='string'||!/^u1:[0-9a-f]{64}$/.test(owner)||
     !Array.isArray(stageKeys)||stageKeys.length<1||stageKeys.length>15||
     stageKeys.some(x=>typeof x!=='string'||!STAGE.test(x))||
     new Set(stageKeys).size!==stageKeys.length)fail('invalid_canonical');
  const placeholders=stageKeys.map(()=>'?').join(',');
  return {
    sql:`(SELECT COUNT(*) FROM iap_trusted_stage_evidence_v1
      WHERE owner_key=? AND origin='server_verified_gameplay' AND status='verified')=?
      AND (SELECT COUNT(*) FROM iap_trusted_stage_evidence_v1
        WHERE owner_key=? AND origin='server_verified_gameplay' AND status='verified'
          AND stage_key IN (${placeholders}))=?`,
    bindings:[owner,stageKeys.length,owner,...stageKeys,stageKeys.length],
  };
}
export async function readTrustedProgressionRC3({db,verifiedIdentity}){
  const owner=ownerKey(verifiedIdentity);
  if(!db||typeof db.prepare!=='function')fail('db_unavailable');
  const session=primary(db);
  const record=await session.prepare(
    'SELECT status,revision,state_json FROM iap_summon_canonical_v1 WHERE owner_key=?'
  ).bind(owner).first();
  if(!record||record.status!=='verified')fail('not_provisioned');
  if(!Number.isSafeInteger(record.revision)||record.revision<0||record.revision>Number.MAX_SAFE_INTEGER-1)
    fail('invalid_canonical');
  const stages=verifiedStageKeys(record.state_json);
  // Require matching server evidence; neither canonical JSON alone nor a
  // caller-supplied stage claim is authoritative.
  await assertTrustedStageEvidenceRC3({db,owner,stageKeys:stages});
  return {
    trusted_progression_contract_version:1,state:'verified',canonical_revision:record.revision,
    cleared_stage_keys:stages,paid_summon_unlocked:true,
    authority:'server_verified_only',display_only:true,
  };
}
export function createTrustedProgressionReadHandlerRC3({
  verifyIdentity=verifyFirebaseHeaders,read=readTrustedProgressionRC3,
}={}){
  return async(request,env)=>{
    if(request.method!=='GET')return respond(405,{error:'method_not_allowed'});
    if(new URL(request.url).search||request.body!==null||request.headers.has('content-length'))
      return respond(400,{error:'unexpected_request_data'});
    if(env?.JADE_TRUSTED_PROGRESSION_READ_ENABLED!=='true')
      return respond(503,{error:'trusted_progression_disabled'});
    if(!env.DB)return respond(503,{error:'trusted_progression_not_configured'});
    try{
      return respond(200,await read({db:env.DB,verifiedIdentity:await verifyIdentity(request.headers,env)}));
    }catch(e){
      if(e instanceof InvalidIdentity)return respond(401,{error:'unauthenticated'});
      if(e instanceof TrustedProgressionErrorRC3&&
        ['unverified_progress','not_provisioned'].includes(e.code))
        return respond(409,{error:'trusted_progression_not_ready'});
      return respond(503,{error:'trusted_progression_temporarily_unavailable'});
    }
  };
}
