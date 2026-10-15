import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync,sign} from 'node:crypto';
import {requestVoidedPlayPageRC7} from '../src/play_voided_gateway_rc7.mjs';
import {createPlayGateway} from '../src/play_api.mjs';
import {verifyGooglePushJwtRC9} from '../src/play_rtdn_signed_push_rc9.mjs';
const range={startTimeMs:10000000,endTimeMs:20000000};
const oauth='fixture_OAuth_token_long_enough_123';
function edge(init,receiver){
 if(init.redirect==='error')throw new TypeError('Invalid redirect value, must be follow or manual');
 if(receiver!==globalThis)throw new TypeError('Illegal invocation');
 assert.equal(init.redirect,'manual');
}
test('refund request works with workerd redirect and native receiver requirements',async()=>{
 const result=await requestVoidedPlayPageRC7({...range,getAccessToken:async()=>oauth,fetcher:async function(url,init){edge(init,this);assert.equal(new URL(url).hostname,'androidpublisher.googleapis.com');return Response.json({voidedPurchases:[]});}});
 assert.deepEqual(result,{voidedPurchases:[]});
});
test('Play OAuth, verification, consumption and refund share safe runtime transport',async()=>{
 const pair=generateKeyPairSync('rsa',{modulusLength:2048});
 const secret=JSON.stringify({type:'service_account',client_email:'runtime-fixture@qa.iam.gserviceaccount.com',private_key:pair.privateKey.export({type:'pkcs8',format:'pem'})});
 const calls=[];
 const fetcher=async function(url,init){
  edge(init,this);calls.push({url,method:init.method});
  if(url==='https://oauth2.googleapis.com/token'){
   assert.equal(init.headers.Authorization,undefined);
   return Response.json({access_token:oauth,expires_in:3600});
  }
  assert.equal(new URL(url).hostname,'androidpublisher.googleapis.com');assert.equal(init.headers.Authorization,'Bearer '+oauth);
  if(url.includes('/voidedpurchases?'))return Response.json({voidedPurchases:[]});
  if(init.method==='POST')return new Response(null,{status:204});
  return Response.json({purchaseStateContext:{purchaseState:'PURCHASED'}});
 };
 const gateway=createPlayGateway(secret,fetcher);
 assert.equal((await gateway.getProductPurchaseV2('com.yungdevstudio.jadeascendant','fixture.purchase.token.123456')).purchaseStateContext.purchaseState,'PURCHASED');
 await gateway.consumeProduct('com.yungdevstudio.jadeascendant','jade_pouch_100','fixture.purchase.token.123456');
 assert.deepEqual(await gateway.listVoidedPurchasesPageRC7(range),{voidedPurchases:[]});
 assert.equal(calls.length,4);assert.equal(calls.filter(x=>x.url==='https://oauth2.googleapis.com/token').length,1);
});
test('RTDN signature verification works in workerd without enabling its route',async()=>{
 const pair=generateKeyPairSync('rsa',{modulusLength:2048});
 const jwk={...pair.publicKey.export({format:'jwk'}),kid:'workerd-rtdn',use:'sig',alg:'RS256'};
 const now=Date.now(),t=Math.floor(now/1000),email='rtdn@qa.iam.gserviceaccount.com',audience='https://qa.workers.dev/v1/rtdn';
 const parts=[{alg:'RS256',typ:'JWT',kid:jwk.kid},{iss:'https://accounts.google.com',aud:audience,email,email_verified:true,sub:'fixture-service',iat:t-1,exp:t+600}].map(x=>Buffer.from(JSON.stringify(x)).toString('base64url')).join('.');
 const token=parts+'.'+sign('RSA-SHA256',Buffer.from(parts),pair.privateKey).toString('base64url');
 const out=await verifyGooglePushJwtRC9(token,{audience,serviceAccountEmail:email,nowMs:now,fetcher:async function(url,init){edge(init,this);assert.equal(url,'https://www.googleapis.com/oauth2/v3/certs');assert.equal(init.headers,undefined);return Response.json({keys:[jwk]});}});
 assert.deepEqual(out,{verified_service_account:true});
});
for(const [status,code] of [[302,'play_redirect_denied'],[401,'play_http_401'],[403,'play_http_403'],[429,'play_http_429'],[503,'play_http_5xx']]){
 test('refund HTTP '+status+' is labelled without leaking Google body or credentials',async()=>{
  await assert.rejects(requestVoidedPlayPageRC7({...range,getAccessToken:async()=>oauth,fetcher:async function(url,init){edge(init,this);return new Response('secret OAuth error body '+oauth,{status,headers:{location:'https://other.invalid'}});}}),e=>e.code===code&&e.message===code&&!JSON.stringify(e).includes(oauth));
 });
}
test('refund timeout remains distinct from HTTP permission failure',async()=>{
 await assert.rejects(requestVoidedPlayPageRC7({...range,getAccessToken:async()=>oauth,fetcher:async()=>{const e=new Error('sensitive details');e.name='TimeoutError';throw e;}}),e=>e.code==='play_fetch_timeout'&&!e.message.includes('sensitive'));
});
test('OAuth redirect is rejected without a second request or token forwarding',async()=>{
 const pair=generateKeyPairSync('rsa',{modulusLength:2048});
 const secret=JSON.stringify({type:'service_account',client_email:'oauth-redirect-fixture@qa.iam.gserviceaccount.com',private_key:pair.privateKey.export({type:'pkcs8',format:'pem'})});
 let calls=0;
 const gateway=createPlayGateway(secret,async function(url,init){edge(init,this);calls++;assert.equal(url,'https://oauth2.googleapis.com/token');return new Response(null,{status:302,headers:{location:'https://elsewhere.invalid'}});});
 await assert.rejects(gateway.getProductPurchaseV2('com.yungdevstudio.jadeascendant','fixture.purchase.token.123456'));
 assert.equal(calls,1);
});
