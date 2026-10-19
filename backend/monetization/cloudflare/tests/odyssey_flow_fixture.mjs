import {DatabaseSync} from 'node:sqlite';import {readFileSync} from 'node:fs';import {TOPUP_BONUSES,reconcileTopupBonus} from '../src/odyssey_purchase_bonus.mjs';import {account} from '../src/odyssey_service.mjs';import {REWARDS} from '../src/odyssey_rules.mjs';
export const owner=account('alice'),other=account('bob'),time=1800000000;
export const event={id:'dragon-test',enabled:true,purchases_enabled:true,starts_at:time-100,ends_at:time-100+14*86400,rewards:REWARDS};
export function fixture(){
 const raw=new DatabaseSync(':memory:');raw.exec(`PRAGMA foreign_keys=ON;
 CREATE TABLE iap_wallet_events_v1(event_key TEXT PRIMARY KEY,owner_key TEXT,event_kind TEXT,item_key TEXT,delta INTEGER,created_at TEXT);
 CREATE TABLE iap_play_void_events_v1(token_key TEXT PRIMARY KEY);
 CREATE TABLE iap_refund_account_holds_v1(owner_key TEXT,status TEXT);
 CREATE TABLE iap_play_void_cursor_v1(cursor_name TEXT,watermark_ms INTEGER);
 `);
 for(const migration of ['0013_odyssey.sql','0015_odyssey_topup_bonus.sql'])raw.exec(readFileSync(new URL('../migrations/'+migration,import.meta.url),'utf8'));
 raw.prepare('UPDATE odyssey_bonus_config SET activated_at=?').run(time-50);
 raw.prepare('INSERT INTO odyssey_events VALUES(?,?,?)').run(event.id,JSON.stringify(event),time-100);
 raw.prepare('INSERT INTO iap_play_void_cursor_v1 VALUES(?,?)').run('voided_inapp',time*1000);
 let seq=0,hook=null;
 const db={prepare(sql){let args=[];return{bind(...values){args=values;return this;},async first(){return raw.prepare(sql).get(...args)||null;},async all(){return{results:raw.prepare(sql).all(...args)};},async run(){return raw.prepare(sql).run(...args);},sql,get args(){return args;}};},async batch(steps){if(hook){const h=hook;hook=null;h();}raw.exec('BEGIN');try{const out=steps.map(s=>raw.prepare(s.sql).run(...s.args));raw.exec('COMMIT');return out;}catch(e){raw.exec('ROLLBACK');throw e;}}};
 function credit(pack=0,opts={}){const tier=TOPUP_BONUSES[pack],key='iapv1:'+(++seq).toString(16).padStart(64,'0');raw.prepare("INSERT INTO iap_wallet_events_v1 VALUES(?,?,?,?,?,datetime(?,'unixepoch'))").run(key,'u1:'+(opts.owner||owner),opts.kind||'play_credit',opts.product||tier.product_id,opts.delta??tier.jade,opts.at??time-1);if(opts.voided)raw.prepare('INSERT INTO iap_play_void_events_v1 VALUES(?)').run('playtoken:'+key.slice(6));return key;}
 const eligible=async()=>{if(raw.prepare("SELECT 1 FROM iap_refund_account_holds_v1 WHERE owner_key=? AND status='held'").get('u1:'+owner))throw Error('held');const cursor=raw.prepare('SELECT watermark_ms FROM iap_play_void_cursor_v1').get();if(cursor.watermark_ms<time*1000-7200000)throw Error('stale');};
 return{db,raw,credit,eligible,run:()=>reconcileTopupBonus(db,event,owner,time,eligible),state:()=>{const row=raw.prepare('SELECT state FROM odyssey_players WHERE owner=?').get(owner);return row?JSON.parse(row.state):null;},claims:()=>raw.prepare('SELECT COUNT(*) AS n FROM odyssey_purchase_bonuses').get().n,hook:h=>hook=h};
}
