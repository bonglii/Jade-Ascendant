import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync, sign, webcrypto} from 'node:crypto';
import {verifyJwt, InvalidIdentity} from '../src/jwt_verify.mjs';
import {verifyAuth} from '../../../player_identity/auth.mjs';
if (!globalThis.crypto) globalThis.crypto=webcrypto;
const pair=generateKeyPairSync('rsa',{modulusLength:2048});
const key=(kid)=>({...pair.publicKey.export({format:'jwk'}),kid,kty:'RSA',alg:'RS256',use:'sig'});
const now=Math.floor(Date.now()/1000);
function token(kid,claims={}) {
 const a=Buffer.from(JSON.stringify({alg:'RS256',kid,typ:'JWT'})).toString('base64url');
 const b=Buffer.from(JSON.stringify({iss:'issuer',aud:'audience',sub:'player',iat:now-1,exp:now+600,...claims})).toString('base64url');
 return `${a}.${b}.${sign('RSA-SHA256',Buffer.from(`${a}.${b}`),pair.privateKey).toString('base64url')}`;
}
const options=(name,fetcher)=>({jwksUrl:'https://fixture.invalid/'+name,issuer:'issuer',audience:'audience',fetcher});
test('workerd-compatible manual mode denies redirects',async()=>{
 let mode;
 const out=await verifyJwt(token('old'),options('manual',async(u,init)=>{mode=init.redirect;return Response.json({keys:[key('old')]});}));
 assert.equal(mode,'manual');assert.equal(out.sub,'player');
 await assert.rejects(verifyJwt(token('old'),options('redirect',async()=>new Response('',{status:302,headers:{location:'https://other.invalid'}}))),InvalidIdentity);
});
test('cached signing keys refresh immediately for rotation',async()=>{
 let calls=0;const opts=options('rotate',async()=>Response.json({keys:[key(++calls===1?'old':'new')]}));
 await verifyJwt(token('old'),opts);await verifyJwt(token('new'),opts);assert.equal(calls,2);
});
test('unknown kids cannot amplify repeated key refreshes',async()=>{
 let calls=0;const opts=options('bounded',async()=>{calls++;return Response.json({keys:[key('old')]});});
 await verifyJwt(token('old'),opts);
 for(let i=0;i<25;i++)await assert.rejects(verifyJwt(token('attacker'+i),opts),InvalidIdentity);
 assert.equal(calls,2);
});
test('concurrent cold verification coalesces one key lookup',async()=>{
 let calls=0;const opts=options('concurrent',async()=>{calls++;await new Promise(r=>setTimeout(r,10));return Response.json({keys:[key('old')]});});
 await Promise.all(Array.from({length:12},()=>verifyJwt(token('old'),opts)));assert.equal(calls,1);
});
test('real signature forgery fails despite matching claims',async()=>{
 const good=token('old');const parts=good.split('.');const bytes=Buffer.from(parts[2],'base64url');bytes[10]^=255;parts[2]=bytes.toString('base64url');
 await assert.rejects(verifyJwt(parts.join('.'),options('forged',async()=>Response.json({keys:[key('old')]}))),InvalidIdentity);
});
test('malformed or oversized key sets fail closed',async()=>{
 for(const [i,keys] of [[],[null],Array.from({length:33},()=>key('old'))].entries())
  await assert.rejects(verifyJwt(token('old'),options('malformed'+i,async()=>Response.json({keys}))),InvalidIdentity);
});
test('profile auth_time uses the supplied verification clock',async()=>{
 const future=now+86400;
 const jwt=token('profile-clock',{iss:'https://securetoken.google.com/jade-ascendant',aud:'jade-ascendant',iat:future-10,exp:future+600,auth_time:future-15,firebase:{sign_in_provider:'google.com'}});
 const uid=await verifyAuth(new Request('https://fixture.invalid/',{headers:{Authorization:'Bearer '+jwt}}),{FIREBASE_PROJECT_ID:'jade-ascendant'},{now:future*1000,fetcher:async()=>Response.json({keys:[key('profile-clock')]})});
 assert.equal(uid,'player');
});
