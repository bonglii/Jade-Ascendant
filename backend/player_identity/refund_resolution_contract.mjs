import {createHash} from 'node:crypto';
export const CASE=Object.freeze({accountRef:'775dc6968aae',creditedJade:100,walletBalance:100,voidedAtMs:Date.parse('2026-10-16T14:05:00Z'),reason:6,source:1,product:'jade_pouch_100'});
export const OWNER_QUERY="SELECT a.owner_key,a.balance,a.revision,h.status AS hold_status,h.reason AS hold_reason,h.revision AS hold_revision FROM iap_wallet_accounts_v1 a LEFT JOIN iap_refund_account_holds_v1 h ON h.owner_key=a.owner_key WHERE a.owner_key LIKE 'u1:"+CASE.accountRef+"%'";
export function quote(value){if(typeof value==='number'){if(!Number.isSafeInteger(value))throw Error('Invalid SQL integer');return String(value);}if(typeof value!=='string')throw Error('Invalid SQL value');return "'"+value.replaceAll("'","''")+"'";}
export function voidQuery(owner){if(!/^u1:[a-f0-9]{64}$/.test(owner))throw Error('Invalid account owner');return `SELECT v.token_key,v.voided_time_ms,v.voided_reason,v.voided_source,e.owner_key AS credit_owner,e.event_kind,e.item_key,e.delta,s.resolution_key,s.credited_jade AS settled_jade FROM iap_play_void_events_v1 v LEFT JOIN iap_wallet_events_v1 e ON e.event_key='iapv1:'||substr(v.token_key,11) LEFT JOIN iap_refund_settlements_v1 s ON s.token_key=v.token_key WHERE v.owner_key=${quote(owner)} ORDER BY v.token_key`;}
export function reviewedPlan(accounts,voids){
 if(!Array.isArray(accounts)||accounts.length!==1)throw Error('Expected exactly one reviewed account');
 const a=accounts[0];if(!new RegExp('^u1:'+CASE.accountRef+'[a-f0-9]{52}$').test(a.owner_key))throw Error('Wrong case account');
 if(!Array.isArray(voids)||voids.length!==1)throw Error('Refund evidence differs from the reviewed single-order case');
 const v=voids[0];if(!/^playtoken:[a-f0-9]{64}$/.test(v.token_key)||(!Number.isSafeInteger(v.voided_time_ms)||Math.floor(v.voided_time_ms/1000)!==CASE.voidedAtMs/1000)||v.voided_reason!==CASE.reason||v.voided_source!==CASE.source||v.credit_owner!==a.owner_key||v.event_kind!=='play_credit'||v.delta!==CASE.creditedJade||v.item_key!==CASE.product)throw Error('Refund/credit evidence differs from reviewed case');
 const key='refundv1:'+createHash('sha256').update(a.owner_key+'|'+v.token_key).digest('hex');
 if(v.resolution_key){if(v.resolution_key!==key||v.settled_jade!==100)throw Error('Existing settlement differs');return {alreadyApplied:true,owner:a.owner_key,key,balance:a.balance,holdStatus:a.hold_status};}
 if(a.hold_status!=='held'||a.hold_reason!=='play_voided_purchase'||a.balance!==CASE.walletBalance||!Number.isSafeInteger(a.revision)||a.revision<0||a.revision>9007199254740989||!Number.isSafeInteger(a.hold_revision)||a.hold_revision<1)throw Error('Account changed since review; no debit authorized by this case');
 return {alreadyApplied:false,owner:a.owner_key,key,debit:100,before:a.balance,after:a.balance-100,revision:a.revision,holdRevision:a.hold_revision,voids:[{token_key:v.token_key,credited_jade:100}]};
}
export function settlementInsert(p){
 if(p.alreadyApplied)throw Error('Settlement already recorded');
 const values=[p.key,p.owner,p.debit,p.before,p.after,p.revision,p.revision+1,p.holdRevision,JSON.stringify(p.voids),'owner_authorized_refund_reconciliation'];
 return 'INSERT INTO iap_refund_resolutions_v1(resolution_key,owner_key,debit_jade,balance_before,balance_after,wallet_revision_before,wallet_revision_after,hold_revision_before,voids_json,review_reason) SELECT '+values.map(quote).join(',')+' WHERE NOT EXISTS(SELECT 1 FROM iap_refund_resolutions_v1 WHERE resolution_key='+quote(p.key)+');';
}
