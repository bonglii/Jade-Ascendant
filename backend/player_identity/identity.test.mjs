import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {generateKeyPairSync,sign} from 'node:crypto';
import {createHandler,registerIdentity,ownerBinding,verifyAuth} from './worker.mjs';
import {InvalidIdentity} from '../monetization/cloudflare/src/jwt_verify.mjs';
import {ProfileAuthRejected,ProfileAuthUnavailable} from './auth.mjs';

function database(){
  const sql=new DatabaseSync(':memory:');
  sql.exec(readFileSync(new URL('./schema.sql',import.meta.url),'utf8'));
  return {sql,withSession(mode){assert.equal(mode,'first-primary');return this;},prepare(query){return {bind(...args){return {
    async first(){return sql.prepare(query).get(...args)||null;},
    async run(){return sql.prepare(query).run(...args);}
  };}};}};
}
const code=n=>'JA'+n.toString(32).toUpperCase().padStart(10,'0').replaceAll('I','Z').replaceAll('L','Y').replaceAll('O','X').replaceAll('U','W');
const request=(body='{}',method='POST')=>new Request('https://player.example/v1/player/register',{method,headers:{'content-type':'application/json'},body:method==='POST'?body:undefined});

test('same authenticated owner always receives same UID, with no name/reward storage',async()=>{
  const db=database(),owner=await ownerBinding('user1');
  const first=await registerIdentity(db,owner);
  const second=await registerIdentity(db,owner);
  assert.deepEqual(second,first);assert.match(first.public_uid,/^JA[A-Z0-9]{10}$/);
  assert.equal(db.sql.prepare('SELECT count(*) AS n FROM player_identities').get().n,1);
  db.sql.close();
});
test('public UID collision retries under real SQLite uniqueness constraints',async()=>{
  const db=database();const a=await ownerBinding('a'),b=await ownerBinding('b');
  await registerIdentity(db,a,{generate:()=>code(1)});
  let count=0;const output=await registerIdentity(db,b,{generate:()=>code(++count)});
  assert.equal(output.public_uid,code(2));assert.equal(count,2);db.sql.close();
});
test('concurrent same-owner registrations converge, different owners stay unique',async()=>{
  const db=database();let counter=100;
  const owner=await ownerBinding('race');
  const raced=await Promise.all(Array.from({length:50},()=>registerIdentity(db,owner,{generate:()=>code(++counter)})));
  assert.equal(new Set(raced.map(r=>r.public_uid)).size,1);
  const owners=await Promise.all(Array.from({length:100},(_,i)=>ownerBinding('user'+i)));
  const separate=await Promise.all(owners.map(owner=>registerIdentity(db,owner,{generate:()=>code(++counter)})));
  assert.equal(new Set(separate.map(r=>r.public_uid)).size,100);
  assert.equal(db.sql.prepare('SELECT count(*) AS n FROM player_identities').get().n,101);db.sql.close();
});
test('allocation exhaustion is bounded and never reassigns another player UID',async()=>{
  const db=database();await registerIdentity(db,await ownerBinding('owner'),{generate:()=>code(7)});
  await assert.rejects(registerIdentity(db,await ownerBinding('other'),{generate:()=>code(7)}),/exhausted/);
  assert.equal(db.sql.prepare('SELECT count(*) AS n FROM player_identities').get().n,1);db.sql.close();
});
test('route rejects owner/UID/name inputs, oversized bodies and wrong methods',async()=>{
  let calls=0;const handler=createHandler({verify:async()=>{calls++;return 'user';}});
  for(const body of ['{"owner":"other"}','{"public_uid":"JA0000000000"}','{"name":"Kim"}','[]','null','{',' '.repeat(40)+'{}']) {
    assert.equal((await handler(request(body),{})).status,400);
  }
  assert.equal((await handler(request(undefined,'GET'),{})).status,405);assert.equal(calls,0);
});
test('unauthenticated requests never reach database and DB errors do not leak',async()=>{
  const denied=createHandler({verify:async()=>{throw new InvalidIdentity();},register:async()=>{throw Error('DB must not run');}});
  assert.equal((await denied(request(),{PROFILE_DB:{}})).status,401);
  const failed=createHandler({verify:async()=> 'user',register:async()=>{throw Error('secret database diagnostic');}});
  const response=await failed(request(),{PROFILE_DB:{}});assert.equal(response.status,503);
  assert.deepEqual(await response.json(),{error:'service_unavailable'});
});
test('route binding derives exclusively from authenticated owner; response never exposes raw UID',async()=>{
  const db=database(),handler=createHandler({verify:async()=> 'verified-owner'});
  const response=await handler(request(),{PROFILE_DB:db});assert.equal(response.status,200);
  const data=await response.json();assert.equal(data.owner_binding,await ownerBinding('verified-owner'));
  assert.equal(data.version,1);assert.equal(JSON.stringify(data).includes('verified-owner'),false);
  db.sql.close();
});
const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});
const jwk={...publicKey.export({format:'jwk'}),kid:'player-qa-key',alg:'RS256',use:'sig'};
const fetcher=async()=>new Response(JSON.stringify({keys:[jwk]}));
const now=Math.floor(Date.now()/1000);
const claims={iss:'https://securetoken.google.com/jade-ascendant',aud:'jade-ascendant',sub:'firebase-user',iat:now-10,exp:now+600,auth_time:now-10,firebase:{sign_in_provider:'google.com'}};
function jwt(payload){const body=[{alg:'RS256',kid:jwk.kid},payload].map(x=>Buffer.from(JSON.stringify(x)).toString('base64url')).join('.');return body+'.'+sign('RSA-SHA256',Buffer.from(body),privateKey).toString('base64url');}
const signed=payload=>new Request('https://player.example',{headers:{authorization:'Bearer '+jwt(payload)}});
test('real RSA signature accepts pinned Firebase project and supported providers',async()=>{
  for(const provider of ['google.com','anonymous']) assert.equal(await verifyAuth(signed({...claims,firebase:{sign_in_provider:provider}}),{FIREBASE_PROJECT_ID:'jade-ascendant'},{fetcher}),'firebase-user');
});
test('wrong audience, issuer, expiry, provider, missing token and forged signature fail',async()=>{
  for(const modified of [{aud:'other'},{iss:'https://evil.example'},{exp:now-1},{firebase:{sign_in_provider:'password'}},{auth_time:now+100}]) {
    await assert.rejects(verifyAuth(signed({...claims,...modified}),{FIREBASE_PROJECT_ID:'jade-ascendant'},{fetcher}),InvalidIdentity);
  }
  await assert.rejects(verifyAuth(new Request('https://player.example'),{FIREBASE_PROJECT_ID:'jade-ascendant'},{fetcher}),InvalidIdentity);
  const token=jwt(claims).split('.');const bytes=Buffer.from(token[2],'base64url');bytes[0]^=1;token[2]=bytes.toString('base64url');
  await assert.rejects(verifyAuth(new Request('https://player.example',{headers:{authorization:'Bearer '+token.join('.')}}),{FIREBASE_PROJECT_ID:'jade-ascendant'},{fetcher}),InvalidIdentity);
});

test('rejection stages distinguish Google OAuth token, wrong project and expired Firebase token',async()=>{
  for(const [modified,stage] of [[{iss:'https://accounts.google.com'},'token_issuer'],[{aud:'other-project'},'token_audience'],[{exp:now-1},'token_expired'],[{firebase:{sign_in_provider:'password'}},'token_provider']]) {
    await assert.rejects(verifyAuth(signed({...claims,...modified}),{FIREBASE_PROJECT_ID:'jade-ascendant'},{fetcher}),e=>e instanceof ProfileAuthRejected&&e.stage===stage);
  }
  await assert.rejects(verifyAuth(signed(claims),{FIREBASE_PROJECT_ID:'wrong'}),e=>e.stage==='server_project');
});
test('Google key transport, HTTP and malformed key responses are unavailable, not invalid credentials',async()=>{
  const cases=[['transport',async()=>{throw Error('private diagnostic');}],['http',async()=>new Response('{}',{status:503})],['format',async()=>new Response('{')]];
  for(const [suffix,source] of cases) {
    await assert.rejects(verifyAuth(signed(claims),{FIREBASE_PROJECT_ID:'jade-ascendant'},
      {fetcher:source,jwksUrl:'https://keys-test.example/'+suffix}),e=>e instanceof ProfileAuthUnavailable&&e.stage==='keys_'+suffix);
  }
});
test('unknown signing key remains denied even when the JWKS endpoint is reachable',async()=>{
  await assert.rejects(verifyAuth(signed(claims),{FIREBASE_PROJECT_ID:'jade-ascendant'},
    {jwksUrl:'https://keys-test.example/unknown',fetcher:async()=>new Response(JSON.stringify({keys:[{...jwk,kid:'different'}]}))}),
    e=>e instanceof InvalidIdentity&&e.stage==='token_signing_key');
});
test('server logs only fixed stages and does not allocate on token or key failure',async()=>{
  const logs=[],warn=console.warn;console.warn=value=>logs.push(value);
  try {
    const handler=createHandler({verify:verifyAuth,register:async()=>{assert.fail('rejected auth reached allocation');}});
    const response=await handler(request(),{FIREBASE_PROJECT_ID:'jade-ascendant',PROFILE_DB:{}});
    assert.equal(response.status,401);assert.deepEqual(await response.json(),{error:'unauthenticated'});
    assert.deepEqual(logs,['JADE_PLAYER_AUTH stage=bearer_format']);
    logs.length=0;
    const unavailable=createHandler({verify:async()=>{throw new ProfileAuthUnavailable('keys_transport');},register:async()=>assert.fail('unavailable auth reached allocation')});
    const failed=await unavailable(request(),{PROFILE_DB:{}});
    assert.equal(failed.status,503);assert.deepEqual(await failed.json(),{error:'service_unavailable'});
    assert.deepEqual(logs,['JADE_PLAYER_AUTH stage=keys_transport']);
  } finally { console.warn=warn; }
});

test('profile native fetch retains global receiver and strict Google-key transport options',async()=>{
  const saved=globalThis.fetch;
  globalThis.fetch=async function(url,init){
    assert.equal(this,globalThis);
    assert.equal(url,'https://keys-test.example/native-receiver');
    assert.equal(init.redirect,'manual');assert.ok(init.signal instanceof AbortSignal);
    return new Response(JSON.stringify({keys:[jwk]}));
  };
  try {
    assert.equal(await verifyAuth(signed(claims),{FIREBASE_PROJECT_ID:'jade-ascendant'},
      {jwksUrl:'https://keys-test.example/native-receiver'}),'firebase-user');
  } finally {globalThis.fetch=saved;}
});
test('key timeout, redirect and receiver errors have fixed unavailable stages',async()=>{
  for(const [error,stage] of [[new DOMException('private timeout detail','TimeoutError'),'keys_timeout'],
    [new TypeError('Illegal invocation: private receiver detail'),'keys_invocation'],
    [new TypeError('Redirect encountered: private redirect destination'),'keys_redirect']]) {
    await assert.rejects(verifyAuth(signed(claims),{FIREBASE_PROJECT_ID:'jade-ascendant'},
      {jwksUrl:'https://keys-test.example/'+stage,fetcher:async()=>{throw error;}}),
      e=>e instanceof ProfileAuthUnavailable&&e.stage===stage);
  }
});

test('profile key transport accepts only redirect modes implemented by workerd',async()=>{
  // Guard mirrors Request::tryParseRedirect in Cloudflare's runtime source:
  // error is rejected before network I/O, even for an endpoint returning 200.
  let requests=0;
  const edgeFetch=async(url,init)=>{
    if(!['follow','manual'].includes(init.redirect)) throw new TypeError('Invalid redirect value, must be one of follow or manual');
    requests++;assert.equal(init.redirect,'manual');
    return new Response(JSON.stringify({keys:[jwk]}));
  };
  assert.equal(await verifyAuth(signed(claims),{FIREBASE_PROJECT_ID:'jade-ascendant'},
    {jwksUrl:'https://keys-test.example/workerd-redirect',fetcher:edgeFetch}),'firebase-user');
  assert.equal(requests,1);
});
test('actual HTTP redirect from key endpoint is rejected without following its Location',async()=>{
  let requests=0;
  await assert.rejects(verifyAuth(signed(claims),{FIREBASE_PROJECT_ID:'jade-ascendant'},
    {jwksUrl:'https://keys-test.example/redirect-denied',fetcher:async(url,init)=>{
      requests++;assert.equal(init.redirect,'manual');
      return new Response(null,{status:302,headers:{location:'https://untrusted.example/keys'}});
    }}),e=>e instanceof ProfileAuthUnavailable&&e.stage==='keys_redirect_response');
  assert.equal(requests,1);
});
