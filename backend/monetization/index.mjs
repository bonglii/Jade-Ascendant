/**
 * Jade Ascendant payment authority — predeploy candidate.
 * Fail-closed by default: JADE_IAP_BACKEND_ENABLED must be explicitly true.
 * No local key file or production credential is included in this code.
 */
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { GoogleAuth } from "google-auth-library";
import { authorizePurchase, PurchaseAuthorityError } from "./src/purchase_authority.mjs";
import { createFirestoreLedger } from "./src/firestore_ledger.mjs";
import { createGooglePlayGateway } from "./src/google_play_gateway.mjs";

if (getApps().length === 0) initializeApp();
const auth = new GoogleAuth({ scopes: ["https://www.googleapis.com/auth/androidpublisher"] });

export const jadeAuthorizePurchase = onCall({
  region: "asia-southeast2",
  enforceAppCheck: true,
  consumeAppCheckToken: true,
  maxInstances: 10,
  timeoutSeconds: 60,
  memory: "256MiB",
}, async request => {
  // A deploy is not itself authorization to start charging real users.
  if (process.env.JADE_IAP_BACKEND_ENABLED !== "true") {
    throw new HttpsError("failed-precondition", "Purchase authority is not yet enabled.");
  }
  const expectedAppId = process.env.JADE_ANDROID_FIREBASE_APP_ID;
  if (!expectedAppId || request.app?.appId !== expectedAppId) {
    throw new HttpsError("permission-denied", "Application identity mismatch.");
  }

  try {
    const playClient = await auth.getClient();
    return await authorizePurchase({
      request,
      playGateway: createGooglePlayGateway(playClient),
      ledger: createFirestoreLedger(getFirestore()),
    });
  } catch (error) {
    if (error instanceof PurchaseAuthorityError) {
      throw new HttpsError(error.code, error.message);
    }
    // Never log or return raw purchase tokens or Google API exception objects.
    throw new HttpsError("internal", "Purchase authorization failed.");
  }
});
