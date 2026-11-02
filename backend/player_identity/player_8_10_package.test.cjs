'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const core=require('./player_8_10_tools.cjs'),native=require('./player_8_10_native_check.cjs'),{ensureWorkBranch}=require('./player_8_10_package.cjs');
function workspace(fn){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jade-810-installer-'));try{return fn(dir);}finally{fs.rmSync(dir,{recursive:true,force:true});}}
function put(root,relative,text){const file=path.join(root,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,text);}
function fixture(dir,extra=[]){
 const folder=path.join(dir,'package'),root=path.join(dir,'project');fs.mkdirSync(root,{recursive:true});
 const entries=[['release/native/JadeMonetizationNativeBridge-production-candidate.aar','binary','old-binary','new-binary'],['docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json','text','{}','{"next":true}'],['backend/player_identity/export_production.ps1','text','old-pin','new-pin'],...extra];
 const manifest={format:core.FORMAT,base:'a'.repeat(40),files:entries.map(([relative,kind,old,next])=>{if(old!==null){put(root,relative,old);put(folder,'base/'+relative,old);}put(folder,'incoming/'+relative,next);return {path:relative,kind,base_sha256:old===null?null:core.hash(Buffer.from(old)),sha256:core.hash(Buffer.from(next))};})};put(folder,'manifest.json',JSON.stringify(manifest));return {folder,root,manifest};
}
test('reviewed candidate updates are backed up and rerun is idempotent',()=>workspace(dir=>{
 const {folder,root}=fixture(dir);const m=core.readPackage(folder),plans=core.prepareInstall(root,folder,m,path.join(dir,'review'));assert.equal(plans.length,3);
 core.applyInstall(root,plans,path.join(dir,'backup'));assert.equal(fs.readFileSync(path.join(dir,'backup/release/native/JadeMonetizationNativeBridge-production-candidate.aar'),'utf8'),'old-binary');
 assert.equal(core.prepareInstall(root,folder,m,path.join(dir,'review-again')).length,0);
}));
test('an edited binary conflicts before any source file is written',()=>workspace(dir=>{
 const {folder,root}=fixture(dir);put(root,'release/native/JadeMonetizationNativeBridge-production-candidate.aar','owner-binary');
 assert.throws(()=>core.prepareInstall(root,folder,core.readPackage(folder),path.join(dir,'review')),/Overlapping edits preserved/);
 assert.equal(fs.readFileSync(path.join(root,'backend/player_identity/export_production.ps1'),'utf8'),'old-pin');
}));
test('installed plugins, signing and production config remain forbidden package paths',()=>workspace(dir=>{
 for(const relative of ['addons/JadeMonetizationNativeBridge/bin/release/JadeMonetizationNativeBridge-release.aar','backend/monetization/cloudflare/wrangler.production-live.toml','backend/private.keystore']){
  const {folder}=fixture(path.join(dir,relative.replaceAll('/','_')),[[relative,'binary',null,'forbidden']]);assert.throws(()=>core.readPackage(folder),/Protected configuration|Path outside batch/);
 }
}));
test('path traversal and a candidate without an exact binary baseline are rejected',()=>workspace(dir=>{
 const {folder,manifest}=fixture(dir);manifest.files[0].path='../escape.aar';put(folder,'manifest.json',JSON.stringify(manifest));assert.throws(()=>core.readPackage(folder),/Invalid package path/);
 manifest.files[0].path='release/native/JadeMonetizationNativeBridge-production-candidate.aar';manifest.files[0].base_sha256=null;put(folder,'manifest.json',JSON.stringify(manifest));assert.throws(()=>core.readPackage(folder),/exact existing binary baseline/);
}));
test('native preflight rejects tampered source, candidate and export helper',()=>{
 const root=path.resolve(__dirname,'../..');assert.equal(native.validate(root).source_inputs,50);
 const proof=JSON.parse(fs.readFileSync(path.join(root,'docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json')));
 for(const altered of [Object.keys(proof.inputs)[0],'release/native/JadeMonetizationNativeBridge-production-candidate.aar','backend/player_identity/production_native_overlay.ps1']){
  assert.throws(()=>native.validate(root,relative=>relative===altered?Buffer.from('tampered'):fs.readFileSync(path.join(root,relative))),/mismatch|changed/);
 }
});
test('synthetic Git fixture preserves main, staged work and local edits on a new branch',()=>workspace(root=>{
 const git=args=>core.command('git',args,root);git(['init','-b','main']);git(['config','user.name','QA Fixture']);git(['config','user.email','qa@example.invalid']);put(root,'owner.txt','base');git(['add','owner.txt']);git(['commit','-qm','synthetic fixture only']);
 const main=git(['rev-parse','main']);put(root,'owner.txt','local-staged');git(['add','owner.txt']);put(root,'untracked.txt','keep');
 const index=git(['diff','--cached']);const branch=ensureWorkBranch(root);
 assert.match(branch,/^work\/player-8-10-20261027/);assert.equal(git(['rev-parse','main']),main);assert.equal(git(['diff','--cached']),index);assert.equal(fs.readFileSync(path.join(root,'untracked.txt'),'utf8'),'keep');
}));

test('source validation preserves an opaque existing bridge without approving it as candidate',()=>{
 const root=path.resolve(__dirname,'../..'),ownerBytes=Buffer.from('owner-compiled bridge');
 const receipt=native.validate(root,relative=>relative===native.INSTALLED?ownerBytes:fs.readFileSync(path.join(root,relative)));
 assert.equal(receipt.installed_bridge.sha256,native.hash(ownerBytes));assert.equal(receipt.installed_bridge.used_as_candidate,false);assert.equal(receipt.candidate_sha256,require('../../docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json').aar_sha256);
});
test('a known R1 added file upgrades safely, while unrelated owner changes still conflict',()=>workspace(dir=>{
 const {folder,root,manifest}=fixture(dir,[['backend/player_identity/new_file.cjs','text',null,'revision two']]);
 const row=manifest.files.at(-1);put(root,row.path,'revision one');put(folder,'previous/'+row.path,'revision one');row.previous_sha256=core.hash(Buffer.from('revision one'));put(folder,'manifest.json',JSON.stringify(manifest));
 const checked=core.readPackage(folder);assert.equal(core.prepareInstall(root,folder,checked,path.join(dir,'review')).length,4);
 put(root,row.path,'owner unrelated version');assert.throws(()=>core.prepareInstall(root,folder,checked,path.join(dir,'held')),/Overlapping edits preserved/);
 put(folder,'previous/'+row.path,'tampered previous');assert.throws(()=>core.readPackage(folder),/Corrupted previous batch file/);
}));
test('an unfinished export is held rather than changing its native file',()=>workspace(dir=>{
 put(dir,'.local/production_native_export/active.json','{}');assert.throws(()=>native.validate(dir),/export recovery receipt/);
}));
