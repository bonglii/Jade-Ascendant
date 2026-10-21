'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {qa,runProcess}=require('./check_event_touch.cjs');
async function check(project,godot){
 const root=fs.realpathSync(project),remembered=path.join(root,'.local/production_native_export/godot-path.local.txt');
 godot=godot||process.env.GODOT_PATH||(fs.existsSync(remembered)?fs.readFileSync(remembered,'utf8').trim().replace(/^"|"$/g,''):'');
 if(!godot||!fs.existsSync(godot))throw Error('Godot console path required; no publish performed.');
 await qa(root,godot);
 const fixture=path.join(root,'.local/event_touch_qa/fixture'),config=path.join(fixture,'project.godot'),logs=path.join(root,'.local/player_direction_qa');fs.mkdirSync(logs,{recursive:true});
 function profile(prefix){fs.writeFileSync(config,fs.readFileSync(config,'utf8').replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="'+prefix+'_jade_event_touch_qa_'+crypto.randomUUID()+'"'));}
 const base=['--headless','--audio-driver','Dummy','--path',fixture,'--script'];
 profile('jade_economy_qa');
 await runProcess(godot,[...base,'res://tests/economy_progression_smoke.gd'],{cwd:root,logs,name:'economy',marker:'ECONOMY_PROGRESS',idleMs:120000,totalMs:120000});
 await runProcess(godot,[...base,'res://tests/economy_progression_smoke.gd','--','--resume'],{cwd:root,logs,name:'economy-restart',marker:'ECONOMY_PROGRESS_RESTART',idleMs:120000,totalMs:120000});
 profile('jade_balance_qa');
 const old=process.env.JADE_BALANCE_AUDIT_OUTPUT;process.env.JADE_BALANCE_AUDIT_OUTPUT=path.join(logs,'build-economy-audit.json');
 try{await runProcess(godot,[...base,'res://tests/balance_audit_export.gd'],{cwd:root,logs,name:'build-audit',marker:'BALANCE_AUDIT_EXPORT',idleMs:120000,totalMs:120000});}finally{if(old===undefined)delete process.env.JADE_BALANCE_AUDIT_OUTPUT;else process.env.JADE_BALANCE_AUDIT_OUTPUT=old;}
 const audit=JSON.parse(fs.readFileSync(path.join(logs,'build-economy-audit.json'),'utf8'));
 if(audit.stages.length!==26||audit.sets.length!==11||audit.weapons.length!==44||audit.permanent_weapon_progression.map(x=>x.total_stones_from_level1).join(',')!=='720,2470,5220,8970,13720')throw Error('Catalog/audit contract differs. Review actual evidence before publishing.');
 console.log('PLAYER_DIRECTION_QA=PASS; REAL_SAVES=UNTOUCHED; PURCHASE=NONE; DEPLOY=NONE');
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3]).catch(e=>{console.error('PLAYER_DIRECTION_QA_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check};
