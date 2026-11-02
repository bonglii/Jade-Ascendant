'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const H=require('./owner_git_helpers.cjs');
const P=require('./publish_owner_source.cjs');
const NATIVE='release/native/JadeMonetizationNativeBridge-production-candidate.aar';
const PROOF='docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json';
const POINTER='docs/checkpoints/CURRENT_WORK.json';
const STATE='docs/checkpoints/OWNER_SOURCE_SYNC_STATE_2026-11-02.json';
const INPUT='backend/monetization/android_bridge/src/main/Test.kt';
const ADDON='addons/JadeMonetizationNativeBridge/export_plugin.gd';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const git=(root,args,options={})=>H.command('git',args,root,options);
function fixture(t){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jade owner publish '));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
 const root=path.join(dir,'owner project'),remote=path.join(dir,'remote.git');fs.mkdirSync(root);
 git(dir,['init','--bare',remote]);git(root,['init','-b',P.DEFAULT_POLICY.branch]);
 git(root,['config','user.email','fixture@example.invalid']);git(root,['config','user.name','Publisher fixture']);
 git(root,['config','core.autocrlf','false']);git(root,['remote','add','origin',remote]);
 const put=(p,v)=>{const f=path.join(root,p);fs.mkdirSync(path.dirname(f),{recursive:true});fs.writeFileSync(f,v);};
 put('.gitignore','.local/\n');put('project.godot','config_version=5\n');put('AGENTS.md','Owner fixture.\n');
 put('scripts/game.gd','extends Node\n');put(INPUT,'package fixture\n');put(ADDON,'extends EditorExportPlugin\n');
 put(NATIVE,'old native fixture');put(PROOF,'{}\n');put(POINTER,'{"state":"existing-game-state.json"}\n');
 put('docs/checkpoints/LESSONS.md','Existing owner lessons.\n');
 put('docs/keep.md','Preserve documentation\n');put('tools/guard.ps1','Write-Host guard\n');
 git(root,['add','.']);git(root,['commit','-m','fixture baseline']);const base=git(root,['rev-parse','HEAD']);
 const native=Buffer.from('R2 native fixture');put(NATIVE,native);
 const inputs={[INPUT]:hash(fs.readFileSync(path.join(root,INPUT))),[ADDON]:hash(fs.readFileSync(path.join(root,ADDON)))};
 put(PROOF,JSON.stringify({aar_sha256:hash(native),inputs},null,2)+'\n');
 put('scripts/game.gd','extends Node\n# owner changes\n');put('scripts/new.gd','extends Node\n');
 fs.unlinkSync(path.join(root,'docs/keep.md'));fs.unlinkSync(path.join(root,'tools/guard.ps1'));
 put('.wrangler/cache.json','local cache');put('backend/monetization/cloudflare/dir','accidental output');
 put('firestore-debug.log','debug');put('powershell.exe.disabled','disabled executable');
 const policy={...P.DEFAULT_POLICY,base,nativeSha:hash(native),nativeInputs:2,modified:['AGENTS.md','scripts/game.gd',NATIVE,PROOF,'export_presets.cfg','docs/checkpoints/LESSONS.md'],retainedDeletions:['docs/keep.md','tools/guard.ps1'],new:['scripts/new.gd']};
 let checks=0;const logs=[];
 const options={root,folder:__dirname,policy,allowFixtureRemote:true,log:v=>logs.push(v),verifyNative:async()=>{checks++;}};
 const run=extra=>P.run({...options,...extra});
 const remoteSha=()=>{const s=git(root,['ls-remote','--heads','origin','refs/heads/'+policy.branch]);return s?s.split(/\s+/)[0]:null;};
 const hook=(where,name,text)=>{const p=path.join(where,'hooks',name);fs.writeFileSync(p,'#!/bin/sh\n'+text+'\n');fs.chmodSync(p,0o755);return p;};
 return {dir,root,remote,put,policy,options,logs,run,remoteSha,hook,get checks(){return checks;}};
}
function before(f){return {head:git(f.root,['rev-parse','HEAD']),index:git(f.root,['write-tree']),pointer:fs.readFileSync(path.join(f.root,POINTER),'utf8')};}
function untouched(f,b){assert.equal(git(f.root,['rev-parse','HEAD']),b.head);assert.equal(git(f.root,['write-tree']),b.index);assert.equal(fs.readFileSync(path.join(f.root,POINTER),'utf8'),b.pointer);assert.equal(f.remoteSha(),null);}
test('production scope matches reviewed owner batch and excludes local debris',()=>{
 const p=P.DEFAULT_POLICY;assert.equal(p.modified.length,85);assert.equal(p.retainedDeletions.length,30);assert.equal(p.nativeInputs,52);
 assert.equal(p.nativeSha,'2171f13f36cf8d90988fd20248f879653104625c8481b91d3fb0a4303fb098ea');
 assert(p.new.includes('scripts/gameplay/'));assert(p.new.some(x=>x.endsWith('ForegroundReadDispatcher.kt')));
 for(const f of ['.wrangler/cache.db','firestore-debug.log','powershell.exe.disabled','backend/monetization/cloudflare/dir'])assert(P.excluded(f,p));
});
test('actual Git commit/push preserves docs/tools and publishes complete selected source',async t=>{
 const f=fixture(t),r=await f.run();assert.equal(f.remoteSha(),r.commit);assert.equal(f.checks,1);
 assert.equal(git(f.root,['show',r.commit+':scripts/new.gd']),'extends Node');
 assert.equal(git(f.root,['show',r.commit+':'+NATIVE]),'R2 native fixture');
 assert.equal(git(f.root,['show',r.commit+':docs/keep.md']),'Preserve documentation');
 assert.equal(git(f.root,['show',r.commit+':tools/guard.ps1']),'Write-Host guard');
 assert(!fs.existsSync(path.join(f.root,'docs/keep.md')));
 for(const p of f.policy.excluded)assert.notEqual(git(f.root,['cat-file','-e',r.commit+':'+p],{allowFailure:true}).status,0);
 const pointer=JSON.parse(git(f.root,['show',r.commit+':'+POINTER]));assert.equal(pointer.state,'existing-game-state.json');assert.equal(pointer.publication_state,STATE);
 const state=JSON.parse(git(f.root,['show',r.commit+':'+STATE]));assert.equal(state.aab,'UNCONFIRMED');assert.equal(state.admob_mitigation,'NOT_APPLIED');
 const receipt=JSON.parse(fs.readFileSync(path.join(f.root,'.local/owner_source_publish/receipt.json')));assert.equal(receipt.remote_commit,r.commit);assert.equal(receipt.phase,'pushed_remote_verified');
 assert(f.logs.includes('OWNER_SOURCE_PUSH=PASS'));
});
test('repeat launcher uses same commit and does not reset source or delete markers',async t=>{
 const f=fixture(t);f.put('.local/unrelated-recovery.json','KEEP');const a=await f.run(),b=await f.run();
 assert.equal(a.commit,b.commit);assert.equal(fs.readFileSync(path.join(f.root,'.local/unrelated-recovery.json'),'utf8'),'KEEP');
 assert.equal(git(f.root,['diff','--cached','--name-only']),'');
});
test('unknown native candidate rejects before source/index writes',async t=>{
 const f=fixture(t);f.put(NATIVE,'unknown');const b=before(f);await assert.rejects(f.run(),/confirmed R2/);untouched(f,b);assert.equal(f.checks,0);
});
test('native provenance count mismatch rejects before writes',async t=>{
 const f=fixture(t);f.policy.nativeInputs=52;const b=before(f);await assert.rejects(f.run(),/exactly 52/);untouched(f,b);
});
test('native verifier failure/active recovery is retained without starting publication',async t=>{
 const f=fixture(t);f.put('.local/export-recovery.json','ACTIVE');const b=before(f);
 await assert.rejects(f.run({verifyNative:async()=>{throw Error('active recovery marker');}}),/active recovery/);untouched(f,b);
 assert.equal(fs.readFileSync(path.join(f.root,'.local/export-recovery.json'),'utf8'),'ACTIVE');
});
test('unrelated staged work is not committed or modified',async t=>{
 const f=fixture(t);f.put('scripts/other.gd','extends Node');git(f.root,['add','scripts/other.gd']);
 const b=before(f);await assert.rejects(f.run(),/outside the reviewed|staged work/);untouched(f,b);
});
test('unexpected local source path blocks publication',async t=>{
 const f=fixture(t);f.put('scripts/unreviewed.gd','extends Node');const b=before(f);await assert.rejects(f.run(),/outside the reviewed/);untouched(f,b);
});
test('unexpected runtime deletion is not swept into the commit',async t=>{
 const f=fixture(t);fs.unlinkSync(path.join(f.root,'scripts/game.gd'));const b=before(f);await assert.rejects(f.run(),/Unexpected deletion/);untouched(f,b);
});
test('release signing password blocks publication without exposing the value',async t=>{
 const f=fixture(t);f.put('export_presets.cfg','keystore/release_password="fixture-only-value"\n');const b=before(f);
 let error;try{await f.run();}catch(e){error=e;}assert(error);assert(!error.message.includes('fixture-only-value'));assert.match(error.message,/signing password/);untouched(f,b);
});
test('private key and service-account patterns are blocked',()=>{
 assert.throws(()=>P.scanSecrets('scripts/new.gd',Buffer.from('-----BEGIN'+' PRIVATE KEY-----')),/Credential/);
 assert.throws(()=>P.scanSecrets('backend/account.json',Buffer.from(JSON.stringify({type:['service','account'].join('_')}))),/Credential/);
});
test('native source changing during verification aborts',async t=>{
 const f=fixture(t);const b=before(f);await assert.rejects(f.run({verifyNative:async()=>f.put(INPUT,'changed during verification')}),/changed during verification/);untouched(f,b);
});
test('existing differing publisher file is preserved',async t=>{
 const f=fixture(t);const name='backend/player_identity/publish_owner_source.cjs';f.put(name,'owner content');
 await assert.rejects(f.run(),/Existing publisher file differs/);assert.equal(fs.readFileSync(path.join(f.root,name),'utf8'),'owner content');assert.equal(f.remoteSha(),null);
});
test('commit hook failure can resume the same prepared staged set',async t=>{
 const f=fixture(t);const h=f.hook(path.join(f.root,'.git'),'pre-commit','exit 1');await assert.rejects(f.run(),/commit.*failed/);
 assert.equal(f.remoteSha(),null);assert(git(f.root,['diff','--cached','--name-only']));fs.unlinkSync(h);
 const r=await f.run();assert.equal(f.remoteSha(),r.commit);
});
test('failed push retains commit and successful retry does not make another commit',async t=>{
 const f=fixture(t);const h=f.hook(f.remote,'pre-receive','exit 1');await assert.rejects(f.run(),/push.*failed/);
 const committed=git(f.root,['rev-parse','HEAD']);assert.notEqual(committed,f.policy.base);assert.equal(f.remoteSha(),null);assert(!f.logs.includes('OWNER_SOURCE_PUSH=PASS'));
 fs.unlinkSync(h);const r=await f.run();assert.equal(r.commit,committed);assert.equal(f.remoteSha(),committed);
});
test('remote branch ahead of owner rejects without force push or source writes',async t=>{
 const f=fixture(t);const other=path.join(f.dir,'other');git(f.dir,['clone',f.root,other]);git(other,['config','user.email','fixture@example.invalid']);git(other,['config','user.name','Fixture']);
 fs.writeFileSync(path.join(other,'new-remote.txt'),'remote');git(other,['add','new-remote.txt']);git(other,['commit','-m','remote-only update']);
 git(other,['remote','set-url','origin',f.remote]);git(other,['push','origin','HEAD:refs/heads/'+f.policy.branch]);const remote=f.remoteSha();
 const b=before(f);await assert.rejects(f.run(),/merge-base.*failed/);assert.equal(f.remoteSha(),remote);assert.equal(git(f.root,['rev-parse','HEAD']),b.head);assert.equal(git(f.root,['write-tree']),b.index);assert.equal(fs.readFileSync(path.join(f.root,POINTER),'utf8'),b.pointer);
});
test('index.lock is not removed',async t=>{
 const f=fixture(t);const lock=path.join(f.root,'.git/index.lock');fs.writeFileSync(lock,'KEEP');await assert.rejects(f.run(),/index.lock/);assert.equal(fs.readFileSync(lock,'utf8'),'KEEP');
});
test('wrong branch and origin stop before native verification',async t=>{
 const f=fixture(t);git(f.root,['switch','-c','unrelated']);await assert.rejects(f.run(),/Unexpected branch/);git(f.root,['switch',f.policy.branch]);
 await assert.rejects(f.run({allowFixtureRemote:false}),/Unexpected origin/);assert.equal(f.checks,0);
});
test('unreviewed local commits are not silently published',async t=>{
 const f=fixture(t);f.put('local.txt','local');git(f.root,['add','local.txt']);git(f.root,['commit','-m','unreviewed local history']);
 const b=before(f);await assert.rejects(f.run(),/Unreviewed local commits/);untouched(f,b);assert.equal(f.checks,0);
});
test('publication adds its lesson once and preserves owner lessons',async t=>{
 const f=fixture(t);await f.run();await f.run();const text=fs.readFileSync(path.join(f.root,'docs/checkpoints/LESSONS.md'),'utf8');
 assert(text.startsWith('Existing owner lessons.'));assert.equal(text.split('Owner source publisher — 2026-11-02').length-1,1);
});
test('CRLF worktree and BOM JSON publish the Git-normalized snapshot',async t=>{
 const f=fixture(t);git(f.root,['config','core.autocrlf','true']);
 f.put('scripts/game.gd','extends Node\r\n# owner changes\r\n');
 const proof=fs.readFileSync(path.join(f.root,PROOF));f.put(PROOF,Buffer.concat([Buffer.from([239,187,191]),proof]));
 f.put(POINTER,Buffer.from('\uFEFF{"state":"existing-game-state.json"}\r\n'));
 const r=await f.run();assert.equal(f.remoteSha(),r.commit);
 assert.equal(git(f.root,['show',r.commit+':scripts/game.gd']),'extends Node\n# owner changes');
 assert(fs.readFileSync(path.join(f.root,'scripts/game.gd'),'utf8').includes('\r\n'));
});
