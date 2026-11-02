'use strict';
// Scoped hash/merge/backup helpers. No publishing or deployment.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const FORMAT='jade.player-8-10.v1';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const normalize=b=>Buffer.from(b.toString('utf8').replace(/^\uFEFF/,'').replace(/\r\n/g,'\n'));
function atomic(file,bytes){fs.mkdirSync(path.dirname(file),{recursive:true});const temp=file+'.tester-'+crypto.randomUUID()+'.tmp';fs.writeFileSync(temp,bytes);fs.renameSync(temp,file);}
function command(exe,args,cwd,{allowFailure=false,inherit=false}={}){
 const result=spawnSync(exe,args,{cwd,encoding:'utf8',windowsHide:true,stdio:inherit?'inherit':['ignore','pipe','pipe'],maxBuffer:16*1024*1024});
 if(allowFailure)return result;
 if(result.error||result.status!==0){throw Error(exe+' '+args.slice(0,3).join(' ')+' failed: '+(result.error?.message||result.stderr||result.stdout||'exit '+result.status));}
 return inherit?'':result.stdout.trim();
}
function git(root,args,options={}){return command('git',args,root,options);}
function safePath(root,relative){
 if(typeof relative!=='string'||relative.includes('\\')||relative.startsWith('/')||relative.split('/').some(x=>!x||x==='.'||x==='..')||!/^([.\w-]+\/)*[.\w-]+$/.test(relative))throw Error('Invalid package path: '+relative);
 const target=path.resolve(root,relative);let part=root;
 for(const name of relative.split('/')){part=path.join(part,name);if(fs.existsSync(part)&&fs.lstatSync(part).isSymbolicLink())throw Error('Package target is a symlink: '+relative);}
 return target;
}
function readPackage(folder){
 const m=JSON.parse(fs.readFileSync(path.join(folder,'manifest.json'),'utf8'));
 if(m.format!==FORMAT||!Array.isArray(m.files)||!m.files.length||!/^[a-f0-9]{40}$/.test(m.base))throw Error('Invalid manifest: expected format '+FORMAT+', base SHA and nonempty files array.');
 const seen=new Set();
 for(const row of m.files){
  safePath(folder,row.path);if(seen.has(row.path)||!['text','binary'].includes(row.kind))throw Error('Duplicate/invalid manifest entry: '+row.path);seen.add(row.path);
  if(!/^(scripts|tests|backend|docs\/checkpoints|release\/native)\//.test(row.path))throw Error('Path outside batch scope: '+row.path);
  if(/wrangler\..*\.toml$|export_presets|release_config|\.aar$|\.keystore$/.test(row.path)&&row.path!=="release/native/JadeMonetizationNativeBridge-production-candidate.aar")throw Error('Protected configuration is not package content: '+row.path);
  if(row.path.endsWith(".aar")&&(row.kind!=="binary"||row.base_sha256===null))throw Error("Candidate requires an exact existing binary baseline");
  const incoming=fs.readFileSync(safePath(path.join(folder,'incoming'),row.path));if(hash(incoming)!==row.sha256)throw Error('Corrupted incoming file: '+row.path);
  if(row.previous_sha256!==undefined){const previous=fs.readFileSync(safePath(path.join(folder,'previous'),row.path));if(!/^[a-f0-9]{64}$/.test(row.previous_sha256)||hash(previous)!==row.previous_sha256)throw Error('Corrupted previous batch file: '+row.path);}
  if(row.base_sha256!==null){const base=fs.readFileSync(safePath(path.join(folder,'base'),row.path));if(hash(base)!==row.base_sha256)throw Error('Corrupted base file: '+row.path);}
 }
 for(const required of ["release/native/JadeMonetizationNativeBridge-production-candidate.aar","docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json","backend/player_identity/export_production.ps1"])if(!seen.has(required))throw Error("Missing native/provenance/export pin: "+required);
 return m;
}
function assertNoIndexLock(root){const file=git(root,['rev-parse','--git-path','index.lock']);if(fs.existsSync(path.resolve(root,file)))throw Error('Git index.lock already exists. Close the Git process that owns it; this launcher never removes another process lock. Source/index/HEAD were not changed.');}
function prepareInstall(root,folder,m,report){
 const plans=[],conflicts=[];fs.mkdirSync(report,{recursive:true});
 for(const row of m.files){
  const target=safePath(root,row.path),exists=fs.existsSync(target),current=exists?fs.readFileSync(target):null;
  const incoming=fs.readFileSync(safePath(path.join(folder,'incoming'),row.path));let original=row.base_sha256===null?null:fs.readFileSync(safePath(path.join(folder,'base'),row.path));
  const equivalent=(a,b)=>a!==null&&b!==null&&(row.kind==='text'?normalize(a).equals(normalize(b)):a.equals(b));
  if(equivalent(current,incoming))continue;
  if(row.previous_sha256!==undefined){const previous=fs.readFileSync(safePath(path.join(folder,'previous'),row.path));if(equivalent(current,previous))original=previous;}
  let desired=incoming;
  if(!(current===null&&original===null)&&!equivalent(current,original)){
   if(current===null||original===null||row.kind!=='text'){conflicts.push(row.path);}
   else if(row.path==='docs/checkpoints/LESSONS.md'&&normalize(incoming).toString().startsWith(normalize(original).toString())){
    const section=normalize(incoming).toString().slice(normalize(original).toString().length);if(normalize(current).toString().includes(section.trim()))continue;desired=Buffer.from(normalize(current).toString().trimEnd()+'\n'+section);
   }else if(row.path==='docs/checkpoints/CURRENT_WORK.json'){
    const local=JSON.parse(current),next=JSON.parse(incoming);desired=Buffer.from(JSON.stringify({...local,...next,previous:local.state===next.state?(local.previous||next.previous):(local.state||next.previous)},null,2)+'\n');
   }else{
    const dir=path.join(report,row.path);fs.mkdirSync(dir,{recursive:true});
    for(const [name,bytes]of [['local',current],['base',original],['incoming',incoming]])fs.writeFileSync(path.join(dir,name),normalize(bytes));
    const merged=command('git',['merge-file','-p',path.join(dir,'local'),path.join(dir,'base'),path.join(dir,'incoming')],root,{allowFailure:true});
    if(merged.error||merged.status!==0){conflicts.push(row.path);if(merged.stdout)fs.writeFileSync(path.join(dir,'conflict.txt'),merged.stdout);}else desired=Buffer.from(merged.stdout);
   }
  }
  if(conflicts.at(-1)===row.path){const dir=path.join(report,row.path);fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'incoming'),incoming);if(current)fs.writeFileSync(path.join(dir,'local'),current);continue;}
  if(current!==null&&desired.equals(current))continue;
  plans.push({path:row.path,target,original:current,desired});
 }
 if(conflicts.length)throw Error('Overlapping edits preserved; no source writes: '+conflicts.join(', ')+'; REPORT='+report);
 return plans;
}
function applyInstall(root,plans,backup){
 // Validate the entire read set again before the first source write.
 for(const p of plans){const now=fs.existsSync(p.target)?fs.readFileSync(p.target):null;if((now===null)!==(p.original===null)||now!==null&&!now.equals(p.original))throw Error('File changed while planning: '+p.path+'; no install started.');}
 for(const p of plans){
  if(p.original!==null)atomic(safePath(backup,p.path),p.original);
  atomic(p.target,p.desired);
 }
 return plans.length;
}
function sourceFingerprint(root){
 const digest=crypto.createHash('sha256');
 function scan(folder){for(const entry of fs.readdirSync(folder,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))){if(['.git','.godot','.local','node_modules','build','.gradle','.wrangler','.cache','.idea'].includes(entry.name))continue;const file=path.join(folder,entry.name);if(entry.isSymbolicLink())continue;if(entry.isDirectory())scan(file);else if(entry.isFile()&&!/\.(aar|jar|mp4|webm|so|uid)$/i.test(file)){digest.update(path.relative(root,file).split(path.sep).join('/'));digest.update(fs.readFileSync(file));}}}
 for(const folder of ['scripts','scenes','tests','addons','assets','backend','release','.github'])if(fs.existsSync(path.join(root,folder)))scan(path.join(root,folder));
 for(const file of ['project.godot','export_presets.cfg'])if(fs.existsSync(path.join(root,file)))digest.update(fs.readFileSync(path.join(root,file)));
 return digest.digest('hex');
}
module.exports={FORMAT,hash,normalize,atomic,command,safePath,readPackage,prepareInstall,applyInstall,sourceFingerprint,assertNoIndexLock};
