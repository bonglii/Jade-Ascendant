import test from 'node:test';
import assert from 'node:assert/strict';
import {runRefundCronJobRC7} from '../src/refund_cron_job_rc7.mjs';
test('no env approval means no network, D1 or play calls',async()=>{
 const result=await runRefundCronJobRC7({}, {makePlayGateway(){throw Error('should not be called')}});
 assert.deepEqual(result,{state:'job_locked'});
});
test('gate alone cannot run without D1 and service account',async()=>{
 await assert.rejects(runRefundCronJobRC7({JADE_REFUND_CRON_JOB_RC7_ENABLED:'true'},{}),/not_configured/);
});
test('scheduled adapter accepts only trusted injected Google client',async()=>{
 const fakeDb={prepare(){},batch(){}}; let calls=0;
 const result=await runRefundCronJobRC7({JADE_REFUND_CRON_JOB_RC7_ENABLED:'true',DB:fakeDb,PLAY_SERVICE_ACCOUNT_JSON:'secret'}, {
   makePlayGateway:()=>({listVoidedPurchasesPageRC7:async()=>{calls++;return {voidedPurchases:[]}}}),
   reconcile:async({listVoidedPage})=>{await listVoidedPage({startTimeMs:1,endTimeMs:2,pageToken:null});return {pages:1,records:0,matched:0,unmatched:0}},
   reconcileUnmatched:async()=>({reviewed:0,matched:0}),
 });
 assert.equal(calls,1);assert.equal(result.state,'staging_reconciled_not_production_ready');
});
test('missing trusted adapter refuses to report a successful reconciliation',async()=>{
 const db={prepare(){},batch(){}};
 await assert.rejects(runRefundCronJobRC7({JADE_REFUND_CRON_JOB_RC7_ENABLED:'true',DB:db,PLAY_SERVICE_ACCOUNT_JSON:'secret'},
  {makePlayGateway:()=>({})}),/adapter_missing/);
});
