/** RC10 Worker edge dispatch. No stage-proof write route exists, by design.
 * Each routed handler must be independently gated. The wrapper also rejects
 * disabled request types BEFORE invoking their handlers or reading D1/JWTs.
 * Unrelated routes are delegated to the original M14/RC2 Worker verbatim.
 */
const noStore=Object.freeze({'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff'});
const locked=(name)=>new Response(JSON.stringify({error:name}),{status:503,headers:noStore});

export function createWorkerEdgeDispatchRC10({baseFetch,rtdnPush,trustedProgressRead,recoveryIndexRead,paidLoadout}={}) {
  if([baseFetch,rtdnPush,trustedProgressRead,recoveryIndexRead,paidLoadout].some(fn=>typeof fn!=='function'))
    throw new TypeError('all_worker_handlers_required');
  return function fetchWithEdgeRC10(request,env,ctx) {
    const path=new URL(request.url).pathname;
    if(path==='/v1/rtdn/voids') {
      if(env?.JADE_IAP_BACKEND_ENABLED!=='true'||env?.JADE_REFUND_RTDN_PUSH_RC9_ENABLED!=='true')
        return locked('rtdn_locked');
      return rtdnPush(request,env,ctx);
    }
    if(path==='/v1/wallet/trusted-progress') {
      if(env?.JADE_TRUSTED_PROGRESSION_READ_ENABLED!=='true')return locked('trusted_progression_disabled');
      return trustedProgressRead(request,env,ctx);
    }
    if(path==='/v1/wallet/summon-recovery-index') {
      if(env?.JADE_SUMMON_RECOVERY_INDEX_READ_ENABLED!=='true')return locked('recovery_index_disabled');
      return recoveryIndexRead(request,env,ctx);
    }
    if(path==='/v1/wallet/paid-loadout') {
      if(request.method==='GET' && env?.JADE_PAID_LOADOUT_READ_ENABLED!=='true')return locked('paid_loadout_read_disabled');
      if(request.method==='POST' && (env?.JADE_IAP_BACKEND_ENABLED!=='true'||env?.JADE_PAID_LOADOUT_WRITE_ENABLED!=='true'))
        return locked('paid_loadout_write_disabled');
      return paidLoadout(request,env,ctx);
    }
    return baseFetch(request,env,ctx);
  };
}
