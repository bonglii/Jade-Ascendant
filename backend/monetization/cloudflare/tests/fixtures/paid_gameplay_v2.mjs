import {DatabaseSync} from 'node:sqlite';
import {createHash,randomUUID} from 'node:crypto';
import {readFileSync,readdirSync} from 'node:fs';
import {canonicalDefaultRC12} from '../../src/canonical_onboarding_rc12.mjs';
import {createPaidGameplayV2} from '../../src/paid_gameplay_v2.mjs';
export const UID='paid-player-a',NOW=1_800_000_000_000;
export const owner=uid=>'u1:'+createHash('sha256').update(uid).digest('hex');
export const command=(kind,expected_revision=0,extra={})=>({request_id:randomUUID(),expected_revision,kind,...extra});
export function fixture({funds=2400,rng=(lo)=>lo}={}){
 const sql=new DatabaseSync(':memory:');sql.exec('PRAGMA foreign_keys=ON');
 const dir=new URL('../../migrations/',import.meta.url);
 for(const file of readdirSync(dir).filter(f=>f.endsWith('.sql')).sort())sql.exec(readFileSync(new URL(file,dir),'utf8'));
 sql.prepare("INSERT INTO iap_play_void_cursor_v1(cursor_name,watermark_ms) VALUES('voided_inapp',?)").run(NOW);
 let beforeBatch=null,failBatch=false,tail=Promise.resolve();
 const db={prepare(query){const stmt=(v)=>({
  async first(){return sql.prepare(query).get(...v)??null;},async all(){return{results:sql.prepare(query).all(...v)};},
  run(){return sql.prepare(query).run(...v);},
 });return{...stmt([]),bind(...v){return stmt(v);}};},withSession(){return this;},batch(stmts){
  const work=tail.then(async()=>{if(beforeBatch)await beforeBatch();sql.exec('BEGIN IMMEDIATE');try{
    const out=stmts.map((s,i)=>{if(failBatch&&i===stmts.length-1)throw Error('injected_write_failure');return s.run();});
    sql.exec('COMMIT');return out;
   }catch(e){sql.exec('ROLLBACK');throw e;}});tail=work.catch(()=>{});return work;
 }};
 function seed(uid=UID,balance=funds){
  sql.prepare('INSERT INTO iap_wallet_accounts_v1(owner_key,balance,revision) VALUES(?,?,1)').run(owner(uid),balance);
  sql.prepare("INSERT INTO iap_wallet_events_v1(event_key,owner_key,event_kind,item_key,delta) VALUES(?,?,'play_credit','jade_pouch_100',2400)").run('test-credit:'+uid,owner(uid));
  sql.prepare("INSERT INTO iap_summon_canonical_v1(owner_key,revision,status,state_json) VALUES(?,0,'verified',?)").run(owner(uid),JSON.stringify(canonicalDefaultRC12()));
 }
 seed();const service=createPaidGameplayV2(db,{now:()=>NOW,rng});
 return{sql,db,service,seed,async init(uid=UID){return service.execute(uid,command('initialize'));},
  beforeBatch(fn){beforeBatch=fn;},injectFailure(value){failBatch=value;},close(){sql.close();}};
}
