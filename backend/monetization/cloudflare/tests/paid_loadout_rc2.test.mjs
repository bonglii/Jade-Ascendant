import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { createPaidLoadoutHandlerRC2,readPaidLoadoutRC2 } from '../src/paid_loadout_route_rc2.mjs';
import { PAID_SLOT_OF_ITEM_RC2 } from '../src/paid_loadout_catalog_rc2.mjs';

const owner=uid=>'u1:'+createHash('sha256').update(uid).digest('hex');
const ID='1270edbf-243a-499b-8306-1c908f641ea4';
const ID2='2270edbf-243a-499b-8306-1c908f641ea4';
const identity=(uid='owner1')=>({auth:{uid,token:{firebase:{sign_in_provider:'google.com'}}},app:{appId:'app-trusted-123456'}});
const endpoint='https://unit.test/v1/wallet/paid-loadout';
const slots=()=>({armament:'',robe:'',bracer:'',boots:'',pendant:''});
const command=(id=ID,revision=0,er=0,s=slots())=>({request_id:id,expected_loadout_revision:revision,expected_entitlement_revision:er,paid_slots:s});
const req=c=>new Request(endpoint,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(c)});
const flags=(db,extra={})=>({DB:db,JADE_IAP_BACKEND_ENABLED:'true',JADE_PAID_LOADOUT_READ_ENABLED:'true',JADE_PAID_LOADOUT_WRITE_ENABLED:'true',...extra});
const canonical=(items=['mistveil_jian'])=>({state_contract_version:1,cleared_stage_keys:['1-5'],pity:{rare_plus:0,epic_plus:0,legendary:0},wish_item_id:'',wish_fate_guaranteed:false,lifetime_pulls:0,inventory:Object.fromEntries(items.map(x=>[x,1])),refinement_shards:0});
class DB {
  constructor(){
    this.sql=new DatabaseSync(':memory:');this.sql.exec('PRAGMA foreign_keys=ON');
    for(const x of ['0001_iap_ledger.sql','0002_wallet_ledger.sql','0003_summon_outcomes.sql','0004_summon_canonical.sql','0005_paid_loadout.sql'])
      this.sql.exec(readFileSync(new URL('../migrations/'+x,import.meta.url),'utf8'));
    this.queue=Promise.resolve();
  }
  prepare(sql){return {bind:(...args)=>({first:async()=>this.sql.prepare(sql).get(...args)??null,run:async()=>this.sql.prepare(sql).run(...args)})};}
  withSession(mode){assert.equal(mode,'first-primary');return this;}
  batch(commands){
    const execute=async()=>{
      this.sql.exec('BEGIN IMMEDIATE');
      try{const out=[];for(const c of commands)out.push(await c.run());this.sql.exec('COMMIT');return out;}
      catch(e){this.sql.exec('ROLLBACK');throw e;}
    };
    const ongoing=this.queue.then(execute,execute);this.queue=ongoing.catch(()=>{});return ongoing;
  }
  seed(uid='owner1',items=['mistveil_jian']){
    this.sql.prepare('INSERT INTO iap_wallet_accounts_v1(owner_key,balance,revision) VALUES (?,0,0)').run(owner(uid));
    this.sql.prepare("INSERT INTO iap_summon_canonical_v1(owner_key,revision,status,state_json) VALUES (?,0,'verified',?)").run(owner(uid),JSON.stringify(canonical(items)));
  }
  get(table){return this.sql.prepare('SELECT COUNT(*) n FROM '+table).get().n;}
  close(){this.sql.close();}
}
const handler=uid=>createPaidLoadoutHandlerRC2({verifyIdentity:async()=>identity(uid)});

test('catalog has all 40 pinned equipment IDs and each belongs to one slot',()=>{
  assert.equal(Object.keys(PAID_SLOT_OF_ITEM_RC2).length,40);
  assert.equal(PAID_SLOT_OF_ITEM_RC2.mistveil_jian,'armament');
  assert.equal(PAID_SLOT_OF_ITEM_RC2.bamboo_weave_robe,'robe');
});
test('both loadout operations fail closed without flags and skip auth',async()=>{
  let authCalls=0;const h=createPaidLoadoutHandlerRC2({verifyIdentity:()=>{authCalls++;throw Error('unexpected');}});
  assert.equal((await h(new Request(endpoint),{})).status,503);
  assert.equal((await h(req(command()),{})).status,503);
  assert.equal(authCalls,0);
});
test('write requires BOTH global IAP lock and independently gated paid loadout flag',async()=>{
  const db=new DB();db.seed();const h=handler();
  for(const e of [{JADE_IAP_BACKEND_ENABLED:'false'},{JADE_PAID_LOADOUT_WRITE_ENABLED:'false'}]){
    assert.equal((await h(req(command()),flags(db,e))).status,503);
  }
  assert.equal(db.get('iap_paid_loadouts_v1'),0);db.close();
});
test('no canonical verified ownership means NO loadout provisioning',async()=>{
  const db=new DB(),h=handler();
  assert.equal((await h(new Request(endpoint),flags(db))).status,409);
  assert.equal((await h(req(command()),flags(db))).status,409);
  assert.equal(db.get('iap_paid_loadouts_v1'),0);db.close();
});
test('empty signed owner view is read-only and does not create anything',async()=>{
  const db=new DB();db.seed();const r=await readPaidLoadoutRC2({db,verifiedIdentity:identity()});
  assert.equal(r.revision,0);assert.equal(r.entitlement_revision,0);
  assert.deepEqual(r.paid_slots,slots());assert.equal(r.authority,'server_only');
  assert.equal(db.get('iap_paid_loadouts_v1'),0);db.close();
});
test('verified equip is committed once, replay stable, and never mutates inventory or wallet',async()=>{
  const db=new DB();db.seed();const h=handler();
  const s=slots();s.armament='mistveil_jian';
  const before=db.sql.prepare('SELECT state_json FROM iap_summon_canonical_v1 WHERE owner_key=?').get(owner('owner1')).state_json;
  const a=await h(req(command(ID,0,0,s)),flags(db));assert.equal(a.status,200);
  const first=await a.json();assert.equal(first.revision,1);assert.equal(first.paid_slots.armament,'mistveil_jian');
  assert.equal(first.entitlement_revision,0);
  const b=await h(req(command(ID,0,0,s)),flags(db));assert.equal(b.status,200);
  assert.deepEqual(await b.json(),first);
  assert.equal(db.get('iap_paid_loadout_ops_v1'),1);
  assert.equal(db.get('iap_wallet_events_v1'),0);
  assert.equal(db.sql.prepare('SELECT state_json FROM iap_summon_canonical_v1 WHERE owner_key=?').get(owner('owner1')).state_json,before);
  db.close();
});
test('request replay with different payload conflicts and has no effects',async()=>{
  const db=new DB();db.seed();const h=handler();
  const s=slots();s.armament='mistveil_jian';
  assert.equal((await h(req(command(ID,0,0,s)),flags(db))).status,200);
  const res=await h(req(command(ID,0,0,slots())),flags(db));
  assert.equal(res.status,409);assert.equal((await res.json()).error,'idempotency_conflict');
  assert.equal(db.get('iap_paid_loadout_ops_v1'),1);db.close();
});
test('unowned item and wrong-slot writes rejected without partial SQL',async()=>{
  const db=new DB();db.seed();const h=handler();
  const s=slots();s.armament='nine_heavens_star_sword';
  const a=await h(req(command(ID,0,0,s)),flags(db));assert.equal(a.status,409);
  assert.equal((await a.json()).error,'paid_item_not_owned');
  s.armament='bamboo_weave_robe';
  assert.equal((await h(req(command(ID,0,0,s)),flags(db))).status,400);
  assert.equal(db.get('iap_paid_loadouts_v1'),0);
  assert.equal(db.get('iap_paid_loadout_ops_v1'),0);db.close();
});
test('cross-account item ownership and loadout are isolated',async()=>{
  const db=new DB();db.seed('owner1',['mistveil_jian']);db.seed('owner2',['bamboo_weave_robe']);
  const s=slots();s.armament='mistveil_jian';
  assert.equal((await handler('owner1')(req(command(ID,0,0,s)),flags(db))).status,200);
  assert.equal((await handler('owner2')(req(command(ID,0,0,s)),flags(db))).status,409);
  const view=await handler('owner2')(new Request(endpoint),flags(db));
  assert.equal(view.status,200);assert.deepEqual((await view.json()).paid_slots,slots());db.close();
});
test('CAS rejects stale revision and canonical progression changes',async()=>{
  const db=new DB();db.seed();const h=handler();const s=slots();s.armament='mistveil_jian';
  assert.equal((await h(req(command(ID,0,0,s)),flags(db))).status,200);
  const stale=await h(req(command(ID2,0,0,s)),flags(db));assert.equal(stale.status,409);
  db.sql.prepare('UPDATE iap_summon_canonical_v1 SET revision=revision+1 WHERE owner_key=?').run(owner('owner1'));
  assert.equal((await h(req(command(ID2,1,0,s)),flags(db))).status,409);
  assert.equal(db.get('iap_paid_loadout_ops_v1'),1);db.close();
});
test('revoked item is never displayed as a paid loadout or replayed',async()=>{
  const db=new DB();db.seed();const h=handler();const s=slots();s.armament='mistveil_jian';
  assert.equal((await h(req(command(ID,0,0,s)),flags(db))).status,200);
  db.sql.prepare('UPDATE iap_summon_canonical_v1 SET revision=revision+1,state_json=? WHERE owner_key=?')
    .run(JSON.stringify(canonical([])),owner('owner1'));
  assert.equal((await h(new Request(endpoint),flags(db))).status,503);
  assert.equal((await h(req(command(ID,0,0,s)),flags(db))).status,409);
  db.close();
});
test('route rejects caller UID, balances, unknown fields, bad request IDs and forbidden methods',async()=>{
  const db=new DB();db.seed();const h=handler();
  assert.equal((await h(new Request(endpoint+'?uid=owner2'),flags(db))).status,400);
  assert.equal((await h(new Request(endpoint,{method:'PUT'}),flags(db))).status,405);
  for(const c of [{...command(),uid:'other'}, {...command(),balance:99999}, {...command(),request_id:'bad'}]){
    assert.equal((await h(req(c),flags(db))).status,400);
  }
  assert.equal(db.get('iap_paid_loadout_ops_v1'),0);db.close();
});

test('two simultaneous writes at same revision produce exactly one committed operation',async()=>{
  const db=new DB();db.seed();const h=handler();
  const s=slots();s.armament='mistveil_jian';
  const result=await Promise.all([h(req(command(ID,0,0,s)),flags(db)),h(req(command(ID2,0,0,s)),flags(db))]);
  assert.deepEqual(result.map(x=>x.status).sort(),[200,409]);
  assert.equal(db.get('iap_paid_loadout_ops_v1'),1);
  assert.equal(db.sql.prepare('SELECT revision FROM iap_paid_loadouts_v1').get().revision,1);
  db.close();
});
