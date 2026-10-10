import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {DatabaseSync} from 'node:sqlite';
import {CATALOG_V1,CATALOG_VERSION} from '../src/summon_catalog_pinned.mjs';
import {resolveTrustedSummonStage,createTestOnlyTrustedResolver,getStagedPoolSnapshot} from '../src/summon_trusted_resolver_stage.mjs';
import {createCanonicalSummonStage} from '../src/summon_canonical_stage.mjs';
import {createD1Wallet} from '../src/d1_wallet.mjs';
const owner=uid=>'u1:'+createHash('sha256').update(uid).digest('hex');
const alice='player_a';
const RID='010161da-f643-4ead-985e-4436980a5251';
const stages=['1-5'];
function base(overrides={}){return {state_contract_version:1,cleared_stage_keys:[...stages],pity:{rare_plus:0,epic_plus:0,legendary:0},wish_item_id:'',wish_fate_guaranteed:false,lifetime_pulls:0,inventory:{},refinement_shards:0,...overrides};}
const rng=(n=0)=>createTestOnlyTrustedResolver((lo,hi)=>{assert.ok(lo<=hi);return lo+Math.min(n,hi-lo)});
const normalized=s=>JSON.stringify(s);
const sg=(c,pullCount=1)=>c({canonicalState:base(),pullCount});

test('M5 pinned catalog has 40 unique equipment entries sorted like EquipmentManager',()=>{
 assert.equal(CATALOG_VERSION,'equipment:1:40');assert.equal(CATALOG_V1.length,40);
 assert.deepEqual(CATALOG_V1.map(x=>x.id),CATALOG_V1.map(x=>x.id).toSorted());
 assert.equal(new Set(CATALOG_V1.map(x=>x.id)).size,40);
 for(const it of CATALOG_V1){assert.match(it.id,/^[a-z][a-z0-9_]+$/);assert.ok(['common','rare','epic','legendary'].includes(it.rarity));assert.ok(Number.isInteger(it.chapter)&&Number.isInteger(it.stage));}
});
test('M5 chapter1-5 server pool never includes chapter2 or chapter3 locked equipment',()=>{
 const {pool,rates}=getStagedPoolSnapshot(stages);
 assert.equal(pool.legendary.length,0);assert.ok(pool.epic.includes('ward_keeper_robe'));
 assert.ok(!pool.rare.includes('moonthread_robe'));
 assert.equal(rates.reduce((a,b)=>a+b,0),10000);
 assert.equal(rates[3],0); // legendary unavailable at Chapter 1-5
});
test('M5 missing legendary redistributes its 200 basis points to nearby epic',()=>{
 const {rates}=getStagedPoolSnapshot(stages);
 assert.deepEqual(rates,[6000,2900,1100,0]);
});
test('M5 fully cleared chapter 3 enables all four rarities',()=>{
 const all=CATALOG_V1.map(x=>x.chapter+'-'+x.stage).filter(x=>x!=='0-0');
 const {pool,rates}=getStagedPoolSnapshot([...new Set(['1-5',...all])]);
 assert.equal(Object.values(pool).flat().length,40);
 assert.deepEqual(rates,[6000,2900,900,200]);
});
test('M5 deterministic first rare roll updates pity and ownership and matches M4 outcome contract',()=>{
 const {outcome,nextState}=rng(6000)({canonicalState:base(),pullCount:1});
 assert.equal(outcome.pull_count,1);assert.equal(outcome.results.length,1);
 assert.equal(outcome.results[0].rarity,'rare');assert.equal(outcome.results[0].duplicate,false);
 assert.equal(nextState.lifetime_pulls,1);assert.deepEqual(nextState.pity,{rare_plus:0,epic_plus:1,legendary:0});
 assert.equal(nextState.inventory[outcome.results[0].item_id],1);
});
test('M5 10 pulls update duplicate shards at server only',()=>{
 const {outcome,nextState}=rng(0)({canonicalState:base(),pullCount:10});
 assert.equal(outcome.results.length,10);assert.equal(outcome.results[0].duplicate,false);
 assert.ok(outcome.results.slice(1,9).every(x=>x.duplicate));
 assert.equal(outcome.results[9].rarity,'rare'); // 10th hard rare pity
 assert.equal(outcome.results[9].duplicate,false);
 assert.equal(nextState.refinement_shards,8*5);assert.equal(nextState.lifetime_pulls,10);
});
test('M5 rare pity overrides normal rate',()=>{
 const s=base({pity:{rare_plus:9,epic_plus:2,legendary:0}});
 const {outcome,nextState}=rng(0)({canonicalState:s,pullCount:1});
 assert.equal(outcome.results[0].rarity,'rare');assert.equal(nextState.pity.rare_plus,0);
});
test('M5 epic pity overrides rare pity if both are one away',()=>{
 const s=base({pity:{rare_plus:9,epic_plus:29,legendary:0}});
 const {outcome,nextState}=rng(0)({canonicalState:s,pullCount:1});
 assert.equal(outcome.results[0].rarity,'epic');assert.equal(nextState.pity.epic_plus,0);
});
test('M5 legendary hard pity overrides rare + epic and enforces wish hit',()=>{
 const s=base({cleared_stage_keys:['1-5','2-5'],pity:{rare_plus:9,epic_plus:29,legendary:49},wish_item_id:'sovereign_mantle'});
 const {outcome,nextState}=rng(0)({canonicalState:s,pullCount:1});
 assert.equal(outcome.results[0].rarity,'legendary');assert.equal(outcome.results[0].item_id,'sovereign_mantle');
 assert.equal(outcome.results[0].hard_legendary_pity,true);assert.equal(outcome.results[0].wish_hit,true);
 assert.deepEqual(nextState.pity,{rare_plus:0,epic_plus:0,legendary:0});
});
test('M5 Wish Fate activates on non-wish natural legendary and consumes on next legendary',()=>{
 // roll first = 10000 => legendary; wish coin = 1 -> nonwish; item = 0. For guaranteed replay, next roll 10000.
 const inputs=[10000,1,0,10000];
 const a=createTestOnlyTrustedResolver((lo,hi)=>{const t=inputs.shift();assert.ok(t>=lo&&t<=hi);return t;});
 const s=base({cleared_stage_keys:['1-5','2-5','3-5'],wish_item_id:'sovereign_mantle'});
 const first=a({canonicalState:s,pullCount:1});
 assert.equal(first.outcome.results[0].rarity,'legendary');assert.equal(first.outcome.results[0].wish_hit,false);
 assert.equal(first.outcome.results[0].wish_fate_activated,true);assert.equal(first.nextState.wish_fate_guaranteed,true);
 const second=a({canonicalState:first.nextState,pullCount:1});
 assert.equal(second.outcome.results[0].item_id,'sovereign_mantle');
 assert.equal(second.outcome.results[0].wish_fate_consumed,true);assert.equal(second.nextState.wish_fate_guaranteed,false);
});
test('M5 random 50/50 Wish hit never activates guarantee when hit',()=>{
 const inputs=[10000,0];
 const a=createTestOnlyTrustedResolver((lo,hi)=>{const t=inputs.shift();assert.ok(t>=lo&&t<=hi);return t;});
 const s=base({cleared_stage_keys:['1-5','2-5'],wish_item_id:'sovereign_mantle'});
 const r=a({canonicalState:s,pullCount:1});
 assert.equal(r.outcome.results[0].wish_hit,true);
 assert.equal(r.outcome.results[0].wish_fate_activated,false);
});
test('M5 missing unlock and forged client wish are rejected',()=>{
 assert.throws(()=>rng(0)({canonicalState:base({cleared_stage_keys:[]}),pullCount:1}),{code:'invalid_canonical_state'});
 assert.throws(()=>rng(0)({canonicalState:base({wish_item_id:'nine_heavens_star_sword'}),pullCount:1}),{code:'wish_not_unlocked'});
 assert.throws(()=>rng(0)({canonicalState:base(),pullCount:4}),{code:'invalid_pull_count'});
});
test('M5 never writes to original canonical state object',()=>{
 const state=base();const original=normalized(state);rng(0)({canonicalState:state,pullCount:10});assert.equal(normalized(state),original);
});
test('M5 invalid RNG results reject before returning fabricated item',()=>{
 const t=createTestOnlyTrustedResolver(()=>10001);
 assert.throws(()=>t({canonicalState:base(),pullCount:1}),{code:'invalid_secure_rng_result'});
});
test('M5 production resolver uses runtime crypto without injection, returns legal result',()=>{
 const r=resolveTrustedSummonStage({canonicalState:base(),pullCount:10});
 assert.equal(r.outcome.results.length,10);
 assert.equal(r.nextState.lifetime_pulls,10);
 assert.deepEqual(r.outcome.next_pity,r.nextState.pity);
});

class D1Sim {
 constructor(){this.db=new DatabaseSync(':memory:');this.db.exec('PRAGMA foreign_keys=ON;');
  for(let i=1;i<=4;i++){const suffix=['iap_ledger','wallet_ledger','summon_outcomes','summon_canonical'][i-1];this.db.exec(readFileSync(new URL(`../migrations/000${i}_${suffix}.sql`,import.meta.url),'utf8'));}
  this.queue=Promise.resolve();
 }
 withSession(name){assert.equal(name,'first-primary');return this;}
 prepare(sql){return {bind:(...args)=>({first:async()=>this.db.prepare(sql).get(...args)??null,run:async()=>this.db.prepare(sql).run(...args)})};}
 batch(stmts){const fn=async()=>{this.db.exec('BEGIN IMMEDIATE');try{const o=[];for(const st of stmts)o.push(await st.run());this.db.exec('COMMIT');return o;}catch(e){this.db.exec('ROLLBACK');throw e;}};const p=this.queue.then(fn,fn);this.queue=p.catch(()=>{});return p;}
 async seed(){const k=owner(alice);this.db.prepare('INSERT INTO iap_wallet_accounts_v1 (owner_key,balance,revision) VALUES (?,1200,0)').run(k);this.db.prepare('INSERT INTO iap_summon_canonical_v1 (owner_key,revision,status,state_json) VALUES (?,0,\'verified\',?)').run(k,JSON.stringify(base()));}
 snapshot(){return this.db.prepare('SELECT balance FROM iap_wallet_accounts_v1 WHERE owner_key=?').get(owner(alice));}
 state(){return JSON.parse(this.db.prepare('SELECT state_json FROM iap_summon_canonical_v1 WHERE owner_key=?').get(owner(alice)).state_json);}
 close(){this.db.close();}
}
test('M5 resolver plugs into M4 canonical transaction: debit, outcome, pity, inventory atomic',async()=>{
 const db=new D1Sim();await db.seed();
 const c=createCanonicalSummonStage(db);
 const r=await c.execute({uid:alice,requestId:RID,pullCount:10,resolveTrustedTransition:rng(0)});
 assert.equal(r.applied,true);assert.equal(r.wallet.balance,300);
 assert.equal(r.outcome.results.length,10);assert.equal(db.state().refinement_shards,40);
 const replay=await c.execute({uid:alice,requestId:RID,pullCount:10,resolveTrustedTransition:()=>{throw Error('must not reroll');}});
 assert.equal(replay.applied,false);assert.deepEqual(replay.outcome,r.outcome);assert.equal(db.snapshot().balance,300);
 db.close();
});
test('M5 source-only remains not imported by Worker route',()=>{
 const index=readFileSync(new URL('../src/index.mjs',import.meta.url),'utf8');
 assert.doesNotMatch(index,/summon_trusted_resolver_stage|summon_catalog_pinned|summon_canonical_stage/);
});
