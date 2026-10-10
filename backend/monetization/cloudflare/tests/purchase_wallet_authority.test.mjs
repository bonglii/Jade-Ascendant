import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { createD1Ledger } from '../src/d1_ledger.mjs';
import { createD1Wallet } from '../src/d1_wallet.mjs';
import { authorizeAndCreditPurchase } from '../src/purchase_wallet_authority.mjs';
import { accountBindingForUid, PurchaseAuthorityError } from '../../src/purchase_authority.mjs';

const purchasesSchema = readFileSync(new URL('../migrations/0001_iap_ledger.sql', import.meta.url), 'utf8');
const walletSchema = readFileSync(new URL('../migrations/0002_wallet_ledger.sql', import.meta.url), 'utf8');

class SqliteD1 {
  constructor() {
    this.db = new DatabaseSync(':memory:');
    this.db.exec('PRAGMA foreign_keys=ON;');
    this.db.exec(purchasesSchema);
    this.db.exec(walletSchema);
    this.queue = Promise.resolve();
  }
  withSession(mode) { assert.equal(mode, 'first-primary'); return this; }
  prepare(sql) {
    return {
      bind: (...params) => ({
        first: async () => this.db.prepare(sql).get(...params) ?? null,
        run: async () => {
          const v = this.db.prepare(sql).run(...params);
          return { meta: { changes: v.changes } };
        },
      }),
    };
  }
  async batch(statements) {
    const run = async () => {
      this.db.exec('BEGIN IMMEDIATE');
      try {
        const result = [];
        for (const stmt of statements) result.push(await stmt.run());
        this.db.exec('COMMIT');
        return result;
      } catch (error) {
        this.db.exec('ROLLBACK');
        throw error;
      }
    };
    const next = this.queue.then(run, run);
    this.queue = next.catch(() => {});
    return next;
  }
  eventCount() {
    return this.db.prepare('SELECT COUNT(*) AS n FROM iap_wallet_events_v1').get().n;
  }
  close() { this.db.close(); }
}

const UID = 'firebase_user_one';
const TOKEN_1 = 'play-test-purchase-token-first-12345';
const TOKEN_2 = 'play-test-purchase-token-second-23456';
const request = (uid = UID, token = TOKEN_1) => ({
  auth: { uid, token: { firebase: { sign_in_provider: 'google.com' } } },
  app: { appId: '1:350718070767:android:e5520012a501d2856cf01a' },
  data: { purchase_token: token },
});
function createGateway(uid = UID, token = TOKEN_1, productId = 'jade_pouch_100') {
  let consumed = false;
  const stats = { reads: 0, consumes: 0 };
  return {
    stats,
    async getProductPurchaseV2(pkg, requestedToken) {
      stats.reads++;
      assert.equal(pkg, 'com.yungdevstudio.jadeascendant');
      assert.equal(requestedToken, token);
      return {
        purchaseStateContext: { purchaseState: 'PURCHASED' },
        obfuscatedExternalAccountId: accountBindingForUid(uid),
        productLineItem: [{
          productId,
          productOfferDetails: {
            quantity: 1,
            refundableQuantity: 1,
            consumptionState: consumed ? 'CONSUMPTION_STATE_CONSUMED' : 'CONSUMPTION_STATE_YET_TO_BE_CONSUMED',
          },
        }],
      };
    },
    async consumeProduct(pkg, playId, requestedToken) {
      stats.consumes++;
      assert.equal(pkg, 'com.yungdevstudio.jadeascendant');
      assert.equal(playId, productId);
      assert.equal(requestedToken, token);
      consumed = true;
    },
    get consumed() { return consumed; },
  };
}
function setup() {
  const db = new SqliteD1();
  return { db, ledger: createD1Ledger(db), wallet: createD1Wallet(db) };
}

// These tests use the real authorizePurchase purchase policy, real SQL schema,
// real SQLite transaction rollback, and the M1 wallet module. Google API alone
// is faked; no online calls or production writes.
test('new Play purchase verifies, consumes, records token, and credits one durable wallet event', async () => {
  const { db, ledger, wallet } = setup();
  const playGateway = createGateway();
  const result = await authorizeAndCreditPurchase({ request: request(), playGateway, ledger, wallet });
  assert.equal(result.grant.state, 'grant_ready');
  assert.equal(result.grant.celestial_jade, 100);
  assert.deepEqual(result.wallet, { wallet_contract_version: 1, balance: 100, revision: 1 });
  assert.equal(playGateway.stats.consumes, 1);
  assert.equal(playGateway.consumed, true);
  assert.equal(db.eventCount(), 1);
  const record = db.db.prepare('SELECT record_json FROM iap_purchase_ledger_v1').get();
  assert.equal(JSON.parse(record.record_json).state, 'grant_ready');
  db.close();
});

test('replay on second device under same UID returns same grant without extra credit', async () => {
  const { db, ledger, wallet } = setup();
  const playGateway = createGateway();
  const first = await authorizeAndCreditPurchase({ request: request(), playGateway, ledger, wallet });
  const second = await authorizeAndCreditPurchase({ request: request(), playGateway, ledger, wallet });
  assert.deepEqual(second, first);
  assert.equal(playGateway.stats.consumes, 1);
  assert.equal(playGateway.stats.reads, 1);
  assert.equal(db.eventCount(), 1);
  db.close();
});

test('wallet outage after token consumption cannot return success; replay repairs lost credit', async () => {
  const { db, ledger, wallet } = setup();
  const playGateway = createGateway();
  const outageWallet = { creditVerifiedPurchase: async () => { throw new Error('simulated wallet outage'); } };
  await assert.rejects(authorizeAndCreditPurchase({ request: request(), playGateway, ledger, wallet: outageWallet }), /outage/);
  assert.equal(playGateway.stats.consumes, 1);
  assert.equal(db.eventCount(), 0);
  assert.equal((await wallet.getSnapshot(UID)).balance, 0);
  const retry = await authorizeAndCreditPurchase({ request: request(), playGateway, ledger, wallet });
  assert.equal(retry.wallet.balance, 100);
  assert.equal(db.eventCount(), 1);
  assert.equal(playGateway.stats.consumes, 1);
  db.close();
});

test('a different UID cannot replay a previously consumed purchase or credit another wallet', async () => {
  const { db, ledger, wallet } = setup();
  const playGateway = createGateway();
  await authorizeAndCreditPurchase({ request: request(), playGateway, ledger, wallet });
  await assert.rejects(authorizeAndCreditPurchase({ request: request('other_account'), playGateway, ledger, wallet }),
    e => e instanceof PurchaseAuthorityError && e.code === 'permission-denied');
  assert.equal((await wallet.getSnapshot('other_account')).balance, 0);
  assert.equal(db.eventCount(), 1);
  db.close();
});

test('invalid client-provided amount prevents both Play consume and wallet credit', async () => {
  const { db, ledger, wallet } = setup();
  const playGateway = createGateway();
  const malicious = request();
  malicious.data.celestial_jade = 900000;
  await assert.rejects(authorizeAndCreditPurchase({ request: malicious, playGateway, ledger, wallet }),
    e => e instanceof PurchaseAuthorityError && e.code === 'invalid-argument');
  assert.equal(playGateway.stats.consumes, 0);
  assert.equal(db.eventCount(), 0);
  db.close();
});

test('unverified Play purchase is rejected before any wallet credit', async () => {
  const { db, ledger, wallet } = setup();
  const playGateway = createGateway();
  const originalRead = playGateway.getProductPurchaseV2;
  playGateway.getProductPurchaseV2 = async (...args) => {
    const data = await originalRead(...args);
    return { ...data, purchaseStateContext: { purchaseState: 'PENDING' } };
  };
  await assert.rejects(authorizeAndCreditPurchase({ request: request(), playGateway, ledger, wallet }),
    e => e instanceof PurchaseAuthorityError && e.code === 'failed-precondition');
  assert.equal(playGateway.stats.consumes, 0);
  assert.equal(db.eventCount(), 0);
  db.close();
});

test('two distinct purchases credit once each, shared between devices', async () => {
  const { db, ledger, wallet } = setup();
  const first = await authorizeAndCreditPurchase({ request: request(), playGateway: createGateway(), ledger, wallet });
  const second = await authorizeAndCreditPurchase({ request: request(UID, TOKEN_2),
    playGateway: createGateway(UID, TOKEN_2, 'jade_pouch_550'), ledger, wallet });
  assert.equal(first.wallet.balance, 100);
  assert.equal(second.wallet.balance, 650);
  assert.equal(db.eventCount(), 2);
  db.close();
});

test('duplicate concurrent purchase authorizations produce one wallet event', async () => {
  const { db, ledger, wallet } = setup();
  const playGateway = createGateway();
  const results = await Promise.all([
    authorizeAndCreditPurchase({ request: request(), playGateway, ledger, wallet }),
    authorizeAndCreditPurchase({ request: request(), playGateway, ledger, wallet }),
  ]);
  assert.equal((await wallet.getSnapshot(UID)).balance, 100);
  assert.equal(db.eventCount(), 1);
  assert.equal(results[0].grant.grant_id, results[1].grant.grant_id);
  db.close();
});

test('wallet adapter fails closed with no wallet or invalid receipt', async () => {
  const { db, ledger } = setup();
  const playGateway = createGateway();
  await assert.rejects(authorizeAndCreditPurchase({ request: request(), playGateway, ledger, wallet: null }), /wallet required/);
  assert.equal(playGateway.stats.reads, 0);
  const brokenWallet = { creditVerifiedPurchase: async () => ({ applied: true, balance: NaN, revision: 1, wallet_contract_version: 1 }) };
  await assert.rejects(authorizeAndCreditPurchase({ request: request(), playGateway, ledger, wallet: brokenWallet }), /Invalid durable/);
  db.close();
});
