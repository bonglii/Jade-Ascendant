const hash=async s=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s))),b=>b.toString(16).padStart(2,'0')).join('');
function internalAuthorized(request,env){const expected=env.ODYSSEY_ADMIN_KEY,actual=request.headers.get('x-odyssey-key')||'';if(!/^[a-f0-9]{64}$/.test(expected||'')||actual.length!==64)return false;let different=0;for(let i=0;i<64;i++)different|=expected.charCodeAt(i)^actual.charCodeAt(i);return different===0;}
async function boundedBody(request){const reader=request.body?.getReader();if(!reader)throw Error('invalid_body');let size=0;const chunks=[];while(true){const p=await reader.read();if(p.done)break;size+=p.value.length;if(size>8192){await reader.cancel();throw Error('body_too_large');}chunks.push(p.value);}const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}return JSON.parse(new TextDecoder().decode(bytes));}
const reply=(status,data)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json','cache-control':'no-store'}});
export async function receiveOdysseyMail(request,env){
 if(request.method!=='POST'||!internalAuthorized(request,env))return reply(403,{error:'forbidden'});
 const r=await boundedBody(request),db=env.PROFILE_DB.withSession?env.PROFILE_DB.withSession('first-primary'):env.PROFILE_DB;
 if(!/^[a-f0-9]{32}$/.test(r.id||'')||!/^[a-f0-9]{64}$/.test(r.owner||'')||typeof r.reward!=='string'||r.reward.length>1024||!Number.isSafeInteger(r.expires_at))return reply(400,{error:'invalid_delivery'});
 const reward=JSON.parse(r.reward),allowed=['spirit_stone','celestial_jade','pavilion_seal','items'];
 if(Object.keys(reward).some(k=>!allowed.includes(k))||Object.entries(reward.items||{}).some(([k,v])=>k!=='heavenweaver_compass'||v!==1)||allowed.slice(0,3).some(k=>reward[k]!==undefined&&(!Number.isSafeInteger(reward[k])||reward[k]<0||reward[k]>10000)))return reply(400,{error:'invalid_reward'});
 const p=await db.prepare('SELECT public_uid FROM player_identities WHERE owner_binding=?').bind(r.owner).first();if(!p)return reply(409,{error:'profile_required'});
 const now=Math.floor(Date.now()/1000),fingerprint=await hash(JSON.stringify([r.owner,r.event_id,reward,r.expires_at])),key='odyssey:'+r.id;
 await db.batch([
  db.prepare('INSERT OR IGNORE INTO mail_campaigns(id,request_id,fingerprint,title,body,sender,reward_json,audience,target_uid,created_at,expires_at,published_at) VALUES(?,?,?,?,?,?,?,\'uid\',?,?,?,?)').bind(r.id,key,fingerprint,'Jade Dragon Odyssey','Your journey rewards are secured. Claim the attached supplies.','CELESTIAL ODYSSEY',r.reward,p.public_uid,now,r.expires_at,now),
  db.prepare('INSERT OR IGNORE INTO mail_recipients(mail_id,owner_binding) SELECT id,? FROM mail_campaigns WHERE id=? AND fingerprint=?').bind(r.owner,r.id,fingerprint)
 ]);
 const stored=await db.prepare('SELECT fingerprint FROM mail_campaigns WHERE id=?').bind(r.id).first();return stored?.fingerprint===fingerprint?reply(200,{id:r.id}):reply(409,{error:'delivery_conflict'});
}
export async function odysseyAdmin(request,env){if(!env.ODYSSEY_IAP||!env.ODYSSEY_ADMIN_KEY)return reply(503,{error:'odyssey_bridge_not_configured'});if(!['GET','POST'].includes(request.method))return reply(405,{error:'method_not_allowed'});const body=request.method==='POST'?JSON.stringify(await boundedBody(request)):undefined;return env.ODYSSEY_IAP.fetch('https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/internal/odyssey/config',{method:request.method,headers:{'content-type':'application/json','x-odyssey-key':env.ODYSSEY_ADMIN_KEY},body});}
export {odysseyDashboard} from './odyssey_dashboard.mjs';
