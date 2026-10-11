import test from 'node:test';
import assert from 'node:assert/strict';
import { createRefundScheduledHandlerRC11 } from '../src/worker_scheduled_refund_rc11.mjs';
import { createPlayGateway } from '../src/play_api.mjs';
import { webcrypto } from 'node:crypto';

const NOW=1791648000000;

test('locked cron performs zero DB, token, or network work',async()=>{
  let touched=0;
  const scheduled=createRefundScheduledHandlerRC11({
    clock:()=>{touched++;return NOW;},
    run:async()=>{touched++;throw Error('should not run');},
  });
  assert.deepEqual(await scheduled({},{}),{state:'job_locked'});
  assert.equal(touched,0);
});

test('enabled cron passes private makePlayGateway and propagates success',async()=>{
  let args;
  const scheduled=createRefundScheduledHandlerRC11({clock:()=>NOW,
    makePlayGateway:secret=>({marker:secret}),
    run:async(env,p)=>{
      args=p;
      assert.equal(env.JADE_REFUND_CRON_JOB_RC7_ENABLED,'true');
      assert.deepEqual(p.makePlayGateway('private-secret'),{marker:'private-secret'});
      return {state:'staging_reconciled_not_production_ready',pages:1};
    },
  });
  assert.equal((await scheduled({}, {JADE_REFUND_CRON_JOB_RC7_ENABLED:'true'})).pages,1);
  assert.equal(args.nowMs,NOW);
});

test('cron rejects an incomplete response instead of marking it successful',async()=>{
  const scheduled=createRefundScheduledHandlerRC11({run:async()=>({state:'job_locked'})});
  await assert.rejects(scheduled({}, {JADE_REFUND_CRON_JOB_RC7_ENABLED:'true'}),/incomplete/);
});

test('cron propagates D1/Play outage to scheduling runtime',async()=>{
  const scheduled=createRefundScheduledHandlerRC11({run:async()=>{throw Error('D1 down');}});
  await assert.rejects(scheduled({}, {JADE_REFUND_CRON_JOB_RC7_ENABLED:'true'}),/D1 down/);
});

test('rejects an invalid clock before touching authenticated transport',async()=>{
  let called=false;
  const scheduled=createRefundScheduledHandlerRC11({clock:()=>NaN,run:async()=>{called=true;}});
  await assert.rejects(scheduled({}, {JADE_REFUND_CRON_JOB_RC7_ENABLED:'true'}),/invalid_job_clock/);
  assert.equal(called,false);
});

test('real Play gateway shares OAuth for purchase check and voided pagination',async()=>{
  const keys=await webcrypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
  const der=new Uint8Array(await webcrypto.subtle.exportKey('pkcs8',keys.privateKey));
  const base64=Buffer.from(der).toString('base64');
  const pem='-----BEGIN PRIVATE KEY-----\n'+base64.match(/.{1,64}/g).join('\n')+'\n-----END PRIVATE KEY-----';
  const secret=JSON.stringify({type:'service_account',client_email:'test-service@gcp-project.iam.gserviceaccount.com',private_key:pem});
  const seen=[];
  const fetcher=async(url,opts)=>{
    const parsed=new URL(url);seen.push({host:parsed.hostname,method:opts.method,url:parsed});
    if(parsed.hostname==='oauth2.googleapis.com'){
      const assertion=String(opts.body.get('assertion'));
      const [h,p,s]=assertion.split('.');assert.ok(h&&p&&s);
      const claims=JSON.parse(Buffer.from(p,'base64url').toString());
      assert.equal(claims.scope,'https://www.googleapis.com/auth/androidpublisher');
      assert.equal(claims.aud,'https://oauth2.googleapis.com/token');
      return new Response(JSON.stringify({access_token:'oauth-generated-server-token-12345',expires_in:3500}),{headers:{'Content-Type':'application/json'}});
    }
    assert.equal(opts.headers.Authorization,'Bearer oauth-generated-server-token-12345');
    assert.equal(parsed.hostname,'androidpublisher.googleapis.com');
    if(parsed.pathname.endsWith('/purchases/voidedpurchases')){
      assert.equal(parsed.searchParams.get('type'),'0');
      assert.equal(parsed.searchParams.get('includeQuantityBasedPartialRefund'),'true');
      assert.equal(parsed.searchParams.get('startTime'),'10000000');
      assert.equal(parsed.searchParams.get('endTime'),'20000000');
      return new Response(JSON.stringify({voidedPurchases:[]}),{headers:{'Content-Type':'application/json'}});
    }
    return new Response(JSON.stringify({purchaseStateContext:{purchaseState:'PURCHASED'}}),{headers:{'Content-Type':'application/json'}});
  };
  const play=createPlayGateway(secret,fetcher);
  const page=await play.listVoidedPurchasesPageRC7({startTimeMs:10000000,endTimeMs:20000000});
  assert.deepEqual(page,{voidedPurchases:[]});
  await play.getProductPurchaseV2('com.yungdevstudio.jadeascendant','sampleplaytoken0000000000');
  assert.equal(seen.filter(e=>e.host==='oauth2.googleapis.com').length,1);
  assert.equal(seen.filter(e=>e.host==='androidpublisher.googleapis.com').length,2);
});

test('untrusted purchase token cannot enter voided gateway parameters',async()=>{
  const gateway=createPlayGateway('{"type":"service_account"}');
  await assert.rejects(gateway.getProductPurchaseV2('evil.package','token-token-token-token'));
});

import { DatabaseSync } from 'node:sqlite';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

function stagedSqliteRefundFixture({purchaseToken,uid}){
  const sqlite=new DatabaseSync(':memory:');
  sqlite.exec('PRAGMA foreign_keys=ON');
  sqlite.exec(`CREATE TABLE iap_wallet_accounts_v1(owner_key TEXT PRIMARY KEY,balance INTEGER NOT NULL DEFAULT 0 CHECK(balance >= 0),revision INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE iap_purchase_ledger_v1(token_key TEXT PRIMARY KEY,record_json TEXT NOT NULL);`);
  for(const name of ['0008_refund_account_holds.sql','0009_play_voided_reconciliation.sql'])
    sqlite.exec(readFileSync(new URL('../migrations/'+name,import.meta.url),'utf8'));
  const hash=x=>createHash('sha256').update(x).digest('hex');
  const key='playtoken:'+hash(purchaseToken);
  sqlite.prepare('INSERT INTO iap_purchase_ledger_v1 VALUES (?,?)').run(key,JSON.stringify({
    tokenKey:key,grantId:'iapv1:'+hash(purchaseToken),ownerUid:uid,ownerBinding:hash(uid),state:'grant_ready',
  }));
  const d1={
    prepare(sql){return {bind(...args){return {
      async first(){return sqlite.prepare(sql).get(...args)??null;},
      async all(){return {results:sqlite.prepare(sql).all(...args)};},
      run(){return sqlite.prepare(sql).run(...args);},
    };},async first(){return sqlite.prepare(sql).get()??null;}};},
    withSession(mode){assert.equal(mode,'first-primary');return this;},
    async batch(stmts){sqlite.exec('BEGIN IMMEDIATE');try{const rows=stmts.map(stmt=>stmt.run());sqlite.exec('COMMIT');return rows;}catch(e){sqlite.exec('ROLLBACK');throw e;}},
  };
  return {sqlite,d1};
}

test('end-to-end scheduled Play poll -> D1 void audit + account hold + freshness watermark',async()=>{
  const token='PLAY_VOIDED_AUTHENTICATED_TOKEN_LONG_987654';
  const uid='firebase-player-777';
  const now=Date.now();
  const {sqlite,d1}=stagedSqliteRefundFixture({purchaseToken:token,uid});
  try{
    let pages=0;
    const scheduled=createRefundScheduledHandlerRC11({clock:()=>now,
      makePlayGateway:_secret=>({listVoidedPurchasesPageRC7:async ({pageToken})=>{
        pages++;
        if(pageToken!==null)throw Error('unexpected page');
        return {voidedPurchases:[{purchaseToken:token,voidedTimeMillis:String(now-120000),voidedReason:7,voidedSource:2}],tokenPagination:{}};
      }}),
    });
    const result=await scheduled({cron:'0 * * * *'},{JADE_REFUND_CRON_JOB_RC7_ENABLED:'true',DB:d1,PLAY_SERVICE_ACCOUNT_JSON:'private-google-secret'});
    assert.equal(result.records,1);assert.equal(pages,1);
    const voided=sqlite.prepare('SELECT token_key,owner_key FROM iap_play_void_events_v1').get();
    const held=sqlite.prepare('SELECT status,owner_key FROM iap_refund_account_holds_v1').get();
    assert.equal(voided.token_key,'playtoken:'+createHash('sha256').update(token).digest('hex'));
    assert.equal(held.status,'held');assert.equal(voided.owner_key,held.owner_key);
    assert.equal(sqlite.prepare('SELECT watermark_ms FROM iap_play_void_cursor_v1').get().watermark_ms,now-60000);
    assert.ok(!JSON.stringify(voided).includes(token));assert.ok(!JSON.stringify(held).includes(uid));
  }finally{sqlite.close();}
});

test('scheduled second-page outage cannot advance D1 refund watermark',async()=>{
  const token='PLAY_VOIDED_AUTHENTICATED_TOKEN_LONG_987654';
  const {sqlite,d1}=stagedSqliteRefundFixture({purchaseToken:token,uid:'firebase-player-777'});
  try{
    const now=Date.now();
    const scheduled=createRefundScheduledHandlerRC11({clock:()=>now,
      makePlayGateway:_secret=>({listVoidedPurchasesPageRC7:async ({pageToken})=>{
        if(pageToken!==null)throw Error('Google API 503');
        return {voidedPurchases:[{purchaseToken:token,voidedTimeMillis:String(now-120000),voidedReason:7,voidedSource:2}],tokenPagination:{nextPageToken:'NEXT'}};
      }}),
    });
    await assert.rejects(scheduled({cron:'0 * * * *'},{JADE_REFUND_CRON_JOB_RC7_ENABLED:'true',DB:d1,PLAY_SERVICE_ACCOUNT_JSON:'private-google-secret'}),/Google API 503/);
    assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM iap_play_void_cursor_v1').get().n,0);
    assert.equal(sqlite.prepare('SELECT status FROM iap_refund_account_holds_v1').get().status,'held');
  }finally{sqlite.close();}
});
