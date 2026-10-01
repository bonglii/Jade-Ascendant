/** Isolated, unit-testable Firebase Functions v2 adapter. No admin SDK here. */
import {
  CloudBoundaryError,
  readCloudSaveCapabilities,
} from "./read_only_policy.mjs";

export function createCallableHandlers({ onCall, HttpsError }) {
  if (typeof onCall !== "function" || typeof HttpsError !== "function") {
    throw new TypeError("A real Firebase callable runtime is required.");
  }

  const jadeCloudSaveCapabilities = onCall({
    region: "asia-southeast2",
    enforceAppCheck: true,
    maxInstances: 1,
    memory: "256MiB",
    timeoutSeconds: 10,
  }, request => {
    try {
      return readCloudSaveCapabilities(request);
    } catch (error) {
      if (error instanceof CloudBoundaryError) {
        throw new HttpsError(error.code, error.message);
      }
      // Do not leak internal details, raw tokens or player information.
      throw new HttpsError("internal", "Cloud status unavailable.");
    }
  });

  // NO upload, restore, purchase grant, revision allocation, or ledger route.
  return Object.freeze({ jadeCloudSaveCapabilities });
}
