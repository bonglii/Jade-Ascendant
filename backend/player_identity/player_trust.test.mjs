import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHandler} from './worker.mjs';
import {trustPages} from './public_trust_pages.mjs';
const policy=JSON.parse(readFileSync(new URL('../../release/player_trust_policy.json',import.meta.url),'utf8'));
test('public policy/deletion work without auth, app installation or DB and do not run scripts/trackers',async()=>{
 const handler=createHandler({verify:()=>{throw Error('must not authenticate public pages');}});
 for(const path of Object.keys(trustPages)){
  const r=await handler(new Request('https://player.test'+path),{});assert.equal(r.status,200);assert.match(r.headers.get('content-type'),/text\/html/);
  assert.match(r.headers.get('content-security-policy'),/default-src 'none'/);assert(!/<script|<iframe|<form|<img/i.test(await r.text()));
  assert.equal((await handler(new Request('https://player.test'+path,{method:'POST'}),{})).status,405);
  assert.equal(await(await handler(new Request('https://player.test'+path,{method:'HEAD'}),{})).text(),'');
 }
});
test('generated pages stay identical to published docs/release copies and explain actual backup/payment/request retention',()=>{
 for(const [path,html] of Object.entries(trustPages))for(const folder of ['docs','release'])assert.equal(readFileSync(new URL('../../'+folder+path,import.meta.url),'utf8'),html);
 assert.equal(policy.sections.length,8);assert.equal(policy.deletion_method,'verified_support_request');assert.equal(policy.response_target_days,30);
 const page=trustPages['/account-deletion.html'];assert.match(page,/mailto:yungdevstudio@gmail.com\?subject=/);assert.match(page,/not required/);assert.match(page,/does not submit a request/);assert.match(page,/without installing/);assert.match(page,/30 days/);assert.match(page,/financial|wallet/);assert(!page.includes('Firebase UID:'));
 const privacy=trustPages['/privacy-policy.html'];assert.match(privacy,/nine permanent/);assert.match(privacy,/Cloudflare/);assert.match(privacy,/signed AdMob server-side verification/);assert.match(privacy,/Firebase Cloud Messaging/);assert.match(privacy,/not keep a per-player list of FCM/);assert(!privacy.includes('Production Cloud Save is not currently available'));
});
