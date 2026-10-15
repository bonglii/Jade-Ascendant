import test from 'node:test';
import assert from 'node:assert/strict';
import {requestVoidedPlayPageRC7,VoidedPlayGatewayErrorRC7} from '../src/play_voided_gateway_rc7.mjs';
const opts={getAccessToken:async()=> 'OAuthTokenLongEnoughForContract_123',startTimeMs:10000000,endTimeMs:20000000};
test('Google API URL fixed, in-app only, includes full and partial refund, Bearer header only',async()=>{
 let called=0;
 const output=await requestVoidedPlayPageRC7({...opts,fetcher:async(url,init)=>{
   called++;
   const u=new URL(url);assert.equal(u.hostname,'androidpublisher.googleapis.com');
   assert.equal(u.pathname,'/androidpublisher/v3/applications/com.yungdevstudio.jadeascendant/purchases/voidedpurchases');
   assert.equal(u.searchParams.get('type'),'0');
   assert.equal(u.searchParams.get('includeQuantityBasedPartialRefund'),'true');
   assert.equal(u.searchParams.get('startTime'),'10000000');
   assert.equal(u.searchParams.get('endTime'),'20000000');
   assert.equal(u.search.includes('OAuthToken'),false);
   assert.equal(init.redirect,'manual');assert.match(init.headers.Authorization,/^Bearer /);
   return new Response(JSON.stringify({voidedPurchases:[]}),{headers:{'Content-Type':'application/json'}});
 }});
 assert.equal(called,1);assert.deepEqual(output,{voidedPurchases:[]});
});
test('Google pagination token uses proper pageSelection.token parameter',async()=>{
 await requestVoidedPlayPageRC7({...opts,pageToken:'NEXT_token=',fetcher:async(url)=>{
   const u=new URL(url);assert.equal(u.searchParams.get('pageSelection.token'),'NEXT_token=');
   assert.equal(u.searchParams.has('startTime'),false);
   return new Response('{}',{headers:{'Content-Type':'application/json'}});
 }});
});
test('invalid OAuth credentials fail closed before network',async()=>{
 await assert.rejects(requestVoidedPlayPageRC7({...opts,getAccessToken:async()=>''}),VoidedPlayGatewayErrorRC7);
});
test('non-200 Play response fails closed',async()=>{
 await assert.rejects(requestVoidedPlayPageRC7({...opts,fetcher:async()=>new Response('{}',{status:503,headers:{'Content-Type':'application/json'}})}),
   VoidedPlayGatewayErrorRC7);
});
test('invalid Content-Type fails closed',async()=>{
 await assert.rejects(requestVoidedPlayPageRC7({...opts,fetcher:async()=>new Response('<html></html>',{headers:{'Content-Type':'text/html'}})}),
   VoidedPlayGatewayErrorRC7);
});
test('oversized advertised response rejected before body read',async()=>{
 await assert.rejects(requestVoidedPlayPageRC7({...opts,fetcher:async()=>new Response('{}',{headers:{'Content-Type':'application/json','Content-Length':'5000000'}})}),
   {name:'VoidedPlayGatewayErrorRC7',code:'oversized_play_page'});
});
test('invalid pagination token rejected before network',async()=>{
 await assert.rejects(requestVoidedPlayPageRC7({...opts,pageToken:'https://evil.com',fetcher:async()=>{throw new Error('network should not happen')}}),
   {name:'VoidedPlayGatewayErrorRC7',code:'invalid_page_token'});
});
