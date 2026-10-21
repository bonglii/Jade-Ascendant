import {timingSafeEqual} from 'node:crypto';
const reply=(status,data)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json','cache-control':'no-store'}});
export async function trialsProgress(request,env){
 const expected=env.ODYSSEY_ADMIN_KEY||'',actual=request.headers.get('x-odyssey-key')||'';
 if(request.method!=='POST'||!/^[a-f0-9]{64}$/.test(expected)||actual.length!==64||!timingSafeEqual(Buffer.from(expected),Buffer.from(actual)))return reply(403,{error:'forbidden'});
 const body=await request.text();if(body.length>128)return reply(400,{error:'invalid_body'});
 let input;try{input=JSON.parse(body);}catch{return reply(400,{error:'invalid_body'});}
 if(Object.keys(input||{}).join(',')!=='owner'||!/^[a-f0-9]{64}$/.test(input.owner||''))return reply(400,{error:'invalid_owner'});
 try{
  const db=env.PROFILE_DB.withSession?env.PROFILE_DB.withSession('first-primary'):env.PROFILE_DB;
  const row=await db.prepare('SELECT snapshot_json FROM player_progress_backups_v1 WHERE owner_binding=?').bind(input.owner).first();
  const journey=row?JSON.parse(row.snapshot_json)?.domains?.journey:null;
  // Eligibility only: an account-owned backup does not prove a future combat result.
  const cleared=journey?.cleared_stage_keys;let tier=0;
  if(Array.isArray(cleared))for(let n=1;n<=3;n++){if(cleared.includes(n+'-5'))tier=n;else break;}
  return reply(200,{tier});
 }catch{return reply(503,{error:'progress_unavailable'});}
}
export async function trialsAdmin(request,env){
 if(!env.ODYSSEY_IAP||!env.ODYSSEY_ADMIN_KEY)return reply(503,{error:'trials_bridge_not_configured'});
 if(!['GET','POST'].includes(request.method))return reply(405,{error:'method_not_allowed'});
 const body=request.method==='POST'?await request.text():undefined;if(body?.length>8192)return reply(413,{error:'body_too_large'});
 return env.ODYSSEY_IAP.fetch('https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/internal/trials/config',{method:request.method,headers:{'content-type':'application/json','x-odyssey-key':env.ODYSSEY_ADMIN_KEY},body});
}
