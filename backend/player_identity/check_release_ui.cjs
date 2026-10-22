'use strict';
// Disposable full-copy fixture: no import writes to the owner's game source/saves.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const {qa,runProcess}=require('./check_event_touch.cjs');
const suites=[['public_readiness_ui_smoke.gd','PUBLIC_READINESS_UI checks=','jade_paid_v2_qa'],['ui_reliability_followup_smoke.gd','UI_RELIABILITY checks=','jade_ui_reliability_qa'],['home_sanctuary_smoke.gd','HOME_SANCTUARY_SMOKE checks=','jade_home_sanctuary_qa'],['player_features_smoke.gd','PLAYER_FEATURES_QA checks=','jade_event_touch_qa'],['release_ui_layout_smoke.gd','RELEASE_UI checks=','jade_release_ui_qa']];
async function check(project,godot,{native=false,only=null}={}){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/release_qa17_qa');fs.mkdirSync(logs,{recursive:true});
 const remembered=path.join(root,'.local/production_native_export/godot-path.local.txt');godot=godot||process.env.GODOT_PATH||(fs.existsSync(remembered)?fs.readFileSync(remembered,'utf8').trim().replace(/^"|"$/g,''):'');
 if(!godot||!fs.existsSync(godot))throw Error('Set GODOT_PATH to the installed Godot4.7.2 console executable. No source/purchase/deployment changes performed.');
 const version=spawnSync(godot,['--version'],{encoding:'utf8',windowsHide:true});if(version.status!==0||!/^4\.7\.2\./.test(version.stdout.trim()))throw Error('Use Godot4.7.2 console.');
 await qa(root,godot,{only:[]});
 const cfg=path.join(root,'.local/event_touch_qa/fixture/project.godot'),fixture=path.dirname(cfg),original=fs.readFileSync(cfg,'utf8');
 const selected=only?suites.filter(([s])=>only.includes(s)):suites;if(only&&selected.length!==only.length)throw Error('Unknown targeted suite.');
 try{for(const [script,marker,prefix]of selected){
  let text=original.replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="'+prefix+'_jade_event_touch_qa_'+crypto.randomUUID()+'"');
  text+='\n[threading]\nworker_pool/max_threads=2\n';fs.writeFileSync(cfg,text);
  const args=[...(native?[]:['--headless']),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script];
  const name=script+(native?'-native':'');
  await runProcess(godot,args,{cwd:root,logs,name,marker,totalMs:150000,idleMs:120000});
  if(!/checks=[1-9]\d* failures=0/.test(fs.readFileSync(path.join(logs,name+'.log'),'utf8')))throw Error('Missing positive zero-failure marker: '+script);
 }}finally{fs.writeFileSync(cfg,original);}
 console.log('RELEASE_QA17_QA=PASS; NATIVE_GUI='+native+'; ANDROID_DEVICE=NOT_TESTED; REAL_SAVES=UNTOUCHED; PURCHASE=NONE; DEPLOY=NONE');return{pass:true,native};
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3],{native:process.argv.includes('--native'),only:process.argv.includes('--native')?['release_ui_layout_smoke.gd']:null}).catch(e=>{console.error('RELEASE_QA17_QA_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check,suites};
