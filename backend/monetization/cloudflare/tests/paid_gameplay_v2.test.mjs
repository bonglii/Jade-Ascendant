import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {fixture,command,UID,NOW,owner} from './fixtures/paid_gameplay_v2.mjs';
import {PAID_CATALOG_V2,PAID_CATALOG_HASH_V2} from '../src/paid_catalog_v2.mjs';
import {createPaidGameplayV2,createPaidGameplayHandlerV2} from '../src/paid_gameplay_v2.mjs';
import {InvalidIdentity} from '../src/jwt_verify.mjs';
const each=fn=>async()=>{const f=fixture();try{await fn(f);}finally{f.close();}};
const roll=(revision=0,count=10)=>command('summon',revision,{pull_count:count});
const identity={auth:{uid:UID,token:{firebase:{sign_in_provider:'google.com'}}},app:{appId:'jade-android-app'}};
const env={JADE_IAP_BACKEND_ENABLED:'true',JADE_PAID_GAMEPLAY_V2_ENABLED:'true',JADE_REFUND_RECONCILIATION_READY:'true'};
test('catalog pin is stable and all active shipping equipment is represented',()=>{
 assert.equal(PAID_CATALOG_V2.length,56);assert.equal(new Set(PAID_CATALOG_V2.map(x=>x.id)).size,56);
 assert.equal(createHash('sha256').update(JSON.stringify(PAID_CATALOG_V2)).digest('hex'),PAID_CATALOG_HASH_V2);
 assert.ok(!PAID_CATALOG_V2.some(x=>x.id.includes('bell')));
 const source=readFileSync(new URL('../../../../scripts/data/equipment_catalog.gd',import.meta.url),'utf8');
 for(const item of PAID_CATALOG_V2)assert.ok(source.includes('"'+item.id+'"'),item.id);
});
test('GET is read-only and initialize preserves v1 exactly',each(async f=>{
 const old=f.sql.prepare('SELECT * FROM iap_summon_canonical_v1').get();
 assert.equal((await f.service.read(UID)).state,'initialize_required');
 assert.equal((await f.service.read('unfunded-user')).state,'unfunded');
 assert.equal(f.sql.prepare('SELECT COUNT(*) AS n FROM iap_paid_gameplay_v2').get().n,0);
 await f.init();await f.init();assert.deepEqual(f.sql.prepare('SELECT * FROM iap_summon_canonical_v1').get(),old);
 assert.equal((await f.service.read(UID)).wallet.balance,2400);
}));
test('verified wallet -> 10 pulls -> duplicate-only refine -> correct-slot equip',each(async f=>{
 await f.init();const result=await f.service.execute(UID,roll());assert.equal(result.snapshot.wallet.balance,1500);
 assert.equal(result.operation.outcome.results.length,10);assert.equal(result.snapshot.lifetime_pulls,10);
 const id=Object.keys(result.snapshot.inventory).find(k=>result.snapshot.inventory[k]===9);assert.ok(id);
 const refined=await f.service.execute(UID,command('refine',1,{item_id:id}));
 assert.equal(refined.snapshot.inventory[id],8);assert.equal(refined.snapshot.stars[id],2);
 const slot=PAID_CATALOG_V2.find(x=>x.id===id).slot;
 const equipped=await f.service.execute(UID,command('equip',2,{item_id:id,slot}));assert.equal(equipped.snapshot.slots[slot],id);
 assert.equal(equipped.snapshot.wallet.balance,1500);
}));
test('same UUID replay cannot debit twice; changed payload rejected',each(async f=>{
 await f.init();const c=roll();const a=await f.service.execute(UID,c),b=await f.service.execute(UID,c);
 assert.deepEqual(a,b);assert.equal(b.snapshot.wallet.revision,2);
 await assert.rejects(f.service.execute(UID,{...c,pull_count:1}),{code:'idempotency_conflict'});
}));
test('simultaneous device CAS writes exactly one pull and a durable cancellation',each(async f=>{
 await f.init();const commands=[roll(),roll()];const results=await Promise.all(commands.map(c=>f.service.execute(UID,c)));
 assert.deepEqual(results.map(x=>x.operation.kind).sort(),['not_committed','summon']);
 assert.equal((await f.service.read(UID)).wallet.balance,1500);
 const loser=results.findIndex(x=>x.operation.kind==='not_committed');
 assert.equal((await f.service.execute(UID,commands[loser])).operation.kind,'not_committed');
}));
test('concurrent replay of identical command returns one outcome',each(async f=>{
 await f.init();const c=roll();const out=await Promise.all([f.service.execute(UID,c),f.service.execute(UID,c)]);
 assert.deepEqual(out[0],out[1]);assert.equal(out[0].snapshot.wallet.balance,1500);
}));
test('insufficient funds cancel without writes and cannot debit after topup',async()=>{
 const f=fixture({funds:0});try{await f.init();const c=roll();
 assert.equal((await f.service.execute(UID,c)).operation.kind,'not_committed');
 f.sql.prepare('UPDATE iap_wallet_accounts_v1 SET balance=2400').run();
 assert.equal((await f.service.execute(UID,c)).operation.kind,'not_committed');
 assert.equal((await f.service.read(UID)).wallet.balance,2400);
 }finally{f.close();}
});
test('failure at last batch write rolls back debit, outcome and ownership',each(async f=>{
 await f.init();f.injectFailure(true);await assert.rejects(f.service.execute(UID,roll()),/injected_write_failure/);
 const s=await f.service.read(UID);assert.equal(s.wallet.balance,2400);assert.equal(s.revision,0);assert.deepEqual(s.inventory,{});
 assert.equal(f.sql.prepare('SELECT COUNT(*) AS n FROM iap_paid_commands_v2').get().n,0);
}));
test('held account denies read, commands and previously committed replay',each(async f=>{
 await f.init();const c=roll();await f.service.execute(UID,c);
 f.sql.prepare("INSERT INTO iap_refund_account_holds_v1(owner_key,status,reason) VALUES(?,'held','manual_review')").run(owner(UID));
 await assert.rejects(f.service.read(UID),{code:'paid_account_on_hold'});
 await assert.rejects(f.service.execute(UID,c),{code:'paid_account_on_hold'});
}));
test('stale refund poll refuses access; racing stale poll rolls back all writes',each(async f=>{
 await f.init();f.beforeBatch(()=>f.sql.prepare('UPDATE iap_play_void_cursor_v1 SET watermark_ms=?').run(NOW-7200001));
 await assert.rejects(f.service.execute(UID,roll()),{code:'refund_monitor_stale'});
 assert.equal(f.sql.prepare('SELECT balance FROM iap_wallet_accounts_v1').get().balance,2400);
 assert.equal(f.sql.prepare('SELECT revision FROM iap_paid_gameplay_v2').get().revision,0);
 await assert.rejects(f.service.read(UID),{code:'refund_monitor_stale'});
}));
test('unowned, cross-slot and nonlegendary wish requests rejected',each(async f=>{
 await f.init();const first=PAID_CATALOG_V2.find(x=>x.rarity==='common');
 await assert.rejects(f.service.execute(UID,command('equip',0,{item_id:first.id,slot:'armament'})),{code:'item_not_owned'});
 await assert.rejects(f.service.execute(UID,command('refine',0,{item_id:first.id})),{code:'refine_not_ready'});
 await assert.rejects(f.service.execute(UID,command('wish',0,{item_id:first.id})),{code:'invalid_command'});
}));
test('targeted legendary guarantee and max-star duplicate cap are server-owned',each(async f=>{
 await f.init();const target=PAID_CATALOG_V2.find(x=>x.rarity==='legendary').id;
 await f.service.execute(UID,command('wish',0,{item_id:target}));
 const row=f.sql.prepare('SELECT state_json FROM iap_paid_gameplay_v2').get(),state=JSON.parse(row.state_json);
 state.pity.legendary=49;f.sql.prepare('UPDATE iap_paid_gameplay_v2 SET state_json=?').run(JSON.stringify(state));
 const result=await f.service.execute(UID,roll(1,1));assert.equal(result.operation.outcome.results[0].item_id,target);
 assert.equal(result.operation.outcome.results[0].hard_legendary_pity,true);
 const final=JSON.parse(f.sql.prepare('SELECT state_json FROM iap_paid_gameplay_v2').get().state_json);
 final.stars[target]=5;final.inventory[target]=5;f.sql.prepare('UPDATE iap_paid_gameplay_v2 SET state_json=?').run(JSON.stringify(final));
 await assert.rejects(f.service.execute(UID,command('refine',2,{item_id:target})),{code:'refine_not_ready'});
}));
test('v1 missing outcome proof cannot mint copies and cutover freezes old writers',each(async f=>{
 const state=JSON.parse(f.sql.prepare('SELECT state_json FROM iap_summon_canonical_v1').get().state_json);
 state.inventory[PAID_CATALOG_V2[0].id]=1;state.lifetime_pulls=1;
 f.sql.prepare('UPDATE iap_summon_canonical_v1 SET state_json=?').run(JSON.stringify(state));
 await assert.rejects(f.init(),{code:'legacy_proof_mismatch'});
 state.inventory={};state.lifetime_pulls=0;f.sql.prepare('UPDATE iap_summon_canonical_v1 SET state_json=?').run(JSON.stringify(state));
 await f.init();assert.throws(()=>f.sql.prepare('UPDATE iap_summon_canonical_v1 SET revision=revision+1').run(),/paid_v2_cutover/);
}));
test('account-scoped replay cannot access another player',each(async f=>{
 await f.init();f.seed('paid-player-b');await f.init('paid-player-b');const c=roll();
 await f.service.execute(UID,c);assert.equal((await f.service.read('paid-player-b')).wallet.balance,2400);
 assert.equal((await f.service.read('paid-player-b')).lifetime_pulls,0);
}));
test('actual Worker-compatible CSPRNG performs an owned draw',each(async f=>{
 await f.init();const service=createPaidGameplayV2(f.db,{now:()=>NOW});
 const r=await service.execute(UID,roll(0,1));assert.equal(r.operation.outcome.results.length,1);
 assert.ok(PAID_CATALOG_V2.some(x=>x.id===r.operation.outcome.results[0].item_id));
}));
test('route remains locked before auth and rejects malformed, oversized or forged requests',async()=>{
 let calls=0;const handler=createPaidGameplayHandlerV2({verifyIdentity:()=>{calls++;return identity;},createService:()=>({read:()=>({}),execute:()=>({})})});
 const req=opts=>new Request('https://test/v1/wallet/gameplay-v2',opts);
 assert.equal((await handler(req(),{})).status,503);assert.equal(calls,0);
 assert.equal((await handler(req(),env)).status,200);
 assert.equal((await handler(req({method:'POST',headers:{'content-type':'application/json'},body:'a'.repeat(1025)}),env)).status,400);
 assert.equal((await handler(req({method:'POST',headers:{'content-type':'application/json'},body:'{'}),env)).status,400);
 const invalid=createPaidGameplayHandlerV2({verifyIdentity:()=>{throw new InvalidIdentity();}});
 assert.equal((await invalid(req(),env)).status,401);
});

test('v1 exact immutable outcome history recovers duplicate copies without touching old fragments',each(async f=>{
 const id=PAID_CATALOG_V2.find(x=>x.rarity==='rare').id,spend='spendv1:'+'a'.repeat(64);
 const results=Array.from({length:10},(_,i)=>({item_id:id,rarity:'rare',duplicate:i>0,duplicate_shards:i>0?12:0}));
 const old=JSON.parse(f.sql.prepare('SELECT state_json FROM iap_summon_canonical_v1').get().state_json);
 old.inventory={[id]:1};old.lifetime_pulls=10;old.refinement_shards=108;
 f.sql.prepare('UPDATE iap_summon_canonical_v1 SET state_json=?,revision=7').run(JSON.stringify(old));
 f.sql.prepare("INSERT INTO iap_wallet_events_v1(event_key,owner_key,event_kind,item_key,delta) VALUES(?,?,'summon_debit','summon:10',-900)").run(spend,owner(UID));
 f.sql.prepare('INSERT INTO iap_summon_outcomes_v1(spend_key,owner_key,pull_count,jade_cost,outcome_json) VALUES(?,?,10,900,?)').run(spend,owner(UID),JSON.stringify({outcome_contract_version:1,pull_count:10,results}));
 const initialized=await f.init();assert.equal(initialized.snapshot.inventory[id],10);
 assert.equal(initialized.snapshot.stars[id],1);assert.equal(initialized.snapshot.lifetime_pulls,10);
 assert.deepEqual(JSON.parse(f.sql.prepare('SELECT state_json FROM iap_summon_canonical_v1').get().state_json),old);
}));
test('confirmed not-committed receipt fences a delayed original request permanently',each(async f=>{
 await f.init();const delayed=roll(),other=roll();let release;let reached;
 const arrived=new Promise(r=>{reached=r;}),pause=new Promise(r=>{release=r;});
 f.beforeBatch(async()=>{f.beforeBatch(null);reached();await pause;});
 const pending=f.service.execute(UID,delayed);await arrived;
 // The same command is cancelled by a competing fresh revision before its old batch resumes.
 // Advance state in one separate connection-equivalent statement, then durable replay tombstone.
 f.sql.prepare('UPDATE iap_paid_gameplay_v2 SET revision=revision+1').run();
 const cancelled=await f.service.execute(UID,delayed);assert.equal(cancelled.operation.kind,'not_committed');
 release();const original=await pending;assert.equal(original.operation.kind,'not_committed');
 assert.equal((await f.service.read(UID)).wallet.balance,2400);
 assert.equal(f.sql.prepare("SELECT COUNT(*) AS n FROM iap_wallet_events_v1 WHERE event_kind='summon_debit'").get().n,0);
}));
