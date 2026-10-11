/**
 * RC2.1 SOURCE-ONLY paid equipment loadout authority.
 * NOT a local grant, stat payload, runtime cutover, or game-save migration.
 * Every read and write checks the CURRENT signed-UID canonical ownership.
 * POST is idempotent and CAS-protected; no unverified progression provisioning.
 */
import { createHash } from 'node:crypto';
import { InvalidIdentity, verifyFirebaseHeaders } from './jwt_verify.mjs';
import { readPaidEntitlementsRC, PaidEntitlementsError } from './paid_entitlements_read_route_rc.mjs';
import { PAID_SLOTS_RC2, PAID_SLOT_OF_ITEM_RC2 } from './paid_loadout_catalog_rc2.mjs';

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const UUID = /^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i;
const PROVIDERS = new Set(['anonymous','google.com']);
const MAX_BODY = 1024;
const MAX_REV = Number.MAX_SAFE_INTEGER-1;
const HEADERS = Object.freeze({
  'content-type':'application/json; charset=utf-8',
  'cache-control':'no-store, private', 'pragma':'no-cache',
  'x-content-type-options':'nosniff', 'referrer-policy':'no-referrer',
  'vary':'Authorization, X-Firebase-AppCheck',
});
const response = (code,data) => new Response(JSON.stringify(data),{status:code,headers:HEADERS});
const sha = s => createHash('sha256').update(s,'utf8').digest('hex');
export class PaidLoadoutErrorRC2 extends Error {
  constructor(code) {super(code);this.name='PaidLoadoutErrorRC2';this.code=code;}
}
const fail = code => {throw new PaidLoadoutErrorRC2(code);};
const plain = v => v !== null && typeof v === 'object' && !Array.isArray(v)
  && (Object.getPrototypeOf(v)===Object.prototype || Object.getPrototypeOf(v)===null);
const exact = (v,fields) => plain(v) && Object.keys(v).length===fields.length
  && fields.every(k=>Object.hasOwn(v,k));
const safe = (v,lo=0,hi=MAX_REV) => Number.isSafeInteger(v) && v>=lo && v<=hi;
const emptySlots = () => Object.fromEntries(PAID_SLOTS_RC2.map(slot=>[slot,'']));
function ownerFromIdentity(identity) {
  const uid = identity?.auth?.uid;
  if (typeof uid!=='string' || !UID.test(uid) ||
      !PROVIDERS.has(identity?.auth?.token?.firebase?.sign_in_provider) ||
      typeof identity?.app?.appId!=='string' || identity.app.appId.length<6) {
    throw new InvalidIdentity();
  }
  return {uid,owner:'u1:'+sha(uid)};
}
function validateSlots(slots,owned) {
  if (!exact(slots,PAID_SLOTS_RC2)) fail('invalid_paid_slots');
  const seen = new Set();
  const result = emptySlots();
  for(const slot of PAID_SLOTS_RC2) {
    const item = slots[slot];
    if(typeof item!=='string' || item.length>96) fail('invalid_paid_slots');
    if(!item) continue;
    if(PAID_SLOT_OF_ITEM_RC2[item]!==slot || seen.has(item)) fail('invalid_paid_slots');
    if(!owned.has(item)) fail('paid_item_not_owned');
    result[slot]=item;
    seen.add(item);
  }
  return result;
}
const primary = db => typeof db.withSession==='function'?db.withSession('first-primary'):db;
const fetchRow = (db,owner) => db.prepare(
  'SELECT revision,slots_json FROM iap_paid_loadouts_v1 WHERE owner_key=?'
).bind(owner).first();
const fetchOp = (db,key) => db.prepare(
  'SELECT owner_key,payload_digest,committed_revision FROM iap_paid_loadout_ops_v1 WHERE operation_key=?'
).bind(key).first();

export async function readPaidLoadoutRC2({db,verifiedIdentity}) {
  if(!db || typeof db.prepare!=='function') fail('db_missing');
  const {owner}=ownerFromIdentity(verifiedIdentity);
  const entitlements=await readPaidEntitlementsRC({db,verifiedIdentity});
  const owned=new Set(entitlements.item_ids);
  const row=await fetchRow(primary(db),owner);
  if(row && (!safe(row.revision) || typeof row.slots_json!=='string' || row.slots_json.length>MAX_BODY)) {
    fail('invalid_server_loadout');
  }
  let slots=emptySlots();
  if(row){
    try {slots=validateSlots(JSON.parse(row.slots_json),owned);}
    catch {fail('invalid_server_loadout');}
  }
  return {
    paid_loadout_contract_version:1,state:'verified',revision:row?.revision??0,
    entitlement_revision:entitlements.revision,paid_slots:slots,authority:'server_only',
  };
}

const eligibilitySql = PAID_SLOTS_RC2.map(() =>
  "AND (? = '' OR json_extract(c.state_json, ?) = 1)"
).join(' ');
const updateSql = `UPDATE iap_paid_loadouts_v1 SET
  revision=CASE WHEN revision=? AND EXISTS (
    SELECT 1 FROM iap_summon_canonical_v1 c
    WHERE c.owner_key=iap_paid_loadouts_v1.owner_key AND c.status='verified'
      AND c.revision=? ${eligibilitySql}
  ) THEN revision+1 ELSE -1 END,
  slots_json=CASE WHEN revision=? THEN ? ELSE slots_json END,
  updated_at=CURRENT_TIMESTAMP WHERE owner_key=?`;

export async function writePaidLoadoutRC2({db,verifiedIdentity,command}) {
  if(!db || typeof db.prepare!=='function' || typeof db.batch!=='function') fail('db_missing');
  const {uid,owner}=ownerFromIdentity(verifiedIdentity);
  const names=['request_id','expected_loadout_revision','expected_entitlement_revision','paid_slots'];
  if(!exact(command,names) || typeof command.request_id!=='string' || !UUID.test(command.request_id) ||
      !safe(command.expected_loadout_revision,0,MAX_REV-1) ||
      !safe(command.expected_entitlement_revision,0,MAX_REV-1)) fail('invalid_command');
  // Validate signed UID and CURRENT entitlements before touching SQL writes.
  const ent=await readPaidEntitlementsRC({db,verifiedIdentity});
  const slots=validateSlots(command.paid_slots,new Set(ent.item_ids));
  const normalized={...command,request_id:command.request_id.toLowerCase(),paid_slots:slots};
  const opKey='loadoutv1:'+sha('paid-loadout:v1\0'+uid+'\0'+normalized.request_id);
  const digest=sha(JSON.stringify({rev:normalized.expected_loadout_revision,
    entitlement_rev:normalized.expected_entitlement_revision,slots}));
  const committed=await fetchOp(primary(db),opKey);
  if(committed){
    if(committed.owner_key!==owner || committed.payload_digest!==digest) fail('operation_conflict');
    // Never replay a stale loadout without checking currently valid ownership.
    return readPaidLoadoutRC2({db,verifiedIdentity});
  }
  const current=await fetchRow(primary(db),owner);
  if(ent.revision!==normalized.expected_entitlement_revision ||
      (current?.revision??0)!==normalized.expected_loadout_revision) fail('revision_conflict');
  // Even an unchanged request must be auditable and guarded by entitlement CAS.
  const empty=JSON.stringify(emptySlots());
  const slotGuard=PAID_SLOTS_RC2.flatMap(slot=>{
    const id=slots[slot];return [id,'$.inventory.'+(id || '__empty__')];
  });
  try{
    await db.batch([
      db.prepare(`INSERT OR IGNORE INTO iap_paid_loadouts_v1 (owner_key,revision,slots_json)
        SELECT owner_key,0,? FROM iap_summon_canonical_v1
        WHERE owner_key=? AND status='verified' AND revision=?`)
        .bind(empty,owner,ent.revision),
      db.prepare(updateSql).bind(normalized.expected_loadout_revision,
        ent.revision,...slotGuard,normalized.expected_loadout_revision,
        JSON.stringify(slots),owner),
      db.prepare(`INSERT INTO iap_paid_loadout_ops_v1
        (operation_key,owner_key,payload_digest,committed_revision) VALUES (?,?,?,?)`)
        .bind(opKey,owner,digest,normalized.expected_loadout_revision+1),
    ]);
    return readPaidLoadoutRC2({db,verifiedIdentity});
  }catch(err){
    const saved=await fetchOp(primary(db),opKey);
    if(saved){
      if(saved.owner_key!==owner || saved.payload_digest!==digest) fail('operation_conflict');
      return readPaidLoadoutRC2({db,verifiedIdentity});
    }
    const latest=await readPaidLoadoutRC2({db,verifiedIdentity});
    if(latest.revision!==normalized.expected_loadout_revision ||
       latest.entitlement_revision!==normalized.expected_entitlement_revision) fail('revision_conflict');
    // Don't disclose internal D1 failures to the HTTP caller.
    throw err;
  }
}

async function jsonBody(request) {
  if(!/^application\/json(?:\s*;|$)/i.test(request.headers.get('content-type')||'')) fail('invalid_command');
  if(!request.body) fail('invalid_command');
  const header=request.headers.get('content-length');
  if(header!==null && (!/^\d+$/.test(header) || Number(header)>MAX_BODY)) fail('invalid_command');
  const reader=request.body.getReader();
  const chunks=[];let total=0;
  try{
    while(true){const {value,done}=await reader.read();if(done)break;
      total+=value.byteLength;if(total>MAX_BODY){await reader.cancel();fail('invalid_command');}
      chunks.push(value);
    }
  }finally{reader.releaseLock();}
  const bytes=new Uint8Array(total);let at=0;
  for(const chunk of chunks){bytes.set(chunk,at);at+=chunk.length;}
  try{return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}
  catch{fail('invalid_command');}
}

export function createPaidLoadoutHandlerRC2({
  verifyIdentity=verifyFirebaseHeaders,read=readPaidLoadoutRC2,write=writePaidLoadoutRC2,
}={}) {
  return async (request,env)=>{
    if(request.method!=='GET' && request.method!=='POST') return response(405,{error:'method_not_allowed'});
    if(new URL(request.url).search) return response(400,{error:'unexpected_request_data'});
    const isWrite=request.method==='POST';
    if(isWrite){
      if(env?.JADE_IAP_BACKEND_ENABLED!=='true' || env?.JADE_PAID_LOADOUT_WRITE_ENABLED!=='true')
        return response(503,{error:'paid_loadout_write_disabled'});
    }else if(env?.JADE_PAID_LOADOUT_READ_ENABLED!=='true'){
      return response(503,{error:'paid_loadout_read_disabled'});
    }
    if(!env?.DB || typeof env.DB.prepare!=='function') return response(503,{error:'paid_loadout_not_configured'});
    if(!isWrite && (request.body!==null || request.headers.has('content-length')))
      return response(400,{error:'unexpected_request_data'});
    try {
      const verifiedIdentity=await verifyIdentity(request.headers,env);
      const result=isWrite
        ? await write({db:env.DB,verifiedIdentity,command:await jsonBody(request)})
        : await read({db:env.DB,verifiedIdentity});
      return response(200,result);
    }catch(e){
      if(e instanceof InvalidIdentity) return response(401,{error:'unauthenticated'});
      if(e instanceof PaidEntitlementsError && e.code==='not_provisioned')
        return response(409,{error:'paid_progression_not_ready'});
      if(e instanceof PaidLoadoutErrorRC2){
        if(e.code==='invalid_command'||e.code==='invalid_paid_slots')return response(400,{error:'invalid_argument'});
        if(e.code==='paid_item_not_owned')return response(409,{error:'paid_item_not_owned'});
        if(e.code==='revision_conflict')return response(409,{error:'retry_after_refresh'});
        if(e.code==='operation_conflict')return response(409,{error:'idempotency_conflict'});
      }
      return response(503,{error:'paid_loadout_temporarily_unavailable'});
    }
  };
}
