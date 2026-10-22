import {timingSafeEqual} from 'node:crypto';
const reply=(status,data)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json','cache-control':'no-store'}});
// A completed admin delivery is an independent free grant. Event outbox mail
// remains backed by Odyssey's milestone/refund policy, never this fallback.
export async function compassMailGrant(db,owner){
 const primary=db.withSession?db.withSession('first-primary'):db;
 const row=await primary.prepare(`SELECT 1 AS granted FROM mail_claims k
  JOIN mail_campaigns c ON c.id=k.mail_id
  JOIN mail_recipients r ON r.mail_id=k.mail_id AND r.owner_binding=k.owner_binding
  WHERE k.owner_binding=? AND k.acknowledged_at>0 AND c.published_at>0
  AND c.request_id NOT LIKE 'odyssey:%' AND k.reward_json=c.reward_json
  AND json_type(k.reward_json,'$.items.heavenweaver_compass')='integer'
  AND json_extract(k.reward_json,'$.items.heavenweaver_compass')>0
  AND NOT EXISTS(SELECT 1 FROM mail_claim_resolution x WHERE x.mail_id=k.mail_id AND x.owner_binding=k.owner_binding)
  LIMIT 1`).bind(owner).first();
 return Boolean(row);
}
export async function equipmentGrantRoute(request,env){
 const expected=env.ODYSSEY_ADMIN_KEY||'',actual=request.headers.get('x-odyssey-key')||'';
 if(!/^[a-f0-9]{64}$/.test(expected)||!/^[a-f0-9]{64}$/.test(actual)||!timingSafeEqual(Buffer.from(expected),Buffer.from(actual)))return reply(403,{error:'forbidden'});
 if(request.method!=='POST')return reply(405,{error:'method_not_allowed'});
 try{
  const reader=request.body?.getReader();if(!reader)return reply(400,{error:'invalid_body'});
  let text='';const decoder=new TextDecoder();let size=0;
  while(true){const part=await reader.read();if(part.done)break;size+=part.value.length;if(size>128){await reader.cancel();return reply(413,{error:'body_too_large'});}text+=decoder.decode(part.value,{stream:true});}text+=decoder.decode();
  let data;try{data=JSON.parse(text);}catch{return reply(400,{error:"invalid_body"});}
  if(!data||Array.isArray(data)||Object.keys(data).join(',')!=='owner'||!/^[a-f0-9]{64}$/.test(data.owner||''))return reply(400,{error:'invalid_owner'});
  return reply(200,{version:1,owner_binding:data.owner,compass_authorized:await compassMailGrant(env.PROFILE_DB,data.owner)});
 }catch{return reply(503,{error:'grant_verification_unavailable'});}
}
