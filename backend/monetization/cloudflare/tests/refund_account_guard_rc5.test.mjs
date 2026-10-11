import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import {
  assertNoRefundHoldRC5,
  refundHoldCasPredicateRC5,
  RefundHoldErrorRC5,
} from '../src/refund_account_guard_rc5.mjs';

const owner = 'u1:' + 'a'.repeat(64);
function setup() {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec('PRAGMA foreign_keys=ON');
  sqlite.exec('CREATE TABLE iap_wallet_accounts_v1 (owner_key TEXT PRIMARY KEY)');
  sqlite.prepare('INSERT INTO iap_wallet_accounts_v1 VALUES (?)').run(owner);
  sqlite.exec(readFileSync(new URL('../migrations/0008_refund_account_holds.sql',import.meta.url),'utf8'));
  const reads=[];
  const db = {
    withSession(mode){assert.equal(mode,'first-primary');return this;},
    prepare(sql){reads.push(sql);return {bind:(...args)=>({first:async()=>sqlite.prepare(sql).get(...args)??null})};},
  };
  return {sqlite,db,reads};
}
test('unheld account allowed via primary-consistent read',async()=>{
  const {sqlite,db,reads}=setup();
  assert.equal(await assertNoRefundHoldRC5({db,owner}),true);
  assert.equal(reads.length,1);sqlite.close();
});
test('server hold denies paid operations',async()=>{
  const {sqlite,db}=setup();
  sqlite.prepare("INSERT INTO iap_refund_account_holds_v1 (owner_key,status,reason) VALUES (?,?,?)")
    .run(owner,'held','play_voided_purchase');
  await assert.rejects(assertNoRefundHoldRC5({db,owner}),
    {name:'RefundHoldErrorRC5',code:'paid_account_on_hold'});
  sqlite.close();
});
test('only explicit release clears a hold',async()=>{
  const {sqlite,db}=setup();
  sqlite.prepare('INSERT INTO iap_refund_account_holds_v1 (owner_key,status,reason) VALUES (?,?,?)')
    .run(owner,'released','manual_review');
  assert.equal(await assertNoRefundHoldRC5({db,owner}),true);sqlite.close();
});
test('malformed owner is rejected without db read',async()=>{
  const {sqlite,db,reads}=setup();
  await assert.rejects(assertNoRefundHoldRC5({db,owner:'../bad'}),RefundHoldErrorRC5);
  assert.equal(reads.length,0);sqlite.close();
});
test('refund hold predicate blocks a state update atomically',()=>{
  const {sqlite}=setup();
  sqlite.exec('CREATE TABLE iap_summon_canonical_v1 (owner_key TEXT PRIMARY KEY, revision INTEGER CHECK(revision >= 0))');
  sqlite.prepare('INSERT INTO iap_summon_canonical_v1 VALUES (?,0)').run(owner);
  const sql=`UPDATE iap_summon_canonical_v1 SET revision=CASE WHEN revision=?
    ${refundHoldCasPredicateRC5()} THEN revision+1 ELSE -1 END WHERE owner_key=?`;
  sqlite.exec('BEGIN');sqlite.prepare(sql).run(0,owner);sqlite.exec('COMMIT');
  assert.equal(sqlite.prepare('SELECT revision FROM iap_summon_canonical_v1').get().revision,1);
  sqlite.prepare("INSERT INTO iap_refund_account_holds_v1 (owner_key,status,reason) VALUES (?,?,?)")
    .run(owner,'held','chargeback_review');
  assert.throws(()=>sqlite.prepare(sql).run(1,owner),/CHECK constraint failed/);
  assert.equal(sqlite.prepare('SELECT revision FROM iap_summon_canonical_v1').get().revision,1);
  sqlite.close();
});
test('missing hold table fails closed, not falsely clear',async()=>{
  const {sqlite,db}=setup();
  sqlite.exec('DROP TABLE iap_refund_account_holds_v1');
  await assert.rejects(assertNoRefundHoldRC5({db,owner}),/no such table/);
  sqlite.close();
});
