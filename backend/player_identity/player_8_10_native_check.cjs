'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const textHash=bytes=>hash(Buffer.from(bytes.toString('utf8').replace(/^\uFEFF/,'').replace(/\r\n/g,'\n')));
const INSTALLED='addons/JadeMonetizationNativeBridge/bin/release/JadeMonetizationNativeBridge-release.aar';
function installed(root,read=relative=>fs.readFileSync(path.join(root,relative))){
 const sha256=hash(read(INSTALLED));
 return {sha256,policy:'preserve_exact_bytes',used_as_candidate:false};
}
function validate(root,read=relative=>fs.readFileSync(path.join(root,relative))){
 if(fs.existsSync(path.join(root,'.local/production_native_export/active.json')))throw Error('An export recovery receipt owns the bridge. Close Godot and run recover_production_export.cmd before installing source.');
 const proofPath='docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json',proofBytes=read(proofPath),proof=JSON.parse(proofBytes);
 if(proof.target!=='production-candidate'||proof.heavenly_trials_ruleset!==2||proof.run_card_export!==1||proof.jvm_test_executions<242||Object.keys(proof.inputs||{}).length!==50)throw Error('Missing reviewed player 8–10 native proof');
 for(const [relative,expected] of Object.entries(proof.inputs)){
  if(!/^(backend\/monetization\/android_bridge|addons\/JadeMonetizationNativeBridge)\//.test(relative)||relative.split('/').includes('..')||textHash(read(relative))!==expected)throw Error('Native source/provenance mismatch: '+relative);
 }
 const candidate='release/native/JadeMonetizationNativeBridge-production-candidate.aar';
 if(hash(read(candidate))!==proof.aar_sha256)throw Error('Native candidate binary mismatch');
 const original=installed(root,read);
 const exporter=read('backend/player_identity/export_production.ps1').toString();
 if(!exporter.includes("$candidateHash = '"+proof.aar_sha256+"'")||!exporter.includes("(TextHash $proofPath) -ne '"+textHash(proofBytes)+"'")||!exporter.includes('$inputs.Count -ne 50'))throw Error('Strict production exporter pins do not match this candidate');
 const helper='backend/player_identity/production_native_overlay.ps1';
 if(!exporter.includes("(TextHash $overlayHelper) -ne '"+textHash(read(helper))+"'"))throw Error('Native overlay helper pin mismatch');
 return {pass:true,installed_bridge:original,source_inputs:50,jvm_test_executions:proof.jvm_test_executions,candidate_sha256:proof.aar_sha256,installed:false,deployed:false};
}
module.exports={validate,installed,INSTALLED,hash,textHash};
if(require.main===module){try{console.log('PLAYER_8_10_NATIVE=PASS; '+JSON.stringify(validate(path.resolve(process.argv[2]||path.join(__dirname,'../..')))));}catch(error){console.error(error.message);process.exitCode=1;}}
