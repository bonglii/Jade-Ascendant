/** Server wallet -> counted gear -> paid loadout. No offline save import.
 * V1 remains immutable after an exact, revision-guarded history migration.
 */
import {createHash} from 'node:crypto';
import {createD1Wallet} from './d1_wallet.mjs';
import {PAID_CATALOG_V2 as CATALOG,PAID_CATALOG_HASH_V2 as HASH,PAID_ITEMS_V2 as ITEMS} from './paid_catalog_v2.mjs';
import {assertNoRefundHoldRC5,RefundHoldErrorRC5} from './refund_account_guard_rc5.mjs';
import {assertVerifiedPlayCreditRC14} from './verified_purchase_unlock_rc14.mjs';
import {InvalidIdentity,verifyFirebaseHeaders} from './jwt_verify.mjs';
const MAX=1_000_000_000,REV=9007199254740990;
const SLOTS=['armament','robe','bracer','boots','pendant'],RARITIES=['common','rare','epic','legendary'];
const PITY=['rare_plus','epic_plus','legendary'],LIMITS=[10,30,50],RATES=[6000,2900,900,200];
const SHARDS={common:5,rare:12,epic:30,legendary:75};
const UUID=/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/;
const sha=s=>createHash('sha256').update(s,'utf8').digest('hex');
const primary=db=>typeof db.withSession==='function'?db.withSession('first-primary'):db;
const plain=x=>x!==null&&typeof x==='object'&&!Array.isArray(x)&&[null,Object.prototype].includes(Object.getPrototypeOf(x));
const exact=(x,keys)=>plain(x)&&Object.keys(x).length===keys.length&&keys.every(k=>Object.hasOwn(x,k));
const int=(x,min=0,max=MAX)=>Number.isSafeInteger(x)&&x>=min&&x<=max;
const emptySlots=()=>Object.fromEntries(SLOTS.map(k=>[k,'']));
export class PaidGameplayErrorV2 extends Error{constructor(code){super(code);this.code=code;}}
const fail=code=>{throw new PaidGameplayErrorV2(code);};
const ownerOf=uid=>{if(typeof uid!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(uid))fail('invalid_identity');return 'u1:'+sha(uid);};
function validate(s){
 if(!exact(s,['version','inventory','stars','slots','pity','wish','wish_guaranteed','lifetime_pulls'])||s.version!==2
  ||!plain(s.inventory)||Object.keys(s.inventory).length>56||!plain(s.stars)||Object.keys(s.stars).length!==Object.keys(s.inventory).length
  ||Object.entries(s.inventory).some(([id,n])=>!ITEMS.has(id)||!int(n,1)||!int(s.stars[id],1,5))
  ||!exact(s.slots,SLOTS)||SLOTS.some(k=>typeof s.slots[k]!=='string'||(s.slots[k]!==''&&(!s.inventory[s.slots[k]]||ITEMS.get(s.slots[k])?.slot!==k)))
  ||!exact(s.pity,PITY)||!PITY.every((k,i)=>int(s.pity[k],0,LIMITS[i]-1))||!int(s.lifetime_pulls)
  ||typeof s.wish!=='string'||(s.wish!==''&&ITEMS.get(s.wish)?.rarity!=='legendary')
  ||typeof s.wish_guaranteed!=='boolean'||(s.wish_guaranteed&&!s.wish))fail('invalid_paid_state');
 return s;
}
function parse(row){if(!row||!int(row.revision,0,REV)||typeof row.state_json!=='string'||row.state_json.length>32768)fail('invalid_paid_state');try{return validate(JSON.parse(row.state_json));}catch{fail('invalid_paid_state');}}
const rowOf=(db,owner)=>primary(db).prepare('SELECT revision,state_json FROM iap_paid_gameplay_v2 WHERE owner_key=?').bind(owner).first();
const opOf=(db,key)=>primary(db).prepare('SELECT owner_key,payload_digest,result_json FROM iap_paid_commands_v2 WHERE operation_key=?').bind(key).first();
async function eligible(db,owner,now,credit=true){
 await assertNoRefundHoldRC5({db,owner});if(credit)await assertVerifiedPlayCreditRC14(db,owner);
 const row=await primary(db).prepare("SELECT watermark_ms FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp'").first();
 if(!int(row?.watermark_ms,now-7200000,now+60000))fail('refund_monitor_stale');
}
const guard=`NOT EXISTS(SELECT 1 FROM iap_refund_account_holds_v1 h WHERE h.owner_key=iap_paid_gameplay_v2.owner_key AND h.status='held')
 AND EXISTS(SELECT 1 FROM iap_play_void_cursor_v1 c WHERE c.cursor_name='voided_inapp' AND c.watermark_ms BETWEEN ? AND ?)
 AND EXISTS(SELECT 1 FROM iap_wallet_events_v1 e WHERE e.owner_key=iap_paid_gameplay_v2.owner_key AND e.event_kind='play_credit')`;
async function migrate(db,uid,now){
 const owner=ownerOf(uid);await eligible(db,owner,now);if(await rowOf(db,owner))return;
 const old=await primary(db).prepare('SELECT revision,status,state_json FROM iap_summon_canonical_v1 WHERE owner_key=?').bind(owner).first();
 if(!old||old.status!=='verified'||!int(old.revision,0,REV))fail('legacy_account_not_ready');
 let s;try{s=JSON.parse(old.state_json);}catch{fail('legacy_proof_mismatch');}
 if(s?.state_contract_version!==1||!int(s.lifetime_pulls)||!plain(s.inventory)||Object.values(s.inventory).some(n=>n!==1)||!int(s.refinement_shards))fail('legacy_proof_mismatch');
 const proof=await primary(db).prepare(`SELECT COUNT(*) AS outcomes,COALESCE(SUM(pull_count),0) AS pulls,
  COALESCE(SUM(CASE WHEN json_extract(outcome_json,'$.outcome_contract_version')=1 AND json_extract(outcome_json,'$.pull_count')=pull_count
   AND json_array_length(outcome_json,'$.results')=pull_count AND EXISTS(SELECT 1 FROM iap_wallet_events_v1 e WHERE e.event_key=iap_summon_outcomes_v1.spend_key
    AND e.owner_key=iap_summon_outcomes_v1.owner_key AND e.event_kind='summon_debit' AND e.delta=-iap_summon_outcomes_v1.jade_cost) THEN 0 ELSE 1 END),0) AS invalid
  FROM iap_summon_outcomes_v1 WHERE owner_key=?`).bind(owner).first();
 const grouped=await primary(db).prepare(`SELECT json_extract(j.value,'$.item_id') AS item_id,json_extract(j.value,'$.rarity') AS rarity,
  COUNT(*) AS copies,SUM(json_extract(j.value,'$.duplicate_shards')) AS shards,
  SUM(CASE WHEN json_type(j.value,'$.duplicate') IN ('true','false') AND
   ((json_extract(j.value,'$.duplicate')=0 AND json_extract(j.value,'$.duplicate_shards')=0)
    OR (json_extract(j.value,'$.duplicate')=1 AND json_extract(j.value,'$.duplicate_shards') IN (5,12,30,75))) THEN 0 ELSE 1 END) AS invalid
  FROM iap_summon_outcomes_v1 o,json_each(o.outcome_json,'$.results') j WHERE o.owner_key=? GROUP BY item_id,rarity LIMIT 57`).bind(owner).all();
 if(!proof||proof.invalid!==0||proof.pulls!==s.lifetime_pulls||!Array.isArray(grouped?.results)||grouped.results.length>56)fail('legacy_proof_mismatch');
 const inventory={},stars={};let count=0,shards=0;
 for(const r of grouped.results){
  if(ITEMS.get(r.item_id)?.rarity!==r.rarity||!int(r.copies,1)||!int(r.shards)||r.invalid!==0
   ||r.shards!==(r.copies-1)*SHARDS[r.rarity]||Object.hasOwn(inventory,r.item_id))fail('legacy_proof_mismatch');
  inventory[r.item_id]=r.copies;stars[r.item_id]=1;count+=r.copies;shards+=r.shards;
 }
 if(count!==proof.pulls||shards!==s.refinement_shards||Object.keys(inventory).length!==Object.keys(s.inventory).length
  ||Object.keys(s.inventory).some(k=>!Object.hasOwn(inventory,k)))fail('legacy_proof_mismatch');
 const loadout=await primary(db).prepare('SELECT revision,slots_json FROM iap_paid_loadouts_v1 WHERE owner_key=?').bind(owner).first();
 let slots=emptySlots();if(loadout){try{slots=JSON.parse(loadout.slots_json);}catch{fail('legacy_proof_mismatch');}}
 const state=validate({version:2,inventory,stars,slots,pity:s.pity,wish:s.wish_item_id,wish_guaranteed:s.wish_fate_guaranteed,lifetime_pulls:s.lifetime_pulls});
 await db.prepare(`INSERT OR IGNORE INTO iap_paid_gameplay_v2(owner_key,revision,source_revision,state_json)
  SELECT c.owner_key,0,c.revision,? FROM iap_summon_canonical_v1 c WHERE c.owner_key=? AND c.status='verified' AND c.revision=? AND c.state_json=?
   AND (SELECT COUNT(*) FROM iap_summon_outcomes_v1 WHERE owner_key=c.owner_key)=?
   AND COALESCE((SELECT revision FROM iap_paid_loadouts_v1 WHERE owner_key=c.owner_key),-1)=?
   AND NOT EXISTS(SELECT 1 FROM iap_refund_account_holds_v1 WHERE owner_key=c.owner_key AND status='held')
   AND EXISTS(SELECT 1 FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp' AND watermark_ms BETWEEN ? AND ?)`)
  .bind(JSON.stringify(state),owner,old.revision,old.state_json,proof.outcomes,loadout?.revision??-1,now-7200000,now+60000).run();
 if(!await rowOf(db,owner))fail('retry_after_refresh');
}
function normalize(c){
 if(!plain(c)||typeof c.request_id!=='string'||!UUID.test(c.request_id)||!int(c.expected_revision,0,REV-1))fail('invalid_command');
 if(typeof c.kind!=='string'||!['initialize','summon','equip','refine','wish','run_start','run_resume'].includes(c.kind))fail('invalid_command');
 const fields={initialize:[],summon:['pull_count'],equip:['slot','item_id'],refine:['item_id'],wish:['item_id'],run_start:['run_id','weapon_level'],run_resume:['run_id']}[c.kind];
 if(!fields||!exact(c,['request_id','expected_revision','kind',...fields]))fail('invalid_command');
 const n={request_id:c.request_id,expected_revision:c.expected_revision,kind:c.kind};for(const k of fields)n[k]=c[k];
 if(fields.includes('run_id')&&(typeof c.run_id!=='string'||!UUID.test(c.run_id)))fail('invalid_command');
 if(c.kind==='run_start'&&!int(c.weapon_level,0,50))fail('invalid_command');
 if(c.kind==='summon'&&![1,10].includes(c.pull_count))fail('invalid_command');
 if(fields.includes('item_id')&&(typeof c.item_id!=='string'||(c.item_id!==''&&!ITEMS.has(c.item_id))))fail('invalid_command');
 if(c.kind==='equip'&&!SLOTS.includes(c.slot))fail('invalid_command');return n;
}
function secureInt(min,max){const range=max-min;if(!Number.isSafeInteger(range)||range<1||range>10000)fail('invalid_rng');const bytes=new Uint32Array(1),limit=Math.floor(4294967296/range)*range;do{globalThis.crypto.getRandomValues(bytes);}while(bytes[0]>=limit);return min+bytes[0]%range;}
function draw(s,count,rng){
 const pool=Object.fromEntries(RARITIES.map(r=>[r,CATALOG.filter(x=>x.rarity===r).map(x=>x.id)]));const pick=a=>a[rng(0,a.length)];const results=[];
 for(let i=0;i<count;i++){
  const hard=s.pity.legendary===49;let rank=hard?3:s.pity.epic_plus===29?2:s.pity.rare_plus===9?1:-1;
  if(rank<0){const n=rng(0,10000);let total=0;for(let j=0;j<4;j++){total+=RATES[j];if(n<total){rank=j;break;}}}
  const rarity=RARITIES[rank];if(!rarity)fail('invalid_rng');const wish=rank===3&&s.wish!=='';const guaranteed=s.wish_guaranteed;
  const id=wish&&(hard||guaranteed||rng(0,2)===0)?s.wish:pick(wish?pool[rarity].filter(x=>x!==s.wish):pool[rarity]);
  if(!id||!pool[rarity].includes(id))fail('invalid_rng');const hit=wish&&id===s.wish,duplicate=Object.hasOwn(s.inventory,id);
  if(wish)s.wish_guaranteed=!hit;s.inventory[id]=(s.inventory[id]??0)+1;s.stars[id]??=1;
  s.pity.rare_plus=rank>=1?0:s.pity.rare_plus+1;s.pity.epic_plus=rank>=2?0:s.pity.epic_plus+1;s.pity.legendary=rank>=3?0:s.pity.legendary+1;
  results.push({item_id:id,rarity,duplicate,duplicate_shards:0,hard_legendary_pity:hard,wish_hit:hit,wish_fate_activated:wish&&!hit&&!hard,wish_fate_consumed:wish&&guaranteed&&hit});
 }
 s.lifetime_pulls+=count;return{pull_count:count,results,next_pity:{...s.pity}};
}
function checkedRun(raw,state){
 let r;try{r=typeof raw==='string'?JSON.parse(raw):raw;}catch{fail('invalid_paid_run');}
 if(!exact(r,['slots','stars','weapon_level'])||!exact(r.slots,SLOTS)||!plain(r.stars))fail('invalid_paid_run');
 const ids=SLOTS.map(k=>r.slots[k]).filter(id=>id!=='');
 if(Object.keys(r.stars).length!==ids.length)fail('invalid_paid_run');
 for(const slot of SLOTS){const id=r.slots[slot];if(typeof id!=='string'||(id!==''&&(!ITEMS.has(id)||ITEMS.get(id).slot!==slot||!int(r.stars[id],1,5))))fail('invalid_paid_run');}
 if(!int(r.weapon_level,r.slots.armament?1:0,r.slots.armament?r.stars[r.slots.armament]*10:0))fail('invalid_paid_run');
 if(ids.some(id=>!state.inventory[id]))fail('run_loadout_unavailable');
 return r;
}
export function createPaidGameplayV2(db,{now=()=>Date.now(),rng=secureInt}={}){
 const wallet=createD1Wallet(db);
 async function read(uid){
  const owner=ownerOf(uid);await eligible(db,owner,now(),false);const row=await rowOf(db,owner),w=await wallet.getSnapshot(uid);let state='ready',s;
  if(row){await assertVerifiedPlayCreditRC14(db,owner);s=parse(row);}
  else{const credit=await primary(db).prepare("SELECT 1 AS yes FROM iap_wallet_events_v1 WHERE owner_key=? AND event_kind='play_credit' LIMIT 1").bind(owner).first();state=credit?'initialize_required':'unfunded';s={inventory:{},stars:{},slots:emptySlots(),pity:{rare_plus:0,epic_plus:0,legendary:0},wish:'',wish_guaranteed:false,lifetime_pulls:0};}
  return{paid_gameplay_version:2,account_binding:owner.slice(3),catalog_hash:HASH,state,revision:row?.revision??0,wallet:{balance:w.balance,revision:w.revision},
   inventory:s.inventory,stars:s.stars,slots:s.slots,pity:s.pity,wish:s.wish,wish_guaranteed:s.wish_guaranteed,lifetime_pulls:s.lifetime_pulls,
   rates:Object.fromEntries(RARITIES.map((r,i)=>[r,RATES[i]])),lease_seconds:120};
 }
 async function execute(uid,input){
  const c=normalize(input),owner=ownerOf(uid),time=now();await eligible(db,owner,time);
  if(c.kind==='initialize'){if(c.expected_revision!==0)fail('invalid_command');await migrate(db,uid,time);return{snapshot:await read(uid),operation:{request_id:c.request_id,kind:c.kind,outcome:null}};}
  const key='paidv2:'+sha(uid+'\0'+c.request_id),digest=sha(JSON.stringify(c));
  const replay=op=>{if(op.owner_key!==owner||op.payload_digest!==digest)fail('idempotency_conflict');return JSON.parse(op.result_json);};
  async function cancel(){const operation={request_id:c.request_id,kind:'not_committed',outcome:null};await db.prepare('INSERT OR IGNORE INTO iap_paid_commands_v2(operation_key,owner_key,payload_digest,result_json) VALUES(?,?,?,?)').bind(key,owner,digest,JSON.stringify(operation)).run();return{snapshot:await read(uid),operation:replay(await opOf(db,key))};}
  const op=await opOf(db,key);if(op)return{snapshot:await read(uid),operation:replay(op)};
  const row=await rowOf(db,owner);if(!row)fail('initialize_required');const s=parse(row);if(row.revision!==c.expected_revision)return cancel();let outcome=null,cost=0,runInsert=null;
  if(c.kind==='run_start'||c.kind==='run_resume'){
   const saved=await primary(db).prepare('SELECT loadout_json FROM iap_paid_runs_v2 WHERE owner_key=? AND run_id=?').bind(owner,c.run_id).first();
   if(c.kind==='run_start'&&saved)return cancel();
   if(c.kind==='run_resume'&&!saved)return cancel();
   let frozen;try{frozen=c.kind==='run_resume'?checkedRun(saved.loadout_json,s):checkedRun({slots:{...s.slots},stars:Object.fromEntries(Object.values(s.slots).filter(Boolean).map(id=>[id,s.stars[id]])),weapon_level:c.weapon_level},s);}catch(e){if(e instanceof PaidGameplayErrorV2&&e.code==='run_loadout_unavailable')return cancel();throw e;}
   if(c.kind==='run_start')runInsert=JSON.stringify(frozen);
   outcome={run_id:c.run_id,...frozen};
  }
  if(c.kind==='summon'){cost=c.pull_count===1?100:900;outcome=draw(s,c.pull_count,rng);}
  if(c.kind==='equip'){if(c.item_id!==''&&(ITEMS.get(c.item_id)?.slot!==c.slot||!s.inventory[c.item_id]))fail('item_not_owned');s.slots[c.slot]=c.item_id;}
  if(c.kind==='refine'){if(!s.inventory[c.item_id]||s.inventory[c.item_id]<2||s.stars[c.item_id]>=5)fail('refine_not_ready');s.inventory[c.item_id]--;s.stars[c.item_id]++;}
  if(c.kind==='wish'){if(c.item_id!==''&&ITEMS.get(c.item_id)?.rarity!=='legendary')fail('invalid_command');if(s.wish!==c.item_id){s.wish=c.item_id;s.wish_guaranteed=false;}}
  validate(s);const operation={request_id:c.request_id,kind:c.kind,outcome},steps=[];
  if(cost){steps.push(db.prepare("INSERT INTO iap_wallet_events_v1(event_key,owner_key,event_kind,item_key,delta) VALUES(?,?,'summon_debit',?,?)").bind(key,owner,'paid-v2:summon:'+c.pull_count,-cost));steps.push(db.prepare('UPDATE iap_wallet_accounts_v1 SET balance=balance-?,revision=revision+1 WHERE owner_key=?').bind(cost,owner));}
  steps.push(db.prepare(`UPDATE iap_paid_gameplay_v2 SET revision=CASE WHEN revision=? AND ${guard} THEN revision+1 ELSE -1 END,state_json=?,updated_at=CURRENT_TIMESTAMP WHERE owner_key=?`).bind(c.expected_revision,time-7200000,time+60000,JSON.stringify(s),owner));
  if(runInsert!==null)steps.push(db.prepare('INSERT INTO iap_paid_runs_v2(owner_key,run_id,loadout_json) VALUES(?,?,?)').bind(owner,c.run_id,runInsert));
  steps.push(db.prepare('INSERT INTO iap_paid_commands_v2(operation_key,owner_key,payload_digest,result_json) VALUES(?,?,?,?)').bind(key,owner,digest,JSON.stringify(operation)));
  try{await db.batch(steps);}catch(e){const saved=await opOf(db,key);if(saved)return{snapshot:await read(uid),operation:replay(saved)};await eligible(db,owner,now());if(cost&&(await wallet.getSnapshot(uid)).balance<cost)return cancel();if((await rowOf(db,owner))?.revision!==row.revision)return cancel();throw e;}
  return{snapshot:await read(uid),operation};
 }
 return{read,execute};
}
const HEADERS={'content-type':'application/json; charset=utf-8','cache-control':'private, no-store','x-content-type-options':'nosniff','vary':'Authorization, X-Firebase-AppCheck'};
const reply=(status,data)=>new Response(JSON.stringify(data),{status,headers:HEADERS});
export function createPaidGameplayHandlerV2({verifyIdentity=verifyFirebaseHeaders,createService=createPaidGameplayV2}={}){
 return async(request,env)=>{
  if(!['GET','POST'].includes(request.method))return reply(405,{error:'method_not_allowed'});
  if(env?.JADE_IAP_BACKEND_ENABLED!=='true'||env?.JADE_PAID_GAMEPLAY_V2_ENABLED!=='true'||env?.JADE_REFUND_RECONCILIATION_READY!=='true')return reply(503,{error:'paid_gameplay_locked'});
  if(new URL(request.url).search)return reply(400,{error:'unexpected_query'});
  try{
   const identity=await verifyIdentity(request.headers,env);if(!['google.com','anonymous'].includes(identity?.auth?.token?.firebase?.sign_in_provider)||typeof identity?.app?.appId!=='string'||identity.app.appId.length<6)throw new InvalidIdentity();
   const service=createService(env.DB),uid=identity.auth.uid;
   if(request.method==='GET'){if(request.body!==null||request.headers.has('content-length'))fail('invalid_command');return reply(200,{snapshot:await service.read(uid),operation:null});}
   if(!/^application\/json(?:\s*;|$)/i.test(request.headers.get('content-type')??'')||!request.body)fail('invalid_command');
   const reader=request.body.getReader(),parts=[];let size=0;
   try{while(true){const{done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>1024){await reader.cancel();fail('invalid_command');}parts.push(value);}}finally{reader.releaseLock();}
   const bytes=new Uint8Array(size);let at=0;for(const part of parts){bytes.set(part,at);at+=part.length;}
   let input;try{input=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{fail('invalid_command');}
   return reply(200,await service.execute(uid,input));
  }catch(e){
   if(e instanceof InvalidIdentity)return reply(401,{error:'unauthenticated'});
   if(e instanceof RefundHoldErrorRC5&&e.code==='paid_account_on_hold')return reply(423,{error:'paid_account_on_hold'});
   if(e instanceof PaidGameplayErrorV2){if(['invalid_command','invalid_identity'].includes(e.code))return reply(400,{error:'invalid_argument'});if(['initialize_required','retry_after_refresh','refine_not_ready','item_not_owned','idempotency_conflict','legacy_proof_mismatch','legacy_account_not_ready','run_not_found','run_already_exists','run_loadout_unavailable'].includes(e.code))return reply(409,{error:e.code});}
   return reply(503,{error:'paid_gameplay_unavailable'});
  }
 };
}
