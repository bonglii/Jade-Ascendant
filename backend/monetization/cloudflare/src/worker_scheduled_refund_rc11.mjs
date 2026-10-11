/** Worker scheduled() bridge for the EXISTING RC7 refund reconciliation job.
 * No public route or client authority. Never acknowledges a failed poll as success.
 * Production schedule and job flag must be explicitly configured after QA.
 */
import { createPlayGateway } from './play_api.mjs';
import { runRefundCronJobRC7 } from './refund_cron_job_rc7.mjs';

export function createRefundScheduledHandlerRC11({
  run=runRefundCronJobRC7,
  makePlayGateway=createPlayGateway,
  clock=()=>Date.now(),
}={}){
  if(typeof run!=='function'||typeof makePlayGateway!=='function'||typeof clock!=='function')
    throw new TypeError('refund_schedule_dependency_invalid');
  return async function scheduled(_event,env,_ctx){
    // Check BEFORE requesting secrets, D1, or making Play network calls.
    if(env?.JADE_REFUND_CRON_JOB_RC7_ENABLED!=='true')return {state:'job_locked'};
    const nowMs=clock();
    if(!Number.isSafeInteger(nowMs)||nowMs<=0)throw new Error('invalid_job_clock');
    // Propagate network/D1/pagination errors: failed job must be observable.
    const result=await run(env,{makePlayGateway,nowMs});
    if(result?.state!=='staging_reconciled_not_production_ready')
      throw new Error('refund_reconciliation_incomplete');
    return result;
  };
}
