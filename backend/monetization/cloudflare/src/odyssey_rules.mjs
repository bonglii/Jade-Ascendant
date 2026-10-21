/** Server-only event rules. No client die, price, balance, victory or ad-success input. */
export class OdysseyError extends Error {constructor(code,status=409){super(code);this.code=code;this.status=status;}}
export const reject=(code,status=409)=>{throw new OdysseyError(code,status);};
export const integer=(v,min,max)=>Number.isSafeInteger(v)&&v>=min&&v<=max;
export const exact=(v,keys)=>{if(!v||typeof v!=='object'||Array.isArray(v)||Object.keys(v).some(k=>!keys.includes(k)))reject('invalid_fields',400);};
export const TILES=['sanctuary','stone','scroll','chest','stone','fork','jade','stone','sanctuary','chest','scroll','stone','fork','jade','stone','chest','sanctuary','scroll','stone','fork'];
export const LIMITS=Object.freeze({free_daily:6,ads_daily:2,paid_daily:10,paid_season:40,max_rolls:152,price_one:25,price_five:100});
export const PREMIUM_LIMITS=Object.freeze({...LIMITS,price_one:10,price_five:40});
export const REWARDS=Object.freeze({tile_stone:20,tile_jade:2,safe_stone:30,challenge_stone:60,seal_24:2,seal_48:3,stone_48:500});
export function definition(input){
 exact(input,['id','starts_at','ends_at','enabled','ads_enabled','purchases_enabled','rewards']);
 if(!/^[a-z0-9_-]{3,48}$/.test(input.id||'')||!integer(input.starts_at,1,4102444800)||input.ends_at!==input.starts_at+14*86400||['enabled','ads_enabled','purchases_enabled'].some(k=>typeof input[k]!=='boolean'))reject('invalid_event',400);
 exact(input.rewards,Object.keys(REWARDS));for(const [key,max] of Object.entries(REWARDS))if(!integer(input.rewards?.[key],0,max))reject('invalid_rewards',400);
 return {id:input.id,starts_at:input.starts_at,ends_at:input.ends_at,enabled:input.enabled,ads_enabled:input.ads_enabled,purchases_enabled:input.purchases_enabled,rewards:Object.fromEntries(Object.keys(REWARDS).map(k=>[k,input.rewards[k]]))};
}
export const initial=()=>({tickets:0,day:'',daily_rolls:0,missions:[],rolls:0,position:0,laps:0,pending:'',battle:null,milestones:[],last_die:0,last_reward:{},notice:'Welcome, cultivator.',daily_ads:0,daily_bought:0,season_bought:0});
export const utcDay=time=>new Date(time*1000).toISOString().slice(0,10);
const add=(r,k,n)=>{if(n>0)r[k]=(r[k]||0)+n;};
export const rewardPresent=r=>(r.spirit_stone||0)>0||(r.celestial_jade||0)>0||(r.pavilion_seal||0)>0||Object.keys(r.items||{}).length>0;
export function transition(inputState,command,event,time,random=()=>crypto.getRandomValues(new Uint32Array(1))[0],limits=LIMITS){
 exact(command,['kind','choice','mission','milestone','pack']);
 const s=structuredClone(inputState),reward={spirit_stone:0,items:{}},pick=n=>{const limit=4294967296-4294967296%n;let value;do{value=random();}while(value>=limit);return value%n;};
 const grace=['milestone','route','counter'].includes(command.kind)?3*86400:0;
 if(!event.enabled||time<event.starts_at||time>=event.ends_at+grace)reject('event_inactive');
 if(s.day!==utcDay(time)){s.day=utcDay(time);s.daily_rolls=0;s.missions=[];s.daily_ads=0;s.daily_bought=0;if(time<event.ends_at)s.tickets+=3;}
 s.last_reward={};let cost=0;
 if(command.kind==='sync')return {state:s,reward,cost};
 if(command.kind==='roll'){
  if(s.pending||s.battle)reject('resolve_tile_first');if(s.tickets<1)reject('no_tickets');if(s.rolls>=LIMITS.max_rolls)reject('journey_complete');
  const die=pick(6)+1;s.tickets--;s.rolls++;s.daily_rolls++;s.last_die=die;const next=s.position+die;s.laps+=Math.floor(next/TILES.length);s.position=next%TILES.length;
  const tile=TILES[s.position];s.notice=tile==='fork'?'Choose your path':tile==='sanctuary'?'Lotus Sanctuary':tile==='jade'?'Celestial Jade discovered':'Supplies discovered';
  if(tile==='fork')s.pending='route';else if(tile==='jade')add(reward,'celestial_jade',event.rewards.tile_jade);else add(reward,'spirit_stone',event.rewards.tile_stone);
 }else if(command.kind==='mission'){
  if(![1,3,5].includes(command.mission)||s.daily_rolls<command.mission||s.missions.includes(command.mission))reject('mission_unavailable');s.missions.push(command.mission);s.tickets++;s.notice='Mission complete · +1 travel seal';
 }else if(command.kind==='route'){
  if(s.pending!=='route'||!['safe','challenge'].includes(command.choice))reject('route_unavailable');s.pending='';
  if(command.choice==='safe'){add(reward,'spirit_stone',event.rewards.safe_stone);s.notice='Quiet Grove · supplies secured';}else{s.battle={turn:0,hits:0,attack:pick(3),opens_at:time+1,deadline:time+15};s.notice='Read the guardian and counter';}
 }else if(command.kind==='counter'){
  const b=s.battle;if(b?.mode==='arena')reject('event_update_required');if(!b||!integer(command.choice,0,2))reject('battle_unavailable');if(time<b.opens_at)reject('guardian_windup');b.hits+=Number(time<=b.deadline&&command.choice===b.attack);b.turn++;
  if(b.turn>=3||time>b.deadline){const win=b.hits>=2;add(reward,'spirit_stone',win?event.rewards.challenge_stone:event.rewards.tile_stone);s.battle=null;s.notice=win?'Guardian defeated':'Base supplies secured';}else{b.attack=pick(3);b.opens_at=time+1;b.deadline=time+15;}
 }else if(command.kind==='milestone'){
  const n=command.milestone;if(![24,48,72].includes(n)||(s.journey_laps_version===2?s.laps<n/6&&(s.journey_legacy_rolls||0)<n:s.rolls<n)||s.milestones.includes(n))reject('milestone_unavailable');s.milestones.push(n);
  if(n===24)add(reward,'pavilion_seal',event.rewards.seal_24);if(n===48){add(reward,'pavilion_seal',event.rewards.seal_48);add(reward,'spirit_stone',event.rewards.stone_48);}if(n===72)reward.items.heavenweaver_compass=1;s.notice=n===72?'Heavenweaver Compass secured in Mail':'Milestone secured in Mail';
 }else if(command.kind==='buy_dice'){
  if(!event.purchases_enabled)reject('purchases_disabled');if(![1,5].includes(command.pack))reject('invalid_pack',400);
  if(s.daily_bought+command.pack>LIMITS.paid_daily||s.season_bought+command.pack>LIMITS.paid_season)reject('purchase_limit');
  if(s.rolls+s.tickets+command.pack>LIMITS.max_rolls)reject('journey_capacity');
  cost=command.pack===1?limits.price_one:limits.price_five;s.tickets+=command.pack;s.daily_bought+=command.pack;s.season_bought+=command.pack;s.notice='Travel seals purchased';
 }else reject('unknown_action',400);
 s.last_reward=reward;return {state:s,reward,cost};
}
