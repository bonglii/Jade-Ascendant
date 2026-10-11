import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {createHash,webcrypto} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {commitTrustedBattleStageRC10,verifyTrustedBattleReceiptRC10} from '../src/trusted_battle_receipt_rc10.mjs';
const now=Date.parse('2026-10-10T08:00:00Z');
const uid='player_v10', uidB='player_v10_b';
const owner=x=>'u1:'+createHash('sha256').update(x).digest('hex');
const b64=v=>Buffer.from(v instanceof Uint8Array ? v : (typeof v==='string'?v:JSON.stringify(v))).toString('base64url');
const state=stages=>JSON.stringify({state_contract_version:1,cleared_stage_keys:stages,pity:{rare_plus:0,epic_plus:0,legendary:0},wish_item_id:'',wish_fate_guaranteed:false,lifetime_pulls:0,inventory:{},refinement_shards:0});
let keypair,jwk;
async function ensureKey(){if(keypair)return;keypair=await webcrypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);jwk={...await webcrypto.subtle.exportKey('jwk',keypair.publicKey),kid:'trusted-stage-verifier-1',alg:'RS256',use:'sig'};}
let nextId=0;
async function sign(stage='1-1',sub=uid,claims={}){await ensureKey();nextId++;const payload={iss:'jade-server-combat-verifier',aud:'jade-ascendant-iap-trusted-progress',sub,stage_key:stage,battle_id:`00000000-0000-4000-8000-${String(nextId).padStart(12,'0')}`,result:'cleared',iat:Math.floor(now/1000)-10,exp:Math.floor(now/1000)+120,receipt_version:1,...claims};const a=b64({alg:'RS256',typ:'JWT',kid:jwk.kid});const b=b64(payload);const sig=await webcrypto.subtle.sign('RSASSA-PKCS1-v1_5',keypair.privateKey,new TextEncoder().encode(a+'.'+b));return a+'.'+b+'.'+b64(Buffer.from(sig));}
const opts=()=>({kid:jwk.kid,pinnedPublicJwk:jwk,nowMs:now,subtle:webcrypto.subtle});
class DB{
  constructor(){this.sql=new DatabaseSync(':memory:');this.sql.exec('PRAGMA foreign_keys=ON');this.sql.exec(`CREATE TABLE iap_wallet_accounts_v1(owner_key TEXT PRIMARY KEY,balance INTEGER NOT NULL DEFAULT 0,revision INTEGER NOT NULL DEFAULT 0);
  CREATE TABLE iap_summon_canonical_v1(owner_key TEXT PRIMARY KEY REFERENCES iap_wallet_accounts_v1(owner_key),revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),status TEXT NOT NULL,state_json TEXT NOT NULL,updated_at TEXT);`);
  this.sql.exec(readFileSync(new URL('../migrations/0006_trusted_progress_evidence.sql',import.meta.url),'utf8'));
  this.onBatch=null;
  }
  seed(id=uid,stages=[]){this.sql.prepare('INSERT INTO iap_wallet_accounts_v1(owner_key) VALUES (?)').run(owner(id));this.sql.prepare('INSERT INTO iap_summon_canonical_v1(owner_key,status,state_json) VALUES (?,?,?)').run(owner(id),'verified',state(stages));}
  prepare(sql){const db=this.sql;return {bind:(...args)=>({first:async()=>db.prepare(sql).get(...args)??null,all:async()=>({results:db.prepare(sql).all(...args)}),run:()=>db.prepare(sql).run(...args)})};}
  withSession(mode){assert.equal(mode,'first-primary');return this;}
  async batch(stmts){if(this.onBatch){const hook=this.onBatch;this.onBatch=null;hook(this.sql);}this.sql.exec('BEGIN IMMEDIATE');try{const rows=stmts.map(s=>s.run());this.sql.exec('COMMIT');return rows;}catch(e){this.sql.exec('ROLLBACK');throw e;}}
  proofCount(){return this.sql.prepare('SELECT COUNT(*) AS n FROM iap_trusted_stage_evidence_v1').get().n;}
  stages(id=uid){return JSON.parse(this.sql.prepare('SELECT state_json FROM iap_summon_canonical_v1 WHERE owner_key=?').get(owner(id)).state_json).cleared_stage_keys;}
  close(){this.sql.close();}
}
const commit=(db,receipt)=>commitTrustedBattleStageRC10({db,receipt,...opts()});
test('signed battle proof commits canonical + stage evidence atomically',async()=>{const db=new DB();db.seed();const r=await commit(db,await sign());assert.equal(r.applied,true);assert.equal(r.canonical_revision,1);assert.deepEqual(db.stages(),['1-1']);assert.equal(db.proofCount(),1);db.close();});
test('replaying same signed receipt is idempotent',async()=>{const db=new DB();db.seed();const receipt=await sign();await commit(db,receipt);const second=await commit(db,receipt);assert.equal(second.applied,false);assert.equal(second.canonical_revision,1);assert.equal(db.proofCount(),1);db.close();});
test('skipping ahead to stage 1-5 is rejected, cannot unlock paid summon',async()=>{const db=new DB();db.seed();await assert.rejects(commit(db,await sign('1-5')),{code:'out_of_order_stage'});assert.equal(db.proofCount(),0);db.close();});
test('signed stage 1-2 succeeds only after genuine stage 1-1 proof',async()=>{const db=new DB();db.seed();await commit(db,await sign('1-1'));await commit(db,await sign('1-2'));assert.deepEqual(db.stages(),['1-1','1-2']);assert.equal(db.proofCount(),2);db.close();});
test('rejects unsigned client stage claims or fake local progression data',async()=>{const db=new DB();db.seed();await assert.rejects(commit(db,'{"stage":"1-5"}'));assert.equal(db.proofCount(),0);db.close();});
test('rejects tampered JWT payload even if old signature was valid',async()=>{await ensureKey();const s=await sign();const p=s.split('.');const data=JSON.parse(Buffer.from(p[1],'base64url'));data.stage_key='1-5';p[1]=b64(data);await assert.rejects(verifyTrustedBattleReceiptRC10(p.join('.'),opts()),{code:'invalid_receipt'});});
test('rejects another UID and prevents allocating stages to other accounts',async()=>{const db=new DB();db.seed();await assert.rejects(commit(db,await sign('1-1',uidB)),{code:'account_not_provisioned'});assert.equal(db.proofCount(),0);db.close();});
test('rejects expired signed receipts before writes',async()=>{const db=new DB();db.seed();await assert.rejects(commit(db,await sign('1-1',uid,{exp:Math.floor(now/1000)-1})),{code:'expired_receipt'});assert.equal(db.proofCount(),0);db.close();});
test('rejects revoked prerequisite even when canonical JSON claims it',async()=>{const db=new DB();db.seed();await commit(db,await sign('1-1'));db.sql.exec("UPDATE iap_trusted_stage_evidence_v1 SET status='revoked'");await assert.rejects(commit(db,await sign('1-2')),{code:'prior_evidence_mismatch'});assert.equal(db.proofCount(),1);db.close();});
test('revocation racing with new stage commit aborts entire D1 transaction',async()=>{const db=new DB();db.seed();await commit(db,await sign('1-1'));const before=db.stages();db.onBatch=sql=>sql.exec("UPDATE iap_trusted_stage_evidence_v1 SET status='revoked' WHERE stage_key='1-1'");await assert.rejects(commit(db,await sign('1-2')),{code:'stage_commit_unavailable'});assert.deepEqual(db.stages(),before);assert.equal(db.proofCount(),1);db.close();});
test('SQL failure rolls back stage evidence and leaves canonical intact',async()=>{const db=new DB();db.seed();db.onBatch=sql=>sql.exec("CREATE TRIGGER reject_proof BEFORE INSERT ON iap_trusted_stage_evidence_v1 BEGIN SELECT RAISE(ABORT, 'unavailable'); END;");await assert.rejects(commit(db,await sign()),{code:'stage_commit_unavailable'});assert.deepEqual(db.stages(),[]);assert.equal(db.proofCount(),0);db.close();});
test('different signed battle for an already awarded stage is rejected',async()=>{const db=new DB();db.seed();await commit(db,await sign());await assert.rejects(commit(db,await sign()),{code:'out_of_order_stage'});assert.equal(db.proofCount(),1);db.close();});

test('full signed first chapter unlock chain reaches 1-5 with five distinct durable proofs',async()=>{
  const db=new DB();db.seed();
  for(let i=1;i<=5;i++) await commit(db,await sign(`1-${i}`));
  assert.deepEqual(db.stages(),['1-1','1-2','1-3','1-4','1-5']);
  assert.equal(db.proofCount(),5);
  const count=db.sql.prepare("SELECT COUNT(*) AS n FROM iap_trusted_stage_evidence_v1 WHERE status='verified' AND origin='server_verified_gameplay'").get().n;
  assert.equal(count,5);db.close();
});
