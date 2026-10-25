import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {calendar,readCalendar} from '../monetization/cloudflare/src/event_calendar.mjs';
import {publishEvent} from '../monetization/cloudflare/src/odyssey_service.mjs';
import {REWARDS} from '../monetization/cloudflare/src/odyssey_rules.mjs';
import {publish} from '../monetization/cloudflare/src/heavenly_trials.mjs';
import {SNAPSHOT_SQL,planRepair,verify} from './repair_event_calendar.mjs';
const start=1792357200,WEEK=604800;
const odyssey=(extra={})=>({id:'odyssey-one',starts_at:start,ends_at:start+14*86400,enabled:true,ads_enabled:false,purchases_enabled:false,rewards:REWARDS,...extra});
const trials=(extra={})=>({id:'trials-one',starts_at:start,enabled:true,ads_enabled:false,shop_enabled:false,themes:['jade_wind','scarlet_rite','starfall','froststep','sunforge'],reward:{celestial_jade:40,pavilion_seal:1,spirit_stone:600},...extra});
function fixture(){
 const raw=new DatabaseSync(':memory:');raw.exec('CREATE TABLE odyssey_events(id TEXT PRIMARY KEY,document TEXT,created_at INTEGER);CREATE TABLE odyssey_players(event_id TEXT,owner TEXT);CREATE TABLE ht_campaigns(id TEXT PRIMARY KEY,document TEXT,created_at INTEGER);CREATE TABLE ht_weeks(id TEXT,campaign TEXT);CREATE TABLE ht_audit(campaign TEXT,action TEXT,document TEXT,created_at INTEGER);');
 const db={prepare(sql){return{sql,args:[],bind(...args){return{...this,args}},async first(){return raw.prepare(this.sql).get(...this.args)||null},async all(){return{results:raw.prepare(this.sql).all(...this.args)}},async run(){return raw.prepare(this.sql).run(...this.args)}}},async batch(steps){raw.exec('BEGIN');try{const out=steps.map(s=>raw.prepare(s.sql).run(...s.args));raw.exec('COMMIT');return out}catch(e){raw.exec('ROLLBACK');throw e}}};
 return{db,raw,close:()=>raw.close(),put(kind,c){raw.prepare('INSERT INTO '+(kind==='odyssey'?'odyssey_events':'ht_campaigns')+' VALUES(?,?,?)').run(c.id,JSON.stringify(c),start)},snapshot(){return raw.prepare(SNAPSHOT_SQL).all()}};
}
test('off events reserve no slot and empty calendar creates no data',async()=>{const f=fixture();try{assert.deepEqual((await readCalendar(f.db,start)).slots,[]);f.put('odyssey',odyssey({enabled:false}));await publish(f.db,trials(),start);assert.equal((await readCalendar(f.db,start)).conflicts.length,0)}finally{f.close()}});
test('cross-event publish is rejected atomically and pausing always remains possible',async()=>{const f=fixture();try{await publishEvent(f.db,odyssey(),start);await assert.rejects(publish(f.db,trials(),start),/event_schedule_conflict/);assert.equal(f.raw.prepare('SELECT COUNT(*) n FROM ht_campaigns').get().n,0);await publishEvent(f.db,odyssey({enabled:false}),start);await publish(f.db,trials(),start);await assert.rejects(publishEvent(f.db,odyssey(),start),/event_schedule_conflict/)}finally{f.close()}});
test('concurrent publishes into initially empty tables have only one winner',async()=>{const f=fixture();try{const r=await Promise.allSettled([publishEvent(f.db,odyssey(),start),publish(f.db,trials(),start)]);assert.equal(r.filter(x=>x.status==='fulfilled').length,1);assert.equal((await readCalendar(f.db,start)).conflicts.length,0)}finally{f.close()}});
test('Odyssey reserves the earned-claim window; future weekly reset after it is allowed',async()=>{const f=fixture();try{await publishEvent(f.db,odyssey(),start);await assert.rejects(publish(f.db,trials({starts_at:start+2*WEEK}),start),/event_schedule_conflict/);await publish(f.db,trials({starts_at:start+3*WEEK}),start);assert.equal((await readCalendar(f.db,start)).conflicts.length,0)}finally{f.close()}});
test('no-overlap and no-event repair are verified no-ops',()=>{const f=fixture();try{let rows=f.snapshot(),p=planRepair(rows);assert.equal(p.kind,'skip');assert.equal(p.sql,null);assert.equal(verify(rows,p).changed.length,0);f.put('odyssey',odyssey({enabled:false}));rows=f.snapshot();p=planRepair(rows);assert.equal(p.reason,'NO_OVERLAP');assert.equal(verify(rows,p).status,'skipped')}finally{f.close()}});
test('only conflicting unfrozen schedule time is changed, and rerun does not move it twice',()=>{const f=fixture();try{const now=f.snapshot()[0].server_now;const monday=Math.floor((now+270000)/WEEK)*WEEK-270000;f.put('odyssey',odyssey({starts_at:monday,ends_at:monday+14*86400}));f.put('trials',trials({starts_at:monday}));const before=f.snapshot(),p=planRepair(before);assert.equal(p.kind,'repair');assert.equal(p.changes.length,1);const old=JSON.parse(p.changes[0].before),after=JSON.parse(p.changes[0].after);assert.deepEqual({...after,starts_at:old.starts_at},old);f.raw.exec(p.sql);assert.equal(verify(f.snapshot(),p).status,'repaired');assert.equal(planRepair(f.snapshot()).kind,'skip');assert.equal(f.raw.prepare('SELECT COUNT(*) n FROM odyssey_players').get().n,0)}finally{f.close()}});
test('frozen weeks and changed admin documents cannot be overwritten by a repair',()=>{const f=fixture();try{const now=f.snapshot()[0].server_now,monday=Math.floor((now+270000)/WEEK)*WEEK-270000;f.put('odyssey',odyssey({starts_at:monday,ends_at:monday+14*86400}));f.put('trials',trials({starts_at:monday}));let p=planRepair(f.snapshot());f.raw.prepare('INSERT INTO ht_weeks VALUES(?,?)').run('frozen','trials-one');assert.throws(()=>planRepair(f.snapshot()),/FROZEN_PROGRESS/);f.raw.exec(p.sql);assert.throws(()=>verify(f.snapshot(),p));f.raw.exec('DELETE FROM ht_weeks');p=planRepair(f.snapshot());f.raw.prepare('UPDATE ht_campaigns SET document=?').run(JSON.stringify(trials({starts_at:monday,enabled:false})));f.raw.exec(p.sql);assert.throws(()=>verify(f.snapshot(),p));assert.equal(JSON.parse(f.raw.prepare('SELECT document FROM ht_campaigns').get().document).enabled,false)}finally{f.close()}});
test('a snapshot without a trusted database clock is rejected',()=>assert.throws(()=>planRepair([]),/clock/));

test('production router exposes only keyed GET calendar and keeps all live gates',async()=>{
 const {createProductionWorkerV2,PRODUCTION_GATES_V2}=await import('../monetization/cloudflare/src/worker_paid_production_v2.mjs');
 const f=fixture(),key='a'.repeat(64),env={DB:f.db,ODYSSEY_ADMIN_KEY:key,...Object.fromEntries(PRODUCTION_GATES_V2.map(k=>[k,'true']))};
 const worker=createProductionWorkerV2({verifyIdentity(){throw Error('calendar must not authenticate a player')}}),url='https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/internal/trials/calendar';
 try{
  assert.equal((await worker.fetch(new Request(url),env)).status,403);
  assert.equal((await worker.fetch(new Request(url,{method:'POST',headers:{'x-odyssey-key':key}}),env)).status,405);
  const r=await worker.fetch(new Request(url,{headers:{'x-odyssey-key':key}}),env);assert.equal(r.status,200);assert.deepEqual((await r.json()).slots,[]);
  assert.equal(f.raw.prepare('SELECT COUNT(*) n FROM odyssey_events').get().n,0);
  assert.equal((await worker.fetch(new Request(url,{headers:{'x-odyssey-key':key}}),{...env,JADE_IAP_BACKEND_ENABLED:'false'})).status,503);
 }finally{f.close()}
});
test('Profile calendar proxy is GET only with fixed internal authority',async()=>{
 const {eventCalendarAdmin}=await import('./heavenly_trials.mjs');let calls=0;const env={ODYSSEY_ADMIN_KEY:'a'.repeat(64),ODYSSEY_IAP:{fetch(url,options){calls++;assert.equal(url,'https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/internal/trials/calendar');assert.equal(options.method,'GET');assert.equal(options.headers['x-odyssey-key'],env.ODYSSEY_ADMIN_KEY);return new Response('{}')}}};
 assert.equal((await eventCalendarAdmin(new Request('https://profile/admin/api/event-calendar',{method:'POST'}),env)).status,405);
 assert.equal(calls,0);assert.equal((await eventCalendarAdmin(new Request('https://profile/admin/api/event-calendar'),env)).status,200);assert.equal(calls,1);
});
