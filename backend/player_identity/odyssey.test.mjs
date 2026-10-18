import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {createHandler,registerIdentity,ownerBinding} from './worker.mjs';
import {receiveOdysseyMail} from './odyssey.mjs';
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
 const draft=(extra={})=>({title:'A Jade gift',body:'Good luck, cultivator.',sender:'JADE SANCTUARY',audience:'uid',target_uid:a.public_uid,expires_at:Math.floor(Date.now()/1000)+86400,reward:{spirit_stone:240,items:{}},...extra});
 async function publish(extra={}){const preview=await api('/admin/api/preview',draft(extra));assert.equal(preview.status,200);const input={...preview.data,request_id:crypto.randomUUID().replaceAll('-','')};delete input.recipient_count_unused;const out=await api('/admin/api/send',input);assert.equal(out.status,200);return {mail:out.data,input};}
 async function page(){return handler(new Request(URL+'/admin/odyssey',{headers:{cookie}}),env);}
 return {db,env,api,login,publish,draft,alice,bob,a,b,page};
}


test('internal event delivery requires shared service credential and is retry-idempotent',async()=>{const f=await fixture();try{f.env.ODYSSEY_ADMIN_KEY='f'.repeat(64);const delivery={id:'c'.repeat(32),owner:f.alice,event_id:'dragon-1',reward:JSON.stringify({spirit_stone:0,items:{heavenweaver_compass:1}}),expires_at:Math.floor(Date.now()/1000)+86400};const send=(key=f.env.ODYSSEY_ADMIN_KEY,body=delivery)=>receiveOdysseyMail(new Request(URL+'/internal/odyssey/mail',{method:'POST',headers:{'x-odyssey-key':key},body:JSON.stringify(body)}),f.env);assert.equal((await send('wrong')).status,403);assert.equal((await send()).status,200);assert.equal((await send()).status,200);assert.equal(f.db.sql.prepare('SELECT count(*) n FROM mail_campaigns').get().n,1);assert.equal(f.db.sql.prepare('SELECT count(*) n FROM mail_recipients').get().n,1);assert.equal((await send(undefined,{...delivery,owner:f.bob})).status,409);const headers={'x-jade-mail-features':'gifts-v2','x-jade-equipment-catalog':'jade-chain-v1','x-jade-returning-glaive':'v1','x-jade-ascendant-arsenal':'v1'};const old=await f.api('/v1/mail/list?installation_id='+installation,undefined,{headers});assert.equal(old.status,200);assert.equal(old.data.entries.length,0);const upgraded=await f.api('/v1/mail/list?installation_id='+installation,undefined,{headers:{...headers,'x-jade-odyssey':'v1'}});assert.equal(upgraded.status,200);assert.equal(upgraded.data.entries.length,1);const claim={mail_id:delivery.id,installation_id:installation};assert.equal((await f.api('/v1/mail/claim',claim,{headers})).status,409);assert.equal((await f.api('/v1/mail/claim',claim,{headers:{...headers,'x-jade-odyssey':'v1'}})).status,200);}finally{f.db.sql.close();}});
test('dashboard proxy preserves session and CSRF before accessing ledger service',async()=>{const f=await fixture();try{let calls=0;f.env.ODYSSEY_ADMIN_KEY='f'.repeat(64);f.env.ODYSSEY_IAP={async fetch(url,init){calls++;assert.equal(init.headers['x-odyssey-key'],f.env.ODYSSEY_ADMIN_KEY);return new Response(JSON.stringify({event:null}));}};assert.equal((await f.api('/admin/api/odyssey')).status,401);await f.login();assert.equal((await f.api('/admin/api/odyssey')).status,200);assert.equal((await f.api('/admin/api/odyssey',{}, {headers:{'x-jade-csrf':''}})).status,403);assert.equal(calls,1);}finally{f.db.sql.close();}});

test('Odyssey dashboard keeps authentication and nonce CSP while rendering WIB controls',async()=>{
 const f=await fixture();try{
  const unauthenticated=await f.api('/admin/api/odyssey');assert.equal(unauthenticated.status,401);
  await f.login();
  const response=await f.api('/admin/api/session');assert.equal(response.status,200);
  const page=await f.page();assert.equal(page.status,200);
  const html=await page.text();
  assert.match(html,/Mulai · WIB/);assert.match(html,/id="review"/);
  assert.doesNotMatch(html,/Start \(UTC\)|__NONCE__/);
  assert.match(page.headers.get('content-security-policy'),/script-src 'nonce-/);
  assert.match(page.headers.get('content-security-policy'),/frame-ancestors 'none'/);
 }finally{f.db.sql.close();}
});
