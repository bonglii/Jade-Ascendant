/** RC3 SOURCE ONLY: authenticated, bounded recovery of LOST paid summon IDs.
 * Immutable request index entries are committed with the original debit/outcome.
 * No spending, RNG, provisioning, local grant, or save mutations.
 */
import { createHash } from 'node:crypto';
import { InvalidIdentity, verifyFirebaseHeaders } from './jwt_verify.mjs';
const UID=/^[A-Za-z0-9_-]{1,128}$/;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const PROVIDERS=new Set(['google.com','anonymous']);
const PAGE=20;
const HEADERS=Object.freeze({
  'content-type':'application/json; charset=utf-8','cache-control':'no-store, private',
  'pragma':'no-cache','x-content-type-options':'nosniff','referrer-policy':'no-referrer',
  'vary':'Authorization, X-Firebase-AppCheck',
});
const reply=(status,body)=>new Response(JSON.stringify(body),{status,headers:HEADERS});
export class SummonRecoveryIndexErrorRC3 extends Error{
  constructor(code){super(code);this.name='SummonRecoveryIndexErrorRC3';this.code=code;}
}
const fail=code=>{throw new SummonRecoveryIndexErrorRC3(code);};
function ownerKey(identity){
  const uid=identity?.auth?.uid;
  if(typeof uid!=='string'||!UID.test(uid)||
      !PROVIDERS.has(identity?.auth?.token?.firebase?.sign_in_provider)||
      typeof identity?.app?.appId!=='string'||identity.app.appId.length<6)throw new InvalidIdentity();
  return 'u1:'+createHash('sha256').update(uid,'utf8').digest('hex');
}
const primary=db=>typeof db.withSession==='function'?db.withSession('first-primary'):db;
function parseBefore(url){
  const values=[...url.searchParams.entries()];
  if(!values.length)return null;
  if(values.length!==1||values[0][0]!=='before'||
      !/^[1-9][0-9]{0,14}$/.test(values[0][1]))fail('invalid_query');
  const n=Number(values[0][1]);
  if(!Number.isSafeInteger(n)||n<1)fail('invalid_query');
  return n;
}
export async function listSummonRequestIdsRC3({db,verifiedIdentity,before=null}){
  const owner=ownerKey(verifiedIdentity);
  if(!db||typeof db.prepare!=='function')fail('db_unavailable');
  if(before!==null&&(!Number.isSafeInteger(before)||before<1))fail('invalid_query');
  const pageReply=await primary(db).prepare(`
    SELECT r.event_sequence,r.request_id FROM iap_summon_request_index_v1 r
    INNER JOIN iap_summon_outcomes_v1 o
      ON r.spend_key=o.spend_key AND r.owner_key=o.owner_key
    WHERE r.owner_key=? AND (? IS NULL OR r.event_sequence<?)
    ORDER BY r.event_sequence DESC LIMIT ?
  `).bind(owner,before,before,PAGE+1).all();
  // D1 result object is mandatory; do not return a fake empty recovery history
  // on malformed SQL replies or confuse a unit-test SQLite array with D1.
  const rows=pageReply?.results;
  if(!Array.isArray(rows)||rows.length>PAGE+1)fail('invalid_stored_index');
  for(let i=0;i<rows.length;i++){
    const r=rows[i];
    if(!Number.isSafeInteger(r.event_sequence)||r.event_sequence<1||
      typeof r.request_id!=='string'||!UUID.test(r.request_id)||
      (i>0&&rows[i-1].event_sequence<=r.event_sequence))fail('invalid_stored_index');
  }
  const available=rows.slice(0,PAGE);
  return {
    recovery_index_contract_version:1,state:'read_only',
    request_ids:available.map(r=>r.request_id),
    next_before:rows.length>PAGE?available[available.length-1].event_sequence:null,
    coverage:'indexed_commits_only',authority:'server_only',
  };
}
export function createSummonRecoveryIndexHandlerRC3({
  verifyIdentity=verifyFirebaseHeaders,list=listSummonRequestIdsRC3,
}={}){
  return async(request,env)=>{
    if(request.method!=='GET')return reply(405,{error:'method_not_allowed'});
    if(request.body!==null||request.headers.has('content-length'))
      return reply(400,{error:'unexpected_request_data'});
    if(env?.JADE_SUMMON_RECOVERY_INDEX_READ_ENABLED!=='true')
      return reply(503,{error:'summon_recovery_index_disabled'});
    if(!env.DB)return reply(503,{error:'summon_recovery_index_not_configured'});
    let before;
    try{before=parseBefore(new URL(request.url));}
    catch{return reply(400,{error:'invalid_argument'});}
    try{
      return reply(200,await list({db:env.DB,verifiedIdentity:await verifyIdentity(request.headers,env),before}));
    }catch(e){
      if(e instanceof InvalidIdentity)return reply(401,{error:'unauthenticated'});
      if(e instanceof SummonRecoveryIndexErrorRC3&&e.code==='invalid_query')
        return reply(400,{error:'invalid_argument'});
      return reply(503,{error:'summon_recovery_index_temporarily_unavailable'});
    }
  };
}
