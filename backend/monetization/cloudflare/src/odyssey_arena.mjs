/** Deterministic preset event combat. No client HP, damage, reward or victory flag. */
export const ARENA_TPS=20,ARENA_MAX_TICKS=600;
const vectors=[[0,0],[0,-12],[9,-9],[12,0],[9,9],[0,12],[-9,9],[-12,0],[-9,-9]];
const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
export function arenaInitial(seed){if(!Number.isSafeInteger(seed)||seed<0||seed>2147483647)throw Error('arena_seed');return {seed,t:0,x:512,y:820,bx:512,by:250,aim_x:512,aim_y:820,hp:5,boss_hp:16,last_hit:-1,done:false,won:false};}
export function arenaStep(s,input){
 if(s.done||!Number.isInteger(input)||input<0||input>8)throw Error('arena_input');
 const v=vectors[input];s.t++;s.x=clamp(s.x+v[0],48,976);s.y=clamp(s.y+v[1],80,944);
 s.bx=clamp(s.bx+Math.sign(s.x-s.bx)*2,100,924);s.by=clamp(s.by+Math.sign(s.y-s.by)*2,100,720);
 const phase=(s.t-1)%60,round=Math.floor((s.t-1)/60),pattern=(s.seed+round)%3;
 if(phase===0){s.aim_x=s.x;s.aim_y=s.y;}
 const dx=s.x-s.bx,dy=s.y-s.by;
 if(s.t%15===0&&dx*dx+dy*dy<=420*420)s.boss_hp--;
 let hit=false;
 if(pattern===0&&phase===30)hit=(s.x-s.aim_x)**2+(s.y-s.aim_y)**2<=115**2;
 if(pattern===1&&phase===30)hit=Math.abs(s.y-s.aim_y)<=72;
 if(pattern===2&&phase>=30&&phase<=50){const distance=Math.sqrt(dx*dx+dy*dy),radius=(phase-29)*32;hit=Math.abs(distance-radius)<=48;}
 if(hit&&s.last_hit!==round){s.hp--;s.last_hit=round;}
 if(s.hp<=0||s.boss_hp<=0||s.t>=ARENA_MAX_TICKS){s.done=true;s.won=s.boss_hp<=0&&s.hp>0;}
 return s;
}
export function replayArena(battle,trace,{stamp,abandon=false}={}){
 if(!battle||battle.mode!=='arena'||typeof trace!=='string'||trace.length>ARENA_MAX_TICKS||!/^[0-8]*$/.test(trace)||typeof abandon!=='boolean')throw Error('invalid_arena_trace');
 const s=arenaInitial(battle.seed);
 if(!Number.isSafeInteger(stamp)||stamp<battle.started_at||trace.length>(stamp-battle.started_at)*ARENA_TPS+40)throw Error('arena_too_fast');
 for(const digit of trace)arenaStep(s,Number(digit));
 if(!s.done&&!abandon)throw Error('arena_incomplete');
 return {...s,won:s.won&&!abandon&&stamp<=battle.deadline};
}
