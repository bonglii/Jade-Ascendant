/** Entry point for a FUTURE authenticated Worker scheduled() handler only.
 * Must never be routed from fetch()/the Android device. Job gate is OFF by default.
 * It does not itself mark JADE_REFUND_RECONCILIATION_READY=true.
 */
import {reconcilePlayVoidsRC7,reconcileUnmatchedVoidsRC7} from './play_voided_reconciliation_rc7.mjs';
export async function runRefundCronJobRC7(env,{
  makePlayGateway, reconcile=reconcilePlayVoidsRC7, reconcileUnmatched=reconcileUnmatchedVoidsRC7,
  nowMs=Date.now(),
}={}) {
  if(env?.JADE_REFUND_CRON_JOB_RC7_ENABLED!=='true')return {state:'job_locked'};
  if(!env.DB||typeof env.DB.prepare!=='function'||typeof env.DB.batch!=='function'||
    typeof env.PLAY_SERVICE_ACCOUNT_JSON!=='string'||!env.PLAY_SERVICE_ACCOUNT_JSON||
    typeof makePlayGateway!=='function')throw new Error('refund_job_not_configured');
  const play=makePlayGateway(env.PLAY_SERVICE_ACCOUNT_JSON);
  if(!play||typeof play.listVoidedPurchasesPageRC7!=='function')throw new Error('refund_play_adapter_missing');
  const completed=await reconcile({db:env.DB,nowMs,
    listVoidedPage: request=>play.listVoidedPurchasesPageRC7(request)});
  // Revisit events first seen before purchase attribution. Any failure should
  // surface as a failed scheduled job rather than reporting false readiness.
  const unmatched=await reconcileUnmatched({db:env.DB,max:100});
  return {state:'staging_reconciled_not_production_ready',pages:completed.pages,
    records:completed.records,matched:completed.matched,
    unmatched_detected:completed.unmatched,backlog_revisited:unmatched.reviewed,
    backlog_attributed:unmatched.matched};
}
