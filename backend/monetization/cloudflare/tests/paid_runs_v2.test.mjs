import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {fixture,command,UID,NOW,owner} from './fixtures/paid_gameplay_v2.mjs';
import {createPaidGameplayV2} from '../src/paid_gameplay_v2.mjs';
const each=fn=>async()=>{const f=fixture();try{await f.init();const s=JSON.parse(f.sql.prepare('SELECT state_json FROM iap_paid_gameplay_v2').get().state_json);s.inventory={jade_binding_chain:3,cloudstep_boots:2};s.stars={jade_binding_chain:3,cloudstep_boots:2};s.slots.armament='jade_binding_chain';s.slots.boots='cloudstep_boots';f.sql.prepare('UPDATE iap_paid_gameplay_v2 SET state_json=?').run(JSON.stringify(s));await fn(f);}finally{f.close();}};
const start=(rev=0,id=randomUUID(),level=12)=>command('run_start',rev,{run_id:id,weapon_level:level});
const resume=(id,rev)=>command('run_resume',rev,{run_id:id});
test('run selection persists on server and consumes no additional wallet credit',each(async f=>{
 const a=await f.service.execute(UID,start());assert.equal(a.snapshot.wallet.balance,2400);assert.equal(a.snapshot.revision,1);assert.equal(a.operation.outcome.slots.armament,'jade_binding_chain');assert.equal(a.operation.outcome.weapon_level,12);
 assert.equal(f.sql.prepare('SELECT COUNT(*) n FROM iap_paid_runs_v2').get().n,1);
}));
test('Continue after service recreation restores original selection and stars, not current hub',each(async f=>{
 const c=start(),a=await f.service.execute(UID,c);
 await f.service.execute(UID,command('equip',1,{slot:'armament',item_id:''}));
 await f.service.execute(UID,command('refine',2,{item_id:'jade_binding_chain'}));
 const restarted=createPaidGameplayV2(f.db,{now:()=>NOW});const b=await restarted.execute(UID,resume(c.run_id,3));
 assert.deepEqual(b.operation.outcome,a.operation.outcome);assert.equal(b.snapshot.slots.armament,'');assert.equal(b.snapshot.stars.jade_binding_chain,4);assert.equal(b.operation.outcome.stars.jade_binding_chain,3);
}));
test('replaying a run request does not duplicate run or revision',each(async f=>{
 const c=start(),a=await f.service.execute(UID,c),b=await f.service.execute(UID,c);assert.deepEqual(a,b);assert.equal(b.snapshot.revision,1);
 await assert.rejects(f.service.execute(UID,{...c,weapon_level:11}),{code:'idempotency_conflict'});
}));
test('new request cannot replace an existing run ID',each(async f=>{
 const c=start();await f.service.execute(UID,c);assert.equal((await f.service.execute(UID,start(1,c.run_id,10))).operation.kind,'not_committed');
 assert.throws(()=>f.sql.prepare("UPDATE iap_paid_runs_v2 SET loadout_json='{}'").run(),/immutable_paid_run/);
}));
test('other account cannot Continue a run by knowing its ID',each(async f=>{
 const c=start();await f.service.execute(UID,c);f.seed('paid-player-b');await f.init('paid-player-b');assert.equal((await f.service.execute('paid-player-b',resume(c.run_id,0))).operation.kind,'not_committed');
}));
test('run ID, frozen slots and ownership cannot be forged by command',each(async f=>{
 for(const bad of [{...start(),run_id:'not-a-uuid'},{...start(),slots:{armament:'void_piercer_spear'}},{...resume(randomUUID(),0),stars:{jade_binding_chain:5}}])await assert.rejects(f.service.execute(UID,bad),{code:'invalid_command'});
 assert.equal((await f.service.execute(UID,resume(randomUUID(),0))).operation.kind,'not_committed');
}));
test('weapon level is bounded by verified stars and must be an integer',each(async f=>{
 for(const n of [-1,0,31,51,1.5,'12',true])await assert.rejects(f.service.execute(UID,start(0,randomUUID(),n)));
 assert.equal(f.sql.prepare('SELECT COUNT(*) n FROM iap_paid_runs_v2').get().n,0);
}));
test('no paid weapon accepts only zero level',each(async f=>{
 await f.service.execute(UID,command('equip',0,{slot:'armament',item_id:''}));
 await assert.rejects(f.service.execute(UID,start(1,randomUUID(),1)),{code:'invalid_paid_run'});
 assert.equal((await f.service.execute(UID,start(1,randomUUID(),0))).operation.outcome.weapon_level,0);
}));
test('last-write failure rolls back run record and selection revision together',each(async f=>{
 f.injectFailure(true);await assert.rejects(f.service.execute(UID,start()),/injected_write_failure/);
 assert.equal(f.sql.prepare('SELECT COUNT(*) n FROM iap_paid_runs_v2').get().n,0);assert.equal((await f.service.read(UID)).revision,0);
}));
test('competing revisions cannot leave an orphan server run',each(async f=>{
 const result=await Promise.all([f.service.execute(UID,start()),f.service.execute(UID,start())]);assert.deepEqual(result.map(x=>x.operation.kind).sort(),['not_committed','run_start']);assert.equal(f.sql.prepare('SELECT COUNT(*) n FROM iap_paid_runs_v2').get().n,1);
}));
test('refund hold blocks run restoration and replay',each(async f=>{
 const c=start();await f.service.execute(UID,c);f.sql.prepare("INSERT INTO iap_refund_account_holds_v1(owner_key,status,reason) VALUES(?,'held','manual_review')").run(owner(UID));
 await assert.rejects(f.service.execute(UID,resume(c.run_id,1)),{code:'paid_account_on_hold'});await assert.rejects(f.service.execute(UID,c),{code:'paid_account_on_hold'});
}));
test('refund watermark racing a run write rolls back server run as well',each(async f=>{
 f.beforeBatch(()=>f.sql.prepare('UPDATE iap_play_void_cursor_v1 SET watermark_ms=?').run(NOW-7200001));await assert.rejects(f.service.execute(UID,start()),{code:'refund_monitor_stale'});assert.equal(f.sql.prepare('SELECT COUNT(*) n FROM iap_paid_runs_v2').get().n,0);
}));
test('removed ownership cannot be revived from the server run record',each(async f=>{
 const c=start();await f.service.execute(UID,c);const s=JSON.parse(f.sql.prepare('SELECT state_json FROM iap_paid_gameplay_v2').get().state_json);s.slots.armament='';delete s.inventory.jade_binding_chain;delete s.stars.jade_binding_chain;f.sql.prepare('UPDATE iap_paid_gameplay_v2 SET state_json=?').run(JSON.stringify(s));
 const request=resume(c.run_id,1);assert.equal((await f.service.execute(UID,request)).operation.kind,'not_committed');assert.equal((await f.service.execute(UID,request)).operation.kind,'not_committed');
}));
test('a lower current star count does not grant old higher stars on fresh snapshot',each(async f=>{
 const c=start();await f.service.execute(UID,c);const s=JSON.parse(f.sql.prepare('SELECT state_json FROM iap_paid_gameplay_v2').get().state_json);s.stars.jade_binding_chain=1;f.sql.prepare('UPDATE iap_paid_gameplay_v2 SET state_json=?').run(JSON.stringify(s));
 const r=await f.service.execute(UID,resume(c.run_id,1));assert.equal(r.operation.outcome.stars.jade_binding_chain,3);assert.equal(r.snapshot.stars.jade_binding_chain,1);
}));
