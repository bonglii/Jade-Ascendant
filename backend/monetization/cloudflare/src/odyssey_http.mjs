import {timingSafeEqual} from 'node:crypto';
import {service,publishEvent,currentEvent,creditAd,flushOutbox} from './odyssey_service.mjs';
export const json=(status,data)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json; charset=utf-8','cache-control':'private, no-store','x-content-type-options':'nosniff'}});
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
  return json(200,await creditAd(env.DB,url.search,env));
 }
 if(!uid)return json(401,{error:'unauthenticated'});
 const api=service(env.DB);let data;
 if(request.method==='GET')data=await api.read(uid);
 else if(request.method==='POST')data=await api.execute(uid,await boundedBody(request));
 else return json(405,{error:'method_not_allowed'});
 ctx?.waitUntil?.(flushOutbox(env));return json(200,data);
 }catch(error){const known=['paid_account_on_hold','no_verified_play_credit','refund_monitor_stale'];if(error.status||known.includes(error.code))return json(error.status||409,{error:error.code});console.warn('JADE_ODYSSEY stage=request_unavailable');return json(503,{error:'odyssey_unavailable'});}}
