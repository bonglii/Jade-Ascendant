'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process');
const {qa,runProcess}=require('./check_event_touch.cjs');
const {nativeFixtureConfig}=require('./check_player_six_fixes.cjs');
const nativeContract=require('./connection_combat_native_contract.cjs');
const sha=nativeContract.sha;
const SUITES=[
 {name:'connection',script:'connection_readiness_smoke.gd',marker:'CONNECTION_READINESS checks='},
 {name:'combat-hits',script:'connection_combat_hits.gd',marker:'CONNECTION_COMBAT_HITS checks='},
 {name:'weapons',script:'weapon_projectile_accounting.gd',marker:'PROJECTILE_ACCOUNTING checks=',totalMs:240000},
 {name:'paid-compatibility',script:'paid_gameplay_v2_smoke.gd',marker:'PAID_GAMEPLAY_V2_CHECKS=',profile:'jade_paid_v2_qa'},
 {name:'event-recovery',script:'odyssey_command_recovery_smoke.gd',marker:'ODYSSEY_COMMAND_RECOVERY=PASS;',explicitPass:true},
 {name:'event-delivery',script:'odyssey_delivery_reliability_smoke.gd',marker:'ODYSSEY_DELIVERY_RELIABILITY=PASS;',explicitPass:true},
 {name:'trials-recovery',script:'heavenly_trials_recovery_smoke.gd',marker:'HEAVENLY_TRIALS_RECOVERY checks=',profile:'jade_heavenly_trials_qa'},
 {name:'event-prewarm',script:'odyssey_prewarm_session_smoke.gd',marker:'ODYSSEY_PREWARM_SESSION checks=',profile:'jade_mail_session_qa'},
 {name:'event-hub',script:'celestial_event_hub_smoke.gd',marker:'CELESTIAL_HUB checks=',profile:'jade_celestial_board_qa'},
 {name:'pavilion-focus',script:'pavilion_focus_smoke.gd',marker:'PAVILION_FOCUS checks=',profile:'jade_pavilion_focus_qa'},
 {name:'yin-coverage',script:'yin_yang_coverage_probe.gd',marker:'YIN_COVERAGE_QA checks=',profile:'jade_yin_coverage_qa'},
 {name:'native-pavilion-hero',script:'player_six_fixes_native.gd',marker:'SIX_FIXES_UI checks=',gui:true,account:true},
 {name:'native-event',script:'connection_ui_native.gd',marker:'CONNECTION_UI_NATIVE checks=',gui:true,account:true},
 {name:'native-bosses',script:'boss_readability_review.gd',marker:'BOSS_READABILITY_REVIEW checks=',gui:true}
];
async function check(project,godot,{native=false,force=false,only=[]}={}){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/connection_combat_qa');fs.mkdirSync(logs,{recursive:true});
 const reportPath=path.join(logs,'report.json');let report={batch:'PLAYER_CONNECTION_COMBAT_20261101',phases:{},native:'PENDING',phone:'NOT_TESTED',publish:'NONE',export:'NONE'};
 if(fs.existsSync(reportPath))try{report=JSON.parse(fs.readFileSync(reportPath,'utf8').replace(/^\uFEFF/,''));}catch{/* Preserve logs; only the damaged cache record is rebuilt. */}
 const save=()=>fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');
 let currentName='preflight';
 try{
  report.native_candidate={...nativeContract.verify(root),failures:undefined};
  await runProcess(process.execPath,[path.join(root,'backend/player_identity/production_release_contract.mjs')],{cwd:root,logs,name:'production-guards',marker:'PRODUCTION_CONFIG=PASS; GATES=9;',totalMs:60000});
  const version=cp.spawnSync(godot,['--version'],{encoding:'utf8',windowsHide:true});
  if(version.error||version.status!==0||!/^4\.7\.2\./.test(version.stdout.trim()))throw Error('Godot 4.7.2 console required.');
  report.godot=version.stdout.trim();report.host_platform=process.platform;
  await qa(root,godot,{only:[]});
  const fixture=path.join(root,'.local/event_touch_qa/fixture'),config=path.join(fixture,'project.godot'),baseConfig=fs.readFileSync(config,'utf8');
  const inputs=JSON.parse(fs.readFileSync(path.join(root,'.local/event_touch_qa/cache-inputs.json'),'utf8'));
  const shared=Object.entries(inputs).filter(([p])=>!p.startsWith('tests/')).sort(([a],[b])=>a.localeCompare(b));
  const driverInputs=[__filename,require.resolve('./check_event_touch.cjs'),require.resolve('./check_player_six_fixes.cjs'),require.resolve('./connection_combat_native_contract.cjs')].map(p=>sha(fs.readFileSync(p)));
  const common=JSON.stringify({shared,driverInputs,project:sha(fs.readFileSync(path.join(root,'project.godot'))),engine:report.godot,platform:process.platform,native:report.native_candidate.aar_sha256});
  const requested=only.length?SUITES.filter(s=>only.includes(s.name)):SUITES;
  if(only.length&&requested.length!==new Set(only).size)throw Error('Unknown focused phase.');
  report.scope=only.length?'FOCUSED':'FULL';report.requested_phases=requested.map(s=>s.name);
  try{
   for(const suite of requested){
    if(suite.gui&&!native)continue;
    currentName=suite.name;
    // Follow the suite's actual test-script dependencies instead of resetting
    // unrelated passed phases when another test is repaired.
    const seen=new Set(),pending=['tests/'+suite.script];
    if(suite.gui)pending.push('tests/fixtures/six_fixes_companion_network.gd');
    if(suite.account)pending.push('tests/fixtures/six_fixes_account.gd');
    while(pending.length){
     const relative=pending.pop();if(seen.has(relative))continue;seen.add(relative);
     const source=fs.readFileSync(path.join(root,relative),'utf8');
     for(const match of source.matchAll(/res:\/\/(tests\/[A-Za-z0-9_./-]+\.gd)/g))if(!seen.has(match[1]))pending.push(match[1]);
    }
    const testInputs=[...seen].sort().map(p=>[p,inputs[p]]);

    const fingerprint=sha(Buffer.from(common+JSON.stringify({suite,testInputs})));
    const prior=report.phases[suite.name];
    const logPath=path.join(logs,suite.name+'.log');
    if(!force&&prior?.status==='PASS'&&prior.fingerprint===fingerprint&&fs.existsSync(logPath)&&sha(fs.readFileSync(logPath))===prior.log_sha256){console.log('CONNECTION_COMBAT_CACHED_PASS='+suite.name+'; INPUTS=UNCHANGED');continue;}
    let profile='jade_connection_combat_qa_'+(suite.profile||suite.name.replace(/-/g,'_'))+'_'+crypto.randomUUID();
    if(suite.gui)profile='jade_aura_live_qa_jade_six_fixes_qa_'+profile;
    let value=baseConfig.replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="'+profile+'"');
    if(suite.account)value=value.replace(/GoogleAccountManager="[^"\r\n]+"/,'GoogleAccountManager="*res://tests/fixtures/six_fixes_account.gd"');
    if(suite.gui)value=nativeFixtureConfig(value);
    fs.writeFileSync(config,value);
    const metadata=await runProcess(godot,[...(suite.gui?[]:['--headless']),'--verbose','--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',fixture,'--script','res://tests/'+suite.script],{cwd:root,logs,name:suite.name,marker:suite.marker,totalMs:suite.totalMs||180000,idleMs:65000});
    const log=fs.readFileSync(logPath,'utf8');
    if(!suite.explicitPass&&!/failures=0|FAILURES=0/.test(log))throw Error('Missing clean QA result: '+suite.name);
    if(suite.gui&&(!log.includes('NATIVE_GUI=true')||!log.includes('SIX_FIXES_OFFLINE_SERVICES=READY')))throw Error('Native GUI/offline-service evidence missing: '+suite.name);
    const line=log.split(/\r?\n/).find(v=>v.startsWith(suite.marker))||'';
    report.phases[suite.name]={status:'PASS',fingerprint,checks:Number(line.match(/(?:checks=|CHECKS=)(\d+)/)?.[1]||0),elapsed_ms:metadata.elapsed_ms,log_sha256:sha(fs.readFileSync(logPath)),native_gui:!!suite.gui};save();
   }
  }finally{fs.writeFileSync(config,baseConfig);}
  // Evidence remains available outside the retained disposable import fixture.
  for(const relative of ['.local/connection_combat_qa/boss_review','.local/connection_combat_qa/ui_review','.local/six_native_images']){
   const from=path.join(fixture,relative);if(fs.existsSync(from))fs.cpSync(from,path.join(logs,'images',path.basename(relative)),{recursive:true});
  }
  report.native=only.length?(native?'FOCUSED_PASS':'NOT_RUN_FOCUSED'):(native&&SUITES.filter(x=>x.gui).every(s=>report.phases[s.name]?.status==='PASS')?'PASS':'NOT_RUN');report.phone='NOT_TESTED';report.completed_at=new Date().toISOString();report.last_error=null;save();
  fs.rmSync(path.join(logs,'FIRST_ERROR.txt'),{force:true});
  console.log('CONNECTION_COMBAT_QA=PASS; HOST='+process.platform+'; NATIVE_GUI='+report.native+'; PHONE=NOT_TESTED; EXPORT=NONE; DEPLOY=NONE');return report;
 }catch(error){
  report.last_error={phase:currentName,message:error.message,at:new Date().toISOString()};report.native='INCOMPLETE';save();
  const file=path.join(logs,currentName+'.log'),lines=fs.existsSync(file)?fs.readFileSync(file,'utf8').split(/\r?\n/):[];
  const i=lines.findIndex(l=>/SCRIPT ERROR|Parse Error|ERROR:/.test(l));
  const summary=error.message+'\n'+(i>=0?lines.slice(i,i+20):lines.slice(-12)).join('\n')+'\nReport: '+reportPath+'\n';
  fs.writeFileSync(path.join(logs,'FIRST_ERROR.txt'),summary);console.error(summary);throw error;
 }
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3],{native:process.argv.includes('--native'),force:process.argv.includes('--force'),only:(process.argv.find(a=>a.startsWith('--only='))||'').slice(7).split(',').filter(Boolean)}).catch(e=>{console.error('CONNECTION_COMBAT_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check,SUITES};
