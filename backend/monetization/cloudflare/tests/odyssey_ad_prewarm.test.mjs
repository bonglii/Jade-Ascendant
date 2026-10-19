import test from 'node:test';import assert from 'node:assert/strict';import {generateKeyPairSync} from 'node:crypto';
test('initial authenticated event read warms keys off the response path; ad tap reuses the verified cache',async()=>{
 const originalFetch=globalThis.fetch,originalNow=Date.now;let calls=0,release;
 const key=generateKeyPairSync('ec',{namedCurve:'prime256v1'}),gate=new Promise(resolve=>release=resolve);
 globalThis.fetch=async function(url,options){assert.equal(this,globalThis);assert.equal(url,'https://www.gstatic.com/admob/reward/verifier-keys.json');assert.equal(options.redirect,'manual');calls++;await gate;return new Response(JSON.stringify({keys:[{keyId:1,pem:key.publicKey.export({type:'spki',format:'pem'})}]}));};
 try{
  const {fixture,event,time}=await import('./odyssey_flow_fixture.mjs'),{odysseyRoute}=await import('../src/odyssey_http.mjs');Date.now=()=>time*1000;
  const f=fixture();f.raw.prepare('UPDATE odyssey_events SET document=?').run(JSON.stringify({...event,ads_enabled:true}));const pending=[],ctx={waitUntil:p=>pending.push(p)},env={DB:f.db,ODYSSEY_AD_UNIT:'ca-app-pub-3082528078187093/8339864838',ODYSSEY_AD_REWARD_ITEM:'Dice'};
  const denied=await odysseyRoute(new Request('https://worker.test/v4/odyssey'),env,ctx,null);assert.equal(denied.status,401);assert.equal(calls,0);
  const read=await odysseyRoute(new Request('https://worker.test/v4/odyssey'),env,ctx,'alice');assert.equal(read.status,200);assert.equal(calls,1,'Warm fetch has started, but the unresolved key response did not block event GET');const data=await read.json();assert.ok(data.state.ad_delivery);release();await Promise.all(pending);
  const post=await odysseyRoute(new Request('https://worker.test/v4/odyssey',{method:'POST',body:JSON.stringify({event_id:event.id,request_id:'6'.repeat(32),revision:data.revision,action:{kind:'ad_intent'}})}),env,undefined,'alice');assert.equal(post.status,200);assert.equal(calls,1,'Ad preflight must reuse trusted warm keys');assert.ok((await post.json()).ad_intent.nonce);
 }finally{release?.();globalThis.fetch=originalFetch;Date.now=originalNow;}
});
