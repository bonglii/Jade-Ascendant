import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { normalizeTrustedGoogleKeys, SsvRejection } from '../ssv/m7e4b_ssv_verifier.mjs';
import {
  acceptVerifiedSsvReceipt, LedgerRejection, m7e4cStorageContract,
} from '../ssv/m7e4c_receipt_ledger.mjs';

const NOW = 1791470000000;
const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const keys = normalizeTrustedGoogleKeys({ keys: [{ keyId: 1234567, pem: publicKey.export({ type: 'spki', format: 'pem' }) }] });
const BASE_NONCE = 'sGIUaubwceUlTJPH9eJpM7e4c_Q_B74t';
const TX = 'abcdef0123456789abcdef0123456789';
const clone = x => structuredClone(x);

class FakeDocument {
  constructor(db, col, id) { this.db = db; this.col = col; this.id = id; this.path = `${col}/${id}`; }
  async get() { return this.db.snapshot(this.path); }
}
class FakeCollection {
  constructor(db, name) { this.db = db; this.name = name; }
  doc(id) { assert.match(id, /^[A-Za-z0-9_-]{1,128}$/); return new FakeDocument(this.db, this.name, id); }
}
class FakeFirestore {
  constructor() { this.store = new Map(); this.wait = Promise.resolve(); this.failBeforeCommit = false; }
  collection(name) { return new FakeCollection(this, name); }
  snapshot(path, state=this.store) {
    return { exists: state.has(path), data: () => clone(state.get(path)) };
  }
  async runTransaction(fn) {
    const previous = this.wait;
    let release;
    this.wait = new Promise(resolve => { release = resolve; });
    await previous;
    try {
      const queued = [];
      const tx = {
        get: async ref => this.snapshot(ref.path),
        create: (ref, data) => queued.push({ op: 'create', path: ref.path, data: clone(data) }),
        update: (ref, data) => queued.push({ op: 'update', path: ref.path, data: clone(data) }),
        set: (ref, data) => queued.push({ op: 'set', path: ref.path, data: clone(data) }),
      };
      const result = await fn(tx);
      if (this.failBeforeCommit) throw new Error('INJECTED_DATABASE_COMMIT_FAILURE');
      const updated = new Map([...this.store].map(([k, v]) => [k, clone(v)]));
      for (const entry of queued) {
        if (entry.op === 'create' && updated.has(entry.path)) throw new Error('CREATE_ALREADY_EXISTS');
        if (entry.op === 'update' && !updated.has(entry.path)) throw new Error('UPDATE_MISSING');
        updated.set(entry.path, entry.op === 'update'
          ? { ...updated.get(entry.path), ...entry.data }
          : clone(entry.data));
      }
      this.store = updated;
      return result;
    } finally { release(); }
  }
  valuesOf(name) {
    return [...this.store].filter(([k]) => k.startsWith(`${name}/`)).map(([, v]) => clone(v));
  }
  seedIntent(intent) {
    const id = m7e4cStorageContract.intentDocumentIdForNonce(intent.nonce);
    this.store.set(`m7e4c_ssv_intents/${id}`, clone(intent));
  }
}
function intent(n=0, overrides={}) {
  const nonce = `${BASE_NONCE}${String(n).padStart(3,'0')}`;
  return {
    intentId: `intent_${n}`, userId: 'server_authenticated_user_01',
    nonce, placement: 'dao_choice_reroll', runId: `run_${n}`,
    adUnit: '9876543210', rewardAmount: 1, rewardItem: 'rewarded_grant',
    status: 'PENDING', issuedAtMs: NOW - 60_000, expiresAtMs: NOW + 300_000,
    ...overrides,
  };
}
function query(i, transId=TX, overrides={}) {
  const params = {
    ad_network: '12345', ad_unit: i.adUnit, reward_amount: String(i.rewardAmount),
    reward_item: i.rewardItem, timestamp: String(NOW), transaction_id: transId,
    custom_data: i.nonce, user_id: 'spoofed_player_id', ...overrides,
  };
  const raw = Object.entries(params).map(([k,v])=>`${k}=${encodeURIComponent(v)}`).join('&');
  const sig = sign('sha256', Buffer.from(raw), privateKey).toString('base64url');
  return `?${raw}&signature=${sig}&key_id=1234567`;
}
function testRig(i=intent()) {
  const db = new FakeFirestore();
  db.seedIntent(i);
  const accept = (q=query(i), nowMs=NOW) => acceptVerifiedSsvReceipt({ rawQuery:q, db, trustedGoogleKeys:keys, nowMs });
  return {db, i, accept};
}
function assertError(code) {
  return e => (e instanceof LedgerRejection || e instanceof SsvRejection) && e.code === code;
}

test('valid signed callback records receipt, credit, consumed intent, daily count and per-run use atomically', async () => {
  const {db,i,accept}=testRig(); const result=await accept();
  assert.deepEqual(result,{status:'VERIFIED_PENDING_DELIVERY',newlyRecorded:true,transactionId:TX});
  assert.equal(db.valuesOf('m7e4c_ssv_receipts').length,1);
  const [credit]=db.valuesOf('m7e4c_ssv_credits');
  assert.equal(credit.state,'PENDING_DELIVERY');
  assert.equal(credit.userId,i.userId); assert.equal(credit.transactionId,TX);
  assert.equal(db.valuesOf('m7e4c_ssv_intents')[0].status,'CONSUMED');
  assert.equal(db.valuesOf('m7e4c_ssv_daily')[0].total,1);
  assert.equal(db.valuesOf('m7e4c_ssv_runs').length,1);
  assert.equal(Object.hasOwn(credit,'grant'),false);
});
test('identical retry is idempotently acknowledged without a second credit',async()=>{
  const {db,accept}=testRig();await accept();const before=clone([...db.store]);
  assert.deepEqual(await accept(),{status:'ALREADY_RECORDED',newlyRecorded:false,transactionId:TX});
  assert.deepEqual([...db.store],before);
});
test('restart a handler against durable database still sees the exact receipt',async()=>{
  const {db,i,accept}=testRig();await accept();
  const newInvocation=()=>acceptVerifiedSsvReceipt({rawQuery:query(i),trustedGoogleKeys:keys,db,nowMs:NOW});
  assert.equal((await newInvocation()).status,'ALREADY_RECORDED');
  assert.equal(db.valuesOf('m7e4c_ssv_credits').length,1);
});
test('concurrent duplicate signed callbacks result in exactly one credit',async()=>{
  const {db,accept}=testRig();const res=await Promise.all([accept(),accept(),accept()]);
  assert.equal(res.filter(x=>x.newlyRecorded).length,1);
  assert.equal(res.filter(x=>!x.newlyRecorded).length,2);
  assert.equal(db.valuesOf('m7e4c_ssv_credits').length,1);
});
test('same signed transaction id for a second intent conflicts without new credit',async()=>{
  const {db,accept}=testRig();await accept();const second=intent(2,{runId:'another_run'});db.seedIntent(second);
  await assert.rejects(acceptVerifiedSsvReceipt({rawQuery:query(second,TX),trustedGoogleKeys:keys,db,nowMs:NOW}),assertError('TRANSACTION_ID_REPLAY_CONFLICT'));
  assert.equal(db.valuesOf('m7e4c_ssv_credits').length,1);
});
test('a second signed transaction cannot spend an already-consumed intent',async()=>{
  const {db,i,accept}=testRig();await accept();
  await assert.rejects(accept(query(i,'11111111111111111111111111111111')),assertError('INTENT_ALREADY_CONSUMED'));
  assert.equal(db.valuesOf('m7e4c_ssv_credits').length,1);
});
test('injected database commit failure writes NOTHING, retry then succeeds',async()=>{
  const {db,accept}=testRig();db.failBeforeCommit=true;
  await assert.rejects(accept(),/INJECTED_DATABASE_COMMIT_FAILURE/);
  assert.equal(db.valuesOf('m7e4c_ssv_receipts').length,0);
  assert.equal(db.valuesOf('m7e4c_ssv_credits').length,0);
  assert.equal(db.valuesOf('m7e4c_ssv_intents')[0].status,'PENDING');
  db.failBeforeCommit=false;
  assert.equal((await accept()).newlyRecorded,true);
});
test('modified signature cannot create a receipt or credit',async()=>{
  const {db,i,accept}=testRig();await assert.rejects(accept(query(i).replace('reward_amount=1','reward_amount=9')),assertError('SIGNATURE_INVALID'));
  assert.equal(db.valuesOf('m7e4c_ssv_receipts').length,0);
});
test('server-side ad unit binding rejects signed wrong ad unit',async()=>{
  const {db,i,accept}=testRig();await assert.rejects(accept(query(i,TX,{ad_unit:'9999'})),assertError('INTENT_BINDING_MISMATCH'));
  assert.equal(db.valuesOf('m7e4c_ssv_credits').length,0);
});
test('nonce that has never been server-issued is rejected',async()=>{
  const {accept}=testRig();const other=intent(9);
  await assert.rejects(accept(query(other)),assertError('UNKNOWN_SERVER_INTENT'));
});
test('a malformed server-issued intent cannot authorize credits',async()=>{
  const {db,i,accept}=testRig();const corrupted={...i,rewardAmount:-2};db.seedIntent(corrupted);
  await assert.rejects(accept(),assertError('SERVER_INTENT_INVALID'));
});
test('expired pending intent cannot record a new credit even with valid signed SSV',async()=>{
  const {db,i,accept}=testRig();db.seedIntent({...i,expiresAtMs:NOW-1});
  await assert.rejects(accept(),assertError('INTENT_EXPIRED'));
});
test('changing an intent after cryptographic verification is caught by transaction re-read',async()=>{
  const {db,i,accept}=testRig();
  const original=db.runTransaction.bind(db);
  db.runTransaction=async work=>{db.seedIntent({...i,userId:'different_server_user'});return original(work);};
  await assert.rejects(accept(),assertError('SERVER_INTENT_CHANGED'));
  assert.equal(db.valuesOf('m7e4c_ssv_credits').length,0);
});
test('global five NON-revive per-day cap enforced atomically across different placements',async()=>{
  const placements=['daily_completion_cache','refinement_supply','victory_encore','qi_focus','pavilion_seal','offline_cultivation_double'];
  const db=new FakeFirestore();
  for(let n=0;n<placements.length;n++){
    const it=intent(n,{placement:placements[n]});db.seedIntent(it);
    const action=()=>acceptVerifiedSsvReceipt({rawQuery:query(it,String(n+1).repeat(32)),trustedGoogleKeys:keys,db,nowMs:NOW});
    if(n<5)assert.equal((await action()).newlyRecorded,true);
    else await assert.rejects(action(),assertError('GLOBAL_DAILY_CAP_REACHED'));
  }
  assert.equal(db.valuesOf('m7e4c_ssv_daily')[0].total,5);
  assert.equal(db.valuesOf('m7e4c_ssv_credits').length,5);
});
test('same non-revive placement is max 1 per account/day even with new run and nonce',async()=>{
  const db=new FakeFirestore(); const a=intent(1),b=intent(2);
  db.seedIntent(a);db.seedIntent(b);
  const invoke=it=>acceptVerifiedSsvReceipt({rawQuery:query(it,it===a?'a'.repeat(32):'b'.repeat(32)),trustedGoogleKeys:keys,db,nowMs:NOW});
  await invoke(a);await assert.rejects(invoke(b),assertError('PLACEMENT_DAILY_CAP_REACHED'));
  assert.equal(db.valuesOf('m7e4c_ssv_credits').length,1);
});
test('revive does not spend global bonus ad cap but is max once per run',async()=>{
  const db=new FakeFirestore(); const a=intent(1,{placement:'game_over_revive',runId:'run_shared'});
  const b=intent(2,{placement:'game_over_revive',runId:'run_shared'});
  db.seedIntent(a);db.seedIntent(b);
  const invoke=(i,txId)=>acceptVerifiedSsvReceipt({rawQuery:query(i,txId),trustedGoogleKeys:keys,db,nowMs:NOW});
  await invoke(a,'a'.repeat(32));
  await assert.rejects(invoke(b,'b'.repeat(32)),assertError('RUN_PLACEMENT_ALREADY_USED'));
  assert.equal(db.valuesOf('m7e4c_ssv_daily').length,0);
});
test('Dao reroll run use survives a daily boundary, even if daily cap resets',async()=>{
  const db=new FakeFirestore();const first=intent(1,{runId:'long_running_session'});
  const following=intent(2,{runId:'long_running_session',issuedAtMs:NOW+86400000-60000,expiresAtMs:NOW+86400000+60000});
  db.seedIntent(first);db.seedIntent(following);
  await acceptVerifiedSsvReceipt({rawQuery:query(first,'a'.repeat(32)),trustedGoogleKeys:keys,db,nowMs:NOW});
  const future=NOW+86400000;
  const newRaw=query(following,'b'.repeat(32),{timestamp:String(future)});
  await assert.rejects(acceptVerifiedSsvReceipt({rawQuery:newRaw,trustedGoogleKeys:keys,db,nowMs:future}),assertError('RUN_PLACEMENT_ALREADY_USED'));
  assert.equal(db.valuesOf('m7e4c_ssv_credits').length,1);
});
test('runId mandatory for Dao and revive intent, fails closed',async()=>{
  const {db,i,accept}=testRig();const copy=clone(i);delete copy.runId;db.seedIntent(copy);
  await assert.rejects(accept(),assertError('SERVER_INTENT_INVALID'));
});
test('corrupt server daily policy denies a credit',async()=>{
  const {db,accept}=testRig();const day=String(Math.floor(NOW/86400000));
  const path=`m7e4c_ssv_daily/${await findUsageId(db,'server_authenticated_user_01',day)}`;
  db.store.set(path,{total:-1,placements:{}});
  await assert.rejects(accept(),assertError('DAILY_POLICY_CORRUPT'));
});
// Find the opaque hashed daily id using the expected JSON tuple hash, not user-provided identity.
async function findUsageId(_db,userId,day){
  const {createHash}=await import('node:crypto');
  return createHash('sha256').update(JSON.stringify(['day',userId,day])).digest('hex');
}
test('callback user_id spoofing cannot change server-issued identity',async()=>{
  const {db,i,accept}=testRig();await accept(query(i,TX,{user_id:'attacker_user_id'}));
  assert.equal(db.valuesOf('m7e4c_ssv_credits')[0].userId,i.userId);
});
test('no database grants, no credits until a signed callback is processed',()=>{
  const {db}=testRig();assert.equal(db.valuesOf('m7e4c_ssv_credits').length,0);
});
test('missing privileged Firestore rejects rather than using a local untrusted store',async()=>{
  const {i}=testRig();await assert.rejects(acceptVerifiedSsvReceipt({rawQuery:query(i),trustedGoogleKeys:keys,db:{}}),assertError('TRUSTED_DATABASE_REQUIRED'));
});
test('same transaction with corrupt receipt is rejected, never acknowledged as valid',async()=>{
  const {db,accept}=testRig();await accept();const paths=[...db.store.keys()].filter(k=>k.startsWith('m7e4c_ssv_receipts/'));
  db.store.set(paths[0],{...db.store.get(paths[0]),userId:'other'});
  await assert.rejects(accept(),assertError('TRANSACTION_ID_REPLAY_CONFLICT'));
});

test('partial persisted receipt without matching credit is NOT acknowledged',async()=>{
  const {db,accept}=testRig();await accept();
  const creditPath=[...db.store.keys()].find(k=>k.startsWith('m7e4c_ssv_credits/'));
  db.store.delete(creditPath);
  await assert.rejects(accept(),assertError('DURABLE_LEDGER_INVARIANT_BROKEN'));
});
