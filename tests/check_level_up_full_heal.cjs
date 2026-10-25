'use strict';
const fs=require('node:fs'),path=require('node:path'),qa=require('../backend/player_identity/check_event_touch.cjs');
async function run(project,godot){
 const root=path.resolve(project),logs=path.join(root,'.local/level_heal_qa');godot=path.resolve(godot);
 await qa.qa(root,godot,{only:[],logs});const fixture=path.join(logs,'fixture'),file=path.join(fixture,'project.godot'),original=fs.readFileSync(file,'utf8');
 try{
  fs.writeFileSync(file,original.replace(/^config\/custom_user_dir_name=.*$/m,'config/custom_user_dir_name="jade_event_touch_qa_jade_level_heal_qa_'+require('node:crypto').randomUUID()+'"'));
  for(const restart of [false,true])await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/level_up_full_heal_smoke.gd',...(restart?['--','--resume']:[])],{cwd:root,logs,name:restart?'full-heal-restart':'full-heal',marker:restart?'LEVEL_UP_FULL_HEAL_RESTART':'LEVEL_UP_FULL_HEAL',totalMs:90000,idleMs:90000});
 }finally{fs.writeFileSync(file,original);}
 console.log('LEVEL_HEAL_QA=PASS; SAVES_PRESERVED; NATIVE=UNCHANGED; ANDROID=NOT_TESTED');
}
if(require.main===module)run(process.argv[2]||path.resolve(__dirname,'..'),process.argv[3]).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={run};
