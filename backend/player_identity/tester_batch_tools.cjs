'use strict';
// Self-contained package installer/publisher. Only manifest paths are written or committed.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const FORMAT='jade.tester-reliability.v1',BRANCH='fix/tester-reliability-20261026';
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
  if(!/^(scripts|tests|assets\/ui\/journey\/stage_art|backend|docs\/checkpoints|\.github\/workflows)\//.test(row.path))throw Error('Path outside batch scope: '+row.path);
  if(/wrangler\..*\.toml$|export_presets|release_config|\.aar$|\.keystore$/.test(row.path))throw Error('Protected configuration is not package content: '+row.path);
  const incoming=fs.readFileSync(safePath(path.join(folder,'incoming'),row.path));if(hash(incoming)!==row.sha256)throw Error('Corrupted incoming file: '+row.path);
  if(row.base_sha256!==null){const base=fs.readFileSync(safePath(path.join(folder,'base'),row.path));if(hash(base)!==row.base_sha256)throw Error('Corrupted base file: '+row.path);}
 }
 return m;
}
function assertNoIndexLock(root){const file=git(root,['rev-parse','--git-path','index.lock']);if(fs.existsSync(path.resolve(root,file)))throw Error('Git index.lock already exists. Close the Git process that owns it; this launcher never removes another process lock. Source/index/HEAD were not changed.');}
function prepareInstall(root,folder,m,report){
 const plans=[],conflicts=[];fs.mkdirSync(report,{recursive:true});
 for(const row of m.files){
  const target=safePath(root,row.path),exists=fs.existsSync(target),current=exists?fs.readFileSync(target):null;
  const incoming=fs.readFileSync(safePath(path.join(folder,'incoming'),row.path));const original=row.base_sha256===null?null:fs.readFileSync(safePath(path.join(folder,'base'),row.path));
  const equivalent=(a,b)=>a!==null&&b!==null&&(row.kind==='text'?normalize(a).equals(normalize(b)):a.equals(b));
  if(equivalent(current,incoming))continue;
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
 function scan(folder){for(const entry of fs.readdirSync(folder,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))){if(['.git','.godot','.local','node_modules','build','.gradle','.wrangler','.cache','.idea'].includes(entry.name))continue;const file=path.join(folder,entry.name);if(entry.isSymbolicLink())continue;if(entry.isDirectory())scan(file);else if(entry.isFile()&&!/\.(aar|jar|mp4|webm|so)$/i.test(file)){digest.update(path.relative(root,file).split(path.sep).join('/'));digest.update(fs.readFileSync(file));}}}
 for(const folder of ['scripts','scenes','tests','addons','assets','backend','release','.github'])if(fs.existsSync(path.join(root,folder)))scan(path.join(root,folder));
 for(const file of ['project.godot','export_presets.cfg'])if(fs.existsSync(path.join(root,file)))digest.update(fs.readFileSync(path.join(root,file)));
 return digest.digest('hex');
}
async function waitCI(sha,save){
 const url='https://api.github.com/repos/bonglii/Jade-Ascendant/actions/runs?head_sha='+sha+'&per_page=100';
 for(let attempt=0;attempt<50;attempt++){
  const r=await fetch(url,{headers:{accept:'application/vnd.github+json','user-agent':'Jade-Tester-Batch'}});if(!r.ok)throw Error('Cannot read exact-SHA CI ('+r.status+'). Commit is already published; retry resumes without reapplying.');
  const data=await r.json(),run=data.workflow_runs?.find(x=>x.head_sha===sha&&x.path==='.github/workflows/tester-reliability-qa.yml');
  if(run?.status==='completed'){
   if(run.conclusion!=='success')throw Error('Exact-SHA tester CI failed: '+run.html_url);
   console.log('TESTER_CI=PASS; COMMIT='+sha);save({sha,run_id:run.id,url:run.html_url});return;
  }
  console.log('TESTER_CI=WAITING; COMMIT='+sha+'; https://github.com/bonglii/Jade-Ascendant/actions');
  await new Promise(resolve=>setTimeout(resolve,30000));
 }
 throw Error('Exact-SHA CI is still pending. Rerun this launcher; completed work is retained.');
}
async function run({folder,args=process.argv.slice(2)}={}){
 const value=flag=>{const i=args.indexOf(flag);return i<0?'':args[i+1]||'';};
 const candidates=[value('--project'),process.env.JADE_PROJECT,process.cwd(),'D:/Godot/project/jade-ascendant'].filter(Boolean);
 const root=candidates.find(p=>fs.existsSync(path.join(p,'project.godot'))&&fs.existsSync(path.join(p,'backend/player_identity')));
 if(!root)throw Error('Project not found. Run with --project "D:\\Godot\\project\\jade-ascendant".');
 const project=fs.realpathSync(root),manifest=readPackage(folder);assertNoIndexLock(project);
 const origin=git(project,['remote','get-url','origin']);if(!/github\.com[:/]bonglii\/Jade-Ascendant(?:\.git)?$/i.test(origin))throw Error('Unexpected origin. No source changed.');
 const privateDir=path.join(project,'.local/tester_reliability_batch');fs.mkdirSync(privateDir,{recursive:true});if(!fs.existsSync(path.join(project,'.local/.gdignore')))atomic(path.join(project,'.local/.gdignore'),Buffer.alloc(0));
 const stateFile=path.join(privateDir,'receipt.json');let state=fs.existsSync(stateFile)?JSON.parse(fs.readFileSync(stateFile,'utf8')):{};
 const save=()=>atomic(stateFile,Buffer.from(JSON.stringify(state,null,2)+'\n'));
 const plans=prepareInstall(project,folder,manifest,path.join(privateDir,'review-'+crypto.randomUUID()));
 const backup=path.join(privateDir,'backups',crypto.randomUUID());const changed=applyInstall(project,plans,backup);console.log('TESTER_INSTALL=PASS; CHANGED='+changed+'; BACKUP='+backup);state.install=true;save();
 if(args.includes('--install-only')){console.log('INSTALL_ONLY; QA/PUBLISH/DEPLOY=NOT_RUN');return;}
 const currentBranch=git(project,['branch','--show-current']);
 if(currentBranch!==BRANCH){
  const exists=git(project,['show-ref','--verify','--quiet','refs/heads/'+BRANCH],{allowFailure:true});
  if(exists.status===0)throw Error('Existing batch branch differs from current branch; source retained. Switch to '+BRANCH+' and rerun.');
  git(project,['switch','-c',BRANCH]);
 }
 const qa=require(path.join(project,'backend/player_identity/check_tester_reliability.cjs'));
 const godot=qa.resolveGodot(project,value('--godot')||process.env.GODOT_PATH),fingerprint=sourceFingerprint(project);
 const qaKey=hash(Buffer.from(fingerprint+hash(fs.readFileSync(godot))));
 if(state.qa!==qaKey){await qa.check(project,godot);state.qa=qaKey;save();}else console.log('TESTER_RESUME_SKIP=qa');
 if(sourceFingerprint(project)!==fingerprint)throw Error('Source changed during QA; retry validates the new source. No commit was made.');
 const paths=manifest.files.map(x=>x.path);const dirty=git(project,['diff','--name-only','HEAD','--',...paths]);
 if(dirty||paths.some(p=>git(project,['ls-files','--error-unmatch','--',p],{allowFailure:true}).status!==0)){
  assertNoIndexLock(project);const list=path.join(privateDir,'publish-paths.nul');fs.writeFileSync(list,paths.join('\0')+'\0');
  git(project,['add','--pathspec-from-file='+list,'--pathspec-file-nul']);
  git(project,['diff','--cached','--check','--',...paths]);
  git(project,['commit','--only','--pathspec-from-file='+list,'--pathspec-file-nul','-m','fix(testers): stabilize wallets, seals, summon reveals and crowded combat']);
 }
 if(sourceFingerprint(project)!==fingerprint)throw Error('Source changed after QA/commit. No push attempted; rerun validates it.');
 const sha=git(project,['rev-parse','HEAD']);state.commit=sha;save();
 git(project,['push','-u','origin','HEAD:refs/heads/'+BRANCH]);state.pushed=sha;save();
 console.log('TESTER_PUBLISHED=PASS\nhttps://github.com/bonglii/Jade-Ascendant/commit/'+sha+'\nhttps://github.com/bonglii/Jade-Ascendant/tree/'+BRANCH);
 if(state.ci?.sha!==sha)await waitCI(sha,result=>{state.ci=result;save();});else console.log('TESTER_RESUME_SKIP=ci');
 if(args.includes('--publish-only')){console.log('PUBLISH_ONLY; DEPLOY=NONE; AAB=NOT_EXPORTED');return;}
 if(process.platform!=='win32')throw Error('Source/CI complete. Use the same launcher on the owner Windows machine for the existing authenticated Worker deployment.');
 const powershell=path.join(process.env.SystemRoot||'C:\\Windows','System32/WindowsPowerShell/v1.0/powershell.exe');
 command(powershell,['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(project,'backend/player_identity/deploy_tester_reliability.ps1'),'-ExpectedCommit',sha],project,{inherit:true});
 state.deployed=sha;save();
 console.log('TESTER_BATCH=PASS; NATIVE=UNCHANGED; PLAY_PRODUCTS=OWNER_SETUP; AAB=NOT_EXPORTED; ANDROID=NOT_TESTED\nNEXT=Create/activate the six v2 Play products after this deployment; close the old editor and export ONE client AAB with backend\\player_identity\\export_production.cmd.');
}
module.exports={FORMAT,hash,normalize,atomic,command,safePath,readPackage,prepareInstall,applyInstall,sourceFingerprint,assertNoIndexLock,run};
