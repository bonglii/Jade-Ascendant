import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import {
  assertRefundCreditEligibleRC8, makeProtectedCreditUpdateRC8, RefundCreditGateErrorRC8,
} from '../src/wallet_refund_credit_rc8.mjs';

const hash = s => createHash('sha256').update(s).digest('hex');
const ownerKey='u1:'+hash('person-one');
const eventKey='iapv1:'+hash('token-one');
const tokenKey='playtoken:'+hash('token-one');
const now=Date.now();
function setup() {
  const sqlite=new DatabaseSync(':memory:');
  sqlite.exec(`PRAGMA foreign_keys=ON;
    CREATE TABLE iap_wallet_accounts_v1(owner_key TEXT PRIMARY KEY,balance INTEGER NOT NULL DEFAULT 0 CHECK(balance BETWEEN 0 AND 9007199254740991),revision INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE iap_wallet_events_v1(event_key TEXT PRIMARY KEY,owner_key TEXT NOT NULL,event_kind TEXT NOT NULL,item_key TEXT NOT NULL,delta INTEGER NOT NULL);
    CREATE TABLE iap_play_void_events_v1(token_key TEXT PRIMARY KEY,owner_key TEXT);
    CREATE TABLE iap_refund_account_holds_v1(owner_key TEXT PRIMARY KEY,status TEXT NOT NULL CHECK(status IN ('held','released')));
    CREATE TABLE iap_play_void_cursor_v1(cursor_name TEXT PRIMARY KEY,watermark_ms INTEGER NOT NULL);`);
  sqlite.prepare('INSERT INTO iap_wallet_accounts_v1 VALUES (?,0,0)').run(ownerKey);
  const wrap={
    prepare(sql){return {bind(...args){return {
      async first(){return sqlite.prepare(sql).get(...args)??null;},
      run(){return sqlite.prepare(sql).run(...args);},
    };}};},
    withSession(mode){assert.equal(mode,'first-primary');return this;},
    async batch(statements){
      sqlite.exec('BEGIN IMMEDIATE');
      try{let out=statements.map(s=>s.run());sqlite.exec('COMMIT');return out;}
      catch(e){sqlite.exec('ROLLBACK');throw e;}
    },
  };
  const balance=()=>sqlite.prepare('SELECT balance, revision FROM iap_wallet_accounts_v1 WHERE owner_key=?').get(ownerKey);
  const events=()=>sqlite.prepare('SELECT * FROM iap_wallet_events_v1').all();
  const cursor=t=>sqlite.prepare("INSERT OR REPLACE INTO iap_play_void_cursor_v1 VALUES ('voided_inapp',?)").run(t);
  async function credit({race,grant=eventKey,amount=100}={}) {
    await assertRefundCreditEligibleRC8({db:wrap,ownerKey,eventKey:grant,nowMs:now});
    if(race) race();
    return wrap.batch([
      wrap.prepare('INSERT INTO iap_wallet_events_v1 VALUES (?,?,?,?,?)').bind(grant,ownerKey,'play_credit','jade_pouch_100',amount),
      makeProtectedCreditUpdateRC8({db:wrap,ownerKey,eventKey:grant,delta:amount,nowMs:now}),
    ]);
  }
  return {sqlite,wrap,balance,events,cursor,credit};
}

test('fresh refund poll allows atomic verified wallet credit',async()=>{
  const f=setup();try{f.cursor(now-60000);await f.credit();assert.deepEqual({...f.balance()},{balance:100,revision:1});assert.equal(f.events().length,1);}finally{f.sqlite.close();}
});
test('missing refund poll refuses credit, event never written',async()=>{
  const f=setup();try{await assert.rejects(f.credit(),{name:'RefundCreditGateErrorRC8',code:'refund_monitor_stale'});assert.equal(f.events().length,0);}finally{f.sqlite.close();}
});
test('stale refund poll refuses credit',async()=>{
  const f=setup();try{f.cursor(now-2*3600000-1);await assert.rejects(f.credit(),{name:'RefundCreditGateErrorRC8',code:'refund_monitor_stale'});}finally{f.sqlite.close();}
});
test('future-dated/reforged cursor refuses credit',async()=>{
  const f=setup();try{f.cursor(now+61000);await assert.rejects(f.credit(),{name:'RefundCreditGateErrorRC8',code:'refund_monitor_stale'});}finally{f.sqlite.close();}
});
test('already voided grant refuses credit even with fresh cursor',async()=>{
  const f=setup();try{f.cursor(now);f.sqlite.prepare('INSERT INTO iap_play_void_events_v1 VALUES (?,?)').run(tokenKey,ownerKey);await assert.rejects(f.credit(),{name:'RefundCreditGateErrorRC8',code:'refund_or_hold'});}finally{f.sqlite.close();}
});
test('held account refuses credit even with fresh cursor',async()=>{
  const f=setup();try{f.cursor(now);f.sqlite.prepare("INSERT INTO iap_refund_account_holds_v1 VALUES (?,'held')").run(ownerKey);await assert.rejects(f.credit(),{name:'RefundCreditGateErrorRC8',code:'refund_or_hold'});}finally{f.sqlite.close();}
});
test('released hold allows credit only if no void exists',async()=>{
  const f=setup();try{f.cursor(now);f.sqlite.prepare("INSERT INTO iap_refund_account_holds_v1 VALUES (?,'released')").run(ownerKey);await f.credit();assert.equal(f.balance().balance,100);}finally{f.sqlite.close();}
});
test('race: refund record inserted after early check aborts event and credit atomically',async()=>{
  const f=setup();try{f.cursor(now);await assert.rejects(f.credit({race:()=>f.sqlite.prepare('INSERT INTO iap_play_void_events_v1 VALUES (?,?)').run(tokenKey,ownerKey)}));assert.deepEqual({...f.balance()},{balance:0,revision:0});assert.equal(f.events().length,0);}finally{f.sqlite.close();}
});
test('race: account hold inserted after early check aborts event and credit atomically',async()=>{
  const f=setup();try{f.cursor(now);await assert.rejects(f.credit({race:()=>f.sqlite.prepare("INSERT INTO iap_refund_account_holds_v1 VALUES (?,'held')").run(ownerKey)}));assert.deepEqual({...f.balance()},{balance:0,revision:0});assert.equal(f.events().length,0);}finally{f.sqlite.close();}
});
test('race: poll cursor reset/stale after early check aborts event and credit atomically',async()=>{
  const f=setup();try{f.cursor(now);await assert.rejects(f.credit({race:()=>f.cursor(now-86400000)}));assert.deepEqual({...f.balance()},{balance:0,revision:0});assert.equal(f.events().length,0);}finally{f.sqlite.close();}
});
test('invalid ledger-bound grant or owner refuses before SQL',async()=>{
  const f=setup();try{f.cursor(now);await assert.rejects(f.credit({grant:'playtoken:'+hash('token-one')}),{name:'RefundCreditGateErrorRC8',code:'invalid_credit_arguments'});await assert.rejects(assertRefundCreditEligibleRC8({db:f.wrap,ownerKey:'bad',eventKey,nowMs:now}),RefundCreditGateErrorRC8);}finally{f.sqlite.close();}
});
test('missing guard migration fails closed',async()=>{
  const f=setup();try{f.cursor(now);f.sqlite.exec('DROP TABLE iap_play_void_events_v1');await assert.rejects(f.credit(),RefundCreditGateErrorRC8);assert.equal(f.events().length,0);}finally{f.sqlite.close();}
});
test('credit replay SQL uniqueness does not add balance twice',async()=>{
  const f=setup();try{f.cursor(now);await f.credit();await assert.rejects(f.credit());assert.deepEqual({...f.balance()},{balance:100,revision:1});assert.equal(f.events().length,1);}finally{f.sqlite.close();}
});
