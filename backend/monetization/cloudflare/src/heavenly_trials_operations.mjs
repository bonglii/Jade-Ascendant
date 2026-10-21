/** Admin-only, read-only operations. Never creates a week, settles a reward or grants goods. */
export const TRIALS_TABLES=Object.freeze(['ht_campaigns','ht_weeks','ht_sessions','ht_progress','ht_actions','ht_ads','ht_purchase_bonus','ht_audit','ht_seal_spends','odyssey_outbox','iap_play_void_cursor_v1']);
const WEEK=604800;
const UNIT=/^ca-app-pub-3082528078187093\/\d{10}$/;
const SHARED_UNITS=new Set(['ca-app-pub-3082528078187093/8339864838','ca-app-pub-3082528078187093/2136559730','ca-app-pub-3082528078187093/9686167686','ca-app-pub-3082528078187093/9338683323']);
const THEMES=new Set(['jade_wind','scarlet_rite','starfall','froststep','sunforge']);
const primary=db=>db.withSession?db.withSession('first-primary'):db;
const count=value=>Math.max(0,Number.isSafeInteger(Number(value))?Number(value):0);
export function campaignState(c,now){return c.starts_at>now?(c.enabled?'scheduled':'scheduled_paused'):(c.enabled?'live':'paused');}
export function previewRotation(campaigns,now,countWeeks=5){
 const beginning=now-((now+270000)%WEEK+WEEK)%WEEK;
 const safe=campaigns.filter(c=>c&&typeof c.id==='string'&&Number.isSafeInteger(c.starts_at)&&Array.isArray(c.themes)&&c.themes.length===5&&c.themes.every(t=>THEMES.has(t))).sort((a,b)=>a.starts_at-b.starts_at||a.id.localeCompare(b.id));
 return Array.from({length:Math.min(8,Math.max(1,countWeeks))},(_,i)=>{
  const starts_at=beginning+i*WEEK,ends_at=starts_at+WEEK,c=safe.filter(c=>c.starts_at<=starts_at).at(-1);
  if(!c)return {starts_at,ends_at,campaign:null,status:'unpublished',theme:null,stage:null};
  if(safe.filter(other=>other.starts_at===c.starts_at).length>1)return {starts_at,ends_at,campaign:null,status:'conflict',theme:null,stage:null};
  const index=Math.floor((starts_at-c.starts_at)/WEEK);
  return {starts_at,ends_at,campaign:c.id,status:!c.enabled?'paused':i===0?'live':'scheduled',theme:c.themes[index%5],stage:(index+4)%5+1,week_id:'ht_'+c.id+'_'+index};
 });
}
export function adConfiguration(env){
 const unit=env.TRIALS_AD_UNIT||'';
 const reason=!unit?'missing_unit':!UNIT.test(unit)?'wrong_app_or_format':SHARED_UNITS.has(unit)||unit===env.ODYSSEY_AD_UNIT?'shared_unit':env.TRIALS_AD_REWARD_ITEM!=='TrialStones'?'reward_label_mismatch':null;
 return {configured:reason===null,reason,unit:UNIT.test(unit)?unit:'',reward_label:'TrialStones',reward_amount:1,ssv_url:'https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/v1/heavenly-trials/ssv',live_delivery_verified:false};
}
export async function trialsOperations(database,env,{now=Math.floor(Date.now()/1000)}={}){
 const db=primary(database);
 const names=(await db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name IN ("+TRIALS_TABLES.map(()=>'?').join(',')+")").bind(...TRIALS_TABLES).all()).results.map(row=>row.name);
 const missing=TRIALS_TABLES.filter(name=>!names.includes(name));
 const result={version:1,server_time:now,schema:{ready:missing.length===0,missing},campaigns:[],current:null,calendar:[],stats:null,refund:{fresh:false,age_seconds:null},ads:adConfiguration(env),play:{product:'heavenly_trials_support_550',jade:550,bonus_seals:2,console_verified:false},profile_binding_configured:!!env.ODYSSEY_PROFILE&&/^[a-f0-9]{64}$/.test(env.ODYSSEY_ADMIN_KEY||'')};
 if(missing.length)return result;
 const documents=(await db.prepare("SELECT document FROM ht_campaigns ORDER BY CAST(json_extract(document,'$.starts_at') AS INTEGER) DESC,id DESC LIMIT 20").all()).results;
 const campaigns=documents.map(row=>JSON.parse(row.document));
 const currentRow=await db.prepare("SELECT document FROM ht_campaigns WHERE CAST(json_extract(document,'$.starts_at') AS INTEGER)<=? ORDER BY CAST(json_extract(document,'$.starts_at') AS INTEGER) DESC LIMIT 1").bind(now).first();
 if(currentRow){const current=JSON.parse(currentRow.document);result.current={...current,status:campaignState(current,now)};if(!campaigns.some(c=>c.id===current.id))campaigns.push(current);}
 result.campaigns=campaigns.map(c=>({...c,status:campaignState(c,now)}));result.calendar=previewRotation(campaigns,now);
 const refund=await db.prepare("SELECT CAST(strftime('%s',updated_at) AS INTEGER) AS checked_at FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp'").first();
 if(refund&&Number.isSafeInteger(Number(refund.checked_at))){const age=now-Number(refund.checked_at);result.refund={fresh:age>=0&&age<=1200,age_seconds:age};}
 const active=result.current;const week=active?'ht_'+active.id+'_'+Math.floor((now-active.starts_at)/WEEK):'';
 const sessions=await db.prepare("SELECT COUNT(*) AS attempts,COUNT(DISTINCT owner) AS participants,SUM(CASE WHEN status='won' THEN 1 ELSE 0 END) AS wins,SUM(CASE WHEN status='running' AND expires_at>? THEN 1 ELSE 0 END) AS running FROM ht_sessions WHERE week=?").bind(now,week).first();
 const progress=await db.prepare('SELECT SUM(CASE WHEN clears>0 AND claimed=0 THEN 1 ELSE 0 END) AS claimable,SUM(CASE WHEN claimed=1 THEN 1 ELSE 0 END) AS claimed,SUM(CASE WHEN bonus=1 THEN 1 ELSE 0 END) AS ad_bonuses FROM ht_progress WHERE week=?').bind(week).first();
 const outbox=await db.prepare("SELECT COUNT(*) AS pending,SUM(CASE WHEN expires_at<=? THEN 1 ELSE 0 END) AS expired FROM odyssey_outbox WHERE delivered_at=0 AND substr(event_id,1,3)='ht_'").bind(now).first();
 result.stats={week_id:week,attempts:count(sessions?.attempts),participants:count(sessions?.participants),wins:count(sessions?.wins),running:count(sessions?.running),claimable_tiers:count(progress?.claimable),claimed_tiers:count(progress?.claimed),ad_bonuses:count(progress?.ad_bonuses),pending_mail:count(outbox?.pending),expired_mail:count(outbox?.expired)};
 return result;
}
