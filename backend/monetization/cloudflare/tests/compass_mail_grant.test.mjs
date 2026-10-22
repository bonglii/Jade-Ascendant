import test from 'node:test';import assert from 'node:assert/strict';
import {readCompassMailGrant} from '../src/compass_mail_grant.mjs';import {service} from '../src/odyssey_service.mjs';import {fixture,time,owner,event} from './odyssey_flow_fixture.mjs';
const key='a'.repeat(64);
test('Compass proof uses only the fixed service and validates response owner/schema',async()=>{
 let calls=0;const env={ODYSSEY_ADMIN_KEY:key,ODYSSEY_PROFILE:{async fetch(url,init){calls++;assert.equal(url,'https://profile.internal/internal/equipment/compass-grant');assert.equal(init.method,'POST');assert.equal(init.headers['x-odyssey-key'],key);assert.deepEqual(JSON.parse(init.body),{owner});assert.ok(init.signal);return Response.json({version:1,owner_binding:owner,compass_authorized:true});}}};
 assert.deepEqual(await readCompassMailGrant(env,owner),{authorized:true,stage:'verified'});assert.equal(calls,1);
 for(const body of [{version:1,owner_binding:'b'.repeat(64),compass_authorized:true},{version:1,owner_binding:owner,compass_authorized:'true'},{version:1,owner_binding:owner,compass_authorized:true,grant:1}]){env.ODYSSEY_PROFILE.fetch=async()=>Response.json(body);assert.deepEqual(await readCompassMailGrant(env,owner),{authorized:false,stage:'unavailable'});}
});
test('missing, broken and oversized service proof never authorizes a weapon',async()=>{
 for(const env of [{},{ODYSSEY_ADMIN_KEY:key,ODYSSEY_PROFILE:{fetch:async()=>{throw Error('offline');}}},{ODYSSEY_ADMIN_KEY:key,ODYSSEY_PROFILE:{fetch:async()=>new Response('x'.repeat(257))}},{ODYSSEY_ADMIN_KEY:key,ODYSSEY_PROFILE:{fetch:async()=>new Response('',{status:403})}}])assert.deepEqual(await readCompassMailGrant(env,owner),{authorized:false,stage:'unavailable'});
});
test('an existing admin grant works for a non-paying account without event milestones or extra rewards',async()=>{
 const f=fixture();try{let seen='';const api=service(f.db,{now:()=>time,economy:4,compassGrant:async value=>{seen=value;return {authorized:true,stage:'verified'};}});const snapshot=await api.read('alice');assert.equal(seen,owner);assert.equal(snapshot.compass_authorized,true);assert.equal(snapshot.state.compass_verification,'verified');assert.deepEqual(snapshot.state.milestones,[]);assert.equal(f.raw.prepare('SELECT COUNT(*) n FROM odyssey_outbox').get().n,0);assert.equal(f.raw.prepare('SELECT COUNT(*) n FROM iap_wallet_events_v1').get().n,0);assert.equal(JSON.parse(f.raw.prepare('SELECT state FROM odyssey_players').get().state).compass_verification,undefined);
 }finally{f.raw.close();}
});
test('proof outages preserve event usability and identify unavailable verification separately from no grant',async()=>{
 const f=fixture();try{const api=service(f.db,{now:()=>time,economy:4,compassGrant:async()=>({authorized:false,stage:'unavailable'})});const snapshot=await api.read('alice');assert.equal(snapshot.compass_authorized,false);assert.equal(snapshot.state.compass_verification,'unavailable');assert.equal(snapshot.event.id,event.id);}finally{f.raw.close();}
});
test('historical earned Compass remains valid without querying admin proof',async()=>{
 const f=fixture();try{const api=service(f.db,{now:()=>time,economy:4,compassGrant:async()=>assert.fail('earned event grant queried admin bridge')});await service(f.db,{now:()=>time,economy:4}).read('alice');const state=JSON.parse(f.raw.prepare('SELECT state FROM odyssey_players').get().state);state.milestones=[72];f.raw.prepare('UPDATE odyssey_players SET state=?').run(JSON.stringify(state));assert.equal((await api.read('alice')).compass_authorized,true);}finally{f.raw.close();}
});
test('a free gift never bypasses holds on a purchase-influenced event state',async()=>{
 const f=fixture();try{await service(f.db,{now:()=>time,economy:4}).read('alice');const state=JSON.parse(f.raw.prepare('SELECT state FROM odyssey_players').get().state);state.season_bought=1;f.raw.prepare('UPDATE odyssey_players SET state=?').run(JSON.stringify(state));f.raw.prepare('INSERT INTO iap_refund_account_holds_v1 VALUES(?,?)').run('u1:'+owner,'held');const api=service(f.db,{now:()=>time,economy:4,compassGrant:async()=>assert.fail('held state reached fallback')});await assert.rejects(api.read('alice'),e=>e.code==='paid_account_on_hold');}finally{f.raw.close();}
});
