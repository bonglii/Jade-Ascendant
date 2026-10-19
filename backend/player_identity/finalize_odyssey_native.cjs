'use strict';
// Called only after the existing production candidate builder completes all JVM/JNI gates.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const textHash=file=>sha(Buffer.from(fs.readFileSync(file,'utf8').replace(/\r\n/g,'\n')));
function finalize(output){
 if(fs.existsSync(path.join(root,'.local/production_native_export/active.json')))throw Error('Recover the interrupted export before updating its pinned artifact.');
 const base=path.resolve(root,'.local/production_native_candidate')+path.sep,dir=path.resolve(output);
 if(!dir.startsWith(base))throw Error('Candidate must come from this project build directory.');
 const receiptFile=path.join(dir,'receipt.json'),proof=JSON.parse(fs.readFileSync(receiptFile,'utf8'));
 const artifact=path.join(dir,'JadeMonetizationNativeBridge-production-candidate.aar');
 if(proof.target!=='production-candidate'||proof.installed!==false||proof.deployed!==false||proof.jvm_test_executions<220||proof.odyssey_shop_protocol!==3||sha(fs.readFileSync(artifact))!==proof.aar_sha256)throw Error('Incomplete native build receipt.');
 const required='backend/monetization/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/';
 for(const name of ['JadeMonetizationNativeBridge.kt','OdysseyContractV1.kt','TrustedIapHttps.kt'])if(!proof.inputs[required+name])throw Error('Missing Odyssey native input.');
 for(const [relative,hash] of Object.entries(proof.inputs)){if(relative.includes('..')||path.isAbsolute(relative)||textHash(path.join(root,relative))!==hash)throw Error('Native source changed after compilation: '+relative);}
 const jni=fs.readFileSync(path.join(dir,'jni.txt'),'utf8');if(!jni.includes('requestOdysseyV1('))throw Error('Odyssey JNI method not compiled.');
 const exporter=path.join(root,'backend/player_identity/export_production.ps1');let source=fs.readFileSync(exporter,'utf8');
 if(!/\$candidateHash = '[a-f0-9]{64}'/.test(source)||!source.includes('Candidate provenance changed.'))throw Error('Unrecognized production export launcher.');
 const count=Object.keys(proof.inputs).length;
 source=source.replace(/\$candidateHash = '[a-f0-9]{64}'/,`$candidateHash = '${proof.aar_sha256}'`).replace(/\(TextHash \$proofPath\) -ne '[a-f0-9]{64}'/,`(TextHash $proofPath) -ne '${textHash(receiptFile)}'`).replace(/\$inputs.Count -ne \d+/,`$inputs.Count -ne ${count}`).replace(/INPUTS=\d+;/,`INPUTS=${count};`);
 const targets=[['release/native/JadeMonetizationNativeBridge-production-candidate.aar',fs.readFileSync(artifact)],['docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json',fs.readFileSync(receiptFile)],['backend/player_identity/export_production.ps1',Buffer.from(source)]];
 const backup=path.join(root,'.local/odyssey_native_backup',crypto.randomUUID());
 for(const [relative] of targets){const dest=path.join(backup,relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,relative),dest);}
 try{for(const [relative,bytes] of targets)fs.writeFileSync(path.join(root,relative),bytes);}catch(error){for(const [relative] of targets)fs.copyFileSync(path.join(backup,relative),path.join(root,relative));throw error;}
 console.log('ODYSSEY_NATIVE_CANDIDATE=PASS; AAR_SOURCE_JNI_JVM_VERIFIED; INSTALLED_RELEASE_UNCHANGED; EXPORT_LAUNCHER_UPDATED');
}
if(require.main===module){try{finalize(process.argv[2]||'');}catch(e){console.error('ODYSSEY_NATIVE_STOPPED: '+e.message);process.exitCode=1;}}
module.exports={finalize};
