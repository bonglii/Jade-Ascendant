'use strict';
const fs=require('node:fs'),path=require('node:path');
const {qa,runProcess}=require('./check_event_touch.cjs');
const serverTests=[...require('./check_player_flow.cjs').serverTests,'backend/player_identity/heavenly_trials.test.mjs','backend/monetization/cloudflare/heavenly_trials.test.mjs','backend/monetization/cloudflare/tests/paid_gameplay_v2.test.mjs','backend/monetization/tests/purchase_authority.test.mjs','backend/monetization/tests/m1b_client_source_boundary.test.mjs'];
async function check(project,godot){
 const root=fs.realpathSync(project),remembered=path.join(root,'.local/production_native_export/godot-path.local.txt');
 godot=godot||process.env.GODOT_PATH||(fs.existsSync(remembered)?fs.readFileSync(remembered,'utf8').trim().replace(/^"|"$/g,''):'');
 const logs=path.join(root,'.local/heavenly_trials_qa');fs.mkdirSync(logs,{recursive:true});
 await runProcess(process.execPath,['--test','--test-concurrency=1',...serverTests],{cwd:root,logs,name:'server',totalMs:180000,idleMs:60000});
 // Existing affected event/mobile/pavilion surfaces plus the weekly runtime tests.
 await qa(root,godot,{only:['celestial_event_hub_smoke.gd','event_scroll_surface_smoke.gd','player_direction_smoke.gd']});
 const fixture=path.join(root,'.local/event_touch_qa/fixture'),cfg=path.join(fixture,'project.godot');
 fs.writeFileSync(cfg,fs.readFileSync(cfg,'utf8').replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="jade_event_touch_qa_jade_heavenly_trials_qa"'));
 for(const [script,marker] of [['heavenly_trials_smoke.gd','HEAVENLY_TRIALS checks='],['heavenly_trials_recovery_smoke.gd','HEAVENLY_TRIALS_RECOVERY checks=']])await runProcess(godot,['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script],{cwd:root,logs,name:script,marker,idleMs:100000,totalMs:100000});
 console.log('HEAVENLY_TRIALS_QA=PASS; REAL_SAVES=UNTOUCHED; PURCHASE=NONE; DEPLOY=NONE');
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3]).catch(e=>{console.error('HEAVENLY_TRIALS_QA_STOPPED: '+e.message);process.exitCode=1});
module.exports={check,serverTests};
