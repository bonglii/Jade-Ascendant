import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { readTrustedProgressionRC3,createTrustedProgressionReadHandlerRC3,trustedStageRevisionGuardRC3 } from '../src/trusted_progression_read_rc3.mjs';
import { listSummonRequestIdsRC3,createSummonRecoveryIndexHandlerRC3 } from '../src/summon_recovery_index_rc3.mjs';

const owner=uid=>'u1:'+createHash('sha256').update(uid).digest('hex');
const evidence=n=>'stagev1:'+String(n).padStart(64,'0');
const identity=(uid='userA')=>({auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}},app:{appId:'trusted-app'}});
const BASE_URL='https://safe.example';
const progressUrl=BASE_URL+'/v1/wallet/trusted-progress';
const recoveryUrl=BASE_URL+'/v1/wallet/summon-recovery-index';
const UUIDS=Array.from({length:25},(_,i)=>`${String(i+1).padStart(8,'0')}-1a2b-4a2b-8a2b-123456789abc`);
const canonical=(stages=['1-5'])=>JSON.stringify({state_contract_version:1,cleared_stage_keys:stages,pity:{rare_plus:0,epic_plus:0,legendary:0},wish_item_id:'',wish_fate_guaranteed:false,lifetime_pulls:0,inventory:{},refinement_shards:0});
class DB{
  constructor(){
    this.sql=new DatabaseSync(':memory:');this.sql.exec('PRAGMA foreign_keys=ON');
    this.sql.exec(`CREATE TABLE iap_wallet_accounts_v1(owner_key TEXT PRIMARY KEY,balance INTEGER DEFAULT 0,revision INTEGER DEFAULT 0);
      CREATE TABLE iap_summon_canonical_v1(owner_key TEXT PRIMARY KEY,revision INTEGER NOT NULL,status TEXT NOT NULL,state_json TEXT NOT NULL);
      CREATE TABLE iap_summon_outcomes_v1(spend_key TEXT PRIMARY KEY,owner_key TEXT NOT NULL,pull_count INTEGER,jade_cost INTEGER,outcome_json TEXT);
    `);
    for(const file of ['0006_trusted_progress_evidence.sql','0007_summon_request_index.sql'])
      this.sql.exec(readFileSync(new URL('../migrations/'+file,import.meta.url),'utf8'));
  }
  withSession(mode){assert.equal(mode,'first-primary');return this;}
  prepare(sql){return {bind:(...args)=>({first:async()=>this.sql.prepare(sql).get(...args)??null,all:async()=>({results:this.sql.prepare(sql).all(...args)}),run:async()=>this.sql.prepare(sql).run(...args)})};}
  seed(uid='userA',stages=['1-5']){
    this.sql.prepare('INSERT INTO iap_wallet_accounts_v1(owner_key) VALUES (?)').run(owner(uid));
    this.sql.prepare("INSERT INTO iap_summon_canonical_v1(owner_key,revision,status,state_json) VALUES (?,0,'verified',?)").run(owner(uid),canonical(stages));
  }
  proof(uid='userA',stage='1-5',index=1,status='verified'){
    this.sql.prepare('INSERT INTO iap_trusted_stage_evidence_v1(owner_key,stage_key,evidence_key,origin,status) VALUES (?,?,?,?,?)')
      .run(owner(uid),stage,evidence(index),'server_verified_gameplay',status);
  }
  commit(uid='userA',id=UUIDS[0],seq=1){
    const hash='spendv1:'+createHash('sha256').update(uid+id).digest('hex');
    this.sql.prepare("INSERT INTO iap_summon_outcomes_v1(spend_key,owner_key,pull_count,jade_cost,outcome_json) VALUES (?, ?,1,100,'{}')").run(hash,owner(uid));
    this.sql.prepare('INSERT INTO iap_summon_request_index_v1(spend_key,owner_key,request_id) VALUES (?,?,?)')
      .run(hash,owner(uid),id);
  }
  count(table){return this.sql.prepare(`SELECT COUNT(*) n FROM ${table}`).get().n;}
  close(){this.sql.close();}
}
const verified=async()=>identity();
const flags=db=>({DB:db,JADE_TRUSTED_PROGRESSION_READ_ENABLED:'true',JADE_SUMMON_RECOVERY_INDEX_READ_ENABLED:'true'});

test('both RC3 routes independently deny by default before Auth and DB',async()=>{
  let calls=0;const verify=()=>{calls++;throw Error('called');};
  const p=createTrustedProgressionReadHandlerRC3({verifyIdentity:verify});
  const r=createSummonRecoveryIndexHandlerRC3({verifyIdentity:verify});
  assert.equal((await p(new Request(progressUrl),{})).status,503);
  assert.equal((await r(new Request(recoveryUrl),{})).status,503);
  assert.equal(calls,0);
});
test('client cannot POST stages, UID or proof to read-only routes',async()=>{
  const p=createTrustedProgressionReadHandlerRC3({verifyIdentity:verified});
  const r=createSummonRecoveryIndexHandlerRC3({verifyIdentity:verified});
  assert.equal((await p(new Request(progressUrl,{method:'POST',body:'{}'}),{})).status,405);
  assert.equal((await r(new Request(recoveryUrl,{method:'POST',body:'{}'}),{})).status,405);
  assert.equal((await p(new Request(progressUrl+'?stage=1-5'),{})).status,400);
});
test('trusted progression refuses auto provision and absent server evidence',async()=>{
  const db=new DB();
  await assert.rejects(readTrustedProgressionRC3({db,verifiedIdentity:identity()}),{code:'not_provisioned'});
  db.seed();
  await assert.rejects(readTrustedProgressionRC3({db,verifiedIdentity:identity()}),{code:'unverified_progress'});
  assert.equal(db.count('iap_trusted_stage_evidence_v1'),0);db.close();
});
test('progress verified only when all canonical stage keys exactly match evidence',async()=>{
  const db=new DB();db.seed('userA',['1-5','2-1']);db.proof('userA','1-5',1);
  await assert.rejects(readTrustedProgressionRC3({db,verifiedIdentity:identity()}),{code:'unverified_progress'});
  db.proof('userA','2-1',2);
  const r=await readTrustedProgressionRC3({db,verifiedIdentity:identity()});
  assert.deepEqual(r.cleared_stage_keys,['1-5','2-1']);
  assert.equal(r.paid_summon_unlocked,true);
  assert.equal(r.authority,'server_verified_only');
  db.close();
});
test('revoke proof fails closed even if canonical state still claims stage',async()=>{
  const db=new DB();db.seed();db.proof();
  assert.equal((await readTrustedProgressionRC3({db,verifiedIdentity:identity()})).state,'verified');
  db.sql.exec("UPDATE iap_trusted_stage_evidence_v1 SET status='revoked'");
  await assert.rejects(readTrustedProgressionRC3({db,verifiedIdentity:identity()}),{code:'unverified_progress'});
  db.close();
});
test('unexpected extra verified evidence fails closed, no staged unlock inflation',async()=>{
  const db=new DB();db.seed();db.proof();db.proof('userA','2-1',2);
  await assert.rejects(readTrustedProgressionRC3({db,verifiedIdentity:identity()}),{code:'unverified_progress'});
  db.close();
});
test('cross-account proof cannot make another account eligible',async()=>{
  const db=new DB();db.seed('userA');db.seed('userB');db.proof('userB','1-5',3);
  await assert.rejects(readTrustedProgressionRC3({db,verifiedIdentity:identity('userA')}),{code:'unverified_progress'});
  assert.equal((await readTrustedProgressionRC3({db,verifiedIdentity:identity('userB')})).state,'verified');db.close();
});
test('invalid identity rejected before any database query',async()=>{
  const db={prepare:()=>{throw Error('db reached');}};
  await assert.rejects(readTrustedProgressionRC3({db,verifiedIdentity:{auth:{uid:'bad'}}}));
  await assert.rejects(listSummonRequestIdsRC3({db,verifiedIdentity:{auth:{uid:'bad'}}}));
});
test('recovery index returns only caller committed IDs and never mutates SQL',async()=>{
  const db=new DB();db.seed('userA');db.seed('userB');
  db.commit('userA',UUIDS[0]);db.commit('userB',UUIDS[1]);
  const a=await listSummonRequestIdsRC3({db,verifiedIdentity:identity('userA')});
  assert.deepEqual(a.request_ids,[UUIDS[0]]);assert.equal(a.next_before,null);
  assert.equal(a.coverage,'indexed_commits_only');
  assert.equal(db.count('iap_summon_request_index_v1'),2);db.close();
});
test('recovery pagination bounded 20 IDs, stable cursor, no cross-account leak',async()=>{
  const db=new DB();db.seed();for(let i=0;i<25;i++)db.commit('userA',UUIDS[i]);
  const a=await listSummonRequestIdsRC3({db,verifiedIdentity:identity()});
  assert.equal(a.request_ids.length,20);assert.equal(a.request_ids[0],UUIDS[24]);
  assert.ok(a.next_before>0);
  const b=await listSummonRequestIdsRC3({db,verifiedIdentity:identity(),before:a.next_before});
  assert.deepEqual(b.request_ids,UUIDS.slice(0,5).reverse());
  assert.equal(b.next_before,null);db.close();
});
test('recovery rejects malformed cursor, query keys, and accidental payload',async()=>{
  const db=new DB();db.seed();const h=createSummonRecoveryIndexHandlerRC3({verifyIdentity:verified});
  for(const u of [recoveryUrl+'?uid=userB',recoveryUrl+'?before=0',recoveryUrl+'?before=-1',recoveryUrl+'?before=1&before=2']){
    assert.equal((await h(new Request(u),flags(db))).status,400);
  }
  assert.equal((await h(new Request(recoveryUrl,{method:'GET',headers:{'content-length':'0'}}),flags(db))).status,400);
  db.close();
});
test('recovery refuses orphan index rows (joins canonical committed outcome)',async()=>{
  const db=new DB();db.seed();db.commit();
  db.sql.exec('PRAGMA foreign_keys=OFF');db.sql.exec('DELETE FROM iap_summon_outcomes_v1');
  const r=await listSummonRequestIdsRC3({db,verifiedIdentity:identity()});
  assert.deepEqual(r.request_ids,[]);db.close();
});
test('index DB constraint prevents duplicate owner UUID and event replay',async()=>{
  const db=new DB();db.seed();db.commit();
  assert.throws(()=>db.commit());
  assert.equal(db.count('iap_summon_request_index_v1'),1);db.close();
});
test('trusted progression status route handles fail-closed states without identity leak',async()=>{
  const db=new DB();db.seed();const h=createTrustedProgressionReadHandlerRC3({verifyIdentity:verified});
  let result=await h(new Request(progressUrl),flags(db));
  assert.equal(result.status,409);assert.deepEqual(await result.json(),{error:'trusted_progression_not_ready'});
  db.proof();result=await h(new Request(progressUrl),flags(db));
  assert.equal(result.status,200);assert.equal((await result.json()).state,'verified');db.close();
});

test('trusted proof CAS is evaluated inside the atomic canonical update',async()=>{
  const db=new DB();db.seed();db.proof();
  const key=owner('userA');
  const guard=trustedStageRevisionGuardRC3(key,['1-5']);
  const stmt=db.sql.prepare(`UPDATE iap_summon_canonical_v1 SET
    revision=CASE WHEN revision=? AND (${guard.sql}) THEN revision+1 ELSE -1 END
    WHERE owner_key=?`);
  assert.equal(stmt.run(0,...guard.bindings,key).changes,1);
  assert.equal(db.sql.prepare('SELECT revision FROM iap_summon_canonical_v1').get().revision,1);
  db.sql.exec("UPDATE iap_trusted_stage_evidence_v1 SET status='revoked'");
  // Transactional trusted CAS fails closed, even if a preflight read previously passed.
  db.sql.exec('SAVEPOINT verify');
  stmt.run(1,...guard.bindings,key);
  assert.equal(db.sql.prepare('SELECT revision FROM iap_summon_canonical_v1').get().revision,-1);
  db.sql.exec('ROLLBACK TO verify');db.sql.exec('RELEASE verify');
  assert.equal(db.sql.prepare('SELECT revision FROM iap_summon_canonical_v1').get().revision,1);
  db.close();
});

test('D1 compatibility regression: malformed .all() arrays are rejected, not treated as verified',async()=>{
  const db=new DB();db.seed();db.proof();db.commit();
  const original=db.prepare.bind(db);
  db.prepare=(sql)=>{
    const statement=original(sql);
    if (!sql.includes('FROM iap_trusted_stage_evidence_v1') &&
        !sql.includes('FROM iap_summon_request_index_v1')) return statement;
    return {bind:(...args)=>{
      const bound=statement.bind(...args);
      return {...bound,all:async()=> (await bound.all()).results};
    }};
  };
  await assert.rejects(readTrustedProgressionRC3({db,verifiedIdentity:identity()}),
    {code:'invalid_evidence'});
  await assert.rejects(listSummonRequestIdsRC3({db,verifiedIdentity:identity()}),
    {code:'invalid_stored_index'});
  db.close();
});

test('D1 compatibility regression: verified stage and recovery HTTP routes handle real D1 results envelope',async()=>{
  const db=new DB();db.seed();db.proof();db.commit();
  const progression=createTrustedProgressionReadHandlerRC3({verifyIdentity:verified});
  const recovery=createSummonRecoveryIndexHandlerRC3({verifyIdentity:verified});
  const progResponse=await progression(new Request(progressUrl),flags(db));
  const recoverResponse=await recovery(new Request(recoveryUrl),flags(db));
  assert.equal(progResponse.status,200);
  assert.equal((await progResponse.json()).paid_summon_unlocked,true);
  assert.equal(recoverResponse.status,200);
  assert.deepEqual((await recoverResponse.json()).request_ids,[UUIDS[0]]);
  db.close();
});
