import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { InvalidIdentity } from '../src/jwt_verify.mjs';
import { createWorkerHandler } from '../src/index.mjs';
import { createSummonRecoveryHandlerM11, readCommittedSummonM11, recoveryKeysM11 } from '../src/summon_recovery_route_m11.mjs';

const HOST = 'https://example.workers.dev';
const ID='9cc242ed-56cc-46bc-8f8d-fb2b83388d7a';
const OTHER='362ef4da-bc86-43e6-86dc-dad77241cbde';
const UID='alice1', UID2='bob2';
const RECOVERY_URL=`${HOST}/v1/wallet/summon-recovery/${ID}`;
const identity = (uid=UID)=>({auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}},app:{appId:'1:350718070767:android:e5520012a501d2856cf01a'}});
const result = () => ({item_id:'mistveil_jian',rarity:'rare',duplicate:false,duplicate_shards:0,hard_legendary_pity:false,wish_hit:false,wish_fate_activated:false,wish_fate_consumed:false});
const outcome = () => ({outcome_contract_version:1,pull_count:1,results:[result()],next_pity:{rare_plus:0,epic_plus:1,legendary:1}});
function store(){
  const sqlite=new DatabaseSync(':memory:');sqlite.exec('PRAGMA foreign_keys=ON');
  for (let i=1;i<=4;i++) {
    const name='000'+i+'_'+['iap_ledger','wallet_ledger','summon_outcomes','summon_canonical'][i-1]+'.sql';
    sqlite.exec(readFileSync(new URL('../migrations/'+name,import.meta.url),'utf8'));
  }
  let writes=0, reads=0, primaryReads=0;
  const db={withSession(mode){assert.equal(mode,'first-primary');primaryReads++;return this;}, prepare(sql){assert.match(sql,/^SELECT owner_key,pull_count,jade_cost,outcome_json FROM iap_summon_outcomes_v1 WHERE spend_key = \?$/);return {bind(key){return {first:async()=>{reads++;return sqlite.prepare(sql).get(key)??null;}}}};}};
  const insert=(uid=UID,requestId=ID,o=outcome())=>{
    const {owner,spend}=recoveryKeysM11(uid,requestId);
    sqlite.prepare('INSERT OR IGNORE INTO iap_wallet_accounts_v1 (owner_key,balance,revision) VALUES (?,1000,1)').run(owner);
    sqlite.prepare("INSERT INTO iap_wallet_events_v1 (event_key, owner_key, event_kind, item_key, delta) VALUES (?,?, 'summon_debit', 'summon:1',-100)").run(spend,owner);
    sqlite.prepare('INSERT INTO iap_summon_outcomes_v1(spend_key,owner_key,pull_count,jade_cost,outcome_json) VALUES(?,?,1,100,?)').run(spend,owner,JSON.stringify(o));
    writes+=3;
    return {owner,spend};
  };
  return {sqlite, db, insert, get writes(){return writes},get reads(){return reads},get primaryReads(){return primaryReads},close:()=>sqlite.close()};
}
function fixture({uid=UID,verified=true,readEnabled='false',db=undefined}={}){
 const counters={auth:0,plays:0,credits:0};
 const s=db??store();
 const worker=createWorkerHandler({verifyIdentity:async()=>{counters.auth++;if(!verified)throw new InvalidIdentity();return identity(uid);}, makeLedger:()=>{counters.credits++;throw Error('must not');},makePlay:()=>{counters.plays++;throw Error('must not');}});
 const env={JADE_IAP_BACKEND_ENABLED:'false',JADE_PAID_WALLET_READ_ENABLED:'false',JADE_SUMMON_RECOVERY_READ_ENABLED:readEnabled,DB:s.db};
 return {s,worker,env,counters};
}
test('M11 UUID+UID spend hash matches canonical M4 format (case-normalized)',()=>{
 const x=recoveryKeysM11(UID,ID),y=recoveryKeysM11(UID,ID.toUpperCase());
 assert.deepEqual(x,y);assert.equal(x.owner,'u1:'+createHash('sha256').update(UID).digest('hex'));
 assert.equal(x.spend,'spendv1:'+createHash('sha256').update('summon:v1\0'+UID+'\0'+ID).digest('hex'));
 assert.notEqual(recoveryKeysM11(UID2,ID).spend,x.spend);
});
test('M11 disabled flag prevents identity + DB operations',async()=>{
 const f=fixture();try{const r=await f.worker(new Request(RECOVERY_URL),f.env);assert.equal(r.status,503);assert.deepEqual(await r.json(),{error:'summon_recovery_disabled'});assert.equal(f.counters.auth,0);assert.equal(f.s.reads,0);}finally{f.s.close();}
});
test('M11 boolean true and uppercase TRUE do not unlock',async()=>{
 const f=fixture();try{for(const val of [true,'TRUE','1',1]){const r=await f.worker(new Request(RECOVERY_URL),{...f.env,JADE_SUMMON_RECOVERY_READ_ENABLED:val});assert.equal(r.status,503);}assert.equal(f.counters.auth,0);}finally{f.s.close();}
});
test('M11 route is independently gated from paid read/purchase gates',async()=>{
 const f=fixture();try{const r=await f.worker(new Request(RECOVERY_URL),{...f.env,JADE_IAP_BACKEND_ENABLED:'true',JADE_PAID_WALLET_READ_ENABLED:'true'});assert.equal(r.status,503);assert.equal(f.counters.auth,0);}finally{f.s.close();}
});
test('M11 invalid UUID is rejected before auth and DB',async()=>{
 const f=fixture({readEnabled:'true'});try{for(const u of [RECOVERY_URL+'x',RECOVERY_URL.replace(ID,'../bad'),RECOVERY_URL.replace(ID,'123'),RECOVERY_URL+'/extra']){const r=await f.worker(new Request(u),f.env);assert.ok([400,404].includes(r.status));}assert.equal(f.counters.auth,0);}finally{f.s.close();}
});
test('M11 blocks non-GET and body even when enabled',async()=>{
 const f=fixture({readEnabled:'true'});try{let r=await f.worker(new Request(RECOVERY_URL,{method:'POST',body:'{}'}),f.env);assert.equal(r.status,405);r=await f.worker(new Request(RECOVERY_URL,{headers:{'content-length':'0'}}),f.env);assert.equal(r.status,400);r=await f.worker(new Request(RECOVERY_URL+'?uid=alice1'),f.env);assert.equal(r.status,400);assert.equal(f.counters.auth,0);}finally{f.s.close();}
});
test('M11 missing DB returns unavailable before auth',async()=>{
 const f=fixture({readEnabled:'true'});try{const r=await f.worker(new Request(RECOVERY_URL),{...f.env,DB:null});assert.equal(r.status,503);assert.equal(f.counters.auth,0);}finally{f.s.close();}
});
test('M11 verified Firebase auth + AppCheck required',async()=>{
 const f=fixture({readEnabled:'true',verified:false});try{const r=await f.worker(new Request(RECOVERY_URL),f.env);assert.equal(r.status,401);assert.equal(f.s.reads,0);}finally{f.s.close();}
});
test('M11 does not accept invalid identity shape after verify callback',async()=>{
 const s=store();try{const h=createSummonRecoveryHandlerM11({verifyIdentity:async()=>({auth:{uid:UID}})});const r=await h(new Request(RECOVERY_URL),{DB:s.db,JADE_SUMMON_RECOVERY_READ_ENABLED:'true'});assert.equal(r.status,401);assert.equal(s.reads,0);}finally{s.close();}
});
test('M11 strict UID binding: same ID on other Firebase account is never disclosed',async()=>{
 const f=fixture({uid:UID2,readEnabled:'true'});try{f.s.insert();const r=await f.worker(new Request(RECOVERY_URL),f.env);assert.equal(r.status,404);assert.deepEqual(await r.json(),{error:'summon_not_found'});assert.equal(f.s.reads,1);}finally{f.s.close();}
});
test('M11 valid committed outcome recoverable, and retry returns exact same outcome without writes',async()=>{
 const f=fixture({readEnabled:'true'});try{f.s.insert();const before=f.s.writes;const x=await f.worker(new Request(RECOVERY_URL),f.env),y=await f.worker(new Request(RECOVERY_URL),f.env);assert.equal(x.status,200);assert.equal(y.status,200);assert.deepEqual(await x.json(),await y.json());const data=await readCommittedSummonM11({db:f.s.db,verifiedIdentity:identity(),requestId:ID});assert.deepEqual(data.outcome,outcome());assert.equal(data.state,'committed');assert.equal(data.request_id,ID);assert.equal(f.s.writes,before);assert.equal(f.counters.plays,0);assert.equal(f.counters.credits,0);assert.ok(f.s.primaryReads>=2);}finally{f.s.close();}
});
test('M11 case-insensitive UUID returns stable lowercase operation id',async()=>{
 const f=fixture({readEnabled:'true'});try{f.s.insert();const r=await f.worker(new Request(RECOVERY_URL.replace(ID,ID.toUpperCase())),f.env);assert.equal(r.status,200);assert.equal((await r.json()).request_id,ID);}finally{f.s.close();}
});
test('M11 not found does not create wallet account or outcome',async()=>{
 const f=fixture({readEnabled:'true'});try{const r=await f.worker(new Request(RECOVERY_URL),f.env);assert.equal(r.status,404);assert.equal(f.s.sqlite.prepare('SELECT COUNT(*) AS n FROM iap_wallet_accounts_v1').get().n,0);}finally{f.s.close();}
});
test('M11 stored response tampering fails closed with no leakage',async()=>{
 const f=fixture({readEnabled:'true'});try{const {spend}=f.s.insert();f.s.sqlite.prepare('UPDATE iap_summon_outcomes_v1 SET outcome_json=? WHERE spend_key=?').run(JSON.stringify({...outcome(),results:[{...result(),duplicate_shards:999999}]}),spend);const r=await f.worker(new Request(RECOVERY_URL),f.env);assert.equal(r.status,503);assert.deepEqual(await r.json(),{error:'summon_recovery_temporarily_unavailable'});}finally{f.s.close();}
});
test('M11 no stale replica: primary session is used for DB read',async()=>{
 const f=fixture({readEnabled:'true'});try{f.s.insert();await f.worker(new Request(RECOVERY_URL),f.env);assert.equal(f.s.primaryReads,1);}finally{f.s.close();}
});
test('M11 purchase endpoint remains disabled independently',async()=>{
 const f=fixture({readEnabled:'true'});try{const r=await f.worker(new Request(HOST+'/v1/iap/authorize',{method:'POST',headers:{'content-type':'application/json'},body:'{}'}),f.env);assert.equal(r.status,503);assert.deepEqual(await r.json(),{error:'purchase_backend_disabled'});}finally{f.s.close();}
});
test('M11 valid request with malformed database row fails closed',async()=>{
 const s=store();try{const req=ID; const key=recoveryKeysM11(UID,req);const db={prepare:()=>({bind:()=>({first:async()=>({owner_key:key.owner,pull_count:1,jade_cost:900,outcome_json:JSON.stringify(outcome())})})})};const h=createSummonRecoveryHandlerM11({verifyIdentity:async()=>identity()});const r=await h(new Request(RECOVERY_URL),{DB:db,JADE_SUMMON_RECOVERY_READ_ENABLED:'true'});assert.equal(r.status,503);}finally{s.close();}
});
test('M11 response suppresses caching and personal identity',async()=>{
 const f=fixture({readEnabled:'true'});try{f.s.insert();const r=await f.worker(new Request(RECOVERY_URL),f.env);const body=await r.text();assert.equal(r.headers.get('cache-control'),'no-store, private');assert.equal(r.headers.get('vary'),'Authorization, X-Firebase-AppCheck');assert.ok(!body.includes(UID));}finally{f.s.close();}
});
