/** Android Publisher API with OAuth2 service-account credentials stored ONLY in a Worker secret. */
const encoder = new TextEncoder();
const SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token";
const BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/";
let cached = null;

function b64u(bytes) {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}
function parseSecret(json) {
  let key;
  try { key = JSON.parse(json); } catch { throw new Error("Google Play service credentials missing"); }
  if (key?.type !== "service_account" || typeof key.client_email !== "string" ||
      !key.client_email.endsWith(".gserviceaccount.com") ||
      typeof key.private_key !== "string" || !key.private_key.includes("-----BEGIN PRIVATE KEY-----")) {
    throw new Error("Google Play service credentials invalid");
  }
  return key;
}
async function oauthToken(secret, fetcher) {
  const key = parseSecret(secret);
  if (cached && cached.email === key.client_email && cached.expiry > Date.now() + 90000) return cached.token;
  const raw = key.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  const rawBytes = Uint8Array.from(atob(raw), c => c.charCodeAt(0));
  const privateKey = await crypto.subtle.importKey("pkcs8", rawBytes, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const now = Math.floor(Date.now() / 1000);
  const jwtHeader = b64u(encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const jwtPayload = b64u(encoder.encode(JSON.stringify({ iss: key.client_email, scope: SCOPE, aud: TOKEN_ENDPOINT, iat: now, exp: now + 3500 })));
  const signingInput = `${jwtHeader}.${jwtPayload}`;
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", privateKey, encoder.encode(signingInput));
  const form = new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${signingInput}.${b64u(new Uint8Array(signature))}` });
  const resp = await fetcher(TOKEN_ENDPOINT, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: form, signal: AbortSignal.timeout(10000) });
  if (!resp.ok) throw new Error("Google OAuth service unavailable");
  const data = await resp.json();
  if (typeof data.access_token !== "string" || !Number.isFinite(data.expires_in)) throw new Error("Invalid Google OAuth reply");
  cached = { email: key.client_email, token: data.access_token, expiry: Date.now() + Math.min(3400, data.expires_in) * 1000 };
  return cached.token;
}
async function callPlay(secret, path, method, fetcher) {
  const token = await oauthToken(secret, fetcher);
  const resp = await fetcher(`${BASE}${path}`, {
    method, headers: { Authorization: `Bearer ${token}` },
    signal: AbortSignal.timeout(15000),
  });
  if (!resp.ok) throw new Error("Google Play verification/consumption unavailable");
  if (method === "GET") return resp.json();
}
export function createPlayGateway(serviceAccountJson, fetcher = fetch) {
  if (!serviceAccountJson) throw new Error("Google Play service credentials missing");
  return {
    async getProductPurchaseV2(packageName, purchaseToken) {
      if (packageName !== "com.yungdevstudio.jadeascendant" || typeof purchaseToken !== "string" || !/^[\x21-\x7e]{16,4096}$/.test(purchaseToken)) throw new Error("Invalid Play request");
      return callPlay(serviceAccountJson, `${encodeURIComponent(packageName)}/purchases/productsv2/tokens/${encodeURIComponent(purchaseToken)}`, "GET", fetcher);
    },
    async consumeProduct(packageName, playProductId, purchaseToken) {
      if (packageName !== "com.yungdevstudio.jadeascendant" || !/^jade_pouch_(100|550|1200|2500|6500|14000)$/.test(playProductId) ||
          typeof purchaseToken !== "string" || !/^[\x21-\x7e]{16,4096}$/.test(purchaseToken)) throw new Error("Invalid Play request");
      return callPlay(serviceAccountJson, `${encodeURIComponent(packageName)}/purchases/products/${encodeURIComponent(playProductId)}/tokens/${encodeURIComponent(purchaseToken)}:consume`, "POST", fetcher);
    },
  };
}
