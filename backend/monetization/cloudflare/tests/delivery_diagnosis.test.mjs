import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
const query=readFileSync(new URL('../delivery_diagnose.sql',import.meta.url),'utf8');
const owner='a'.repeat(64),other='b'.repeat(64);
function fixture(){
 const db=new DatabaseSync(':memory:');
 db.exec(`CREATE TABLE iap_purchase_ledger_v1(token_key TEXT PRIMARY KEY,record_json TEXT);
 CREATE TABLE iap_wallet_accounts_v1(owner_key TEXT PRIMARY KEY,balance INTEGER,revision INTEGER);
 CREATE TABLE iap_wallet_events_v1(event_key TEXT PRIMARY KEY,owner_key TEXT,event_kind TEXT);
 CREATE TABLE iap_play_void_events_v1(token_key TEXT PRIMARY KEY);
 CREATE TABLE iap_refund_account_holds_v1(owner_key TEXT PRIMARY KEY,status TEXT);
 CREATE TABLE iap_play_void_cursor_v1(cursor_name TEXT PRIMARY KEY,watermark_ms INTEGER);`);
 return {db,add(binding=owner,id='one'){db.prepare('INSERT INTO iap_purchase_ledger_v1 VALUES (?,?)').run(id,JSON.stringify({ownerBinding:binding,grantId:'iapv1:'+id,state:'grant_ready',ownerUid:'must-never-export'}));},rows(){return db.prepare(query).all().map(x=>({...x}));}};
}
test('actual SQL identifies verified-but-not-credited without leaking token or UID',()=>{
 const f=fixture();try{f.add();const r=f.rows()[0];assert.equal(r.verified_not_credited,1);assert.equal(r.wallet_exists,0);assert.equal(r.refund_monitor,'missing');assert.equal(r.account_ref,owner.slice(0,12));assert.equal(JSON.stringify(r).includes('must-never-export'),false);assert.equal(Object.keys(r).includes('token_key'),false);}finally{f.db.close();}
});
test('credits, voids, holds and another account are independently reported',()=>{
 const f=fixture();try{f.add();f.add(other,'two');f.db.prepare('INSERT INTO iap_wallet_accounts_v1 VALUES (?,?,?)').run('u1:'+owner,100,1);f.db.prepare('INSERT INTO iap_wallet_events_v1 VALUES (?,?,?)').run('iapv1:one','u1:'+owner,'play_credit');f.db.prepare('INSERT INTO iap_play_void_events_v1 VALUES (?)').run('one');f.db.prepare('INSERT INTO iap_refund_account_holds_v1 VALUES (?,?)').run('u1:'+owner,'held');f.db.prepare('INSERT INTO iap_play_void_cursor_v1 VALUES (?,?)').run('voided_inapp',Date.now());const rows=f.rows();assert.equal(rows.length,2);assert.equal(rows[0].verified_not_credited,0);assert.equal(rows[0].credited_purchases,1);assert.equal(rows[0].account_held,1);assert.equal(rows[0].voided_purchases,1);assert.equal(rows[0].refund_monitor,'fresh');assert.equal(rows[1].verified_not_credited,1);assert.equal(rows[1].account_held,0);}finally{f.db.close();}
});
test('stale refund monitor and malformed ledger do not appear healthy',()=>{
 const f=fixture();try{f.add();f.db.prepare('INSERT INTO iap_purchase_ledger_v1 VALUES (?,?)').run('malformed','not json');f.db.prepare('INSERT INTO iap_play_void_cursor_v1 VALUES (?,?)').run('voided_inapp',Date.now()-10800000);assert.equal(f.rows()[0].refund_monitor,'stale');}finally{f.db.close();}
});
test('diagnosis executes only reads and preserves all table contents',()=>{
 const f=fixture();try{f.add();const before=f.db.prepare('SELECT record_json FROM iap_purchase_ledger_v1').get();f.rows();f.rows();assert.deepEqual(f.db.prepare('SELECT record_json FROM iap_purchase_ledger_v1').get(),before);assert.equal(f.db.prepare('SELECT count(*) AS n FROM iap_wallet_events_v1').get().n,0);}finally{f.db.close();}
});
