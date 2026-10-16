import {verifyJwt, InvalidIdentity} from '../monetization/cloudflare/src/jwt_verify.mjs';

const FIREBASE_KEYS = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
export class ProfileAuthRejected extends InvalidIdentity {
  constructor(stage) { super(); this.stage = stage; }
}
export class ProfileAuthUnavailable extends Error {
  constructor(stage) { super('Authentication keys unavailable.'); this.stage = stage; }
}
const reject = stage => { throw new ProfileAuthRejected(stage); };
function decode(part) {
  try {
    const base = part.replace(/-/g,'+').replace(/_/g,'/');
    const bytes = Uint8Array.from(atob(base+'='.repeat((4-base.length%4)%4)),c=>c.charCodeAt(0));
    const value = JSON.parse(new TextDecoder().decode(bytes));
    if(!value || typeof value!=='object' || Array.isArray(value)) reject('token_format');
    return value;
  } catch { reject('token_format'); }
}

export async function verifyAuth(request,env,options={}) {
  if(env.FIREBASE_PROJECT_ID !== 'jade-ascendant') reject('server_project');
  const match = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(request.headers.get('authorization')||'');
  if(!match) reject('bearer_format');
  if(match[1].length>8192 || match[1].length<50) reject('token_format');
  const parts=match[1].split('.'),header=decode(parts[0]),claims=decode(parts[1]);
  if(header.alg!=='RS256'||typeof header.kid!=='string'||!header.kid) reject('token_header');
  // These checks only label rejection. No decoded claim is trusted for identity
  // until the existing cryptographic verifier below succeeds.
  if(claims.iss!=='https://securetoken.google.com/jade-ascendant') reject('token_issuer');
  if(claims.aud!=='jade-ascendant' && !(Array.isArray(claims.aud)&&claims.aud.includes('jade-ascendant'))) reject('token_audience');
  const time=Math.floor((options.now??Date.now())/1000);
  if(!Number.isSafeInteger(claims.exp)||claims.exp<=time) reject('token_expired');
  if(!Number.isSafeInteger(claims.iat)||claims.iat>time+30) reject('token_issued_time');
  if(typeof claims.sub!=='string'||!claims.sub||claims.sub.length>128) reject('token_subject');
  if(!Number.isSafeInteger(claims.auth_time)||claims.auth_time>time+30) reject('token_auth_time');
  if(!['anonymous','google.com'].includes(claims.firebase?.sign_in_provider)) reject('token_provider');
  if(options.requireGoogle===true&&claims.firebase?.sign_in_provider!=='google.com')reject('google_required');
  let lookupStage='',lookupUnavailable=false;
  const fetcher=async(...args)=>{
    let response;
    try {
      // Runtime native functions may require their original receiver. Keep
      // the runtime receiver while preserving the profile diagnostics.
      const source=options.fetcher??globalThis.fetch;
      const [url,init]=args;
      // workerd accepts only follow/manual; "error" throws before any network
      // request. Manual plus the status checks below preserves redirect denial.
      response=await source.call(globalThis,url,{...init,redirect:'manual',signal:AbortSignal.timeout(10000)});
    } catch(error) {
      // Fixed labels only. Never log error.message, request data or the token.
      lookupStage=error?.name==='TimeoutError'||error?.name==='AbortError'?'keys_timeout':
        /illegal invocation/i.test(String(error?.message||''))?'keys_invocation':
        /redirect/i.test(String(error?.message||''))?'keys_redirect':'keys_transport';
      lookupUnavailable=true;throw new ProfileAuthUnavailable(lookupStage);
    }
    if(!response.ok) { lookupStage=response.status>=300&&response.status<400?'keys_redirect_response':'keys_http';lookupUnavailable=true;return response; }
    let keys;
    try { keys=(await response.clone().json()).keys; }
    catch { lookupStage='keys_format';lookupUnavailable=true;return response; }
    if(!Array.isArray(keys)||!keys.length||keys.length>32||keys.some(k=>!k||typeof k!=="object"||typeof k.kid!=="string"||typeof k.kty!=="string")) { lookupStage='keys_format';lookupUnavailable=true; }
    else if(!keys.some(k=>k.kid===header.kid&&k.kty==='RSA'&&(!k.alg||k.alg==='RS256')&&(!k.use||k.use==='sig'))) lookupStage='token_signing_key';
    return response;
  };
  try {
    const user=await verifyJwt(match[1],{jwksUrl:FIREBASE_KEYS,issuer:'https://securetoken.google.com/jade-ascendant',audience:'jade-ascendant',...options,fetcher});
    return user.sub;
  } catch(error) {
    if(lookupUnavailable) throw new ProfileAuthUnavailable(lookupStage);
    if(error instanceof InvalidIdentity) reject(lookupStage||'token_signature_or_cached_key');
    throw error;
  }
}
