/**
 * Source-only authenticated repair for ALREADY-verified & consumed Play purchases.
 * Does not call Google Play, accept a token, verify a new purchase, or mint a grant.
 * The only input to recovery is a cryptographically verified Firebase identity.
 * Existing D1 grant_ready records are the durable authority; the wallet remains
 * idempotent and refund-freshness/hold guarded. Fail closed on any anomaly.
 */
import { createHash } from 'node:crypto';
import { InvalidIdentity, verifyFirebaseHeaders } from './jwt_verify.mjs';
import { createD1Wallet } from './d1_wallet.mjs';
import { ensureCanonicalAccountAfterVerifiedCreditRC12 } from './canonical_onboarding_rc12.mjs';
import { productByInternalId, PURCHASE_CONTRACT_VERSION } from '../../src/product_catalog.mjs';

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const TOKEN_KEY = /^playtoken:[a-f0-9]{64}$/;
const MAX_PURCHASES_PER_CALL = 32;
const HEADER = Object.freeze({
  'content-type':'application/json; charset=utf-8',
  'cache-control':'private, no-store',
  'pragma':'no-cache',
  'x-content-type-options':'nosniff',
  'referrer-policy':'no-referrer',
  'vary':'Authorization, X-Firebase-AppCheck',
});
const reply = (status,body) => {
  // Fixed server-owned labels only, no request/token/account/response payload logs.
  console.info('JADE_IAP_REPAIR status='+status+' stage='+(status===200?'server_reconciled':body.error));
  return new Response(JSON.stringify(body),{status,headers:HEADER});
};
async function emptyPost(request) {
  if(![null,'0'].includes(request.headers.get('content-length')))return false;
  if(request.body===null)return true;
  let reader,timer;
  try {
    reader=request.body.getReader();
    const deadline=new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('body_deadline')),1000);});
    // A real zero-byte HTTP body may be represented by a non-null stream.
    // Bound both waiting and empty chunks; never buffer an arbitrary client body.
    for(let i=0;i<8;i++){
      const {value,done}=await Promise.race([reader.read(),deadline]);
      if(value?.byteLength)return false;
      if(done)return true;
    }
    return false;
  } catch {return false;} finally {
    clearTimeout(timer);
    if(reader){try{void reader.cancel().catch(()=>{});reader.releaseLock();}catch{}}
  }
}
const sha = v => createHash('sha256').update(v,'utf8').digest('hex');
export class PurchaseRepairError extends Error {
  constructor(code) { super(code); this.name='PurchaseRepairError'; this.code=code; }
}
const fail = code => {throw new PurchaseRepairError(code);};
const plain = x => x !== null && typeof x==='object' && !Array.isArray(x)
  && (Object.getPrototypeOf(x)===Object.prototype || Object.getPrototypeOf(x)===null);

function eligibleOwner(identity) {
  const uid=identity?.auth?.uid;
  if (typeof uid!=='string' || !UID.test(uid) ||
      !['anonymous','google.com'].includes(identity?.auth?.token?.firebase?.sign_in_provider) ||
      typeof identity?.app?.appId!=='string' || identity.app.appId.length<6) throw new InvalidIdentity();
  return uid;
}
function grantFromLedger(row, uid) {
  if (!plain(row) || typeof row.token_key!=='string' || !TOKEN_KEY.test(row.token_key)
    || typeof row.record_json!=='string' || row.record_json.length>8192) fail('invalid_server_purchase');
  let record;
  try { record=JSON.parse(row.record_json); } catch { fail('invalid_server_purchase'); }
  if (!plain(record) || Object.keys(record).length!==9) fail('invalid_server_purchase');
  const fields=['contractVersion','tokenKey','grantId','ownerUid','ownerBinding',
    'internalProductId','playProductId','celestialJade','state'];
  if(fields.some(x=>!Object.hasOwn(record,x))) fail('invalid_server_purchase');
  const fingerprint=row.token_key.slice('playtoken:'.length);
  const product=productByInternalId(record.internalProductId);
  if(record.contractVersion!==PURCHASE_CONTRACT_VERSION || record.state!=='grant_ready' ||
    record.tokenKey!==row.token_key || record.grantId!=='iapv1:'+fingerprint ||
    record.ownerUid!==uid || record.ownerBinding!==sha(uid) ||
    !product || product.playProductId!==record.playProductId ||
    product.celestialJade!==record.celestialJade ||
    !Number.isSafeInteger(record.celestialJade) || record.celestialJade<=0)
      fail('invalid_server_purchase');
  return {
    purchase_contract_version: record.contractVersion,
    state: 'grant_ready',
    grant_id: record.grantId,
    internal_product_id: record.internalProductId,
    celestial_jade: record.celestialJade,
  };
}

export async function repairVerifiedPurchases({db, verifiedIdentity,
  makeWallet=createD1Wallet, initialize=ensureCanonicalAccountAfterVerifiedCreditRC12}={}) {
  if(!db?.prepare || !db?.batch || typeof makeWallet!=='function' || typeof initialize!=='function')
    fail('repair_unavailable');
  const uid=eligibleOwner(verifiedIdentity);
  const primary=typeof db.withSession==='function' ? db.withSession('first-primary'): db;
  const result=await primary.prepare(`SELECT token_key,record_json FROM iap_purchase_ledger_v1
    WHERE (CASE WHEN json_valid(record_json) THEN json_extract(record_json,'$.ownerUid') ELSE NULL END)=?
      AND (CASE WHEN json_valid(record_json) THEN json_extract(record_json,'$.state') ELSE NULL END)='grant_ready'
    ORDER BY token_key LIMIT ?`).bind(uid, MAX_PURCHASES_PER_CALL+1).all();
  if(!Array.isArray(result?.results)) fail('invalid_d1_reply');
  // Never silently truncate the ledger and claim the wallet is repaired.
  if(result.results.length>MAX_PURCHASES_PER_CALL) fail('repair_batch_limit');
  const grants=result.results.map(row=>grantFromLedger(row,uid));
  const wallet=makeWallet(db);
  if(!wallet || typeof wallet.creditVerifiedPurchase!=='function') fail('repair_unavailable');
  let recovered=0;
  for(const grant of grants){
    // D1 credit includes refund freshness, void, and account hold guards inside
    // the atomic wallet batch. A failure must stop repair; replay is safe.
    const receipt=await wallet.creditVerifiedPurchase(uid,grant);
    if(!receipt || typeof receipt.applied!=='boolean') fail('invalid_wallet_reply');
    if(receipt.applied) recovered++;
  }
  // Do not provision a canonical account on an empty/unauthorized ledger scan.
  if(grants.length) await initialize({db,verifiedUid:uid});
  return {repair_contract_version:1,state:'server_reconciled',
    verified_purchases:grants.length, new_wallet_credits:recovered};
}

export function createVerifiedPurchaseRepairHandler({
  verifyIdentity=verifyFirebaseHeaders, repair=repairVerifiedPurchases,
}={}) {
  return async (request, env) => {
    if(request.method!=='POST') return reply(405,{error:'method_not_allowed'});
    const url=new URL(request.url);
    if(url.search || !await emptyPost(request))
      return reply(400,{error:'unexpected_request_data'});
    if(env?.JADE_IAP_BACKEND_ENABLED!=='true' ||
       env?.JADE_VERIFIED_PURCHASE_REPAIR_ENABLED!=='true')
      return reply(503,{error:'purchase_recovery_disabled'});
    if(!env.DB?.prepare || !env.DB?.batch) return reply(503,{error:'repair_unavailable'});
    try {
      const identity=await verifyIdentity(request.headers,env);
      const result=await repair({db:env.DB,verifiedIdentity:identity});
      return reply(200,result);
    } catch(e) {
      if(e instanceof InvalidIdentity) return reply(401,{error:'unauthenticated'});
      if(e instanceof PurchaseRepairError && e.code==='repair_batch_limit')
        return reply(503,{error:'repair_requires_support'});
      return reply(503,{error:'purchase_repair_temporarily_unavailable'});
    }
  };
}
