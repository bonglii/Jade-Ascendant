import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {createHandler,registerIdentity,ownerBinding} from './worker.mjs';
import {MailError} from './mail.mjs';
import {normalizeDocument,activeBanner,publicSnapshot,FEATURED_CATALOG,BASE_RATES} from './pavilion.mjs';

const URL='https://mail.example',secret='a'.repeat(64),installation='1'.repeat(32),otherInstallation='2'.repeat(32);
function database(){
 const sql=new DatabaseSync(':memory:');sql.exec('PRAGMA foreign_keys=ON');
 for(const name of ['schema.sql','mail_schema.sql','mail_studio_schema.sql','pavilion_schema.sql'])sql.exec(readFileSync(new globalThis.URL(name,import.meta.url),'utf8'));
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

const now=()=>Math.floor(Date.now()/1000);
const banner=(extra={})=>({id:'9'.repeat(32),title:'Celestial Rebirth',subtitle:'Ancient relics return',artwork:'sanctum',featured:FEATURED_CATALOG.slice(0,5).map(x=>x.id),rates:{...BASE_RATES},starts_at:now()-10,ends_at:now()+86400,enabled:true,...extra});
const publication=(document,revision=0)=>({request_id:crypto.randomUUID().replaceAll('-',''),expected_revision:revision,document});
test('read-only public banner requires no identity and returns bounded server-time lease',async()=>{
 const f=await fixture();const publicOut=await f.api('/v1/pavilion/banner');assert.equal(publicOut.status,200);assert.equal(publicOut.data.banner,null);assert.equal(publicOut.data.valid_until-publicOut.data.server_time,300);assert.equal((await f.api('/v1/pavilion/banner',{})).status,405);assert.equal((await f.api('/admin/api/pavilion')).status,401);f.db.sql.close();
});
test('banner publish requires existing admin cookie, origin and CSRF',async()=>{
 const f=await fixture(),p=publication({banners:[banner()]});assert.equal((await f.api('/admin/api/pavilion/publish',p)).status,401);await f.login();assert.equal((await f.api('/admin/api/pavilion/publish',p,{headers:{'x-jade-csrf':''}})).status,403);assert.equal((await f.api('/admin/api/pavilion/publish',p,{headers:{origin:'https://evil.example'}})).status,403);assert.equal(f.db.sql.prepare('SELECT count(*) n FROM pavilion_revisions').get().n,0);f.db.sql.close();
});
test('publish is atomic, append-only, stale-safe and retry-idempotent',async()=>{
 const f=await fixture();await f.login();const p=publication({banners:[banner()]});const one=await f.api('/admin/api/pavilion/publish',p);assert.equal(one.status,200);assert.equal(one.data.revision,1);assert.equal((await f.api('/admin/api/pavilion/publish',p)).data.revision,1);const stale=await f.api('/admin/api/pavilion/publish',publication({banners:[]}));assert.equal(stale.status,409);assert.equal(stale.data.error,'banner_stale');assert.equal((await f.api('/admin/api/pavilion/publish',{...p,document:{banners:[]}})).status,409);assert.equal(f.db.sql.prepare('SELECT count(*) n FROM pavilion_revisions').get().n,1);assert.equal(f.db.sql.prepare("SELECT count(*) n FROM mail_admin_audit WHERE action='banner_publish'").get().n,1);const publicOut=await f.api('/v1/pavilion/banner');assert.equal(publicOut.data.banner.title,'Celestial Rebirth');f.db.sql.close();
});
test('invalid rate totals, fractions, IDs, unknown gear, schedules and extra fields are rejected',()=>{
 const invalid=[{rates:{common:5999,rare:2900,epic:900,legendary:200}},{rates:{common:6000,rare:2899.5,epic:900,legendary:200.5}},{rates:{...BASE_RATES,legendary:0}},{featured:['bamboo_weave_robe']},{featured:['new_not_shipped']},{featured:[FEATURED_CATALOG[0].id,FEATURED_CATALOG[0].id]},{featured:[]},{featured:FEATURED_CATALOG.slice(0,6).map(x=>x.id)},{ends_at:now()-60},{ends_at:now()+91*86400},{artwork:'https://evil.example'},{title:'<script>'},{title:''},{id:'invalid'},{enabled:1},{currency_grant:999}];for(const change of invalid)assert.throws(()=>normalizeDocument({banners:[banner(change)]}),MailError);assert.throws(()=>normalizeDocument({banners:Array.from({length:13},(_,n)=>banner({id:String(n).padStart(32,'0')}))}),MailError);assert.throws(()=>normalizeDocument({banners:[banner(),banner()]}),MailError);
});
test('scheduled priority, disable, exact boundary expiry and server lease transitions',()=>{
 const a=banner({starts_at:100,ends_at:400}),b=banner({id:'8'.repeat(32),starts_at:200,ends_at:300});const doc=normalizeDocument({banners:[a,b]});assert.equal(activeBanner(doc,99),null);assert.equal(activeBanner(doc,100).id,a.id);assert.equal(activeBanner(doc,200).id,b.id);assert.equal(activeBanner(doc,300).id,a.id);assert.equal(activeBanner(doc,400),null);assert.equal(publicSnapshot({revision:1,document:doc},190).valid_until,200);assert.equal(publicSnapshot({revision:1,document:doc},200).valid_until,300);assert.equal(activeBanner({banners:[a,{...b,enabled:false}]},220).id,a.id);
});
test('disable and rollback create new revisions without altering player tables',async()=>{
 const f=await fixture();await f.login();const players=JSON.stringify(f.db.sql.prepare('SELECT * FROM player_identities').all()),first={banners:[banner()]};await f.api('/admin/api/pavilion/publish',publication(first));assert.equal((await f.api('/admin/api/pavilion/publish',publication({banners:[banner({enabled:false})]},1))).status,200);assert.equal((await f.api('/v1/pavilion/banner')).data.banner,null);assert.equal((await f.api('/admin/api/pavilion/publish',publication(first,2))).status,200);assert.equal((await f.api('/v1/pavilion/banner')).data.banner.id,first.banners[0].id);const history=await f.api('/admin/api/pavilion/revisions');assert.deepEqual(history.data.entries.map(x=>x.revision),[3,2,1]);assert.equal(JSON.stringify(f.db.sql.prepare('SELECT * FROM player_identities').all()),players);for(const table of ['mail_campaigns','mail_claims'])assert.equal(f.db.sql.prepare('SELECT count(*) n FROM '+table).get().n,0);f.db.sql.close();
});
test('schema deployment is repeatable and preserves immutable revisions',async()=>{
 const f=await fixture();await f.login();await f.api('/admin/api/pavilion/publish',publication({banners:[banner()]}));f.db.sql.exec(readFileSync(new globalThis.URL('pavilion_schema.sql',import.meta.url),'utf8'));assert.equal((await f.api('/v1/pavilion/banner')).data.revision,1);f.db.sql.close();
});
test('server handles missing new schema as unavailable, never fabricated active configuration',async()=>{
 const f=await fixture();f.db.sql.exec('DROP TABLE pavilion_revisions;DROP TABLE pavilion_control;');const out=await f.api('/v1/pavilion/banner');assert.equal(out.status,503);assert.equal(out.data.error,'banner_unavailable');f.db.sql.close();
});
