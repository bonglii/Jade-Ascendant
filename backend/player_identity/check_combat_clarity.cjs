'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const {qa,runProcess}=require('./check_event_touch.cjs');
async function check(project,godot){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/combat_clarity_qa');fs.mkdirSync(logs,{recursive:true});
 const remembered=path.join(root,'.local/production_native_export/godot-path.local.txt');godot=godot||process.env.GODOT_PATH||(fs.existsSync(remembered)?fs.readFileSync(remembered,'utf8').trim().replace(/^"|"$/g,''):'');
 if(!godot||!fs.existsSync(godot))throw Error('Set GODOT_PATH to the installed Godot4.7.2 console executable.');
 const version=spawnSync(godot,['--version'],{encoding:'utf8',windowsHide:true});if(version.status!==0||!/^4\.7\.2\./.test(version.stdout.trim()))throw Error('Use Godot4.7.2 console.');
 const contract=spawnSync(process.execPath,['backend/player_identity/production_release_contract.mjs'],{cwd:root,encoding:'utf8',windowsHide:true});if(contract.status!==0)throw Error('Existing production contract failed.');console.log(contract.stdout.trim());
 await qa(root,godot,{only:[]});
 const fixture=path.join(root,'.local/event_touch_qa/fixture'),cfg=path.join(fixture,'project.godot'),baseline=fs.readFileSync(cfg,'utf8');
 const suites=[
 ['combat_clarity_smoke.gd','COMBAT_CLARITY checks=','jade_event_touch_qa','COMBAT_CLARITY_RESTART'],
 ['combat_stats_layout_smoke.gd','COMBAT_STATS_LAYOUT checks=','jade_event_touch_qa',''],
 ['encounter_cadence_realms_smoke.gd','CADENCE_REALMS checks=','jade_event_touch_qa',''],
 ['elite_pacing_smoke.gd','ELITE_PACING_QA','jade_pacing_qa',''],
 ['combat_fairness_smoke.gd','COMBAT_FAIRNESS','jade_combat_fairness_qa',''],
 ['cultivation_mastery_smoke.gd','CULTIVATION_MASTERY','jade_hero_qa','CULTIVATION_MASTERY_RESTART'],
 ['paid_run_recovery_smoke.gd','PAID_RUN_RECOVERY_CHECKS=','jade_paid_run_qa','PAID_RUN_RECOVERY_CHECKS='],
 ['economy_progression_smoke.gd','ECONOMY_PROGRESS_QA','jade_economy_qa','ECONOMY_PROGRESS_RESTART'],
 ['progression_cadence_export.gd','PROGRESSION_CADENCE_EXPORT=PASS','jade_event_touch_qa','']
 ];
 try{for(const [script,marker,prefix,restart]of suites){
  fs.writeFileSync(cfg,baseline.replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="'+prefix+'_jade_event_touch_qa_'+crypto.randomUUID()+'"'));
  const args=['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script];
  await runProcess(godot,args,{cwd:root,logs,name:script,marker,idleMs:95000,totalMs:100000});
  if(restart)await runProcess(godot,[...args,'--',script.startsWith('cultivation')?'--restart':'--resume'],{cwd:root,logs,name:script+'-restart',marker:restart,idleMs:95000,totalMs:100000});
 }}finally{fs.writeFileSync(cfg,baseline);}
 console.log('COMBAT_CLARITY_QA=PASS; REAL_SAVES=UNTOUCHED; NATIVE=UNCHANGED; PURCHASE=NONE; DEPLOY=NONE');return{pass:true};
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3]).catch(e=>{console.error('COMBAT_CLARITY_QA_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check};
