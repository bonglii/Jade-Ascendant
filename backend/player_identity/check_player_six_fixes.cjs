'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process');
const {qa,runProcess}=require('./check_event_touch.cjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const LEGACY_CHECKER_SHA='890447d332be6fc08170462c450f26308e4cea34bc6ea6e5d7928c55e84df5ee';
const ISOLATOR='tests/fixtures/six_fixes_companion_network.gd';
const OFFLINE_MARKER='SIX_FIXES_OFFLINE_SERVICES=READY';
function nativeFixtureConfig(value){
 let matches=0,inAutoload=false;
 const lines=value.split(/\r?\n/).map(line=>{
  const section=line.trim().match(/^\[([^\]]+)\]$/);
  if(section)inAutoload=section[1]==='autoload';
  if(inAutoload&&/^\s*CompanionNetwork\s*=/.test(line)){
   matches++;
   return 'CompanionNetwork="*res://'+ISOLATOR+'"';
  }
  return line;
 });
 if(matches!==1)throw Error('Native QA requires exactly one CompanionNetwork autoload; production project was not changed.');
 return lines.join('\n');
}
function legacyChecker(root){
 const base=path.join(root,'.local/player_six_fixes_install/backups');
 if(!fs.existsSync(base))return null;
 for(const name of fs.readdirSync(base).sort().reverse().slice(0,20)){
  const file=path.join(base,name,'backend/player_identity/check_player_six_fixes.cjs');
  if(fs.existsSync(file)&&fs.statSync(file).size<65536){const bytes=fs.readFileSync(file);if(sha(bytes)===LEGACY_CHECKER_SHA)return bytes;}
 }
 return null;
}
function reuseLegacyHeadless(root,report,before,after,projectBytes,dependencyBytes,versionBytes){
 const noReuse={phases:{},cache_migration:null};
 try{
  if(!before||!report.fingerprint||!report.phases)return noReuse;
  const old=JSON.parse(before),current=JSON.parse(after),changed=[...new Set([...Object.keys(old),...Object.keys(current)])].filter(key=>old[key]!==current[key]).sort();
  if(changed.some(key=>key!==ISOLATOR))return noReuse;
  const checker=legacyChecker(root);
  if(!checker||sha(Buffer.concat([before,projectBytes,checker,dependencyBytes,versionBytes]))!==report.fingerprint)return noReuse;
  const phases={};for(const name of ['combat','ui','paid-compatibility'])if(report.phases[name]==='PASS')phases[name]='PASS';
  if(!Object.keys(phases).length)return noReuse;
  return {phases,cache_migration:{legacy_checker_sha256:LEGACY_CHECKER_SHA,retained_phases:Object.keys(phases),changed_input_paths:changed,native_reset:true}};
 }catch{return noReuse;}
}
async function check(project,godot,{native=false,force=false}={}){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/player_six_fixes_qa');fs.mkdirSync(logs,{recursive:true});
 const reportPath=path.join(logs,'report.json');let report={};if(fs.existsSync(reportPath))report=JSON.parse(fs.readFileSync(reportPath,'utf8').replace(/^\uFEFF/,''));
 try{
  const cacheFile=path.join(root,'.local/event_touch_qa/cache-inputs.json'),before=fs.existsSync(cacheFile)?fs.readFileSync(cacheFile):null;
  await qa(root,godot,{only:[]});
  const fixture=path.join(root,'.local/event_touch_qa/fixture'),config=path.join(fixture,'project.godot'),baseConfig=fs.readFileSync(config,'utf8');
  const version=cp.spawnSync(godot,['--version'],{encoding:'utf8',windowsHide:true});
  if(version.status!==0||!/^4\.7\.2\./.test(version.stdout.trim()))throw Error('Godot 4.7.2 console required.');
  const after=fs.readFileSync(cacheFile),projectBytes=fs.readFileSync(path.join(root,'project.godot')),dependencyBytes=fs.readFileSync(require.resolve('./check_event_touch.cjs')),versionBytes=Buffer.from(version.stdout);
  const fingerprint=sha(Buffer.concat([after,projectBytes,fs.readFileSync(__filename),dependencyBytes,versionBytes]));
  if(force||report.fingerprint!==fingerprint){
   // Only GUI service isolation changed. Reuse legacy headless passes only after
   // authenticating their exact old fingerprint against a verified source backup.
   const reuse=force?{phases:{},cache_migration:null}:reuseLegacyHeadless(root,report,before,after,projectBytes,dependencyBytes,versionBytes);
   report={batch:'PLAYER_SIX_FIXES_20261029',qa_revision:'R4_NATIVE_QA_ISOLATION_20261031',fingerprint,godot:version.stdout.trim(),phases:reuse.phases,cache_migration:reuse.cache_migration,native:'PENDING',phone:'NOT_TESTED',publish:'NONE',export:'NONE'};
   if(reuse.cache_migration)console.log('SIX_FIXES_LEGACY_CACHED_PASS='+Object.keys(reuse.phases).join(',')+'; VERIFIED_INPUTS=UNCHANGED');
  }
  const save=()=>fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');
  async function phase(name,script,marker,{gui=false,account=false,profile='jade_six_fixes_qa'}={}){
   if(report.phases[name]==='PASS'){console.log('SIX_FIXES_CACHED_PASS='+name+'; INPUTS=UNCHANGED');return;}
   let value=baseConfig.replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="jade_aura_live_qa_'+profile+'_'+crypto.randomUUID()+'"');
   if(account)value=value.replace(/GoogleAccountManager="[^"\r\n]+"/,'GoogleAccountManager="*res://tests/fixtures/six_fixes_account.gd"');
   if(gui)value=nativeFixtureConfig(value);
   fs.writeFileSync(config,value);
   await runProcess(godot,[...(gui?[]:['--headless']),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',fixture,'--script','res://tests/'+script],{cwd:root,logs,name,marker,totalMs:180000,idleMs:60000});
   const log=fs.readFileSync(path.join(logs,name+'.log'),'utf8');
   if(!/failures=0|FAILURES=0/.test(log))throw Error('Missing clean QA result: '+name);
   if(gui&&!log.includes('NATIVE_GUI=true'))throw Error('Native GUI evidence missing: '+name);
   if(gui&&!log.includes(OFFLINE_MARKER))throw Error('Native QA offline service evidence missing: '+name);
   report.phases[name]='PASS';save();
  }
  await phase('combat','player_six_fixes_combat.gd','SIX_FIXES_COMBAT checks=');
  await phase('ui','player_six_fixes_ui.gd','SIX_FIXES_UI checks=',{account:true});
  await phase('paid-compatibility','paid_gameplay_v2_smoke.gd','PAID_GAMEPLAY_V2_CHECKS=',{profile:'jade_paid_v2_qa'});
  if(native){
   await phase('native-ui','player_six_fixes_native.gd','SIX_FIXES_UI checks=',{gui:true,account:true});
   await phase('native-combat','player_six_fixes_combat_native.gd','SIX_FIXES_COMBAT checks=',{gui:true});
   report.native='PASS';save();
  }
  for(const [src,dest] of [['.local/six_review','review-records'],['.local/six_native_images','native-ui'],['.local/six_native_combat','native-combat']]){
   const folder=path.join(fixture,src);if(fs.existsSync(folder))fs.cpSync(folder,path.join(logs,dest),{recursive:true});
  }
  delete report.last_error;delete report.failed_at;
  const first=path.join(logs,'FIRST_ERROR.txt');if(fs.existsSync(first)){fs.copyFileSync(first,path.join(logs,'PREVIOUS_ERROR.txt'));fs.rmSync(first);}
  report.completed_at=new Date().toISOString();save();
  console.log('PLAYER_SIX_QA=PASS; NATIVE_GUI='+(report.native==='PASS')+'; PHONE=NOT_TESTED; PUBLISH=NONE; EXPORT=NONE');return report;
 }catch(error){
  report.last_error=error.message;report.failed_at=new Date().toISOString();fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');
  const recent=fs.readdirSync(logs).filter(n=>n.endsWith('.log')).map(n=>({p:path.join(logs,n),t:fs.statSync(path.join(logs,n)).mtimeMs})).sort((a,b)=>b.t-a.t)[0];
  const lines=recent?fs.readFileSync(recent.p,'utf8').split(/\r?\n/):[],i=lines.findIndex(l=>/SCRIPT ERROR|ERROR:/.test(l));
  const summary=error.message+'\n'+(i>=0?lines.slice(i,i+20):lines.slice(-15)).join('\n')+'\nReport: '+reportPath+'\n';
  fs.writeFileSync(path.join(logs,'FIRST_ERROR.txt'),summary);console.error(summary);throw error;
 }
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3],{native:process.argv.includes('--native'),force:process.argv.includes('--force')}).catch(e=>{console.error('PLAYER_SIX_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check,nativeFixtureConfig,reuseLegacyHeadless};
