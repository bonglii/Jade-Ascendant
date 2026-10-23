import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {definition,WEEK} from '../monetization/cloudflare/src/heavenly_trials.mjs';
import {formatWib} from './admin_time.mjs';
// The clock is the driving row, not a property of a possibly empty campaign set.
export const SNAPSHOT_SQL="SELECT clock.server_now,c.id,c.document,c.created_at,CASE WHEN c.id IS NULL THEN 0 ELSE (SELECT COUNT(*) FROM ht_weeks w WHERE w.campaign=c.id) END AS materialized_weeks FROM (SELECT unixepoch('now') AS server_now) AS clock LEFT JOIN ht_campaigns c ON 1=1 ORDER BY c.created_at DESC";
function snapshot(rows){
 if(!Array.isArray(rows)||!rows.length)throw Error('Snapshot has no clock row. Refresh the database snapshot; do not use the device clock.');
 const now=Number(rows[0].server_now);
 if(!Number.isSafeInteger(now)||now<1700000000||rows.some(r=>Number(r.server_now)!==now))throw Error('Missing or inconsistent trusted database time.');
 const empty=rows.length===1&&rows[0].id===null&&rows[0].document===null;
 if(!empty&&rows.some(r=>typeof r.id!=='string'||typeof r.document!=='string'))throw Error('Malformed campaign snapshot.');
 return {now,campaigns:empty?[]:rows.map(r=>({...r,c:definition(JSON.parse(r.document))}))};
}
const quote=s=>"'"+s.replaceAll("'","''")+"'";
export function planRepair(rows,id=''){
 const {now,campaigns}=snapshot(rows);
 if(!campaigns.length){
  if(id)throw Error('Requested campaign does not exist. No schedule changed.');
  return {version:2,kind:'skip',reason:'NO_CAMPAIGNS',prepared_at:now,sql:null};
 }
 const candidates=campaigns.filter(r=>r.c.starts_at>now&&(id?r.id===id:r.c.enabled));
 if(candidates.length!==1)throw Error('Expected one not-yet-started campaign; found '+candidates.length+'. Existing live rotations are unchanged. Supply -CampaignId only after reviewing the dashboard.');
 const row=candidates[0];if(Number(row.materialized_weeks)!==0)throw Error('Campaign already has frozen weeks. Existing sessions/progress are preserved; automatic repair refused.');
 const thisWeek=now-((now+270000)%WEEK+WEEK)%WEEK;
 const active=campaigns.some(r=>r.c.starts_at<=now);
 const starts=active?thisWeek+WEEK:thisWeek;
 if(campaigns.some(r=>r.id!==row.id&&r.c.starts_at===starts))throw Error('Destination reset slot occupied. Nothing changed.');
 const next=definition({...row.c,starts_at:starts});const document=JSON.stringify(next);
 const sql=`UPDATE ht_campaigns SET document=${quote(document)} WHERE id=${quote(row.id)} AND document=${quote(row.document)} AND CAST(json_extract(document,'$.starts_at') AS INTEGER)>unixepoch('now') AND unixepoch('now') BETWEEN ${now} AND ${now+21600} AND NOT EXISTS(SELECT 1 FROM ht_weeks WHERE campaign=${quote(row.id)}) AND NOT EXISTS(SELECT 1 FROM ht_campaigns WHERE id<>${quote(row.id)} AND CAST(json_extract(document,'$.starts_at') AS INTEGER)=${starts}) AND (SELECT COUNT(*) FROM ht_campaigns)=${campaigns.length} AND ${campaigns.filter(r=>r.id!==row.id).map(r=>`EXISTS(SELECT 1 FROM ht_campaigns WHERE id=${quote(r.id)} AND document=${quote(r.document)})`).join(' AND ')||'1=1'};\nINSERT INTO ht_audit(campaign,action,document,created_at) SELECT ${quote(row.id)},'schedule_repair_wib',${quote(document)},unixepoch('now') WHERE EXISTS(SELECT 1 FROM ht_campaigns WHERE id=${quote(row.id)} AND document=${quote(document)}) AND NOT EXISTS(SELECT 1 FROM ht_audit WHERE campaign=${quote(row.id)} AND action='schedule_repair_wib' AND document=${quote(document)});\n`;
 return {version:2,kind:'repair',id:row.id,before:row.document,after:document,prepared_at:now,starts_at:starts,starts_wib:formatWib(starts),preserves_live_rotation:active,sql};
}
export function readRows(file){const data=JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));if(!Array.isArray(data)||data.some(r=>r.success!==true))throw Error('D1 query did not succeed.');return data.flatMap(r=>r.results||[]);}
export function verifyResult(rows,plan){
 if(plan.kind==='skip'){
  if(plan.reason!=='NO_CAMPAIGNS'||snapshot(rows).campaigns.length)throw Error('Campaign data changed after the empty snapshot. Nothing changed; review the new schedule.');
  return {status:'skipped',reason:'NO_CAMPAIGNS',database_time:snapshot(rows).now};
 }
 if(rows.length!==1||rows[0].document!==plan.after)throw Error('Remote document differs. Do not rerun an old plan; refresh the snapshot.');
 return {status:'repaired',id:plan.id,starts_at:plan.starts_at,starts_wib:plan.starts_wib};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const [mode,input,folder,id='']=process.argv.slice(2);
  if(mode==='snapshot-query'){
   console.log(SNAPSHOT_SQL);
  }else if(mode==='prepare'){
   const plan=planRepair(readRows(input),id);fs.mkdirSync(folder,{recursive:true});
   fs.writeFileSync(path.join(folder,'plan.json'),JSON.stringify(plan,null,2)+'\n');
   fs.writeFileSync(path.join(folder,'verify.sql'),plan.kind==='skip'?SNAPSHOT_SQL:`SELECT document FROM ht_campaigns WHERE id=${quote(plan.id)};`);
   if(plan.kind==='skip'){
    console.log('TRIALS_TIME_PLAN=SKIP; REASON=NO_CAMPAIGNS; EVENT_NOT_CREATED; DATABASE_WRITE=NONE');
   }else{
    fs.writeFileSync(path.join(folder,'repair.sql'),plan.sql);
    console.log('TRIALS_TIME_PLAN='+plan.id+'; START='+plan.starts_wib+'; LIVE_PROGRESS=RETAINED');
   }
  }else if(mode==='verify'){
   const plan=JSON.parse(fs.readFileSync(path.join(folder,'plan.json'),'utf8'));
   const result=verifyResult(readRows(input),plan);
   fs.writeFileSync(path.join(folder,'done.json'),JSON.stringify({...result,verified_at:new Date().toISOString()},null,2)+'\n');
   console.log(result.status==='skipped'?'TRIALS_TIME_SKIPPED=NO_CAMPAIGNS; DATABASE_READ=PASS; DATABASE_WRITE=NONE; EVENT_NOT_CREATED':'TRIALS_TIME_RESET=PASS; START='+plan.starts_wib+'; SAVES_REWARDS=UNCHANGED; WORKER_DEPLOY=NONE');
  }else throw Error('Invalid repair mode.');
 }catch(e){console.error('TRIALS_TIME_STOPPED: '+e.message);process.exitCode=1;}
}
