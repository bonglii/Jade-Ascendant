'use strict';
// Publish the owner worktree; no installer, game QA, Worker deploy or export is invoked.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const H=require('./owner_git_helpers.cjs');
const DEFAULT_POLICY=require('./owner_source_scope.json');
const NATIVE='release/native/JadeMonetizationNativeBridge-production-candidate.aar';
const PROOF='docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json';
const STATE='docs/checkpoints/OWNER_SOURCE_SYNC_STATE_2026-11-02.json';
const POINTER='docs/checkpoints/CURRENT_WORK.json';
const LESSONS='docs/checkpoints/LESSONS.md';
const OWN=['publish_owner_source.cjs','owner_git_helpers.cjs','owner_source_scope.json','publish_owner_source.test.cjs','push_latest.cmd'];
const PREFIX='backend/player_identity/';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const readJson=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const split=s=>s.split('\0').filter(Boolean);
function git(root,args,opts={}){return H.command('git',args,root,opts);}
function child(root,p){return H.safePath(root,p);}
function excluded(p,policy){return policy.excluded.some(x=>p===x||x.endsWith('/')&&p.startsWith(x))||/(^|\/)(?:\.wrangler|\.godot|\.local|node_modules|\.gradle)(?:\/|$)/.test(p)||/\.(?:log|tmp|bak|disabled|apk|aab)$/i.test(p);}
function permitted(p,policy){return policy.modified.includes(p)||policy.new.some(x=>p===x||x.endsWith('/')&&p.startsWith(x))||p===STATE||p===POINTER||OWN.some(x=>p===PREFIX+x);}
function scanSecrets(p,bytes){
 if(/(^|\/)(?:\.env(?:\..*)?|.*\.(?:keystore|jks|p12|pem|key))$/i.test(p))throw Error('Private file excluded from publication: '+p);
 if(bytes.includes(0))return;
 const text=bytes.toString('utf8');
 const patterns=[/-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----/,/\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,})\b/,/"type"\s*:\s*"service_account"/];
 if(patterns.some(r=>r.test(text)))throw Error('Credential-like content detected; file not published: '+p);
 if(p==='export_presets.cfg'&&/^keystore\/release_password\s*=\s*"[^"\r\n]+"/m.test(text))throw Error('Release signing password is present in export_presets.cfg. Publication stopped before staging; do not paste the password into chat.');
}
function remoteHead(root,branch){
 const lines=git(root,['ls-remote','--heads','origin','refs/heads/'+branch]).split(/\r?\n/).filter(Boolean);
 if(lines.length>1)throw Error('Ambiguous remote branch.');
 return lines.length?lines[0].split(/\s+/)[0]:null;
}
function productionNative(root){
 if(process.platform!=='win32')throw Error('Run push_latest.cmd on the owner Windows project.');
 const exe=path.join(process.env.SystemRoot||'C:\\Windows','System32','WindowsPowerShell','v1.0','powershell.exe');
 H.command(exe,['-NoProfile','-ExecutionPolicy','Bypass','-File',child(root,'backend/player_identity/export_production.ps1'),'-VerifyOnly'],root,{inherit:true});
}
function plan(root,policy){
 const dirty=split(git(root,['diff','--name-only','-z','HEAD']));
 const untracked=split(git(root,['ls-files','--others','--exclude-standard','-z']));
 const retained=[],skipped=[],files=[];
 for(const p of [...new Set([...dirty,...untracked])].sort()){
  if(excluded(p,policy)){skipped.push(p);continue;}
  const file=child(root,p);
  if(!fs.existsSync(file)){
   if(policy.retainedDeletions.includes(p)){retained.push(p);continue;}
   throw Error('Unexpected deletion; source preserved: '+p);
  }
  if(!permitted(p,policy))throw Error('Change outside the reviewed owner status: '+p);
  if(!fs.statSync(file).isFile())throw Error('Not a regular source file: '+p);
  if(fs.statSync(file).size>=95*1024*1024)throw Error('File exceeds publication size limit: '+p);
  scanSecrets(p,fs.readFileSync(file));files.push(p);
 }
 return {files,retained,skipped};
}
function fingerprint(root,files){return sha(Buffer.from(files.map(p=>p+'\0'+sha(fs.readFileSync(child(root,p)))).join('\0')));}
function verifySnapshot(root,files,commit){
 for(const p of files){
  const expected=git(root,['hash-object','--path='+p,'--',p]);
  const actual=git(root,['rev-parse',(commit===':INDEX:'?'':commit)+':'+p]);
  if(actual!==expected)throw Error('Committed content differs from current source: '+p);
 }
}
function writeJson(file,value){const bytes=Buffer.from(JSON.stringify(value,null,2)+'\n');if(fs.existsSync(file)&&fs.readFileSync(file).equals(bytes))return;H.atomic(file,bytes);}
async function run({root,folder=__dirname,policy=DEFAULT_POLICY,verifyNative=productionNative,log=console.log,allowFixtureRemote=false}={}){
 root=fs.realpathSync(root);
 if(!fs.existsSync(child(root,'project.godot')))throw Error('project.godot not found.');
 H.assertNoIndexLock(root);
 if(git(root,['rev-parse','--show-toplevel']).replace(/\\/g,'/').toLowerCase()!==root.replace(/\\/g,'/').toLowerCase())throw Error('Project must be the Git repository root.');
 const branch=git(root,['branch','--show-current']);
 if(branch!==policy.branch)throw Error('Unexpected branch: '+branch+'; expected '+policy.branch);
 const origin=git(root,['remote','get-url','origin']);
 if(!allowFixtureRemote&&!/^(?:https:\/\/github\.com\/bonglii\/Jade-Ascendant(?:\.git)?|git@github\.com:bonglii\/Jade-Ascendant(?:\.git)?)$/.test(origin))throw Error('Unexpected origin repository.');
 for(const ref of ['MERGE_HEAD','CHERRY_PICK_HEAD','REVERT_HEAD'])if(fs.existsSync(path.resolve(root,git(root,['rev-parse','--git-path',ref]))))throw Error('Finish the existing Git operation first: '+ref);
 for(const ref of ['rebase-merge','rebase-apply','index.lock'])if(fs.existsSync(path.resolve(root,git(root,['rev-parse','--git-path',ref]))))throw Error('Existing Git operation/lock retained: '+ref);
 git(root,['merge-base','--is-ancestor',policy.base,'HEAD']);
 const stateDir=path.join(root,'.local','owner_source_publish');
 if(git(root,['check-ignore','--no-index','--', '.local/owner_source_publish/receipt.json'],{allowFailure:true}).status!==0)throw Error('.local must be ignored before storing publication receipts.');
 const receiptFile=path.join(stateDir,'receipt.json');
 let receipt=fs.existsSync(receiptFile)?readJson(receiptFile):{};
 const currentHead=git(root,['rev-parse','HEAD']);
 if(currentHead!==policy.base&&currentHead!==receipt.commit){
  const resumedCommit=receipt.phase==='staging'&&Array.isArray(receipt.files)&&git(root,['rev-parse','HEAD^'])===receipt.head;
  if(!resumedCommit)throw Error('Unreviewed local commits beyond the owner baseline. Nothing pushed.');
  verifySnapshot(root,receipt.files,currentHead);
 }
 const first=plan(root,policy);
 const staged=split(git(root,['diff','--cached','--name-only','-z']));
 if(staged.length){
  if(receipt.phase!=='staging'||receipt.head!==git(root,['rev-parse','HEAD'])||!Array.isArray(receipt.files)||staged.some(p=>!receipt.files.includes(p))||receipt.fingerprint!==fingerprint(root,receipt.files))throw Error('Unrelated or changed staged work preserved. No commit made.');
  verifySnapshot(root,staged,':INDEX:');
 }
 const proof=readJson(child(root,PROOF));
 if(sha(fs.readFileSync(child(root,NATIVE)))!==policy.nativeSha||String(proof.aar_sha256).toLowerCase()!==policy.nativeSha)throw Error('Native candidate does not match the confirmed R2 SHA256.');
 if(!proof.inputs||Object.keys(proof.inputs).length!==policy.nativeInputs)throw Error('Expected exactly '+policy.nativeInputs+' native provenance inputs.');
 const nativeFiles=Object.keys(proof.inputs);
 for(const input of nativeFiles){
  child(root,input);
  if(!/^(?:backend\/monetization\/android_bridge\/|addons\/JadeMonetizationNativeBridge\/)/.test(input)||excluded(input,policy)||!/\.(?:kt|kts|xml|json|properties|pro|gd)$/.test(input))throw Error('Unexpected native input path: '+input);
  if(!fs.existsSync(child(root,input)))throw Error('Native input missing: '+input);
 }
 const nativeReadSet=[NATIVE,PROOF,...nativeFiles];
 const nativeFingerprint=fingerprint(root,nativeReadSet);
 await verifyNative(root);
 if(fingerprint(root,nativeReadSet)!==nativeFingerprint)throw Error('Native inputs changed during verification. No publication started.');
 const remoteBefore=remoteHead(root,branch);
 if(remoteBefore){
  git(root,['fetch','--no-tags','origin','refs/heads/'+branch]);
  if(git(root,['rev-parse','FETCH_HEAD'])!==remoteBefore)throw Error('Remote changed during preflight; rerun the launcher.');
  git(root,['merge-base','--is-ancestor',remoteBefore,'HEAD']);
 }
 for(const name of OWN){
  const source=fs.readFileSync(path.join(folder,name)),target=child(root,PREFIX+name);
  if(fs.existsSync(target)&&!fs.readFileSync(target).equals(source))throw Error('Existing publisher file differs; preserved: '+PREFIX+name);
  if(!fs.existsSync(target)||!fs.readFileSync(target).equals(source))H.atomic(target,source);
 }
 const current=readJson(child(root,POINTER));
 current.publication_state=STATE;
 current.source_branch=branch;
 writeJson(child(root,POINTER),current);
 const lessonMarker='Owner source publisher — 2026-11-02';
 const lessonBytes=fs.readFileSync(child(root,LESSONS));
 if(!lessonBytes.toString('utf8').includes(lessonMarker))H.atomic(child(root,LESSONS),Buffer.concat([lessonBytes,Buffer.from('\n\n## '+lessonMarker+'\n\nA literal credential-shaped sample in a self-published test triggered the scanner during author QA. Construct synthetic credential samples at runtime and keep the publication guard enabled. Preserve unrelated index work and recovery markers; retain omitted documentation/build tools in the Git tree; declare push PASS only after the remote ref equals the committed snapshot.\n')]));
 writeJson(child(root,STATE),{
  format:policy.format,repository:policy.repository,source_branch:branch,base_commit:policy.base,
  snapshot_identity:'Use the Git commit containing this file; verify the remote branch points to it.',
  native_candidate_sha256:policy.nativeSha,native_provenance_inputs:policy.nativeInputs,
  windows_r2:{status:'PASS',evidence:'Owner confirmation in chat, 2026-11-02; no fresh game QA in this publication.'},
  recovery:'PASS per owner log',aab:'UNCONFIRMED',phone_test:'UNCONFIRMED',admob_mitigation:'NOT_APPLIED',
  publishing:'Source snapshot only. Push result and verified SHA are printed by push_latest.cmd and retained in .local/owner_source_publish/receipt.json.',
  retained_head_files:policy.retainedDeletions,excluded_local_paths:policy.excluded,
  next_action:'After remote SHA verification, use this branch/commit as the source for a fresh checkout and gameplay review. Check exact-SHA CI separately; no deployment or export is performed by this launcher.'
 });
 const p=plan(root,policy);
 const files=[...new Set([...p.files,...nativeFiles,NATIVE,PROOF,...OWN.map(x=>PREFIX+x),STATE,POINTER])].sort();
 // plan() scanned every changed/new file. Unchanged native inputs are included
 // for snapshot completeness; they already belong to the confirmed base commit.
 const inputFingerprint=fingerprint(root,files);
 if(fingerprint(root,nativeReadSet)!==nativeFingerprint)throw Error('Native inputs changed after verification. Source/index retained.');
 fs.mkdirSync(stateDir,{recursive:true});
 receipt={...receipt,phase:'staging',head:git(root,['rev-parse','HEAD']),files,fingerprint:inputFingerprint,retained:p.retained,skipped:p.skipped};writeJson(receiptFile,receipt);
 const pathList=path.join(stateDir,'paths.nul');fs.writeFileSync(pathList,files.map(p=>':(literal)'+p).join('\0')+'\0');
 H.assertNoIndexLock(root);
 git(root,['add','--pathspec-from-file='+pathList,'--pathspec-file-nul']);
 const actualStaged=split(git(root,['diff','--cached','--name-only','-z']));
 if(actualStaged.some(f=>!files.includes(f)))throw Error('Unexpected staged changes; index retained.');
 if(split(git(root,['diff','--cached','--diff-filter=D','--name-only','-z'])).length)throw Error('Unexpected staged deletion; index retained.');
 if(fingerprint(root,files)!==inputFingerprint)throw Error('Source changed while staging; index retained.');
 if(actualStaged.length)git(root,['commit','-m','chore(source): checkpoint owner R2 connection and combat source']);
 const commit=git(root,['rev-parse','HEAD']);
 if(actualStaged.length&&split(git(root,['diff-tree','--no-commit-id','--name-only','-r','-z',commit])).some(f=>!files.includes(f)))throw Error('Commit hook introduced an unexpected file. Commit retained; nothing pushed.');
 verifySnapshot(root,files,commit);
 if(fingerprint(root,files)!==inputFingerprint)throw Error('Source changed after commit. Nothing pushed; rerun the launcher.');
 receipt={...receipt,phase:'committed',commit};writeJson(receiptFile,receipt);
 log('OWNER_SOURCE_COMMIT='+commit);
 const beforePush=remoteHead(root,branch);
 if(beforePush!==remoteBefore)throw Error('Remote changed before push. Local commit retained; rerun to check ancestry.');
 git(root,['push','-u','origin','HEAD:refs/heads/'+branch],{inherit:true});
 if(remoteHead(root,branch)!==commit)throw Error('Push was attempted but remote SHA is unconfirmed. Rerun to verify; no force push.');
 receipt={...receipt,phase:'pushed_remote_verified',remote_commit:commit,verified_utc:new Date().toISOString()};writeJson(receiptFile,receipt);
 log('OWNER_SOURCE_PUSH=PASS');
 if(!allowFixtureRemote){
  log('GITHUB_COMMIT_URL=https://github.com/'+policy.repository+'/commit/'+commit);
  log('GITHUB_SOURCE_URL=https://github.com/'+policy.repository+'/tree/'+branch);
 }
 log('RETAINED_DELETIONS='+p.retained.length+'; EXCLUDED_LOCAL_FILES='+p.skipped.length);
 log('CI=CHECK_SEPARATELY; DEPLOY=NOT_RUN; AAB=UNCONFIRMED; PHONE=UNCONFIRMED');
 return {commit,files,retained:p.retained};
}
module.exports={run,plan,scanSecrets,excluded,fingerprint,DEFAULT_POLICY};
if(require.main===module){
 const args=process.argv.slice(2);const i=args.indexOf('--project');const root=i<0?'D:/Godot/project/jade-ascendant':args[i+1];
 run({root}).catch(e=>{console.error('OWNER_SOURCE_PUSH=NOT_CONFIRMED\n'+e.message);process.exitCode=1;});
}
