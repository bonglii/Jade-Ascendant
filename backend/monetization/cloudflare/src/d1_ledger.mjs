/** D1 ledger with optimistic compare-and-swap, primary-consistent reads.
 * SQL contains no purchase token. JSON contains SHA256 fingerprints only.
 */
const KEY = /^playtoken:[a-f0-9]{64}$/;
const MAX_ATTEMPTS = 10;

export function createD1Ledger(d1) {
  if (!d1 || typeof d1.prepare !== "function") throw new TypeError("D1 binding required");
  const db = typeof d1.withSession === "function" ? d1.withSession("first-primary") : d1;
  return {
    async runTransaction(key, callback) {
      if (typeof key !== "string" || !KEY.test(key) || typeof callback !== "function") throw new TypeError("Invalid ledger call");
      for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
        const current = await db.prepare("SELECT record_json, revision FROM iap_purchase_ledger_v1 WHERE token_key = ?")
          .bind(key).first();
        const data = current ? JSON.parse(current.record_json) : null;
        const decision = await callback(data);
        if (!decision || typeof decision !== "object" || Array.isArray(decision)) throw new TypeError("Bad transaction decision");
        if (!Object.hasOwn(decision, "nextRecord")) return decision.result;
        const next = decision.nextRecord;
        if (!next || typeof next !== "object" || Array.isArray(next) || next.tokenKey !== key) throw new TypeError("Bad ledger record");
        const serialized = JSON.stringify(next);
        const saved = current
          ? await db.prepare("UPDATE iap_purchase_ledger_v1 SET record_json = ?, revision = revision + 1 WHERE token_key = ? AND revision = ?")
              .bind(serialized, key, current.revision).run()
          : await db.prepare("INSERT OR IGNORE INTO iap_purchase_ledger_v1 (token_key, record_json, revision) VALUES (?, ?, 1)")
              .bind(key, serialized).run();
        if (saved.meta?.changes === 1) return decision.result;
        // A concurrent request won this revision. Re-read and revalidate via callback.
      }
      throw new Error("Ledger contention; retry request");
    },
  };
}
