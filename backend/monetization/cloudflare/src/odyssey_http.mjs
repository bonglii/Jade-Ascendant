import {timingSafeEqual} from 'node:crypto';
import {service,publishEvent,currentEvent,creditAd,flushOutbox,prepareAdVerification} from './odyssey_service.mjs';
export const json=(status,data)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json; charset=utf-8','cache-control':'private, no-store','x-content-type-options':'nosniff'}});
export function adsConfigured(env){return /^ca-app-pub-[0-9]{16}\/[0-9]{10}$/.test(env.ODYSSEY_AD_UNIT||'')&&typeof env.ODYSSEY_AD_REWARD_ITEM==='string'&&env.ODYSSEY_AD_REWARD_ITEM.length>0;}
export function internalAuthorized(request,env){const expected=env.ODYSSEY_ADMIN_KEY,actual=request.headers.get('x-odyssey-key');return /^[a-f0-9]{64}$/.test(expected||'')&&typeof actual==='string'&&actual.length===64&&timingSafeEqual(Buffer.from(expected),Buffer.from(actual));}
export async function boundedBody(request){const reader=request.body?.getReader();if(!reader)throw Object.assign(new Error(),{code:'invalid_body',status:400});let size=0;const chunks=[];while(true){const part=await reader.read();if(part.done)break;size+=part.value.length;if(size>8192){await reader.cancel();throw Object.assign(new Error(),{code:'body_too_large',status:413});}chunks.push(part.value);}try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw Object.assign(new Error(),{code:'invalid_json',status:400});}}
export async function odysseyRoute(request,env,ctx,uid){const url=new URL(request.url);try{
 if(url.pathname==='/internal/odyssey/config'){
  if(!internalAuthorized(request,env))return json(403,{error:'forbidden'});
  if(request.method==='GET')return json(200,{event:await currentEvent(env.DB)});
  if(request.method==='POST'){const input=await boundedBody(request);if(input.ads_enabled&&(!/^ca-app-pub-[0-9]{16}\/[0-9]{10}$/.test(env.ODYSSEY_AD_UNIT||'')||!env.ODYSSEY_AD_REWARD_ITEM))return json(409,{error:'ads_not_configured'});return json(200,{event:await publishEvent(env.DB,input,Math.floor(Date.now()/1000))});}
  return json(405,{error:'method_not_allowed'});
 }
 if(url.pathname==='/v1/odyssey/ssv'){
  if(request.method!=='GET')return json(405,{error:'method_not_allowed'});
  const result=await creditAd(env.DB,url.search,env);console.info('JADE_ODYSSEY_AD stage='+(result.credited?'credited':'other_placement'));return json(200,result);
 }
 if(!uid)return json(401,{error:'unauthenticated'});
 const api=service(env.DB,{adConfigured:adsConfigured(env),economy:url.pathname==='/v4/odyssey'?4:url.pathname==='/v3/odyssey'?3:url.pathname==='/v2/odyssey'?2:1});let data;
 if(request.method==='GET')data=await api.read(uid);
 else if(request.method==='POST'){const input=await boundedBody(request);if(input.action?.kind==='ad_intent'){if(!adsConfigured(env))return json(503,{error:'ads_not_configured'});await prepareAdVerification();}data=await api.execute(uid,input);}
 else return json(405,{error:'method_not_allowed'});
 if(url.pathname==='/v4/odyssey'&&data.ad_delivery){data.ad_delivery.expected_unit=env.ODYSSEY_AD_UNIT||'';data.ad_delivery.expected_reward_item=env.ODYSSEY_AD_REWARD_ITEM||'';}
 ctx?.waitUntil?.(flushOutbox(env));return json(200,data);
 }catch(error){if(url.pathname==='/v1/odyssey/ssv'){const stage=String(error.code||error.message||'unknown').replace(/[^A-Za-z0-9_]/g,'').slice(0,64);console.warn('JADE_ODYSSEY_AD stage='+stage);if(error.name==='SsvRejection')return json(400,{error:error.code});}const known=['paid_account_on_hold','no_verified_play_credit','refund_monitor_stale'];if(error.status||known.includes(error.code))return json(error.status||409,{error:error.code});console.warn('JADE_ODYSSEY stage=request_unavailable');return json(503,{error:'odyssey_unavailable'});}}
