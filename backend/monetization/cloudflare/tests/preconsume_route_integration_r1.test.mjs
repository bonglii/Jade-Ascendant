import test from 'node:test';
import assert from 'node:assert/strict';
import {createPaidPurchaseCreditHandlerM13} from '../src/paid_purchase_credit_route_m13.mjs';
import {InvalidIdentity} from '../src/jwt_verify.mjs';
const URL='https://jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev/v1/iap/authorize-v2';
const token='token-with-safe-test-padding-1234';
const uid='firebase_user_123';
const identity={auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}},app:{appId:'app'}},
      enabled={JADE_IAP_BACKEND_ENABLED:'true',JADE_PAID_WALLET_CREDIT_V2_ENABLED:'true',PLAY_SERVICE_ACCOUNT_JSON:'test-only'};
const msg=()=>new Request(URL,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({purchase_token:token})});
function scenario({watermark=Date.now(),held=0,voided=0,down=false,authFailed=false}={}) {
 const stats={precheck:0,authorize:0,playCalls:0};
 const DB={withSession(mode){assert.equal(mode,'first-primary');return this},prepare(){return {bind(){return {async first(){stats.precheck++;if(down)throw Error('down');return {voided,held,watermark_ms:watermark};}}}}}};
 const handler=createPaidPurchaseCreditHandlerM13({
  verifyIdentity:async()=>{if(authFailed)throw new InvalidIdentity('auth failed');return identity},
  makeWallet:()=>({}),makeLedger:()=>({}),makePlay:()=>{stats.playCalls++;return {};},
  authorizeAndCredit:async()=>{stats.authorize++;return {wallet:{wallet_contract_version:1,balance:100,revision:1}};},
 });
 return {handler,env:{...enabled,DB},stats};
}
test('stale refund cursor blocks Play, consume, and wallet writes',async()=>{
 const s=scenario({watermark:Date.now()-4*3600000});const r=await s.handler(msg(),s.env);
 assert.equal(r.status,503);assert.equal(s.stats.precheck,1);assert.equal(s.stats.authorize,0);assert.equal(s.stats.playCalls,0);
 assert.equal((await r.json()).error,'temporary_failure');
});
test('fresh cursor permits authority, without exposing purchase token in response',async()=>{
 const s=scenario();const r=await s.handler(msg(),s.env);
 assert.equal(r.status,200);assert.equal(s.stats.authorize,1);
 const response=await r.text();assert.ok(!response.includes(token));assert.equal(JSON.parse(response).wallet.balance,100);
});
test('refund held and D1 outage block before Play',async()=>{
 for(const config of [{held:1},{voided:1},{down:true}]){
  const s=scenario(config);assert.equal((await s.handler(msg(),s.env)).status,503);
  assert.equal(s.stats.authorize,0);assert.equal(s.stats.playCalls,0);
 }
});
test('missing Firebase identity blocks all D1/Play calls',async()=>{
 const s=scenario({authFailed:true});assert.equal((await s.handler(msg(),s.env)).status,401);
 assert.equal(s.stats.precheck,0);assert.equal(s.stats.authorize,0);
});
test('global disabled returns 503 without contacting backend',async()=>{
 const s=scenario();assert.equal((await s.handler(msg(),{...s.env,JADE_IAP_BACKEND_ENABLED:'false'})).status,503);
 assert.equal(s.stats.precheck,0);assert.equal(s.stats.authorize,0);
});
