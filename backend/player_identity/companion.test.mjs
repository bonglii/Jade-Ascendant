import test from 'node:test';
import assert from 'node:assert/strict';
import {validateEvents,publishedAgenda,createCompanionHandler} from './companion.mjs';

const t=1800000000;
const event=(id,kind='stage_enter',chapter=1,stage=1,seconds=0)=>({id:id.repeat(32),kind,chapter,stage,seconds});
test('opt-in telemetry rejects unknown, duplicate and malformed events',()=>{
 assert.deepEqual(validateEvents({version:1,events:[event('a')]}),[event('a')]);
 for(const events of [[],[event('a'),event('a')],[{...event('a'),extra:true}],[event('z')],[event('a','stage_enter',2,6)],[event('a','session_start',1,1)],[event('a','stage_enter',1,1,-1)]])assert.throws(()=>validateEvents({version:1,events}));
 assert.throws(()=>validateEvents({version:1,events:[event('a')],owner_binding:'untrusted'}));
});
test('only published, active and upcoming events appear in public agenda',async()=>{
 const env={ODYSSEY_ADMIN_KEY:'local-only',ODYSSEY_IAP:{async fetch(url){if(url.endsWith('/internal/trials/operations'))return Response.json({calendar:[{status:'draft',theme:'private',starts_at:t+30,ends_at:t+300},{status:'scheduled',theme:'jade_sanctum',starts_at:t+60,ends_at:t+360},{status:'live',theme:'expired',starts_at:t-500,ends_at:t-1}]});return Response.json({event:{enabled:true,starts_at:t+10,ends_at:t+120}});}}};
 const agenda=await publishedAgenda(env,t);
 assert.equal(agenda.events.length,2);assert.equal(agenda.partial,false);
 assert.ok(agenda.events.every(e=>!e.title.includes('private')));
 assert.equal((await publishedAgenda({},t)).partial,true);
});
test('unauthenticated metrics and unsupported agenda methods fail closed',async()=>{
 const handler=createCompanionHandler({verify:async()=>{throw Object.assign(new Error('denied'),{status:401,code:'auth_required'});},now:()=>t});
 assert.equal((await handler(new Request('https://example.test/v1/player/gameplay-metrics',{method:'DELETE'}),{PROFILE_DB:{}})).status,401);
 assert.equal((await handler(new Request('https://example.test/v1/player/agenda',{method:'POST'}),{})).status,405);
 assert.equal((await handler(new Request('https://example.test/v1/player/agenda'),{})).status,200);
});

test('agenda omits malformed calendars and does not expose admin-only labels',async()=>{
 const bad=[
   {status:'draft',theme:'classified',starts_at:t+10,ends_at:t+30},
   {status:'scheduled',theme:'<script>private</script>',starts_at:t+10,ends_at:t+30},
   {status:'scheduled',theme:'x'.repeat(200),starts_at:t+10,ends_at:t+30},
   {status:'scheduled',theme:'jade_sanctum',starts_at:t+40,ends_at:t+20},
   {status:'scheduled',theme:'jade_sanctum',starts_at:t+40,ends_at:t+60},
 ];
 const env={ODYSSEY_ADMIN_KEY:'qa-key',ODYSSEY_IAP:{async fetch(url){
   if(url.endsWith('/internal/trials/operations'))return Response.json({calendar:bad});
   return Response.json({event:{enabled:true,starts_at:t+90,ends_at:t+80}});
 }}};
 const result=await publishedAgenda(env,t);
 assert.equal(result.events.length,1);
 assert.equal(result.events[0].title,'Heavenly Trials · jade sanctum');
 assert.equal(result.events[0].status,'scheduled');
 assert.equal(result.events[0].starts_at,t+40);
});
