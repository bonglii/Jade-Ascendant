import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {TOPUP_BONUSES,bonusSummary,reconcileTopupBonus} from '../src/odyssey_purchase_bonus.mjs';
import {service,account} from '../src/odyssey_service.mjs';
import {REWARDS} from '../src/odyssey_rules.mjs';
const owner=account('alice'),other=account('bob'),time=1800000000;
const event={id:'dragon-test',enabled:true,purchases_enabled:true,starts_at:time-100,ends_at:time-100+14*86400,rewards:REWARDS};
function fixture(){
 const raw=new DatabaseSync(':memory:');raw.exec(`PRAGMA foreign_keys=ON;
 CREATE TABLE iap_wallet_events_v1(event_key TEXT PRIMARY KEY,owner_key TEXT,event_kind TEXT,item_key TEXT,delta INTEGER,created_at TEXT);
 CREATE TABLE iap_play_void_events_v1(token_key TEXT PRIMARY KEY);
 CREATE TABLE iap_refund_account_holds_v1(owner_key TEXT,status TEXT);
 CREATE TABLE iap_play_void_cursor_v1(cursor_name TEXT,watermark_ms INTEGER);
 `);
 for(const migration of ['0013_odyssey.sql','0015_odyssey_topup_bonus.sql'])raw.exec(readFileSync(new URL('../migrations/'+migration,import.meta.url),'utf8'));
 raw.prepare('UPDATE odyssey_bonus_config SET activated_at=?').run(time-50);
 raw.prepare('INSERT INTO odyssey_events VALUES(?,?,?)').run(event.id,JSON.stringify(event),time-100);
 raw.prepare('INSERT INTO iap_play_void_cursor_v1 VALUES(?,?)').run('voided_inapp',time*1000);
 let seq=0,hook=null;
 const db={prepare(sql){let args=[];return{bind(...values){args=values;return this;},async first(){return raw.prepare(sql).get(...args)||null;},async all(){return{results:raw.prepare(sql).all(...args)};},async run(){return raw.prepare(sql).run(...args);},sql,get args(){return args;}};},async batch(steps){if(hook){const h=hook;hook=null;h();}raw.exec('BEGIN');try{const out=steps.map(s=>raw.prepare(s.sql).run(...s.args));raw.exec('COMMIT');return out;}catch(e){raw.exec('ROLLBACK');throw e;}}};
 function credit(pack=0,opts={}){const tier=TOPUP_BONUSES[pack],key='iapv1:'+(++seq).toString(16).padStart(64,'0');raw.prepare("INSERT INTO iap_wallet_events_v1 VALUES(?,?,?,?,?,datetime(?,'unixepoch'))").run(key,'u1:'+(opts.owner||owner),opts.kind||'play_credit',opts.product||tier.product_id,opts.delta??tier.jade,opts.at??time-1);if(opts.voided)raw.prepare('INSERT INTO iap_play_void_events_v1 VALUES(?)').run('playtoken:'+key.slice(6));return key;}
 const eligible=async()=>{if(raw.prepare("SELECT 1 FROM iap_refund_account_holds_v1 WHERE owner_key=? AND status='held'").get('u1:'+owner))throw Error('held');const cursor=raw.prepare('SELECT watermark_ms FROM iap_play_void_cursor_v1').get();if(cursor.watermark_ms<time*1000-7200000)throw Error('stale');};
 return{db,raw,credit,eligible,run:()=>reconcileTopupBonus(db,event,owner,time,eligible),state:()=>{const row=raw.prepare('SELECT state FROM odyssey_players WHERE owner=?').get(owner);return row?JSON.parse(row.state):null;},claims:()=>raw.prepare('SELECT COUNT(*) AS n FROM odyssey_purchase_bonuses').get().n,hook:h=>hook=h};
}
test('six fixed verified Jade packs yield 45 dice; no Jade balance is changed',async()=>{const f=fixture();for(let i=0;i<6;i++)f.credit(i);await f.run();assert.equal(f.state().tickets,45);assert.equal(f.state().bonus_dice,45);assert.equal(f.claims(),6);const b=await bonusSummary(f.db,event,owner,time);assert.equal(b.claimed_total,45);assert(b.offers.every(x=>x.claimed));});
test('restore, repeated reads and repeat purchase of same pack never double credit',async()=>{const f=fixture();f.credit(1);await f.run();for(let i=0;i<3;i++){f.credit(1);await f.run();}assert.equal(f.state().tickets,3);assert.equal(f.claims(),1);});
test('different accounts, old credits, wrong amounts, local events and voided orders are ineligible',async()=>{const f=fixture();f.credit(0,{owner:other});f.credit(1,{at:time-60});f.credit(2,{delta:1});f.credit(3,{kind:'local_reward'});f.credit(4,{voided:true});f.credit(5,{product:'unknown'});await f.run();assert.equal(f.claims(),0);assert.equal(f.state(),null);});
test('disabled, unscheduled and closed promotions do not award',async()=>{for(const e of [null,{...event,enabled:false},{...event,purchases_enabled:false},{...event,starts_at:time+1},{...event,ends_at:time}]){const f=fixture();f.credit();await reconcileTopupBonus(f.db,e,owner,time,f.eligible);assert.equal(f.claims(),0);}});
test('rollout cutoff is stable on migration replay and has no retroactive awards',async()=>{const f=fixture();f.credit(0,{at:time-51});f.raw.exec(readFileSync(new URL('../migrations/0015_odyssey_topup_bonus.sql',import.meta.url),'utf8'));assert.equal(f.raw.prepare('SELECT activated_at FROM odyssey_bonus_config').get().activated_at,time-50);await f.run();assert.equal(f.claims(),0);f.credit();await f.run();assert.equal(f.claims(),1);});
test('refunded account and stale refund monitor refuse paid influence',async()=>{for(const issue of ['held','stale']){const f=fixture();f.credit();if(issue==='held')f.raw.prepare('INSERT INTO iap_refund_account_holds_v1 VALUES(?,?)').run('u1:'+owner,'held');else f.raw.exec('UPDATE iap_play_void_cursor_v1 SET watermark_ms=1');await assert.rejects(f.run());assert.equal(f.claims(),0);}});
test('void arriving after eligibility check rolls the entire award back',async()=>{const f=fixture(),key=f.credit();f.hook(()=>f.raw.prepare('INSERT INTO iap_play_void_events_v1 VALUES(?)').run('playtoken:'+key.slice(6)));await f.run();assert.equal(f.claims(),0);assert.equal(f.state().tickets,0);});
test('hold arriving between check and commit leaves no bonus or receipt',async()=>{const f=fixture();f.credit();f.hook(()=>f.raw.prepare('INSERT INTO iap_refund_account_holds_v1 VALUES(?,?)').run('u1:'+owner,'held'));await assert.rejects(f.run());assert.equal(f.claims(),0);assert.equal(f.state().tickets,0);});
test('event disabled during transaction prevents award until enabled again',async()=>{const f=fixture();f.credit();f.hook(()=>f.raw.prepare('UPDATE odyssey_events SET document=?').run(JSON.stringify({...event,enabled:false})));await assert.rejects(f.run());assert.equal(f.claims(),0);assert.equal(f.state().tickets,0);});
test('over 500 repeated low-tier purchases cannot starve a later higher tier',async()=>{const f=fixture();for(let i=0;i<510;i++)f.credit();f.credit(5);await f.run();assert.equal(f.state().tickets,17);assert.equal(f.claims(),2);});
test('receipts are immutable and uniquely tied to one season/account/pack',async()=>{const f=fixture();f.credit();await f.run();assert.throws(()=>f.raw.exec('DELETE FROM odyssey_purchase_bonuses'));assert.throws(()=>f.raw.exec('UPDATE odyssey_purchase_bonuses SET dice=16'));assert.equal(f.claims(),1);});
test('CAS race retries from latest state without losing existing tickets',async()=>{const f=fixture();f.credit();f.hook(()=>f.raw.exec("UPDATE odyssey_players SET revision=revision+1,state=json_set(state,'$.tickets',7)"));await f.run();assert.equal(f.state().tickets,8);assert.equal(f.claims(),1);});

test('v3 service returns verified bonuses and preserves them during daily sync and exact replay',async()=>{const f=fixture();f.credit(1);const api=service(f.db,{economy:3,now:()=>time});const first=await api.read('alice');assert.equal(first.state.tickets,3);assert.equal(first.purchase_bonus.claimed_total,3);assert.equal(first.limits.price_one,10);const command={event_id:event.id,request_id:'c'.repeat(32),revision:first.revision,action:{kind:'sync'}};const out=await api.execute('alice',command);assert.equal(out.state.tickets,6);assert.equal(out.state.bonus_dice,3);assert.deepEqual(await api.execute('alice',command),out);assert.equal(f.claims(),1);});
test('legacy v1/v2 read paths work without bonus schema and keep their original prices',async()=>{const f=fixture();f.raw.exec('DROP TABLE odyssey_purchase_bonuses;DROP TABLE odyssey_bonus_config;');for(const economy of [1,2]){const out=await service(f.db,{economy,now:()=>time}).read('alice');assert.equal(out.purchase_bonus,undefined);assert.equal(out.limits.price_one,economy===1?25:10);}});
test('an account hold prevents reading or playing previously granted bonus dice',async()=>{const f=fixture();f.credit();const api=service(f.db,{economy:3,now:()=>time});const first=await api.read('alice');f.raw.prepare('INSERT INTO iap_refund_account_holds_v1 VALUES(?,?)').run('u1:'+owner,'held');await assert.rejects(api.read('alice'),e=>e.code==='paid_account_on_hold');await assert.rejects(api.execute('alice',{event_id:event.id,request_id:'c'.repeat(32),revision:first.revision,action:{kind:'roll'}}),e=>e.code==='paid_account_on_hold');assert.equal(f.state().rolls,0);});
test('promotion disabled during commit rolls back every bonus receipt',async()=>{const f=fixture();f.credit();f.hook(()=>f.raw.exec('UPDATE odyssey_bonus_config SET enabled=0'));await assert.rejects(f.run());assert.equal(f.claims(),0);assert.equal(f.state().tickets,0);});

test('mixed legacy/first and half-base purchases keep receipt key and amount from the same event',async()=>{
 const f=fixture();const first=f.credit(0,{delta:100});f.credit(0,{delta:50});
 await f.run();assert.equal(f.state().tickets,1);assert.equal(f.claims(),1);
 const receipt=f.raw.prepare('SELECT credit_event_key FROM odyssey_purchase_bonuses').get();assert.equal(receipt.credit_event_key,first);
 await f.run();assert.equal(f.state().tickets,1);
});
test('all six halved base packs retain their existing one-per-season dice bonus',async()=>{
 const f=fixture();for(let i=0;i<6;i++)f.credit(i,{delta:TOPUP_BONUSES[i].jade/2});
 await f.run();assert.equal(f.state().tickets,45);assert.equal(f.claims(),6);
 for(let i=0;i<6;i++)f.credit(i,{delta:TOPUP_BONUSES[i].jade});
 await f.run();assert.equal(f.state().tickets,45);assert.equal(f.claims(),6);
});
