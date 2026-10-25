'use strict';
const fs=require('node:fs'),path=require('node:path'),qa=require('../backend/player_identity/check_event_touch.cjs'),crypto=require('node:crypto');
async function run(project,godot){
 const root=path.resolve(project),logs=path.join(root,'.local/event_operations_qa');godot=path.resolve(godot);
 await qa.qa(root,godot,{only:[],logs});
 const fixture=path.join(logs,'fixture');
 // Two real processes, same isolated user directory: the welcome is session-only.
 for(let i=1;i<=2;i++)await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/connection_welcome_smoke.gd'],{cwd:root,logs,name:'connection-welcome-'+i,marker:'CONNECTION_WELCOME',totalMs:120000,idleMs:120000});
 const file=path.join(fixture,'project.godot'),original=fs.readFileSync(file,'utf8');
 try{
  fs.writeFileSync(file,original.replace(/^config\/custom_user_dir_name=.*$/m,'config/custom_user_dir_name="jade_profile_qa_jade_event_touch_qa_'+crypto.randomUUID()+'"'));
  await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/player_profile_smoke.gd'],{cwd:root,logs,name:'welcome-profile-regression',marker:'PLAYER_PROFILE_QA',totalMs:120000,idleMs:120000});
 }finally{fs.writeFileSync(file,original);}
 console.log('CONNECTION_WELCOME_QA=PASS; TWO_PROCESSES; ANDROID=NOT_TESTED');
}
if(require.main===module)run(process.argv[2]||path.resolve(__dirname,'..'),process.argv[3]).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={run};
