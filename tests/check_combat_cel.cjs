'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),qa=require('../backend/player_identity/check_event_touch.cjs');
async function run(project,godot){
 const root=path.resolve(project),logs=path.join(root,'.local/combat_cel_recovery'),fixture=path.join(logs,'fixture');godot=path.resolve(godot);
 await qa.qa(root,godot,{only:[],logs});process.env.JADE_YIN_REPORT=path.join(logs,'yin-yang-coverage.json');
 for(const [script,marker,guard]of [['combat_cel_smoke.gd','COMBAT_CEL_QA','jade_combat_cel_qa'],['yin_yang_coverage_probe.gd','YIN_COVERAGE_QA','jade_yin_coverage_qa'],['run_report_smoke.gd','RUN_REPORT','jade_report_qa'],['combat_skill_polish_smoke.gd','COMBAT_SKILL_POLISH','jade_combat_pass_qa']]){
  const p=path.join(fixture,'project.godot');fs.writeFileSync(p,fs.readFileSync(p,'utf8').replace(/^config\/custom_user_dir_name=.*$/m,'config/custom_user_dir_name="jade_event_touch_qa_'+guard+'_'+crypto.randomUUID()+'"'));
  await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script],{cwd:root,logs,name:script,marker,totalMs:120000,idleMs:120000});
 }
 console.log('COMBAT_CEL_RECOVERY=PASS; ANDROID=NOT_TESTED');
}
if(require.main===module)run(process.argv[2]||path.resolve(__dirname,'..'),process.argv[3]).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={run};
