import {initial,integer,reject} from './odyssey_rules.mjs';
export const TOPUP_BONUSES=Object.freeze([
 Object.freeze({product_id:'jade_pouch_100',jade:100,dice:1}),Object.freeze({product_id:'jade_satchel_550',jade:550,dice:3}),
 Object.freeze({product_id:'jade_casket_1200',jade:1200,dice:5}),Object.freeze({product_id:'jade_vault_2500',jade:2500,dice:8}),
 Object.freeze({product_id:'jade_treasury_6500',jade:6500,dice:12}),Object.freeze({product_id:'jade_ascendant_14000',jade:14000,dice:16}),
]);
const active=(event,cfg,time)=>cfg?.enabled===1&&event?.enabled===true&&event.purchases_enabled===true&&time>=event.starts_at&&time<event.ends_at;
const claims=async(db,event,owner)=>event?(await db.prepare('SELECT product_id,dice FROM odyssey_purchase_bonuses WHERE event_id=? AND owner=?').bind(event.id,owner).all()).results:[];
export async function bonusSummary(db,event,owner,time){
 const cfg=await db.prepare('SELECT enabled,activated_at FROM odyssey_bonus_config WHERE singleton=1').first();
 const existing=await claims(db,event,owner),ids=new Set(existing.map(x=>x.product_id));
 return {version:1,active:active(event,cfg,time),once_per_pack:true,eligible_from:Math.max(cfg?.activated_at||0,event?.starts_at||0),claimed_total:existing.reduce((n,x)=>n+x.dice,0),offers:TOPUP_BONUSES.map(x=>({...x,claimed:ids.has(x.product_id)}))};
}
export async function reconcileTopupBonus(db,event,owner,time,eligible){
 const cfg=await db.prepare('SELECT enabled,activated_at FROM odyssey_bonus_config WHERE singleton=1').first();
 if(!active(event,cfg,time))return;
 const cutoff=Math.max(cfg.activated_at,event.starts_at),key='u1:'+owner;
 for(let attempt=0;attempt<2;attempt++){
  const known=new Set((await claims(db,event,owner)).map(x=>x.product_id));
  const rows=(await db.prepare(`SELECT chosen.event_key,chosen.item_key,chosen.delta FROM iap_wallet_events_v1 chosen WHERE chosen.event_key IN (SELECT MIN(e.event_key) FROM iap_wallet_events_v1 e
   LEFT JOIN iap_play_void_events_v1 v ON v.token_key='playtoken:'||substr(e.event_key,7)
   WHERE e.owner_key=? AND e.event_kind='play_credit' AND e.created_at>=datetime(?,'unixepoch') AND e.created_at<datetime(?,'unixepoch')
   AND v.token_key IS NULL AND ((e.item_key='jade_pouch_100' AND e.delta IN (100,50)) OR (e.item_key='jade_satchel_550' AND e.delta IN (550,275)) OR (e.item_key='jade_casket_1200' AND e.delta IN (1200,600)) OR (e.item_key='jade_vault_2500' AND e.delta IN (2500,1250)) OR (e.item_key='jade_treasury_6500' AND e.delta IN (6500,3250)) OR (e.item_key='jade_ascendant_14000' AND e.delta IN (14000,7000))) GROUP BY e.item_key)`).bind(key,cutoff,event.ends_at).all()).results;
  const awards=[];
  for(const row of rows){const pack=TOPUP_BONUSES.find(x=>x.product_id===row.item_key);if(pack&&!known.has(pack.product_id)&&(row.delta===pack.jade||row.delta===pack.jade/2)){awards.push({...pack,jade:row.delta,event_key:row.event_key});known.add(pack.product_id);}}
  if(!awards.length)return;
  await eligible();
  await db.prepare('INSERT OR IGNORE INTO odyssey_players(event_id,owner,state) VALUES(?,?,?)').bind(event.id,owner,JSON.stringify(initial())).run();
  const player=await db.prepare('SELECT revision,state FROM odyssey_players WHERE event_id=? AND owner=?').bind(event.id,owner).first();
  const state=JSON.parse(player.state),added=awards.reduce((n,x)=>n+x.dice,0),previous=state.bonus_dice||0;
  if(!integer(previous,0,45)||previous+added>45||!integer(state.tickets,0,1000-added))reject('invalid_bonus_state',503);
  state.tickets+=added;state.bonus_dice=previous+added;state.notice=`Top-up bonus secured · +${added} travel dice`;
  const evidence=awards.map(()=>`EXISTS(SELECT 1 FROM iap_wallet_events_v1 e WHERE e.event_key=? AND e.owner_key=? AND e.event_kind='play_credit' AND e.item_key=? AND e.delta=? AND e.created_at>=datetime(?,'unixepoch') AND e.created_at<datetime(?,'unixepoch')) AND NOT EXISTS(SELECT 1 FROM iap_play_void_events_v1 WHERE token_key=?)`).join(' AND ');
  const args=awards.flatMap(x=>[x.event_key,key,x.product_id,x.jade,cutoff,event.ends_at,'playtoken:'+x.event_key.slice(6)]);
  const guard=`EXISTS(SELECT 1 FROM odyssey_events WHERE id=? AND document=?) AND EXISTS(SELECT 1 FROM odyssey_bonus_config WHERE singleton=1 AND enabled=1 AND activated_at=?) AND NOT EXISTS(SELECT 1 FROM iap_refund_account_holds_v1 WHERE owner_key=? AND status='held') AND EXISTS(SELECT 1 FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp' AND watermark_ms BETWEEN ? AND ?) AND ${evidence}`;
  const steps=[db.prepare('UPDATE odyssey_players SET revision=CASE WHEN revision=? AND '+guard+' THEN revision+1 ELSE -1 END,state=? WHERE event_id=? AND owner=?').bind(player.revision,event.id,JSON.stringify(event),cfg.activated_at,key,time*1000-7200000,time*1000+60000,...args,JSON.stringify(state),event.id,owner)];
  for(const x of awards)steps.push(db.prepare('INSERT INTO odyssey_purchase_bonuses(event_id,owner,product_id,credit_event_key,dice,created_at) VALUES(?,?,?,?,?,?)').bind(event.id,owner,x.product_id,x.event_key,x.dice,time));
  try{await db.batch(steps);return;}catch(error){if(attempt===1)throw error;}
 }
}
