'use strict';
// Read-only verification shared by the installer, Windows QA and author tests.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const text=bytes=>bytes.toString('utf8').replace(/^\uFEFF/,'').replace(/\r\n/g,'\n');
const CANDIDATE='release/native/JadeMonetizationNativeBridge-production-candidate.aar';
const PROOF='docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json';
const EXPORTER='backend/player_identity/export_production.ps1';
const LOCKED='addons/JadeMonetizationNativeBridge/bin/release/JadeMonetizationNativeBridge-release.aar';
const AAR_SHA='2171f13f36cf8d90988fd20248f879653104625c8481b91d3fb0a4303fb098ea';
const PROOF_SHA='ff0dadb7aee521fbc5d71d5de62ca948c12567b0cc68d1aa4211ac389c0f9596';
const OVERLAY='backend/player_identity/production_native_overlay.ps1';
const OVERLAY_SHA='ddebc683ae50ef49191e8935bef80a159a2dad1a878d1da03ad544fad6173b6a';
function inspect(root,{read=relative=>fs.readFileSync(path.join(root,relative))}={}){
 const failures=[];
 const fail=(file,message)=>failures.push({path:file,error:Error(message)});
 const get=relative=>{try{return read(relative);}catch(error){fail(relative,'Native input tidak tersedia: '+relative);return null;}};
 // Never replace a candidate while the previous temporary export needs recovery.
 const active='.local/production_native_export/active.json';
 if(fs.existsSync(path.join(root,active)))fail(active,'Export sebelumnya belum selesai/recover. Jalankan exporter lama dengan -RecoverOnly terlebih dahulu.');
 const proofBytes=get(PROOF),candidate=get(CANDIDATE),exporterBytes=get(EXPORTER),locked=get(LOCKED),overlayBytes=get(OVERLAY);
 let proof=null;
 if(proofBytes){
  if(sha(Buffer.from(text(proofBytes)))!==PROOF_SHA)fail(PROOF,'Provenance harus sama persis dengan native candidate yang sudah direview.');
  try{proof=JSON.parse(text(proofBytes));}catch{fail(PROOF,'Native provenance bukan JSON valid.');}
 }
 if(candidate&&sha(candidate)!==AAR_SHA)fail(CANDIDATE,'Native candidate AAR hash mismatch.');
 if(proof){
  if(proof.target!=='production-candidate'||proof.aar_sha256!==AAR_SHA||proof.installed!==false||proof.deployed!==false||proof.connection_read_lanes_revision!==1||proof.jvm_test_executions!==248||proof.heavenly_trials_ruleset!==2||proof.run_card_export!==1)fail(PROOF,'Native candidate metadata mismatch.');
  const inputs=proof.inputs&&typeof proof.inputs==='object'&&!Array.isArray(proof.inputs)?Object.entries(proof.inputs):[];
  if(inputs.length!==52)fail(PROOF,'Native candidate requires exactly 52 reviewed source inputs.');
  for(const [relative,hash]of inputs){
   if(!relative||path.isAbsolute(relative)||relative.includes('\\')||relative.split('/').includes('..')||!/^([a-f0-9]{64})$/.test(hash)){fail(PROOF,'Unsafe native input inventory.');continue;}
   const bytes=get(relative);if(bytes&&sha(Buffer.from(text(bytes)))!==hash)fail(relative,'Source native berbeda dari compiled candidate: '+relative+'. Tidak ada source yang ditimpa.');
  }
 }
 if(exporterBytes){
  const exporter=text(exporterBytes);
  if(!exporter.includes("$candidateHash = '"+AAR_SHA+"'")||!exporter.includes("(TextHash $proofPath) -ne '"+PROOF_SHA+"'")||!exporter.includes('$inputs.Count -ne 52'))fail(EXPORTER,'Exporter tidak cocok dengan candidate/provenance yang direview.');
  // The owner v2 exporter snapshots/restores the actual installed bytes. Its
  // reviewed helper remains pinned; a fixed historical locked hash would
  // incorrectly reject a valid owner build before the temporary overlay.
  if(!exporter.includes("(TextHash $overlayHelper) -ne '"+OVERLAY_SHA+"'")||!exporter.includes('. $overlayHelper')||!exporter.includes('Start-JadeNativeOverlay')||!exporter.includes('Restore-JadeNativeOverlay')||!exporter.includes('$originalHash = HashFile $release'))fail(EXPORTER,'Exporter harus memakai reviewed v2 overlay dan hash bridge asli.');
  if(!overlayBytes||sha(Buffer.from(text(overlayBytes)))!==OVERLAY_SHA)fail(OVERLAY,'Native overlay helper berubah dari versi owner yang direview.');
 }
 return {failures,aar_sha256:AAR_SHA,source_inputs:52,jvm_test_executions:248};
}
function verify(root,options){const result=inspect(root,options);if(result.failures.length)throw Error(result.failures.map(x=>x.path+': '+x.error.message).join('\n'));return result;}
module.exports={inspect,verify,sha,text,CANDIDATE,PROOF,EXPORTER,LOCKED,AAR_SHA,PROOF_SHA,OVERLAY,OVERLAY_SHA};
