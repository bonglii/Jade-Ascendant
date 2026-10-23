'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawn}=require('node:child_process');
const tests=[['compass_pursuit_smoke.gd','COMPASS_PURSUIT'],['interface_consistency_smoke.gd','INTERFACE_CONSISTENCY'],['event_scroll_surface_smoke.gd','EVENT_SCROLL_SURFACE'],['celestial_event_hub_smoke.gd','CELESTIAL_HUB'],['board_polish_interaction_smoke.gd','BOARD_POLISH_INTERACTION'],['player_flow_consistency_smoke.gd','PLAYER_FLOW_CONSISTENCY'],['player_direction_smoke.gd','PLAYER_DIRECTION'],['stage_records_smoke.gd','STAGE_RECORDS'],['release_polish_smoke.gd','RELEASE_POLISH']];
const clean=s=>s.replace(/\x1b\[[0-9;]*m/g,'');
async function runProcess(executable,args,{cwd,logs,name,marker='',idleMs=300000,totalMs=1200000,heartbeatMs=15000}={}){
 const started=Date.now(),logPath=path.join(logs,name+'.log'),metaPath=path.join(logs,name+'.json');
 fs.mkdirSync(logs,{recursive:true});fs.writeFileSync(logPath,'');console.log('EVENT_TOUCH_QA='+name);
 let lastOutput=started,lastLine='',tail='',errorLines='',outputBytes=0,reason='',childError=null;
 const result=await new Promise(resolve=>{
  const child=spawn(executable,args,{cwd,windowsHide:true,stdio:['ignore','pipe','pipe']});
  const timer=setInterval(()=>{
   const now=Date.now();
   if(!reason&&(now-started>=totalMs||now-lastOutput>=idleMs)){
    reason=now-started>=totalMs?'TOTAL_TIMEOUT':'NO_OUTPUT_TIMEOUT';console.error('EVENT_TOUCH_QA_STOP='+reason+'; CACHE_RETAINED=true');child.kill();
   }
  },Math.min(1000,Math.max(20,idleMs/4)));
  const heartbeat=setInterval(()=>console.log('EVENT_TOUCH_QA_PROGRESS='+name+'; ELAPSED_SECONDS='+Math.floor((Date.now()-started)/1000)+'; '+lastLine.slice(-160)),heartbeatMs);
  function output(bytes){
   outputBytes+=bytes.length;lastOutput=Date.now();fs.appendFileSync(logPath,bytes);
   const text=clean(bytes.toString('utf8'));tail=(tail+text).slice(-8192);
   const lines=text.split(/[\r\n]/).filter(s=>s.trim());if(lines.length)lastLine=lines.at(-1).trim();
   if(/SCRIPT ERROR|Parse Error|ERROR:/.test(tail))errorLines=tail;
  }
  child.stdout.on('data',output);child.stderr.on('data',output);
  child.on('error',e=>{childError=e;});
  child.on('close',(code,signal)=>{clearInterval(timer);clearInterval(heartbeat);resolve({code,signal});});
 });
 const text=clean(fs.readFileSync(logPath,'utf8'));
 if(!reason)reason=childError?'PROCESS_START_FAILED':result.code!==0?'PROCESS_EXIT_'+result.code:errorLines?'GODOT_ERROR':marker&&!text.includes(marker)?'MISSING_PASS_MARKER':'';
 const metadata={name,executable,args,elapsed_ms:Date.now()-started,exit_code:result.code,signal:result.signal,process_error:childError?{code:childError.code,message:childError.message}:null,reason,output_bytes:outputBytes,last_output:lastLine,log:logPath};
 fs.writeFileSync(metaPath,JSON.stringify(metadata,null,2)+'\n');
 if(reason||childError||result.code!==0||errorLines||marker&&!text.includes(marker)){
  console.error((errorLines||tail).slice(-3000));
  throw Error(reason+'; elapsed '+Math.round(metadata.elapsed_ms/1000)+'s; logs: '+logPath+' and '+metaPath+'; retry retains import cache');
 }
 if(marker)console.log(text.split(/\r?\n/).find(line=>line.startsWith(marker)));
 return metadata;
}
function syncFixture(root,fixture,stateFile){
 let previous={};if(fs.existsSync(stateFile))previous=JSON.parse(fs.readFileSync(stateFile,'utf8'));
 const current={};let copied=0;
 function scan(relative){
  const source=path.join(root,relative),stat=fs.lstatSync(source);
  if(stat.isSymbolicLink())return;
  if(stat.isDirectory()){
   if(['.godot','.git','node_modules'].includes(path.basename(source)))return;
   for(const child of fs.readdirSync(source).sort())scan(path.join(relative,child));return;
  }
  if(/\.(?:aar|jar|so|mp4|webm)$/i.test(relative))return;
  const bytes=fs.readFileSync(source),hash=crypto.createHash('sha256').update(bytes).digest('hex'),key=relative.split(path.sep).join('/'),dest=path.join(fixture,relative);
  current[key]=hash;
  if(previous[key]!==hash||!fs.existsSync(dest)){fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes);copied++;}
 }
 for(const dir of ['assets','scripts','scenes','tests','addons','release'])scan(dir);
 for(const relative of Object.keys(previous))if(!(relative in current)){
  if(relative.includes('..')||path.isAbsolute(relative))throw Error('Invalid cached QA path');
  fs.rmSync(path.join(fixture,relative),{force:true});
 }
 const temp=stateFile+'.tmp';fs.writeFileSync(temp,JSON.stringify(current));fs.renameSync(temp,stateFile);
 return copied;
}
async function qa(project,godot,options={}){
 const root=fs.realpathSync(project),remembered=path.join(root,'.local/production_native_export/godot-path.local.txt');
 godot=godot||process.env.GODOT_PATH||(fs.existsSync(remembered)?fs.readFileSync(remembered,'utf8').trim().replace(/^"|"$/g,''):'');
 if(!godot||!fs.existsSync(godot))throw Error('Godot console executable not found. Run with an explicit Godot path; no publish performed.');
 const logs=options.logs||path.join(root,'.local/event_touch_qa');fs.mkdirSync(logs,{recursive:true});
 const fixture=options.fixture||path.join(logs,'fixture');fs.mkdirSync(fixture,{recursive:true});
 console.log('EVENT_TOUCH_QA_FIXTURE='+fixture+'; CACHE=RETAINED_FOR_RETRY');
 const original=fs.readFileSync(path.join(root,'project.godot'),'utf8');
 function config(){
  let text=original.replace('Firebase="*uid://bfps2e72dlnwq"','Firebase="*res://addons/GodotFirebaseAndroid/Firebase.gd"')
   .replace(/^\s*config\/(?:use_custom_user_dir|custom_user_dir_name)\s*=.*$/gm,'')
   .replace(/config\/name="[^"\r\n]*"/,'config/name="jade-event-touch-qa"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="jade_celestial_board_qa_jade_event_touch_qa_'+crypto.randomUUID()+'"')
   .replace(/enabled=PackedStringArray\([^\r\n]*\)/,'enabled=PackedStringArray()')
   .replace(/(renderer\/rendering_method[^=]*)=[^\r\n]*/g,'$1="gl_compatibility"');
  text+='\n[input_devices]\npointing/emulate_touch_from_mouse=true\n\n[debug]\ngdscript/warnings/enable=true\ngdscript/warnings/shadowed_variable_base_class=2\n';
  fs.writeFileSync(path.join(fixture,'project.godot'),text);
 }
 if(!options.fixture){
  console.log('EVENT_TOUCH_QA_SYNC_FILES='+syncFixture(root,fixture,path.join(logs,'cache-inputs.json')));
  config();await runProcess(godot,['--headless','--audio-driver','Dummy','--editor','--path',fixture,'--import','--quit'],{cwd:root,logs,name:'import',idleMs:300000,totalMs:1200000});
 }
 const selected=options.only?tests.filter(([name])=>options.only.includes(name)):tests;
 if(options.only&&selected.length!==options.only.length)throw Error("Unknown focused QA suite");
 for(const [script,marker]of selected){
  config();const args=['--headless','--audio-driver','Dummy','--path',fixture,'--script','res://tests/'+script];
  await runProcess(godot,args,{cwd:root,logs,name:script,marker,idleMs:100000,totalMs:100000});
  const restartMarker=options.restart?.[script];
  if(restartMarker)await runProcess(godot,[...args,'--','--resume'],{cwd:root,logs,name:script+'-restart',marker:restartMarker,idleMs:100000,totalMs:100000});
 }
 console.log('EVENT_TOUCH_QA=PASS; REAL_SAVES=UNTOUCHED; PURCHASE=NONE');return {pass:true,tests:tests.length};
}
if(require.main===module)qa(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3]).catch(e=>{console.error('EVENT_TOUCH_QA_STOPPED: '+e.message);process.exitCode=1;});
module.exports={qa,runProcess,syncFixture};
