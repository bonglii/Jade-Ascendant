import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {calendar} from '../monetization/cloudflare/src/event_calendar.mjs';
import {definition as trialDefinition,WEEK} from '../monetization/cloudflare/src/heavenly_trials.mjs';
import {definition as odysseyDefinition} from '../monetization/cloudflare/src/odyssey_rules.mjs';
import {readRows} from './repair_trials_time.mjs';
export const SNAPSHOT_SQL="SELECT unixepoch('now') AS server_now,'clock' AS kind,NULL AS id,NULL AS document,0 AS created_at,0 AS activity UNION ALL SELECT unixepoch('now'),'odyssey',id,document,created_at,(SELECT COUNT(*) FROM odyssey_players p WHERE p.event_id=e.id) FROM odyssey_events e UNION ALL SELECT unixepoch('now'),'trials',id,document,created_at,(SELECT COUNT(*) FROM ht_weeks w WHERE w.campaign=c.id) FROM ht_campaigns c";
const quote=s=>"'"+s.replaceAll("'","''")+"'";
function snapshot(rows){
 if(!Array.isArray(rows)||!rows.length||rows[0].kind!=='clock')throw Error('Missing trusted database clock. No schedule changed.');
 const now=Number(rows[0].server_now);
 if(!Number.isSafeInteger(now)||now<1700000000||rows.some(r=>Number(r.server_now)!==now))throw Error('Invalid trusted database time.');
 const entries=rows.filter(r=>r.kind!=='clock').map(r=>{
  if(!['odyssey','trials'].includes(r.kind)||typeof r.document!=='string'||!Number.isSafeInteger(Number(r.activity))||Number(r.activity)<0)throw Error('Invalid event snapshot.');
  const config=(r.kind==='trials'?trialDefinition:odysseyDefinition)(JSON.parse(r.document));
  if(config.id!==r.id)throw Error('Event document identity differs.');
  return {...r,config};
 });
 return {now,entries};
}
const view=(entries,now)=>calendar(entries.filter(r=>r.kind==='odyssey'),entries.filter(r=>r.kind==='trials'),now);
export function planRepair(rows){
 const {now,entries}=snapshot(rows),before=view(entries,now);
 if(!before.conflicts.length)return {version:1,kind:'skip',reason:entries.length?'NO_OVERLAP':'NO_EVENTS',prepared_at:now,before,changes:[],sql:null};
 const changed=structuredClone(entries),changes=[],occupied=new Set(entries.filter(r=>r.kind==='trials').map(r=>r.config.starts_at));
 for(const row of changed.filter(r=>r.kind==='trials'&&r.config.enabled)){
  const collisions=before.conflicts.filter(pair=>pair.includes(row.id));if(!collisions.length)continue;
  if(Number(row.activity)!==0)throw Error('OVERLAP_HAS_FROZEN_PROGRESS: '+row.id+'. No event time, reward or player progress changed. Disable one event in dashboard before retrying.');
  const stop=Math.max(now+60,...changed.filter(r=>r.kind==='odyssey'&&r.config.enabled).map(r=>r.config.ends_at+259200));
  let starts=Math.ceil((stop+270000)/WEEK)*WEEK-270000;
  occupied.delete(row.config.starts_at);while(occupied.has(starts))starts+=WEEK;occupied.add(starts);
  if(starts>now+90*86400)throw Error('Repair exceeds the existing90-day scheduling limit. Nothing changed.');
  const next=trialDefinition({...row.config,starts_at:starts});
  changes.push({id:row.id,before:row.document,after:JSON.stringify(next),starts_at:starts});row.document=JSON.stringify(next);row.config=next;
 }
 if(!changes.length||view(changed,now).conflicts.length)throw Error('Schedule cannot be repaired without changing player history. Nothing changed.');
 const guards=[`unixepoch('now') BETWEEN ${now} AND ${now+900}`,...['odyssey','trials'].map(kind=>`(SELECT COUNT(*) FROM ${kind==='odyssey'?'odyssey_events':'ht_campaigns'})=${entries.filter(r=>r.kind===kind).length}`),...entries.map(r=>`EXISTS(SELECT 1 FROM ${r.kind==='odyssey'?'odyssey_events':'ht_campaigns'} WHERE id=${quote(r.id)} AND document=${quote(r.document)})`),...changes.map(c=>`NOT EXISTS(SELECT 1 FROM ht_weeks WHERE campaign=${quote(c.id)})`)];
 let sql=`UPDATE ht_campaigns SET document=CASE id ${changes.map(c=>`WHEN ${quote(c.id)} THEN ${quote(c.after)}`).join(' ')} ELSE document END WHERE id IN (${changes.map(c=>quote(c.id)).join(',')}) AND ${guards.join(' AND ')};\n`;
 for(const c of changes)sql+=`INSERT INTO ht_audit(campaign,action,document,created_at) SELECT ${quote(c.id)},'schedule_conflict_repair',${quote(c.after)},unixepoch('now') WHERE EXISTS(SELECT 1 FROM ht_campaigns WHERE id=${quote(c.id)} AND document=${quote(c.after)}) AND NOT EXISTS(SELECT 1 FROM ht_audit WHERE campaign=${quote(c.id)} AND action='schedule_conflict_repair' AND document=${quote(c.after)});\n`;
 return {version:1,kind:'repair',prepared_at:now,before,changes,sql};
}
export function verify(rows,plan){
 const {now,entries}=snapshot(rows),after=view(entries,now);
 if(after.conflicts.length)throw Error('Calendar still conflicts. Do not overwrite newer admin edits.');
 for(const c of plan.changes)if(entries.find(r=>r.kind==='trials'&&r.id===c.id)?.document!==c.after)throw Error('Prepared repair was not applied exactly. Backup retained.');
 return {status:plan.kind==='skip'?'skipped':'repaired',reason:plan.reason??'OVERLAP_ONLY',server_time:now,changed:plan.changes.map(c=>({id:c.id,starts_at:c.starts_at})),player_progress:'unchanged',rewards:'unchanged',events_created:0};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))try{
 const [mode,input,folder]=process.argv.slice(2);
 if(mode==='snapshot-query')console.log(SNAPSHOT_SQL);
 else if(mode==='prepare'){
  const plan=planRepair(readRows(input));fs.mkdirSync(folder,{recursive:true});fs.writeFileSync(path.join(folder,'plan.json'),JSON.stringify(plan,null,2)+'\n');
  if(plan.sql)fs.writeFileSync(path.join(folder,'repair.sql'),plan.sql);
  console.log('EVENT_CALENDAR_PLAN='+plan.kind.toUpperCase()+'; CHANGES='+plan.changes.length+'; PROGRESS_REWARDS=UNCHANGED');
 }else if(mode==='verify'){
  const result=verify(readRows(input),JSON.parse(fs.readFileSync(path.join(folder,'plan.json'),'utf8')));fs.writeFileSync(path.join(folder,'done.json'),JSON.stringify(result,null,2)+'\n');console.log('EVENT_CALENDAR='+result.status.toUpperCase()+'; CHANGED='+result.changed.length+'; PROGRESS_REWARDS=UNCHANGED; EVENTS_CREATED=0');
 }else throw Error('Invalid calendar repair mode.');
}catch(error){console.error('EVENT_CALENDAR_STOPPED: '+error.message);process.exitCode=1;}
