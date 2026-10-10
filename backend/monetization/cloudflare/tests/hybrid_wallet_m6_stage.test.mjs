import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { classifyLegacyJade, planHybridSummon } from '../src/hybrid_wallet_policy_stage.mjs';
import { getVerifiedPaidWalletView } from '../src/hybrid_paid_wallet_view_stage.mjs';
import { createD1Wallet } from '../src/d1_wallet.mjs';

const saved=(jade=0,ids=[])=>({celestial_jade:jade,processed_iap_grant_ids:ids});
const plan=(source='auto',pullCount=1,earnedJade=0,legacyJade=0,online=true)=>planHybridSummon({source,pullCount,earnedJade,legacyJade,online});
const auth=(uid='device_owner')=>({auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}},app:{appId:'1:350718070767:android:e5520012a501d2856cf01a'}});
const grant=(id='a')=>({purchase_contract_version:1,state:'grant_ready',grant_id:'iapv1:'+id.repeat(64),internal_product_id:'jade_casket_1200',celestial_jade:1200});
class SqliteD1 {
  constructor(){this.db=new DatabaseSync(':memory:');this.db.exec('PRAGMA foreign_keys=ON');
    for(const f of ['0001_iap_ledger.sql','0002_wallet_ledger.sql'])this.db.exec(readFileSync(new URL('../migrations/'+f,import.meta.url),'utf8'));
    this.queue=Promise.resolve();}
  withSession(name){assert.equal(name,'first-primary');return this;}
  prepare(sql){const s=this.db.prepare(sql);return {bind:(...args)=>({first:async()=>s.get(...args)??null,run:async()=>s.run(...args)})};}
  batch(statements){const execute=async()=>{this.db.exec('BEGIN IMMEDIATE');try{for(const stmt of statements)await stmt.run();this.db.exec('COMMIT');}catch(e){this.db.exec('ROLLBACK');throw e;}};const next=this.queue.then(execute,execute);this.queue=next.catch(()=>{});return next;}
  close(){this.db.close();}
}

test('old save amount preserved as LEGACY not magically server-paid',()=>{const s=saved(1200,['iapv1:old']);const before=structuredClone(s);const x=classifyLegacyJade(s);assert.equal(x.legacy_unclassified_jade,1200);assert.equal(x.auto_paid_credit,0);assert.equal(x.needs_reconciliation,true);assert.deepEqual(s,before);});
test('empty new save safely creates no obligation to reconcile',()=>{assert.equal(classifyLegacyJade(saved()).needs_reconciliation,false);});
test('old legacy amount without grants remains unclassified',()=>{assert.equal(classifyLegacyJade(saved(100)).needs_reconciliation,true);});
test('old grant receipt with spent balance still demands reconciliation',()=>{assert.equal(classifyLegacyJade(saved(0,['iapv1:old'])).needs_reconciliation,true);});
test('invalid legacy strings cannot be converted into credit',()=>{assert.throws(()=>classifyLegacyJade({celestial_jade:'900'}),{code:'invalid_legacy_save'});});
test('negative and fractional legacy values rejected',()=>{for(const n of [-1,1.5,Number.MAX_VALUE])assert.throws(()=>classifyLegacyJade(saved(n)),{code:'invalid_legacy_save'});});
test('invalid legacy receipt array fails closed',()=>{assert.throws(()=>classifyLegacyJade(saved(1,'bad')),{code:'invalid_legacy_grants'});});
test('earned jade 100 previews local lane only, without server debit',()=>{const x=plan('earned',1,100,0,false);assert.equal(x.source,'earned');assert.equal(x.local_debit,-100);assert.equal(x.requires_server_authorization,false);});
test('legacy offline jade can be previewed without migration or conversion',()=>{const x=plan('legacy',1,0,100,false);assert.equal(x.operation,'legacy_local_only_pending_game_atomic_commit');assert.equal(x.local_debit,-100);});
test('paid jade never gets local debit even if client says it can pay',()=>{const x=plan('paid',10,99999,99999,true);assert.equal(x.operation,'server_authorization_required');assert.equal(x.local_debit,0);assert.equal(x.cost,900);assert.equal(x.requires_server_authorization,true);});
test('paid spend blocked offline regardless of local balances',()=>{assert.equal(plan('paid',1,10000,10000,false).operation,'paid_requires_network');});
test('auto prioritizes earned lane then legacy lane, not merging',()=>{assert.equal(plan('auto',1,100,100).source,'earned');assert.equal(plan('auto',1,99,100).source,'legacy');});
test('auto cannot blend 500 earned with 500 legacy for 900 cost',()=>{const x=plan('auto',10,500,500,false);assert.equal(x.source,'none');assert.equal(x.local_debit,0);});
test('auto cannot blend local and cached paid balance',()=>{const x=plan('auto',10,500,0,true);assert.equal(x.source,'paid');assert.equal(x.local_debit,0);});
test('auto routes to server when online and no local lane sufficient',()=>{assert.equal(plan('auto',10,0,0,true).operation,'server_authorization_required');});
test('auto returns blocked when no local lane and offline',()=>{assert.equal(plan('auto',10,0,0,false).operation,'insufficient_single_lane');});
test('validates modes, pull counts and no negative/fractional local balance',()=>{assert.throws(()=>plan('gift',1,0,0),{code:'invalid_source'});assert.throws(()=>plan('paid',4,0,0),{code:'invalid_pull_count'});assert.throws(()=>plan('paid',1,-1,0),{code:'invalid_local_balance'});assert.throws(()=>plan('paid',1,0,0.5),{code:'invalid_local_balance'});});
test('paid projection rejects missing Auth or App Check context',async()=>{const wallet={getSnapshot:async()=>({wallet_contract_version:1,balance:1,revision:1})};await assert.rejects(getVerifiedPaidWalletView({verifiedIdentity:{},wallet}),{code:'verified_identity_required'});});
test('paid projection rejects unsupported identity provider',async()=>{const wallet={getSnapshot:async()=>({wallet_contract_version:1,balance:1,revision:1})};const identity=auth();identity.auth.token.firebase.sign_in_provider='custom';await assert.rejects(getVerifiedPaidWalletView({verifiedIdentity:identity,wallet}),{code:'verified_identity_required'});});
test('paid projection rejects malformed snapshot and missing wallet',async()=>{await assert.rejects(getVerifiedPaidWalletView({verifiedIdentity:auth(),wallet:{getSnapshot:async()=>({wallet_contract_version:1,balance:-1,revision:0})}}),{code:'invalid_paid_wallet_snapshot'});await assert.rejects(getVerifiedPaidWalletView({verifiedIdentity:auth(),wallet:null}),{code:'authoritative_wallet_required'});});
test('paid view reads server D1 only and never credits old local jade',async()=>{const db=new SqliteD1();try{const wallet=createD1Wallet(db);const old=classifyLegacyJade(saved(900,['iapv1:old']));const before=await getVerifiedPaidWalletView({verifiedIdentity:auth(),wallet});assert.equal(before.paid_wallet.balance,0);assert.equal(old.auto_paid_credit,0);assert.equal(db.db.prepare('SELECT COUNT(*) AS n FROM iap_wallet_events_v1').get().n,0);}finally{db.close();}});
test('two devices of same account see one paid wallet, grant replay cannot double balance',async()=>{const db=new SqliteD1();try{const wallet=createD1Wallet(db);await wallet.creditVerifiedPurchase('device_owner',grant());await wallet.creditVerifiedPurchase('device_owner',grant());const a=await getVerifiedPaidWalletView({verifiedIdentity:auth(),wallet});const b=await getVerifiedPaidWalletView({verifiedIdentity:auth(),wallet});assert.deepEqual(a,b);assert.equal(a.paid_wallet.balance,1200);assert.equal(a.paid_wallet.revision,1);assert.equal(a.local_wallet_authority,'device_only_untrusted');assert.equal(a.legacy_wallet_migration,'requires_explicit_reconciliation');}finally{db.close();}});
test('paid wallet is scoped to signed-in Firebase UID, not an offline balance',async()=>{const db=new SqliteD1();try{const wallet=createD1Wallet(db);await wallet.creditVerifiedPurchase('device_owner',grant());const b=await getVerifiedPaidWalletView({verifiedIdentity:auth('other_user'),wallet});assert.equal(b.paid_wallet.balance,0);}finally{db.close();}});
test('server database read failure propagates instead of falling back to local claims',async()=>{const e=new Error('D1 outage');await assert.rejects(getVerifiedPaidWalletView({verifiedIdentity:auth(),wallet:{getSnapshot:async()=>{throw e;}}}),e);});
