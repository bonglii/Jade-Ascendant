import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { generateKeyPairSync, sign } from 'node:crypto';
import { normalizeTrustedGoogleKeys } from '../ssv/m7e4b_ssv_verifier.mjs';
import { m7e4cStorageContract } from '../ssv/m7e4c_receipt_ledger.mjs';
import { createGoogleKeySource, GOOGLE_ADMOB_VERIFIER_URL } from '../ssv/m7e4d_google_keys.mjs';
import { createSsvHttpHandler, isEmulatorOnlyEnabled } from '../ssv/m7e4d_http_boundary.mjs';

const NOW=1791470000000;
const {privateKey,publicKey}=generateKeyPairSync('ec',{namedCurve:'prime256v1'});
const pem=publicKey.export({type:'spki',format:'pem'});
const keys=normalizeTrustedGoogleKeys({keys:[{keyId:1234567,pem}]});
const NONCE='oWQe5Vt0epTz6ZtGLxYnCfTC8M73Rg3p';
const TX='ac'.repeat(16);
const clone=x=>structuredClone(x);
class Ref {
  constructor(db,col,id){this.db=db;this.path=`${col}/${id}`;}
  async get(){return this.db.snapshot(this.path);}
}
class FakeDb {
  constructor(){this.store=new Map();this.queue=Promise.resolve();this.fail=false;}
  collection(name){return {doc:id=>new Ref(this,name,id)};}
  snapshot(path,store=this.store){return{exists:store.has(path),data:()=>clone(store.get(path))};}
  async runTransaction(work){
    const prior=this.queue;let release;this.queue=new Promise(r=>release=r);await prior;
    try{
      const writes=[];const tx={
        get:async ref=>this.snapshot(ref.path),
        create:(ref,data)=>writes.push(['create',ref.path,clone(data)]),
        update:(ref,data)=>writes.push(['update',ref.path,clone(data)]),
        set:(ref,data)=>writes.push(['set',ref.path,clone(data)]),
      };
      const result=await work(tx);
      if(this.fail)throw Error('COMMIT_FAILURE');
      const next=new Map([...this.store].map(([k,v])=>[k,clone(v)]));
      for(const [op,path,data] of writes){
        if(op==='create'&&next.has(path))throw Error('CREATE_EXISTING');
        if(op==='update'&&!next.has(path))throw Error('UPDATE_MISSING');
        next.set(path,op==='update'?{...next.get(path),...data}:data);
      }
      this.store=next;return result;
    }finally{release();}
  }
  values(prefix){return [...this.store.entries()].filter(([k])=>k.startsWith(prefix+'/')).map(([,v])=>v);}
}
const intent=(n=0)=>({intentId:`intent_${n}`,userId:'trusted_uid_1',nonce:NONCE+n,
  placement:'dao_choice_reroll',runId:`run_${n}`,adUnit:'9876543210',
  rewardAmount:1,rewardItem:'rewarded_grant',status:'PENDING',
  issuedAtMs:NOW-1000,expiresAtMs:NOW+1000*60});
function query(i=intent(),transaction=TX){
  const fields={ad_network:'12345',ad_unit:i.adUnit,reward_amount:String(i.rewardAmount),
    reward_item:i.rewardItem,timestamp:String(NOW),transaction_id:transaction,
    custom_data:i.nonce,user_id:'UNTRUSTED_NOT_USED'};
  const raw=Object.entries(fields).map(([k,v])=>`${k}=${encodeURIComponent(v)}`).join('&');
  return `?${raw}&signature=${sign('sha256',Buffer.from(raw),privateKey).toString('base64url')}&key_id=1234567`;
}
async function httpInvoke(handler, url, method='GET'){
  const server=createServer(handler);await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try{
    const response=await fetch(`http://127.0.0.1:${server.address().port}${url}`,{method});
    return {status:response.status,text:await response.text(),headers:response.headers};
  }finally{await new Promise(r=>server.close(r));}
}
function rig(){
  const db=new FakeDb();const i=intent();
  db.store.set(`m7e4c_ssv_intents/${m7e4cStorageContract.intentDocumentIdForNonce(i.nonce)}`,i);
  const handler=createSsvHttpHandler({db,enabled:true,now:()=>NOW,getTrustedGoogleKeys:async()=>keys});
  return {db,i,handler};
}

test('valid signed HTTP callback returns 200 only after recording pending credit',async()=>{
  const {db,i,handler}=rig();const res=await httpInvoke(handler,'/jadeAdSsvEmulator'+query(i));
  assert.equal(res.status,200);assert.equal(res.text,'OK');
  assert.equal(db.values('m7e4c_ssv_receipts').length,1);
  assert.equal(db.values('m7e4c_ssv_credits')[0].state,'PENDING_DELIVERY');
  assert.equal(db.values('m7e4c_ssv_credits')[0].userId,i.userId);
  assert.equal(res.headers.get('cache-control'),'no-store');
});
test('duplicate signed callback returns 200 without extra credit',async()=>{
  const {db,i,handler}=rig();const url='/'+query(i);
  assert.equal((await httpInvoke(handler,url)).status,200);
  assert.equal((await httpInvoke(handler,url)).status,200);
  assert.equal(db.values('m7e4c_ssv_credits').length,1);
});
test('parallel callbacks converge on single pending reward',async()=>{
  const {db,i,handler}=rig();const url='/'+query(i);
  const results=await Promise.all(Array.from({length:3},()=>httpInvoke(handler,url)));
  assert.deepEqual(results.map(r=>r.status),[200,200,200]);
  assert.equal(db.values('m7e4c_ssv_credits').length,1);
});
test('broken transaction is retriable 503 with zero receipts',async()=>{
  const {db,i,handler}=rig();db.fail=true;
  const first=await httpInvoke(handler,'/'+query(i));
  assert.equal(first.status,503);assert.equal(db.values('m7e4c_ssv_receipts').length,0);
  db.fail=false;assert.equal((await httpInvoke(handler,'/'+query(i))).status,200);
});
test('no callback acknowledgement if Google keys fetch fails',async()=>{
  const {db,i}=rig();const handler=createSsvHttpHandler({db,enabled:true,now:()=>NOW,getTrustedGoogleKeys:async()=>{throw Error('NO_NETWORK')}});
  assert.equal((await httpInvoke(handler,'/'+query(i))).status,503);
  assert.equal(db.values('m7e4c_ssv_credits').length,0);
});
test('unknown signed nonce rejected without credit',async()=>{
  const {db,handler}=rig();assert.equal((await httpInvoke(handler,'/'+query(intent(3)))).status,403);
  assert.equal(db.values('m7e4c_ssv_credits').length,0);
});
test('forged signed fields rejected without credit',async()=>{
  const {db,i,handler}=rig();assert.equal((await httpInvoke(handler,'/'+query(i).replace('reward_amount=1','reward_amount=9'))).status,403);
  assert.equal(db.values('m7e4c_ssv_credits').length,0);
});
test('GET only, POST rejected before ledger touch',async()=>{
  const {db,i,handler}=rig();assert.equal((await httpInvoke(handler,'/'+query(i),'POST')).status,405);
  assert.equal(db.values('m7e4c_ssv_receipts').length,0);
});
test('missing query rejected without reading database',async()=>{
  const {db,handler}=rig();assert.equal((await httpInvoke(handler,'/')).status,400);
  assert.equal(db.values('m7e4c_ssv_receipts').length,0);
});
test('explicit kill switch blocks a signed callback',async()=>{
  const {db,i}=rig();const handler=createSsvHttpHandler({db,enabled:false,now:()=>NOW,getTrustedGoogleKeys:async()=>keys});
  assert.equal((await httpInvoke(handler,'/'+query(i))).status,503);
  assert.equal(db.values('m7e4c_ssv_credits').length,0);
});
test('only a restricted demo Firestore and Functions emulator may enable endpoint',()=>{
  const good={FUNCTIONS_EMULATOR:'true',FIRESTORE_EMULATOR_HOST:'127.0.0.1:8088',
    GCLOUD_PROJECT:'demo-jade-ssv',JADE_SSV_EMULATOR_TEST_ONLY:'1'};
  assert.equal(isEmulatorOnlyEnabled(good),true);
  for(const key of Object.keys(good)){
    const bad={...good};delete bad[key];assert.equal(isEmulatorOnlyEnabled(bad),false,key);
  }
  assert.equal(isEmulatorOnlyEnabled({...good,GCLOUD_PROJECT:'production-jade'}),false);
  assert.equal(isEmulatorOnlyEnabled({...good,FIRESTORE_EMULATOR_HOST:'firestore.googleapis.com:443'}),false);
});
test('pinned Google verifier URL, bounded 12-hour TTL cache and auto-refresh',async()=>{
  let time=NOW,calls=0;
  const keySource=createGoogleKeySource({now:()=>time,ttlMs:12*3600*1000,
    fetchImpl:async(url,opts)=>{
      assert.equal(url,GOOGLE_ADMOB_VERIFIER_URL);
      assert.equal(opts.method,'GET');assert.equal(opts.redirect,'error');
      calls++;
      return {ok:true,status:200,headers:{get:()=>null},text:async()=>JSON.stringify({keys:[{keyId:1234567,pem}]})};
    }});
  const a=await keySource();const b=await keySource();assert.equal(a,b);assert.equal(calls,1);
  time+=12*3600*1000+1;const c=await keySource();assert.ok(c);assert.equal(calls,2);
});
test('concurrent key requests share one fetch',async()=>{
  let calls=0;
  const source=createGoogleKeySource({now:()=>NOW,fetchImpl:async()=>{
    calls++;await new Promise(r=>setTimeout(r,15));
    return {ok:true,status:200,headers:{get:()=>null},text:async()=>JSON.stringify({keys:[{keyId:1234567,pem}]})};
  }});
  const z=await Promise.all([source(),source(),source()]);
  assert.equal(calls,1);assert.ok(z.every(k=>k===z[0]));
});
test('invalid/oversized/HTTP failed Google key response fails closed',async()=>{
  const mock=async response=>{
    const s=createGoogleKeySource({now:()=>NOW,fetchImpl:async()=>response});
    await assert.rejects(s());
  };
  await mock({ok:false,status:500,headers:{get:()=>null},text:async()=>''});
  await mock({ok:true,status:200,headers:{get:()=>null},text:async()=>JSON.stringify({keys:[]})});
  await mock({ok:true,status:200,headers:{get:()=>String(1024*1024)},text:async()=>''});
  await mock({ok:true,status:200,headers:{get:()=>null},text:async()=>'{'});
  await mock({ok:true,status:200,headers:{get:()=>null},text:async()=>'.'.repeat(300000)});
});
test('key caching cannot exceed 24h by construction',()=>{
  assert.throws(()=>createGoogleKeySource({ttlMs:25*3600*1000}),/KEY_SOURCE_CONFIG_INVALID/);
});
