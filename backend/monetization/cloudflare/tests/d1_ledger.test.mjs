import test from 'node:test';
import assert from 'node:assert/strict';
import { createD1Ledger } from '../src/d1_ledger.mjs';
const KEY = 'playtoken:' + 'a'.repeat(64);
class FakeD1 {
  records = new Map();
  withSession(mode) { assert.equal(mode, 'first-primary'); return this; }
  prepare(sql) {
    return { bind: (...params) => ({
      first: async () => {
        assert.match(sql, /SELECT/);
        return this.records.get(params[0]) || null;
      },
      run: async () => {
        if (sql.startsWith('INSERT')) {
          if (this.records.has(params[0])) return { meta: { changes: 0 } };
          this.records.set(params[0], { record_json: params[1], revision: 1 });
          return { meta: { changes: 1 } };
        }
        if (sql.startsWith('UPDATE')) {
          const before = this.records.get(params[1]);
          if (!before || before.revision !== params[2]) return { meta: { changes: 0 } };
          this.records.set(params[1], { record_json: params[0], revision: before.revision + 1 });
          return { meta: { changes: 1 } };
        }
        throw new Error('Unexpected SQL');
      },
    }) };
  }
}
test('D1 ledger creates, reads, and updates a durable fingerprint record', async () => {
  const db = new FakeD1();
  const ledger = createD1Ledger(db);
  assert.equal(await ledger.runTransaction(KEY, () => ({ result: 'none' })), 'none');
  assert.equal(await ledger.runTransaction(KEY, v => ({ nextRecord: { tokenKey: KEY, state: 'pending' }, result: v })), null);
  assert.equal(db.records.get(KEY).revision, 1);
  const result = await ledger.runTransaction(KEY, old => ({ nextRecord: { ...old, state: 'ready' }, result: old.state }));
  assert.equal(result, 'pending');
  assert.equal(JSON.parse(db.records.get(KEY).record_json).state, 'ready');
  assert.equal(db.records.get(KEY).revision, 2);
});
test('D1 compare-and-swap retries after concurrent revision wins', async () => {
  const db = new FakeD1();
  db.records.set(KEY, { record_json: JSON.stringify({ tokenKey: KEY, state: 'pending' }), revision: 1 });
  const ledger = createD1Ledger(db);
  let calls = 0;
  let resume;
  const blocker = new Promise(r => { resume = r; });
  const delayed = ledger.runTransaction(KEY, async old => {
    calls++;
    if (calls === 1) await blocker;
    return { nextRecord: { ...old, state: calls === 1 ? 'stale' : 'ready' }, result: calls };
  });
  await ledger.runTransaction(KEY, old => ({ nextRecord: { ...old, state: 'updated' }, result: null }));
  resume();
  assert.equal(await delayed, 2);
  assert.equal(JSON.parse(db.records.get(KEY).record_json).state, 'ready');
});
test('D1 ledger rejects malformed fingerprint', async () => {
  const ledger = createD1Ledger(new FakeD1());
  await assert.rejects(ledger.runTransaction('raw.purchase.token', () => ({ result: null })), /Invalid ledger/);
});
