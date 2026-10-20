import {flowTransition,flowState,BOARD_REWARDS} from './odyssey_flow_rules.mjs';
import {utcDay} from './odyssey_rules.mjs';
import {reconcileTopupBonus,bonusSummary} from './odyssey_purchase_bonus.mjs';
import {createHash} from 'node:crypto';
import {initial,transition,definition,LIMITS,PREMIUM_LIMITS,integer,reject,rewardPresent,exact} from './odyssey_rules.mjs';
import {assertNoRefundHoldRC5} from './refund_account_guard_rc5.mjs';
import {assertVerifiedPlayCreditRC14} from './verified_purchase_unlock_rc14.mjs';
import {createGoogleKeySource} from '../../ssv/m7e4d_google_keys.mjs';
import {verifyGoogleSsv,parseSignedCallback} from '../../ssv/m7e4b_ssv_verifier.mjs';
const sha=s=>createHash('sha256').update(s).digest('hex');
const id=()=>crypto.randomUUID().replaceAll('-','');
const primary=db=>db.withSession?db.withSession('first-primary'):db;
export const account=uid=>{if(typeof uid!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(uid))reject('invalid_identity',401);return sha(uid);};
export async function currentEvent(db){const r=await primary(db).prepare('SELECT document FROM odyssey_events ORDER BY created_at DESC,id DESC LIMIT 1').first();return r?JSON.parse(r.document):null;}
export async function publishEvent(db,input,time){const e=definition(input),old=await db.prepare('SELECT document FROM odyssey_events WHERE id=?').bind(e.id).first();if(old){const original=JSON.parse(old.document);if(JSON.stringify({...original,enabled:e.enabled,ads_enabled:e.ads_enabled,purchases_enabled:e.purchases_enabled})!==JSON.stringify(e))reject('published_event_immutable');await db.prepare('UPDATE odyssey_events SET document=? WHERE id=?').bind(JSON.stringify(e),e.id).run();}else{if(e.starts_at<time-60||e.starts_at>time+90*86400)reject('invalid_schedule',400);const previous=await currentEvent(db);if(previous&&previous.ends_at+3*86400>time)reject('previous_season_not_finished');await db.prepare("INSERT INTO odyssey_events SELECT ?,?,? WHERE NOT EXISTS(SELECT 1 FROM odyssey_events WHERE json_extract(document,'$.ends_at')+259200>?)").bind(e.id,JSON.stringify(e),time,time).run();const created=await db.prepare('SELECT document FROM odyssey_events WHERE id=?').bind(e.id).first();if(!created)reject('previous_season_not_finished');}return e;}
async function paidEligible(db,owner,time){const key='u1:'+owner;await assertNoRefundHoldRC5({db,owner:key});await assertVerifiedPlayCreditRC14(db,key);const c=await primary(db).prepare("SELECT watermark_ms FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp'").first();if(!integer(c?.watermark_ms,time*1000-7200000,time*1000+60000))reject('refund_monitor_stale',503);}
const paidGuard="NOT EXISTS(SELECT 1 FROM iap_refund_account_holds_v1 WHERE owner_key=? AND status='held') AND EXISTS(SELECT 1 FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp' AND watermark_ms BETWEEN ? AND ?) AND EXISTS(SELECT 1 FROM iap_wallet_events_v1 WHERE owner_key=? AND event_kind='play_credit')";
export function service(db,{now=()=>Math.floor(Date.now()/1000),rng,economy=1,adConfigured=true}={}){
 db=primary(db);
 const prices=economy>=2?PREMIUM_LIMITS:LIMITS;
 const withBonus=economy>=3;
 const withFlow=economy>=4;
 const resolve=withFlow?flowTransition:transition;
 async function delivery(event,owner,stamp){
  if(!adConfigured)return {configured:false,stage:'configuration_required'};
  if(!event)return {configured:true,stage:'none'};
  const row=await db.prepare('SELECT id,expires_at,consumed_at FROM odyssey_ad_intents WHERE event_id=? AND owner=? ORDER BY created_at DESC,id DESC LIMIT 1').bind(event.id,owner).first();
  return row?{configured:true,stage:row.consumed_at?'credited':stamp>row.expires_at?'expired':'pending',nonce:row.id,expires_at:row.expires_at}:{configured:true,stage:'none'};
 }
 const influenced=s=>(s.season_bought||0)>0||(s.bonus_dice||0)>0;
 async function read(uid){
  const owner=account(uid),event=await currentEvent(db);
  if(withBonus)await reconcileTopupBonus(db,event,owner,now(),()=>paidEligible(db,owner,now()));
  if(withFlow&&event?.enabled&&now()>=event.starts_at&&now()<event.ends_at){
   await db.prepare('INSERT OR IGNORE INTO odyssey_players(event_id,owner,state) VALUES(?,?,?)').bind(event.id,owner,JSON.stringify(initial())).run();
   for(let attempt=0;attempt<2;attempt++){
    const current=await db.prepare('SELECT state,revision FROM odyssey_players WHERE event_id=? AND owner=?').bind(event.id,owner).first(),s=JSON.parse(current.state),stamp=now();
    if(s.day===utcDay(stamp)&&s.task_day===utcDay(stamp))break;
    if(influenced(s))await paidEligible(db,owner,stamp);
    const next=resolve(s,{kind:'sync'},event,stamp,rng,prices).state;
    const protectedRead=influenced(s),guardArgs=protectedRead?['u1:'+owner,stamp*1000-7200000,stamp*1000+60000,'u1:'+owner]:[];
    try{await db.batch([db.prepare('UPDATE odyssey_players SET revision=CASE WHEN revision=? AND EXISTS(SELECT 1 FROM odyssey_events WHERE id=? AND document=?)'+(protectedRead?' AND '+paidGuard:'')+' THEN revision+1 ELSE -1 END,state=? WHERE event_id=? AND owner=?').bind(current.revision,event.id,JSON.stringify(event),...guardArgs,JSON.stringify(next),event.id,owner)]);break;}catch(e){if(attempt===1)throw e;}
   }
  }
  const r=event?await db.prepare('SELECT state,revision FROM odyssey_players WHERE event_id=? AND owner=?').bind(event.id,owner).first():null;
  const state=r?JSON.parse(r.state):initial();if(influenced(state))await paidEligible(db,owner,now());
  const grants=(await db.prepare("SELECT state FROM odyssey_players p WHERE owner=? AND EXISTS(SELECT 1 FROM json_each(p.state,'$.milestones') WHERE value=72) LIMIT 100").bind(owner).all()).results.map(row=>JSON.parse(row.state));
  if(grants.length&&grants.every(influenced)&&!influenced(state))await paidEligible(db,owner,now());
  const result={version:1,owner_binding:owner,event,state,revision:r?.revision||0,server_time:now(),limits:prices,compass_authorized:grants.length>0,lease_seconds:60};
  if(withFlow){result.board_rewards=BOARD_REWARDS;result.ad_delivery=await delivery(event,owner,now());}
  if(withBonus)result.purchase_bonus=await bonusSummary(db,event,owner,now());return result;
 }
 async function execute(uid,input){
  exact(input,['event_id','request_id','revision','action']);if(!/^[a-z0-9_-]{3,48}$/.test(input.event_id||'')||!/^[a-f0-9]{32}$/.test(input.request_id||'')||!integer(input.revision,0,10000))reject('invalid_request',400);
  const owner=account(uid),stamp=now(),fingerprint=sha(JSON.stringify(input));
  const prior=await db.prepare('SELECT fingerprint,response FROM odyssey_actions WHERE event_id=? AND owner=? AND request_id=?').bind(input.event_id,owner,input.request_id).first();
  if(prior){if(prior.fingerprint!==fingerprint)reject('request_reused');return JSON.parse(prior.response);}
  const r=await db.prepare('SELECT document FROM odyssey_events WHERE id=?').bind(input.event_id).first();if(!r)reject('event_unavailable',404);const event=JSON.parse(r.document);
  await db.prepare('INSERT OR IGNORE INTO odyssey_players(event_id,owner,state) VALUES(?,?,?)').bind(event.id,owner,JSON.stringify(initial())).run();
  const player=await db.prepare('SELECT * FROM odyssey_players WHERE event_id=? AND owner=?').bind(event.id,owner).first();if(player.revision!==input.revision)reject('revision_changed');
  const state=JSON.parse(player.state),adIntent=input.action?.kind==='ad_intent';
  const out=resolve(state,adIntent?{kind:'sync'}:input.action,event,stamp,rng,prices);
  if(out.cost>0||influenced(state))await paidEligible(db,owner,stamp);
  let ad=null;
  if(adIntent){if(!adConfigured)reject('ads_not_configured',503);exact(input.action,['kind']);if(!event.ads_enabled||out.state.daily_ads>=LIMITS.ads_daily)reject('ad_limit');const outstanding=await db.prepare('SELECT COUNT(*) AS n FROM odyssey_ad_intents WHERE event_id=? AND owner=? AND consumed_at=0 AND expires_at>?').bind(event.id,owner,stamp).first();if(outstanding.n>=4)reject('ad_already_pending');ad={nonce:id(),expires_at:Math.min(stamp+1200,event.ends_at)};}
  const response={version:1,owner_binding:owner,event,state:out.state,revision:input.revision+1,server_time:stamp,limits:prices,ad_intent:ad,jade_spent:out.cost};
  if(withFlow)response.board_rewards=BOARD_REWARDS;
  if(withFlow)response.ad_delivery=ad?{configured:true,stage:'pending',nonce:ad.nonce,expires_at:ad.expires_at}:await delivery(event,owner,stamp);
  if(withBonus)response.purchase_bonus=await bonusSummary(db,event,owner,stamp);
  const guarded=out.cost>0||influenced(state);
  const guardArgs=guarded?['u1:'+owner,stamp*1000-7200000,stamp*1000+60000,'u1:'+owner]:[];
  const steps=[db.prepare('UPDATE odyssey_players SET revision=CASE WHEN revision=?'+(guarded?' AND '+paidGuard:'')+' THEN revision+1 ELSE -1 END,state=?,last_request=? WHERE event_id=? AND owner=?').bind(input.revision,...guardArgs,JSON.stringify(out.state),input.request_id,event.id,owner)];
  if(out.cost){
   // Legacy schema calls every spend 'summon_debit'. item_key disambiguates this
   // expense. All negative deltas remain visible to existing refund reconciliation.
   const eventKey='odyssey:'+sha(owner+':'+event.id+':'+input.request_id);
   steps.push(db.prepare("INSERT INTO iap_wallet_events_v1(event_key,owner_key,event_kind,item_key,delta) VALUES(?,?,'summon_debit',?,?)").bind(eventKey,'u1:'+owner,'odyssey:'+event.id+':dice:'+input.action.pack,-out.cost));
   steps.push(db.prepare('UPDATE iap_wallet_accounts_v1 SET balance=balance-?,revision=revision+1 WHERE owner_key=?').bind(out.cost,'u1:'+owner));
  }
  if(ad)steps.push(db.prepare('INSERT INTO odyssey_ad_intents(id,event_id,owner,created_at,expires_at) VALUES(?,?,?,?,?)').bind(ad.nonce,event.id,owner,stamp,ad.expires_at));
  if(rewardPresent(out.reward))steps.push(db.prepare('INSERT INTO odyssey_outbox(id,owner,event_id,reward,title,expires_at) VALUES(?,?,?,?,?,?)').bind(sha(event.id+':'+owner+':'+input.request_id).slice(0,32),owner,event.id,JSON.stringify(out.reward),out.state.notice,event.ends_at+30*86400));
  steps.push(db.prepare('INSERT INTO odyssey_actions VALUES(?,?,?,?,?,?)').bind(event.id,owner,input.request_id,fingerprint,JSON.stringify(response),stamp));
  try{await db.batch(steps);}catch(error){const committed=await db.prepare('SELECT fingerprint,response FROM odyssey_actions WHERE event_id=? AND owner=? AND request_id=?').bind(event.id,owner,input.request_id).first();if(committed){if(committed.fingerprint!==fingerprint)reject('request_reused');return JSON.parse(committed.response);}if(out.cost){const wallet=await db.prepare('SELECT balance FROM iap_wallet_accounts_v1 WHERE owner_key=?').bind('u1:'+owner).first();if((wallet?.balance||0)<out.cost)reject('insufficient_jade');}const latest=await db.prepare('SELECT revision FROM odyssey_players WHERE event_id=? AND owner=?').bind(event.id,owner).first();if(latest?.revision!==player.revision)reject('revision_changed');throw error;}
  return response;
 }
 return {read,execute};
}
const getKeys=createGoogleKeySource();
export async function prepareAdVerification(){
 try{await getKeys();}catch(error){console.warn('JADE_ODYSSEY_AD stage='+String(error.message||'keys_unavailable').replace(/[^A-Za-z0-9_]/g,'').slice(0,64));reject('ad_verification_unavailable',503);}
}
export async function creditAd(db,rawQuery,env,{keys=getKeys,now=()=>Date.now()}={}){
 // Other placements share the rewarded unit. Ignoring an absent event nonce
 // grants nothing; event callbacks still verify the untouched signed bytes.
 if(!new URLSearchParams(rawQuery.startsWith('?')?rawQuery.slice(1):rawQuery).get('custom_data'))return {ignored:true};
 const parsed=parseSignedCallback(rawQuery),nonce=parsed.params.custom_data;
 if(!nonce)return {ignored:true};if(!/^[a-f0-9]{32}$/.test(nonce))reject('invalid_ad_intent',400);
 const intent=await primary(db).prepare('SELECT * FROM odyssey_ad_intents WHERE id=?').bind(nonce).first();if(!intent)reject('invalid_ad_intent',400);
 if(!env.ODYSSEY_AD_UNIT||!env.ODYSSEY_AD_REWARD_ITEM)reject('ads_not_configured',503);
 const verified=verifyGoogleSsv(rawQuery,{trustedGoogleKeys:await keys(),expectedAdUnit:env.ODYSSEY_AD_UNIT,expectedCustomData:nonce,expectedRewardAmount:1,expectedRewardItem:env.ODYSSEY_AD_REWARD_ITEM,nowMs:now(),maxAgeMs:1200000});
 const existing=await primary(db).prepare('SELECT intent_id FROM odyssey_ad_receipts WHERE transaction_id=?').bind(verified.transactionId).first();if(existing){if(existing.intent_id!==nonce)reject('ad_receipt_conflict');return {credited:true};}
 const stamp=Math.floor(now()/1000),r=await db.prepare('SELECT document FROM odyssey_events WHERE id=?').bind(intent.event_id).first();const event=r?JSON.parse(r.document):null;
 if(!event?.enabled||!event.ads_enabled||stamp>=event.ends_at||stamp>intent.expires_at||intent.consumed_at||verified.timestampMs<intent.created_at*1000-1000)reject('ad_intent_expired');
 for(let attempt=0;attempt<3;attempt++){
  const player=await primary(db).prepare('SELECT state,revision FROM odyssey_players WHERE event_id=? AND owner=?').bind(intent.event_id,intent.owner).first();if(!player)reject('invalid_ad_intent');
  const s=transition(JSON.parse(player.state),{kind:'sync'},event,stamp).state;if(s.daily_ads>=LIMITS.ads_daily)reject('ad_limit');s.daily_ads++;s.tickets++;s.notice='Verified ad · +1 travel die';
  try{await db.batch([
   db.prepare('UPDATE odyssey_players SET revision=CASE WHEN revision=? THEN revision+1 ELSE -1 END,state=? WHERE event_id=? AND owner=?').bind(player.revision,JSON.stringify(s),intent.event_id,intent.owner),
   db.prepare('INSERT INTO odyssey_ad_receipts VALUES(?,?,?)').bind(verified.transactionId,nonce,stamp),
   db.prepare('UPDATE odyssey_ad_intents SET consumed_at=? WHERE id=? AND consumed_at=0').bind(stamp,nonce)
  ]);return {credited:true};}catch(error){
   const replay=await primary(db).prepare('SELECT intent_id FROM odyssey_ad_receipts WHERE transaction_id=?').bind(verified.transactionId).first();if(replay){if(replay.intent_id!==nonce)reject('ad_receipt_conflict');return {credited:true};}
   const latest=await primary(db).prepare('SELECT revision FROM odyssey_players WHERE event_id=? AND owner=?').bind(intent.event_id,intent.owner).first();
   if(attempt<2&&latest?.revision!==player.revision)continue;
   throw error;
  }
 }
 reject('ad_credit_retry',503);
}
export async function flushOutbox(env,limit=8){if(!env.ODYSSEY_PROFILE||!env.ODYSSEY_ADMIN_KEY)return;const rows=(await env.DB.prepare('SELECT * FROM odyssey_outbox WHERE delivered_at=0 ORDER BY id LIMIT ?').bind(limit).all()).results;
 for(const row of rows){try{const response=await env.ODYSSEY_PROFILE.fetch('https://profile.internal/internal/odyssey/mail',{method:'POST',headers:{'content-type':'application/json','x-odyssey-key':env.ODYSSEY_ADMIN_KEY},body:JSON.stringify(row)});if(response.status===200){const data=await response.json();if(data.id===row.id)await env.DB.prepare('UPDATE odyssey_outbox SET delivered_at=? WHERE id=? AND delivered_at=0').bind(Math.floor(Date.now()/1000),row.id).run();}}catch{console.warn('JADE_ODYSSEY stage=outbox_retry');}}
}
