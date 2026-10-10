/** M7E4D: pinned Google AdMob verifier key endpoint. No client key injection. */
import { normalizeTrustedGoogleKeys } from './m7e4b_ssv_verifier.mjs';

export const GOOGLE_ADMOB_VERIFIER_URL = 'https://www.gstatic.com/admob/reward/verifier-keys.json';
const MAX_KEY_BYTES = 256 * 1024;
const MAX_CACHE_MS = 24 * 60 * 60 * 1000;

/** Fetch and cache trusted verifier keys. Fail closed when unavailable/expired. */
export function createGoogleKeySource({ fetchImpl = globalThis.fetch, now = Date.now, ttlMs = 12 * 60 * 60 * 1000 } = {}) {
  if (typeof fetchImpl !== 'function' || typeof now !== 'function' ||
      !Number.isSafeInteger(ttlMs) || ttlMs <= 0 || ttlMs > MAX_CACHE_MS) {
    throw new Error('KEY_SOURCE_CONFIG_INVALID');
  }
  let cached = null;
  let expires = 0;
  let inFlight = null;
  return async function getTrustedGoogleKeys() {
    const stamp = now();
    if (!Number.isSafeInteger(stamp) || stamp < 0) throw new Error('KEY_SOURCE_CLOCK_INVALID');
    if (cached && stamp < expires) return cached;
    if (inFlight) return inFlight;
    inFlight = (async () => {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 5000);
      try {
        const response = await fetchImpl(GOOGLE_ADMOB_VERIFIER_URL, {
          method: 'GET', redirect: 'error', signal: controller.signal,
          headers: { accept: 'application/json' },
        });
        if (!response || !response.ok || response.status !== 200) throw new Error('GOOGLE_KEYS_HTTP_FAILURE');
        const length = Number(response.headers?.get?.('content-length') ?? 0);
        if (!Number.isFinite(length) || length < 0 || length > MAX_KEY_BYTES) throw new Error('GOOGLE_KEYS_TOO_LARGE');
        // Bound actual payload regardless of Content-Length.
        const body = await response.text();
        if (Buffer.byteLength(body, 'utf8') > MAX_KEY_BYTES) throw new Error('GOOGLE_KEYS_TOO_LARGE');
        let payload;
        try { payload = JSON.parse(body); } catch { throw new Error('GOOGLE_KEYS_JSON_INVALID'); }
        const parsed = normalizeTrustedGoogleKeys(payload);
        cached = parsed;
        expires = now() + ttlMs;
        return cached;
      } finally { clearTimeout(timeout); }
    })();
    try { return await inFlight; } finally { inFlight = null; }
  };
}
