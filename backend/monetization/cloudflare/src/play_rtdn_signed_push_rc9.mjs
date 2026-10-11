/**
 * RC9 stage-only — authenticated Google Play RTDN voided purchase ingestion.
 * No public or active route. Only bind from a gated Worker route after review.
 * JWT: Google RS256, pinned Google JWKS, exact issuer/audience/service email.
 * No Play token/UID/order ID is returned, logged or stored by this handler.
 */
import { recordPlayVoidRC7 } from './play_voided_reconciliation_rc7.mjs';

const PACKAGE = 'com.yungdevstudio.jadeascendant';
const GOOGLE_JWKS = 'https://www.googleapis.com/oauth2/v3/certs';
const MAX_BODY_BYTES = 12 * 1024;
const MAX_MESSAGE_BYTES = 8 * 1024;
const JWT_RE = /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/;
const TOKEN_RE = /^[\x21-\x7e]{16,4096}$/;
const milliseconds = v => typeof v === 'string' && /^\d{10,17}$/.test(v) && Number.isSafeInteger(Number(v)) && Number(v) > 0 ? Number(v) : null;
const object = x => x !== null && typeof x === 'object' && !Array.isArray(x) && Object.getPrototypeOf(x) === Object.prototype;

export class RtdnIngressErrorRC9 extends Error {
  constructor(code) { super(code); this.name = 'RtdnIngressErrorRC9'; this.code = code; }
}
function reject(code) { throw new RtdnIngressErrorRC9(code); }
function bytesB64u(value) {
  if (typeof value !== 'string' || value.length === 0 || !/^[A-Za-z0-9_-]+$/.test(value)) reject('invalid_jwt');
  try {
    const b = value.replace(/-/g, '+').replace(/_/g, '/');
    return Uint8Array.from(atob(b + '='.repeat((4 - b.length % 4) % 4)), c => c.charCodeAt(0));
  } catch { reject('invalid_jwt'); }
}
function jsonBytes(bytes, code) {
  try { const o=JSON.parse(new TextDecoder('utf-8', {fatal:true}).decode(bytes)); if(!object(o)) reject(code); return o; }
  catch { reject(code); }
}
function asInt(value, min, max) { return Number.isSafeInteger(value) && value >= min && value <= max; }

/** Cryptographic verification is performed BEFORE parsing the Pub/Sub message. */
export async function verifyGooglePushJwtRC9(token, {
  audience, serviceAccountEmail, fetcher = fetch, subtle = crypto.subtle,
  nowMs = Date.now(), jwksCache = null,
} = {}) {
  if (typeof token !== 'string' || token.length < 100 || token.length > 8192 || !JWT_RE.test(token)) reject('invalid_jwt');
  if (typeof audience !== 'string' || !/^https:\/\/[a-z0-9.-]+(?:\/[A-Za-z0-9/_-]+)+$/.test(audience) ||
      typeof serviceAccountEmail !== 'string' || !/^[a-z0-9._-]+@[a-z0-9.-]+\.gserviceaccount\.com$/.test(serviceAccountEmail)) reject('rtdn_not_configured');
  if (!Number.isSafeInteger(nowMs) || nowMs <= 0) reject('invalid_clock');
  const [a,b,s] = token.split('.');
  const header=jsonBytes(bytesB64u(a),'invalid_jwt');
  const claims=jsonBytes(bytesB64u(b),'invalid_jwt');
  if (header.alg !== 'RS256' || typeof header.kid !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(header.kid) ||
      (header.typ !== undefined && header.typ !== 'JWT')) reject('invalid_jwt');
  const now=Math.floor(nowMs/1000);
  if (!['accounts.google.com','https://accounts.google.com'].includes(claims.iss) ||
      claims.aud !== audience || claims.email !== serviceAccountEmail || claims.email_verified !== true ||
      typeof claims.sub !== 'string' || !claims.sub ||
      !asInt(claims.iat, 1, now+60) || !asInt(claims.exp, now+1, now+3600) ||
      claims.exp - claims.iat > 3600) reject('invalid_jwt');
  let keys=jwksCache?.keys;
  if (!Array.isArray(keys) || !Number.isSafeInteger(jwksCache.expiresMs) || jwksCache.expiresMs <= nowMs ||
      !keys.some(k => k?.kid === header.kid)) {
    let response;
    try { response=await fetcher(GOOGLE_JWKS, {redirect:'error',signal:AbortSignal.timeout(5000)}); }
    catch { reject('jwks_unavailable'); }
    if (!response?.ok) reject('jwks_unavailable');
    const rawLength=response.headers?.get('content-length');
    if (rawLength !== null && rawLength !== undefined && (!/^\d+$/.test(rawLength) || Number(rawLength)>131072)) reject('jwks_unavailable');
    try { const parsed=await response.json(); keys=parsed.keys; }
    catch { reject('jwks_unavailable'); }
    if (!Array.isArray(keys) || keys.length < 1 || keys.length>64) reject('jwks_unavailable');
    if (jwksCache) { jwksCache.keys=keys; jwksCache.expiresMs=nowMs+300_000; }
  }
  const key=keys.find(k => k?.kid === header.kid && k.kty === 'RSA' &&
    (!k.alg || k.alg === 'RS256') && (!k.use || k.use === 'sig'));
  if (!key) reject('invalid_jwt');
  try {
    const publicKey=await subtle.importKey('jwk',key,{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['verify']);
    const valid=await subtle.verify('RSASSA-PKCS1-v1_5',publicKey,bytesB64u(s),new TextEncoder().encode(a+'.'+b));
    if (!valid) reject('invalid_jwt');
  } catch { reject('invalid_jwt'); }
  return {verified_service_account:true};
}

function standardBase64(value) {
  if (typeof value !== 'string' || value.length < 4 || value.length > MAX_MESSAGE_BYTES*2 ||
      !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value)) reject('invalid_message');
  let bytes;
  try { bytes=Uint8Array.from(atob(value),c=>c.charCodeAt(0)); }
  catch { reject('invalid_message'); }
  if (bytes.length>MAX_MESSAGE_BYTES) reject('invalid_message');
  return bytes;
}
export function decodeGooglePlayPushRC9(envelope, {subscription,nowMs=Date.now()}={}) {
  if (!object(envelope) || typeof subscription !== 'string' || envelope.subscription!==subscription ||
      !object(envelope.message) || typeof envelope.message.messageId !== 'string' ||
      !/^[A-Za-z0-9._:-]{1,128}$/.test(envelope.message.messageId)) reject('invalid_message');
  const notification=jsonBytes(standardBase64(envelope.message.data),'invalid_message');
  if (notification.version !== '1.0' || notification.packageName !== PACKAGE ||
      milliseconds(notification.eventTimeMillis) === null ||
      milliseconds(notification.eventTimeMillis) > nowMs + 300_000) reject('invalid_notification');
  const voided=notification.voidedPurchaseNotification;
  if (voided===undefined) {
    // Other authenticated Play notifications are not refunds. Acknowledge, no hold.
    return {kind:'unrelated'};
  }
  if (!object(voided) || voided.purchaseToken === undefined ||
      !TOKEN_RE.test(voided.purchaseToken) || voided.productType !== 2 ||
      ![1,2].includes(voided.refundType) ||
      Object.keys(notification).some(k => k.endsWith('Notification') && k!=='voidedPurchaseNotification')) reject('invalid_notification');
  // RTDN doesn't include void reason/source: use 0 (other/unknown) until cron enriches.
  // Partial refunds also hold the account pending manual review; do NOT credit.
  return {kind:'void', item:{
    purchaseToken:voided.purchaseToken,
    voidedTimeMillis:notification.eventTimeMillis,
    voidedReason:0, voidedSource:0,
  }};
}

async function readJsonBounded(request) {
  if (!/^application\/json(?:\s*;|$)/i.test(request.headers.get('content-type') || '')) reject('invalid_message');
  const advertised=request.headers.get('content-length');
  if (advertised !== null && (!/^\d+$/.test(advertised) || Number(advertised)>MAX_BODY_BYTES)) reject('invalid_message');
  if (!request.body) reject('invalid_message');
  let len=0;const chunks=[];const reader=request.body.getReader();
  try { while(true){const {done,value}=await reader.read();if(done)break;
    len+=value.byteLength;if(len>MAX_BODY_BYTES){await reader.cancel();reject('invalid_message');}
    chunks.push(value);
  }} finally {reader.releaseLock();}
  const buffer=new Uint8Array(len);let offset=0;
  for(const chunk of chunks){buffer.set(chunk,offset);offset+=chunk.length;}
  return jsonBytes(buffer,'invalid_message');
}
const response=(status,data)=>new Response(JSON.stringify(data),{status,headers:{
  'content-type':'application/json; charset=utf-8', 'cache-control':'no-store',
  'x-content-type-options':'nosniff', 'referrer-policy':'no-referrer',
}});

/** Requires both gates explicitly. This handler MUST NOT be attached to public routes by default. */
export function createGooglePlayVoidedPushHandlerRC9({
  verifier=verifyGooglePushJwtRC9, record=recordPlayVoidRC7,
  fetcher=fetch, subtle=crypto.subtle, jwksCache={keys:null,expiresMs:0}, clock=()=>Date.now(),
}={}) {
  return async function handle(request,env) {
    if (request.method!=='POST') return response(405,{error:'method_not_allowed'});
    if (env?.JADE_REFUND_RTDN_PUSH_RC9_ENABLED!=='true' || env?.JADE_IAP_BACKEND_ENABLED!=='true')
      return response(503,{error:'rtdn_locked'});
    if (!env.DB?.prepare || !env.DB?.batch ||
        typeof env.JADE_RTDN_PUSH_AUDIENCE!=='string' ||
        typeof env.JADE_RTDN_PUSH_EMAIL!=='string' ||
        typeof env.JADE_RTDN_PUSH_SUBSCRIPTION!=='string') return response(503,{error:'rtdn_not_configured'});
    const bearer=request.headers.get('Authorization')||'';
    if(!/^Bearer [A-Za-z0-9_.-]+$/.test(bearer)) return response(401,{error:'unauthenticated'});
    const nowMs=clock();
    try {
      await verifier(bearer.slice(7),{audience:env.JADE_RTDN_PUSH_AUDIENCE,
        serviceAccountEmail:env.JADE_RTDN_PUSH_EMAIL,fetcher,subtle,nowMs,jwksCache});
      const message=decodeGooglePlayPushRC9(await readJsonBounded(request),{
        subscription:env.JADE_RTDN_PUSH_SUBSCRIPTION,nowMs});
      if (message.kind==='unrelated') return response(200,{state:'ignored'});
      const result=await record({db:env.DB,item:message.item,nowMs});
      if (!result || typeof result.matched !== 'boolean') return response(503,{error:'rtdn_unavailable'});
      // Return only a generic ack, no account existence signal to push sender.
      return response(200,{state:'recorded'});
    } catch(error) {
      if(error instanceof RtdnIngressErrorRC9) {
        if(error.code==='jwks_unavailable') return response(503,{error:'rtdn_unavailable'});
        if(error.code==='invalid_jwt') return response(401,{error:'unauthenticated'});
        if(error.code==='rtdn_not_configured') return response(503,{error:'rtdn_not_configured'});
        return response(400,{error:'invalid_notification'});
      }
      // Transient DB/D1 failure -> Pub/Sub retries. Never acknowledge uncommitted voids.
      return response(503,{error:'rtdn_unavailable'});
    }
  };
}
