import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {definition,WEEK} from '../monetization/cloudflare/src/heavenly_trials.mjs';
import {formatWib} from './admin_time.mjs';
const quote=s=>"'"+s.replaceAll("'","''")+"'";
export function planRepair(rows,id=''){
 if(!Array.isArray(rows))throw Error('Invalid campaign snapshot.');
 const now=Number(rows[0]?.server_now);if(!Number.isSafeInteger(now)||now<1700000000)throw Error('Missing trusted database time.');
 const campaigns=rows.map(r=>({...r,c:definition(JSON.parse(r.document))}));
 const candidates=campaigns.filter(r=>r.c.starts_at>now&&(id?r.id===id:r.c.enabled));
 if(candidates.length!==1)throw Error('Expected one not-yet-started campaign; found '+candidates.length+'. Existing live rotations are unchanged. Supply -CampaignId only after reviewing the dashboard.');
 const row=candidates[0];if(Number(row.materialized_weeks)!==0)throw Error('Campaign already has frozen weeks. Existing sessions/progress are preserved; automatic repair refused.');
 const thisWeek=now-((now+270000)%WEEK+WEEK)%WEEK;
 const active=campaigns.some(r=>r.c.starts_at<=now);
 const starts=active?thisWeek+WEEK:thisWeek;
 if(campaigns.some(r=>r.id!==row.id&&r.c.starts_at===starts))throw Error('Destination reset slot occupied. Nothing changed.');
 const next=definition({...row.c,starts_at:starts});const document=JSON.stringify(next);
 const sql=`UPDATE ht_campaigns SET document=${quote(document)} WHERE id=${quote(row.id)} AND document=${quote(row.document)} AND CAST(json_extract(document,'$.starts_at') AS INTEGER)>unixepoch('now') AND unixepoch('now') BETWEEN ${now} AND ${now+21600} AND NOT EXISTS(SELECT 1 FROM ht_weeks WHERE campaign=${quote(row.id)}) AND NOT EXISTS(SELECT 1 FROM ht_campaigns WHERE id<>${quote(row.id)} AND CAST(json_extract(document,'$.starts_at') AS INTEGER)=${starts}) AND (SELECT COUNT(*) FROM ht_campaigns)=${campaigns.length} AND ${campaigns.filter(r=>r.id!==row.id).map(r=>`EXISTS(SELECT 1 FROM ht_campaigns WHERE id=${quote(r.id)} AND document=${quote(r.document)})`).join(' AND ')||'1=1'};\nINSERT INTO ht_audit(campaign,action,document,created_at) SELECT ${quote(row.id)},'schedule_repair_wib',${quote(document)},unixepoch('now') WHERE EXISTS(SELECT 1 FROM ht_campaigns WHERE id=${quote(row.id)} AND document=${quote(document)}) AND NOT EXISTS(SELECT 1 FROM ht_audit WHERE campaign=${quote(row.id)} AND action='schedule_repair_wib' AND document=${quote(document)});\n`;
 return {version:1,id:row.id,before:row.document,after:document,prepared_at:now,starts_at:starts,starts_wib:formatWib(starts),preserves_live_rotation:active,sql};
}
export function readRows(file){const data=JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));if(!Array.isArray(data)||data.some(r=>r.success!==true))throw Error('D1 query did not succeed.');return data.flatMap(r=>r.results||[]);}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const [mode,input,folder,id='']=process.argv.slice(2);const rows=readRows(input);
  if(mode==='prepare'){
   const plan=planRepair(rows,id);fs.mkdirSync(folder,{recursive:true});fs.writeFileSync(path.join(folder,'plan.json'),JSON.stringify(plan,null,2)+'\n');fs.writeFileSync(path.join(folder,'repair.sql'),plan.sql);fs.writeFileSync(path.join(folder,'verify.sql'),`SELECT document FROM ht_campaigns WHERE id=${quote(plan.id)};`);console.log('TRIALS_TIME_PLAN='+plan.id+'; START='+plan.starts_wib+'; LIVE_PROGRESS=RETAINED');
  }else if(mode==='verify'){
   const plan=JSON.parse(fs.readFileSync(path.join(folder,'plan.json'),'utf8'));if(rows.length!==1||rows[0].document!==plan.after)throw Error('Remote document differs. Do not rerun an old plan; refresh the snapshot.');fs.writeFileSync(path.join(folder,'done.json'),JSON.stringify({id:plan.id,starts_at:plan.starts_at,starts_wib:plan.starts_wib,verified_at:new Date().toISOString()},null,2)+'\n');console.log('TRIALS_TIME_RESET=PASS; START='+plan.starts_wib+'; SAVES_REWARDS=UNCHANGED; WORKER_DEPLOY=NONE');
  }else throw Error('Invalid repair mode.');
 }catch(e){console.error('TRIALS_TIME_STOPPED: '+e.message);process.exitCode=1;}
}
