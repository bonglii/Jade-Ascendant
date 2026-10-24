'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),qa=require('../backend/player_identity/check_event_touch.cjs');
async function run(project,godot,{gui=false}={}){
 const root=path.resolve(project),logs=path.join(root,'.local/controls_final_qa');godot=path.resolve(godot);
 await qa.qa(root,godot,{only:[],logs});const fixture=path.join(logs,'fixture');
 for(const [script,marker]of [['controls_comfort_smoke.gd','CONTROLS_COMFORT'],...(!gui?[['yin_yang_tempo_smoke.gd','YIN_TEMPO']]:[])]){
  const config=path.join(fixture,'project.godot');fs.writeFileSync(config,fs.readFileSync(config,'utf8').replace(/^config\/custom_user_dir_name=.*$/m,'config/custom_user_dir_name="jade_event_touch_qa_controls_'+crypto.randomUUID()+'"'));
  const args=[...(gui?['--rendering-method','gl_compatibility']:['--headless']),'--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script];
  await qa.runProcess(godot,args,{cwd:root,logs,name:(gui?'gui-':'')+script,marker,totalMs:120000,idleMs:120000});
  if(script==='controls_comfort_smoke.gd')await qa.runProcess(godot,[...args,'--','--resume-controls'],{cwd:root,logs,name:(gui?'gui-':'')+'controls-restart',marker:'CONTROLS_RESTART',totalMs:120000,idleMs:120000});
 }
 console.log('CONTROLS_FINAL_QA=PASS; ANDROID=NOT_TESTED');
}
if(require.main===module)run(process.argv[2]||path.resolve(__dirname,'..'),process.argv[3],{gui:process.argv.includes('--gui')}).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={run};
