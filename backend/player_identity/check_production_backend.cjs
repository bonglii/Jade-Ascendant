'use strict';
process.env.JADE_TAIL_DOH='1';
require('./release_doh_route.cjs');
const https=require('node:https');
let finished=false,req;
const timer=setTimeout(()=>{finish('BACKEND_CHECK_TIMEOUT');req?.destroy();},15000);
function finish(error){
 if(finished)return;
 finished=true;clearTimeout(timer);
 if(error){console.error(error);process.exitCode=1;}
 else console.log('PRODUCTION_BACKEND_HEALTH=PASS; CONTRACT=2; RELEASE_ENABLED=true');
}
req=https.get('https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/health',{
 rejectUnauthorized:true,agent:false,headers:{Accept:'application/json'},
},res=>{
 let body='',bytes=0;
 if(res.statusCode!==200){res.resume();finish('BACKEND_HTTP_'+res.statusCode);return;}
 res.on('data',chunk=>{bytes+=chunk.length;if(bytes>8192){finish('BACKEND_RESPONSE_TOO_LARGE');req.destroy();}else body+=chunk;});
 res.on('error',()=>finish('BACKEND_RESPONSE_FAILED'));
 res.on('end',()=>{
  try{const d=JSON.parse(body);if(d.service!=='jade-iap'||d.gameplay_contract!==2||d.release_enabled!==true)throw Error();finish();}
  catch{finish('BACKEND_NOT_ACTIVE_OR_WRONG_CONTRACT');}
 });
});
req.on('error',e=>finish('BACKEND_CONNECTION_FAILED; CODE='+(e.code||'UNKNOWN')));
req.on('close',()=>{if(!finished)finish('BACKEND_CONNECTION_CLOSED');});
