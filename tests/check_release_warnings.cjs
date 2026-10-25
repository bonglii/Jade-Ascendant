'use strict';
const fs=require('node:fs'),path=require('node:path'),qa=require('../backend/player_identity/check_event_touch.cjs');
const warnings=['integer_division','shadowed_global_identifier','shadowed_variable','incompatible_ternary','confusable_local_declaration','unassigned_variable'];
async function run(project,godot){
 const root=path.resolve(project),logs=path.join(root,'.local/event_operations_qa');godot=path.resolve(godot);
 await qa.qa(root,godot,{only:[],logs});
 const fixture=path.join(logs,'fixture'),file=path.join(fixture,'project.godot'),original=fs.readFileSync(file,'utf8');
 try{
  let config=original;
  for(const key of warnings)config=config.replace(new RegExp('^gdscript/warnings/'+key+'=.*$','gm'),'');
  config=config.replace('[debug]','[debug]\n'+warnings.map(k=>'gdscript/warnings/'+k+'=2').join('\n'));
  fs.writeFileSync(file,config);
  await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/release_warning_audit.gd'],{cwd:root,logs,name:'release-warnings',marker:'RELEASE_WARNING_AUDIT',totalMs:120000,idleMs:120000});
 }finally{fs.writeFileSync(file,original);}
 await qa.runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/compass_pursuit_smoke.gd'],{cwd:root,logs,name:'warning-compass-regression',marker:'COMPASS_PURSUIT',totalMs:120000,idleMs:120000});
 console.log('RELEASE_WARNING_QA=PASS; WARNING_LEVELS=STRICT; GAMEPLAY=UNCHANGED; ANDROID=NOT_TESTED');
}
if(require.main===module)run(process.argv[2]||path.resolve(__dirname,'..'),process.argv[3]).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={run};
