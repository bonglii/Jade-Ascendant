import test from 'node:test';
import assert from 'node:assert/strict';
import { createWorkerHandler } from '../src/index.mjs';
import { createPaidWalletReadHandlerM8 } from '../src/paid_wallet_read_route_m8.mjs';
import { InvalidIdentity } from '../src/jwt_verify.mjs';

const HOST = 'https://jade-ascendant-iap.example.workers.dev';
const WALLET = `${HOST}/v1/wallet/paid`;
const id = (uid='player_A') => ({
  auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}},
  app:{appId:'1:350718070767:android:e5520012a501d2856cf01a'},
});
const env = (read='false') => ({
  JADE_IAP_BACKEND_ENABLED:'false', JADE_PAID_WALLET_READ_ENABLED:read,
  DB:{},
});
const fixture = (options={}) => {
  const counters = { verified:0, walletReads:0, ledgerWrites:0, playCalls:0, owner:null };
  const verifyIdentity = options.verifyIdentity ?? (async()=>{counters.verified++; return id();});
  const makeWallet = options.makeWallet ?? (()=>({
    getSnapshot: async uid => {
      counters.walletReads++; counters.owner=uid;
      return {wallet_contract_version:1,balance:500,revision:2};
    },
  }));
  const worker = createWorkerHandler({
    verifyIdentity,
    makePaidWalletRead: deps => createPaidWalletReadHandlerM8({...deps,makeWallet}),
    makeLedger:()=>{counters.ledgerWrites++;throw new Error('purchase ledger must not start');},
    makePlay:()=>{counters.playCalls++;throw new Error('Play must not start');},
  });
  return { worker, counters };
};
const request = (url=WALLET, opts={}) => new Request(url,opts);

test('M10 read endpoint appears at intended exact path, but remains locked',async()=>{
  const {worker,counters}=fixture();
  const r=await worker(request(),env());
  assert.equal(r.status,503);
  assert.deepEqual(await r.json(),{error:'paid_wallet_read_disabled'});
  assert.equal(counters.verified,0);
  assert.equal(counters.walletReads,0);
});
test('M10 read gate does not accept JS boolean true or uppercase TRUE',async()=>{
  const {worker}=fixture();
  assert.equal((await worker(request(),env(true))).status,503);
  assert.equal((await worker(request(),env('TRUE'))).status,503);
});
test('M10 purchase authorization independently stays locked',async()=>{
  const {worker,counters}=fixture();
  const r=await worker(request(`${HOST}/v1/iap/authorize`,{method:'POST',headers:{'content-type':'application/json'},body:'{}'}),env('true'));
  assert.equal(r.status,503);
  assert.deepEqual(await r.json(),{error:'purchase_backend_disabled'});
  assert.equal(counters.verified,0);
  assert.equal(counters.ledgerWrites,0);
  assert.equal(counters.playCalls,0);
});
test('M10 route only GET, no accidental POST mutation',async()=>{
  const {worker,counters}=fixture();
  const r=await worker(request(WALLET,{method:'POST',body:'{}'}),env('true'));
  assert.equal(r.status,405);
  assert.equal(counters.verified,0);
});
test('M10 query is rejected, including caller claimed UID',async()=>{
  const {worker,counters}=fixture();
  const r=await worker(request(WALLET+'?uid=another'),env('true'));
  assert.equal(r.status,400);
  assert.equal(counters.verified,0);
});
test('M10 content-length rejected even if empty',async()=>{
  const {worker,counters}=fixture();
  const r=await worker(request(WALLET,{headers:{'content-length':'0'}}),env('true'));
  assert.equal(r.status,400);
  assert.equal(counters.verified,0);
});
test('M10 refuses missing D1 and does not verify tokens',async()=>{
  const {worker,counters}=fixture();
  const r=await worker(request(),{...env('true'),DB:null});
  assert.equal(r.status,503);
  assert.equal(counters.verified,0);
});
test('M10 gate true still requires valid Firebase Auth and App Check',async()=>{
  const {worker}=fixture({verifyIdentity:async()=>{throw new InvalidIdentity()}});
  const r=await worker(request(),env('true'));
  assert.equal(r.status,401);
  assert.deepEqual(await r.json(),{error:'unauthenticated'});
});
test('M10 successful read uses only verified UID and returns private no-store data',async()=>{
  const {worker,counters}=fixture({verifyIdentity:async()=>{counters.verified++;return id('player_B')}});
  const r=await worker(request(WALLET,{headers:{'x-user-id':'player_A'}}),env('true'));
  assert.equal(r.status,200);
  const body=await r.json();
  assert.equal(body.paid_wallet.balance,500);
  assert.equal(body.paid_wallet.authority,'server');
  assert.equal(counters.owner,'player_B');
  assert.equal(counters.walletReads,1);
  assert.equal(counters.ledgerWrites,0);
  assert.equal(counters.playCalls,0);
  assert.equal(r.headers.get('cache-control'),'no-store, private');
});
test('M10 read never credits or debits account',async()=>{
  const {worker}=fixture({makeWallet:()=>({
    getSnapshot:async()=>({wallet_contract_version:1,balance:70,revision:3}),
    creditVerifiedPurchase:()=>{throw new Error('unauthorized credit');},
    debitServerAuthorizedSummon:()=>{throw new Error('unauthorized debit');},
  })});
  const r=await worker(request(),env('true'));
  assert.equal(r.status,200);
});
test('M10 SQL failures are sanitized, never leaked',async()=>{
  const {worker}=fixture({makeWallet:()=>({getSnapshot:async()=>{throw new Error('SQL secrets 123');}})});
  const r=await worker(request(),env('true'));
  assert.equal(r.status,503);
  assert.ok(!(await r.text()).includes('SQL secrets 123'));
});
test('M10 invalid stored balance rejected',async()=>{
  const {worker}=fixture({makeWallet:()=>({getSnapshot:async()=>({wallet_contract_version:1,balance:-1,revision:0})})});
  assert.equal((await worker(request(),env('true'))).status,503);
});
test('M10 path prefix cannot access account wallet',async()=>{
  const {worker,counters}=fixture();
  const r=await worker(request(WALLET+'/oops'),env('true'));
  assert.equal(r.status,404);
  assert.equal(counters.walletReads,0);
});
test('M10 preexisting health endpoint unchanged',async()=>{
  const {worker}=fixture();
  const r=await worker(request(`${HOST}/health`),env());
  assert.equal(r.status,200);
  assert.deepEqual(await r.json(),{service:'jade-iap',activation:'locked'});
});
