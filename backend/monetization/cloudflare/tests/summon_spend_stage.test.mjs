import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { createD1Wallet } from '../src/d1_wallet.mjs';
import { createStagedSummonCoordinator } from '../src/summon_spend_stage.mjs';

const migrationPaths = ['0001_iap_ledger.sql','0002_wallet_ledger.sql','0003_summon_outcomes.sql'];
const uid='firebaseuser1';
const oneId='bd487181-9981-4fd2-a8e7-59c4278732c1';
const secondId='ada71289-b2c7-4b39-a8aa-b7e2a077c10d';
const thirdId='0b2590dd-3211-4d54-93a9-5c03b616ec4a';
const grant=(id='a')=>({purchase_contract_version:1,state:'grant_ready',grant_id:'iapv1:'+id.repeat(64), internal_product_id:'jade_pouch_100',celestial_jade:100});
const tenGrant=()=>({purchase_contract_version:1,state:'grant_ready',grant_id:'iapv1:'+'b'.repeat(64),internal_product_id:'jade_casket_1200',celestial_jade:1200});
const outcome=(pullCount,rarity='rare')=>({outcome_contract_version:1,pull_count:pullCount,results:Array.from({length:pullCount},()=>({item_id:'test_blade',rarity})),next_pity:{rare_plus:0,epic_plus:2,legendary:2}});

class SqliteD1 {
  constructor() {
    this.db=new DatabaseSync(':memory:'); this.db.exec('PRAGMA foreign_keys=ON;');
    for(const n of migrationPaths) this.db.exec(readFileSync(new URL('../migrations/'+n,import.meta.url),'utf8'));
    this.queue=Promise.resolve();
  }
  withSession(m) {assert.equal(m,'first-primary');return this;}
  prepare(sql) {return {bind:(...args)=>({first:async()=>this.db.prepare(sql).get(...args)??null,run:async()=>this.db.prepare(sql).run(...args)})};}
  async batch(stmts) {
    const work=async()=>{this.db.exec('BEGIN IMMEDIATE');try {const a=[];for(const s of stmts)a.push(await s.run());this.db.exec('COMMIT');return a;}catch(e){this.db.exec('ROLLBACK');throw e;}};
    const next=this.queue.then(work,work);this.queue=next.catch(()=>{});return next;
  }
  events(){return this.db.prepare('SELECT COUNT(*) AS n FROM iap_wallet_events_v1').get().n;}
  results(){return this.db.prepare('SELECT COUNT(*) AS n FROM iap_summon_outcomes_v1').get().n;}
  close(){this.db.close();}
}
const setup=()=>{const db=new SqliteD1();return {db, wallet:createD1Wallet(db), coordinator:createStagedSummonCoordinator(db)};};
const execute=(c,{uid:who=uid,requestId=oneId,pullCount=1,resolveTrustedOutcome=()=>outcome(pullCount)}={})=> c.execute({uid:who,requestId,pullCount,resolveTrustedOutcome});

test('server-fixed single pull cost 100, wallet receipt and durable outcome atomic',async()=>{
 const {db,wallet,coordinator}=setup(); await wallet.creditVerifiedPurchase(uid,grant());
 const r=await execute(coordinator);assert.equal(r.applied,true);assert.equal(r.wallet.balance,0);assert.equal(r.outcome.results[0].item_id,'test_blade');
 assert.equal(db.events(),2);assert.equal(db.results(),1);db.close();
});
test('replay returns exact immutable outcome and no second spend',async()=>{
 const {db,wallet,coordinator}=setup();await wallet.creditVerifiedPurchase(uid,grant());
 const first=await execute(coordinator);const second=await execute(coordinator,{resolveTrustedOutcome:()=>{throw Error('Must not be called again');}});
 assert.equal(second.applied,false);assert.deepEqual(first.outcome,second.outcome);assert.equal(second.wallet.balance,0);assert.equal(db.results(),1);db.close();
});
test('ten pull cost 900 from server regardless of client-supplied price',async()=>{
 const {db,wallet,coordinator}=setup();await wallet.creditVerifiedPurchase(uid,tenGrant());
 const r=await execute(coordinator,{pullCount:10});assert.equal(r.wallet.balance,300);assert.equal(r.outcome.results.length,10);
 assert.equal(db.db.prepare("SELECT delta FROM iap_wallet_events_v1 WHERE event_kind='summon_debit'").get().delta,-900);db.close();
});
test('insufficient funds rolls back spend event and outcome together',async()=>{
 const {db,coordinator}=setup();await assert.rejects(execute(coordinator),{code:'insufficient_funds'});
 assert.equal(db.events(),0);assert.equal(db.results(),0);db.close();
});
test('concurrent requests with same id debit only once with one stored result',async()=>{
 const {db,wallet,coordinator}=setup();await wallet.creditVerifiedPurchase(uid,grant());
 const result=await Promise.all([execute(coordinator),execute(coordinator)]);
 assert.equal(result.filter(r=>r.applied).length,1);assert.equal(db.results(),1);assert.equal((await wallet.getSnapshot(uid)).balance,0);db.close();
});
test('different ids from two devices cannot overspend one balance',async()=>{
 const {db,wallet,coordinator}=setup();await wallet.creditVerifiedPurchase(uid,grant());
 const settled=await Promise.allSettled([execute(coordinator),execute(coordinator,{requestId:secondId})]);
 assert.equal(settled.filter(r=>r.status==='fulfilled').length,1);assert.equal(settled.filter(r=>r.status==='rejected'&&r.reason.code==='insufficient_funds').length,1);
 assert.equal(db.results(),1);assert.equal((await wallet.getSnapshot(uid)).balance,0);db.close();
});
test('request id tied to account; other user cannot reuse spend result',async()=>{
 const {db,wallet,coordinator}=setup();await wallet.creditVerifiedPurchase(uid,grant());await execute(coordinator);
 const b=await assert.rejects(execute(coordinator,{uid:'seconduser'}),{code:'insufficient_funds'});
 assert.equal(db.results(),1);db.close();
});
test('reused operation id with changed pull count rejected, no extra debit',async()=>{
 const {db,wallet,coordinator}=setup();await wallet.creditVerifiedPurchase(uid,tenGrant());await execute(coordinator);
 await assert.rejects(execute(coordinator,{pullCount:10}),{code:'operation_conflict'});
 assert.equal((await wallet.getSnapshot(uid)).balance,1100);db.close();
});
test('client cannot choose amount/unsupported pull count/invalid UUID',async()=>{
 const {db,wallet,coordinator}=setup();await wallet.creditVerifiedPurchase(uid,grant());
 await assert.rejects(execute(coordinator,{pullCount:4}),{code:'invalid_pull_count'});
 await assert.rejects(execute(coordinator,{requestId:'1'}),{code:'invalid_request_id'});
 assert.equal(db.results(),0);db.close();
});
test('no resolver or malformed outcome means no debit',async()=>{
 const {db,wallet,coordinator}=setup();await wallet.creditVerifiedPurchase(uid,grant());
 await assert.rejects(coordinator.execute({uid,requestId:oneId,pullCount:1}),{code:'trusted_server_resolver_required'});
 await assert.rejects(execute(coordinator,{resolveTrustedOutcome:()=>({result:'client_grant'})}),{code:'untrusted_outcome_invalid'});
 assert.equal((await wallet.getSnapshot(uid)).balance,100);assert.equal(db.results(),0);db.close();
});
test('db error after input validation rolls back both state and wallet',async()=>{
 const {db,wallet,coordinator}=setup();await wallet.creditVerifiedPurchase(uid,grant());
 db.db.exec("CREATE TRIGGER block_outcome BEFORE INSERT ON iap_summon_outcomes_v1 BEGIN SELECT RAISE(ABORT,'test_db_block'); END;");
 await assert.rejects(execute(coordinator),/test_db_block/);
 assert.equal((await wallet.getSnapshot(uid)).balance,100);assert.equal(db.results(),0);assert.equal(db.events(),1);db.close();
});
test('missing outcome on replay does not silently duplicate a debit',async()=>{
 const {db,wallet,coordinator}=setup();await wallet.creditVerifiedPurchase(uid,grant());
 const r=await execute(coordinator);db.db.prepare('DELETE FROM iap_summon_outcomes_v1 WHERE spend_key=?').run(r.spend_id);
 await assert.rejects(execute(coordinator),{code:'orphan_spend_event'});
 assert.equal((await wallet.getSnapshot(uid)).balance,0);assert.equal(db.events(),2);db.close();
});
test('migration is additive and can be applied twice locally',async()=>{
 const {db}=setup();db.db.exec(readFileSync(new URL('../migrations/0003_summon_outcomes.sql',import.meta.url),'utf8'));
 assert.equal(db.db.prepare("SELECT COUNT(*) AS n FROM sqlite_master WHERE name='iap_summon_outcomes_v1'").get().n,1);
 db.close();
});
