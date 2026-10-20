import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync,writeFileSync} from 'node:fs';
import {fixture,event,time} from './odyssey_flow_fixture.mjs';import {service} from '../src/odyssey_service.mjs';import {odysseyRoute} from '../src/odyssey_http.mjs';import {odysseyWire} from '../src/odyssey_wire.mjs';
const envValues={ODYSSEY_AD_UNIT:'ca-app-pub-3082528078187093/8339864838',ODYSSEY_AD_REWARD_ITEM:'Dice'};
const nativeSource=readFileSync(new URL('../../android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/OdysseyContractV1.kt',import.meta.url),'utf8');
const allowed=new Set([...nativeSource.match(/require\(keys\(raw\)\.all\{it in setOf\(([^\n]+?)\)\}\)/)[1].matchAll(/"([^"]+)"/g)].map(x=>x[1]));
const closed=data=>Object.keys(data).every(k=>allowed.has(k)),corpus=[];
function record(name,data,accepted=true){corpus.push({name,accepted,data:structuredClone(data)});}
function setup(){const f=fixture();return {...f,api:service(f.db,{economy:4,now:()=>time})};}
test('reproduce native rejection and normalize read without mutating source or weakening root allowlist',async()=>{
 const f=setup(),before=await f.api.read('alice'),saved=JSON.stringify(before);assert.equal(closed(before),false);record('old_root_rejected',before,false);
 const after=odysseyWire(before,envValues);assert.ok(closed(after));assert.equal(after.state.ad_delivery.expected_unit,envValues.ODYSSEY_AD_UNIT);assert.equal(JSON.stringify(before),saved);record('read',after);
 record('wrong_owner',{...after,owner_binding:'f'.repeat(64)},false);record('bad_price',{...after,limits:{...after.limits,price_one:0}},false);record('unknown_root',{...after,unexpected:true},false);
});
test('all receipt stages preserve currency state and legacy responses',async()=>{
 const f=setup(),base=await f.api.read('alice');for(const stage of ['none','pending','credited','expired','configuration_required']){
  const ad={configured:stage!=='configuration_required',stage,...(['pending','credited','expired'].includes(stage)?{nonce:'d'.repeat(32),expires_at:time+1200}:{})};
  const after=odysseyWire({...base,ad_delivery:ad},envValues);assert.ok(closed(after));assert.equal(after.state.tickets,base.state.tickets);assert.equal(after.state.daily_ads,base.state.daily_ads);record(stage,after);
 }const legacy={...base};delete legacy.ad_delivery;delete legacy.board_rewards;assert.deepEqual(odysseyWire(legacy,envValues),legacy);record('legacy',legacy);
});
test('actual HTTP GET, fresh POST and old journal replay all normalize; persisted receipt stays byte-identical',async()=>{
 const f=setup(),env={DB:f.db,...envValues},previous=Date.now;Date.now=()=>time*1000;
 try{
  const read=await odysseyRoute(new Request('https://worker.test/v4/odyssey'),env,undefined,'alice');assert.equal(read.status,200);const initial=await read.json();assert.ok(closed(initial));record('http_get',initial);
  const cmd={event_id:event.id,request_id:'1'.repeat(32),revision:initial.revision,action:{kind:'sync'}};const stored=await f.api.execute('alice',cmd);assert.ok(stored.ad_delivery);
  const journal=f.raw.prepare('SELECT response FROM odyssey_actions WHERE request_id=?').get(cmd.request_id).response;
  const post=body=>odysseyRoute(new Request('https://worker.test/v4/odyssey',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)}),env,undefined,'alice');
  const a=await post(cmd),b=await post(cmd);assert.equal(a.status,200);assert.equal(b.status,200);const av=await a.json();assert.deepEqual(av,await b.json());assert.ok(closed(av));assert.ok(av.state.ad_delivery);record('old_replay',av);
  assert.equal(f.raw.prepare('SELECT response FROM odyssey_actions WHERE request_id=?').get(cmd.request_id).response,journal);assert.equal(f.raw.prepare('SELECT COUNT(*) n FROM odyssey_actions').get().n,1);
  const fresh=await post({...cmd,request_id:'2'.repeat(32),revision:av.revision});assert.equal(fresh.status,200);const nv=await fresh.json();assert.ok(closed(nv));record('fresh_post',nv);
 }finally{Date.now=previous;}
});
test('nonce contract, no-event, disabled-event and v1/v2/v3 remain supported',async()=>{
 const f=setup();f.raw.prepare('UPDATE odyssey_events SET document=?').run(JSON.stringify({...event,ads_enabled:true}));const before=await f.api.read('alice'),intent=await f.api.execute('alice',{event_id:event.id,request_id:'3'.repeat(32),revision:before.revision,action:{kind:'ad_intent'}}),after=odysseyWire(intent,envValues);assert.deepEqual(after.ad_intent,intent.ad_intent);record('intent',after);
 f.raw.prepare('UPDATE odyssey_events SET document=?').run(JSON.stringify({...event,enabled:false}));record('disabled',odysseyWire(await f.api.read('alice'),envValues));
 f.raw.prepare('DELETE FROM odyssey_ad_intents').run();f.raw.prepare('DELETE FROM odyssey_actions').run();f.raw.prepare('DELETE FROM odyssey_players').run();f.raw.prepare('DELETE FROM odyssey_events').run();record('no_event',odysseyWire(await f.api.read('alice'),envValues));
 for(const economy of [1,2,3]){const data=await service(f.db,{economy,now:()=>time}).read('alice');assert.ok(closed(data));assert.ok(!data.state.ad_delivery);record('v'+economy,data);}
});
test('HTTP errors retain authentication/invalid request failures',async()=>{
 const f=setup(),env={DB:f.db,...envValues};assert.equal((await odysseyRoute(new Request('https://worker.test/v4/odyssey'),env,undefined,null)).status,401);
 const bad=await odysseyRoute(new Request('https://worker.test/v4/odyssey',{method:'POST',body:'{}'}),env,undefined,'alice');assert.notEqual(bad.status,200);assert.ok(!('state' in await bad.json()));
});
test('export exact HTTP/service corpus for original Kotlin regression',()=>{if(process.env.JADE_WIRE_CORPUS)writeFileSync(process.env.JADE_WIRE_CORPUS,JSON.stringify(corpus,null,2));assert.ok(corpus.length>=19);});
