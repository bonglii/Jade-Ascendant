/** Isolated Firebase Functions emulator-only SSV intake. NEVER deploy this entrypoint. */
import { createRequire } from 'node:module';
import { createGoogleKeySource } from '../m7e4d_google_keys.mjs';
import { createSsvHttpHandler, isEmulatorOnlyEnabled } from '../m7e4d_http_boundary.mjs';
const require = createRequire(import.meta.url);
const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const getTrustedGoogleKeys = createGoogleKeySource(); // One bounded cache per emulator process.

export const jadeAdSsvEmulator = onRequest({ region: 'us-central1', cors: false, maxInstances: 1 },
  async (req, res) => {
    if (!isEmulatorOnlyEnabled(process.env)) {
      res.status(503).set('Cache-Control', 'no-store').send('EMULATOR_ONLY');
      return;
    }
    if (getApps().length === 0) initializeApp({ projectId: process.env.GCLOUD_PROJECT });
    const handler = createSsvHttpHandler({
      db: getFirestore(),
      getTrustedGoogleKeys,
      enabled: true,
    });
    await handler(req, res);
  }
);
