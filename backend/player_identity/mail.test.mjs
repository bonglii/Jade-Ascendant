import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {createHandler,registerIdentity,ownerBinding} from './worker.mjs';
import {MailError} from './mail.mjs';
import dashboard from './dashboard.mjs';

const URL='https://mail.example',secret='a'.repeat(64),installation='1'.repeat(32),otherInstallation='2'.repeat(32);
function database(){
 const sql=new DatabaseSync(':memory:');sql.exec('PRAGMA foreign_keys=ON');
 for(const name of ['schema.sql','mail_schema.sql','mail_studio_schema.sql'])sql.exec(readFileSync(new globalThis.URL(name,import.meta.url),'utf8'));
 const db={sql,withSession(mode){assert.equal(mode,'first-primary');return db;},prepare(query){
  const statement={query,args:[],bind(...args){return {...statement,args};},async first(){return sql.prepare(this.query).get(...this.args)||null;},async all(){return {results:sql.prepare(this.query).all(...this.args)};},async run(){const out=sql.prepare(this.query).run(...this.args);return {meta:{changes:Number(out.changes)}};}};return statement;
 },async batch(statements){sql.exec('BEGIN');try{const out=statements.map(s=>{const stmt=sql.prepare(s.query);return stmt.columns().length?{results:stmt.all(...s.args)}:{meta:{changes:Number(stmt.run(...s.args).changes)}};});sql.exec('COMMIT');return out;}catch(error){sql.exec('ROLLBACK');throw error;}}};return db;
}
async function fixture(){
 const db=database(),alice=await ownerBinding('alice'),bob=await ownerBinding('bob');
 const a=await registerIdentity(db,alice),b=await registerIdentity(db,bob);
 const env={PROFILE_DB:db,FIREBASE_PROJECT_ID:'jade-ascendant',MAIL_ADMIN_SECRET:secret};
 const handler=createHandler({verify:async request=>request.headers.get('x-test-user')||'alice'});
 let cookie='',csrf='';
 async function api(path,body,options={}){
  const headers={cookie,origin:URL,'x-jade-csrf':csrf,'x-test-user':options.user||'alice','x-jade-owner-binding':await ownerBinding(options.user||'alice'),...options.headers};
  if(body!==undefined)headers['content-type']='application/json';
  const req=new Request(URL+path,{method:body===undefined?'GET':'POST',headers,body:body===undefined?undefined:JSON.stringify(body)});
  const response=await handler(req,env);const data=await response.json();return {response,data,status:response.status};
 }
 async function login(){const out=await api('/admin/api/login',{password:secret});assert.equal(out.status,200);cookie=out.response.headers.get('set-cookie').split(';')[0];csrf=out.data.csrf;return out;}
 const draft=(extra={})=>({title:'A Jade gift',body:'Good luck, cultivator.',sender:'JADE SANCTUARY',audience:'uid',target_uid:a.public_uid,expires_at:Math.floor(Date.now()/1000)+86400,reward:{spirit_stone:200,items:{refinement_shard:2}},...extra});
 async function publish(extra={}){const preview=await api('/admin/api/preview',draft(extra));assert.equal(preview.status,200);const input={...preview.data,request_id:crypto.randomUUID().replaceAll('-','')};delete input.recipient_count_unused;const out=await api('/admin/api/send',input);assert.equal(out.status,200);return {mail:out.data,input};}
 return {db,env,api,login,publish,draft,alice,bob,a,b};
}

test('dashboard CSP, session cookies, logout and CSRF protect administrator actions',async()=>{
 const f=await fixture();const handler=createHandler({verify:async()=>assert.fail('admin route used player identity')});
 const html=await handler(new Request(URL+'/admin'),f.env);assert.equal(html.status,200);assert.match(html.headers.get('content-security-policy'),/frame-ancestors 'none'/);assert.equal((await html.text()).includes('__NONCE__'),false);
 assert.equal((await f.api('/admin/api/history')).status,401);
 const logged=await f.login();for(const flag of ['HttpOnly','Secure','SameSite=Strict'])assert.match(logged.response.headers.get('set-cookie'),new RegExp(flag));
 assert.equal((await f.api('/admin/api/preview',f.draft(),{headers:{'x-jade-csrf':''}})).status,403);
 assert.equal((await f.api('/admin/api/preview',f.draft(),{headers:{origin:'https://evil.example'}})).status,403);
 assert.equal((await f.api('/admin/api/history',undefined,{headers:{cookie:'jade_admin=9999999999.'+'1'.repeat(32)+'.'+'0'.repeat(64)}})).status,401);
 assert.equal((await f.api('/admin/api/logout',{})).status,200);f.db.sql.close();
});
test('invalid admin credentials are rate limited and the database stores no password or raw IP',async()=>{
 const f=await fixture();for(let i=0;i<12;i++)assert.equal((await f.api('/admin/api/login',{password:'wrong'})).status,401);
 assert.equal((await f.api('/admin/api/login',{password:secret})).status,429);
 const row=f.db.sql.prepare('SELECT * FROM mail_admin_attempts').get();assert.match(row.bucket,/^[a-f0-9]{64}$/);assert.equal(JSON.stringify(row).includes(secret),false);f.db.sql.close();
});
test('preview validates recipients, reward allowlist and mandatory text without writing campaigns',async()=>{
 const f=await fixture();await f.login();
 for(const draft of [f.draft({title:''}),f.draft({target_uid:'JA0000000000'}),f.draft({reward:{spirit_stone:-1,items:{}}}),f.draft({reward:{spirit_stone:0,items:{premium_jade:1}}}),f.draft({reward:{spirit_stone:0.5,items:{}}})])assert.ok((await f.api('/admin/api/preview',draft)).status>=400);
 assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_campaigns').get().n,0);f.db.sql.close();
});
test('send snapshots recipients, is idempotent after lost responses, and prevents changed payload reuse',async()=>{
 const f=await fixture();await f.login();const {mail,input}=await f.publish({audience:'all',target_uid:''});assert.equal(mail.recipients,2);
 await registerIdentity(f.db,await ownerBinding('new-user'));
 const retry=await f.api('/admin/api/send',input);assert.equal(retry.status,200);assert.equal(retry.data.id,mail.id);assert.equal(retry.data.recipients,2);
 const changed=await f.api('/admin/api/send',{...input,draft:{...input.draft,title:'Different'}});assert.equal(changed.status,409);
 const fresh=await f.api('/v1/mail/list?installation_id='+installation,undefined,{user:'new-user'});assert.equal(fresh.data.entries.length,0);f.db.sql.close();
});
test('stale preview count and failed transaction never publish partial mail',async()=>{
 const f=await fixture();await f.login();const p=await f.api('/admin/api/preview',f.draft({audience:'all',target_uid:''}));
 await registerIdentity(f.db,await ownerBinding('later'));
 assert.equal((await f.api('/admin/api/send',{...p.data,request_id:'3'.repeat(32)})).status,409);
 f.db.sql.exec("CREATE TRIGGER reject_mail BEFORE INSERT ON mail_recipients BEGIN SELECT RAISE(ABORT,'fixture failure'); END");
 const p2=await f.api('/admin/api/preview',f.draft());
 assert.equal((await f.api('/admin/api/send',{...p2.data,request_id:'4'.repeat(32)})).status,503);
 assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_campaigns').get().n,0);assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_recipients').get().n,0);f.db.sql.close();
});
test('recipient isolation and retryable claims survive response loss, cancellation and expiry',async()=>{
 const f=await fixture();await f.login();const {mail}=await f.publish();const claim={mail_id:mail.id,installation_id:installation};
 assert.equal((await f.api('/v1/mail/claim',claim,{user:'bob'})).status,404);
 const first=await f.api('/v1/mail/claim',claim);assert.equal(first.status,200);assert.equal(first.data.delivery_state,'pending');
 const again=await f.api('/v1/mail/claim',claim);assert.equal(again.data.receipt_id,first.data.receipt_id);
 assert.equal((await f.api('/v1/mail/claim',{...claim,installation_id:otherInstallation})).status,409);
 await f.api('/admin/api/cancel',{mail_id:mail.id});f.db.sql.prepare('UPDATE mail_campaigns SET expires_at=1 WHERE id=?').run(mail.id);
 assert.equal((await f.api('/v1/mail/claim',claim)).data.receipt_id,first.data.receipt_id);
 assert.equal((await f.api('/v1/mail/delete',{mail_id:mail.id})).status,409);
 const ack={...claim,receipt_id:first.data.receipt_id};assert.equal((await f.api('/v1/mail/ack',{...ack,receipt_id:'f'.repeat(32)})).status,409);
 assert.equal((await f.api('/v1/mail/ack',ack)).status,200);assert.equal((await f.api('/v1/mail/ack',ack)).status,200);
 const done=await f.api('/v1/mail/claim',claim);assert.equal(done.data.delivery_state,'claimed');assert.equal(done.data.reward,undefined);
 assert.equal((await f.api('/v1/mail/delete',{mail_id:mail.id})).status,200);f.db.sql.close();
});
test('concurrent devices converge on one reservation; unacknowledged receipts stay recoverable',async()=>{
 const f=await fixture();await f.login();const {mail}=await f.publish();
 const out=await Promise.all(Array.from({length:12},(_,i)=>f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:(i%2?'1':'2').repeat(32)})));
 const accepted=out.filter(x=>x.status===200);assert.ok(accepted.length>0);assert.equal(new Set(accepted.map(x=>x.data.receipt_id)).size,1);
 assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_claims').get().n,1);f.db.sql.close();
});
test('server read/delivery/claim history and pagination report actual recipient state',async()=>{
 const f=await fixture();await f.login();const {mail}=await f.publish({audience:'all',target_uid:''});
 const inbox=await f.api('/v1/mail/list?installation_id='+installation);assert.equal(inbox.data.entries.length,1);assert.equal(inbox.data.owner_binding,f.alice);
 await f.api('/v1/mail/read',{mail_id:mail.id});const claimed=await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation});
 await f.api('/v1/mail/ack',{mail_id:mail.id,installation_id:installation,receipt_id:claimed.data.receipt_id});
 const h=(await f.api('/admin/api/history')).data.entries[0];assert.equal(h.recipients,2);assert.equal(h.delivered,1);assert.equal(h.read_count,1);assert.equal(h.claimed,1);
 const recipients=(await f.api('/admin/api/recipients?mail_id='+mail.id)).data.entries;assert.equal(recipients.length,2);assert.ok(recipients.some(r=>r.public_uid===f.a.public_uid&&r.acknowledged_at>0));f.db.sql.close();
});
test('cancelled or expired mail cannot create a new grant; notices can be deleted',async()=>{
 const f=await fixture();await f.login();const {mail}=await f.publish();await f.api('/admin/api/cancel',{mail_id:mail.id});
 assert.equal((await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation})).status,409);
 assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_claims').get().n,0);
 const notice=await f.publish({reward:{spirit_stone:0,items:{}}});assert.equal((await f.api('/v1/mail/delete',{mail_id:notice.mail.id})).status,200);f.db.sql.close();
});

test('stale token account context cannot reserve a broadcast gift for the previous account',async()=>{
 const f=await fixture();await f.login();const {mail}=await f.publish({audience:'all',target_uid:''});
 const out=await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation},{user:'bob',headers:{'x-jade-owner-binding':f.alice}});
 assert.equal(out.status,409);assert.equal(out.data.error,'account_changed');
 assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_claims').get().n,0);f.db.sql.close();
});
test('multibyte mail body at the documented character limit passes bounded JSON parsing',async()=>{
 const f=await fixture();await f.login();const draft=f.draft({body:'道'.repeat(4000)});
 assert.equal((await f.api('/admin/api/preview',draft)).status,200);f.db.sql.close();
});

test('username/password setup invalidates bootstrap sessions and requires no second factor',async()=>{
 const f=await fixture();await f.login();const setup=await f.api('/admin/api/account/setup',{username:'jade_admin',password:'a secure password 123!'});assert.equal(setup.status,200);assert.equal(setup.data.secret,undefined);assert.equal(setup.data.recovery_codes,undefined);
 assert.equal((await f.api('/admin/api/session')).status,401);assert.equal((await f.api('/admin/api/login',{password:secret})).status,401);
 assert.equal((await f.api('/admin/api/login',{username:'jade_admin',password:'a secure password 123!'})).status,200);assert.equal((await f.api('/admin/api/login',{username:'jade_admin',password:'wrong password'})).status,401);
 const row=f.db.sql.prepare('SELECT * FROM mail_admin_account').get();assert.equal(row.totp_sealed,'');assert.ok(!JSON.stringify(row).includes('a secure password'));f.db.sql.close();
});

test('archive cleanup hides history, preserves claim uniqueness and inbox, and restores individually',async()=>{
 const f=await fixture();await f.login();const {mail}=await f.publish();const h=await f.api('/admin/api/history');
 assert.equal((await f.api('/admin/api/archive',{cutoff:h.data.cutoff,q:'',status:'all'})).status,200);
 assert.equal((await f.api('/admin/api/history')).data.entries.length,0);assert.equal((await f.api('/admin/api/history?archive=1')).data.entries.length,1);
 assert.equal((await f.api('/v1/mail/list?installation_id='+installation)).data.entries.length,1);
 const first=await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation});assert.equal(first.status,200);
 await f.api('/v1/mail/ack',{mail_id:mail.id,installation_id:installation,receipt_id:first.data.receipt_id});
 const retry=await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:otherInstallation});assert.equal(retry.data.delivery_state,'claimed');assert.equal(retry.data.reward,undefined);
 assert.equal((await f.api('/admin/api/archive/restore',{mail_id:mail.id})).status,200);assert.equal((await f.api('/admin/api/history')).data.entries[0].claimed,1);f.db.sql.close();
});

test('player search, title/UID history filters and formula-safe CSV export match actual recipients',async()=>{
 const f=await fixture();await f.login();const {mail}=await f.publish({title:'=IMPORTXML("bad")'});await f.publish({target_uid:f.b.public_uid,title:'Different'});
 const query=await f.api('/admin/api/players?q='+f.a.public_uid);assert.equal(query.data.entries[0].mails,1);assert.equal(query.data.entries[0].last_seen,null);
 assert.equal((await f.api('/admin/api/history?q='+f.a.public_uid)).data.entries[0].id,mail.id);
 assert.equal((await f.api('/admin/api/history?q=Different')).data.entries.length,1);
 const handler=createHandler({verify:async()=> 'alice'});const login=await f.login();const csv=await handler(new Request(URL+'/admin/api/export?q='+f.a.public_uid,{headers:{cookie:login.response.headers.get('set-cookie').split(';')[0]}}),f.env);
 assert.equal(csv.status,200);const text=await csv.text();assert.match(text,/"'=IMPORTXML/);assert.ok(!text.includes('Different'));f.db.sql.close();
});

test('drafts survive editing and scheduling captures recipients at execution exactly once',async()=>{
 const {processScheduled}=await import('./mail.mjs');const f=await fixture();await f.login();const draft=f.draft({audience:'all',target_uid:''});
 const saved=await f.api('/admin/api/drafts/save',{id:'',draft});assert.equal(saved.status,200);draft.title='Revised';await f.api('/admin/api/drafts/save',{id:saved.data.id,draft});assert.equal((await f.api('/admin/api/drafts')).data.entries[0].draft.title,'Revised');assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_campaigns').get().n,0);
 const p=await f.api('/admin/api/preview',draft);const id='7'.repeat(32),run_at=Math.floor(Date.now()/1000)+120;const input={preview:p.data,run_at,request_id:id};
 assert.equal((await f.api('/admin/api/jobs/schedule',input)).status,200);assert.equal((await f.api('/admin/api/jobs/schedule',input)).status,200);
 await processScheduled(f.env);assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_campaigns').get().n,0);
 await registerIdentity(f.db,await ownerBinding('later-player'));f.db.sql.prepare('UPDATE mail_jobs SET run_at=?,updated_at=0').run(Math.floor(Date.now()/1000)-1);
 await Promise.all([processScheduled(f.env),processScheduled(f.env)]);assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_campaigns').get().n,1);assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_recipients').get().n,3);assert.equal(f.db.sql.prepare('SELECT state FROM mail_jobs').get().state,'sent');
 const c=f.db.sql.prepare('SELECT id FROM mail_campaigns').get().id;assert.equal((await f.api('/admin/api/jobs/cancel',{id})).status,409);await processScheduled(f.env);assert.equal(f.db.sql.prepare('SELECT id FROM mail_campaigns').get().id,c);f.db.sql.close();
});

test('cancelled schedules never send and expired scheduled gifts fail without partial recipients',async()=>{
 const {processScheduled}=await import('./mail.mjs');const f=await fixture();await f.login();const p=await f.api('/admin/api/preview',f.draft());const id='8'.repeat(32);
 await f.api('/admin/api/jobs/schedule',{preview:p.data,run_at:Math.floor(Date.now()/1000)+120,request_id:id});assert.equal((await f.api('/admin/api/jobs/cancel',{id})).status,200);
 f.db.sql.prepare('UPDATE mail_jobs SET run_at=0,updated_at=0').run();await processScheduled(f.env);assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_campaigns').get().n,0);
 const second='9'.repeat(32);await f.api('/admin/api/jobs/schedule',{preview:p.data,run_at:Math.floor(Date.now()/1000)+120,request_id:second});const d=f.draft({expires_at:1});f.db.sql.prepare('UPDATE mail_jobs SET run_at=0,updated_at=0,draft_json=? WHERE id=?').run(JSON.stringify(d),second);
 await processScheduled(f.env);assert.equal(f.db.sql.prepare('SELECT state FROM mail_jobs WHERE id=?').get(second).state,'failed');assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_recipients').get().n,0);f.db.sql.close();
});

test('activity and version segments select only server-observed signed players',async()=>{
 const f=await fixture();await f.login();await f.api('/v1/mail/list?installation_id='+installation,undefined,{headers:{'x-jade-client-version':'1.0.6'}});
 const segment={audience:'segment',target_uid:'',segment:{kind:'version',value:'1.0.6'}};const {mail}=await f.publish(segment);assert.equal(mail.recipients,1);assert.equal(mail.audience,'segment');assert.equal((await f.api('/v1/mail/list?installation_id='+installation,undefined,{user:'bob'})).data.entries.length,0);
 assert.equal((await f.api('/admin/api/preview',f.draft({...segment,segment:{kind:'active7',value:''}}))).data.recipient_count,2);
 assert.equal((await f.api('/admin/api/preview',f.draft({...segment,segment:{kind:'inactive30',value:''}}))).status,404);f.db.sql.close();
});

test('admin closes pending cases without regrant and reports resolution separately from client acknowledgement',async()=>{
 const f=await fixture();await f.login();const {mail}=await f.publish();await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation});
 assert.equal((await f.api('/admin/api/resolve',{mail_id:mail.id,uid:f.a.public_uid,reason:'Reinstall reported and reviewed',confirmation:'RESET'})).status,400);
 assert.equal((await f.api('/admin/api/resolve',{mail_id:mail.id,uid:f.a.public_uid,reason:'Reinstall reported and reviewed',confirmation:'CLOSE WITHOUT REWARD'})).status,200);
 const retry=await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:otherInstallation});assert.equal(retry.data.delivery_state,'claimed');assert.equal(retry.data.reward,undefined);
 const c=(await f.api('/admin/api/history')).data.entries[0];assert.equal(c.claimed,0);assert.equal(c.resolved,1);assert.equal((await f.api('/admin/api/recipients?mail_id='+mail.id)).data.entries[0].resolved_at>0,true);
 assert.equal((await f.api('/admin/api/audit')).data.entries.some(x=>x.action==='resolve_without_reward'),true);f.db.sql.close();
});

test('existing 2FA accounts accept their valid password and password change revokes prior sessions',async()=>{
 const f=await fixture();await f.login();await f.api('/admin/api/account/setup',{username:'studio_owner',password:'initial long password!'});
 f.db.sql.prepare("UPDATE mail_admin_account SET totp_sealed='legacy-encrypted-secret',last_step=999999999").run();
 const login=await f.api('/admin/api/login',{username:'studio_owner',password:'initial long password!'});assert.equal(login.status,200);
 const oldCookie=login.response.headers.get('set-cookie').split(';')[0],headers={cookie:oldCookie,'x-jade-csrf':login.data.csrf};
 const changed=await f.api('/admin/api/account/password',{password:'initial long password!',new_password:'replacement password 123!'},{headers});assert.equal(changed.status,200);
 assert.equal((await f.api('/admin/api/session',undefined,{headers})).status,401);assert.equal((await f.api('/admin/api/login',{username:'studio_owner',password:'initial long password!'})).status,401);
 assert.equal((await f.api('/admin/api/login',{username:'studio_owner',password:'replacement password 123!'})).status,200);f.db.sql.close();
});

test('archive cutoff leaves newer sends visible and resolution races cannot relabel a completed client claim',async()=>{
 const f=await fixture();await f.login();const first=await f.publish();const cutoff=(await f.api('/admin/api/history')).data.cutoff;const second=await f.publish();await f.api('/admin/api/archive',{cutoff,q:'',status:'all'});
 assert.equal((await f.api('/admin/api/history')).data.entries[0].id,second.mail.id);const claim=await f.api('/v1/mail/claim',{mail_id:first.mail.id,installation_id:installation});
 const batch=f.db.batch;f.db.batch=async statements=>{f.db.sql.prepare('UPDATE mail_claims SET acknowledged_at=? WHERE mail_id=?').run(Math.floor(Date.now()/1000),first.mail.id);return batch(statements);};
 const resolved=await f.api('/admin/api/resolve',{mail_id:first.mail.id,uid:f.a.public_uid,reason:'Case checked by administrator',confirmation:'CLOSE WITHOUT REWARD'});assert.equal(resolved.status,409);assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_claim_resolution').get().n,0);assert.ok(claim.data.receipt_id);f.db.sql.close();
});

test('owner reset changes only admin credentials, hides plaintext and revokes sessions without deleting mail',async()=>{
 const {resetSQL}=await import('./reset_mail_admin.mjs');const f=await fixture();await f.login();const {mail}=await f.publish();
 await f.api('/admin/api/account/setup',{username:'old_admin',password:'old password 123!'});
 const login=await f.api('/admin/api/login',{username:'old_admin',password:'old password 123!'});const headers={cookie:login.response.headers.get('set-cookie').split(';')[0]};
 const password='新しい password 123!';const sql=await resetSQL({key:secret,username:'new_admin',password});assert.ok(!sql.includes(password));assert.ok(!sql.includes(secret));assert.ok(!/DELETE FROM mail_(campaigns|claims|recipients)/.test(sql));
 f.db.sql.exec(sql);assert.equal((await f.api('/admin/api/session',undefined,{headers})).status,401);
 assert.equal((await f.api('/admin/api/login',{username:'new_admin',password})).status,200);assert.equal((await f.api('/admin/api/login',{username:'old_admin',password:'old password 123!'})).status,401);
 assert.equal(f.db.sql.prepare('SELECT id FROM mail_campaigns').get().id,mail.id);assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM player_identities').get().n,2);
 await assert.rejects(resetSQL({key:secret,username:"admin'; DROP TABLE mail_claims; --",password}),/invalid_username/);f.db.sql.close();
});

test('gift catalog matches authored equipment and extended rewards freeze exact receipts',async()=>{
 const {CATALOG}=await import('./mail_rewards.mjs');assert.equal(CATALOG.equipment.length,42);const f=await fixture();await f.login();
 const reward={spirit_stone:20,celestial_jade:500,pavilion_seal:3,items:{refinement_shard:2,nine_heavens_star_sword:1}};const {mail}=await f.publish({reward});assert.deepEqual(mail.reward,reward);
 assert.equal((await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation})).data.error,'client_upgrade_required');
 assert.equal((await f.api('/v1/mail/list?installation_id='+installation)).data.entries.length,0);
 const features={headers:{'x-jade-mail-features':'gifts-v2'}};assert.equal((await f.api('/v1/mail/list?installation_id='+installation,undefined,features)).data.entries.length,1);
 const held=await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation},features);assert.equal(held.status,200);assert.deepEqual(held.data.reward,reward);
 const again=await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation},features);assert.equal(again.data.receipt_id,held.data.receipt_id);
 await f.api('/v1/mail/ack',{mail_id:mail.id,installation_id:installation,receipt_id:held.data.receipt_id});assert.equal((await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation},features)).data.reward,undefined);f.db.sql.close();
});

test('Jade/seal-only gifts are claims, unsupported paid fields and forged equipment are rejected',async()=>{
 const f=await fixture();await f.login();for(const reward of [{spirit_stone:0,items:{},celestial_jade:1},{spirit_stone:0,items:{},pavilion_seal:1}]){
  const {mail}=await f.publish({reward});assert.equal((await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation},{headers:{'x-jade-mail-features':'gifts-v2'}})).status,200);
 }
 for(const reward of [{spirit_stone:0,items:{},celestial_jade:true},{spirit_stone:0,items:{},celestial_jade:10001},{spirit_stone:0,items:{},pavilion_seal:101},{spirit_stone:0,items:{},paid_jade:1},{spirit_stone:0,items:{unknown_weapon:1}},{spirit_stone:0,items:{nine_heavens_star_sword:2}}])assert.equal((await f.api('/admin/api/preview',f.draft({reward}))).status,400);
 const {CATALOG}=await import('./mail_rewards.mjs');assert.equal((await f.api('/admin/api/preview',f.draft({reward:{spirit_stone:0,items:Object.fromEntries(CATALOG.equipment.slice(0,6).map(item=>[item.id,1]))}}))).status,400);f.db.sql.close();
});

test('new chain gifts remain unreserved for old APKs and freeze one receipt for the new catalog',async()=>{
 const f=await fixture();await f.login();const reward={spirit_stone:0,items:{jade_binding_chain:1}};
 const {mail}=await f.publish({reward});const old={headers:{'x-jade-mail-features':'gifts-v2'}},current={headers:{...old.headers,'x-jade-equipment-catalog':'jade-chain-v1'}};
 assert.equal((await f.api('/v1/mail/list?installation_id='+installation,undefined,old)).data.entries.length,0);
 assert.equal((await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation},old)).data.error,'client_upgrade_required');
 assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_claims WHERE mail_id=?').get(mail.id).n,0);
 assert.equal((await f.api('/v1/mail/list?installation_id='+installation,undefined,current)).data.entries[0].reward.items.jade_binding_chain,1);
 const claim={mail_id:mail.id,installation_id:installation};const first=await f.api('/v1/mail/claim',claim,current),again=await f.api('/v1/mail/claim',claim,current);
 assert.equal(first.status,200);assert.deepEqual(first.data.reward,reward);assert.equal(first.data.receipt_id,again.data.receipt_id);
 assert.equal((await f.api('/admin/api/preview',f.draft({reward:{spirit_stone:0,items:{jade_binding_chain:2}}}))).status,400);f.db.sql.close();
});

test('returning glaive gifts require their own catalog capability while existing chain builds remain compatible',async()=>{
 const f=await fixture();await f.login();const reward={spirit_stone:0,items:{celestial_returning_glaive:1}};const {mail}=await f.publish({reward});
 const chain={headers:{'x-jade-mail-features':'gifts-v2','x-jade-equipment-catalog':'jade-chain-v1'}},current={headers:{...chain.headers,'x-jade-returning-glaive':'v1'}};
 assert.equal((await f.api('/v1/mail/list?installation_id='+installation,undefined,chain)).data.entries.length,0);
 assert.equal((await f.api('/v1/mail/claim',{mail_id:mail.id,installation_id:installation},chain)).data.error,'client_upgrade_required');
 assert.equal(f.db.sql.prepare('SELECT count(*) AS n FROM mail_claims WHERE mail_id=?').get(mail.id).n,0);
 assert.equal((await f.api('/v1/mail/list?installation_id='+installation,undefined,current)).data.entries[0].reward.items.celestial_returning_glaive,1);
 const claim={mail_id:mail.id,installation_id:installation};const first=await f.api('/v1/mail/claim',claim,current),again=await f.api('/v1/mail/claim',claim,current);
 assert.equal(first.status,200);assert.deepEqual(first.data.reward,reward);assert.equal(first.data.receipt_id,again.data.receipt_id);
 assert.equal((await f.api('/admin/api/preview',f.draft({reward:{spirit_stone:0,items:{celestial_returning_glaive:2}}}))).status,400);f.db.sql.close();
});
