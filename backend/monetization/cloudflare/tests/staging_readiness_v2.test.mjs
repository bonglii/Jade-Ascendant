import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import worker from '../src/worker_staging_tester_r1.mjs';
import {fixture} from './fixtures/paid_gameplay_v2.mjs';
const host='https://jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev';
const flags={JADE_IAP_BACKEND_ENABLED:'true',JADE_PAID_WALLET_CREDIT_V2_ENABLED:'true',JADE_CANONICAL_ONBOARDING_RC12_ENABLED:'true',JADE_PAID_GAMEPLAY_V2_ENABLED:'true',JADE_REFUND_RECONCILIATION_READY:'true',JADE_STAGING_ACCOUNT_GUARD:'true'};
test('health advertises code/config, never device purchase proof',async()=>{
 const r=await worker.fetch(new Request(host+'/health'),flags,{}),s=await r.json();assert.equal(r.status,200);assert.equal(s.service,'jade-iap-staging');assert.equal(s.activation,'tester_credit_only');assert.equal(s.tester_guard,true);assert.equal(s.gameplay_contract,2);assert.equal(s.paid_run_contract,1);assert.deepEqual(Object.keys(s).sort(),['activation','gameplay_contract','paid_run_contract','service','tester_guard']);
});
test('disabled prerequisites or wrong host fail closed',async()=>{
 for(const key of Object.keys(flags).filter(k=>k!=='JADE_STAGING_ACCOUNT_GUARD')){const s=await(await worker.fetch(new Request(host+'/health'),{...flags,[key]:'false'},{})).json();assert.equal(s.paid_run_contract,0,key);assert.equal(s.gameplay_contract,0,key);}
 assert.equal((await worker.fetch(new Request('https://other.workers.dev/health'),flags,{})).status,421);
});
const sql=readFileSync(new URL('../staging_readiness_v2.sql',import.meta.url),'utf8');
test('prerequisite query is read only and does not invent device evidence',()=>{
 assert.ok(!/\b(INSERT|UPDATE|DELETE|DROP|ALTER|ATTACH|REPLACE|CREATE|PRAGMA)\b/i.test(sql));const f=fixture();try{f.sql.prepare('UPDATE iap_play_void_cursor_v1 SET watermark_ms=?').run(Date.now());const s=f.sql.prepare(sql).get();assert.equal(s.paid_schema_ready,1);assert.equal(s.refund_monitor_fresh,1);assert.equal(s.initialized_paid_accounts,0);assert.equal(s.stored_paid_runs,0);assert.equal(s.device_purchase_evidence,'not_checked');}finally{f.close();}
});
test('server-time query rejects stale, future or missing refund poll',()=>{
 const f=fixture();try{for(const ms of [Date.now()-7201000,Date.now()+62000]){f.sql.prepare('UPDATE iap_play_void_cursor_v1 SET watermark_ms=?').run(ms);assert.equal(f.sql.prepare(sql).get().refund_monitor_fresh,0);}f.sql.prepare('DELETE FROM iap_play_void_cursor_v1').run();assert.equal(f.sql.prepare(sql).get().refund_monitor_fresh,0);assert.equal(f.sql.prepare(sql).get().refund_poll_age_seconds,null);}finally{f.close();}
});
