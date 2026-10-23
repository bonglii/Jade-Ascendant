'use strict';
// Offline asset integrity and unchanged live-gate check. No purchase, deploy or network.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {assertConfig}=require('./production_release_contract.mjs');
function check(project=path.resolve(__dirname,'../..')){
 const root=fs.realpathSync(project),dir=path.join(root,'assets/audio/presentation_v3');
 const manifest=JSON.parse(fs.readFileSync(path.join(dir,'manifest.json'),'utf8'));
 if(!Array.isArray(manifest)||manifest.length!==91)throw Error('Audio catalog differs.');
 const names=new Set(),signatures=new Set();let waves=0,music=0;
 for(const row of manifest){
  if(!/^[a-z_0-9]+\.(wav|ogg)$/.test(row.file)||names.has(row.file))throw Error('Invalid/duplicate audio path.');names.add(row.file);
  const bytes=fs.readFileSync(path.join(dir,row.file)),hash=crypto.createHash('sha256').update(bytes).digest('hex');
  if(hash!==row.sha256||signatures.has(hash)||!Number.isFinite(row.seconds)||row.seconds<=0)throw Error('Audio integrity failed: '+row.file);signatures.add(hash);
  if(row.file.endsWith('.wav')){
   if(bytes.toString('ascii',0,4)!=='RIFF'||bytes.toString('ascii',8,12)!=='WAVE')throw Error('Invalid WAV: '+row.file);
   let offset=12,data=null,channels=0,rate=0,bits=0,format=0;
   while(offset+8<=bytes.length){const id=bytes.toString('ascii',offset,offset+4),size=bytes.readUInt32LE(offset+4);if(offset+8+size>bytes.length)throw Error('Truncated WAV.');if(id==='fmt '){format=bytes.readUInt16LE(offset+8);channels=bytes.readUInt16LE(offset+10);rate=bytes.readUInt32LE(offset+12);bits=bytes.readUInt16LE(offset+22);}if(id==='data')data=bytes.subarray(offset+8,offset+8+size);offset+=8+size+(size%2);}
   if(format!==1||channels!==1||rate!==44100||bits!==16||!data||data.length<2000)throw Error('Unexpected PCM format: '+row.file);
   let peak=0,energy=0;for(let i=0;i+1<data.length;i+=2){const v=data.readInt16LE(i);peak=Math.max(peak,Math.abs(v));energy+=v*v;}
   if(peak<400||peak>=32700||energy===0||Math.abs(data.length/2/rate-row.seconds)>.005)throw Error('Clipped/silent/duration-mismatched audio: '+row.file);waves++;
  }else{if(bytes.toString('ascii',0,4)!=='OggS')throw Error('Invalid Ogg: '+row.file);music++;}
 }
 const source=fs.readFileSync(path.join(root,'scripts/managers/audio_manager.gd'),'utf8');
 for(const name of names)if(!source.includes('/presentation_v3/'+name))throw Error('Unused declared audio: '+name);
 for(const name of ['CC BY 3.0','Majadroid','brainiac256','elerya','rubberduck','Jan Schupke'])if(!source.includes(name))throw Error('Missing shipped audio attribution: '+name);
 assertConfig(fs.readFileSync(path.join(root,'backend/monetization/cloudflare/wrangler.production-live.toml'),'utf8'));
 console.log('RELEASE_POLISH_ASSETS=PASS; WAV='+waves+'; MUSIC='+music+'; NO_CLIPPING; GATES=9; DEPLOY=NONE');
 return {waves,music,files:names.size};
}
if(require.main===module){try{check(process.argv[2]);}catch(e){console.error('RELEASE_POLISH_ASSETS_STOPPED: '+e.message);process.exitCode=1;}}
module.exports={check};
