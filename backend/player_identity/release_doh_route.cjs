'use strict';
// Preload only in this diagnostic process. TLS, SNI, HTTP and credentials are untouched.
const dns = require('node:dns');
const https = require('node:https');
const net = require('node:net');
function workersHost(host) {
 return typeof host === 'string' && host.length <= 253 && host.toLowerCase().replace(/\.$/,'').endsWith('.workers.dev') &&
  host.replace(/\.$/,'').split('.').every(label=>/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/i.test(label));
}
function publicIPv4(ip) {
 if(net.isIP(ip)!==4)return false;
 const [a,b,c]=ip.split('.').map(Number);
 return !(a===0||a===10||a===127||a>=224||a===100&&b>=64&&b<=127||a===169&&b===254||a===172&&b>=16&&b<=31||a===192&&(b===168||b===0||b===2)||a===198&&(b===18||b===19||b===51&&c===100)||a===203&&b===0&&c===113);
}
const PROVIDERS=[{host:'cloudflare-dns.com',ip:'1.1.1.1',path:'/dns-query',name:'primary'},{host:'dns.google',ip:'8.8.8.8',path:'/resolve',name:'secondary'}];
function query(provider,host,request=https.request) {
 return new Promise((resolve,reject)=>{
  let settled=false,req,timer;
  const done=(err,value)=>{if(settled)return;settled=true;clearTimeout(timer);err?reject(new Error('encrypted_dns_failed')):resolve(value);};
  timer=setTimeout(()=>{done(new Error());req?.destroy();},4000);
  const lookup=(_host,options,callback)=>{if(typeof options==='function'){callback=options;options={};}callback(null,options?.all?[{address:provider.ip,family:4}]:provider.ip,4);};
  try{
   req=request({hostname:provider.host,servername:provider.host,port:443,method:'GET',path:provider.path+'?name='+encodeURIComponent(host)+'&type=A',headers:{Accept:'application/dns-json'},lookup,agent:false,rejectUnauthorized:true},res=>{
    if(res.statusCode!==200){res.resume();done(new Error());return;}
    const chunks=[];let size=0;
    res.on('data',chunk=>{if(settled)return;size+=chunk.length;if(size>16384){done(new Error());req.destroy();return;}chunks.push(chunk);});
    res.on('error',()=>done(new Error()));
    res.on('end',()=>{
     if(settled)return;
     try{
      const body=JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if(body.Status!==0||!Array.isArray(body.Answer)||body.Answer.length>32)throw new Error();
      const addresses=[...new Set(body.Answer.filter(x=>x?.type===1&&publicIPv4(x.data)).map(x=>x.data))].slice(0,4);
      if(!addresses.length)throw new Error();done(null,addresses);
     }catch{done(new Error());}
    });
   });req.on('error',()=>done(new Error()));req.end();
  }catch{done(new Error());}
 });
}
function resolver({queryFn=query,log=()=>{},clock=Date.now}={}) {
 const cache=new Map(),pending=new Map();
 return async host=>{
  host=host.toLowerCase().replace(/\.$/,'');
  if(!workersHost(host))throw new Error('unapproved_dns_host');
  if(cache.get(host)?.until>clock())return cache.get(host).addresses;
  if(pending.has(host))return pending.get(host);
  const task=(async()=>{
   for(const provider of PROVIDERS){
    try{
     const addresses=await queryFn(provider,host);
     if(!Array.isArray(addresses)||!addresses.length||addresses.some(ip=>!publicIPv4(ip)))throw new Error();
     if(cache.size>=32)cache.delete(cache.keys().next().value);
     cache.set(host,{addresses,until:clock()+60000});log(provider.name,host);return addresses;
    }catch{}
   }
   throw new Error('encrypted_dns_unavailable');
  })();pending.set(host,task);
  try{return await task;}finally{pending.delete(host);}
 };
}
function createLookup(original,resolveHost) {
 return function lookup(host,options,callback){
  if(!workersHost(host))return original.apply(this,arguments);
  if(typeof options==='function'){callback=options;options={};}
  else if(typeof options==='number')options={family:options};
  options=options||{};
  if(typeof callback!=='function')throw new TypeError('DNS callback required');
  if(options.family===6||options.family==='IPv6'){const e=new Error('No IPv6 route in this diagnostic');e.code='EAI_NODATA';queueMicrotask(()=>callback(e));return;}
  resolveHost(host).then(ips=>{
   if(options.all)callback(null,ips.map(address=>({address,family:4})));
   else callback(null,ips[0],4);
  },()=>{const e=new Error('Encrypted DNS unavailable for Workers hostname');e.code='EAI_AGAIN';callback(e);});
 };
}
function install(){
 const lookup=createLookup(dns.lookup,resolver({log:(route,host)=>process.stderr.write('JADE_TAIL_DNS='+route+'; HOST='+host+'\n')}));
 dns.lookup=lookup;
 require('node:module').syncBuiltinESMExports();
}
module.exports={workersHost,publicIPv4,query,resolver,createLookup,install};
if(process.env.JADE_TAIL_DOH==='1')install();
