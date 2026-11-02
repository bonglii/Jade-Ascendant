'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{execFileSync}=require('node:child_process');
const core=require('./tester_batch_tools.cjs'),installer=require('./player_followup_package.cjs');
function git(root,...args){return execFileSync('git',args,{cwd:root,encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();}
function fixture(t){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jade-followup-')),root=path.join(dir,'project'),folder=path.join(dir,'package');
 t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));fs.mkdirSync(path.join(root,'backend/player_identity'),{recursive:true});
 fs.writeFileSync(path.join(root,'project.godot'),'[application]\nconfig/name="fixture"\n');
 fs.mkdirSync(path.join(root,'scripts'));const base='first\nkeep\n'+Array.from({length:12},(_,i)=>'stable '+i+'\n').join('')+'last\n';
 fs.writeFileSync(path.join(root,'scripts/example.gd'),base);
 git(root,'init','-b','main');git(root,'config','user.name','Fixture');git(root,'config','user.email','fixture@example.invalid');git(root,'add','.');git(root,'commit','-m','fixture');git(root,'remote','add','origin','https://github.com/bonglii/Jade-Ascendant.git');
 const sha=git(root,'rev-parse','HEAD');fs.mkdirSync(path.join(folder,'base/scripts'),{recursive:true});fs.mkdirSync(path.join(folder,'incoming/scripts'),{recursive:true});
 const incoming=base.replace('first','updated');fs.writeFileSync(path.join(folder,'base/scripts/example.gd'),base);fs.writeFileSync(path.join(folder,'incoming/scripts/example.gd'),incoming);
 fs.writeFileSync(path.join(folder,'manifest.json'),JSON.stringify({format:core.FORMAT,base:sha,files:[{path:'scripts/example.gd',kind:'text',sha256:core.hash(Buffer.from(incoming)),base_sha256:core.hash(Buffer.from(base))}]}));
 return{dir,root,folder,base,incoming,sha};
}
test('one batch preserves main HEAD, unrelated staged edits and live files; repeat is idempotent',async t=>{
 const f=fixture(t);fs.writeFileSync(path.join(f.root,'unrelated.txt'),'owner work\n');git(f.root,'add','unrelated.txt');
 fs.mkdirSync(path.join(f.root,'release'));fs.writeFileSync(path.join(f.root,'release/protected.cfg'),'live');
 const index=git(f.root,'diff','--cached');
 const first=await installer.run({folder:f.folder,args:['--project',f.root,'--install-only']});
 assert.equal(first.last_changed_files,1);assert.equal(git(f.root,'rev-parse','main'),f.sha);assert.equal(git(f.root,'rev-parse','HEAD'),f.sha);assert.notEqual(git(f.root,'branch','--show-current'),'main');
 assert.equal(git(f.root,'diff','--cached'),index);assert.equal(fs.readFileSync(path.join(f.root,'release/protected.cfg'),'utf8'),'live');
 assert.equal(fs.readFileSync(path.join(first.last_backup,'scripts/example.gd'),'utf8'),f.base);
 const second=await installer.run({folder:f.folder,args:['--project',f.root,'--install-only']});assert.equal(second.last_changed_files,0);
 assert.equal(git(f.root,'rev-list','--all','--count'),'1');
});
test('nonoverlapping owner edits survive three-way install',async t=>{
 const f=fixture(t);fs.writeFileSync(path.join(f.root,'scripts/example.gd'),f.base.replace('last','owner last'));
 await installer.run({folder:f.folder,args:['--project',f.root,'--install-only']});
 const text=fs.readFileSync(path.join(f.root,'scripts/example.gd'),'utf8');assert.ok(text.startsWith('updated'));assert.ok(text.includes('owner last'));
});
test('overlap stops the entire plan before source or branch changes',async t=>{
 const f=fixture(t);fs.writeFileSync(path.join(f.root,'scripts/example.gd'),f.base.replace('first','owner first'));
 const manifest=JSON.parse(fs.readFileSync(path.join(f.folder,'manifest.json')));const bytes=Buffer.from('new\n');fs.writeFileSync(path.join(f.folder,'incoming/scripts/new.gd'),bytes);manifest.files.unshift({path:'scripts/new.gd',kind:'text',sha256:core.hash(bytes),base_sha256:null});fs.writeFileSync(path.join(f.folder,'manifest.json'),JSON.stringify(manifest));
 await assert.rejects(installer.run({folder:f.folder,args:['--project',f.root,'--install-only']}),/no source writes/);
 assert.equal(git(f.root,'branch','--show-current'),'main');assert.ok(!fs.existsSync(path.join(f.root,'scripts/new.gd')));assert.ok(fs.readFileSync(path.join(f.root,'scripts/example.gd'),'utf8').startsWith('owner first'));
});
test('QA receipt reuses identical inputs; source and engine changes invalidate it',async t=>{
 const f=fixture(t),engine=path.join(f.dir,'engine');fs.writeFileSync(engine,'engine v1');let checks=0;
 const qa={resolveGodot:()=>engine,check:async()=>{checks++;return{pass:true,suites:['fixture']};}};
 const run=()=>installer.run({folder:f.folder,args:['--project',f.root],qaOverride:qa});
 await run();await run();assert.equal(checks,1);
 fs.writeFileSync(path.join(f.root,'scripts/owner.gd'),'owner dependency');await run();assert.equal(checks,2);
 fs.writeFileSync(engine,'engine v2');await run();assert.equal(checks,3);assert.equal(git(f.root,'rev-list','--all','--count'),'1');
});
test('publishing flags and protected release configuration are rejected',async t=>{
 const f=fixture(t);await assert.rejects(installer.run({folder:f.folder,args:['--project',f.root,'--push']}),/Unknown flag/);
 const manifest=JSON.parse(fs.readFileSync(path.join(f.folder,'manifest.json')));manifest.files[0].path='release/release_config.gd';fs.writeFileSync(path.join(f.folder,'manifest.json'),JSON.stringify(manifest));
 await assert.rejects(installer.run({folder:f.folder,args:['--project',f.root,'--install-only']}),/outside batch scope|Protected configuration/);
 assert.equal(git(f.root,'branch','--show-current'),'main');
});
test('a failed or interrupted new QA cannot retain a current pass receipt',async t=>{
 const f=fixture(t),engine=path.join(f.dir,'engine');fs.writeFileSync(engine,'engine');let fail=false;
 const qa={resolveGodot:()=>engine,check:async()=>{if(fail)throw Error('interrupted fixture');return{pass:true,suites:['fixture']};}};
 const run=()=>installer.run({folder:f.folder,args:['--project',f.root],qaOverride:qa});
 await run();fs.writeFileSync(path.join(f.root,'scripts/owner.gd'),'new dependency');fail=true;
 await assert.rejects(run(),/interrupted fixture/);
 const state=JSON.parse(fs.readFileSync(path.join(f.root,'.local/player_followup_batch/receipt.json')));
 assert.equal(state.local_qa,false);assert.ok(state.pending_qa_key);fail=false;
 const resumed=await run();assert.equal(resumed.local_qa,true);assert.ok(!resumed.pending_qa_key);
});
