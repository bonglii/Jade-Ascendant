import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync,sign} from 'node:crypto';
import {verifyFirebaseHeaders} from '../src/jwt_verify.mjs';
const pair=generateKeyPairSync('rsa',{modulusLength:2048});
const jwk={...pair.publicKey.export({format:'jwk'}),kid:'receiver-regression',alg:'RS256',use:'sig'};
const now=Math.floor(Date.now()/1000);
function jwt(claims){const parts=[{alg:'RS256',kid:jwk.kid,typ:'JWT'},claims].map(x=>Buffer.from(JSON.stringify(x)).toString('base64url')).join('.');return parts+'.'+sign('RSA-SHA256',Buffer.from(parts),pair.privateKey).toString('base64url');}
test('default Firebase Auth and App Check key fetch preserves the workerd global receiver',async()=>{
 const original=globalThis.fetch;const calls=[];
 globalThis.fetch=async function(url,init){
  if(this!==globalThis)throw new TypeError('Illegal invocation');
  calls.push(url);assert.equal(init.redirect,'manual');
  assert.equal(init.headers,undefined);assert.equal(init.body,undefined);
  return Response.json({keys:[jwk]});
 };
 try{
  const env={FIREBASE_PROJECT_ID:'jade-ascendant',FIREBASE_PROJECT_NUMBER:'350718070767',JADE_ANDROID_FIREBASE_APP_ID:'1:350718070767:android:e5520012a501d2856cf01a'};
  const common={iat:now-10,exp:now+600};
  const auth=jwt({...common,iss:'https://securetoken.google.com/jade-ascendant',aud:'jade-ascendant',sub:'receiver-test-uid',auth_time:now-15,firebase:{sign_in_provider:'google.com'}});
  const app=jwt({...common,iss:'https://firebaseappcheck.googleapis.com/350718070767',aud:['projects/350718070767'],sub:env.JADE_ANDROID_FIREBASE_APP_ID});
  const result=await verifyFirebaseHeaders(new Headers({Authorization:'Bearer '+auth,'X-Firebase-AppCheck':app}),env);
  assert.equal(result.auth.uid,'receiver-test-uid');assert.equal(result.app.appId,env.JADE_ANDROID_FIREBASE_APP_ID);
  assert.equal(calls.length,2);assert.ok(calls.every(url=>url.startsWith('https://')));
 }finally{globalThis.fetch=original;}
});
