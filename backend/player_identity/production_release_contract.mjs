import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
export const LIVE_GATES=Object.freeze(['JADE_REAL_MONEY_RELEASE_ENABLED','JADE_IAP_BACKEND_ENABLED','JADE_PAID_WALLET_CREDIT_V2_ENABLED','JADE_CANONICAL_ONBOARDING_RC12_ENABLED','JADE_PAID_GAMEPLAY_V2_ENABLED','JADE_PAID_WALLET_READ_ENABLED','JADE_REFUND_RECONCILIATION_READY','JADE_REFUND_CRON_JOB_RC7_ENABLED','JADE_VERIFIED_PURCHASE_REPAIR_ENABLED']);
export const TABLES=Object.freeze(['iap_purchase_ledger_v1','iap_wallet_accounts_v1','iap_wallet_events_v1','iap_summon_outcomes_v1','iap_summon_canonical_v1','iap_paid_loadouts_v1','iap_paid_loadout_ops_v1','iap_trusted_stage_evidence_v1','iap_summon_request_index_v1','iap_refund_account_holds_v1','iap_play_void_events_v1','iap_play_void_cursor_v1','iap_paid_gameplay_v2','iap_paid_commands_v2','iap_paid_runs_v2']);
export function assertConfig(text){
 const databases=[...text.matchAll(/^\[\[d1_databases\]\]\s*$([\s\S]*?)(?=^\[|$(?![\s\S]))/gm)];
 if(databases.length!==1)throw Error('ambiguous_production_database');
 const get=key=>{const scope=['binding','database_name','database_id'].includes(key)?databases[0][1]:text;const matches=[...scope.matchAll(new RegExp('^'+key+'\\s*=\\s*"([^"\\r\\n]*)"\\s*$','gm'))];if(matches.length!==1)throw Error('ambiguous_config_'+key);return matches[0][1];};
 for(const [key,value] of Object.entries({name:'jade-ascendant-iap',main:'src/worker_paid_production_v2.mjs',binding:'DB',database_name:'jade-iap-ledger',database_id:'f0e59ec4-effb-4002-b9a5-d246965b5b83',FIREBASE_PROJECT_ID:'jade-ascendant',FIREBASE_PROJECT_NUMBER:'350718070767',JADE_ANDROID_FIREBASE_APP_ID:'1:350718070767:android:e5520012a501d2856cf01a',JADE_STAGING_ACCOUNT_GUARD:'false'}))if(get(key)!==value)throw Error('wrong_production_'+key);
 for(const gate of LIVE_GATES)if(get(gate)!=='true')throw Error('production_gate_locked_'+gate);
 for(const [,key,value] of text.matchAll(/^(JADE_[A-Z0-9_]+)\s*=\s*"([^"\r\n]*)"\s*$/gm)){
  if(key.endsWith('_ENABLED')&&value==='true'&&!LIVE_GATES.includes(key))throw Error('unreviewed_live_gate_'+key);
 }
 if(!/^crons\s*=\s*\["\*\/15 \* \* \* \*"\]\s*$/m.test(text))throw Error('production_refund_schedule_missing');
 return true;
}
export function assertReadiness(value){
 if(!Array.isArray(value)||value.length!==1||value[0].success!==true||value[0].results?.length!==1)throw Error('readiness_query_failed');
 const row=value[0].results[0];
 if(row.schema_count!==TABLES.length)throw Error('production_schema_incomplete');
 if(!Number.isSafeInteger(row.refund_age_seconds)||row.refund_age_seconds<0||row.refund_age_seconds>1200)throw Error('production_refund_monitor_not_fresh');
 return true;
}
export const readinessSQL=`SELECT (SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN (${TABLES.map(x=>"'"+x+"'").join(',')})) AS schema_count,(SELECT CAST(strftime('%s','now') AS INTEGER)-CAST(strftime('%s',updated_at) AS INTEGER) FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp') AS refund_age_seconds`;
if(process.argv[1]===fileURLToPath(import.meta.url)){
 try{
  if(process.argv[2]==='sql')console.log(readinessSQL);
  else if(process.argv[2]==='readiness') {assertReadiness(JSON.parse(readFileSync(process.argv[3],'utf8')));console.log('PRODUCTION_SCHEMA_AND_REFUND=PASS');}
  else {assertConfig(readFileSync(new URL('../monetization/cloudflare/wrangler.production-live.toml',import.meta.url),'utf8'));console.log('PRODUCTION_CONFIG=PASS; GATES=9; TARGET=EXISTING_PRODUCTION');}
 }catch(error){console.error(error.message);process.exitCode=1;}
}
