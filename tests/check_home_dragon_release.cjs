'use strict';
const fs=require('node:fs'),path=require('node:path'),qa=require('../backend/player_identity/check_event_touch.cjs');
async function run(project,godot,{gui=false}={}){
 const root=path.resolve(project),logs=path.join(root,'.local/home_dragon_qa');godot=path.resolve(godot);
 await qa.qa(root,godot,{only:[],logs});
 const fixture=path.join(logs,'fixture');
 await qa.runProcess(godot,[...(gui?[]:['--headless']),'--audio-driver','Dummy','--path',fixture,'--script','res://tests/home_dragon_release_smoke.gd'],{cwd:root,logs,name:gui?'home-dragon-gui':'home-dragon',marker:'HOME_DRAGON_RELEASE',totalMs:120000,idleMs:120000});
 if(!gui){
  for(const [script,marker]of [['compass_pursuit_smoke.gd','COMPASS_PURSUIT'],['final_mobile_polish_smoke.gd','FINAL_MOBILE_POLISH']])await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script],{cwd:root,logs,name:script,marker,totalMs:120000,idleMs:120000});
  const file=path.join(fixture,'project.godot'),original=fs.readFileSync(file,'utf8');
  try{
   const keys=['integer_division','shadowed_global_identifier','shadowed_variable','incompatible_ternary','confusable_local_declaration','unassigned_variable'];
   let config=original;for(const key of keys)config=config.replace(new RegExp('^gdscript/warnings/'+key+'=.*$','gm'),'');
   config=config.replace('[debug]','[debug]\n'+keys.map(key=>'gdscript/warnings/'+key+'=2').join('\n'));fs.writeFileSync(file,config);
   await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/release_warning_audit.gd'],{cwd:root,logs,name:'home-dragon-strict',marker:'RELEASE_WARNING_AUDIT',totalMs:120000,idleMs:120000});
  }finally{fs.writeFileSync(file,original);}
 }
 console.log('HOME_DRAGON_QA=PASS; GATES=UNCHANGED; ANDROID=NOT_TESTED');
}
if(require.main===module)run(process.argv[2]||path.resolve(__dirname,'..'),process.argv[3],{gui:process.argv.includes('--gui')}).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={run};
