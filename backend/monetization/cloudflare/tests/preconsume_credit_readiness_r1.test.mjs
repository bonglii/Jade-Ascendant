import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {assertPreconsumeCreditReadinessR1 as guard} from '../src/preconsume_credit_readiness_r1.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const uid='test-firebase-uid';
const token='test-play-purchase-token-01234567890';
const now=Date.now();
function fixture({watermark=now-1000,voided=0,held=0,failure=false}={}) {
 const stats={reads:0,queries:[],consumes:0,credits:0};
 const db={
  withSession(mode){assert.equal(mode,'first-primary');return this},
  prepare(sql){stats.queries.push(sql);return {bind(...args){return {
   async first(){stats.reads++;if(failure)throw Error('DB down');
    assert.deepEqual(args,['playtoken:'+hash(token),'u1:'+hash(uid)]);
    return {voided,held,watermark_ms:watermark};
   }
  }}}}
 };
 return {db,stats};
}
test('fresh verified account and purchase allow only preflight',async()=>{
 const f=fixture();assert.equal(await guard({db:f.db,verifiedUid:uid,purchaseToken:token,nowMs:now}),true);
 assert.equal(f.stats.reads,1);assert.equal(f.stats.consumes,0);assert.equal(f.stats.credits,0);
});
test('missing refund cursor fails before any downstream call',async()=>{
 const f=fixture({watermark:null});await assert.rejects(guard({db:f.db,verifiedUid:uid,purchaseToken:token,nowMs:now}),{code:'refund_monitor_stale'});
 assert.equal(f.stats.consumes,0);assert.equal(f.stats.credits,0);
});
test('stale refund cursor fails closed',async()=>{
 const f=fixture({watermark:now-2*3600000-1});await assert.rejects(guard({db:f.db,verifiedUid:uid,purchaseToken:token,nowMs:now}),{code:'refund_monitor_stale'});
});
test('voided purchase or held account fails closed',async()=>{
 for (const props of [{voided:1},{held:1}]) {const f=fixture(props);await assert.rejects(guard({db:f.db,verifiedUid:uid,purchaseToken:token,nowMs:now}),{code:'refund_or_hold'});}
});
test('D1 unavailable fails closed',async()=>{
 const f=fixture({failure:true});await assert.rejects(guard({db:f.db,verifiedUid:uid,purchaseToken:token,nowMs:now}),{code:'refund_gate_unavailable'});
});
test('forged client UID and purchase token fail before D1 read',async()=>{
 const f=fixture();for(const [u,t] of [['bad uid',token],[uid,'x'],[null,token],[uid,null]]) {
  await assert.rejects(guard({db:f.db,verifiedUid:u,purchaseToken:t,nowMs:now}),TypeError);
 }assert.equal(f.stats.reads,0);
});
test('future watermark beyond skew fails closed',async()=>{
 const f=fixture({watermark:now+61000});await assert.rejects(guard({db:f.db,verifiedUid:uid,purchaseToken:token,nowMs:now}),{code:'refund_monitor_stale'});
});
