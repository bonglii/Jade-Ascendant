'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {syncFixture,runProcess}=require('./check_event_touch.cjs');
const {resolveGodot}=require('./check_tester_reliability.cjs');
const {validate}=require('./player_8_10_native_check.cjs');
function audit(log,negative=false){
 let text=fs.readFileSync(log,'utf8');
 if(negative){
  const regions=[...text.matchAll(/EXPECTED_ATOMIC_FAILURE_BEGIN\r?\n([\s\S]*?)EXPECTED_ATOMIC_FAILURE_END/g)];
  if(regions.length!==1||!regions[0][1].includes('Reward could not be committed'))throw Error('Missing deliberate transaction rejection evidence');
  text=text.replace(regions[0][0],'EXPECTED_ATOMIC_REJECTION_VERIFIED');
 }
 if(/SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances were leaked|resources still in use at exit/m.test(text))throw Error('Unexpected runtime error/leak; see '+log);
}
async function focused(executable,args,{cwd,logs,name,marker}){
 const {spawn}=require('node:child_process'),log=path.join(logs,name+'.log');fs.writeFileSync(log,'');console.log('PLAYER_8_10_QA='+name);
 const started=Date.now();
 const code=await new Promise((resolve,reject)=>{
  const child=spawn(executable,args,{cwd,windowsHide:true,stdio:['ignore','pipe','pipe']});
  const timer=setTimeout(()=>{child.kill();reject(Error('Focused runtime timed out'));},180000);
  for(const stream of [child.stdout,child.stderr])stream.on('data',bytes=>fs.appendFileSync(log,bytes));
  child.on('error',error=>{clearTimeout(timer);reject(error);});child.on('close',code=>{clearTimeout(timer);resolve(code);});
 });
 if(code!==0)throw Error('Focused runtime exited '+code+'; see '+log);
 const text=fs.readFileSync(log,'utf8');audit(log,true);
 if(!text.includes(marker)||!/checks=\d+ failures=0/.test(text))throw Error('Focused runtime pass marker missing');
 fs.writeFileSync(path.join(logs,name+'.json'),JSON.stringify({name,exit_code:code,elapsed_ms:Date.now()-started,reason:'',expected_atomic_rejection:true,log},null,2)+'\n');
 console.log(text.split(/\r?\n/).find(line=>line.startsWith(marker)));
}
async function check(project,godot){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/player_8_10_qa'),fixture=path.join(logs,'fixture');fs.mkdirSync(fixture,{recursive:true});
 godot=resolveGodot(root,godot);validate(root);
 await runProcess(process.execPath,['backend/player_identity/production_release_contract.mjs'],{cwd:root,logs,name:'production-config',marker:'PRODUCTION_CONFIG=PASS',totalMs:30000});
 await runProcess(process.execPath,['--test','--test-concurrency=1','backend/monetization/cloudflare/heavenly_trials.test.mjs','backend/player_identity/heavenly_trials.test.mjs'],{cwd:root,logs,name:'server',totalMs:60000,idleMs:45000});
 syncFixture(root,fixture,path.join(logs,'cache-inputs.json'));
 const original=fs.readFileSync(path.join(root,'project.godot'),'utf8');
 function config(){
  const token='jade_player_810_qa_jade_heavenly_trials_qa_jade_event_touch_qa_'+crypto.randomUUID();
  let text=original.replace('Firebase="*uid://bfps2e72dlnwq"','Firebase="*res://addons/GodotFirebaseAndroid/Firebase.gd"').replace(/^\s*config\/(?:use_custom_user_dir|custom_user_dir_name)\s*=.*$/gm,'').replace(/config\/name="[^"\r\n]*"/,'config/name="jade-player-810-qa"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+token+'"').replace(/enabled=PackedStringArray\([^\r\n]*\)/,'enabled=PackedStringArray()').replace(/(renderer\/rendering_method[^=]*)=[^\r\n]*/g,'$1="gl_compatibility"');
  text+='\n[input_devices]\npointing/emulate_touch_from_mouse=true\n\n[threading]\nworker_pool/max_threads=2\n\n[debug]\ngdscript/warnings/enable=true\ngdscript/warnings/shadowed_variable_base_class=2\n';fs.writeFileSync(path.join(fixture,'project.godot'),text);
 }
 config();
 await runProcess(godot,['--headless','--audio-driver','Dummy','--editor','--path',fixture,'--import','--quit'],{cwd:root,logs,name:'import',totalMs:1200000,idleMs:300000});
 const suites=[['player_8_10_smoke.gd','PLAYER_8_10 checks=',true],['heavenly_trials_smoke.gd','HEAVENLY_TRIALS checks=',false],['heavenly_trials_recovery_smoke.gd','HEAVENLY_TRIALS_RECOVERY checks=',false]];
 for(const [script,marker,negative] of suites){
  config();await (negative?focused:runProcess)(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script],{cwd:root,logs,name:script,marker,totalMs:180000,idleMs:100000});audit(path.join(logs,script+'.log'),negative);
 }
 const receipt={pass:true,suites:suites.map(x=>x[0]),server_tests:20,native:validate(root),android_tested:false,exported:false,deployed:false};
 fs.writeFileSync(path.join(logs,'receipt.json'),JSON.stringify(receipt,null,2)+'\n');
 console.log('PLAYER_8_10_QA=PASS; REAL_SAVES=UNTOUCHED; ANDROID=NOT_TESTED; COMMIT/PUSH/DEPLOY/EXPORT=NONE');return receipt;
}
module.exports={check,audit};
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3]).catch(error=>{console.error('PLAYER_8_10_STOPPED: '+error.message);process.exitCode=1;});
