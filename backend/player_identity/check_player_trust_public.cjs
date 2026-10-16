'use strict';
process.env.JADE_TAIL_DOH='1';require('./release_doh_route.cjs');
const https=require('node:https');
function check(path){return new Promise((resolve,reject)=>{
 let ended=false,bytes=0,body='';
 const done=error=>{if(ended)return;ended=true;clearTimeout(timer);if(error)reject(Error(error));else resolve(path);};
 const request=https.get('https://jade-ascendant-player.jade-ascendant-studio.workers.dev'+path,{agent:false,rejectUnauthorized:true,headers:{Accept:'text/html'}},response=>{
  if(response.statusCode!==200||response.headers['x-jade-trust-version']!=='1'||!String(response.headers['content-type']).includes('text/html')){response.resume();done('PUBLIC_TRUST_WRONG_HTTP_OR_VERSION');return;}
  response.on('data',chunk=>{bytes+=chunk.length;if(bytes>65536){done('PUBLIC_TRUST_TOO_LARGE');request.destroy();}else body+=chunk;});
  response.on('error',()=>done('PUBLIC_TRUST_RESPONSE_FAILED'));
  response.on('end',()=>done(!body.includes('Jade Ascendant')||!body.includes('Yung Dev Studio')||!body.includes('yungdevstudio@gmail.com')||/\<(script|iframe)\b/i.test(body)?'PUBLIC_TRUST_CONTENT_MISMATCH':null));
 });
 const timer=setTimeout(()=>{done('PUBLIC_TRUST_TIMEOUT');request.destroy();},15000);
 request.on('error',()=>done('PUBLIC_TRUST_CONNECTION_FAILED'));
 request.on('close',()=>{if(!ended)done('PUBLIC_TRUST_CONNECTION_CLOSED');});
});}
(async()=>{try{for(const path of ['/privacy-policy.html','/account-deletion.html'])console.log('PUBLIC_TRUST_HTTP=PASS; PATH='+await check(path));}catch(error){console.error(error.message);process.exitCode=1;}})();
