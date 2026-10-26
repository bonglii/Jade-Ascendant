'use strict';
// Reuses the shipped disposable-fixture/import watchdog. Never opens real saves.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {qa,runProcess}=require('./check_event_touch.cjs');
const suites=[
 ['tester_reliability_smoke.gd','TESTER_RELIABILITY checks=','jade_tester_reliability_qa'],
 ['tester_surface_gestures_smoke.gd','TESTER_SURFACE checks=','jade_tester_surface_qa'],
 ['server_jade_delivery_smoke.gd','SERVER_JADE_DELIVERY checks=','jade_server_delivery_qa'],
 ['paid_gameplay_v2_smoke.gd','PAID_GAMEPLAY_V2_CHECKS=','jade_paid_v2_qa'],
 ['pavilion_sanctum_smoke.gd','GACHA_NATIVE_QA checks=','jade_gacha_qa'],
 ['compass_pursuit_smoke.gd','COMPASS_PURSUIT checks=','jade_event_touch_qa'],
 ['crowd_performance_smoke.gd','CROWD_PERFORMANCE_CHECKS=','jade_crowd_qa'],
 ['odyssey_prewarm_session_smoke.gd','ODYSSEY_PREWARM_SESSION checks=','jade_mail_session_qa'],
 ['heavenly_trials_smoke.gd','HEAVENLY_TRIALS checks=','jade_heavenly_trials_qa'],
];
async function server(root,logs){
 const folder=path.join(root,'backend/monetization/cloudflare/tests');
 const tests=fs.readdirSync(folder).filter(s=>s.endsWith('.test.mjs')).sort().map(s=>'backend/monetization/cloudflare/tests/'+s);
 tests.push('backend/monetization/tests/purchase_authority.test.mjs','backend/monetization/tests/runtime_adapters.test.mjs','backend/player_identity/production_release_contract.test.mjs','backend/player_identity/tester_batch_tools.test.cjs');
 await runProcess(process.execPath,['backend/player_identity/production_release_contract.mjs'],{cwd:root,logs,name:'production-contract',marker:'PRODUCTION_CONFIG=PASS',totalMs:30000});
 await runProcess(process.execPath,['--test','--test-concurrency=4',...tests],{cwd:root,logs,name:'current-backend',totalMs:180000,marker:''});
 const text=fs.readFileSync(path.join(logs,'current-backend.log'),'utf8');
 if(!/(?:#|ℹ) fail 0/.test(text))throw Error('Current executable backend suite did not finish with zero failures.');
}
function resolveGodot(root,godot){
 const remembered=path.join(root,'.local/production_native_export/godot-path.local.txt');
 godot=godot||process.env.GODOT_PATH||(fs.existsSync(remembered)?fs.readFileSync(remembered,'utf8').trim().replace(/^"|"$/g,''):'');
 if(!godot||!fs.existsSync(godot))throw Error('Set GODOT_PATH to the existing Godot 4.7.2 console executable, or pass it as argument 2.');
 const result=require('node:child_process').spawnSync(godot,['--version'],{encoding:'utf8',windowsHide:true});
 if(result.status!==0||!/^4\.7\.2\./.test(result.stdout.trim()))throw Error('Use the installed Godot 4.7.2 console executable.');
 return fs.realpathSync(godot);
}
async function check(project,godot,{native=false,serverOnly=false}={}){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/tester_reliability_qa');fs.mkdirSync(logs,{recursive:true});
 if(!native)await server(root,logs);
 if(serverOnly){console.log('TESTER_SERVER_QA=PASS; DEPLOY=NONE');return;}
 godot=resolveGodot(root,godot);
 await qa(root,godot,{only:[]});
 const fixture=path.join(root,'.local/event_touch_qa/fixture'),config=path.join(fixture,'project.godot'),original=fs.readFileSync(config,'utf8');
 const selected=native?[
  suites[1],['pavilion_secrecy_render_smoke.gd','RARITY_PIXEL_PROOF blue_Rare_vs_purple_Epic=different PASS','jade_gacha_qa']
 ]:suites;
 try{
  for(const [script,marker,prefix]of selected){
   fs.writeFileSync(config,original.replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="'+prefix+'_'+crypto.randomUUID()+'"'));
   await runProcess(godot,[...(native?[]:['--headless']),'--verbose','--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',fixture,'--script','res://tests/'+script],{cwd:root,logs,name:script+(native?'-native':''),marker,totalMs:150000,idleMs:100000});
  }
 }finally{fs.writeFileSync(config,original);}
 console.log('TESTER_RELIABILITY_QA=PASS; NATIVE_GUI='+native+'; PHONE=NOT_TESTED; PURCHASE=NONE; DEPLOY=NONE; SAVES=UNTOUCHED');
 return{pass:true,native};
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3],{native:process.argv.includes('--native'),serverOnly:process.argv.includes('--server-only')}).catch(e=>{console.error('TESTER_QA_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check,suites,server,resolveGodot};
