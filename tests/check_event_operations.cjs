'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),qa=require('../backend/player_identity/check_event_touch.cjs');
async function run(project,godot){
 const root=path.resolve(project),logs=path.join(root,'.local/event_operations_qa'),fixture=path.join(logs,'fixture');godot=path.resolve(godot);
 await qa.qa(root,godot,{only:[],logs});
 const suites=[['event_off_smoke.gd','EVENT_OFF','jade_event_touch_qa'],['odyssey_prewarm_session_smoke.gd','ODYSSEY_PREWARM_SESSION','jade_mail_session_qa'],['heavenly_trials_smoke.gd','HEAVENLY_TRIALS checks=','jade_heavenly_trials_qa'],['heavenly_trials_recovery_smoke.gd','HEAVENLY_TRIALS_RECOVERY checks=','jade_heavenly_trials_qa']];
 for(const [script,marker,guard]of suites){
  const p=path.join(fixture,'project.godot');fs.writeFileSync(p,fs.readFileSync(p,'utf8').replace(/^config\/custom_user_dir_name=.*$/m,'config/custom_user_dir_name="jade_event_touch_qa_'+guard+'_'+crypto.randomUUID()+'"'));
  await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script],{cwd:root,logs,name:script,marker,totalMs:120000,idleMs:120000});
 }
 console.log('EVENT_OPERATIONS_RUNTIME=PASS; ANDROID=NOT_TESTED');
}
if(require.main===module)run(process.argv[2]||path.resolve(__dirname,'..'),process.argv[3]).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={run};
