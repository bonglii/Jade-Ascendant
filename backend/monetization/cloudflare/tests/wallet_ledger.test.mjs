import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { createD1Wallet, WalletError } from '../src/d1_wallet.mjs';

const purchaseMigration = readFileSync(new URL('../migrations/0001_iap_ledger.sql', import.meta.url), 'utf8');
const migration = readFileSync(new URL('../migrations/0002_wallet_ledger.sql', import.meta.url), 'utf8');
const ID1 = 'iapv1:' + 'a'.repeat(64);
const ID2 = 'iapv1:' + 'b'.repeat(64);
const SP1 = 'spendv1:' + 'c'.repeat(64);
const grant = (id=ID1, product='jade_pouch_100', jade=100) => ({
  purchase_contract_version: 1, state:'grant_ready', grant_id:id,
  internal_product_id:product, celestial_jade:jade,
});

class SqliteD1 {
  constructor() {
    this.db = new DatabaseSync(':memory:');
    this.db.exec('PRAGMA foreign_keys=ON;');
    this.db.exec(purchaseMigration);
    this.db.exec(migration);
    this.queue = Promise.resolve();
  }
  withSession(mode) { assert.equal(mode,'first-primary'); return this; }
  prepare(sql) {
    const stmt = this.db.prepare(sql);
    return { bind: (...args) => ({ first: async () => stmt.get(...args) || null,
      run: async () => stmt.run(...args) }) };
  }
  batch(statements) {
    const execute = async () => {
      this.db.exec('BEGIN IMMEDIATE');
      try {
        const results = [];
        for (const q of statements) results.push(await q.run());
        this.db.exec('COMMIT');
        return results;
      } catch(e) { this.db.exec('ROLLBACK'); throw e; }
    };
    const next = this.queue.then(execute, execute);
    this.queue = next.catch(() => {});
    return next;
  }
  close() { this.db.close(); }
}

const setup=() => { const db=new SqliteD1();return { db, wallet:createD1Wallet(db) }; };

// These tests use a real SQLite engine with all D1 SQL and transactional
// rollback, not a Map pretending to be a database.
test('empty account snapshot is zero without creating wallet', async () => {
  const {db,wallet}=setup();
  assert.deepEqual(await wallet.getSnapshot('user-A'),{wallet_contract_version:1,balance:0,revision:0});
  assert.equal(db.db.prepare('SELECT COUNT(*) AS n FROM iap_wallet_accounts_v1').get().n,0);
  db.close();
});
test('verified credit is atomic and replay safe', async () => {
  const {db,wallet}=setup();
  assert.deepEqual(await wallet.creditVerifiedPurchase('user-A',grant()),
    {wallet_contract_version:1,balance:100,revision:1,applied:true});
  assert.deepEqual(await wallet.creditVerifiedPurchase('user-A',grant()),
    {wallet_contract_version:1,balance:100,revision:1,applied:false});
  assert.equal(db.db.prepare('SELECT COUNT(*) AS n FROM iap_wallet_events_v1').get().n,1);
  db.close();
});
test('same purchase cannot credit another device/account', async () => {
  const {db,wallet}=setup();
  await wallet.creditVerifiedPurchase('user-A',grant());
  await assert.rejects(wallet.creditVerifiedPurchase('user-B',grant()),{code:'event_conflict'});
  assert.equal((await wallet.getSnapshot('user-B')).balance,0);
  db.close();
});
test('same event with changed product or amount is rejected', async () => {
  const {db,wallet}=setup();
  await wallet.creditVerifiedPurchase('user-A',grant());
  await assert.rejects(wallet.creditVerifiedPurchase('user-A',grant(ID1,'jade_satchel_550',550)),{code:'event_conflict'});
  assert.throws(() => wallet.creditVerifiedPurchase('user-A',grant(ID1,'jade_pouch_100',200)),{code:'invalid_product_amount'});
  db.close();
});
test('two different verified purchases add once each', async () => {
  const {db,wallet}=setup();
  await wallet.creditVerifiedPurchase('user-A',grant());
  await wallet.creditVerifiedPurchase('user-A',grant(ID2,'jade_satchel_550',550));
  assert.equal((await wallet.getSnapshot('user-A')).balance,650);
  db.close();
});
test('debit is atomic, prevents negative balance, retry stays idempotent', async () => {
  const {db,wallet}=setup();
  await wallet.creditVerifiedPurchase('user-A',grant());
  assert.deepEqual(await wallet.debitServerAuthorizedSummon('user-A',
    {spendId:SP1,intent:'summon:1',jadeCost:40}),
    {wallet_contract_version:1,balance:60,revision:2,applied:true});
  assert.equal((await wallet.debitServerAuthorizedSummon('user-A',
    {spendId:SP1,intent:'summon:1',jadeCost:40})).applied,false);
  assert.equal((await wallet.getSnapshot('user-A')).balance,60);
  await assert.rejects(wallet.debitServerAuthorizedSummon('user-A',
    {spendId:'spendv1:'+'e'.repeat(64),intent:'summon:10',jadeCost:70}),{code:'insufficient_funds'});
  assert.equal((await wallet.getSnapshot('user-A')).balance,60);
  assert.equal(db.db.prepare('SELECT COUNT(*) AS n FROM iap_wallet_events_v1').get().n,2);
  db.close();
});
test('debit impossible in empty wallet', async () => {
  const {db,wallet}=setup();
  await assert.rejects(wallet.debitServerAuthorizedSummon('user-A',
    {spendId:SP1,intent:'summon:1',jadeCost:1}),{code:'insufficient_funds'});
  assert.equal((await wallet.getSnapshot('user-A')).balance,0);
  assert.equal(db.db.prepare('SELECT COUNT(*) AS n FROM iap_wallet_events_v1').get().n,0);
  db.close();
});
test('malformed client grant and spend attempts fail closed', async () => {
  const {db,wallet}=setup();
  await assert.rejects(wallet.creditVerifiedPurchase('invalid uid',grant()),{code:'invalid_uid'});
  assert.throws(() => wallet.creditVerifiedPurchase('user-A',{...grant(),arbitrary:1}),{code:'invalid_grant'});
  assert.throws(() => wallet.creditVerifiedPurchase('user-A',grant(ID1,'jade_pouch_100',9000)),{code:'invalid_product_amount'});
  assert.throws(() => wallet.debitServerAuthorizedSummon('user-A',
    {spendId:SP1,intent:'random_client_cost',jadeCost:1}),{code:'invalid_spend'});
  assert.equal(db.db.prepare('SELECT COUNT(*) AS n FROM iap_wallet_events_v1').get().n,0);
  db.close();
});
test('two concurrent duplicate credits settle to one wallet event', async () => {
  const {db,wallet}=setup();
  const result=await Promise.all([wallet.creditVerifiedPurchase('user-A',grant()),wallet.creditVerifiedPurchase('user-A',grant())]);
  assert.equal(result.filter(x=>x.applied).length,1);
  assert.equal((await wallet.getSnapshot('user-A')).balance,100);
  db.close();
});
test('migration is additive and preserves legacy purchase ledger schema', async () => {
  const {db}=setup();
  const names=db.db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map(x=>x.name);
  assert.ok(names.includes('iap_wallet_accounts_v1'));
  assert.ok(names.includes('iap_wallet_events_v1'));
  assert.ok(names.includes('iap_purchase_ledger_v1'));
  db.db.prepare('INSERT INTO iap_purchase_ledger_v1 (token_key, record_json) VALUES (?, ?)').run('playtoken:'+'f'.repeat(64),'{}');
  db.db.exec(migration);
  assert.equal(db.db.prepare('SELECT COUNT(*) AS n FROM iap_purchase_ledger_v1').get().n,1);
  db.close();
});
