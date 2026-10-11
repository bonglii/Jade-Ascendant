import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { canonicalDefaultRC12, ensureCanonicalAccountAfterVerifiedCreditRC12, CanonicalOnboardingErrorRC12 } from '../src/canonical_onboarding_rc12.mjs';
import { createPaidCreditOnboardingGateRC12 } from '../src/paid_credit_onboarding_gate_rc12.mjs';
const UID='play_test_user_987';
const owner='u1:'+createHash('sha256').update(UID).digest('hex');
const migrations=[
`CREATE TABLE iap_wallet_accounts_v1 (owner_key TEXT PRIMARY KEY NOT NULL CHECK(length(owner_key)=67 AND substr(owner_key,1,3)='u1:'), balance INTEGER NOT NULL DEFAULT 0 CHECK(balance BETWEEN 0 AND 9007199254740991), revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0));`,
`CREATE TABLE iap_summon_canonical_v1 (owner_key TEXT PRIMARY KEY NOT NULL REFERENCES iap_wallet_accounts_v1(owner_key), revision INTEGER NOT NULL DEFAULT 0 CHECK(revision BETWEEN 0 AND 9007199254740990), status TEXT NOT NULL CHECK(status IN ('unprovisioned','verified')), state_json TEXT NOT NULL CHECK(json_valid(state_json) AND length(state_json) BETWEEN 20 AND 65536), updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);`,
];
class DB {
 constructor(){this.sql=new DatabaseSync(':memory:');this.sql.exec('PRAGMA foreign_keys=ON');for(const sql of migrations)this.sql.exec(sql);}
 withSession(mode){assert.equal(mode,'first-primary');return this;}
 prepare(sql){return {bind:(...values)=>({run:async()=>this.sql.prepare(sql).run(...values),first:async()=>this.sql.prepare(sql).get(...values)??null})};}
 addWallet(){this.sql.prepare('INSERT INTO iap_wallet_accounts_v1 (owner_key) VALUES (?)').run(owner);}
 get(){return this.sql.prepare('SELECT revision,status,state_json FROM iap_summon_canonical_v1').get();}
 close(){this.sql.close();}
}
const onboard=(db,uid=UID)=>ensureCanonicalAccountAfterVerifiedCreditRC12({db,verifiedUid:uid});
const request=()=>new Request('https://example.test/v1/iap/authorize-v2',{method:'POST',headers:{Authorization:'Bearer signed-example'}});
const env=db=>({DB:db,JADE_IAP_BACKEND_ENABLED:'true',JADE_PAID_WALLET_CREDIT_V2_ENABLED:'true',JADE_CANONICAL_ONBOARDING_RC12_ENABLED:'true'});
test('never creates canonical state unless a wallet account already exists',async()=>{
 const db=new DB();await assert.rejects(onboard(db),CanonicalOnboardingErrorRC12);assert.equal(db.get(),undefined);db.close();
});
test('new verified wallet owner gets empty, locked, SERVER-only summon state',async()=>{
 const db=new DB();db.addWallet();assert.deepEqual(await onboard(db),{ready:true});
 const row=db.get();assert.equal(row.status,'verified');assert.equal(row.revision,0);
 assert.deepEqual(JSON.parse(row.state_json),canonicalDefaultRC12());
 assert.equal(JSON.parse(row.state_json).cleared_stage_keys.includes('1-5'),false);db.close();
});
test('replay cannot replace items, pity, stage clears or revision',async()=>{
 const db=new DB();db.addWallet();await onboard(db);
 const state=canonicalDefaultRC12();state.inventory={jade_sword:1};state.cleared_stage_keys=['1-1'];state.lifetime_pulls=15;
 db.sql.prepare('UPDATE iap_summon_canonical_v1 SET revision=9,state_json=?').run(JSON.stringify(state));
 await onboard(db);assert.equal(db.get().revision,9);assert.deepEqual(JSON.parse(db.get().state_json),state);db.close();
});
test('unprovisioned existing row is never overwritten',async()=>{
 const db=new DB();db.addWallet();db.sql.prepare("INSERT INTO iap_summon_canonical_v1(owner_key,status,state_json) VALUES (?,'unprovisioned',?)").run(owner,JSON.stringify(canonicalDefaultRC12()));
 await assert.rejects(onboard(db),e=>e.code==='canonical_onboarding_not_ready');assert.equal(db.get().status,'unprovisioned');db.close();
});
test('invalid user identifiers never reach SQL',async()=>{
 const db=new DB();db.addWallet();for(const uid of ['a/b','','🥺','a'.repeat(129)])await assert.rejects(onboard(db,uid),e=>e.code==='invalid_trusted_uid');assert.equal(db.get(),undefined);db.close();
});
test('locked gate refuses credit before touching Auth/Play/DB',async()=>{
 const db=new DB();let calls=0;const wrapped=createPaidCreditOnboardingGateRC12({baseFetch:async()=>{calls++;return new Response('ok',{status:200})},verifyIdentity:async()=>{calls++;return {auth:{uid:UID}}}});
 for(const key of ['JADE_IAP_BACKEND_ENABLED','JADE_PAID_WALLET_CREDIT_V2_ENABLED','JADE_CANONICAL_ONBOARDING_RC12_ENABLED']){
 const locked={...env(db),[key]:'false'};const res=await wrapped(request(),locked);assert.equal(res.status,503);
 }
 assert.equal(calls,0);db.close();
});
test('upstream purchase rejection never initializes an account',async()=>{
 const db=new DB();db.addWallet();let calls=0;
 const wrapped=createPaidCreditOnboardingGateRC12({baseFetch:async()=>{calls++;return new Response('no',{status:409})},verifyIdentity:async()=>({auth:{uid:UID}})});
 assert.equal((await wrapped(request(),env(db))).status,409);assert.equal(calls,1);assert.equal(db.get(),undefined);db.close();
});
test('purchase success initializes canonical state before returning success',async()=>{
 const db=new DB();db.addWallet();const wrapped=createPaidCreditOnboardingGateRC12({baseFetch:async()=>new Response('{"state":"server_wallet_credited"}',{status:200}),verifyIdentity:async()=>({auth:{uid:UID}})});
 const result=await wrapped(request(),env(db));assert.equal(result.status,200);assert.equal(db.get().status,'verified');db.close();
});
test('crash after wallet credit -> onboarding 503, replay same purchase repairs without minting credit',async()=>{
 const db=new DB();let walletCredits=0;let upstreamCalls=0;
 const wrapped=createPaidCreditOnboardingGateRC12({baseFetch:async()=>{upstreamCalls++;if(walletCredits===0)walletCredits++;return new Response('{}',{status:200})},verifyIdentity:async()=>({auth:{uid:UID}})});
 assert.equal((await wrapped(request(),env(db))).status,503);assert.equal(walletCredits,1);
 db.addWallet();assert.equal((await wrapped(request(),env(db))).status,200);assert.equal(walletCredits,1);assert.equal(upstreamCalls,2);
 db.close();
});
test('invalid or missing signed identity denies purchase',async()=>{
 const db=new DB();let calls=0;
 const wrapped=createPaidCreditOnboardingGateRC12({baseFetch:async()=>{calls++;return new Response('{}',{status:200})},verifyIdentity:async()=>{throw Error('JWT invalid')}});
 assert.equal((await wrapped(request(),env(db))).status,401);assert.equal(calls,0);db.close();
});
test('non-purchase requests pass through untouched',async()=>{
 let calls=0;const wrapped=createPaidCreditOnboardingGateRC12({baseFetch:async()=>{calls++;return new Response('normal',{status:200})},verifyIdentity:async()=>{throw Error('must not run')}});
 const result=await wrapped(new Request('https://example.test/health'),{});assert.equal(result.status,200);assert.equal(calls,1);
});
