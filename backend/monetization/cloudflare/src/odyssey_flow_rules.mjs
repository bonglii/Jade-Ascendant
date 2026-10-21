import {transition,utcDay,TILES,reject,exact,integer,PREMIUM_LIMITS} from './odyssey_rules.mjs';
import {replayArena} from './odyssey_arena.mjs';
export const BOARD_REWARDS=Object.freeze({seal_tiles:Object.freeze([9,17]),seal_per_stop:1,max_seals:2,repeat:"once_per_event"});
const add=(r,k,n)=>{r[k]=(r[k]||0)+n;};
export function flowState(input,time){
 const s=structuredClone(input);
 if(s.journey_laps_version!==2){s.journey_laps_version=2;s.journey_legacy_rolls=Number.isSafeInteger(s.rolls)?s.rolls:0;}
 if(s.task_day!==utcDay(time)){s.task_day=utcDay(time);s.daily_gifts=0;s.daily_guardians=0;s.task_claims=[];}
 // Legacy/partial JSON states must not serialize undefined++ as NaN/null.
 for(const key of ['daily_gifts','daily_guardians'])if(!Number.isSafeInteger(s[key])||s[key]<0)s[key]=0;
 s.task_claims=Array.isArray(s.task_claims)?[...new Set(s.task_claims.filter(x=>['gifts','guardian'].includes(x)))]:[];
 return s;
}
export const taskReady=(s,id)=>id==='gifts'?s.daily_gifts>=3:id==='guardian'?s.daily_guardians>=1:false;
export function flowTransition(input,command,event,time,rng,prices=PREMIUM_LIMITS){
 const state=flowState(input,time),kind=command?.kind;
 if(['task','missions_all','arena_finish'].includes(kind)){
  exact(command,kind==='task'?['kind','task']:kind==='arena_finish'?['kind','trace','abandon']:['kind']);
  if(kind==='arena_finish'&&(!event.enabled||time<event.starts_at||time>=event.ends_at+3*86400))reject('event_inactive');
  const out=kind==='arena_finish'?{state,reward:{spirit_stone:0,items:{}},cost:0}:transition(state,{kind:'sync'},event,time,rng,prices),s=out.state;
  if(kind==='arena_finish'){
   if(!s.battle||s.battle.mode!=='arena')reject('arena_unavailable');
   let result;try{result=replayArena(s.battle,command.trace,{stamp:time,abandon:command.abandon});}catch(e){reject(e.message,400);}
   s.battle=null;s.notice=result.won?'Guardian defeated':'Base supplies secured';add(out.reward,'spirit_stone',result.won?event.rewards.challenge_stone:event.rewards.tile_stone);
   if(result.won)s.daily_guardians++;
  }else{
   let count=0;
   if(kind==='missions_all')for(const n of [1,3,5])if(s.daily_rolls>=n&&!s.missions.includes(n)){s.missions.push(n);s.tickets++;count++;}
   const ids=kind==='task'?[command.task]:['gifts','guardian'];
   for(const id of ids){if(!['gifts','guardian'].includes(id))reject('invalid_task',400);if(taskReady(s,id)&&!s.task_claims.includes(id)){s.task_claims.push(id);add(out.reward,'spirit_stone',id==='gifts'?30:60);count++;}else if(kind==='task')reject('mission_unavailable');}
   if(!count)reject('mission_unavailable');s.notice=count===1?'Daily reward secured':'Available daily rewards secured';
  }
  s.last_reward=out.reward;return out;
 }
 const out=transition(state,command,event,time,rng,prices),s=out.state;
 if(kind==='roll'&&['stone','scroll','chest','jade'].includes(TILES[s.position]))s.daily_gifts++;
 if(kind==='roll'&&BOARD_REWARDS.seal_tiles.includes(s.position)){
  // JSON state and the existing reward outbox commit in the same CAS batch.
  // Keep base supplies. Each marked stop adds a seal once for this event owner.
  const claimed=Array.isArray(s.board_seal_claims)?s.board_seal_claims.filter(x=>BOARD_REWARDS.seal_tiles.includes(x)):[];
  if(!claimed.includes(s.position)){
   s.board_seal_claims=[...new Set([...claimed,s.position])];add(out.reward,'pavilion_seal',BOARD_REWARDS.seal_per_stop);
   s.notice='Pavilion Seal discovered · secured in Mail';s.last_reward=out.reward;
  }
 }

 if(kind==='route'&&command.choice==='challenge'){
  // The die and encounter seed are server-generated. Old encounters retain the
  // legacy counter route; only new v4 encounters create a movable arena.
  const seed=(rng? rng():crypto.getRandomValues(new Uint32Array(1))[0])&0x7fffffff;
  s.battle={mode:'arena',seed,started_at:time,deadline:time+180,attack:0,turn:0,hits:0,opens_at:time};
  s.notice='Dragon Gate arena opened';
 }
 if(kind==='counter'&&s.battle===null&&s.notice==='Guardian defeated')s.daily_guardians++;
 return out;
}
