import test from 'node:test';
import assert from 'node:assert/strict';
import { createPaidPurchaseCreditHandlerM13 } from '../src/paid_purchase_credit_route_m13.mjs';
import { createWorkerHandler } from '../src/index.mjs';
import { InvalidIdentity } from '../src/jwt_verify.mjs';
import { PurchaseAuthorityError } from '../../src/purchase_authority.mjs';
import { WalletError } from '../src/d1_wallet.mjs';

const URL = 'https://example.workers.dev/v1/iap/authorize-v2';
const TOKEN = 'test-purchase-token-abcdefghijklmnopqrstuvwxyz';
const IDENTITY = { auth:{ uid:'user_test', token:{firebase:{sign_in_provider:'google.com'}} }, app:{appId:'app_test'} };
const ENV = { JADE_IAP_BACKEND_ENABLED:'true', JADE_PAID_WALLET_CREDIT_V2_ENABLED:'true', DB:{}, PLAY_SERVICE_ACCOUNT_JSON:'opaque-secret' };
const request = (body={purchase_token:TOKEN}, method='POST', ct='application/json') => new Request(URL, {
  method, headers: ct ? {'content-type':ct} : {}, body: method==='POST' ? (typeof body==='string' ? body : JSON.stringify(body)) : undefined
});
const walletResponse = { wallet:{wallet_contract_version:1,balance:550,revision:2}, grant:{state:'grant_ready', grant_id:'private-should-not-reach-device', celestial_jade:550} };
function factory({auth=async()=>IDENTITY,credit=async()=>walletResponse}={}) {
  let calls=0;
  const handler=createPaidPurchaseCreditHandlerM13({
    verifyIdentity:auth,
    authorizeAndCredit:async args=>{calls++;return credit(args);},
    makeWallet:()=>({}), makeLedger:()=>({}), makePlay:()=>({}),
  });
  return {handler,calls:()=>calls};
}

test('M13 is disabled unless both global and dedicated gates true',async()=>{
  const x=factory({auth:async()=>{throw Error('must not check auth');}});
  for (const e of [{},{JADE_IAP_BACKEND_ENABLED:'true'},{JADE_PAID_WALLET_CREDIT_V2_ENABLED:'true'},
    {...ENV,JADE_PAID_WALLET_CREDIT_V2_ENABLED:'false'}, {...ENV,JADE_IAP_BACKEND_ENABLED:'false'}]){
    const r=await x.handler(request(),e);assert.equal(r.status,503);
    assert.deepEqual(await r.json(),{error:'paid_wallet_credit_disabled'});
  }
  assert.equal(x.calls(),0);
});
test('M13 locked before body parsing, auth, D1 and Play',async()=>{
  const r=await factory({auth:async()=>{throw Error('called auth');}}).handler(request('{BAD'), {});
  assert.equal(r.status,503);
});
test('M13 missing D1 or Play credential rejects closed',async()=>{
  const h=factory().handler;
  assert.equal((await h(request(),{...ENV,DB:null})).status,503);
  assert.equal((await h(request(),{...ENV,PLAY_SERVICE_ACCOUNT_JSON:null})).status,503);
});
test('M13 rejects GET without touching identity',async()=>{
  assert.equal((await factory({auth:async()=>{throw Error('bad');}}).handler(request({},'GET'),ENV)).status,405);
});
test('M13 requires verified Firebase identity',async()=>{
  const h=factory({auth:async()=>{throw new InvalidIdentity('bad')}}).handler;
  const r=await h(request(),ENV);assert.equal(r.status,401);
});
test('M13 accepts exact token-only body and returns only authoritative wallet receipt',async()=>{
  const x=factory();const r=await x.handler(request(),ENV);
  assert.equal(r.status,200); assert.deepEqual(await r.json(),{
    purchase_receipt_version:1,state:'server_wallet_credited',wallet:{wallet_contract_version:1,balance:550,revision:2},
  });
  assert.equal(x.calls(),1);
  assert.match(r.headers.get('cache-control'),/no-store/);
});
test('M13 never returns UID, Play grant, token, product or client spendable Jade',async()=>{
  const r=await factory().handler(request(),ENV);const s=await r.text();
  for(const value of ['grant_id','celestial_jade','purchase_token','user_test','internal_product_id']) assert.ok(!s.includes(value));
});
test('M13 rejects extra client-supplied UID, product and amount',async()=>{
  for(const key of ['uid','celestial_jade','internal_product_id']){
    const x=factory();const r=await x.handler(request({purchase_token:TOKEN,[key]:'injected'}),ENV);
    assert.equal(r.status,400);assert.equal(x.calls(),0);
  }
});
test('M13 rejects malformed JSON, wrong content type, short token',async()=>{
  const h=factory().handler;
  for(const r of [request('{invalid'),request({},'POST','text/plain'),request({purchase_token:'bad'})]){
    assert.equal((await h(r,ENV)).status,400);
  }
});
test('M13 rejects oversized request body (> 8KB)',async()=>{
  const r=await factory().handler(request('x'.repeat(8500)),ENV);assert.equal(r.status,400);
});
test('M13 rejects non-integer and unsafe wallet amounts without leaking grant',async()=>{
  for(const b of [-1,1.5,Number.MAX_SAFE_INTEGER+1]){
    const r=await factory({credit:async()=>({wallet:{wallet_contract_version:1,balance:b,revision:2}})}).handler(request(),ENV);
    assert.equal(r.status,503);
  }
});
test('M13 rejects empty wallet revision even when amount 0',async()=>{
  const r=await factory({credit:async()=>({wallet:{wallet_contract_version:1,balance:0,revision:0}})}).handler(request(),ENV);
  assert.equal(r.status,503);
});
test('M13 yields same server receipt on replay without local grant',async()=>{
  const x=factory(); const a=await x.handler(request(),ENV); const b=await x.handler(request(),ENV);
  assert.deepEqual(await a.json(),await b.json()); assert.equal(x.calls(),2);
});
test('M13 maps purchase account mismatch to 403',async()=>{
  const r=await factory({credit:async()=>{throw new PurchaseAuthorityError('permission-denied','denied')}}).handler(request(),ENV);
  assert.equal(r.status,403);assert.deepEqual(await r.json(),{error:'permission-denied'});
});
test('M13 maps purchase not-ready to retryable 409',async()=>{
  const r=await factory({credit:async()=>{throw new PurchaseAuthorityError('failed-precondition','pending')}}).handler(request(),ENV);
  assert.equal(r.status,409);
});
test('M13 maps wallet write failure to 503 without leaking contents',async()=>{
  const r=await factory({credit:async()=>{throw new WalletError('invalid_stored_wallet')}}).handler(request(),ENV);
  assert.equal(r.status,503);
  assert.deepEqual(await r.json(),{error:'wallet_temporarily_unavailable'});
});
test('M13 maps ambiguous backend failures to generic 503',async()=>{
  const r=await factory({credit:async()=>{throw new Error('private-key-leak')}}).handler(request(),ENV);
  assert.equal(r.status,503);assert.ok(!(await r.text()).includes('private-key-leak'));
});
test('M13 Worker routing of v2 remains locked while legacy route is retired',async()=>{
  const worker=createWorkerHandler({verifyIdentity:async()=>IDENTITY});
  let r=await worker(request(),{...ENV,JADE_PAID_WALLET_CREDIT_V2_ENABLED:'false'});
  assert.equal(r.status,503);assert.deepEqual(await r.json(),{error:'paid_wallet_credit_disabled'});
  r=await worker(new Request('https://example.workers.dev/v1/iap/authorize',{method:'POST'}),ENV);
  assert.equal(r.status,410);assert.deepEqual(await r.json(),{error:'legacy_purchase_route_retired'});
});
