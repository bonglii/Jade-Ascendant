import {fail,json,readBody,exact,digest,mac,checkProof,nowSeconds} from './mail_admin.mjs';
import {draft} from '../monetization/cloudflare/src/update_push_contract.mjs';
import {audit} from './mail_studio.mjs';
const normalize=input=>{try{return draft(input);}catch(e){fail(e.status||400,e.code||'invalid_update_draft');}};
const view=r=>({id:r.id,draft:JSON.parse(r.draft_json),state:r.state,created_at:r.created_at,updated_at:r.updated_at,error:r.error_code,message_id:r.message_id});
async function bridge(env,input){
 if(!env.ODYSSEY_IAP||!env.ODYSSEY_ADMIN_KEY)fail(503,'push_bridge_missing');
 const response=await env.ODYSSEY_IAP.fetch('https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/internal/updates',{method:'POST',headers:{'content-type':'application/json','x-odyssey-key':env.ODYSSEY_ADMIN_KEY},body:JSON.stringify(input)});
 let data;try{data=await response.json();}catch{fail(502,'push_delivery_unknown');}
 if(!response.ok)fail(response.status,data.error||'push_unavailable');return data;
}
export async function updatePushAdminRoute(db,env,request,url){
 if(!url.pathname.startsWith('/admin/api/updates/'))return null;
 const action=url.pathname.slice('/admin/api/updates/'.length),time=nowSeconds();
 if(action==='history'&&request.method==='GET')return json(200,{entries:(await db.prepare('SELECT * FROM player_update_push_v1 ORDER BY created_at DESC,id DESC LIMIT 50').all()).results.map(view)});
 if(request.method!=='POST')fail(405,'method_not_allowed');const input=await readBody(request,4096);
 if(action==='check'){exact(input,[]);return json(200,await bridge(env,{kind:'check'}));}
 if(action==='preview'){
  const d=normalize(input),fingerprint=await digest(JSON.stringify(d)),expires=time+300;
  return json(200,{draft:d,confirm_expires_at:expires,confirm_token:await mac(env,'update:'+fingerprint+':'+expires),audience:'Opted-in Android installations running an older version',play_url:'https://play.google.com/store/apps/details?id=com.yungdevstudio.jadeascendant'});
 }
 if(action==='send'){
  exact(input,['request_id','draft','confirm_expires_at','confirm_token']);if(!/^[a-f0-9]{32}$/.test(input.request_id||''))fail(400,'invalid_update_id');
  const d=normalize(input.draft),fingerprint=await digest(JSON.stringify(d));
  let row=await db.prepare('SELECT * FROM player_update_push_v1 WHERE id=?').bind(input.request_id).first();
  if(row){if(row.fingerprint!==fingerprint)fail(409,'request_reused');if(row.state!=='pending')return json(200,view(row));}
  if(!row){
  if(!Number.isSafeInteger(input.confirm_expires_at)||input.confirm_expires_at<=time||input.confirm_expires_at>time+300)fail(400,'update_preview_expired');
  if(!await checkProof(env,'update:'+fingerprint+':'+input.confirm_expires_at,input.confirm_token))fail(403,'preview_required');
  await db.prepare("INSERT OR IGNORE INTO player_update_push_v1(id,fingerprint,draft_json,state,created_at,updated_at) SELECT ?,?,?,'pending',?,? WHERE (SELECT count(*) FROM player_update_push_v1 WHERE created_at>?)<3").bind(input.request_id,fingerprint,JSON.stringify(d),time,time,time-3600).run();
  row=await db.prepare('SELECT * FROM player_update_push_v1 WHERE id=?').bind(input.request_id).first();if(!row)fail(429,'update_broadcast_limit');if(row.fingerprint!==fingerprint)fail(409,'request_reused');}
  const claimed=await db.prepare("UPDATE player_update_push_v1 SET state='sending',updated_at=? WHERE id=? AND state='pending' RETURNING id").bind(time,input.request_id).first();
  if(!claimed)return json(200,view(row));
  let result;try{result=await bridge(env,{kind:'send',id:input.request_id,draft:d});}catch(e){result={status:'unknown',error:e.code||'push_delivery_unknown'};}
  const state=result.accepted===true?'accepted':result.status==='rejected'?'rejected':'unknown';
  await db.prepare('UPDATE player_update_push_v1 SET state=?,message_id=?,error_code=?,updated_at=? WHERE id=? AND state=\'sending\'').bind(state,result.message_id||'',result.error||'',nowSeconds(),input.request_id).run();
  await audit(db,'update_push',{id:input.request_id,version_code:d.version_code,state});
  return json(200,view(await db.prepare('SELECT * FROM player_update_push_v1 WHERE id=?').bind(input.request_id).first()));
 }
 fail(404,'not_found');
}
