import {trialsOperations} from './heavenly_trials_operations.mjs';
import {createHash,timingSafeEqual} from 'node:crypto';
import {boundedBody,json} from './odyssey_http.mjs';
import {flushOutbox,account} from './odyssey_service.mjs';
import {createGoogleKeySource} from '../../ssv/m7e4d_google_keys.mjs';
import {verifyGoogleSsv,parseSignedCallback} from '../../ssv/m7e4b_ssv_verifier.mjs';
export const THEMES=['jade_wind','scarlet_rite','starfall','froststep','sunforge'];
export const PACK='heavenly_trials_support_550';
export const WEEK=604800,GRACE=172800;
const sha=x=>createHash('sha256').update(x).digest('hex');
const uuid=()=>crypto.randomUUID().replaceAll('-','');
const whole=(x,min,max)=>Number.isSafeInteger(x)&&x>=min&&x<=max;
const fail=(code,status=409)=>{throw Object.assign(Error(code),{code,status});};
const exact=(o,keys)=>o&&typeof o==='object'&&!Array.isArray(o)&&Object.keys(o).sort().join(',')===[...keys].sort().join(',');
const primary=db=>db.withSession?db.withSession('first-primary'):db;
export function definition(input){
 if(!exact(input,['id','starts_at','enabled','ads_enabled','shop_enabled','themes','reward']))fail('invalid_config',400);
 if(!/^[a-z0-9_-]{3,40}$/.test(input.id)||!whole(input.starts_at,1700000000,4102444800)||((input.starts_at+3*86400+3*3600)%WEEK)!==0)fail('start_must_be_monday_0400_wib',400);
 for(const key of ['enabled','ads_enabled','shop_enabled'])if(typeof input[key]!=='boolean')fail('invalid_config',400);
 if(!Array.isArray(input.themes)||input.themes.length!==5||new Set(input.themes).size!==5||input.themes.some(x=>!THEMES.includes(x)))fail('invalid_themes',400);
 if(!exact(input.reward,['celestial_jade','pavilion_seal','spirit_stone'])||!whole(input.reward.celestial_jade,0,40)||!whole(input.reward.pavilion_seal,0,1)||!whole(input.reward.spirit_stone,0,600))fail('reward_budget_exceeded',400);
 return {id:input.id,starts_at:input.starts_at,enabled:input.enabled,ads_enabled:input.ads_enabled,shop_enabled:input.shop_enabled,themes:[...input.themes],reward:{celestial_jade:input.reward.celestial_jade,pavilion_seal:input.reward.pavilion_seal,spirit_stone:input.reward.spirit_stone}};
}
export async function currentCampaign(db,now=Math.floor(Date.now()/1000)){const row=await primary(db).prepare("SELECT document FROM ht_campaigns ORDER BY CASE WHEN json_extract(document,'$.starts_at')<=? THEN 0 ELSE 1 END,CASE WHEN json_extract(document,'$.starts_at')<=? THEN -json_extract(document,'$.starts_at') ELSE json_extract(document,'$.starts_at') END LIMIT 1").bind(now,now).first();return row?JSON.parse(row.document):null;}
export async function publish(db,input,now){
 const next=definition(input),oldRow=await db.prepare('SELECT document FROM ht_campaigns WHERE id=?').bind(next.id).first(),old=oldRow?JSON.parse(oldRow.document):null;
 if(old&&old.id===next.id){
  const fixed={...old,enabled:next.enabled,ads_enabled:next.ads_enabled,shop_enabled:next.shop_enabled};
  if(JSON.stringify(definition(fixed))!==JSON.stringify(next))fail('published_rotation_immutable');
 }else if(next.starts_at<now-WEEK+1||next.starts_at>now+90*86400)fail('invalid_schedule');
 const document=JSON.stringify(next);
 // A single weekly rotation wins a reset slot, including concurrent publishes.
 await db.batch([
  db.prepare("INSERT INTO ht_campaigns SELECT ?,?,? WHERE EXISTS(SELECT 1 FROM ht_campaigns WHERE id=?) OR NOT EXISTS(SELECT 1 FROM ht_campaigns WHERE CAST(json_extract(document,'$.starts_at') AS INTEGER)=? AND id<>?) ON CONFLICT(id) DO UPDATE SET document=excluded.document").bind(next.id,document,now,next.id,next.starts_at,next.id),
  db.prepare("INSERT INTO ht_audit(campaign,action,document,created_at) SELECT ?,'publish',?,? WHERE EXISTS(SELECT 1 FROM ht_campaigns WHERE id=? AND document=?)").bind(next.id,document,now,next.id,document)
 ]);
 const saved=await db.prepare('SELECT document FROM ht_campaigns WHERE id=?').bind(next.id).first();
 if(!saved||saved.document!==document)fail('schedule_slot_occupied');
 return next;
}
export async function weekFor(db,campaign,now,offset=0){
 if(!campaign||now<campaign.starts_at)return null;
 const index=Math.floor((now-campaign.starts_at)/WEEK)+offset;if(index<0)return null;
 const starts_at=campaign.starts_at+index*WEEK,id='ht_'+campaign.id+'_'+index;
 const document={id,campaign:campaign.id,index,theme:campaign.themes[index%5],stage:(index+4)%5+1,starts_at,ends_at:starts_at+WEEK,reward:campaign.reward};
 await db.prepare('INSERT OR IGNORE INTO ht_weeks VALUES(?,?,?,?,?)').bind(id,campaign.id,JSON.stringify(document),starts_at,starts_at+WEEK).run();
 return JSON.parse((await db.prepare('SELECT document FROM ht_weeks WHERE id=?').bind(id).first()).document);
}
async function eligibility(env,owner){
 if(!env.ODYSSEY_PROFILE||!env.ODYSSEY_ADMIN_KEY)return 0;
 const response=await env.ODYSSEY_PROFILE.fetch('https://jade-ascendant-player.jade-ascendant-studio.workers.dev/internal/trials/progress',{method:'POST',headers:{'content-type':'application/json','x-odyssey-key':env.ODYSSEY_ADMIN_KEY},body:JSON.stringify({owner})});
 if(!response.ok)return 0;const data=await response.json();return whole(data.tier,0,3)?data.tier:0;
}
async function grantSteps(db,owner,week,tiers){
 const steps=[];
 for(const tier of tiers){
  const row=await db.prepare('SELECT * FROM ht_progress WHERE owner=? AND week=? AND tier=?').bind(owner,week.id,tier).first();
  if(!row||!row.clears||row.claimed)continue;
  // CAS-backed insert and receipt bit are in one atomic D1 transaction.
  const id=sha(week.id+':'+owner+':'+tier).slice(0,32);
  steps.push(db.prepare("INSERT OR IGNORE INTO odyssey_outbox(id,owner,event_id,reward,title,expires_at) SELECT ?,?,?,?,?,? WHERE EXISTS(SELECT 1 FROM ht_progress WHERE owner=? AND week=? AND tier=? AND clears>0 AND claimed=0)").bind(id,owner,week.id,JSON.stringify({...week.reward,items:{}}),'Heavenly Trials · Tier '+tier,week.ends_at+30*86400,owner,week.id,tier));
  steps.push(db.prepare('UPDATE ht_progress SET claimed=1 WHERE owner=? AND week=? AND tier=? AND clears>0').bind(owner,week.id,tier));
 }
 return steps;
}
async function grants(db,owner,week,tiers){const steps=await grantSteps(db,owner,week,tiers);if(steps.length)await db.batch(steps);}
export function trialsService(database,{now=()=>Math.floor(Date.now()/1000),unlock=eligibility,env={}}={}){
 const db=primary(database);
 async function read(uid){
  const owner=account(uid),stamp=now(),campaign=await currentCampaign(db,stamp),week=await weekFor(db,campaign,stamp);
  await db.prepare("UPDATE ht_sessions SET status='abandoned' WHERE owner=? AND status='running' AND expires_at<?").bind(owner,stamp).run();
  const tier=await unlock(env,owner),progress=week?(await db.prepare('SELECT * FROM ht_progress WHERE owner=? AND week=? ORDER BY tier').bind(owner,week.id).all()).results:[];
  const previousRow=await db.prepare('SELECT w.document FROM ht_weeks w JOIN ht_progress p ON p.week=w.id WHERE p.owner=? AND p.clears>0 AND p.claimed=0 AND w.id<>? AND w.ends_at>=? AND w.starts_at<? ORDER BY w.starts_at DESC LIMIT 1').bind(owner,week?.id||'',stamp-GRACE,stamp).first();
  const previous=previousRow?JSON.parse(previousRow.document):null,previousProgress=previous?(await db.prepare('SELECT * FROM ht_progress WHERE owner=? AND week=? AND clears>0 AND claimed=0').bind(owner,previous.id).all()).results:[];
  const session=await db.prepare("SELECT id,week,tier,started_at,expires_at FROM ht_sessions WHERE owner=? AND status='running'").bind(owner).first();
  if(session)session.week_config=JSON.parse((await db.prepare('SELECT document FROM ht_weeks WHERE id=?').bind(session.week).first()).document);
  const ad=(await db.prepare('SELECT id,week,tier,expires_at,consumed_at FROM ht_ads WHERE owner=? ORDER BY created_at DESC LIMIT 1').bind(owner).first())||null;
  if(week)await reconcilePack(db,owner,week,stamp);
  let pack=false;if(week)pack=!!await db.prepare('SELECT event_key FROM ht_purchase_bonus WHERE owner=? AND week=?').bind(owner,week.id).first();
  const bonus_seals=await trialSealBalance(db,owner);
  return {bonus_seals,version:1,owner_binding:owner,server_time:stamp,campaign,week,unlock_tier:tier,progress,previous,previous_progress:previousProgress,session,ad,pack_claimed:pack,ad_unit:env.TRIALS_AD_UNIT||'',ads_ready:!!campaign?.ads_enabled&&/^ca-app-pub-\d{16}\/\d{10}$/.test(env.TRIALS_AD_UNIT||'')&&!!env.TRIALS_AD_REWARD_ITEM,shop_ready:!!campaign?.shop_enabled,pack_product:PACK};
 }
 async function execute(uid,input){
  if(!exact(input,['request_id','week_id','action'])||!/^[a-f0-9]{32}$/.test(input.request_id)||!/^ht_[a-z0-9_-]{3,64}$/.test(input.week_id)||!input.action?.kind)fail('invalid_request',400);
  const owner=account(uid),stamp=now(),fingerprint=sha(JSON.stringify(input));
  const old=await db.prepare('SELECT * FROM ht_actions WHERE owner=? AND request_id=?').bind(owner,input.request_id).first();
  if(old){if(old.fingerprint!==fingerprint)fail('request_reused');return read(uid);}
  const campaign=await currentCampaign(db,stamp),current=await weekFor(db,campaign,stamp),row=await db.prepare('SELECT document FROM ht_weeks WHERE id=?').bind(input.week_id).first();
  if(!row)fail('week_not_found');const week=JSON.parse(row.document),a=input.action,steps=[db.prepare('INSERT INTO ht_actions VALUES(?,?,?,?)').bind(owner,input.request_id,fingerprint,'{}')];
  const active=campaign?.enabled&&week.campaign===campaign.id&&week.id===current?.id&&stamp>=week.starts_at&&stamp<week.ends_at;
  if(a.kind==='start'){
   if(!exact(a,['kind','tier'])||!whole(a.tier,1,3)||!active)fail('trial_not_available');
   if(a.tier>await unlock(env,owner))fail('tier_locked');
   await db.prepare("UPDATE ht_sessions SET status='abandoned' WHERE owner=? AND status='running' AND expires_at<?").bind(owner,stamp).run();
   const activeSession=await db.prepare("SELECT id FROM ht_sessions WHERE owner=? AND status='running'").bind(owner).first();
   if(activeSession&&activeSession.id!==sha(owner+':'+input.request_id).slice(0,32))fail('session_in_progress');
   const id=sha(owner+':'+input.request_id).slice(0,32);steps.push(db.prepare("INSERT INTO ht_sessions VALUES(?,?,?,?,?,?,'running',NULL)").bind(id,owner,week.id,a.tier,stamp,Math.min(stamp+900,week.ends_at+GRACE)));
  }else if(a.kind==='finish'){
   if(!exact(a,['kind','session_id','won','time_ms','hits','deaths','damage'])||!/^[a-f0-9]{32}$/.test(a.session_id)||typeof a.won!=='boolean'||!whole(a.time_ms,0,900000)||!whole(a.hits,0,100000)||!whole(a.deaths,0,100)||!whole(a.damage,0,1000000000))fail('invalid_report',400);
   const session=await db.prepare('SELECT * FROM ht_sessions WHERE id=? AND owner=? AND week=?').bind(a.session_id,owner,week.id).first();
   if(!session)fail('unknown_session');
   if(session.status==='running'){
    if(stamp>session.expires_at||stamp>week.ends_at+GRACE||a.time_ms>(stamp-session.started_at+15)*1000||a.won&&((stamp-session.started_at)<20||a.time_ms<20000||a.deaths>0||a.damage<1))fail('invalid_session_result');
    if(a.won)steps.push(db.prepare("INSERT INTO ht_progress(owner,week,tier,clears,best_ms,survivor,untouched) SELECT ?,?,?,1,?,1,? WHERE EXISTS(SELECT 1 FROM ht_sessions WHERE id=? AND status='running') ON CONFLICT(owner,week,tier) DO UPDATE SET clears=MIN(clears+1,1000000),best_ms=MIN(best_ms,excluded.best_ms),survivor=1,untouched=MAX(untouched,excluded.untouched)").bind(owner,week.id,session.tier,a.time_ms,a.hits===0?1:0,session.id));
    steps.push(db.prepare("UPDATE ht_sessions SET status=?,report=? WHERE id=? AND status='running'").bind(a.won?'won':'failed',JSON.stringify(a),session.id));
   }else if(session.report!==JSON.stringify(a))fail('session_already_settled');
  }else if(a.kind==='abandon'){
   if(!exact(a,['kind','session_id']))fail('invalid_request',400);
   steps.push(db.prepare("UPDATE ht_sessions SET status='abandoned' WHERE id=? AND owner=? AND week=? AND status='running'").bind(a.session_id,owner,week.id));
  }else if(a.kind==='claim_all'){
   if(!exact(a,['kind'])||stamp>week.ends_at+GRACE)fail('claim_window_closed');steps.push(...await grantSteps(db,owner,week,[1,2,3]));
  }else if(a.kind==='ad_intent'){
   if(!exact(a,['kind','tier'])||!whole(a.tier,1,3)||!active||!campaign.ads_enabled||!env.TRIALS_AD_UNIT||!env.TRIALS_AD_REWARD_ITEM)fail('ads_not_configured');
   const progress=await db.prepare('SELECT * FROM ht_progress WHERE owner=? AND week=? AND tier=?').bind(owner,week.id,a.tier).first();if(!progress?.claimed||progress.bonus)fail('bonus_not_available');
   const pending=await db.prepare('SELECT id FROM ht_ads WHERE owner=? AND week=? AND tier=? AND consumed_at=0 AND expires_at>?').bind(owner,week.id,a.tier,stamp).first();
   if(!pending)steps.push(db.prepare('INSERT INTO ht_ads(id,owner,week,tier,created_at,expires_at) VALUES(?,?,?,?,?,?) ON CONFLICT(owner,week,tier) DO UPDATE SET id=excluded.id,created_at=excluded.created_at,expires_at=excluded.expires_at WHERE ht_ads.consumed_at=0').bind(uuid(),owner,week.id,a.tier,stamp,Math.min(stamp+1200,week.ends_at+GRACE)));
  }else if(a.kind==='pack_reconcile'){
   if(!exact(a,['kind']))fail('invalid_request',400);await reconcilePack(db,owner,week,stamp);
  }else fail('unknown_action',400);
  try{await db.batch(steps);}catch(error){const replay=await db.prepare('SELECT fingerprint FROM ht_actions WHERE owner=? AND request_id=?').bind(owner,input.request_id).first();if(!replay||replay.fingerprint!==fingerprint)throw error;}
  return read(uid);
 }
 return {read,execute};
}
export async function reconcilePack(db,owner,week,now){
 const key='u1:'+owner;
 // Play-credited Jade and bonus Seals remain in the paid ledger, never local mail.
 const credit=await primary(db).prepare("SELECT e.event_key FROM iap_wallet_events_v1 e LEFT JOIN iap_play_void_events_v1 v ON v.token_key='playtoken:'||substr(e.event_key,7) WHERE e.owner_key=? AND e.item_key=? AND e.event_kind='play_credit' AND e.delta=550 AND unixepoch(e.created_at)>=? AND unixepoch(e.created_at)<? AND v.token_key IS NULL AND NOT EXISTS(SELECT 1 FROM iap_refund_account_holds_v1 WHERE owner_key=? AND status='held') ORDER BY e.created_at LIMIT 1").bind(key,PACK,week.starts_at,week.ends_at,key).first();
 if(!credit)return false;
 await db.prepare('INSERT OR IGNORE INTO ht_purchase_bonus VALUES(?,?,?,?)').bind(credit.event_key,owner,week.id,now).run();return true;
}
const keys=createGoogleKeySource();
export async function creditTrialAd(db,raw,env,{getKeys=keys,now=()=>Date.now()}={}){
 const parsed=parseSignedCallback(raw),nonce=parsed.params.custom_data;
 if(!/^[a-f0-9]{32}$/.test(nonce||''))fail('invalid_ad_intent',400);
 const ad=await primary(db).prepare('SELECT * FROM ht_ads WHERE id=?').bind(nonce).first();if(!ad)fail('invalid_ad_intent',400);
 const receipt=verifyGoogleSsv(raw,{trustedGoogleKeys:await getKeys(),expectedAdUnit:env.TRIALS_AD_UNIT,expectedCustomData:nonce,expectedRewardAmount:1,expectedRewardItem:env.TRIALS_AD_REWARD_ITEM,nowMs:now(),maxAgeMs:1200000});
 if(ad.consumed_at){if(ad.transaction_id!==receipt.transactionId)fail('ad_receipt_conflict');return {credited:true};}
 const stamp=Math.floor(now()/1000);if(stamp>ad.expires_at||receipt.timestampMs<ad.created_at*1000-1000)fail('ad_expired');
 const week=JSON.parse((await db.prepare('SELECT document FROM ht_weeks WHERE id=?').bind(ad.week).first()).document),id=sha('ad:'+ad.id).slice(0,32);
 await db.batch([db.prepare('UPDATE ht_ads SET consumed_at=?,transaction_id=? WHERE id=? AND consumed_at=0').bind(stamp,receipt.transactionId,ad.id),db.prepare('UPDATE ht_progress SET bonus=1 WHERE owner=? AND week=? AND tier=? AND claimed=1').bind(ad.owner,ad.week,ad.tier),db.prepare('INSERT OR IGNORE INTO odyssey_outbox VALUES(?,?,?,?,?,?,0)').bind(id,ad.owner,week.id,JSON.stringify({spirit_stone:week.reward.spirit_stone,items:{}}),'Optional ad · bonus Stones',week.ends_at+30*86400)]);return {credited:true};
}
export async function settleTrials(env){
 const db=primary(env.DB),stamp=Math.floor(Date.now()/1000);
 const expired=(await db.prepare('SELECT p.owner,p.week FROM ht_progress p JOIN ht_weeks w ON w.id=p.week WHERE p.clears>0 AND p.claimed=0 AND w.ends_at+?<=? GROUP BY p.owner,p.week LIMIT 100').bind(GRACE,stamp).all()).results;
 for(const row of expired){const week=JSON.parse((await db.prepare('SELECT document FROM ht_weeks WHERE id=?').bind(row.week).first()).document);await grants(db,row.owner,week,[1,2,3]);}
 await flushOutbox(env);
}
export async function trialsRoute(request,env,ctx,uid){
 try{
  const url=new URL(request.url),stamp=Math.floor(Date.now()/1000);
  if(['/internal/trials/config','/internal/trials/operations'].includes(url.pathname)){
   const expected=env.ODYSSEY_ADMIN_KEY||'',actual=request.headers.get('x-odyssey-key')||'';
   if(!/^[a-f0-9]{64}$/.test(expected)||!/^[a-f0-9]{64}$/.test(actual)||!timingSafeEqual(Buffer.from(expected),Buffer.from(actual)))return json(403,{error:'forbidden'});
   if(url.pathname==='/internal/trials/operations')return request.method==='GET'?json(200,await trialsOperations(env.DB,env,{now:stamp})):json(405,{error:'method_not_allowed'});
   if(request.method==='GET')return json(200,{campaign:await currentCampaign(env.DB),server_time:stamp});
   if(request.method==='POST')return json(200,{campaign:await publish(env.DB,await boundedBody(request),stamp),server_time:stamp});
  }
  if(url.pathname==='/v1/heavenly-trials/ssv'&&request.method==='GET')return json(200,await creditTrialAd(env.DB,url.search,env));
  if(!uid)return json(401,{error:'unauthenticated'});
  const api=trialsService(env.DB,{env});let data;
  if(request.method==='GET')data=await api.read(uid);else if(request.method==='POST')data=await api.execute(uid,await boundedBody(request));else return json(405,{error:'method_not_allowed'});
  ctx?.waitUntil?.(flushOutbox(env));return json(200,data);
 }catch(error){return json(error.status||503,{error:error.code||'trials_unavailable'});}
}

export async function trialSealBalance(db,owner){
 const r=await primary(db).prepare("SELECT MAX(0,COALESCE((SELECT SUM(e.delta/550*2) FROM iap_wallet_events_v1 e WHERE e.owner_key=? AND e.event_kind='play_credit' AND e.item_key='heavenly_trials_support_550' AND e.delta=550 AND NOT EXISTS(SELECT 1 FROM iap_play_void_events_v1 v WHERE v.token_key='playtoken:'||substr(e.event_key,7))),0)-COALESCE((SELECT COUNT(*) FROM ht_seal_spends WHERE owner=?),0)) AS balance").bind('u1:'+owner,owner).first();return r?.balance||0;
}
