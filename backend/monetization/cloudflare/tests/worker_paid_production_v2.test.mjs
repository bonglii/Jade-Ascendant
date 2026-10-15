import test from 'node:test';
import assert from 'node:assert/strict';
import {createProductionWorkerV2,PRODUCTION_GATES_V2} from '../src/worker_paid_production_v2.mjs';
const host='https://jade-ascendant-iap.jade-ascendant-studio.workers.dev';
const env=Object.fromEntries(PRODUCTION_GATES_V2.map(k=>[k,'true']));
const id=provider=>({auth:{uid:'uid',token:{firebase:{sign_in_provider:provider}}},app:{appId:'android-jade'}});
test('production requires every gate before auth or side effects',async()=>{
 let called=0;const w=createProductionWorkerV2({verifyIdentity(){called++;return id('google.com');},base:{fetch(){called++;return new Response('{}');}}});
 for(const gate of PRODUCTION_GATES_V2){assert.equal((await w.fetch(new Request(host+'/v1/iap/authorize-v2'),{...env,[gate]:'false'})).status,503);}
 assert.equal(called,0);
 assert.equal((await w.fetch(new Request(host+'/health'),env)).status,200);assert.equal(called,0);
});
test('production refuses staging hosts, staging guard and anonymous purchases',async()=>{
 const w=createProductionWorkerV2({verifyIdentity:()=>id('anonymous'),base:{fetch(){throw Error('must not reach');}}});
 assert.equal((await w.fetch(new Request('https://example.com/v1/iap/authorize-v2'),env)).status,421);
 assert.equal((await w.fetch(new Request(host+'/v1/iap/authorize-v2'),{...env,JADE_STAGING_ACCOUNT_GUARD:'true'})).status,503);
 assert.equal((await w.fetch(new Request(host+'/v1/iap/authorize-v2'),env)).status,401);
});
test('production allows recoverable Google players without tester allowlist, rejects old writers',async()=>{
 let called=0;const w=createProductionWorkerV2({verifyIdentity:()=>id('google.com'),base:{fetch(){called++;return new Response('{}');}}});
 assert.equal((await w.fetch(new Request(host+'/v1/wallet/gameplay-v2'),env)).status,200);assert.equal(called,1);
 assert.equal((await w.fetch(new Request(host+'/v1/wallet/summon'),env)).status,410);assert.equal(called,1);
});
test('RTDN bypasses player verification only to delegate its separate verifier',async()=>{
 let called=0;const w=createProductionWorkerV2({verifyIdentity(){throw Error('player auth must not run');},base:{fetch(){called++;return new Response('{}',{status:401});}}});
 assert.equal((await w.fetch(new Request(host+'/v1/rtdn/voids'),env)).status,401);assert.equal(called,1);
});
