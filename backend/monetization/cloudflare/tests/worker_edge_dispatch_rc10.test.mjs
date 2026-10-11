import test from 'node:test';
import assert from 'node:assert/strict';
import {createWorkerEdgeDispatchRC10} from '../src/worker_edge_dispatch_rc10.mjs';
const counters=()=>({base:0,rtdn:0,progress:0,recovery:0,loadout:0});
const h=c=>createWorkerEdgeDispatchRC10({
  baseFetch:async()=>{c.base++;return new Response('old');},
  rtdnPush:async()=>{c.rtdn++;return new Response('rtdn');},
  trustedProgressRead:async()=>{c.progress++;return new Response('progress');},
  recoveryIndexRead:async()=>{c.recovery++;return new Response('recovery');},
  paidLoadout:async()=>{c.loadout++;return new Response('loadout');},
});
const u=p=>'https://iap.example'+p;
test('disabled routes fail closed before any handler/DB/auth call',async()=>{
  const c=counters(),f=h(c);
  for(const [path,method] of [['/v1/rtdn/voids','POST'],['/v1/wallet/trusted-progress','GET'],['/v1/wallet/summon-recovery-index','GET'],['/v1/wallet/paid-loadout','GET'],['/v1/wallet/paid-loadout','POST']]){
    const result=await f(new Request(u(path),{method}),{});assert.equal(result.status,503);
  }
  assert.deepEqual(c,counters());
});
test('explicitly gated requests hit only their own handler',async()=>{
  const c=counters(),f=h(c),env={JADE_IAP_BACKEND_ENABLED:'true',JADE_REFUND_RTDN_PUSH_RC9_ENABLED:'true',JADE_TRUSTED_PROGRESSION_READ_ENABLED:'true',JADE_SUMMON_RECOVERY_INDEX_READ_ENABLED:'true',JADE_PAID_LOADOUT_READ_ENABLED:'true',JADE_PAID_LOADOUT_WRITE_ENABLED:'true'};
  assert.equal(await (await f(new Request(u('/v1/rtdn/voids'),{method:'POST'}),env)).text(),'rtdn');
  assert.equal(await (await f(new Request(u('/v1/wallet/trusted-progress')),env)).text(),'progress');
  assert.equal(await (await f(new Request(u('/v1/wallet/summon-recovery-index')),env)).text(),'recovery');
  assert.equal(await (await f(new Request(u('/v1/wallet/paid-loadout')),env)).text(),'loadout');
  assert.equal(await (await f(new Request(u('/v1/wallet/paid-loadout'),{method:'POST'}),env)).text(),'loadout');
  assert.deepEqual(c,{base:0,rtdn:1,progress:1,recovery:1,loadout:2});
});
test('old purchase, wallet, summon, and health URLs are delegated unchanged',async()=>{
  const c=counters(),f=h(c);
  for(const path of ['/health','/v1/iap/authorize-v2','/v1/wallet/paid','/v1/wallet/summon','/v1/wallet/summon-recovery/uuid','/v1/wallet/entitlements'])
    assert.equal(await (await f(new Request(u(path)),{})).text(),'old');
  assert.equal(c.base,6);
});
test('read/write loadout remain independently locked',async()=>{
  const c=counters(),f=h(c),env={JADE_PAID_LOADOUT_READ_ENABLED:'true',JADE_PAID_LOADOUT_WRITE_ENABLED:'false',JADE_IAP_BACKEND_ENABLED:'true'};
  assert.equal((await f(new Request(u('/v1/wallet/paid-loadout')),env)).status,200);
  assert.equal((await f(new Request(u('/v1/wallet/paid-loadout'),{method:'POST'}),env)).status,503);
  assert.equal(c.loadout,1);
});
test('trusted stage/proof write is never routed',async()=>{
  const c=counters(),f=h(c);
  const r=await f(new Request(u('/v1/wallet/trusted-progress/issue'),{method:'POST'}),{});
  assert.equal(await r.text(),'old');assert.equal(c.progress,0);
});
