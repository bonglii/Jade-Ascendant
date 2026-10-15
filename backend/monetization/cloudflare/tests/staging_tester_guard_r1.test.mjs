import {test} from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {createStagingTesterGuardR1} from '../src/staging_tester_guard_r1.mjs';
globalThis.crypto??=webcrypto;
const request=()=>new Request('https://jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev/v1/wallet');
const digest=async(uid)=>Buffer.from(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(uid))).toString('hex');
test('recovery config enables only tester read/repair, keeps paid spending locked',()=>{
 const cfg=readFileSync(new URL('../wrangler.wallet-recovery.toml',import.meta.url),'utf8');
 for(const flag of ['JADE_PAID_WALLET_READ_ENABLED','JADE_VERIFIED_PURCHASE_REPAIR_ENABLED','JADE_STAGING_ACCOUNT_GUARD']) assert.ok(cfg.includes(`${flag} = "true"`));
 for(const flag of ['JADE_PAID_SUMMON_WRITE_ENABLED','JADE_PAID_LOADOUT_WRITE_ENABLED','JADE_REFUND_RECONCILIATION_READY']) assert.ok(cfg.includes(`${flag} = "false"`));
 assert.ok(cfg.includes('"nodejs_compat"'));
});
test('wrong verified account blocked before worker, correct verified account accepted',async()=>{
 let uid='wrong-owner';let calls=0;
 const guard=createStagingTesterGuardR1({verifyIdentity:async()=>({auth:{uid}}),baseFetch:async()=>{calls++;return new Response('ok');}});
 const env={DB:{},JADE_STAGING_ACCOUNT_GUARD:'true',JADE_PAID_WALLET_READ_ENABLED:'true',JADE_STAGING_TESTER_UID_SHA256:await digest('right-owner')};
 assert.equal((await guard(request(),env,{})).status,403);assert.equal(calls,0);
 uid='right-owner';assert.equal((await guard(request(),env,{})).status,200);assert.equal(calls,1);
});
test('missing tester secret fails closed and unverified identity rejected',async()=>{
 const guard=createStagingTesterGuardR1({verifyIdentity:async()=>{throw Error('fixture');},baseFetch:async()=>{throw Error('must not run');}});
 const env={DB:{},JADE_STAGING_ACCOUNT_GUARD:'true',JADE_PAID_WALLET_READ_ENABLED:'true'};
 assert.equal((await guard(request(),env,{})).status,503);
 env.JADE_STAGING_TESTER_UID_SHA256=await digest('right-owner');assert.equal((await guard(request(),env,{})).status,401);
});
test('optional second tester preserves first tester, excludes everyone else and rejects malformed configuration',async()=>{
 let uid='first-google-player';let calls=0;
 const guard=createStagingTesterGuardR1({verifyIdentity:async()=>({auth:{uid}}),baseFetch:async()=>{calls++;return new Response('ok');}});
 const env={DB:{},JADE_STAGING_ACCOUNT_GUARD:'true',JADE_PAID_GAMEPLAY_V2_ENABLED:'true',
  JADE_STAGING_TESTER_UID_SHA256:await digest(uid)};
 assert.equal((await guard(request(),env,{})).status,200);
 uid='second-google-player';assert.equal((await guard(request(),env,{})).status,403);
 env.JADE_STAGING_SECOND_TESTER_UID_SHA256=await digest(uid);
 assert.equal((await guard(request(),env,{})).status,200);
 uid='first-google-player';assert.equal((await guard(request(),env,{})).status,200);
 uid='outsider-google-player';assert.equal((await guard(request(),env,{})).status,403);
 for(const bad of ['',null,'*','short','A'.repeat(64),['x']]) {
  env.JADE_STAGING_SECOND_TESTER_UID_SHA256=bad;
  assert.equal((await guard(request(),env,{})).status,503);
 }
 assert.equal(calls,3);
});
