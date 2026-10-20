import test from 'node:test';import assert from 'node:assert/strict';
import {initial,utcDay,transition} from '../src/odyssey_rules.mjs';
import {flowTransition,BOARD_REWARDS} from '../src/odyssey_flow_rules.mjs';
import {service} from '../src/odyssey_service.mjs';
import {fixture,event,time,owner,other} from './odyssey_flow_fixture.mjs';
const state=()=>({...initial(),day:utcDay(time),task_day:utcDay(time),tickets:150,missions:[],task_claims:[]});
const rollAt=(s,index)=>flowTransition({...s,position:(index+19)%20},{kind:'roll'},event,time,()=>0);
test('two marked board stops each add one Pavilion Seal alongside normal supplies',()=>{
 let s=state(),total=0;
 for(const i of BOARD_REWARDS.seal_tiles){const out=rollAt(s,i);assert.equal(out.reward.pavilion_seal,1);assert.equal(out.reward.spirit_stone,event.rewards.tile_stone);assert.equal(out.state.last_reward.pavilion_seal,1);assert.equal(out.state.daily_gifts,(s.daily_gifts||0)+1);s=out.state;total+=out.reward.pavilion_seal;}
 assert.equal(total,2);assert.deepEqual(s.board_seal_claims,[9,17]);
});
test('every landing across the 152-roll cap awards at most two board seals, including revisits',()=>{
 let s=state(),total=0;s.tickets=152;
 for(let i=0;i<152;i++){const out=rollAt(s,i%20===0?9:i%20===1?17:1);s=out.state;total+=out.reward.pavilion_seal||0;}
 assert.equal(total,2);assert.equal(s.rolls,152);assert.equal(s.tickets,0);assert.throws(()=>rollAt(s,9));
});
test('day reset and reconnect preserve collected stops; a new event owner starts empty',()=>{
 const a=rollAt(state(),9).state;assert.equal(rollAt(a,9).reward.pavilion_seal,undefined);
 const next=flowTransition(a,{kind:'sync'},event,time+86400).state;
 assert.deepEqual(next.board_seal_claims,[9]);assert.equal(rollAt(next,9).reward.pavilion_seal,undefined);
 assert.equal(rollAt(state(),9).reward.pavilion_seal,1);
});
test('legacy client economy and ordinary stops preserve existing grants and fields',()=>{
 const a=transition({...state(),position:8},{kind:'roll'},event,time,()=>0);assert.equal(a.reward.pavilion_seal,undefined);
 for(const i of [0,1,2,3,4,6,7,8,10,11,13,14,15,16,18])assert.equal(rollAt(state(),i).reward.pavilion_seal,undefined);
 assert.equal(BOARD_REWARDS.max_seals,2);
});
test('server snapshot declares the stops, and client-supplied rewards or stop claims are rejected',async()=>{
 const f=fixture(),api=service(f.db,{economy:4,now:()=>time});const a=await api.read('alice');assert.deepEqual(a.board_rewards,BOARD_REWARDS);
 for(const action of [{kind:'roll',pavilion_seal:100},{kind:'roll',board_seal_claims:[]},{kind:'board_claim',tile:9}])await assert.rejects(api.execute('alice',{event_id:event.id,request_id:'1'.repeat(32),revision:a.revision,action}));
 assert.equal(f.raw.prepare('SELECT COUNT(*) n FROM odyssey_outbox').get().n,0);
});
test('actual SQLite service commits seal, state and outbox once; exact request replay cannot grant twice',async()=>{
 const f=fixture(),api=service(f.db,{economy:4,now:()=>time,rng:()=>0});await api.read('alice');f.raw.prepare('UPDATE odyssey_players SET state=? WHERE owner=?').run(JSON.stringify({...state(),position:8}),owner);
 const a=await api.read('alice'),cmd={event_id:event.id,request_id:'2'.repeat(32),revision:a.revision,action:{kind:'roll'}};
 const out=await api.execute('alice',cmd);assert.equal(out.state.last_reward.pavilion_seal,1);assert.deepEqual(out.board_rewards,BOARD_REWARDS);assert.deepEqual(await api.execute('alice',cmd),out);
 const rows=f.raw.prepare('SELECT reward,owner FROM odyssey_outbox').all();assert.equal(rows.length,1);assert.equal(rows[0].owner,owner);assert.equal(JSON.parse(rows[0].reward).pavilion_seal,1);
 await assert.rejects(api.execute('alice',{...cmd,request_id:'3'.repeat(32)}),e=>e.code==='revision_changed');
 const bob=await api.read('bob');assert.equal(bob.owner_binding,other);assert.equal(bob.state.board_seal_claims,undefined);
});
test('concurrent different request ids competing for the same revision retain one outbox grant',async()=>{
 const f=fixture(),api=service(f.db,{economy:4,now:()=>time,rng:()=>0});await api.read('alice');f.raw.prepare('UPDATE odyssey_players SET state=? WHERE owner=?').run(JSON.stringify({...state(),position:16}),owner);const a=await api.read('alice');
 const results=await Promise.allSettled(['4','5'].map(n=>api.execute('alice',{event_id:event.id,request_id:n.repeat(32),revision:a.revision,action:{kind:'roll'}})));
 assert.equal(results.filter(x=>x.status==='fulfilled').length,1);assert.equal(f.raw.prepare('SELECT COUNT(*) n FROM odyssey_outbox').get().n,1);assert.deepEqual(f.state().board_seal_claims,[17]);
});
test('HTTP seal metadata stays inside state accepted by the installed closed native envelope, with immutable journal replay',async()=>{
 const {odysseyRoute}=await import('../src/odyssey_http.mjs');const {readFileSync}=await import('node:fs');
 const source=readFileSync(new URL('../../android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/OdysseyContractV1.kt',import.meta.url),'utf8');
 const allowed=new Set([...source.match(/require\(keys\(raw\)\.all\{it in setOf\(([^\n]+?)\)\}\)/)[1].matchAll(/"([^"]+)"/g)].map(x=>x[1]));
 const f=fixture(),previous=Date.now;Date.now=()=>time*1000;
 try{
  const get=()=>odysseyRoute(new Request('https://worker.test/v4/odyssey'),{DB:f.db},undefined,'alice');const first=await (await get()).json();
  assert(Object.keys(first).every(k=>allowed.has(k)));assert.deepEqual(first.state.board_rewards,BOARD_REWARDS);assert.equal(first.board_rewards,undefined);
  f.raw.prepare('UPDATE odyssey_players SET state=? WHERE owner=?').run(JSON.stringify({...state(),position:8}),owner);
  // The real HTTP route obtains entropy on the server. Repeated reads must not
  // award the stop, alter the reward state, or write a delivery receipt.
  await get();await get();assert.equal(f.raw.prepare('SELECT COUNT(*) n FROM odyssey_outbox').get().n,0);
  const api=service(f.db,{economy:4,now:()=>time,rng:()=>0}),before=await api.read('alice'),cmd={event_id:event.id,request_id:'6'.repeat(32),revision:before.revision,action:{kind:'roll'}};
  await api.execute('alice',cmd);const journal=f.raw.prepare('SELECT response FROM odyssey_actions WHERE request_id=?').get(cmd.request_id).response;
  const replay=await odysseyRoute(new Request('https://worker.test/v4/odyssey',{method:'POST',body:JSON.stringify(cmd)}),{DB:f.db},undefined,'alice');
  assert.equal(replay.status,200);const body=await replay.json();assert(Object.keys(body).every(k=>allowed.has(k)));assert.deepEqual(body.state.board_seal_claims,[9]);assert.deepEqual(body.state.board_rewards,BOARD_REWARDS);
  assert.equal(f.raw.prepare('SELECT response FROM odyssey_actions WHERE request_id=?').get(cmd.request_id).response,journal);assert.equal(f.raw.prepare('SELECT COUNT(*) n FROM odyssey_outbox').get().n,1);
 }finally{Date.now=previous;}
});
