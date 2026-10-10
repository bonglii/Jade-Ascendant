import test from 'node:test';
import assert from 'node:assert/strict';
import { createPaidWalletReadHandlerM8 } from '../src/paid_wallet_read_route_m8.mjs';
import { InvalidIdentity } from '../src/jwt_verify.mjs';
const BASE = 'https://jade-ascendant-iap.example.workers.dev/v1/wallet/paid';
const identity = uid => ({auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}}, app:{appId:'1:350718070767:android:e5520012a501d2856cf01a'}});
const en = { JADE_PAID_WALLET_READ_ENABLED:'true', JADE_IAP_BACKEND_ENABLED:'false', DB: {} };
const mk = ({ verify = async() => identity('ownerA'), getSnapshot = async uid => ({wallet_contract_version:1,balance:uid==='ownerA'?1200:0,revision:1}), makeWallet } = {}) => {
  const calls=[];
  const handler = createPaidWalletReadHandlerM8({
    verifyIdentity: async(h,e)=>{calls.push('verify');return verify(h,e)},
    makeWallet: makeWallet ?? (() => {calls.push('wallet');return {getSnapshot: async uid=>{calls.push('read:'+uid); return getSnapshot(uid)}}}),
  });
  return { handler, calls };
};
const get = (url=BASE,opts={}) => new Request(url,opts);
const json = async r => {const j=await r.json();return j};
test('not exposed on unrelated paths', async()=>{const {handler,calls}=mk();const r=await handler(get(BASE+'/x'),en);assert.equal(r.status,404);assert.equal(calls.length,0)});
test('only GET permitted',async()=>{const {handler,calls}=mk();const r=await handler(get(BASE,{method:'POST',body:'{}'}),en);assert.equal(r.status,405);assert.equal(calls.length,0)});
test('query parameters forbidden, including caller-controlled uid',async()=>{const {handler,calls}=mk();const r=await handler(get(BASE+'?uid=ownerB'),en);assert.equal(r.status,400);assert.equal(calls.length,0)});
test('request body forbidden',async()=>{const {handler,calls}=mk();assert.throws(()=>get(BASE,{method:'GET',body:'{}'}),TypeError);assert.equal(calls.length,0)});
test('content-length forbidden',async()=>{const {handler,calls}=mk();const r=await handler(get(BASE,{headers:{'content-length':'0'}}),en);assert.equal(r.status,400);assert.equal(calls.length,0)});
test('read gate missing always 503 before auth',async()=>{const {handler,calls}=mk();const r=await handler(get(),{...en,JADE_PAID_WALLET_READ_ENABLED:undefined});assert.equal(r.status,503);assert.deepEqual(await json(r),{error:'paid_wallet_read_disabled'});assert.equal(calls.length,0)});
test('purchase flag does not activate read route',async()=>{const {handler,calls}=mk();const r=await handler(get(),{...en,JADE_PAID_WALLET_READ_ENABLED:'false',JADE_IAP_BACKEND_ENABLED:'true'});assert.equal(r.status,503);assert.equal(calls.length,0)});
test('read gate string must be exactly true',async()=>{const {handler}=mk();assert.equal((await handler(get(),{...en,JADE_PAID_WALLET_READ_ENABLED:true})).status,503)});
test('no D1 returns sanitized 503',async()=>{const {handler,calls}=mk();const r=await handler(get(),{...en,DB:null});assert.equal(r.status,503);assert.equal(calls.length,0)});
test('invalid Firebase Auth or App Check fails closed',async()=>{const {handler,calls}=mk({verify:async()=>{throw new InvalidIdentity()}});const r=await handler(get(),en);assert.equal(r.status,401);assert.deepEqual(calls,['verify'])});
test('validated UID determines wallet, not an optional client header',async()=>{const {handler,calls}=mk({verify:async()=>identity('ownerB')});const r=await handler(get(BASE,{headers:{'x-uid':'ownerA'}}),en);const body=await json(r);assert.equal(r.status,200);assert.equal(body.paid_wallet.balance,0);assert.deepEqual(calls,['verify','wallet','read:ownerB'])});
test('successful snapshot does not change wallet and is private no-store',async()=>{const {handler}=mk();const r=await handler(get(),en);const body=await json(r);assert.equal(r.status,200);assert.equal(body.paid_wallet.balance,1200);assert.equal(body.paid_wallet.authority,'server');assert.equal(body.legacy_wallet_migration,'requires_explicit_reconciliation');assert.equal(r.headers.get('cache-control'),'no-store, private');assert.match(r.headers.get('vary'),/Authorization/)});
test('unsupported authentication provider rejected after verified headers',async()=>{const x=identity('ownerA');x.auth.token.firebase.sign_in_provider='custom';const {handler}=mk({verify:async()=>x});const r=await handler(get(),en);assert.equal(r.status,401)});
test('wallet read errors sanitized',async()=>{const {handler}=mk({getSnapshot:async()=>{throw new Error('DB_SECRET_PASSWORD')}});const r=await handler(get(),en);assert.equal(r.status,503);assert.ok(!JSON.stringify(await json(r)).includes('DB_SECRET_PASSWORD'))});
test('invalid wallet snapshot fails closed',async()=>{const {handler}=mk({getSnapshot:async()=>({wallet_contract_version:1,balance:-100,revision:0})});const r=await handler(get(),en);assert.equal(r.status,503)});
test('route never performs credit/debit',async()=>{let debit=0;const {handler}=mk({makeWallet:()=>({getSnapshot:async()=>({wallet_contract_version:1,balance:9,revision:2}),creditVerifiedPurchase:()=>{debit++},debitServerAuthorizedSummon:()=>{debit++}})});assert.equal((await handler(get(),en)).status,200);assert.equal(debit,0)});
