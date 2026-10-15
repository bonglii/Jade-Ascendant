import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { createHash, webcrypto } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createD1Wallet } from '../src/d1_wallet.mjs';
import {
  createGooglePlayVoidedPushHandlerRC9,
  verifyGooglePushJwtRC9,
  decodeGooglePlayPushRC9,
  RtdnIngressErrorRC9,
} from '../src/play_rtdn_signed_push_rc9.mjs';

const now=Date.parse('2026-10-10T08:00:00Z');
const sub='projects/jade-ascendant/subscriptions/jade-iap-voided';
const aud='https://example.workers.dev/v1/rtdn/voids';
const email='iap-voided-push@jade-ascendant.iam.gserviceaccount.com';
const token='PlayToken_for_refund_reconciliation_rc9_ABC123';
const uid='firebase-player-777';
const hash=x=>createHash('sha256').update(x).digest('hex');
const enc=new TextEncoder();
const b64=buf=>Buffer.from(buf).toString('base64url');
let publicJwk,privateKey;
async function keys(){
  if(privateKey)return;
  const kp=await webcrypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
  privateKey=kp.privateKey;
  publicJwk={...await webcrypto.subtle.exportKey('jwk',kp.publicKey),kid:'test-google-kid',alg:'RS256',use:'sig'};
}
const fetcher=async (url)=>{assert.equal(url,'https://www.googleapis.com/oauth2/v3/certs');return new Response(JSON.stringify({keys:[publicJwk]}),{headers:{'content-type':'application/json'}});};
const defaults=()=>({iss:'https://accounts.google.com',aud,email,email_verified:true,sub:'service-123',iat:Math.floor(now/1000)-60,exp:Math.floor(now/1000)+2400});
async function jwt(claims={},header={}){
  await keys();
  const a=b64(JSON.stringify({alg:'RS256',typ:'JWT',kid:'test-google-kid',...header}));
  const b=b64(JSON.stringify({...defaults(),...claims}));
  const signature=await webcrypto.subtle.sign('RSASSA-PKCS1-v1_5',privateKey,enc.encode(a+'.'+b));
  return a+'.'+b+'.'+b64(signature);
}
const notice=(overrides={})=>({version:'1.0',packageName:'com.yungdevstudio.jadeascendant',eventTimeMillis:String(now-2000),
  voidedPurchaseNotification:{purchaseToken:token,orderId:'GS.test-order',productType:2,refundType:1},...overrides});
const push=message=>({subscription:sub,message:{messageId:'msg-123',data:Buffer.from(JSON.stringify(message)).toString('base64')}});
const req=(body,auth)=>new Request(aud,{method:'POST',headers:{'content-type':'application/json',Authorization:'Bearer '+auth},body:JSON.stringify(body)});
const env=(db,overrides={})=>({JADE_REFUND_RTDN_PUSH_RC9_ENABLED:'true',JADE_IAP_BACKEND_ENABLED:'true',JADE_RTDN_PUSH_AUDIENCE:aud,JADE_RTDN_PUSH_EMAIL:email,JADE_RTDN_PUSH_SUBSCRIPTION:sub,DB:db,...overrides});
function fixture(hasLedger=true){
 const sqlite=new DatabaseSync(':memory:');sqlite.exec('PRAGMA foreign_keys=ON');
 sqlite.exec(`CREATE TABLE iap_wallet_accounts_v1(owner_key TEXT PRIMARY KEY,balance INTEGER NOT NULL DEFAULT 0 CHECK(balance BETWEEN 0 AND 9007199254740991),revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0));
 CREATE TABLE iap_purchase_ledger_v1(token_key TEXT PRIMARY KEY,record_json TEXT NOT NULL);
 CREATE TABLE iap_wallet_events_v1(event_key TEXT PRIMARY KEY,owner_key TEXT NOT NULL REFERENCES iap_wallet_accounts_v1(owner_key),event_kind TEXT NOT NULL,item_key TEXT NOT NULL,delta INTEGER NOT NULL);`);
 for (const mig of ['0008_refund_account_holds.sql','0009_play_voided_reconciliation.sql'])
   sqlite.exec(readFileSync(new URL('../migrations/'+mig,import.meta.url),'utf8'));
 if(hasLedger) {
   const record={tokenKey:'playtoken:'+hash(token),grantId:'iapv1:'+hash(token),ownerUid:uid,ownerBinding:hash(uid),state:'grant_ready'};
   sqlite.prepare('INSERT INTO iap_purchase_ledger_v1 VALUES (?,?)').run(record.tokenKey,JSON.stringify(record));
 }
 const db={
   prepare(sql) {
     return { bind(...args) {
       return {
         async first() { return sqlite.prepare(sql).get(...args) ?? null; },
         async all() { return {results:sqlite.prepare(sql).all(...args)}; },
         run() { return sqlite.prepare(sql).run(...args); },
       };
     }};
   },
   withSession(mode){assert.equal(mode,'first-primary');return this;},
   async batch(stmts){sqlite.exec('BEGIN IMMEDIATE');try{const r=stmts.map(s=>s.run());sqlite.exec('COMMIT');return r;}catch(e){sqlite.exec('ROLLBACK');throw e;}},
 };
 return {sqlite,db,close:()=>sqlite.close(),holds:()=>sqlite.prepare('SELECT * FROM iap_refund_account_holds_v1').all(),voids:()=>sqlite.prepare('SELECT * FROM iap_play_void_events_v1').all()};
}
function handler(extra={}){return createGooglePlayVoidedPushHandlerRC9({fetcher,subtle:webcrypto.subtle,clock:()=>now,...extra});}

test('accepts signed Google OIDC JWT, exact claims and pinned JWKS',async()=>{
 const value=await jwt();assert.deepEqual(await verifyGooglePushJwtRC9(value,{audience:aud,serviceAccountEmail:email,fetcher,subtle:webcrypto.subtle,nowMs:now}),{verified_service_account:true});
});
test('verified PubSub void is durably fingerprinted and holds matching account',async()=>{
 const f=fixture();try{
  const r=await handler()(req(push(notice()),await jwt()),env(f.db));
  assert.equal(r.status,200);assert.deepEqual(await r.json(),{state:'recorded'});
  assert.equal(f.voids().length,1);assert.equal(f.voids()[0].token_key,'playtoken:'+hash(token));
  assert.equal(f.voids()[0].voided_reason,0);assert.equal(f.voids()[0].owner_key,'u1:'+hash(uid));
  assert.equal(f.holds()[0].status,'held');
  assert.ok(!JSON.stringify(f.voids()).includes(token));assert.ok(!JSON.stringify(f.holds()).includes(uid));
 }finally{f.close();}
});
test('repeated signed refund does not duplicate rows or hold revision',async()=>{
 const f=fixture();try{
  const h=handler(),q=req(push(notice()),await jwt());
  assert.equal((await h(q,env(f.db))).status,200);
  assert.equal((await h(req(push(notice()),await jwt()),env(f.db))).status,200);
  assert.equal(f.holds()[0].revision,1);assert.equal(f.voids().length,1);
 }finally{f.close();}
});
test('void arriving before ledger is retained for attribution rather than credited',async()=>{
 const f=fixture(false);try{
  assert.equal((await handler()(req(push(notice()),await jwt()),env(f.db))).status,200);
  assert.equal(f.voids().length,1);assert.equal(f.voids()[0].owner_key,null);assert.equal(f.holds().length,0);
 }finally{f.close();}
});
test('authenticated non-refund notification is ignored with no DB writes',async()=>{
 const f=fixture();try{
  const event=notice();delete event.voidedPurchaseNotification;
  event.oneTimeProductNotification={version:'1.0',notificationType:1,sku:'jade_pouch_100',purchaseToken:token};
  const r=await handler()(req(push(event),await jwt()),env(f.db));assert.equal(r.status,200);
  assert.equal(f.voids().length,0);
 }finally{f.close();}
});
test('partial refund triggers hold even though exact refund amount is unknown',async()=>{
 const f=fixture();try{
  const event=notice();event.voidedPurchaseNotification.refundType=2;
  assert.equal((await handler()(req(push(event),await jwt()),env(f.db))).status,200);
  assert.equal(f.holds()[0].status,'held');
 }finally{f.close();}
});
test('invalid signer email fails before any DB write',async()=>{
 const f=fixture();try{assert.equal((await handler()(req(push(notice()),await jwt({email:'evil@other.iam.gserviceaccount.com'})),env(f.db))).status,401);assert.equal(f.voids().length,0);}finally{f.close();}
});
test('invalid audience fails before any DB write',async()=>{
 const f=fixture();try{assert.equal((await handler()(req(push(notice()),await jwt({aud:'https://evil.invalid/route'})),env(f.db))).status,401);assert.equal(f.voids().length,0);}finally{f.close();}
});
test('tampered signature fails before any DB write',async()=>{
 const f=fixture();try{const signed=await jwt();const parts=signed.split('.');
  const signature=Buffer.from(parts[2],'base64url');signature[0]^=1;
  const altered=parts.slice(0,2).join('.')+'.'+signature.toString('base64url');
  assert.equal((await handler()(req(push(notice()),altered),env(f.db))).status,401);assert.equal(f.voids().length,0);}finally{f.close();}
});
test('expired JWT is rejected before DB',async()=>{
 const f=fixture();try{assert.equal((await handler()(req(push(notice()),await jwt({exp:Math.floor(now/1000)-1})),env(f.db))).status,401);assert.equal(f.voids().length,0);}finally{f.close();}
});
test('disabled IAP or disabled RTDN gate does not verify or read',async()=>{
 const f=fixture();try{const h=handler({verifier:()=>{throw Error('should not verify');}});
  assert.equal((await h(req(push(notice()),await jwt()),env(f.db,{JADE_IAP_BACKEND_ENABLED:'false'}))).status,503);
  assert.equal((await h(req(push(notice()),await jwt()),env(f.db,{JADE_REFUND_RTDN_PUSH_RC9_ENABLED:'false'}))).status,503);assert.equal(f.voids().length,0);
 }finally{f.close();}
});
test('wrong subscription is rejected without a DB mutation',async()=>{
 const f=fixture();try{const event=push(notice());event.subscription='projects/other/subscriptions/other';
  assert.equal((await handler()(req(event,await jwt()),env(f.db))).status,400);assert.equal(f.voids().length,0);
 }finally{f.close();}
});
test('wrong package is rejected without a DB mutation',async()=>{
 const f=fixture();try{assert.equal((await handler()(req(push(notice({packageName:'com.other.app'})),await jwt()),env(f.db))).status,400);assert.equal(f.voids().length,0);}finally{f.close();}
});
test('subscription void for a different product type is rejected',async()=>{
 const f=fixture();try{const event=notice();event.voidedPurchaseNotification.productType=1;
  assert.equal((await handler()(req(push(event),await jwt()),env(f.db))).status,400);assert.equal(f.voids().length,0);
 }finally{f.close();}
});
test('missing signature fails without D1 calls',async()=>{
 const f=fixture();try{const r=new Request(aud,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(push(notice()))});
  assert.equal((await handler()(r,env(f.db))).status,401);assert.equal(f.voids().length,0);
 }finally{f.close();}
});
test('D1 failure returns retryable 503 and no false acknowledged refund',async()=>{
 const f=fixture();try{const h=handler({record:async()=>{throw Error('D1 down');}});
  assert.equal((await h(req(push(notice()),await jwt()),env(f.db))).status,503);assert.equal(f.voids().length,0);
 }finally{f.close();}
});
test('oversized body is rejected even with valid JWT',async()=>{
 const f=fixture();try{const oversized='x'.repeat(13*1024);
  const r=new Request(aud,{method:'POST',headers:{'content-type':'application/json',Authorization:'Bearer '+await jwt()},body:oversized});
  assert.equal((await handler()(r,env(f.db))).status,400);assert.equal(f.voids().length,0);
 }finally{f.close();}
});
test('JWT key retrieval failure is retryable, never falsely acknowledged',async()=>{
 const f=fixture();try{const h=createGooglePlayVoidedPushHandlerRC9({fetcher:async()=>{throw Error('Google down');},subtle:webcrypto.subtle,clock:()=>now});
  assert.equal((await h(req(push(notice()),await jwt()),env(f.db))).status,503);assert.equal(f.voids().length,0);
 }finally{f.close();}
});
test('invalid pubsub base64 is rejected',()=>{
 assert.throws(()=>decodeGooglePlayPushRC9({subscription:sub,message:{messageId:'123',data:'%%%'}},{subscription:sub,nowMs:now}),RtdnIngressErrorRC9);
});
test('JWT claim cannot bypass service identity by injecting unsigned fields',async()=>{
 const f=fixture();try{assert.equal((await handler()(req(push(notice()),await jwt({email_verified:false})),env(f.db))).status,401);assert.equal(f.voids().length,0);}finally{f.close();}
});

test('FULL FLOW: real patched wallet credits, verified Google RTDN holds, replay is denied',async()=>{
  const f=fixture();try{
    f.sqlite.prepare("INSERT INTO iap_play_void_cursor_v1(cursor_name,watermark_ms) VALUES ('voided_inapp',?)").run(now-10_000);
    // Clock is injected for this test because the staged RTDN is fixed at 2026-10-10.
    // RC8 checks Date.now() so use a temporary current watermark for the wallet.
    f.sqlite.prepare("UPDATE iap_play_void_cursor_v1 SET watermark_ms=? WHERE cursor_name='voided_inapp'").run(Date.now()-10_000);
    const wallet=createD1Wallet(f.db);
    const grant={purchase_contract_version:1,state:'grant_ready',grant_id:'iapv1:'+hash(token),internal_product_id:'jade_pouch_100',celestial_jade:100};
    assert.equal((await wallet.creditVerifiedPurchase(uid,grant)).balance,100);
    const receipt=await handler()(req(push(notice()),await jwt()),env(f.db));
    assert.equal(receipt.status,200);
    assert.equal(f.holds().length,1);
    await assert.rejects(wallet.creditVerifiedPurchase(uid,grant),{name:'RefundCreditGateErrorRC8',code:'refund_or_hold'});
    assert.equal(f.sqlite.prepare('SELECT balance FROM iap_wallet_accounts_v1').get().balance,100);
    assert.equal(f.sqlite.prepare('SELECT COUNT(*) AS n FROM iap_wallet_events_v1').get().n,1);
  }finally{f.close();}
});
test('FULL FLOW: signed refund before credited wallet blocks new credits',async()=>{
  const f=fixture();try{
    f.sqlite.prepare("INSERT INTO iap_play_void_cursor_v1(cursor_name,watermark_ms) VALUES ('voided_inapp',?)").run(Date.now()-10_000);
    const receipt=await handler()(req(push(notice()),await jwt()),env(f.db));assert.equal(receipt.status,200);
    const wallet=createD1Wallet(f.db);
    const grant={purchase_contract_version:1,state:'grant_ready',grant_id:'iapv1:'+hash(token),internal_product_id:'jade_pouch_100',celestial_jade:100};
    await assert.rejects(wallet.creditVerifiedPurchase(uid,grant),{name:'RefundCreditGateErrorRC8',code:'refund_or_hold'});
    assert.equal(f.sqlite.prepare('SELECT COUNT(*) AS n FROM iap_wallet_events_v1').get().n,0);
  }finally{f.close();}
});
