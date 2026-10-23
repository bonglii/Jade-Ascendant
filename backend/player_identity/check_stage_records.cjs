'use strict';
const fs=require('node:fs'),path=require('node:path');
const {qa}=require('./check_event_touch.cjs');
async function check(project,godot){
 const root=fs.realpathSync(project),remembered=path.join(root,'.local/production_native_export/godot-path.local.txt');
 godot=godot||process.env.GODOT_PATH||(fs.existsSync(remembered)?fs.readFileSync(remembered,'utf8').trim().replace(/^"|"$/g,''):'');
 // Resume immediately in the same isolated save directory, before any later suite.
 await qa(root,godot,{restart:{'stage_records_smoke.gd':'STAGE_RECORDS_RESTART'}});
 console.log('STAGE_RECORDS_QA=PASS; REAL_SAVES=UNTOUCHED; PURCHASE=NONE; DEPLOY=NONE');
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3]).catch(e=>{console.error('STAGE_RECORDS_QA_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check};
