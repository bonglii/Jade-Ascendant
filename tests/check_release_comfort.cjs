'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const qa=require('../backend/player_identity/check_event_touch.cjs');
const suites=[['release_comfort_batch_smoke.gd','RELEASE_COMFORT_BATCH','jade_event_touch_qa'],['ascendant_arsenal_smoke.gd','ASCENDANT_ARSENAL_QA','jade_arsenal_qa'],['returning_glaive_smoke.gd','RETURNING_GLAIVE_CHECKS','jade_glaive_qa'],['odyssey_combat_smoke.gd','ODYSSEY_COMBAT','jade_warning_cleanup_qa'],['compass_pursuit_smoke.gd','COMPASS_PURSUIT','jade_event_touch_qa']];
async function run(project,godot,{only=null,gui=false}={}){
 const root=path.resolve(project),logs=path.join(root,gui?'.local/release_comfort_gui':'.local/release_comfort_qa');godot=path.resolve(godot);
 await qa.qa(root,godot,{only:[],logs});const fixture=path.join(logs,'fixture');
 for(const [script,marker,guard]of suites){if(only&&!only.includes(script))continue;
  const config=path.join(fixture,'project.godot');let text=fs.readFileSync(config,'utf8');text=text.replace(/^config\/custom_user_dir_name=.*$/m,'config/custom_user_dir_name="jade_event_touch_qa_'+guard+'_'+crypto.randomUUID()+'"');fs.writeFileSync(config,text);
  const args=[...(gui?['--rendering-method','gl_compatibility']:['--headless']),'--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script];
  await qa.runProcess(godot,args,{cwd:root,logs,name:(gui?'gui-':'')+script,marker,totalMs:100000,idleMs:100000});
  if(script==='release_comfort_batch_smoke.gd'&&!gui)await qa.runProcess(godot,[...args,'--','--restart-welcome'],{cwd:root,logs,name:'welcome-restart',marker:'COMFORT_RESTART',totalMs:100000,idleMs:100000});
 }
 console.log('RELEASE_COMFORT_QA=PASS; ANDROID=NOT_TESTED');
}
if(require.main===module)run(process.argv[2]||path.resolve(__dirname,'..'),process.argv[3],{gui:process.argv.includes('--gui'),only:process.argv.includes('--gui')?['release_comfort_batch_smoke.gd']:null}).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={run};
