import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {DatabaseSync} from 'node:sqlite';
import {createCanonicalSummonStage} from '../src/summon_canonical_stage.mjs';
import {createD1Wallet} from '../src/d1_wallet.mjs';

const UID='alice1',UID2='bob2';
const REQ='9cc242ed-56cc-46bc-8f8d-fb2b83388d7a';
const REQ2='362ef4da-bc86-43e6-86dc-dad77241cbde';
const owner=uid=>'u1:'+createHash('sha256').update(uid).digest('hex');
const grant=(id,product='jade_casket_1200',amount=1200)=>({purchase_contract_version:1,state:'grant_ready',grant_id:'iapv1:'+id.repeat(64),internal_product_id:product,celestial_jade:amount});
const canonical=()=>({state_contract_version:1,cleared_stage_keys:['1-5'],pity:{rare_plus:0,epic_plus:0,legendary:0},wish_item_id:'',wish_fate_guaranteed:false,lifetime_pulls:0,inventory:{},refinement_shards:0});
const result=(id='test_blade',rarity='rare',duplicate=false)=>({item_id:id,rarity,duplicate,duplicate_shards:duplicate?12:0,hard_legendary_pity:false,wish_hit:false,wish_fate_activated:false,wish_fate_consumed:false});
function resolver({pullCount,canonicalState}) {
  const r=Array.from({length:pullCount},(_,i)=>result('test_blade','rare',i>0 || !!canonicalState.inventory.test_blade));
  const shards=canonicalState.refinement_shards + r.filter(x=>x.duplicate).length*12;
  const next={...canonicalState,inventory:{...canonicalState.inventory,test_blade:1},refinement_shards:shards,lifetime_pulls:canonicalState.lifetime_pulls+pullCount,pity:{rare_plus:0,epic_plus:canonicalState.pity.epic_plus+pullCount,legendary:canonicalState.pity.legendary+pullCount}};
  // 10 pulls can be tested from default 0, within pity ranges.
  const outcome={outcome_contract_version:1,pull_count:pullCount,results:r,next_pity:next.pity};
  return {outcome,nextState:next};
}
class SqliteD1 {
  constructor(){
    this.db=new DatabaseSync(':memory:');this.db.exec('PRAGMA foreign_keys=ON;');
    for(let i=1;i<=4;i++){
      const file=`000${i}_`+['iap_ledger','wallet_ledger','summon_outcomes','summon_canonical'][i-1]+'.sql';
      this.db.exec(readFileSync(new URL('../migrations/'+file,import.meta.url),'utf8'));
    }
    this.queue=Promise.resolve();
  }
  withSession(name){assert.equal(name,'first-primary');return this;}
  prepare(sql){return {bind:(...args)=>({first:async()=>this.db.prepare(sql).get(...args)??null,run:async()=>this.db.prepare(sql).run(...args)})};}
  batch(statements){
    const exec=async()=>{this.db.exec('BEGIN IMMEDIATE');try{let out=[];for(const s of statements)out.push(await s.run());this.db.exec('COMMIT');return out;}catch(e){this.db.exec('ROLLBACK');throw e;}};
    const next=this.queue.then(exec,exec);this.queue=next.catch(()=>{});return next;
  }
  seed(uid=UID,s=canonical(),status='verified'){
    this.db.prepare('INSERT OR IGNORE INTO iap_wallet_accounts_v1 (owner_key,balance,revision) VALUES (?,0,0)').run(owner(uid));
    this.db.prepare('INSERT INTO iap_summon_canonical_v1 (owner_key,revision,status,state_json) VALUES (?,0,?,?)').run(owner(uid),status,JSON.stringify(s));
  }
  get(uid=UID){return this.db.prepare('SELECT * FROM iap_summon_canonical_v1 WHERE owner_key=?').get(owner(uid));}
  outcomeCount(){return this.db.prepare('SELECT COUNT(*) AS n FROM iap_summon_outcomes_v1').get().n;}
  eventCount(){return this.db.prepare('SELECT COUNT(*) AS n FROM iap_wallet_events_v1').get().n;}
  close(){this.db.close();}
}
function setup({seed=true}={}){const db=new SqliteD1();if(seed) db.seed();return {db,wallet:createD1Wallet(db),c:createCanonicalSummonStage(db)};}
const exec=(c,extra={})=>c.execute({uid:UID,requestId:REQ,pullCount:1,resolveTrustedTransition:resolver,...extra});

test('M4 migration creates canonical table and repeat is idempotent',()=>{const {db}=setup();const sql=readFileSync(new URL('../migrations/0004_summon_canonical.sql',import.meta.url),'utf8');db.db.exec(sql);assert.ok(db.get());db.close();});
test('unprovisioned account cannot summon even when wallet is credited',async()=>{const {db,wallet,c}=setup({seed:false});await wallet.creditVerifiedPurchase(UID,grant('a'));await assert.rejects(exec(c),{code:'canonical_state_not_verified'});assert.equal(db.outcomeCount(),0);db.close();});
test('explicit status unprovisioned refuses all resolver calls',async()=>{const {db,wallet,c}=setup({seed:false});db.seed(UID,canonical(),'unprovisioned');await wallet.creditVerifiedPurchase(UID,grant('a'));await assert.rejects(exec(c,{resolveTrustedTransition:()=>{throw Error('must not call')}}),{code:'canonical_state_not_verified'});db.close();});
test('server requires trusted stage unlock',async()=>{const s=canonical();s.cleared_stage_keys=[];const {db,wallet,c}=setup({seed:false});db.seed(UID,s);await wallet.creditVerifiedPurchase(UID,grant('a'));await assert.rejects(exec(c),{code:'summon_not_unlocked'});db.close();});
test('single summon updates wallet, immutable result and canonical state atomically',async()=>{const {db,wallet,c}=setup();await wallet.creditVerifiedPurchase(UID,grant('a'));const x=await exec(c);assert.equal(x.applied,true);assert.equal(x.wallet.balance,1100);const state=JSON.parse(db.get().state_json);assert.equal(state.lifetime_pulls,1);assert.equal(state.inventory.test_blade,1);assert.equal(state.pity.epic_plus,1);assert.equal(db.get().revision,1);assert.equal(db.outcomeCount(),1);db.close();});
test('same request replay returns stored result with no second spend or state mutation',async()=>{const {db,wallet,c}=setup();await wallet.creditVerifiedPurchase(UID,grant('a'));const first=await exec(c);const replay=await exec(c,{resolveTrustedTransition:()=>{throw Error('resolver must not run')}});assert.equal(replay.applied,false);assert.deepEqual(replay.outcome,first.outcome);assert.equal(replay.wallet.balance,1100);assert.equal(db.get().revision,1);assert.equal(db.outcomeCount(),1);db.close();});
test('second summon increments duplicate shards and canonical lifetime',async()=>{const {db,wallet,c}=setup();await wallet.creditVerifiedPurchase(UID,grant('a'));await exec(c);const next=await exec(c,{requestId:REQ2});assert.equal(next.outcome.results[0].duplicate,true);const state=JSON.parse(db.get().state_json);assert.equal(state.refinement_shards,12);assert.equal(state.lifetime_pulls,2);assert.equal(next.wallet.balance,1000);db.close();});
test('10-pull costs 900, single owned item + 9 duplicates produce shards',async()=>{const {db,wallet,c}=setup();await wallet.creditVerifiedPurchase(UID,grant('a'));const x=await exec(c,{pullCount:10});assert.equal(x.wallet.balance,300);const state=JSON.parse(db.get().state_json);assert.equal(state.refinement_shards,108);assert.equal(state.inventory.test_blade,1);assert.equal(state.lifetime_pulls,10);db.close();});
test('insufficient wallet balance rolls back canonical state and outcome',async()=>{const {db,wallet,c}=setup();await assert.rejects(exec(c),{code:'insufficient_funds'});assert.equal(db.get().revision,0);assert.equal(db.outcomeCount(),0);assert.equal(db.eventCount(),0);db.close();});
test('malicious resolver cannot change cleared stages, item counts or lifetime',async()=>{const {db,wallet,c}=setup();await wallet.creditVerifiedPurchase(UID,grant('a'));await assert.rejects(exec(c,{resolveTrustedTransition:(q)=>{const x=resolver(q);x.nextState.cleared_stage_keys=['2-5'];return x;}}),{code:'invalid_state_transition'});await assert.rejects(exec(c,{resolveTrustedTransition:(q)=>{const x=resolver(q);x.nextState.inventory.other_blade=1;return x;}}),{code:'invalid_inventory_transition'});await assert.rejects(exec(c,{resolveTrustedTransition:(q)=>{const x=resolver(q);x.nextState.lifetime_pulls=999;return x;}}),{code:'invalid_state_transition'});assert.equal((await wallet.getSnapshot(UID)).balance,1200);assert.equal(db.outcomeCount(),0);db.close();});
test('resolver cannot spoof duplicate status or extra shards',async()=>{const {db,wallet,c}=setup();await wallet.creditVerifiedPurchase(UID,grant('a'));await assert.rejects(exec(c,{resolveTrustedTransition:(q)=>{const x=resolver(q);x.outcome.results[0].duplicate=true;return x;}}),{code:'invalid_duplicate_result'});await assert.rejects(exec(c,{resolveTrustedTransition:(q)=>{const x=resolver(q);x.nextState.refinement_shards=100;return x;}}),{code:'invalid_inventory_transition'});assert.equal(db.outcomeCount(),0);db.close();});
test('DB error on outcome insert rolls back balance, event and canonical revision',async()=>{const {db,wallet,c}=setup();await wallet.creditVerifiedPurchase(UID,grant('a'));db.db.exec("CREATE TRIGGER fail_outcome BEFORE INSERT ON iap_summon_outcomes_v1 BEGIN SELECT RAISE(ABORT,'test_block'); END;");await assert.rejects(exec(c),/test_block/);assert.equal((await wallet.getSnapshot(UID)).balance,1200);assert.equal(db.get().revision,0);assert.equal(db.outcomeCount(),0);assert.equal(db.eventCount(),1);db.close();});
test('two devices with different IDs cannot commit stale pity at same revision',async()=>{const {db,wallet,c}=setup();await wallet.creditVerifiedPurchase(UID,grant('a'));let release;const gate=new Promise(r=>release=r);let ready=0;let entered;const both=new Promise(r=>entered=r);const held=async(q)=>{if(++ready===2)entered();await gate;return resolver(q);};const p1=exec(c,{resolveTrustedTransition:held});const p2=exec(c,{requestId:REQ2,resolveTrustedTransition:held});await both;release();const results=await Promise.allSettled([p1,p2]);assert.equal(results.filter(x=>x.status==='fulfilled').length,1);assert.equal(results.filter(x=>x.status==='rejected'&&x.reason.code==='state_contention_retry').length,1);assert.equal(db.get().revision,1);assert.equal(db.outcomeCount(),1);assert.equal((await wallet.getSnapshot(UID)).balance,1100);db.close();});
test('same ID simultaneously executes only once with idempotent replay',async()=>{const {db,wallet,c}=setup();await wallet.creditVerifiedPurchase(UID,grant('a'));const vals=await Promise.all([exec(c),exec(c)]);assert.equal(vals.filter(x=>x.applied).length,1);assert.equal(db.outcomeCount(),1);assert.equal(db.get().revision,1);db.close();});
test('different accounts never share wallet/canonical state',async()=>{const {db,wallet,c}=setup();db.seed(UID2);await wallet.creditVerifiedPurchase(UID,grant('a'));await exec(c);await assert.rejects(exec(c,{uid:UID2}),{code:'insufficient_funds'});assert.equal(db.get(UID2).revision,0);assert.equal(db.outcomeCount(),1);db.close();});
test('pure resolver missing or invalid pull count rejects before any debit',async()=>{const {db,wallet,c}=setup();await wallet.creditVerifiedPurchase(UID,grant('a'));await assert.rejects(exec(c,{resolveTrustedTransition:null}),{code:'trusted_server_resolver_required'});await assert.rejects(exec(c,{pullCount:4}),{code:'invalid_pull_count'});assert.equal(db.outcomeCount(),0);db.close();});
