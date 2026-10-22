'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const {qa,runProcess}=require('./check_event_touch.cjs');
const serverTests=[...new Set([...require('./check_liveops_control.cjs').serverTests,'backend/monetization/cloudflare/tests/compass_mail_grant.test.mjs'])];
async function check(project,godot){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/player_journey_qa');fs.mkdirSync(logs,{recursive:true});
 await runProcess(process.execPath,['--test','--test-concurrency=1',...serverTests],{cwd:root,logs,name:'server',idleMs:60000,totalMs:180000});
 const contract=spawnSync(process.execPath,['backend/player_identity/production_release_contract.mjs'],{cwd:root,encoding:'utf8',windowsHide:true});if(contract.status!==0)throw Error('Production contract failed. No publish/deploy performed.');console.log(contract.stdout.trim());
 const remembered=path.join(root,'.local/production_native_export/godot-path.local.txt');godot=godot||process.env.GODOT_PATH||(fs.existsSync(remembered)?fs.readFileSync(remembered,'utf8').trim().replace(/^"|"$/g,''):'');
 if(!godot||!fs.existsSync(godot))throw Error('Godot console path required. Set GODOT_PATH to the existing Godot4.7.2 console executable; no publish/deploy performed.');
 const version=spawnSync(godot,['--version'],{encoding:'utf8',windowsHide:true});if(version.status!==0||!/^4\.7\.2\./.test(version.stdout.trim()))throw Error('Use the existing Godot4.7.2 console build.');
 await qa(root,godot,{only:[]});
 const fixture=path.join(root,'.local/event_touch_qa/fixture'),cfg=path.join(fixture,'project.godot'),baseline=fs.readFileSync(cfg,'utf8');
 try{
 for(const [script,marker,prefix,restart] of [
  ['run_entry_reliability_smoke.gd','RUN_ENTRY_RELIABILITY checks=','jade_event_touch_qa',false],
  ['player_journey_layout_smoke.gd','PLAYER_JOURNEY_LAYOUT checks=','jade_event_touch_qa',false],
  ['paid_run_recovery_smoke.gd','PAID_RUN_RECOVERY_CHECKS=','jade_paid_run_qa',true],
  ['odyssey_combat_smoke.gd','ODYSSEY_COMBAT checks=','jade_warning_cleanup_qa',false],
  ['economy_progression_smoke.gd','ECONOMY_PROGRESS_QA','jade_economy_qa',true],
  ['player_direction_smoke.gd','PLAYER_DIRECTION checks=','jade_event_touch_qa',false]
 ]){
  fs.writeFileSync(cfg,baseline.replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="'+prefix+'_jade_event_touch_qa_'+crypto.randomUUID()+'"'));
  const args=['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script];
  await runProcess(godot,args,{cwd:root,logs,name:script,marker,idleMs:95000,totalMs:100000});
  if(restart)await runProcess(godot,[...args,'--','--resume'],{cwd:root,logs,name:script+'-restart',marker:script.startsWith('economy')?'ECONOMY_PROGRESS_RESTART':marker,idleMs:95000,totalMs:100000});
 }
 }finally{fs.writeFileSync(cfg,baseline);}
 console.log('PLAYER_JOURNEY_QA=PASS; REAL_SAVES=UNTOUCHED; NATIVE=UNCHANGED; PURCHASE=NONE; DEPLOY=NONE');return {pass:true};
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3]).catch(e=>{console.error('PLAYER_JOURNEY_QA_STOPPED: '+e.message);process.exitCode=1});
module.exports={check,serverTests};
