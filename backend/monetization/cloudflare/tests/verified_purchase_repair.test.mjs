import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createVerifiedPurchaseRepairHandler, repairVerifiedPurchases } from '../src/verified_purchase_repair.mjs';
import { createD1Wallet } from '../src/d1_wallet.mjs';

const sha=s=>createHash('sha256').update(s).digest('hex');
const UID='firebase-verified-user';
const BAD='different-firebase-user';
const IDENTITY=uid=>({auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}},app:{appId:'android-jade-client'}});
const FRESH=()=>Date.now()-30_000;
function fixture() {
  const sql=new DatabaseSync(':memory:');
  sql.exec('PRAGMA foreign_keys=ON');
  for (const file of [
    '../migrations/0001_iap_ledger.sql',
    '../migrations/0002_wallet_ledger.sql',
    '../migrations/0004_summon_canonical.sql',
    '../migrations/0008_refund_account_holds.sql',
    '../migrations/0009_play_voided_reconciliation.sql',
    '../migrations/0010_purchase_repair_owner_index.sql',
  ]) sql.exec(readFileSync(new URL(file,import.meta.url),'utf8'));
  sql.prepare(`INSERT INTO iap_play_void_cursor_v1 (cursor_name,watermark_ms)
     VALUES ('voided_inapp',?)`).run(FRESH());
  const db={
    prepare(query){return {bind(...values){return {
      async first(){return sql.prepare(query).get(...values)??null;},
      async all(){return {results:sql.prepare(query).all(...values)};},
      run(){return sql.prepare(query).run(...values);},
    };}};},
    withSession(where){assert.equal(where,'first-primary');return this;},
    async batch(stmts){sql.exec('BEGIN IMMEDIATE');try{const out=stmts.map(s=>s.run());sql.exec('COMMIT');return out;}
      catch(e){sql.exec('ROLLBACK');throw e;}},
  };
  const fingerprint=t=>sha(t);
  function ledger(uid,{name='jade_pouch_100',product='jade_pouch_100',amount=100,token='token-a',state='grant_ready',malformed=false}={}) {
    const token_key='playtoken:'+fingerprint(token), record={
      contractVersion:1, tokenKey:token_key, grantId:'iapv1:'+fingerprint(token),
      ownerUid:uid,ownerBinding:sha(uid),internalProductId:name,
      playProductId:product,celestialJade:amount,state,
    };
    sql.prepare('INSERT INTO iap_purchase_ledger_v1 (token_key,record_json) VALUES (?,?)')
      .run(token_key,malformed?'{':JSON.stringify(record));
    return token_key;
  }
  function get(uid){const owner='u1:'+sha(uid);return {
    wallet:sql.prepare('SELECT balance,revision FROM iap_wallet_accounts_v1 WHERE owner_key=?').get(owner)??null,
    canonical:sql.prepare('SELECT status,revision,state_json FROM iap_summon_canonical_v1 WHERE owner_key=?').get(owner)??null,
    events:sql.prepare('SELECT event_key FROM iap_wallet_events_v1 WHERE owner_key=?').all(owner),
  };}
  return {sql,db,ledger,get,close:()=>sql.close()};
}

const repair=(f,uid=UID)=>repairVerifiedPurchases({db:f.db,verifiedIdentity:IDENTITY(uid)});

test('grant_ready purchase credited once and canonical account created from server ledger only',async()=>{
 const f=fixture();try {f.ledger(UID);const a=await repair(f);assert.deepEqual(a,
  {repair_contract_version:1,state:'server_reconciled',verified_purchases:1,new_wallet_credits:1});
 assert.deepEqual({...f.get(UID).wallet},{balance:100,revision:1});
 const canonical=JSON.parse(f.get(UID).canonical.state_json);
 assert.equal(f.get(UID).canonical.status,'verified');
 assert.deepEqual(canonical.cleared_stage_keys,[]);assert.deepEqual(canonical.inventory,{});
 assert.equal(canonical.lifetime_pulls,0);assert.equal(f.get(UID).events.length,1);
 }finally{f.close();}
});

test('replay is idempotent and preserves wallet, stage state and pity',async()=>{
 const f=fixture();try{f.ledger(UID);await repair(f);
 const owner='u1:'+sha(UID);const canonical=JSON.parse(f.get(UID).canonical.state_json);
 canonical.pity.legendary=25;canonical.cleared_stage_keys=['1-1'];
 f.sql.prepare('UPDATE iap_summon_canonical_v1 SET revision=7,state_json=? WHERE owner_key=?')
  .run(JSON.stringify(canonical),owner);
 const replay=await repair(f);assert.equal(replay.new_wallet_credits,0);
 assert.equal(f.get(UID).wallet.balance,100);assert.equal(f.get(UID).wallet.revision,1);
 assert.equal(f.get(UID).canonical.revision,7);
 assert.deepEqual(JSON.parse(f.get(UID).canonical.state_json),canonical);
 }finally{f.close();}
});

test('verified_pending_consume cannot be repaired using only ledger record',async()=>{
 const f=fixture();try{f.ledger(UID,{state:'verified_pending_consume'});
 const result=await repair(f);assert.equal(result.verified_purchases,0);
 assert.equal(f.get(UID).wallet,null);assert.equal(f.get(UID).canonical,null);
 }finally{f.close();}
});

test('different account cannot recover someone else purchase',async()=>{
 const f=fixture();try{f.ledger(UID);
 const result=await repair(f,BAD);assert.equal(result.verified_purchases,0);
 assert.equal(f.get(UID).wallet,null);assert.equal(f.get(BAD).wallet,null);
 }finally{f.close();}
});

test('refund event stops credit and no canonical state minted',async()=>{
 const f=fixture();try{const key=f.ledger(UID);f.sql.prepare(`INSERT INTO iap_play_void_events_v1
 (token_key,voided_time_ms,voided_reason,voided_source) VALUES (?,?,1,0)`).run(key,Date.now());
 await assert.rejects(repair(f));assert.equal(f.get(UID).wallet,null);
 assert.equal(f.get(UID).canonical,null);
 }finally{f.close();}
});

test('held account stops credit for previously verified Play purchase',async()=>{
 const f=fixture();try{f.ledger(UID);const owner='u1:'+sha(UID);
 f.sql.prepare('INSERT INTO iap_wallet_accounts_v1 (owner_key) VALUES (?)').run(owner);
 f.sql.prepare(`INSERT INTO iap_refund_account_holds_v1
  (owner_key,status,reason) VALUES (?,'held','manual_review')`).run(owner);
 await assert.rejects(repair(f));assert.equal(f.get(UID).wallet.balance,0);
 assert.equal(f.get(UID).events.length,0);
 }finally{f.close();}
});

test('stale reconciliation fails closed, replay after fresh watermark repairs',async()=>{
 const f=fixture();try{f.ledger(UID);
 f.sql.prepare(`UPDATE iap_play_void_cursor_v1 SET watermark_ms=?`).run(Date.now()-4*3600000);
 await assert.rejects(repair(f));assert.equal(f.get(UID).wallet,null);
 f.sql.prepare(`UPDATE iap_play_void_cursor_v1 SET watermark_ms=?`).run(FRESH());
 assert.equal((await repair(f)).new_wallet_credits,1);
 }finally{f.close();}
});

test('corrupt record owned by another account is rejected before any credit',async()=>{
 const f=fixture();try{const key=f.ledger(UID);
 const record=JSON.parse(f.sql.prepare('SELECT record_json FROM iap_purchase_ledger_v1 WHERE token_key=?').get(key).record_json);
 record.ownerBinding=sha(BAD);
 f.sql.prepare('UPDATE iap_purchase_ledger_v1 SET record_json=? WHERE token_key=?').run(JSON.stringify(record),key);
 await assert.rejects(repair(f),{name:'PurchaseRepairError',code:'invalid_server_purchase'});
 assert.equal(f.get(UID).wallet,null);
 }finally{f.close();}
});

test('malformed ledger JSON is safely ignored by expression index and query',async()=>{
 const f=fixture();try{f.ledger(UID,{malformed:true});assert.equal((await repair(f)).verified_purchases,0);
 }finally{f.close();}
});

test('concurrent idempotency logically maintained across sequential replays',async()=>{
 const f=fixture();try{f.ledger(UID,{token:'receipt-1'});f.ledger(UID,{token:'receipt-2'});
 assert.equal((await repair(f)).new_wallet_credits,2);
 assert.equal((await repair(f)).new_wallet_credits,0);
 assert.equal(f.get(UID).wallet.balance,200);assert.equal(f.get(UID).wallet.revision,2);
 assert.equal(f.get(UID).events.length,2);
 }finally{f.close();}
});

test('batch limit fails closed without partial writes',async()=>{
 const f=fixture();try{for(let i=0;i<33;i++)f.ledger(UID,{token:`receipt-many-${i}`});
 await assert.rejects(repair(f),{name:'PurchaseRepairError',code:'repair_batch_limit'});
 assert.equal(f.get(UID).wallet,null);assert.equal(f.get(UID).events.length,0);
 }finally{f.close();}
});

test('route gate checks before authentication and D1; cannot turn on accidentally',async()=>{
 let called=0;const handler=createVerifiedPurchaseRepairHandler({
  verifyIdentity:()=>{called++;throw Error('should not happen');},
  repair:()=>{called++;throw Error('should not happen');},
 });
 const r=await handler(new Request('https://example.com/v1/iap/recover-verified',{method:'POST'}),{});
 assert.equal(r.status,503);assert.equal(called,0);
});

test('route needs Firebase identity, App Check, empty POST and explicit recovery flag',async()=>{
 const f=fixture();try{f.ledger(UID);const handler=createVerifiedPurchaseRepairHandler({
   verifyIdentity:()=>IDENTITY(UID),
 });
 const env={DB:f.db,JADE_IAP_BACKEND_ENABLED:'true',JADE_VERIFIED_PURCHASE_REPAIR_ENABLED:'true'};
 const r=await handler(new Request('https://example.com/v1/iap/recover-verified',{method:'POST'}),env);
 assert.equal(r.status,200);assert.equal((await r.json()).new_wallet_credits,1);
 const bad=await handler(new Request('https://example.com/v1/iap/recover-verified',{method:'POST',body:'{}'}),env);
 assert.equal(bad.status,400);
 const invalid=createVerifiedPurchaseRepairHandler({verifyIdentity:()=>{throw new Error('invalid');}});
 const denial=await invalid(new Request('https://example.com/v1/iap/recover-verified',{method:'POST'}),env);
 assert.equal(denial.status,503);assert.equal(f.get(UID).wallet.balance,100);
 }finally{f.close();}
});

test('empty POST Content-Length 0 accepted for native HTTPS connection',async()=>{
 const f=fixture();try{f.ledger(UID);
 const handler=createVerifiedPurchaseRepairHandler({verifyIdentity:()=>IDENTITY(UID)});
 const env={DB:f.db,JADE_IAP_BACKEND_ENABLED:'true',JADE_VERIFIED_PURCHASE_REPAIR_ENABLED:'true'};
 const req=new Request('https://example.com/v1/iap/recover-verified',{
   method:'POST',headers:{'content-length':'0'},
 });
 const out=await handler(req,env);
 assert.equal(out.status,200);
 assert.equal(f.get(UID).wallet.balance,100);
 }finally{f.close();}
});

test('crash after wallet credit but before canonical onboarding is repaired on replay',async()=>{
 const f=fixture();try {f.ledger(UID);
 await assert.rejects(repairVerifiedPurchases({db:f.db,verifiedIdentity:IDENTITY(UID),
   initialize: async()=>{throw Error('simulated process crash');}}));
 assert.equal(f.get(UID).wallet.balance,100);
 assert.equal(f.get(UID).canonical,null);
 const repaired=await repair(f);
 assert.equal(repaired.new_wallet_credits,0);
 assert.equal(f.get(UID).wallet.balance,100);
 assert.equal(f.get(UID).canonical.status,'verified');
 assert.equal(f.get(UID).events.length,1);
 }finally{f.close();}
});

test('all ledger records are validated before first new credit',async()=>{
 const f=fixture();try{f.ledger(UID,{token:'a-valid-grant'});
 const corrupted=f.ledger(UID,{token:'a-corrupt-grant'});
 const record=JSON.parse(f.sql.prepare('SELECT record_json FROM iap_purchase_ledger_v1 WHERE token_key=?').get(corrupted).record_json);
 record.celestialJade=99999;
 f.sql.prepare('UPDATE iap_purchase_ledger_v1 SET record_json=? WHERE token_key=?').run(JSON.stringify(record),corrupted);
 await assert.rejects(repair(f),{name:'PurchaseRepairError',code:'invalid_server_purchase'});
 assert.equal(f.get(UID).events.length,0);
 }finally{f.close();}
});

test('native zero-byte POST stream is accepted and replay cannot credit twice',async()=>{
 const f=fixture();try{f.ledger(UID);
  const handler=createVerifiedPurchaseRepairHandler({verifyIdentity:()=>IDENTITY(UID)});
  const env={DB:f.db,JADE_IAP_BACKEND_ENABLED:'true',JADE_VERIFIED_PURCHASE_REPAIR_ENABLED:'true'};
  for(let i=0;i<2;i++){
   const req=new Request('https://example.com/v1/iap/recover-verified',{method:'POST',headers:{'content-length':'0'},body:''});
   assert.notEqual(req.body,null);
   const out=await handler(req,env);assert.equal(out.status,200);
   assert.equal((await out.json()).new_wallet_credits,i===0?1:0);
  }
  assert.equal(f.get(UID).wallet.balance,100);assert.equal(f.get(UID).events.length,1);
 }finally{f.close();}
});

test('empty stream repair returns zero receipts without inventing wallet/account ownership',async()=>{
 const f=fixture();try{
  const handler=createVerifiedPurchaseRepairHandler({verifyIdentity:()=>IDENTITY(UID)});
  const env={DB:f.db,JADE_IAP_BACKEND_ENABLED:'true',JADE_VERIFIED_PURCHASE_REPAIR_ENABLED:'true'};
  const out=await handler(new Request('https://example.com/v1/iap/recover-verified',{method:'POST',body:''}),env);
  assert.equal(out.status,200);assert.deepEqual(await out.json(),{repair_contract_version:1,state:'server_reconciled',verified_purchases:0,new_wallet_credits:0});
  assert.equal(f.get(UID).wallet,null);assert.equal(f.get(UID).events.length,0);
 }finally{f.close();}
});
test('declared zero length cannot hide a non-empty recovery payload',async()=>{
 let calls=0;const handler=createVerifiedPurchaseRepairHandler({verifyIdentity:()=>{calls++;throw Error();},repair:()=>assert.fail()});
 const out=await handler(new Request('https://example.com/v1/iap/recover-verified',{method:'POST',headers:{'content-length':'0'},body:'{}'}),{});
 assert.equal(out.status,400);assert.equal(calls,0);
});
test('non-terminating recovery body is bounded without reaching identity or ledger',async()=>{
 let calls=0,cancelled=false;
 const handler=createVerifiedPurchaseRepairHandler({verifyIdentity:()=>{calls++;throw Error();},repair:()=>assert.fail()});
 const body=new ReadableStream({cancel(){cancelled=true;}});
 const out=await handler(new Request('https://example.com/v1/iap/recover-verified',{method:'POST',body,duplex:'half'}),{});
 assert.equal(out.status,400);assert.equal(calls,0);assert.equal(cancelled,true);
});
