import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { parseSignedCallback, normalizeTrustedGoogleKeys, verifyGoogleSsv, buildPendingLedgerCandidate, SsvRejection } from '../ssv/m7e4b_ssv_verifier.mjs';

const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const pem = publicKey.export({ type: 'spki', format: 'pem' });
const trustedGoogleKeys = normalizeTrustedGoogleKeys({ keys: [{ keyId: 1234567, pem }] });
const NOW = 1791470000000;
const NONCE = 'sGIUaubwceUlTJPH9eJpM7e4b_Q_B74t';
const basic = {
  ad_network: '12345', ad_unit: '9876543210', custom_data: NONCE,
  reward_amount: '1', reward_item: 'rewarded_grant',
  timestamp: String(NOW), transaction_id: 'abcdef0123456789abcdef0123456789',
};
const config = {trustedGoogleKeys, expectedAdUnit: '9876543210', expectedCustomData: NONCE, expectedRewardAmount: 1, expectedRewardItem: 'rewarded_grant', nowMs: NOW};
const urlEncode = v => encodeURIComponent(v);
function make(parts = basic, opts = {}) {
  const source = opts.raw ?? Object.entries(parts).map(([k, v]) => `${k}=${urlEncode(v)}`).join('&');
  const signature = sign('sha256', Buffer.from(source, 'utf8'), opts.signingKey || privateKey).toString('base64url');
  return `?${source}&signature=${signature}&key_id=${opts.keyId || 1234567}`;
}
function rejectsWith(fn, code) { assert.throws(fn, e => e instanceof SsvRejection && e.code === code); }

test('valid Google-like P256 signed query is cryptographically verified, not rewarded', () => {
  const result = verifyGoogleSsv(make(), config);
  assert.equal(result.verified, true);
  assert.equal(result.transactionId, basic.transaction_id);
  assert.equal(Object.hasOwn(result, 'userId'), false);
  assert.equal(Object.hasOwn(result, 'grant'), false);
});
test('signature verifies EXACT raw original byte order (no canonical query sorting)', () => {
  const raw = Object.entries(basic).reverse().map(([k,v])=>`${k}=${urlEncode(v)}`).join('&');
  assert.equal(verifyGoogleSsv(make(basic,{raw}), config).verified, true);
  const original = make(basic,{raw});
  rejectsWith(() => verifyGoogleSsv(original.replace('ad_unit=9876543210','ad_unit=9876543211'), config), 'SIGNATURE_INVALID');
});
test('tampering signed reward amount is rejected', () => rejectsWith(() => verifyGoogleSsv(make().replace('reward_amount=1','reward_amount=9'), config), 'SIGNATURE_INVALID'));
test('valid signature for wrong ad unit cannot grant', () => rejectsWith(() => verifyGoogleSsv(make({...basic,ad_unit:'00000'}), config), 'INTENT_BINDING_MISMATCH'));
test('valid signature for other nonce cannot grant', () => rejectsWith(() => verifyGoogleSsv(make({...basic,custom_data:'another_nonce'}), config), 'INTENT_BINDING_MISMATCH'));
test('valid signature for wrong reward item cannot grant', () => rejectsWith(() => verifyGoogleSsv(make({...basic,reward_item:'gems'}), config), 'INTENT_BINDING_MISMATCH'));
test('valid signature for wrong amount cannot grant', () => rejectsWith(() => verifyGoogleSsv(make({...basic,reward_amount:'2'}), config), 'INTENT_BINDING_MISMATCH'));
test('signature value and key_id must be the final two parameters', () => rejectsWith(() => parseSignedCallback(make() + '&foo=bar'), 'SIGNATURE_TAIL_INVALID'));
test('duplicate signed keys are forbidden even with signed payload', () => rejectsWith(() => verifyGoogleSsv(make(basic,{raw:`${Object.entries(basic).map(([k,v])=>`${k}=${urlEncode(v)}`).join('&')}&reward_amount=1`}), config), 'DUPLICATE_PARAMETER'));
test('unknown signed parameter is forbidden', () => rejectsWith(() => verifyGoogleSsv(make({...basic,evil:'extra'}), config), 'UNKNOWN_PARAMETER'));
test('missing required parameter is rejected', () => {const p={...basic};delete p.transaction_id;rejectsWith(() => verifyGoogleSsv(make(p), config), 'MISSING_PARAMETER');});
test('unknown key_id rejected even when signature bytes otherwise correct', () => rejectsWith(() => verifyGoogleSsv(make(basic,{keyId:3333333}), config), 'UNTRUSTED_KEY_ID'));
test('valid signature by wrong signing key rejected', () => {const other=generateKeyPairSync('ec',{namedCurve:'prime256v1'}).privateKey;rejectsWith(() => verifyGoogleSsv(make(basic,{signingKey:other}), config), 'SIGNATURE_INVALID');});
test('corrupt signature encoding rejected', () => rejectsWith(() => parseSignedCallback(make().replace(/signature=[^&]+/, 'signature=!!!')), 'SIGNATURE_TAIL_INVALID'));
test('non P256 trusted key rejected', () => {const r=generateKeyPairSync('rsa',{modulusLength:2048}).publicKey.export({type:'spki',format:'pem'});rejectsWith(() => normalizeTrustedGoogleKeys({keys:[{keyId:12345,pem:r}]}), 'KEYSET_INVALID');});
test('duplicate trusted key IDs rejected', () => rejectsWith(() => normalizeTrustedGoogleKeys({keys:[{keyId:12345,pem},{keyId:12345,pem}]}), 'KEYSET_INVALID'));
test('expired callback rejected (do not replay delayed arbitrarily)', () => rejectsWith(() => verifyGoogleSsv(make({...basic,timestamp:String(NOW-86400000-1000)}), config), 'TIMESTAMP_OUT_OF_WINDOW'));
test('future callback rejected', () => rejectsWith(() => verifyGoogleSsv(make({...basic,timestamp:String(NOW+900000)}), config), 'TIMESTAMP_OUT_OF_WINDOW'));
test('Google sample microsecond-ish timestamp normalized as milliseconds', () => {const r=verifyGoogleSsv(make({...basic,timestamp:String(NOW*1000)}),config);assert.equal(r.timestampMs,NOW);});
test('non hex transaction id rejected despite valid signature', () => rejectsWith(() => verifyGoogleSsv(make({...basic,transaction_id:'a-abc'}), config), 'TRANSACTION_ID_INVALID'));
test('server intent is required before building candidate (no client-chosen account)', () => rejectsWith(() => buildPendingLedgerCandidate(verifyGoogleSsv(make(), config), {intentId:'i',userId:'u',nonce:'wrong',placement:'dao_choice_reroll',adUnit:'9876543210',rewardAmount:1,rewardItem:'rewarded_grant'}), 'PENDING_INTENT_MISMATCH'));
test('ledger candidate includes only trusted server identity and does not mutate economy', () => {const v=verifyGoogleSsv(make({...basic,user_id:'attacker'}),config);const c=buildPendingLedgerCandidate(v,{intentId:'intent_1',userId:'legitimate_player',placement:'dao_choice_reroll',nonce:NONCE,adUnit:'9876543210',rewardAmount:1,rewardItem:'rewarded_grant'});assert.equal(c.userId,'legitimate_player');assert.equal(c.state,'VERIFIED_PENDING_ATOMIC_LEDGER');assert.equal(Object.hasOwn(c,'grant'),false);});
test('missing server-side offer config fails closed', () => rejectsWith(() => verifyGoogleSsv(make(),{trustedGoogleKeys}), 'SERVER_CONFIGURATION_INVALID'));

test('forged plain object cannot enter authoritative pending-ledger handoff', () => {const forged={verified:true,transactionId:basic.transaction_id,adUnit:basic.ad_unit,customData:NONCE,rewardAmount:1,rewardItem:'rewarded_grant',timestampMs:NOW}; rejectsWith(() => buildPendingLedgerCandidate(forged,{intentId:'intent_1',userId:'legit',placement:'dao_choice_reroll',nonce:NONCE,adUnit:basic.ad_unit,rewardAmount:1,rewardItem:'rewarded_grant'}),'PENDING_INTENT_MISMATCH');});
