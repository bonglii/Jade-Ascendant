import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { InvalidIdentity, verifyJwt, verifyFirebaseHeaders } from '../src/jwt_verify.mjs';
const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwk = { ...publicKey.export({ format: 'jwk' }), kid: 'qa-key', use: 'sig', alg: 'RS256' };
const jwksFetch = async () => new Response(JSON.stringify({ keys: [jwk] }), { status: 200 });
const b64u = bytes => Buffer.from(bytes).toString('base64url');
const encode = x => b64u(JSON.stringify(x));
function jwt(payload, header = { alg: 'RS256', kid: 'qa-key', typ: 'JWT' }) {
  const parts = `${encode(header)}.${encode(payload)}`;
  return `${parts}.${b64u(sign('RSA-SHA256', Buffer.from(parts), privateKey))}`;
}
const now = Math.floor(Date.now()/1000);
const project = 'jade-ascendant';
const num = '350718070767';
const appId = '1:350718070767:android:e5520012a501d2856cf01a';
const userClaims = { iss: `https://securetoken.google.com/${project}`, aud: project, sub: 'test_123', iat: now-20, exp: now+1800, auth_time: now-100, firebase: { sign_in_provider: 'google.com' } };
const appClaims = { iss: `https://firebaseappcheck.googleapis.com/${num}`, aud: [`projects/${num}`], sub: appId, iat: now-10, exp: now+1800 };
const env = { FIREBASE_PROJECT_ID: project, FIREBASE_PROJECT_NUMBER: num, JADE_ANDROID_FIREBASE_APP_ID: appId };
function headers(user = jwt(userClaims), app = jwt(appClaims)) { return new Headers({ Authorization: `Bearer ${user}`, 'X-Firebase-AppCheck': app }); }

test('Firebase Auth and App Check valid signed JWTs identify UID/app', async () => {
  const out = await verifyFirebaseHeaders(headers(), env, { fetcher: jwksFetch });
  assert.equal(out.auth.uid, 'test_123');
  assert.equal(out.app.appId, appId);
});
test('Firebase JWT forgery, wrong audience, wrong App Check subject fail closed', async () => {
  const forged = jwt(userClaims).slice(0, -2) + 'AA';
  await assert.rejects(verifyFirebaseHeaders(headers(forged), env, { fetcher: jwksFetch }), InvalidIdentity);
  await assert.rejects(verifyFirebaseHeaders(headers(jwt({ ...userClaims, aud: 'other-project' })), env, { fetcher: jwksFetch }), InvalidIdentity);
  await assert.rejects(verifyFirebaseHeaders(headers(jwt(userClaims), jwt({ ...appClaims, sub: 'different_app' })), env, { fetcher: jwksFetch }), InvalidIdentity);
});
test('expired, wrong signature algorithm, missing App Check fail closed', async () => {
  await assert.rejects(verifyFirebaseHeaders(headers(jwt({ ...userClaims, exp: now-1 })), env, { fetcher: jwksFetch }), InvalidIdentity);
  await assert.rejects(verifyFirebaseHeaders(headers(jwt(userClaims, { alg: 'none', kid: 'qa-key', typ: 'JWT' })), env, { fetcher: jwksFetch }), InvalidIdentity);
  const h = headers(); h.delete('X-Firebase-AppCheck');
  await assert.rejects(verifyFirebaseHeaders(h, env, { fetcher: jwksFetch }), InvalidIdentity);
});
test('App Check token must have JWT typ and exact project number', async () => {
  await assert.rejects(verifyFirebaseHeaders(headers(jwt(userClaims), jwt(appClaims, { alg:'RS256', kid: 'qa-key' })), env, { fetcher: jwksFetch }), InvalidIdentity);
  await assert.rejects(verifyFirebaseHeaders(headers(), { ...env, FIREBASE_PROJECT_NUMBER:'111' }, { fetcher: jwksFetch }), InvalidIdentity);
});
