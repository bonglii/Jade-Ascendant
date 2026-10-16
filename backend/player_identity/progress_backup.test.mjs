import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {createProgressBackupHandler,DOMAINS,hash,validSnapshot,MAX_BYTES} from './progress_backup.mjs';
import {InvalidIdentity} from '../monetization/cloudflare/src/jwt_verify.mjs';
function fixture(){
 const sqlite=new DatabaseSync(':memory:');sqlite.exec(readFileSync(new URL('./progress_backup_schema.sql',import.meta.url),'utf8'));
 const db={
  withSession:s=>{assert.equal(s,'first-primary');return db;},
  prepare(sql){return {bind(...args){return {
   first:async()=>sqlite.prepare(sql).get(...args)??null,
   run:async()=>({meta:{changes:sqlite.prepare(sql).run(...args).changes}}),
  };}};},
 };
 let clock=1792150000000;
 const handler=createProgressBackupHandler({verify:async(r,_e,options)=>{assert.equal(options.requireGoogle,true);if(!r.headers.get('authorization'))throw new InvalidIdentity();return r.headers.get('authorization');},now:()=>clock});
 const env={JADE_PROGRESS_BACKUP_ENABLED:'true',PROFILE_DB:db};
 const call=(user='A',body,query='')=>handler(new Request('https://profile.test/v1/player/progress-backup'+query,{method:body===undefined?'GET':'POST',headers:{authorization:user,'content-type':'application/json'},body:body===undefined?undefined:typeof body==='string'?body:JSON.stringify(body)}),env);
 return {sqlite,db,env,handler,call,advance:()=>{clock+=61000;}};
}
function snapshot(){
 const domains=Object.fromEntries(DOMAINS.map(id=>[id,{version:1}]));
 Object.assign(domains.achievements,{progress:{},unlocked:[],claimed:[]});
 Object.assign(domains.cultivation_mastery,{choices:{},realm:0,clears:0,best_hits:4,run:{},trial:{}});
 Object.assign(domains.daily_quests,{date_key:'2026-10-16',progress:{},completed:[],claimed:[]});
 Object.assign(domains.equipment,{equipped_item_ids:{},ascension_stars:{},weapon_levels:{}});
 Object.assign(domains.idle_cultivation,{last_claim_unix:1,last_observed_unix:1,lifetime_claim_seconds:0,shard_progress_units:0});
 Object.assign(domains.inventory,{item_counts:{}});
 Object.assign(domains.journey,{selected_chapter_id:1,selected_stage_id:1,active_run_chapter_id:0,active_run_stage_id:0,m7d_run_id:'',unlocked_stage_keys:['1-1'],cleared_stage_keys:[]});
 Object.assign(domains.pavilion,{meditation_date:'',cosmetic_id:'plain',owned_cosmetics:['plain']});
 Object.assign(domains.progression,{spirit_stone:10,vitality_level:0,sword_power_level:0,swift_qi_level:0});
 return {format:1,domains};
}
const command=(revision=0,id='a'.repeat(32))=>({expected_revision:revision,request_id:id,snapshot:snapshot()});
test('new account has no backup; nine domains, equipment levels and mastery round trip',async()=>{
 const f=fixture();assert.equal((await (await f.call()).json()).backup,null);
 const result=await f.call('A',command());assert.equal(result.status,200);assert.equal((await result.json()).revision,1);
 const data=await (await f.call()).json();assert.equal(data.owner_binding,await hash('A'));assert.deepEqual(data.backup.snapshot,snapshot());assert(validSnapshot(data.backup.snapshot));f.sqlite.close();
});
test('account B cannot read A or select A via URL/body',async()=>{
 const f=fixture();await f.call('A',command());assert.equal((await (await f.call('B')).json()).backup,null);
 assert.equal((await f.call('B',undefined,'?owner=A')).status,400);
 assert.equal((await f.call('B',{...command(),owner_binding:await hash('A')})).status,400);f.sqlite.close();
});
test('same request is idempotent; changed request payload cannot be replayed',async()=>{
 const f=fixture();assert.equal((await f.call('A',command())).status,200);assert.equal((await f.call('A',command())).status,200);
 const altered=command();altered.snapshot.domains.progression.spirit_stone=99;assert.equal((await f.call('A',altered)).status,409);
 assert.equal(f.sqlite.prepare('SELECT revision FROM player_progress_backups_v1').get().revision,1);f.sqlite.close();
});
test('two devices use revision CAS, cooldown and retain previous snapshot',async()=>{
 const f=fixture();await f.call('A',command());assert.equal((await f.call('A',command(0,'b'.repeat(32)))).status,409);
 assert.equal((await f.call('A',command(1,'b'.repeat(32)))).status,429);f.advance();
 const next=command(1,'b'.repeat(32));next.snapshot.domains.progression.spirit_stone=20;
 assert.equal((await f.call('A',next)).status,200);
 const row=f.sqlite.prepare('SELECT revision,previous_json FROM player_progress_backups_v1').get();assert.equal(row.revision,2);assert.deepEqual(JSON.parse(row.previous_json),snapshot());
 assert.equal((await f.call('A',command(1,'c'.repeat(32)))).status,409);f.sqlite.close();
});
test('Google identity and feature gate required before storage',async()=>{
 const f=fixture();assert.equal((await f.call('')).status,401);f.env.JADE_PROGRESS_BACKUP_ENABLED='false';assert.equal((await f.call()).status,503);f.sqlite.close();
});
test('rejects missing mastery, newer schema, paid state, active runs and oversized/deep data',async()=>{
 for(const mutate of [s=>delete s.domains.cultivation_mastery,s=>s.domains.inventory.version=2,s=>s.domains.pavilion.paid_wallet={},s=>s.domains.journey.active_run_stage_id=1,s=>s.domains.cultivation_mastery.trial={id:'x'},s=>s.domains.equipment.active_run_loadout_snapshot={},s=>s.domains.pavilion.email='private',s=>s.domains.inventory.item_counts.x=-1]){
  const f=fixture(),data=command();mutate(data.snapshot);assert.equal((await f.call('A',data)).status,400);assert.equal(f.sqlite.prepare('SELECT count(*) AS n FROM player_progress_backups_v1').get().n,0);f.sqlite.close();
 }
 const f=fixture();assert.equal((await f.call('A','x'.repeat(MAX_BYTES+1))).status,400);assert.equal((await f.call('A','{')).status,400);f.sqlite.close();
});
test('snapshot archive creates no paid ledger/wallet tables',async()=>{
 const f=fixture();await f.call('A',command());const names=f.sqlite.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map(x=>x.name);assert.deepEqual(names,['player_progress_backups_v1']);f.sqlite.close();
});
