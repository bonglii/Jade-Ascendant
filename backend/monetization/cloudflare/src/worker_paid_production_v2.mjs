import {updatePushRoute} from './update_push_gateway.mjs';
/** Explicit production entrypoint. Existing production config is unchanged. */
import candidate from './worker_release_candidate.mjs';
import {odysseyRoute} from './odyssey_http.mjs';
import {flushOutbox} from './odyssey_service.mjs';
import {verifyFirebaseHeaders} from './jwt_verify.mjs';
const HOST='jade-ascendant-iap.jade-ascendant-studio.workers.dev';
export const PRODUCTION_GATES_V2=Object.freeze([
 'JADE_REAL_MONEY_RELEASE_ENABLED','JADE_IAP_BACKEND_ENABLED',
 'JADE_PAID_WALLET_CREDIT_V2_ENABLED','JADE_CANONICAL_ONBOARDING_RC12_ENABLED',
 'JADE_PAID_GAMEPLAY_V2_ENABLED','JADE_PAID_WALLET_READ_ENABLED',
 'JADE_REFUND_RECONCILIATION_READY','JADE_REFUND_CRON_JOB_RC7_ENABLED',
 'JADE_VERIFIED_PURCHASE_REPAIR_ENABLED',
]);
const reply=(status,data)=>new Response(JSON.stringify(data),{status,headers:{
 'content-type':'application/json; charset=utf-8','cache-control':'private, no-store',
 'x-content-type-options':'nosniff',
}});
export function createProductionWorkerV2({base=candidate,verifyIdentity=verifyFirebaseHeaders}={}){
 return{async fetch(request,env,ctx){
  const url=new URL(request.url);
  if(url.hostname!==HOST)return reply(421,{error:'invalid_production_host'});
  const active=env?.JADE_STAGING_ACCOUNT_GUARD!=='true'&&PRODUCTION_GATES_V2.every(k=>env?.[k]==='true');
  if(url.pathname==='/health'&&request.method==='GET')return reply(200,{service:'jade-iap',gameplay_contract:2,release_enabled:active});
  if(!active)return reply(503,{error:'real_money_locked'});
  if(url.pathname==='/internal/updates')return updatePushRoute(request,env);
  if(['/internal/odyssey/config','/v1/odyssey/ssv'].includes(url.pathname))return odysseyRoute(request,env,ctx);
  // RTDN uses its own trusted Google service identity, never a player token.
  if(url.pathname==='/v1/rtdn/voids')return base.fetch(request,env,ctx);
  if(!['/v1/iap/authorize-v2','/v1/iap/recover-verified','/v1/wallet/paid','/v1/wallet/gameplay-v2','/v1/odyssey','/v2/odyssey'].includes(url.pathname))return reply(410,{error:'paid_route_retired'});
  try{
   const identity=await verifyIdentity(request.headers,env);
   if(identity?.auth?.token?.firebase?.sign_in_provider!=='google.com'||!identity?.auth?.uid||typeof identity?.app?.appId!=='string')return reply(401,{error:'recoverable_google_account_required'});
   if(['/v1/odyssey','/v2/odyssey'].includes(url.pathname))return odysseyRoute(request,env,ctx,identity.auth.uid);
  }catch{return reply(401,{error:'unauthenticated'});}
  return base.fetch(request,env,ctx);
 },async scheduled(event,env,ctx){
  // Mail delivery retries cannot suppress the existing refund monitor.
  const results=await Promise.allSettled([base.scheduled?.(event,env,ctx),flushOutbox(env)]);
  if(results[0].status==='rejected')throw results[0].reason;
 }};
}
export default createProductionWorkerV2();
