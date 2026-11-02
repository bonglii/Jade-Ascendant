'use strict';
// Focused client regressions only; all gameplay saves live in a disposable fixture.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {qa,runProcess}=require('./check_event_touch.cjs');
const {resolveGodot}=require('./check_tester_reliability.cjs');
const suites=[
 ['player_followup_1_7_smoke.gd','PLAYER_FOLLOWUP checks=','jade_player_followup_qa',false],
 ['level_up_full_heal_smoke.gd','LEVEL_UP_FULL_HEAL','jade_level_heal_qa',true],
 ['player_direction_smoke.gd','PLAYER_DIRECTION','jade_event_touch_qa',false],
 ['hero_equipment_progression_smoke.gd','HERO_RULES_CHECKS=','jade_hero_qa',true],
 ['stage_records_smoke.gd','STAGE_RECORDS','jade_event_touch_qa',false],
 ['heavenly_trials_smoke.gd','HEAVENLY_TRIALS checks=','jade_heavenly_trials_qa',false]
];
async function check(project,godot,{only=null}={}){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/player_followup_qa');
 godot=resolveGodot(root,godot);
 // Incremental source sync/import reuses the existing cache. Actual user saves are never opened.
 await qa(root,godot,{only:[],logs});
 const fixture=path.join(logs,'fixture'),file=path.join(fixture,'project.godot'),original=fs.readFileSync(file,'utf8');
 try{
  const selected=only?suites.filter(([script])=>only.includes(script)):suites;
  if(only&&selected.length!==only.length)throw Error('Unknown focused follow-up suite');
  for(const [script,marker,prefix,restart]of selected){
   fs.writeFileSync(file,original.replace(/^config\/custom_user_dir_name=.*$/m,'config/custom_user_dir_name="jade_event_touch_qa_'+prefix+'_'+crypto.randomUUID()+'"'));
   for(const resume of restart?[false,true]:[false]){
    const pass=resume?(script==='level_up_full_heal_smoke.gd'?'LEVEL_UP_FULL_HEAL_RESTART':'HERO_RULES_RESTART_CHECKS='):marker;
    await runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script,...(resume?['--','--resume']:[])],{cwd:root,logs,name:script+(resume?'-restart':''),marker:pass,totalMs:120000,idleMs:100000});
    const log=fs.readFileSync(path.join(logs,script+(resume?'-restart':'')+'.log'),'utf8');
    if(/ObjectDB instances were leaked|resources still in use at exit/.test(log))throw Error('Runtime teardown leaked objects/resources: '+script);
   }
  }
  await runProcess(process.execPath,['backend/player_identity/production_release_contract.mjs'],{cwd:root,logs,name:'production-config',marker:'PRODUCTION_CONFIG=PASS',totalMs:30000});
 }finally{fs.writeFileSync(file,original);}
 console.log('PLAYER_FOLLOWUP_QA=PASS; ANDROID=NOT_TESTED; PURCHASE=NONE; DEPLOY=NONE; REAL_SAVES=UNTOUCHED');
 return{pass:true,suites:only||suites.map(x=>x[0]),android_tested:false};
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3]).catch(e=>{console.error('PLAYER_FOLLOWUP_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check,suites};
