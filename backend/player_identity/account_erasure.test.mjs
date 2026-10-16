import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import {makeErasurePlan,validatePlan} from './account_erasure.mjs';
import {createHash} from 'node:crypto';
const now=Date.parse('2026-10-16T16:00:00Z');
const input={firebase_uid:'verified-owner-A',ownership_verified:true,request_verified:true,firebase_deleted_at:'2026-10-16T14:50:00Z'};
const plan=makeErasurePlan(input,now),b='b'.repeat(64),a=plan.owner_binding,k=plan.owner_key;
function profile(){
 const db=new DatabaseSync(':memory:');db.exec('PRAGMA foreign_keys=ON');
 for(const name of ['schema.sql','mail_schema.sql','mail_studio_schema.sql','announcement_schema.sql','progress_backup_schema.sql'])db.exec(readFileSync(new URL(name,import.meta.url),'utf8'));
 for(const [owner,uid] of [[a,'JA0000000001'],[b,'JA0000000002']]){
  db.prepare('INSERT INTO player_identities VALUES(?,?,1)').run(owner,uid);
  db.prepare('INSERT INTO mail_player_activity VALUES(?,1,?)').run(owner,'version');
  db.prepare("INSERT INTO player_progress_backups_v1 VALUES(?,1,?,'{}',?,1,'{}')").run(owner,'r'.repeat(32),'h'.repeat(64));
 }
 for(const [id,audience,target] of [['shared','all',''],['private','uid','JA0000000001']]){
  db.prepare("INSERT INTO mail_campaigns VALUES(?,?,?,'title','body','sender','{}',?,?,1,999,1,0)").run(id,id,'fingerprint',audience,target);
  db.prepare('INSERT INTO mail_archives VALUES(?,1)').run(id);
 }
 for(const [id,owner] of [['shared',a],['shared',b],['private',a]]){
  db.prepare('INSERT INTO mail_recipients VALUES(?,?,1,1,0)').run(id,owner);
  db.prepare("INSERT INTO mail_claims VALUES(?,?,?,?,'{}',1,1)").run(id,owner,'device',id+owner);
  db.prepare("INSERT INTO mail_claim_resolution VALUES(?,?,'done',1)").run(id,owner);
 }
 db.exec("INSERT INTO player_announcements VALUES('notice','r','f','title','body','notice',1,99,1,0)");
 for(const owner of [a,b])db.prepare("INSERT INTO player_announcement_reads VALUES('notice',?,1)").run(owner);
 for(const t of ['mail_drafts','mail_jobs']){
  const json=JSON.stringify({audience:'uid',target_uid:'JA0000000001'});
  if(t==='mail_drafts')db.prepare('INSERT INTO mail_drafts VALUES(?,?,1)').run('draft',json);
  else db.prepare("INSERT INTO mail_jobs VALUES('job','req','fp',?,1,'scheduled',1,1,'','')").run(json);
 }
 db.prepare("INSERT INTO mail_admin_audit VALUES('audit','resolve',?,1)").run(JSON.stringify({owner_binding:a}));
 return db;
}
test('requires independently verified request/ownership and Firebase removal before token-expiry wait',()=>{
 validatePlan(plan);assert(!JSON.stringify(plan).includes(input.firebase_uid));
 for(const patch of [{ownership_verified:false},{request_verified:false},{firebase_uid:'JA0000000001'},{firebase_deleted_at:'2026-10-16T15:00:00Z'},{firebase_deleted_at:'2027-01-01'},{firebase_uid:"invalid\nuid"}])assert.throws(()=>makeErasurePlan({...input,...patch},now));
 assert.throws(()=>makeErasurePlan({...input,owner_binding:b},now));
});
test('plan cannot redirect DB, owner or remove WHERE even with a newly computed checksum',()=>{
 for(const changed of [{...plan,owner_binding:b},{...plan,targets:{...plan.targets,iap:{id:'staging'}}},{...plan,profile_check:'SELECT 0'},{...plan,iap_sql:'DELETE FROM iap_paid_runs_v2;',iap_sha256:createHash('sha256').update('DELETE FROM iap_paid_runs_v2;').digest('hex')}])assert.throws(()=>validatePlan(changed));
});
test('actual SQL erases both snapshots, target account/mail and scheduled targeted mail while keeping shared content and player B',()=>{
 const db=profile();db.exec('BEGIN');db.exec(plan.profile_sql);db.exec('COMMIT');
 assert.equal(db.prepare(plan.profile_check).get().remaining_account_rows,0);
 assert.equal(db.prepare('SELECT COUNT(*) AS n FROM player_identities WHERE owner_binding=?').get(b).n,1);
 assert.equal(db.prepare('SELECT COUNT(*) AS n FROM player_progress_backups_v1 WHERE owner_binding=?').get(b).n,1);
 assert.equal(db.prepare('SELECT COUNT(*) AS n FROM mail_recipients WHERE owner_binding=?').get(b).n,1);
 assert.equal(db.prepare("SELECT COUNT(*) AS n FROM mail_campaigns WHERE id='shared'").get().n,1);
 assert.equal(db.prepare('SELECT COUNT(*) AS n FROM mail_drafts').get().n,0);assert.equal(db.prepare('SELECT COUNT(*) AS n FROM mail_jobs').get().n,0);
 db.exec(plan.profile_sql);assert.equal(db.prepare(plan.profile_check).get().remaining_account_rows,0);db.close();
});
test('foreign-key inconsistency rolls back the entire profile transaction rather than erasing another recipient',()=>{
 const db=profile();db.prepare("INSERT INTO mail_recipients VALUES('private',?,1,0,0)").run(b);
 db.exec('BEGIN');assert.throws(()=>db.exec(plan.profile_sql));db.exec('ROLLBACK');
 assert.equal(db.prepare('SELECT COUNT(*) AS n FROM player_identities').get().n,2);assert.equal(db.prepare('SELECT COUNT(*) AS n FROM player_progress_backups_v1').get().n,2);db.close();
});
test('IAP SQL is idempotent and never writes financial/refund ledger rows',()=>{
 const db=new DatabaseSync(':memory:');db.exec('PRAGMA foreign_keys=ON');
 for(const name of readdirSync(new URL('../monetization/cloudflare/migrations/',import.meta.url)).filter(s=>s.endsWith('.sql')).sort())db.exec(readFileSync(new URL('../monetization/cloudflare/migrations/'+name,import.meta.url),'utf8'));
 for(const key of [k,'u1:'+b]){
  db.prepare('INSERT INTO iap_wallet_accounts_v1 VALUES(?,100,1)').run(key);
  db.prepare("INSERT INTO iap_summon_canonical_v1(owner_key,revision,status,state_json) VALUES(?,1,'verified',?)").run(key,JSON.stringify({inventory:{example:1}}));
  db.prepare('INSERT INTO iap_paid_gameplay_v2(owner_key,source_revision,state_json) VALUES(?,1,?)').run(key,JSON.stringify({inventory:{example:1}}));
  db.prepare('INSERT INTO iap_paid_runs_v2(owner_key,run_id,loadout_json) VALUES(?,?,?)').run(key,'a'.repeat(36),JSON.stringify({weapon:'example',version:1}));
 }
 const before=db.prepare('SELECT * FROM iap_wallet_accounts_v1 ORDER BY owner_key').all();
 db.exec('BEGIN');db.exec(plan.iap_sql);db.exec('COMMIT');db.exec(plan.iap_sql);
 assert.equal(db.prepare(plan.iap_check).get().remaining_gameplay_rows,0);assert.deepEqual(db.prepare('SELECT * FROM iap_wallet_accounts_v1 ORDER BY owner_key').all(),before);
 assert.equal(db.prepare('SELECT COUNT(*) AS n FROM iap_paid_gameplay_v2 WHERE owner_key=?').get('u1:'+b).n,1);db.close();
});
