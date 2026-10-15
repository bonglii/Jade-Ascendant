/** Real refund tables and fresh cursor in isolated SQLite tests only. */
import {readFileSync} from 'node:fs';
export function seedRefundPrerequisites(sql){
 for(const name of ['0008_refund_account_holds.sql','0009_play_voided_reconciliation.sql'])
  sql.exec(readFileSync(new URL('../../migrations/'+name,import.meta.url),'utf8'));
 sql.prepare("INSERT OR REPLACE INTO iap_play_void_cursor_v1(cursor_name,watermark_ms) VALUES('voided_inapp',?)").run(Date.now());
}
