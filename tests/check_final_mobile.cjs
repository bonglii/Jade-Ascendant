'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto'),qa=require('../backend/player_identity/check_event_touch.cjs');
const suites=[['final_mobile_polish_smoke.gd','FINAL_MOBILE_POLISH','jade_event_touch_qa'],['final_mobile_combat_smoke.gd','FINAL_MOBILE_COMBAT','jade_event_touch_qa'],['compass_pursuit_smoke.gd','COMPASS_PURSUIT','jade_event_touch_qa'],['server_mail_smoke.gd','SERVER_MAIL_SMOKE','jade_server_mail_qa'],['release_comfort_batch_smoke.gd','RELEASE_COMFORT_BATCH','jade_event_touch_qa'],['home_sanctuary_smoke.gd','HOME_SANCTUARY_SMOKE','jade_home_sanctuary_qa'],['interface_consistency_smoke.gd','INTERFACE_CONSISTENCY','jade_event_touch_qa']];
async function run(project,godot,{gui=false,only=null}={}){
 const root=path.resolve(project),logs=path.join(root,gui?'.local/final_mobile_gui':'.local/event_touch_qa');godot=path.resolve(godot);
 await qa.qa(root,godot,{only:[],logs});const fixture=path.join(logs,'fixture');
 for(const [script,marker,guard]of suites){if(only&&!only.includes(script))continue;if(gui&&!script.startsWith('final_mobile_'))continue;
  const file=path.join(fixture,'project.godot');fs.writeFileSync(file,fs.readFileSync(file,'utf8').replace(/^config\/custom_user_dir_name=.*$/m,'config/custom_user_dir_name="jade_event_touch_qa_'+guard+'_'+crypto.randomUUID()+'"'));
  await qa.runProcess(godot,[...(gui?['--rendering-method','gl_compatibility']:['--headless']),'--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script],{cwd:root,logs,name:(gui?'gui-':'')+script,marker,totalMs:120000,idleMs:120000});
  if(!gui&&script==='final_mobile_polish_smoke.gd')await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script,'--','--restart-mail'],{cwd:root,logs,name:'restart-mail',marker:'FINAL_MOBILE_RESTART',totalMs:120000,idleMs:120000});
  if(!gui&&script==='server_mail_smoke.gd'){
   fs.writeFileSync(file,fs.readFileSync(file,'utf8').replace(/^config\/custom_user_dir_name=.*$/m,'config/custom_user_dir_name="jade_event_touch_qa_jade_server_mail_qa_guest_'+crypto.randomUUID()+'"'));
   await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script,'--','--anonymous-guest'],{cwd:root,logs,name:'anonymous-server-mail',marker:'SERVER_MAIL_SMOKE',totalMs:120000,idleMs:120000});
  }
 }
 console.log('FINAL_MOBILE_QA=PASS; ANDROID=NOT_TESTED');
}
if(require.main===module)run(process.argv[2]||path.resolve(__dirname,'..'),process.argv[3],{gui:process.argv.includes('--gui')}).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={run};
