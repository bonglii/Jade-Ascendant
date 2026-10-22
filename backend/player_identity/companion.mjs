/** Self-reported, opt-in aggregate funnel. Never progression, reward or purchase proof. */
import {verifyAuth} from './auth.mjs';
import {InvalidIdentity} from '../monetization/cloudflare/src/jwt_verify.mjs';
import {json,readBody,exact,digest,fail} from './mail_admin.mjs';
const KINDS=new Set(['session_start','tutorial_complete','stage_enter','stage_clear','stage_defeat','stage_leave']);
const ID=/^[a-f0-9]{32}$/;
const primary=db=>db.withSession?db.withSession('first-primary'):db;
const caches=new WeakMap();
export function validateEvents(input){
 exact(input,['version','events']);
 if(input.version!==1||!Array.isArray(input.events)||input.events.length<1||input.events.length>20)fail(400,'invalid_events');
 const ids=new Set();
 return input.events.map(e=>{exact(e,['id','kind','chapter','stage','seconds']);if(!ID.test(e.id||'')||ids.has(e.id)||!KINDS.has(e.kind)||!Number.isInteger(e.chapter)||!Number.isInteger(e.stage)||!Number.isInteger(e.seconds)||e.seconds<0||e.seconds>86400)fail(400,'invalid_events');ids.add(e.id);
 const stageEvent=e.kind.startsWith('stage_');if(stageEvent?e.chapter<1||e.chapter>5||e.stage<1||e.stage>(e.chapter===1?6:5):e.chapter!==0||e.stage!==0)fail(400,'invalid_stage');
 return {id:e.id,kind:e.kind,chapter:e.chapter,stage:e.stage,seconds:e.seconds};});
}
export async function acceptMetrics(db,owner,events,stamp){
 const session=primary(db),day=stamp-stamp%86400;
 for(const e of events){const old=await session.prepare('SELECT event_kind,chapter,stage,duration_seconds FROM player_gameplay_metrics_v1 WHERE owner_binding=? AND event_id=?').bind(owner,e.id).first();if(old&&(old.event_kind!==e.kind||old.chapter!==e.chapter||old.stage!==e.stage||old.duration_seconds!==e.seconds))fail(409,'event_reused');}
 await session.batch(events.map(e=>session.prepare('INSERT OR IGNORE INTO player_gameplay_metrics_v1(owner_binding,event_id,event_kind,chapter,stage,duration_seconds,received_at) SELECT ?,?,?,?,?,?,? WHERE EXISTS(SELECT 1 FROM player_identities WHERE owner_binding=?) AND (SELECT COUNT(*) FROM player_gameplay_metrics_v1 WHERE owner_binding=? AND received_at>=?)<200').bind(owner,e.id,e.kind,e.chapter,e.stage,e.seconds,stamp,owner,owner,day)));
 const accepted=[];
 for(const e of events)if(await session.prepare('SELECT event_id FROM player_gameplay_metrics_v1 WHERE owner_binding=? AND event_id=?').bind(owner,e.id).first())accepted.push(e.id);
 await session.prepare('DELETE FROM player_gameplay_metrics_v1 WHERE received_at<?').bind(stamp-30*86400).run();
 return accepted;
}
async function bridge(env,path){
 if(!env.ODYSSEY_IAP||!env.ODYSSEY_ADMIN_KEY)return null;
 const response=await env.ODYSSEY_IAP.fetch('https://jade-ascendant-iap.jade-ascendant-studio.workers.dev'+path,{method:'GET',headers:{'x-odyssey-key':env.ODYSSEY_ADMIN_KEY},signal:AbortSignal.timeout(6000)});
 if(!response.ok)return null;
 const text=await response.text();if(text.length>65536)return null;return JSON.parse(text);
}
export async function publishedAgenda(env,stamp){
 const key=env.ODYSSEY_IAP;if(!key)return {version:1,server_time:stamp,partial:true,events:[]};
 // Cache only until the next public start/end boundary. Otherwise a cached
 // 'scheduled' label can remain after an event starts, or an expired event
 // can stay visible for up to a minute after it has ended.
 const cached=caches.get(key);if(cached&&cached.until>stamp)return cached.value;
 const [trials,odyssey]=await Promise.allSettled([bridge(env,'/internal/trials/operations'),bridge(env,'/internal/odyssey/config')]);
 const t=trials.status==='fulfilled'?trials.value:null,o=odyssey.status==='fulfilled'?odyssey.value:null,events=[];
 for(const week of Array.isArray(t?.calendar)?t.calendar.slice(0,8):[]){
  if(!['live','scheduled'].includes(week.status)||!Number.isSafeInteger(week.starts_at)||!Number.isSafeInteger(week.ends_at)||week.starts_at>=week.ends_at||week.ends_at<=stamp)continue;
  // Bounded, public theme IDs only; unpublished admin labels never reach players.
  const theme=week.theme;
  if(typeof theme!=='string'||!(/^[a-z0-9_]{1,48}$/).test(theme))continue;
  events.push({kind:'heavenly_trials',title:'Heavenly Trials · '+theme.replaceAll('_',' '),starts_at:week.starts_at,ends_at:week.ends_at,status:week.starts_at>stamp?'scheduled':'live'});
}
 const event=o?.event;
 if(event?.enabled===true&&Number.isSafeInteger(event.starts_at)&&Number.isSafeInteger(event.ends_at)&&event.starts_at<event.ends_at&&event.ends_at>stamp)events.push({kind:'odyssey',title:'Jade Dragon Odyssey',starts_at:event.starts_at,ends_at:event.ends_at,status:event.starts_at>stamp?'scheduled':'live'});
 events.sort((a,b)=>a.starts_at-b.starts_at||a.kind.localeCompare(b.kind));
 const value={version:1,server_time:stamp,partial:!t||!o,events};
 const upcomingBoundaries=events.flatMap(e=>[e.starts_at,e.ends_at]).filter(x=>x>stamp);
 const cacheUntil=Math.min(stamp+60,...upcomingBoundaries);
 caches.set(key,{until:cacheUntil,value});return value;
}
/** Independently scheduled privacy-retention purge. The Profile Worker already
 * has a one-minute cron for mail; the caller invokes this once each UTC hour.
 * Existing installations without the new metrics table are unaffected.
 * This is not a reward, purchase, identity or campaign operation.
 */
export async function purgeExpiredMetrics(database,stamp){
 if(!database||!Number.isSafeInteger(stamp)||stamp<30*86400)throw new TypeError('invalid_retention_input');
 const db=primary(database);
 const exists=await db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name=?").bind('player_gameplay_metrics_v1').first();
 if(!exists)return false;
 await db.prepare('DELETE FROM player_gameplay_metrics_v1 WHERE received_at<?').bind(stamp-30*86400).run();
 return true;
}
export async function metricSummary(database,stamp){
 const db=primary(database),since=stamp-7*86400;
 const rows=(await db.prepare('SELECT date(received_at,\'unixepoch\') AS day,event_kind AS kind,chapter,stage,COUNT(*) AS events,COUNT(DISTINCT owner_binding) AS players,ROUND(AVG(duration_seconds),1) AS average_seconds FROM player_gameplay_metrics_v1 WHERE received_at>=? GROUP BY day,event_kind,chapter,stage ORDER BY day DESC,chapter,stage,event_kind LIMIT 500').bind(since).all()).results;
 return {version:1,since,server_time:stamp,retention_days:30,source:'opt_in_client_reports',cohort_retention_available:false,rows};
}
export function createCompanionHandler({verify=verifyAuth,now=()=>Math.floor(Date.now()/1000)}={}){
 return async(request,env)=>{
  const path=new URL(request.url).pathname;
  try{
   if(path==='/v1/player/agenda'){if(request.method!=='GET')return json(405,{error:'method_not_allowed'});return json(200,await publishedAgenda(env,now()));}
   if(path!=='/v1/player/gameplay-metrics')return json(404,{error:'not_found'});
   if(!['POST','DELETE'].includes(request.method))return json(405,{error:'method_not_allowed'});
   const uid=await verify(request,env,{requireGoogle:true}),owner=await digest(uid);
   if(!env.PROFILE_DB)return json(503,{error:'service_unavailable'});
   if(request.method==='DELETE'){await primary(env.PROFILE_DB).prepare('DELETE FROM player_gameplay_metrics_v1 WHERE owner_binding=?').bind(owner).run();return json(200,{version:1,owner_binding:owner,accepted:[]});}
   const events=validateEvents(await readBody(request,8192));
   return json(200,{version:1,owner_binding:owner,accepted:await acceptMetrics(env.PROFILE_DB,owner,events,now())});
  }catch(error){return json(error instanceof InvalidIdentity?401:error.status||503,{error:error instanceof InvalidIdentity?'unauthenticated':error.status?error.code:'service_unavailable'});}
 };
}
export const metricsDashboard=`<!doctype html><html lang="id"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Jade · Player Insights</title><style nonce="__NONCE__">body{margin:0;background:#051b1d;color:#d5e8df;font:16px system-ui}main{max-width:1120px;margin:40px auto;padding:24px}header,section{padding:24px;border:1px solid #9b8758;border-radius:18px;background:linear-gradient(140deg,#123933,#071f24);margin-bottom:20px}h1{color:#f2d18a}a{color:#89e4bf}button{background:#16493e;color:#f2d18a;border:1px solid #ba985a;border-radius:12px;padding:14px;cursor:pointer}table{border-collapse:collapse;width:100%;min-width:680px}td,th{text-align:left;padding:14px;border-bottom:1px solid #294b45}.scroll{overflow:auto}small{color:#93b7aa}</style><main><header><a href="/admin">‹ Dashboard</a><h1>Player Insights</h1><p>Laporan pemain yang mengaktifkan berbagi statistik. Bukan bukti progres/reward atau angka seluruh pemain.</p><button id="refresh">Perbarui</button><p id="status">Memuat…</p></header><section><h2>7 hari terakhir</h2><small>Event dan pemain unik per baris. Clear/enter bukan cohort conversion; satu pemain dapat mencoba beberapa kali. Data tersimpan paling lama30 hari. Durasi adalah laporan client.</small><div class="scroll"><table><thead><tr><th>Tanggal</th><th>Event</th><th>Stage</th><th>Event masuk</th><th>Pemain unik</th><th>Rata-rata detik</th></tr></thead><tbody id="rows"></tbody></table></div></section></main><script nonce="__NONCE__">const state=document.querySelector('#status'),rows=document.querySelector('#rows');async function load(){document.querySelector('#refresh').disabled=true;try{const r=await fetch('/admin/api/player-insights',{credentials:'same-origin'});if(!r.ok)throw Error(r.status);const d=await r.json();rows.replaceChildren();for(const item of d.rows){const tr=document.createElement('tr');for(const value of [item.day,item.kind,item.chapter?item.chapter+'-'+item.stage:'—',item.events,item.players,item.average_seconds]){const td=document.createElement('td');td.textContent=String(value);tr.append(td);}rows.append(tr);}state.textContent=d.rows.length?'Diperbarui · '+new Date(d.server_time*1000).toLocaleString():'Belum ada laporan opt-in; jangan ditafsirkan sebagai nol pemain.';}catch(e){state.textContent='Belum tersedia. Periksa login dan deployment schema.';}finally{document.querySelector('#refresh').disabled=false;}}document.querySelector('#refresh').addEventListener('click',load);load();</script></html>`;
