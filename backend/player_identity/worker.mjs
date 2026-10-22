import {createCompanionHandler,purgeExpiredMetrics} from './companion.mjs';
import {trialsProgress} from './heavenly_trials.mjs';
import {equipmentGrantRoute} from './equipment_grants.mjs';
import {receiveOdysseyMail} from './odyssey.mjs';
import {InvalidIdentity} from '../monetization/cloudflare/src/jwt_verify.mjs';
import {verifyAuth, ProfileAuthRejected, ProfileAuthUnavailable} from './auth.mjs';
export {verifyAuth} from './auth.mjs';
import {createMailHandler,MailError,processScheduled} from './mail.mjs';

import {currentDocument,publicSnapshot} from './pavilion.mjs';
import {trustPages} from './public_trust_pages.mjs';
import {createProgressBackupHandler} from './progress_backup.mjs';

const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const UID = /^JA[0-9A-HJKMNP-TV-Z]{10}$/;
const encoder = new TextEncoder();
const headers = {'content-type':'application/json','cache-control':'no-store','x-content-type-options':'nosniff'};
const reply = (code,body) => new Response(JSON.stringify(body),{status:code,headers});

export async function ownerBinding(uid) {
  const hash = await crypto.subtle.digest('SHA-256',encoder.encode(uid));
  return Array.from(new Uint8Array(hash),x=>x.toString(16).padStart(2,'0')).join('');
}

export function generateUid() {
  const bytes = crypto.getRandomValues(new Uint8Array(10));
  return 'JA'+Array.from(bytes,b=>ALPHABET[b&31]).join('');
}

export async function registerIdentity(db,owner,{generate=generateUid,now=Date.now}={}) {
  if(!/^[a-f0-9]{64}$/.test(owner)) throw new TypeError('invalid_owner');
  // Authoritative reads: bypass replica staleness when concurrent devices register.
  const session = db.withSession ? db.withSession('first-primary') : db;
  const read = () => session.prepare('SELECT public_uid FROM player_identities WHERE owner_binding = ?').bind(owner).first();
  let row = await read();
  if(row) return {public_uid:row.public_uid,owner_binding:owner};
  for(let attempt=0;attempt<8;attempt++) {
    const uid = generate();
    if(!UID.test(uid)) throw new TypeError('invalid_generated_uid');
    // Both ownership and public UID are unique in SQL, including simultaneous
    // registrations. IGNORE handles only uniqueness races; real DB errors propagate.
    await session.prepare('INSERT OR IGNORE INTO player_identities(owner_binding,public_uid,created_at) VALUES(?,?,?)')
      .bind(owner,uid,Math.floor(now()/1000)).run();
    row = await read();
    if(row) return {public_uid:row.public_uid,owner_binding:owner};
  }
  throw new Error('uid_allocation_exhausted');
}

export function createHandler({verify=verifyAuth,register=registerIdentity}={}) {
  const handleMail=createMailHandler({verify});
  const handleCompanion=createCompanionHandler({verify});
  const handleProgressBackup=createProgressBackupHandler({verify});
  return async(request,env)=>{
    const url = new URL(request.url);
    if(url.pathname==='/internal/equipment/compass-grant')return equipmentGrantRoute(request,env);
    if(url.pathname==='/internal/trials/progress')return trialsProgress(request,env);
    if(url.pathname==='/internal/odyssey/mail')return receiveOdysseyMail(request,env);
    if(Object.hasOwn(trustPages,url.pathname)){
      if(!['GET','HEAD'].includes(request.method))return reply(405,{error:'method_not_allowed'});
      return new Response(request.method==='HEAD'?null:trustPages[url.pathname],{headers:{'content-type':'text/html; charset=utf-8','cache-control':'public,max-age=300','content-security-policy':"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",'x-content-type-options':'nosniff','referrer-policy':'no-referrer','x-jade-trust-version':'1'}});
    }
    if(['/v1/player/agenda','/v1/player/gameplay-metrics'].includes(url.pathname))return handleCompanion(request,env);
    if(url.pathname==='/v1/player/progress-backup')return handleProgressBackup(request,env);
    if(url.pathname==='/v1/pavilion/banner') {
      if(request.method!=='GET')return reply(405,{error:'method_not_allowed'});
      if(!env.PROFILE_DB)return reply(503,{error:'service_unavailable'});
      try {const db=env.PROFILE_DB.withSession?env.PROFILE_DB.withSession('first-primary'):env.PROFILE_DB;return reply(200,publicSnapshot(await currentDocument(db),undefined,request.headers.get('x-jade-ascendant-arsenal')==='v1'));}
      catch {return reply(503,{error:'banner_unavailable'});}
    }
    if(url.pathname.startsWith('/admin')||url.pathname.startsWith('/v1/mail/')) {
      try { return await handleMail(request,env); }
      catch(error) {
        if(error instanceof MailError)return reply(error.status,{error:error.code});
        if(error instanceof ProfileAuthRejected||error instanceof ProfileAuthUnavailable)console.warn('JADE_PLAYER_AUTH stage='+error.stage);
        if(!(error instanceof InvalidIdentity)&&!(error instanceof ProfileAuthUnavailable))console.warn('JADE_MAIL stage=service_unavailable');
        return reply(error instanceof InvalidIdentity?401:503,{error:error instanceof InvalidIdentity?'unauthenticated':'service_unavailable'});
      }
    }
    if(url.pathname==='/health'&&request.method==='GET') {
      return reply(env.PROFILE_DB?200:503,{service:'jade-player-identity',ready:!!env.PROFILE_DB});
    }
    if(url.pathname!=='/v1/player/register') return reply(404,{error:'not_found'});
    if(request.method!=='POST') return reply(405,{error:'method_not_allowed'});
    // No email, local UID, arbitrary owner, name, reward or account merge inputs.
    // Registration identifies ONLY the signed token subject.
    if(request.headers.get('content-type')!=='application/json'||request.headers.get('content-length') && Number(request.headers.get('content-length'))>32)
      return reply(400,{error:'invalid_body'});
    let body;
    try {
      const reader=request.body?.getReader();
      let size=0;const chunks=[];
      if(reader) while(true) {
        const chunk=await reader.read();if(chunk.done)break;
        size+=chunk.value.byteLength;
        if(size>32){await reader.cancel();return reply(400,{error:'invalid_body'});}
        chunks.push(chunk.value);
      }
      const bytes=new Uint8Array(size);let offset=0;
      for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
      body=JSON.parse(new TextDecoder().decode(bytes));
    }catch{return reply(400,{error:'invalid_body'});}
    if(!body||Array.isArray(body)||typeof body!=='object'||Object.keys(body).length) return reply(400,{error:'invalid_body'});
    try {
      const uid=await verify(request,env);
      if(!env.PROFILE_DB) return reply(503,{error:'service_unavailable'});
      return reply(200,{version:1,...await register(env.PROFILE_DB,await ownerBinding(uid))});
    }catch(error){
      // Only fixed stage codes: never log the request, token, claims or account.
      if(error instanceof ProfileAuthRejected || error instanceof ProfileAuthUnavailable)
        console.warn('JADE_PLAYER_AUTH stage='+error.stage);
      return reply(error instanceof InvalidIdentity?401:503,{error:error instanceof InvalidIdentity?'unauthenticated':'service_unavailable'});
    }
  };
}

export default {fetch:createHandler(),scheduled(controller,env,ctx){
 // Mail stays independent; an optional analytics purge may never delay mail.
 ctx.waitUntil(processScheduled(env));
 // Existing Profile Worker cron is once per minute. Purge at UTC hour 00.
 // Never touch the new table before its staged SQL migration is present.
 const scheduledAt=Number(controller?.scheduledTime ?? Date.now());
 if(env.PROFILE_DB&&Number.isFinite(scheduledAt)&&new Date(scheduledAt).getUTCMinutes()===0){
  ctx.waitUntil(purgeExpiredMetrics(env.PROFILE_DB,Math.floor(scheduledAt/1000))
   .catch(()=>console.warn('JADE_METRICS_RETENTION stage=retry_pending')));
 }
}};
