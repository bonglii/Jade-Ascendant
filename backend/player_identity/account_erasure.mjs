import {createHash,randomUUID} from 'node:crypto';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
export const TARGETS={profile:{account:'ee6b437305c6145769a57ff3b9effe44',id:'1089de95-8cdc-447d-a9e3-9e743d200cba',name:'jade-player-identities'},iap:{account:'ee6b437305c6145769a57ff3b9effe44',id:'f0e59ec4-effb-4002-b9a5-d246965b5b83',name:'jade-iap-ledger'}};
export const GAMEPLAY_TABLES=['iap_paid_runs_v2','iap_paid_commands_v2','iap_paid_gameplay_v2','iap_paid_loadout_ops_v1','iap_paid_loadouts_v1','iap_trusted_stage_evidence_v1','iap_summon_request_index_v1','iap_summon_outcomes_v1','iap_summon_canonical_v1'];
export const PROFILE_OWNER_TABLES=['mail_claim_resolution','mail_claims','mail_recipients','mail_player_activity','player_announcement_reads','player_progress_backups_v1','player_identities'];
const hash=s=>createHash('sha256').update(s).digest('hex');
function sqlForOwner(owner){
 const ownerKey='u1:'+owner,q="'"+owner+"'",k="'"+ownerKey+"'";
 const targetUID=`(SELECT public_uid FROM player_identities WHERE owner_binding=${q})`;
 // Keep shared content and other recipients intact. Remove targeted drafts/jobs and their audit references.
 const privateCampaign=`SELECT id FROM mail_campaigns WHERE audience='uid' AND target_uid=${targetUID}`;
 const profile=[
 `DELETE FROM mail_admin_audit WHERE (json_valid(detail_json) AND (json_extract(detail_json,'$.owner_binding')=${q} OR json_extract(detail_json,'$.mail_id') IN (${privateCampaign})))`,
 `DELETE FROM mail_drafts WHERE json_valid(draft_json) AND json_extract(draft_json,'$.audience')='uid' AND json_extract(draft_json,'$.target_uid')=${targetUID}`,
 `DELETE FROM mail_jobs WHERE json_valid(draft_json) AND json_extract(draft_json,'$.audience')='uid' AND json_extract(draft_json,'$.target_uid')=${targetUID}`,
 ...PROFILE_OWNER_TABLES.slice(0,-1).map(t=>`DELETE FROM ${t} WHERE owner_binding=${q}`),
 `DELETE FROM mail_archives WHERE mail_id IN (${privateCampaign})`,
 `DELETE FROM mail_campaigns WHERE id IN (${privateCampaign})`,
 `DELETE FROM player_identities WHERE owner_binding=${q}`
 ].map(s=>s+';').join('\n')+'\n';
 const iap=GAMEPLAY_TABLES.map(t=>`DELETE FROM ${t} WHERE owner_key=${k};`).join('\n')+'\n';
 const profileCount=PROFILE_OWNER_TABLES.map(t=>`(SELECT COUNT(*) FROM ${t} WHERE owner_binding=${q})`).join('+');
 const iapCount=GAMEPLAY_TABLES.map(t=>`(SELECT COUNT(*) FROM ${t} WHERE owner_key=${k})`).join('+');
 return {profile,iap,profileCount,iapCount,targetUID};
}
export function makeErasurePlan(input,now=Date.now()){
 if(!input||Array.isArray(input)||Object.keys(input).sort().join(',')!=='firebase_deleted_at,firebase_uid,ownership_verified,request_verified')throw Error('invalid_verified_input');
 if(input.ownership_verified!==true||input.request_verified!==true)throw Error('verify_request_and_ownership_first');
 if(typeof input.firebase_uid!=='string'||input.firebase_uid.length<1||input.firebase_uid.length>128||/[\x00-\x20\x7f]/.test(input.firebase_uid))throw Error('private_firebase_uid_required_not_public_uid');
 if(/^JA[0-9A-HJKMNP-TV-Z]{10}$/.test(input.firebase_uid))throw Error('public_uid_is_not_firebase_uid');
 const deleted=typeof input.firebase_deleted_at==='string'?Date.parse(input.firebase_deleted_at):NaN;
 if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(input.firebase_deleted_at)||!Number.isFinite(deleted)||now-deleted<65*60000)throw Error('delete_firebase_auth_first_then_wait_65_minutes_for_existing_id_tokens');
 const owner=hash(input.firebase_uid),ownerKey='u1:'+owner;
 const {profile,iap,profileCount,iapCount,targetUID}=sqlForOwner(owner);
 return {format:1,case_id:randomUUID(),created_at:new Date(now).toISOString(),firebase_deleted_at:new Date(deleted).toISOString(),firebase_deletion_evidence:'operator_attested_not_independently_verified',targets:TARGETS,owner_binding:owner,owner_key:ownerKey,profile_sql:profile,iap_sql:iap,profile_sha256:hash(profile),iap_sha256:hash(iap),profile_check:`SELECT ${profileCount} AS remaining_account_rows,${targetUID} AS public_uid`,iap_check:`SELECT ${iapCount} AS remaining_gameplay_rows`,retained:'Purchase, wallet, refund and minimum security evidence only; no paid/gameplay rows are retained by this plan.'};
}
export function validatePlan(plan){
 if(plan?.format!==1||!/^[a-f0-9]{64}$/.test(plan.owner_binding)||plan.owner_key!=='u1:'+plan.owner_binding||JSON.stringify(plan.targets)!==JSON.stringify(TARGETS)||hash(plan.profile_sql)!==plan.profile_sha256||hash(plan.iap_sql)!==plan.iap_sha256)throw Error('plan_integrity_failed');
 const expected=sqlForOwner(plan.owner_binding);
 if(plan.profile_sql!==expected.profile||plan.iap_sql!==expected.iap||plan.profile_check!==`SELECT ${expected.profileCount} AS remaining_account_rows,${expected.targetUID} AS public_uid`||plan.iap_check!==`SELECT ${expected.iapCount} AS remaining_gameplay_rows`)throw Error('erasure_sql_scope_changed');
 // Regenerate the exact SQL from the bound identity hash without requiring the private UID again.
 for(const sql of [plan.profile_sql,plan.iap_sql])if(/\b(?:DROP|TRUNCATE|UPDATE|INSERT|ATTACH|PRAGMA)\b/i.test(sql))throw Error('unexpected_erasure_statement');
 const deletes=[...plan.profile_sql.matchAll(/DELETE FROM ([a-z0-9_]+)/g),...plan.iap_sql.matchAll(/DELETE FROM ([a-z0-9_]+)/g)].map(x=>x[1]);
 if(deletes.length!==21||deletes.some(t=>!['mail_admin_audit','mail_drafts','mail_jobs','mail_archives','mail_campaigns',...PROFILE_OWNER_TABLES,...GAMEPLAY_TABLES].includes(t)))throw Error('unexpected_erasure_scope');
 return plan;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const mode=process.argv[2];
  if(mode==='prepare'){
   const plan=makeErasurePlan(JSON.parse(readFileSync(0,'utf8').replace(/^\uFEFF/,'')));
   const root=resolve(dirname(fileURLToPath(import.meta.url)),'../../.local/account_erasure',plan.case_id);mkdirSync(root,{recursive:true,mode:0o700});
   writeFileSync(resolve(root,'plan.json'),JSON.stringify(plan,null,2)+'\n',{mode:0o600});
   writeFileSync(resolve(root,'profile.sql'),plan.profile_sql,{mode:0o600});writeFileSync(resolve(root,'iap.sql'),plan.iap_sql,{mode:0o600});
   console.log(root);
  }else if(mode==='validate'){
   validatePlan(JSON.parse(readFileSync(process.argv[3],'utf8')));console.log('ERASURE_PLAN=VALID; NO_REMOTE_ACTION');
  }else throw Error('Use prepare with verified input on stdin, or validate PLAN_PATH. Default action performs no deletion.');
 }catch(error){const safe=/^[a-z0-9_]+$/.test(error.message)?error.message:'invalid_input_or_operation';console.error('ACCOUNT_ERASURE_STOP='+safe);process.exitCode=1;}
}
