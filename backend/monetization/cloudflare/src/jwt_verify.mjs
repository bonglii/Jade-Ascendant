/** Verify Firebase Auth and App Check signatures at the Cloudflare edge.
 * Fixed Google JWKS URLs only. No client-supplied keys, issuers or audiences.
 */
const FIREBASE_KEYS = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const APP_CHECK_KEYS = "https://firebaseappcheck.googleapis.com/v1/jwks";
const encoder = new TextEncoder();
const keySets = new Map();

export class InvalidIdentity extends Error {
  constructor() { super("Invalid identity."); this.name = "InvalidIdentity"; }
}

function base64urlBytes(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]+={0,2}$/.test(value)) throw new InvalidIdentity();
  const padded = value.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(padded + "=".repeat((4 - padded.length % 4) % 4));
  return Uint8Array.from(binary, c => c.charCodeAt(0));
}
function decodeJson(value) {
  try { return JSON.parse(new TextDecoder().decode(base64urlBytes(value))); }
  catch { throw new InvalidIdentity(); }
}

async function loadKeys(url, fetcher) {
  const now = Date.now();
  const cached = keySets.get(url);
  if (cached?.expires > now) return cached.keys;
  let response;
  try { response = await fetcher(url, { redirect: "error", signal: AbortSignal.timeout(5000) }); }
  catch { throw new InvalidIdentity(); }
  if (!response.ok) throw new InvalidIdentity();
  let parsed;
  try { parsed = await response.json(); } catch { throw new InvalidIdentity(); }
  if (!Array.isArray(parsed.keys) || parsed.keys.length === 0) throw new InvalidIdentity();
  // Short cache: safe even when Google rotates signing keys.
  keySets.set(url, { keys: parsed.keys, expires: now + 15 * 60 * 1000 });
  return parsed.keys;
}

export async function verifyJwt(token, { jwksUrl, issuer, audience, subject, requireTyp = false, fetcher = fetch, now = Date.now() }) {
  if (typeof token !== "string" || token.length > 8192 || token.length < 50) throw new InvalidIdentity();
  const parts = token.split(".");
  if (parts.length !== 3) throw new InvalidIdentity();
  const header = decodeJson(parts[0]);
  const payload = decodeJson(parts[1]);
  if (!header || typeof header !== "object" || header.alg !== "RS256" || typeof header.kid !== "string" || !header.kid ||
      (requireTyp && header.typ !== "JWT") || !payload || typeof payload !== "object") throw new InvalidIdentity();
  const keys = await loadKeys(jwksUrl, fetcher);
  const jwk = keys.find(k => k.kid === header.kid && k.kty === "RSA" && (!k.alg || k.alg === "RS256") && (!k.use || k.use === "sig"));
  if (!jwk) throw new InvalidIdentity();
  try {
    const publicKey = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
    const verified = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", publicKey, base64urlBytes(parts[2]), encoder.encode(parts[0] + "." + parts[1]));
    if (!verified) throw new InvalidIdentity();
  } catch { throw new InvalidIdentity(); }
  const time = Math.floor(now / 1000);
  if (payload.iss !== issuer ||
      !(typeof audience === "string" && (payload.aud === audience || (Array.isArray(payload.aud) && payload.aud.includes(audience)))) ||
      !Number.isSafeInteger(payload.exp) || payload.exp <= time ||
      !Number.isSafeInteger(payload.iat) || payload.iat > time + 30 ||
      typeof payload.sub !== "string" || !payload.sub ||
      (subject && payload.sub !== subject)) throw new InvalidIdentity();
  return payload;
}

export async function verifyFirebaseHeaders(headers, env, options = {}) {
  const projectId = env.FIREBASE_PROJECT_ID;
  const projectNumber = env.FIREBASE_PROJECT_NUMBER;
  const appId = env.JADE_ANDROID_FIREBASE_APP_ID;
  if (projectId !== "jade-ascendant" || projectNumber !== "350718070767" ||
      appId !== "1:350718070767:android:e5520012a501d2856cf01a") throw new InvalidIdentity();
  const bearer = headers.get("Authorization") || "";
  const match = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(bearer);
  const appToken = headers.get("X-Firebase-AppCheck");
  if (!match || !appToken) throw new InvalidIdentity();
  const opts = options.fetcher ? { fetcher: options.fetcher } : {};
  const user = await verifyJwt(match[1], {
    jwksUrl: FIREBASE_KEYS, issuer: `https://securetoken.google.com/${projectId}`, audience: projectId, ...opts,
  });
  if (!Number.isSafeInteger(user.auth_time) || user.auth_time > Math.floor(Date.now() / 1000) + 30 ||
      !user.firebase || !["google.com", "anonymous"].includes(user.firebase.sign_in_provider)) throw new InvalidIdentity();
  const app = await verifyJwt(appToken, {
    jwksUrl: APP_CHECK_KEYS, issuer: `https://firebaseappcheck.googleapis.com/${projectNumber}`,
    audience: `projects/${projectNumber}`, subject: appId, requireTyp: true, ...opts,
  });
  return { auth: { uid: user.sub, token: { firebase: { sign_in_provider: user.firebase.sign_in_provider } } }, app: { appId: app.sub } };
}
