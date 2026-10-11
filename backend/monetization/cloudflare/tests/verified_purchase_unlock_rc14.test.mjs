import test from 'node:test';
import assert from 'node:assert/strict';
import {
  assertVerifiedPlayCreditRC14, verifiedPlayCreditCasGuardRC14,
  paidPurchaseUnlockEnabledRC14, VerifiedPurchaseUnlockErrorRC14,
} from '../src/verified_purchase_unlock_rc14.mjs';

const a='u1:'+'1'.repeat(64), b='u1:'+'2'.repeat(64);
const events=[{owner_key:a,event_kind:'play_credit'},{owner_key:a,event_kind:'summon_debit'},
  {owner_key:b,event_kind:'summon_debit'}];
const mockDb = (records=events) => ({
  prepare() { throw Error('primary session required'); },
  withSession(mode) {
    assert.equal(mode,'first-primary');
    return {prepare(sql) {
      assert.match(sql,/FROM iap_wallet_events_v1/);
      return {bind(owner) {
        return {async first() {
          return records.some(e=>e.owner_key===owner && e.event_kind==='play_credit') ? {eligible:1}:null;
        }};
      }};
    }};
  },
});

test('verified Play credit allows the paid-only policy',async()=>{
  assert.equal(await assertVerifiedPlayCreditRC14(mockDb(),a),true);
});
test('offline progress and summon debits cannot unlock paid summon',async()=>{
  await assert.rejects(assertVerifiedPlayCreditRC14(mockDb(),b),
    e=>e instanceof VerifiedPurchaseUnlockErrorRC14 && e.code==='no_verified_play_credit');
});
test('invalid or unknown owner fails closed',async()=>{
  for(const owner of ['', 'u1:'+ 'a'.repeat(63),'u1:'+ 'g'.repeat(64),null]){
    await assert.rejects(assertVerifiedPlayCreditRC14(mockDb(),owner),
      e=>e instanceof VerifiedPurchaseUnlockErrorRC14 && e.code==='invalid_owner');
  }
});
test('D1 unavailable fails closed',async()=>{
  await assert.rejects(assertVerifiedPlayCreditRC14({},a),
    e=>e instanceof VerifiedPurchaseUnlockErrorRC14 && e.code==='missing_d1');
});
test('CAS SQL is account-bound and checks server play_credit, not local progress',()=>{
  const g=verifiedPlayCreditCasGuardRC14(a);
  assert.deepEqual(g.bindings,[a]);
  assert.match(g.sql,/event_kind='play_credit'/);
  assert.match(g.sql,/owner_key=\?/);
  assert.doesNotMatch(g.sql,/(?:stage|client|save|progress)/);
});
test('gate is false if any independent approval is false/missing',()=>{
  const base={JADE_IAP_BACKEND_ENABLED:'true',JADE_PAID_SUMMON_WRITE_ENABLED:'true',
    JADE_REFUND_RECONCILIATION_READY:'true',JADE_PAID_SUMMON_PURCHASE_UNLOCK_ENABLED:'true'};
  assert.equal(paidPurchaseUnlockEnabledRC14(base),true);
  for (const k of Object.keys(base)) for(const value of [undefined,'false',true]) {
    assert.equal(paidPurchaseUnlockEnabledRC14({...base,[k]:value}),false);
  }
  assert.equal(paidPurchaseUnlockEnabledRC14({}),false);
});
test('refunded purchase may only be handled by separate atomic refund hold CAS',()=>{
  const guard=verifiedPlayCreditCasGuardRC14(a);
  assert.equal(guard.bindings.length,1);
  // Intentional: does not claim the purchase event alone handles a later refund.
  assert.doesNotMatch(guard.sql,/refund|hold/);
});
