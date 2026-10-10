import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import {
  readPendingEntitlements, createPendingInboxCallable,
  m7e4eInboxContract,
} from '../ssv/m7e4e_pending_inbox.mjs';

const key = (...x) => createHash('sha256').update(JSON.stringify(x)).digest('hex');
const uid = 'firebase_user_123';
const makeCredit = (i = 'abc') => ({
  intentId: `intent_${i}`, transactionId: `transaction_${i}`,
  userId: uid, placement: 'dao_choice_reroll', rewardItem: 'reroll',
  rewardAmount: 1, state: 'PENDING_DELIVERY', createdAtMs: 123,
});
const makeReceipt = credit => ({
  ...credit, state: 'VERIFIED_PENDING_DELIVERY',
});
function database(creditList = [makeCredit()], overrides = {}) {
  const docs = creditList.map(credit => ({
    id: key('intent', credit.intentId), data: () => ({ ...credit }),
  }));
  const receipts = Object.fromEntries(creditList.map(c => [c.transactionId, makeReceipt(c)]));
  Object.assign(receipts, overrides);
  const events = [];
  const db = {
    events,
    collection(name) {
      events.push(['collection', name]);
      if (name === 'm7e4c_ssv_receipts') return {
        doc(id) {
          events.push(['doc', id]);
          return { async get() {
            const data = receipts[id];
            return { exists: Boolean(data), data: () => data };
          } };
        },
      };
      if (name !== 'm7e4c_ssv_credits') throw Error('WRONG_COLLECTION');
      let filters = [], cap = 0;
      const q = {
        where(field, op, value) { filters.push([field, op, value]); return q; },
        limit(n) { cap = n; return q; },
        async get() {
          events.push(['query', filters, cap]);
          let out = docs;
          for (const [field, op, value] of filters) {
            if (op !== '==') throw Error('BAD_QUERY');
            out = out.filter(x => x.data()[field] === value);
          }
          return { docs: out.slice(0, cap) };
        },
      };
      return q;
    },
  };
  return db;
}
function setupCallable({ enabled = true, db = database() } = {}) {
  let options;
  let handler;
  class HttpsError extends Error {
    constructor(code, message) { super(message); this.code = code; }
  }
  createPendingInboxCallable({
    onCall(o, fn) { options = o; handler = fn; return fn; },
    HttpsError,
    getDb: () => db,
    enabled,
  });
  return { invoke: req => handler(req), options, db };
}

test('foundation defaults to disabled and read-only', () => {
  assert.equal(m7e4eInboxContract.productionEnabled, false);
  assert.equal(m7e4eInboxContract.writesAllowed, false);
  assert.equal(m7e4eInboxContract.gameplayGrantAllowed, false);
  assert.equal(m7e4eInboxContract.clientAckAllowed, false);
  assert.equal(m7e4eInboxContract.callableRegistered, false);
});
test('retrieves only verified user pending credit with validated receipt', async () => {
  const d = database([makeCredit(), {...makeCredit('other'), userId: 'someone_else'}]);
  const r = await readPendingEntitlements({ db: d, authenticatedUid: uid });
  assert.equal(r.items.length, 1);
  assert.equal(r.items[0].entitlementId, key('intent', 'intent_abc'));
  assert.equal(r.items[0].state, 'PENDING_DELIVERY');
  assert.equal(r.hasMore, false);
  assert.equal(r.creditAllowed, false);
  assert.equal(r.clientAckAllowed, false);
  assert.equal('transactionId' in r.items[0], false);
  assert.equal('userId' in r.items[0], false);
  assert.equal('nonce' in r.items[0], false);
  assert.ok(d.events.some(e => e[0] === 'query' && e[2] === 21));
  assert.ok(d.events.some(e => e[0] === 'query' && e[1].some(f => f[0] === 'userId' && f[2] === uid)));
});
test('no verified user rejected without database read', async () => {
  const d = database();
  await assert.rejects(readPendingEntitlements({ db:d, authenticatedUid:'' }), /AUTH_REQUIRED/);
  assert.equal(d.events.length, 0);
});
test('does not accept arbitrary database or client uid as authentication', async () => {
  await assert.rejects(readPendingEntitlements({authenticatedUid:uid}), /TRUSTED_DATABASE_REQUIRED/);
});
test('missing receipt causes whole inbox to fail closed', async () => {
  await assert.rejects(readPendingEntitlements({db:database([makeCredit()], {transaction_abc: null}), authenticatedUid:uid}), /DURABLE_LEDGER_INVARIANT_BROKEN/);
});
test('mismatched receipt cannot be listed as valid', async () => {
  await assert.rejects(readPendingEntitlements({db:database([makeCredit()], {transaction_abc:{...makeReceipt(makeCredit()), rewardAmount:22}}), authenticatedUid:uid}), /DURABLE_LEDGER_INVARIANT_BROKEN/);
});
test('mutated credit record is refused', async () => {
  await assert.rejects(readPendingEntitlements({db:database([{...makeCredit(), rewardAmount:-5}]),authenticatedUid:uid}), /DURABLE_CREDIT_INVALID/);
});
test('unregistered factory is disabled by default, with enforced App Check', async () => {
  const x = setupCallable({ enabled:false });
  assert.equal(x.options.enforceAppCheck, true);
  await assert.rejects(x.invoke({auth:{uid},data:{}}), e=>e.code==='unavailable'&&e.message==='INBOX_DISABLED');
  assert.equal(x.db.events.length,0);
});
test('rejects unauthenticated and supplied user IDs', async () => {
  const x = setupCallable();
  await assert.rejects(x.invoke({data:{}}),e=>e.code==='unauthenticated');
  await assert.rejects(x.invoke({auth:{uid},data:{uid}}),e=>e.code==='invalid-argument');
  assert.equal(x.db.events.length,0);
});
test('authenticated callable works using auth.uid, no request fields', async () => {
  const x = setupCallable();
  const r = await x.invoke({auth:{uid},data:{}});
  assert.equal(r.status,'READ_ONLY_PENDING');
  assert.equal(r.items.length,1);
});
test('database error returns generic unavailable, without raw details', async () => {
  const x = setupCallable({db:{collection(){throw new Error('Sensitive service token')}}});
  await assert.rejects(x.invoke({auth:{uid},data:{}}), e=>e.code==='unavailable' && !e.message.includes('Sensitive'));
});
test('truncates to bounded read limit and indicates more results', async () => {
  const lots=Array.from({length:23},(_,i)=>({...makeCredit(String(i)),createdAtMs:i}));
  const x=await readPendingEntitlements({db:database(lots),authenticatedUid:uid});
  assert.equal(x.items.length,20);
  assert.equal(x.hasMore,true);
});
test('duplicate client ID cannot change other user query', async () => {
  const other={...makeCredit('other'),userId:'another'};
  const x=setupCallable({db:database([other])});
  const r=await x.invoke({auth:{uid},data:{}});
  assert.equal(r.items.length,0);
});
