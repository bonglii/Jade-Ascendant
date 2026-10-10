/** Google Play Android Publisher REST adapter with injected authenticated client.
 * Any transport failure is deliberately sanitized to avoid exposing tokens in
 * Cloud Logging, callable errors, or Google SDK exception messages.
 */
import { PurchaseAuthorityError } from "./purchase_authority.mjs";

const BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/";
const PACKAGE = /^[a-zA-Z][a-zA-Z0-9_.]*$/;
const PRODUCT = /^[a-zA-Z0-9_.-]{1,200}$/;

function cleanPackage(value) {
  if (typeof value !== "string" || !PACKAGE.test(value)) {
    throw new TypeError("Invalid Android application ID");
  }
  return encodeURIComponent(value);
}
function cleanProduct(value) {
  if (typeof value !== "string" || !PRODUCT.test(value)) {
    throw new TypeError("Invalid Google Play product ID");
  }
  return encodeURIComponent(value);
}
function cleanToken(value) {
  if (typeof value !== "string" || !/^[\x21-\x7e]{16,4096}$/.test(value)) {
    throw new PurchaseAuthorityError("invalid-argument", "Invalid purchase token.");
  }
  return encodeURIComponent(value);
}
async function safeRequest(client, params) {
  try {
    return await client.request(params);
  } catch (error) {
    // Only the HTTP status is inspected. Never interpolate URL or SDK error.
    const status = error?.response?.status;
    if (status === 404 || status === 400) {
      throw new PurchaseAuthorityError("failed-precondition", "Google Play purchase is unavailable.");
    }
    throw new PurchaseAuthorityError("unavailable", "Google Play service temporarily unavailable.");
  }
}

export function createGooglePlayGateway(authenticatedGoogleClient) {
  if (!authenticatedGoogleClient || typeof authenticatedGoogleClient.request !== "function") {
    throw new TypeError("An authenticated Google API client is required");
  }
  return {
    async getProductPurchaseV2(packageName, purchaseToken) {
      const url = `${BASE}${cleanPackage(packageName)}/purchases/productsv2/tokens/${cleanToken(purchaseToken)}`;
      const result = await safeRequest(authenticatedGoogleClient, {
        url, method: "GET", timeout: 15000,
      });
      return result.data;
    },
    async consumeProduct(packageName, playProductId, purchaseToken) {
      const url = `${BASE}${cleanPackage(packageName)}/purchases/products/${cleanProduct(playProductId)}/tokens/${cleanToken(purchaseToken)}:consume`;
      await safeRequest(authenticatedGoogleClient, {
        url, method: "POST", data: {}, timeout: 15000,
      });
    },
  };
}
