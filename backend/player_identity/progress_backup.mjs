/** Account-owned offline archive, never a paid wallet/entitlement authority.
 * Profile D1 only. Existing Firebase Cloud Save remains disabled.
 */
import {verifyAuth} from './auth.mjs';
import {InvalidIdentity} from '../monetization/cloudflare/src/jwt_verify.mjs';
export const DOMAINS=Object.freeze(['achievements','cultivation_mastery','daily_quests','equipment','idle_cultivation','inventory','journey','pavilion','progression']);
export const MAX_BYTES=196608;
const encoder=new TextEncoder();
const record=v=>v!==null&&typeof v==='object'&&!Array.isArray(v);
const whole=v=>Number.isSafeInteger(v)&&v>=0;
const headers={'content-type':'application/json','cache-control':'private, no-store','x-content-type-options':'nosniff'};
const reply=(status,body)=>new Response(JSON.stringify(body),{status,headers});
export const hash=async value=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',encoder.encode(value))),x=>x.toString(16).padStart(2,'0')).join('');
const REQUIRED={achievements:['progress','unlocked','claimed'],cultivation_mastery:['choices','realm','clears','best_hits','run','trial'],daily_quests:['date_key','progress','completed','claimed'],equipment:['equipped_item_ids','ascension_stars','weapon_levels'],idle_cultivation:['last_claim_unix','last_observed_unix','lifetime_claim_seconds','shard_progress_units'],inventory:['item_counts'],journey:['selected_chapter_id','selected_stage_id','active_run_chapter_id','active_run_stage_id','unlocked_stage_keys','cleared_stage_keys'],pavilion:['meditation_date','cosmetic_id','owned_cosmetics'],progression:['spirit_stone','vitality_level','sword_power_level','swift_qi_level']};
function safeTree(v,depth=0){
 if(depth>14)return false;
 if(v===null||typeof v==='boolean')return true;
 if(typeof v==='number')return whole(v);
 if(typeof v==='string')return encoder.encode(v).length<=4096;
 if(Array.isArray(v))return v.length<=4096&&v.every(x=>safeTree(x,depth+1));
 if(!record(v)||Object.keys(v).length>2048)return false;
 return Object.entries(v).every(([k,x])=>k.length<=128&&!['__proto__','constructor','prototype','purchase_token','purchaseToken','id_token','access_token','auth','email','paid_wallet','paid_entitlements'].includes(k)&&safeTree(x,depth+1));
}
export function validSnapshot(value){
 if(!record(value)||Object.keys(value).sort().join(',')!=='domains,format'||value.format!==1||!record(value.domains)||Object.keys(value.domains).sort().join(',')!==DOMAINS.join(',')||!safeTree(value))return false;
 for(const id of DOMAINS){const d=value.domains[id];if(!record(d)||d.version!==1||!REQUIRED[id].every(k=>Object.hasOwn(d,k)))return false;}
 const j=value.domains.journey,m=value.domains.cultivation_mastery,e=value.domains.equipment;
 if(j.active_run_chapter_id!==0||j.active_run_stage_id!==0||j.m7d_run_id!=='')return false;
 if(!record(m.run)||Object.keys(m.run).length||!record(m.trial)||Object.keys(m.trial).length)return false;
 if(Object.hasOwn(e,'active_run_loadout_snapshot'))return false;
 return true;
}
async function readBody(request){
 if(!request.headers.get('content-type')?.toLowerCase().startsWith('application/json'))throw Error('invalid_body');
 const reader=request.body?.getReader();if(!reader)throw Error('invalid_body');
 let size=0;const chunks=[];
 try{
  const deadline=Date.now()+8000;
  while(true){const remaining=deadline-Date.now();if(remaining<=0)throw Error('invalid_body');let timer;
   const part=await Promise.race([reader.read(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('invalid_body')),remaining);})]).finally(()=>clearTimeout(timer));
   if(part.done)break;size+=part.value.byteLength;if(size>MAX_BYTES)throw Error('invalid_body');chunks.push(part.value);
  }
  const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
  return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
 }catch{await reader.cancel().catch(()=>{});throw Error('invalid_body');}
}
const publicRow=row=>row?{revision:row.revision,updated_at:row.updated_at,snapshot_hash:row.snapshot_hash,snapshot:JSON.parse(row.snapshot_json)}:null;
export function createProgressBackupHandler({verify=verifyAuth,now=Date.now}={}){
 return async(request,env)=>{
  if(env.JADE_PROGRESS_BACKUP_ENABLED!=='true')return reply(503,{error:'progress_backup_disabled'});
  if(!['GET','POST'].includes(request.method))return reply(405,{error:'method_not_allowed'});
  if(new URL(request.url).search)return reply(400,{error:'unsupported_query'});
  try{
   const uid=await verify(request,env,{requireGoogle:true}),owner=await hash(uid);
   if(!env.PROFILE_DB)return reply(503,{error:'service_unavailable'});
   const db=env.PROFILE_DB.withSession?env.PROFILE_DB.withSession('first-primary'):env.PROFILE_DB;
   const read=()=>db.prepare('SELECT revision,request_id,snapshot_json,snapshot_hash,updated_at FROM player_progress_backups_v1 WHERE owner_binding=?').bind(owner).first();
   const row=await read();
   if(request.method==='GET')return reply(200,{version:1,owner_binding:owner,backup:publicRow(row)});
   let data;try{data=await readBody(request);}catch{return reply(400,{error:'invalid_body'});}
   if(!record(data)||Object.keys(data).sort().join(',')!=='expected_revision,request_id,snapshot'||!whole(data.expected_revision)||data.expected_revision>=9007199254740990||typeof data.request_id!=='string'||!/^[a-f0-9]{32}$/.test(data.request_id)||!validSnapshot(data.snapshot))return reply(400,{error:'invalid_snapshot'});
   const serialized=JSON.stringify(data.snapshot),digest=await hash(serialized);
   if(row?.request_id===data.request_id){if(row.snapshot_hash!==digest)return reply(409,{error:'request_reused'});return reply(200,{version:1,owner_binding:owner,revision:row.revision,updated_at:row.updated_at,snapshot_hash:digest});}
   if(data.expected_revision!==(row?.revision??0))return reply(409,{error:'backup_conflict'});
   const seconds=Math.floor(now()/1000);
   if(row&&seconds-row.updated_at<60)return reply(429,{error:'backup_cooldown'});
   const result=await db.prepare(`INSERT INTO player_progress_backups_v1(owner_binding,revision,request_id,snapshot_json,snapshot_hash,updated_at,previous_json)
    VALUES(?,1,?,?,?,?,NULL)
    ON CONFLICT(owner_binding) DO UPDATE SET previous_json=snapshot_json,revision=revision+1,request_id=excluded.request_id,snapshot_json=excluded.snapshot_json,snapshot_hash=excluded.snapshot_hash,updated_at=excluded.updated_at
    WHERE revision=? AND updated_at<=?`).bind(owner,data.request_id,serialized,digest,seconds,data.expected_revision,seconds-60).run();
   if(result.meta?.changes!==1)return reply(409,{error:'backup_conflict'});
   return reply(200,{version:1,owner_binding:owner,revision:data.expected_revision+1,updated_at:seconds,snapshot_hash:digest});
  }catch(error){
   if(error instanceof InvalidIdentity)return reply(401,{error:'google_sign_in_required'});
   console.warn('JADE_PROGRESS_BACKUP stage=service_unavailable');
   return reply(503,{error:'progress_backup_unavailable'});
  }
 };
}
