import {seedRefundPrerequisites} from './fixtures/refund_prerequisites.mjs';
/** Real repo integration: run AFTER installing RC3 into project source.
 * These tests intentionally execute the actual canonical stage and pinned RNG resolver.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { createCanonicalSummonStage } from '../src/summon_canonical_stage.mjs';
import { createTestOnlyTrustedResolver } from '../src/summon_trusted_resolver_stage.mjs';
import { createD1Wallet } from '../src/d1_wallet.mjs';

const uid='rc3_verified_user';
const owner='u1:'+createHash('sha256').update(uid).digest('hex');
const uuid='6a2ce511-144d-4f34-83a2-cd24b2d692b3';
const state=()=>({state_contract_version:1,cleared_stage_keys:['1-5'],pity:{rare_plus:0,epic_plus:0,legendary:0},wish_item_id:'',wish_fate_guaranteed:false,lifetime_pulls:0,inventory:{},refinement_shards:0});
const resolver=createTestOnlyTrustedResolver(low=>low);
class DB{
  constructor(){
    this.sql=new DatabaseSync(':memory:');this.sql.exec('PRAGMA foreign_keys=ON');
    for(const name of ['0001_iap_ledger.sql','0002_wallet_ledger.sql','0003_summon_outcomes.sql',
      '0004_summon_canonical.sql','0005_paid_loadout.sql','0006_trusted_progress_evidence.sql','0007_summon_request_index.sql']){
      this.sql.exec(readFileSync(new URL('../migrations/'+name,import.meta.url),'utf8'));
    }
    seedRefundPrerequisites(this.sql);
    this.queue=Promise.resolve();
  }
  withSession(mode){assert.equal(mode,'first-primary');return this;}
  prepare(sql){return {bind:(...args)=>({
    first:async()=>this.sql.prepare(sql).get(...args)??null,
    all:async()=>({results:this.sql.prepare(sql).all(...args)}),
    run:async()=>this.sql.prepare(sql).run(...args),
  })};}
  batch(steps){
    const transaction=async()=>{
      this.sql.exec('BEGIN IMMEDIATE');
      try{const r=[];for(const step of steps)r.push(await step.run());this.sql.exec('COMMIT');return r;}
      catch(e){this.sql.exec('ROLLBACK');throw e;}
    };
    const t=this.queue.then(transaction,transaction);this.queue=t.catch(()=>{});return t;
  }
  async seed({withProof=true}={}){
    this.sql.prepare("INSERT INTO iap_wallet_accounts_v1(owner_key,balance,revision) VALUES (?,0,0)").run(owner);
    this.sql.prepare("INSERT INTO iap_summon_canonical_v1(owner_key,revision,status,state_json) VALUES (?,0,'verified',?)")
      .run(owner,JSON.stringify(state()));
    if(withProof){this.sql.prepare("INSERT INTO iap_trusted_stage_evidence_v1(owner_key,stage_key,evidence_key,origin,status) VALUES (?,'1-5',?,'server_verified_gameplay','verified')")
      .run(owner,'stagev1:'+'e'.repeat(64));}
    await createD1Wallet(this).creditVerifiedPurchase(uid,{
      purchase_contract_version:1,state:'grant_ready',grant_id:'iapv1:'+'f'.repeat(64),
      internal_product_id:'jade_casket_1200',celestial_jade:1200,
    });
  }
  counts(){return {
    balance:this.sql.prepare('SELECT balance FROM iap_wallet_accounts_v1').get().balance,
    walletEvents:this.sql.prepare('SELECT COUNT(*) AS n FROM iap_wallet_events_v1').get().n,
    outcomes:this.sql.prepare('SELECT COUNT(*) AS n FROM iap_summon_outcomes_v1').get().n,
    recoveryIds:this.sql.prepare('SELECT COUNT(*) AS n FROM iap_summon_request_index_v1').get().n,
    revision:this.sql.prepare('SELECT revision FROM iap_summon_canonical_v1').get().revision,
  };}
  close(){this.sql.close();}
}
const secureStage=db=>createCanonicalSummonStage(db,{requireTrustedProof:true,writeRecoveryIndex:true});
const spend=(db,resolveTrustedTransition=resolver)=>secureStage(db).execute({uid,requestId:uuid,pullCount:1,resolveTrustedTransition});

test('RC3 atomic committed spend creates exactly one durable recovery ID',async()=>{
  const db=new DB();await db.seed();
  const result=await spend(db);
  assert.equal(result.applied,true);
  assert.equal(result.wallet.balance,1100);
  assert.deepEqual(db.counts(),{balance:1100,walletEvents:2,outcomes:1,recoveryIds:1,revision:1});
  assert.equal(db.sql.prepare('SELECT request_id FROM iap_summon_request_index_v1').get().request_id,uuid);
  db.close();
});
test('RC3 replay of SAME UUID never writes a second event or recovery index row',async()=>{
  const db=new DB();await db.seed();
  const first=await spend(db),second=await spend(db);
  assert.deepEqual(second.outcome,first.outcome);
  assert.equal(second.applied,false);
  assert.deepEqual(db.counts(),{balance:1100,walletEvents:2,outcomes:1,recoveryIds:1,revision:1});
  db.close();
});
test('RC3 missing trusted proof fails before RNG and does not debit',async()=>{
  const db=new DB();await db.seed({withProof:false});let rolls=0;
  const fake=createTestOnlyTrustedResolver(low=>{rolls++;return low;});
  await assert.rejects(spend(db,fake),{code:'unverified_progress'});
  assert.equal(rolls,0);
  assert.deepEqual(db.counts(),{balance:1200,walletEvents:1,outcomes:0,recoveryIds:0,revision:0});
  db.close();
});
test('RC3 proof revoked after preflight but before batch CAS rolls back ALL writes',async()=>{
  const db=new DB();await db.seed();
  let invoked=0;
  const revoking=async args=>{
    invoked++;
    db.sql.prepare("UPDATE iap_trusted_stage_evidence_v1 SET status='revoked' WHERE owner_key=?").run(owner);
    return resolver(args);
  };
  await assert.rejects(spend(db,revoking));
  assert.equal(invoked,1);
  assert.deepEqual(db.counts(),{balance:1200,walletEvents:1,outcomes:0,recoveryIds:0,revision:0});
  db.close();
});
test('RC3 recovery-index SQL failure rolls back debit, outcome and canonical item',async()=>{
  const db=new DB();await db.seed();
  db.sql.exec("CREATE TRIGGER rc3_abort_index BEFORE INSERT ON iap_summon_request_index_v1 BEGIN SELECT RAISE(ABORT,'test_index_error'); END;");
  await assert.rejects(spend(db),/test_index_error/);
  assert.deepEqual(db.counts(),{balance:1200,walletEvents:1,outcomes:0,recoveryIds:0,revision:0});
  db.close();
});
