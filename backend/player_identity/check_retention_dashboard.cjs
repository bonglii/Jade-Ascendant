'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const {qa,runProcess}=require('./check_event_touch.cjs');
async function check(project,godot,{native=false,only=null}={}){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/retention_dashboard_qa');fs.mkdirSync(logs,{recursive:true});
 godot=godot||process.env.GODOT_PATH;if(!godot||!fs.existsSync(godot))throw Error('Set GODOT_PATH to Godot4.7.2 console.');
 const version=spawnSync(godot,['--version'],{encoding:'utf8'});if(version.status!==0||!/^4\.7\.2\./.test(version.stdout.trim()))throw Error('Use Godot4.7.2 console.');
 await qa(root,godot,{only:[]});
 const fixture=path.join(root,'.local/event_touch_qa/fixture'),cfg=path.join(fixture,'project.godot'),original=fs.readFileSync(cfg,'utf8');
 const suites=native?[['release_ui_layout_smoke.gd','RELEASE_UI checks=','jade_release_ui_qa']]:[
 ['retention_loop_smoke.gd','RETENTION_LOOP checks=','jade_retention_qa','restart'],
 ['player_direction_smoke.gd','PLAYER_DIRECTION checks=','jade_event_touch_qa'],
 ['home_sanctuary_smoke.gd','HOME_SANCTUARY_SMOKE checks=','jade_home_sanctuary_qa'],
 ['lin_yue_library_smoke.gd','LIN_LIBRARY_QA checks=','jade_lin_library_qa'],
 ['combat_skill_polish_smoke.gd','COMBAT_SKILL_POLISH_QA checks=','jade_combat_pass_qa'],
 ['arsenal_integration_smoke.gd','ARSENAL_INTEGRATION_QA checks=','jade_arsenal_qa_integration']];
 const selected=only?suites.filter(row=>only.includes(row[0])):suites;if(only&&selected.length!==only.length)throw Error("Unknown targeted suite.");
 try{for(const [script,marker,prefix,restart]of selected){
  fs.writeFileSync(cfg,original.replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="'+prefix+'_jade_event_touch_qa_'+crypto.randomUUID()+'"')+'\n[threading]\nworker_pool/max_threads=2\n');
  const args=[...(native?[]:['--headless']),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script];
  for(const resume of restart?[false,true]:[false]){
   const name=script+(native?'-native':'')+(resume?'-restart':'');
   await runProcess(godot,[...args,...(resume?['--','--resume']:[])],{cwd:root,logs,name,marker,totalMs:150000,idleMs:120000});
   if(!/checks=[1-9]\d* failures=0/.test(fs.readFileSync(path.join(logs,name+'.log'),'utf8')))throw Error('Missing zero-failure check count: '+name);
  }
 }}finally{fs.writeFileSync(cfg,original);}
 console.log('RETENTION_DASHBOARD_QA=PASS; NATIVE_GUI='+native+'; REAL_SAVES=UNTOUCHED; PURCHASE=NONE; DEPLOY=NONE');
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3],{native:process.argv.includes('--native')}).catch(e=>{console.error('RETENTION_DASHBOARD_QA_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check};
