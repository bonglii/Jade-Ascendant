'use strict';
const fs=require('node:fs'),path=require('node:path');
const {qa,runProcess}=require('./check_event_touch.cjs');
async function check(project,godot){
 const root=fs.realpathSync(project),remembered=path.join(root,'.local/production_native_export/godot-path.local.txt');
 godot=godot||process.env.GODOT_PATH||(fs.existsSync(remembered)?fs.readFileSync(remembered,'utf8').trim().replace(/^"|"$/g,''):'');
 await qa(root,godot);
 const fixture=path.join(root,'.local/event_touch_qa/fixture'),logs=path.join(root,'.local/stage_records_qa');fs.mkdirSync(logs,{recursive:true});
 await runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/stage_records_smoke.gd','--','--resume'],{cwd:root,logs,name:'records-restart',marker:'STAGE_RECORDS_RESTART',idleMs:90000,totalMs:90000});
 console.log('STAGE_RECORDS_QA=PASS; REAL_SAVES=UNTOUCHED; PURCHASE=NONE; DEPLOY=NONE');
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3]).catch(e=>{console.error('STAGE_RECORDS_QA_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check};
