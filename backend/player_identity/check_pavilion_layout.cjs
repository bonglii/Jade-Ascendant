'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process');
const {qa,runProcess}=require('./check_event_touch.cjs');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
async function check(project,godot,{native=false,force=false}={}){
 const root=fs.realpathSync(project),logs=path.join(root,'.local/pavilion_layout_repair');fs.mkdirSync(logs,{recursive:true});
 const reportPath=path.join(logs,'report.json');let report={};
 if(fs.existsSync(reportPath))report=JSON.parse(fs.readFileSync(reportPath,'utf8').replace(/^\uFEFF/,''));
 try{
  await qa(root,godot,{only:[]});
  const fixture=path.join(root,'.local/event_touch_qa/fixture'),config=path.join(fixture,'project.godot');
  fs.writeFileSync(config,fs.readFileSync(config,'utf8').replace(/config\/custom_user_dir_name="[^"\r\n]*"/,'config/custom_user_dir_name="jade_aura_live_qa_layout_repair_'+crypto.randomUUID()+'"'));
  const version=cp.spawnSync(godot,['--version'],{encoding:'utf8',windowsHide:true});
  if(version.status!==0||!/^4\.7\.2\./.test(version.stdout.trim()))throw Error('Godot 4.7.2 console required.');
  const fingerprint=sha(Buffer.concat([fs.readFileSync(path.join(root,'.local/event_touch_qa/cache-inputs.json')),fs.readFileSync(path.join(root,'project.godot')),fs.readFileSync(__filename),fs.readFileSync(require.resolve('./check_event_touch.cjs')),Buffer.from(version.stdout)]));
  if(force||report.fingerprint!==fingerprint)report={batch:'PAVILION_LAYOUT_REPAIR_2026-10-28',fingerprint,godot:version.stdout.trim(),headless:'PENDING',safe_area:'PENDING',native:'PENDING',phone:'NOT_TESTED',publish:'NONE',export:'NONE'};
  const save=()=>fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');
  const headless=['--headless','--verbose','--audio-driver','Dummy','--path',fixture,'--script','res://tests/pavilion_layout_review.gd'];
  if(report.headless!=='PASS'){
   await runProcess(godot,headless,{cwd:root,logs,name:'layout-all-pages',marker:'PAVILION_LAYOUT checks=',totalMs:130000});report.headless='PASS';save();
  }else console.log('PAVILION_REPAIR_LAYOUT=CACHED_PASS; SOURCE_HASHES=UNCHANGED');
  if(report.safe_area!=='PASS'){
   await runProcess(godot,[...headless,'--','--safe-area'],{cwd:root,logs,name:'layout-safe-area',marker:'PAVILION_LAYOUT checks=',totalMs:70000});report.safe_area='PASS';save();
  }else console.log('PAVILION_REPAIR_SAFE_AREA=CACHED_PASS; SOURCE_HASHES=UNCHANGED');
  if(native&&report.native!=='PASS'){
   await runProcess(godot,['--verbose','--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',fixture,'--script','res://tests/aura_pavilion_integration_smoke.gd'],{cwd:root,logs,name:'native-aura-and-swipe',marker:'AURA_PAVILION checks=',totalMs:130000});
   if(!fs.readFileSync(path.join(logs,'native-aura-and-swipe.log'),'utf8').includes('NATIVE_GUI=true'))throw Error('Native GUI evidence missing; headless cannot pass the native gate.');
   report.native='PASS';save();
  }
  const images=path.join(fixture,'.local/aura_native_images');if(native&&fs.existsSync(images))fs.cpSync(images,path.join(logs,'native-images'),{recursive:true});
  const layouts=path.join(fixture,'.local/pavilion_review');if(fs.existsSync(layouts))fs.cpSync(layouts,path.join(logs,'layout-records'),{recursive:true});
  delete report.last_error;delete report.failed_at;
  const firstError=path.join(logs,'FIRST_ERROR.txt');
  if(fs.existsSync(firstError)){fs.copyFileSync(firstError,path.join(logs,'PREVIOUS_ERROR.txt'));fs.rmSync(firstError);}
  report.completed_at=new Date().toISOString();save();
  console.log('PAVILION_REPAIR_QA=PASS; NATIVE_GUI='+(report.native==='PASS')+'; PHONE=NOT_TESTED; PUBLISH=NONE; EXPORT=NONE');
  return report;
 }catch(error){
  report.last_error=error.message;report.failed_at=new Date().toISOString();fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');
  const recent=fs.readdirSync(logs).filter(n=>n.endsWith('.log')).map(n=>({p:path.join(logs,n),t:fs.statSync(path.join(logs,n)).mtimeMs})).sort((a,b)=>b.t-a.t)[0];
  const lines=recent?fs.readFileSync(recent.p,'utf8').split(/\r?\n/):[];const index=lines.findIndex(s=>/SCRIPT ERROR|ERROR:/.test(s));
  const excerpt=index>=0?lines.slice(index,index+18).join('\n'):lines.slice(-12).join('\n');
  const summary='PAVILION REPAIR — FAILED\n'+error.message+'\n'+excerpt+'\nReport: '+reportPath+'\n';fs.writeFileSync(path.join(logs,'FIRST_ERROR.txt'),summary);
  console.error(summary);throw error;
 }
}
if(require.main===module)check(process.argv[2]||path.resolve(__dirname,'../..'),process.argv[3],{native:process.argv.includes('--native'),force:process.argv.includes('--force')}).catch(e=>{console.error('PAVILION_REPAIR_STOPPED: '+e.message);process.exitCode=1;});
module.exports={check};
