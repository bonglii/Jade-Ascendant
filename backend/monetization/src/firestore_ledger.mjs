/**
 * Firestore transactional adapter for the purchase-authority contract.
 * Document IDs are deterministic SHA-256 token fingerprints from the core.
 * No raw purchase token is written to Firestore.
 */
export const PURCHASE_LEDGER_COLLECTION = "iap_purchase_ledger_v1";

export function createFirestoreLedger(db) {
  if (!db || typeof db.collection !== "function" || typeof db.runTransaction !== "function") {
    throw new TypeError("Firestore database with transactions is required");
  }
  const collection = db.collection(PURCHASE_LEDGER_COLLECTION);
  return {
    async runTransaction(key, callback) {
      if (typeof key !== "string" || !/^playtoken:[a-f0-9]{64}$/.test(key)) {
        throw new TypeError("Invalid purchase ledger key");
      }
      if (typeof callback !== "function") {
        throw new TypeError("Ledger callback must be a function");
      }
      const docRef = collection.doc(key);
      return db.runTransaction(async transaction => {
        const snapshot = await transaction.get(docRef);
        const current = snapshot.exists ? snapshot.data() : null;
        const decision = await callback(current);
        if (!decision || typeof decision !== "object" || Array.isArray(decision)) {
          throw new TypeError("Ledger callback returned an invalid decision");
        }
        if (Object.hasOwn(decision, "nextRecord")) {
          if (!decision.nextRecord || typeof decision.nextRecord !== "object" || Array.isArray(decision.nextRecord)) {
            throw new TypeError("Invalid ledger record");
          }
          transaction.set(docRef, decision.nextRecord);
        }
        return decision.result;
      });
    },
  };
}
