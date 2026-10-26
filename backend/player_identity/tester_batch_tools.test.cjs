'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {spawnSync}=require('node:child_process');
const T=require('./tester_batch_tools.cjs');
function fixture(){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jade-tester-package-')),root=path.join(dir,'project'),pkg=path.join(dir,'renamed-download');fs.mkdirSync(root);fs.mkdirSync(pkg);
 const git=(args)=>{const r=spawnSync('git',args,{cwd:root,encoding:'utf8'});assert.equal(r.status,0,r.stderr);return r.stdout;};git(['init','-q']);git(['config','user.email','isolated-qa@example.invalid']);git(['config','user.name','Isolated QA']);
 const put=(relative,content)=>{const p=path.join(root,relative);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,content);};
 const entries=[];
 function file(relative,base,incoming,local=base,kind='text'){
  if(local!==null)put(relative,local);
  for(const [folder,content]of [['base',base],['incoming',incoming]])if(content!==null){const p=path.join(pkg,folder,relative);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,content);}
  entries.push({path:relative,kind,sha256:T.hash(Buffer.from(incoming)),base_sha256:base===null?null:T.hash(Buffer.from(base))});
 }
 function manifest(){fs.writeFileSync(path.join(pkg,'manifest.json'),JSON.stringify({format:T.FORMAT,base:'a'.repeat(40),files:entries}));return T.readPackage(pkg);}
 return{dir,root,pkg,git,put,file,manifest,close(){fs.rmSync(dir,{recursive:true,force:true});}};
}
test('self-contained renamed package accepts CRLF and retry makes zero source writes',()=>{
 const f=fixture();try{f.file('scripts/test.gd','a\nb\n','a\nc\n','a\r\nb\r\n');const m=f.manifest();let p=T.prepareInstall(f.root,f.pkg,m,path.join(f.dir,'review'));
 assert.equal(T.applyInstall(f.root,p,path.join(f.dir,'backup')),1);assert.equal(fs.readFileSync(path.join(f.root,'scripts/test.gd'),'utf8'),'a\nc\n');
 p=T.prepareInstall(f.root,f.pkg,m,path.join(f.dir,'retry'));assert.equal(p.length,0);
 }finally{f.close();}
});
test('non-overlapping owner edits merge while unrelated files remain intact',()=>{
 const f=fixture();try{f.put('project.godot','owner-version-35\n');f.file('scripts/test.gd','a\nb\nc\nd\n','a\nb\nc\nupdated\n','owner\nb\nc\nd\n');
 const p=T.prepareInstall(f.root,f.pkg,f.manifest(),path.join(f.dir,'review'));T.applyInstall(f.root,p,path.join(f.dir,'backup'));
 assert.equal(fs.readFileSync(path.join(f.root,'scripts/test.gd'),'utf8'),'owner\nb\nc\nupdated\n');assert.equal(fs.readFileSync(path.join(f.root,'project.godot'),'utf8'),'owner-version-35\n');assert.equal(T.prepareInstall(f.root,f.pkg,f.manifest(),path.join(f.dir,'retry')).length,0);
 }finally{f.close();}
});
test('a true overlap stops the entire install before any source write',()=>{
 const f=fixture();try{f.file('scripts/first.gd','old\n','new\n');f.file('scripts/conflict.gd','base\n','incoming\n','local\n');
 assert.throws(()=>T.prepareInstall(f.root,f.pkg,f.manifest(),path.join(f.dir,'review')),/no source writes/);
 assert.equal(fs.readFileSync(path.join(f.root,'scripts/first.gd'),'utf8'),'old\n');assert.equal(fs.readFileSync(path.join(f.root,'scripts/conflict.gd'),'utf8'),'local\n');
 }finally{f.close();}
});
test('Unicode lessons and owner checkpoint are idempotent across interrupted resumes',()=>{
 const f=fixture();try{f.file('docs/checkpoints/LESSONS.md','Catatan — awal\n','Catatan — awal\n\n### New\n- Once.\n','Catatan — awal\n- Owner note.\n');
 f.file('docs/checkpoints/CURRENT_WORK.json',JSON.stringify({state:'old'}),JSON.stringify({state:'new',previous:'old'}),JSON.stringify({state:'owner-current',extra:true}));
 let p=T.prepareInstall(f.root,f.pkg,f.manifest(),path.join(f.dir,'review'));T.applyInstall(f.root,p,path.join(f.dir,'backup'));
 p=T.prepareInstall(f.root,f.pkg,f.manifest(),path.join(f.dir,'retry'));T.applyInstall(f.root,p,path.join(f.dir,'backup2'));
 const lessons=fs.readFileSync(path.join(f.root,'docs/checkpoints/LESSONS.md'),'utf8');assert.equal((lessons.match(/### New/g)||[]).length,1);assert.ok(lessons.includes('Owner note.'));
 const state=JSON.parse(fs.readFileSync(path.join(f.root,'docs/checkpoints/CURRENT_WORK.json')));assert.deepEqual(state,{state:'new',extra:true,previous:'owner-current'});
 }finally{f.close();}
});
test('payload corruption and changing editor files stop before writes',()=>{
 const f=fixture();try{f.file('scripts/test.gd','base\n','incoming\n');const m=f.manifest();const p=T.prepareInstall(f.root,f.pkg,m,path.join(f.dir,'review'));f.put('scripts/test.gd','editor update\n');
 assert.throws(()=>T.applyInstall(f.root,p,path.join(f.dir,'backup')),/File changed while planning/);
 fs.writeFileSync(path.join(f.pkg,'incoming/scripts/test.gd'),'corrupt');assert.throws(()=>T.readPackage(f.pkg),/Corrupted incoming/);
 }finally{f.close();}
});
test('Git lock is preserved and narrow commit retains unrelated staged work',()=>{
 const f=fixture();try{f.put('scripts/a.gd','old\n');f.put('project.godot','version35\n');f.git(['add','.']);f.git(['commit','-qm','base']);
 const lock=path.join(f.root,'.git/index.lock');fs.writeFileSync(lock,'');assert.throws(()=>T.assertNoIndexLock(f.root),/index.lock/);assert.ok(fs.existsSync(lock));fs.unlinkSync(lock);
 f.put('project.godot','version36\n');f.git(['add','project.godot']);f.put('scripts/a.gd','new\n');
 const list=path.join(f.dir,'paths');fs.writeFileSync(list,'scripts/a.gd\0');f.git(['add','--pathspec-from-file='+list,'--pathspec-file-nul']);f.git(['commit','--only','--pathspec-from-file='+list,'--pathspec-file-nul','-m','batch']);
 assert.equal(f.git(['diff','--cached','--name-only']).trim(),'project.godot');assert.equal(f.git(['show','HEAD:project.godot']),'version35\n');assert.equal(f.git(['show','HEAD:scripts/a.gd']),'new\n');
 }finally{f.close();}
});
