'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {runProcess}=require('./check_event_touch.cjs');
test('first actual Godot error remains visible after long import progress',async()=>{
 const logs=fs.mkdtempSync(path.join(os.tmpdir(),'jade-first-error-')),messages=[],original=console.error;
 console.error=(...args)=>messages.push(args.join(' '));
 try{
  const script="process.stderr.write('SCRIPT ERROR: Parse Error: missing importer ROOT_CAUSE\\n');setTimeout(()=>{process.stdout.write(('normal import progress\\n').repeat(4000));},30);";
  await assert.rejects(runProcess(process.execPath,['-e',script],{logs,name:'first-error',idleMs:10000,totalMs:10000,heartbeatMs:10000}),/GODOT_ERROR/);
  assert.match(messages.join('\n'),/ROOT_CAUSE/);
  const receipt=JSON.parse(fs.readFileSync(path.join(logs,'first-error.json'),'utf8'));
  assert.equal(receipt.exit_code,0);assert.equal(receipt.reason,'GODOT_ERROR');
  assert.ok(fs.readFileSync(path.join(logs,'first-error.log'),'utf8').includes('normal import progress'));
 }finally{console.error=original;fs.rmSync(logs,{recursive:true,force:true});}
});
test('audio QA rejects an omitted importer sidecar before invoking Godot',()=>{
 const root=path.resolve(__dirname,'../..'),fixture=fs.mkdtempSync(path.join(os.tmpdir(),'jade-metadata-regression-'));
 try{
  const files=['tests/chinese_music_qa.cjs','scripts/managers/audio_manager.gd','assets/audio/chinese_music/provenance.json','assets/audio/chinese_music/lotus_pond_loop.ogg','assets/audio/chinese_music/dragon_dance_loop.ogg','assets/audio/chinese_music/lotus_pond_loop.ogg.import','assets/audio/chinese_music/dragon_dance_loop.ogg.import'];
  for(const name of files){const dest=path.join(fixture,name);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,name),dest);}
  const cp=require('node:child_process'),run=()=>cp.spawnSync(process.execPath,[path.join(fixture,'tests/chinese_music_qa.cjs'),'--source-only'],{encoding:'utf8',timeout:10000});
  const valid=run();assert.equal(valid.status,0,valid.stderr);assert.match(valid.stdout,/IMPORT_METADATA=2/);
  fs.unlinkSync(path.join(fixture,'assets/audio/chinese_music/lotus_pond_loop.ogg.import'));
  const missing=run();assert.notEqual(missing.status,0);assert.match(missing.stderr,/lotus_pond_loop\.ogg\.import/);
 }finally{fs.rmSync(fixture,{recursive:true,force:true});}
});
