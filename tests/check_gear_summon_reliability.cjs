'use strict';
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto'),qa=require('../backend/player_identity/check_event_touch.cjs');
async function run(project,godot,{reproduce=false}={}){
 const root=path.resolve(project),logs=path.join(root,'.local/gear_summon_qa');godot=path.resolve(godot);
 await qa.qa(root,godot,{only:[],logs});
 const fixture=path.join(logs,'fixture');
 if(reproduce){
  const file=path.join(fixture,'scripts/managers/pavilion_manager.gd'),correct=fs.readFileSync(file);
  try{
   const original=cp.execFileSync('git',['show','06a7b39fba78b0fb1a3dfdfb31f549c8d222d5cc:scripts/managers/pavilion_manager.gd'],{cwd:root});
   fs.writeFileSync(file,original);
   await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/gear_summon_reliability_smoke.gd','--','--repro'],{cwd:root,logs,name:'baseline-read-busy',marker:'PAVILION_REFRESH_REPRO local_summon_ready=false read_busy=true',totalMs:120000,idleMs:120000});
  }finally{fs.writeFileSync(file,correct);}
 }
 await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/gear_summon_reliability_smoke.gd'],{cwd:root,logs,name:'gear-summon-reliability',marker:'GEAR_SUMMON_RELIABILITY',totalMs:120000,idleMs:120000});
 const config=path.join(fixture,'project.godot'),original=fs.readFileSync(config,'utf8');
 try{
  fs.writeFileSync(config,original.replace(/^config\/custom_user_dir_name=.*$/m,'config/custom_user_dir_name="jade_paid_v2_qa_jade_event_touch_qa_'+crypto.randomUUID()+'"'));
  await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/paid_gameplay_v2_smoke.gd'],{cwd:root,logs,name:'paid-v2-regression',marker:'PAID_GAMEPLAY_V2',totalMs:120000,idleMs:120000});
 }finally{fs.writeFileSync(config,original);}
 console.log('GEAR_SUMMON_QA=PASS; PAID_GUARDS_PRESERVED; ANDROID=NOT_TESTED');
}
if(require.main===module)run(process.argv[2]||path.resolve(__dirname,'..'),process.argv[3],{reproduce:process.argv.includes('--reproduce')}).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={run};
