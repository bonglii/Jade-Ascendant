/**
 * RC7 STAGING ONLY — Google Play Voided Purchases reconciliation.
 * No HTTP endpoints, no client arguments, no automatic scheduling, no production gates.
 * Caller MUST supply a trusted service-account Play API adapter and D1; NEVER accept
 * client-supplied void events. Transactional per-event hold + audit; bounded replayable poll.
 * Google API range is ~30 days; RTDN and gap monitoring remain release requirements.
 */
import { createHash } from 'node:crypto';

export class VoidedReconciliationErrorRC7 extends Error {
  constructor(code) { super(code); this.name='VoidedReconciliationErrorRC7'; this.code=code; }
}
const fail = code => { throw new VoidedReconciliationErrorRC7(code); };
const UID = /^[A-Za-z0-9_-]{1,128}$/;
const TOKEN = /^[\x21-\x7e]{16,4096}$/;
const TOKEN_KEY = /^playtoken:[a-f0-9]{64}$/;
const ONE_DAY = 86400000;
const MAX_LOOKBACK = 29 * ONE_DAY;
const OVERLAP = 72 * 3600000;
const primary = db => typeof db.withSession === 'function' ? db.withSession('first-primary') : db;
const sha = value => createHash('sha256').update(value,'utf8').digest('hex');
const isInt = n => Number.isSafeInteger(n) && n > 0;
const asPlain = value => value && typeof value === 'object' && !Array.isArray(value);
function requireDb(db) {
  if (!db || typeof db.prepare !== 'function' || typeof db.batch !== 'function') fail('d1_required');
}
function tokenKey(token) {
  if(typeof token!=='string' || !TOKEN.test(token)) fail('invalid_play_void');
  return 'playtoken:'+sha(token);
}
function parseMillis(value) {
  if(typeof value!=='string' || !/^\d{10,17}$/.test(value)) fail('invalid_play_void');
  const ms=Number(value);
  if(!isInt(ms)) fail('invalid_play_void');
  return ms;
}
function validateVoid(item,nowMs) {
  if(!asPlain(item)) fail('invalid_play_void');
  const key=tokenKey(item.purchaseToken);
  const ms=parseMillis(item.voidedTimeMillis);
  if(ms > nowMs + ONE_DAY) fail('invalid_play_void');
  if(!Number.isInteger(item.voidedReason) || item.voidedReason<0 || item.voidedReason>8 ||
      !Number.isInteger(item.voidedSource) || item.voidedSource<0 || item.voidedSource>2 ||
      (item.voidedQuantity!==undefined && item.voidedQuantity!==1)) fail('invalid_play_void');
  return {key,ms,reason:item.voidedReason,source:item.voidedSource};
}
function ownerForRecord(raw,key) {
  if(!raw) return null;
  let record;
  try{record=JSON.parse(raw.record_json);}catch{fail('ledger_corrupted');}
  const uid=record?.ownerUid;
  if(typeof uid!=='string' || !UID.test(uid) || record?.tokenKey!==key ||
      record?.ownerBinding!==sha(uid) || record?.grantId !== 'iapv1:'+key.slice(10) ||
      !['verified_pending_consume','grant_ready'].includes(record?.state)) fail('ledger_corrupted');
  return 'u1:'+sha(uid);
}
async function lookupOwner(db,key) {
  const row=await primary(db).prepare(
    'SELECT record_json FROM iap_purchase_ledger_v1 WHERE token_key=?'
  ).bind(key).first();
  return ownerForRecord(row,key);
}
async function attachVoidedKey({db,key,ms,reason,source}) {
  const owner=await lookupOwner(db,key);
  const existing=await primary(db).prepare(
    'SELECT owner_key FROM iap_play_void_events_v1 WHERE token_key=?'
  ).bind(key).first();
  if(existing?.owner_key && owner && existing.owner_key!==owner) fail('owner_conflict');
  const ops=[];
  if(owner) {
    // Parent wallet account must exist before hold and audit FK inserts.
    ops.push(db.prepare(
      'INSERT OR IGNORE INTO iap_wallet_accounts_v1 (owner_key,balance,revision) VALUES (?,0,0)'
    ).bind(owner));
  }
  ops.push(db.prepare(`INSERT INTO iap_play_void_events_v1
    (token_key,owner_key,voided_time_ms,voided_reason,voided_source) VALUES (?,?,?,?,?)
    ON CONFLICT(token_key) DO UPDATE SET
    owner_key=COALESCE(iap_play_void_events_v1.owner_key,excluded.owner_key)`).bind(key,owner,ms,reason,source));
  if(owner) {
    // Do not auto-release a hold. Replays remain held even after manual release;
    // resolution needs a separate audited manual review path.
    ops.push(db.prepare(`INSERT INTO iap_refund_account_holds_v1
      (owner_key,status,reason,revision) VALUES (?,'held','play_voided_purchase',1)
      ON CONFLICT(owner_key) DO UPDATE SET
        status='held',reason='play_voided_purchase',
        revision=CASE WHEN status='held' THEN revision ELSE revision+1 END,
        updated_at=CURRENT_TIMESTAMP`).bind(owner));
  }
  // Cloudflare D1 batch executes these statements as a single transaction.
  await db.batch(ops);
  return {matched:!!owner};
}

/** Called ONLY with a page item from Google's authenticated voidedpurchases.list. */
export async function recordPlayVoidRC7({db,item,nowMs=Date.now()}) {
  requireDb(db);
  if(!isInt(nowMs)) fail('invalid_clock');
  const row=validateVoid(item,nowMs);
  return attachVoidedKey({db,...row});
}

/** Resolve previously unknown voids when their purchase ledger eventually exists. */
export async function reconcileUnmatchedVoidsRC7({db,max=100}) {
  requireDb(db);
  if(!Number.isInteger(max) || max<1 || max>100) fail('invalid_limit');
  const rows=await primary(db).prepare(
    'SELECT token_key,voided_time_ms,voided_reason,voided_source FROM iap_play_void_events_v1 WHERE owner_key IS NULL LIMIT ?'
  ).bind(max).all();
  if(!Array.isArray(rows?.results)) fail('invalid_d1_reply');
  let matched=0;
  for(const r of rows.results){
    if(typeof r.token_key!=='string'||!TOKEN_KEY.test(r.token_key)) fail('invalid_stored_token_key');
    if((await attachVoidedKey({db,key:r.token_key,ms:r.voided_time_ms,reason:r.voided_reason,source:r.voided_source})).matched) matched++;
  }
  return {reviewed:rows.results.length,matched};
}

/** This must be checked again ATOMICALLY within wallet credit's D1 transaction. */
export function creditNotVoidedSqlRC7() {
  return `NOT EXISTS (SELECT 1 FROM iap_play_void_events_v1 v
    WHERE v.token_key = 'playtoken:' || substr(?,7))
    AND NOT EXISTS (SELECT 1 FROM iap_refund_account_holds_v1 h
    WHERE h.owner_key = ? AND h.status='held')`;
}

/** Cron-invocable function; never wire to public fetch(). */
export async function reconcilePlayVoidsRC7({db,listVoidedPage,nowMs=Date.now(),maxPages=20}) {
  requireDb(db);
  if(typeof listVoidedPage!=='function') fail('trusted_play_gateway_required');
  if(!isInt(nowMs) || !Number.isInteger(maxPages) || maxPages<1 || maxPages>100) fail('invalid_configuration');
  const cursor=await primary(db).prepare(
    "SELECT watermark_ms FROM iap_play_void_cursor_v1 WHERE cursor_name='voided_inapp'"
  ).first();
  if(cursor && (!isInt(cursor.watermark_ms) || cursor.watermark_ms>nowMs || nowMs-cursor.watermark_ms>MAX_LOOKBACK))
    fail('reconciliation_gap');
  const fromMs=cursor ? Math.max(nowMs-MAX_LOOKBACK,cursor.watermark_ms-OVERLAP) : nowMs-MAX_LOOKBACK;
  const endMs=nowMs-60000; // Avoid asking Play for future/just-arriving records.
  if(fromMs>=endMs) fail('window_too_small');
  const visited=new Set();
  let pageToken=null,pages=0,records=0,matched=0,unmatched=0;
  do {
    if(pages>=maxPages) fail('page_limit_reached');
    const reply=await listVoidedPage({startTimeMs:fromMs,endTimeMs:endMs,pageToken});
    if(!asPlain(reply)) fail('invalid_play_page');
    const rows=reply.voidedPurchases===undefined?[]:reply.voidedPurchases;
    if(!Array.isArray(rows)||rows.length>1000) fail('invalid_play_page');
    for(const item of rows){
      const outcome=await recordPlayVoidRC7({db,item,nowMs});
      records++;
      if(outcome.matched) matched++; else unmatched++;
    }
    pages++;
    const next=reply.tokenPagination?.nextPageToken;
    if(next===undefined||next===null||next==='') pageToken=null;
    else {
      if(typeof next!=='string'||next.length>512||!/^[A-Za-z0-9+/_=-]+$/.test(next)||visited.has(next))
        fail('invalid_pagination');
      visited.add(next);pageToken=next;
    }
  }while(pageToken);
  // Only AFTER ALL pages and event writes succeed. On failure prior watermark stays put,
  // and already recorded voids are replay-safe. Requires full 30d backfill on first run.
  await db.batch([db.prepare(`INSERT INTO iap_play_void_cursor_v1
    (cursor_name,watermark_ms,revision) VALUES ('voided_inapp',?,1)
    ON CONFLICT(cursor_name) DO UPDATE SET
      watermark_ms=MAX(watermark_ms,excluded.watermark_ms),
      revision=revision+1,updated_at=CURRENT_TIMESTAMP`).bind(endMs)]);
  return {state:'staged_reconciliation_only',pages,records,matched,unmatched,from_ms:fromMs,through_ms:endMs};
}
