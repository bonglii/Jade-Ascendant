'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const cp = require('node:child_process');
const {install, configMerge, publish} = require('../tools/install_branding.cjs');
const repo = path.resolve(__dirname, '..');
const pkg = path.resolve(process.argv[2]);
const manifest = JSON.parse(fs.readFileSync(path.join(pkg, 'manifest.json')));
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'jade-brand-installer-'));
function git(args) {const r = cp.spawnSync('git', args, {cwd:root,encoding:'utf8'});assert.equal(r.status,0,r.stderr);}
try {
  git(['init', '-b', manifest.branch]);
  for (const f of manifest.files) {
    if (f.before === null) continue;
    const r=cp.spawnSync('git',['show',`${manifest.base}:${f.path}`],{cwd:repo});
    assert.equal(r.status,0);
    const dest=path.join(root,f.path);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,r.stdout);
  }
  git(['config','user.name','Branding fixture']);git(['config','user.email','fixture@example.invalid']);
  git(['add','.']);git(['commit','-m','fixture baseline']);
  const remote=path.join(root,'.local','remote.git');fs.mkdirSync(path.dirname(remote),{recursive:true});
  git(['init','--bare',remote]);git(['remote','add','origin',remote]);git(['push','origin',manifest.branch]);
  const presets=path.join(root,'export_presets.cfg');
  const exportChanges=manifest.files.find(f=>f.path==='export_presets.cfg').config;
  const android='[preset.0]\nname="Android"\nplatform="Android"\n[preset.0.options]\nversion/code=987\nsplash_screen/icon=""\nsplash_screen/background_color=Color(0, 0, 0, 1)\n';
  for (const index of [0,3,12]) {
    const fixture=android.replaceAll('preset.0','preset.'+index)+'\n[preset.7]\nplatform="Windows Desktop"\n[preset.7.options]\nsplash_screen/icon="windows.png"\n';
    const merged=configMerge(Buffer.from(fixture),exportChanges).toString();
    assert(merged.includes('splash_screen/disable_godot_boot_splash=true'));
    assert(merged.includes('splash_screen/icon="res://assets/branding/boot_seal.png"'));
    assert(merged.includes('splash_screen/icon="windows.png"'));
    assert(merged.includes('version/code=987'));
    assert(!merged.includes('[preset.1.options]'));
  }
  const noOptions=configMerge(Buffer.from('[preset.4]\nplatform="Android"\n'),exportChanges).toString();
  assert(noOptions.includes('[preset.4.options]'));
  assert.throws(()=>configMerge(Buffer.from('[preset.0]\nplatform="Windows Desktop"\n'),exportChanges),/No Android/);
  // Reproduce the actual report: local editor contains one Android preset only.
  let local=fs.readFileSync(presets,'utf8');
  const second=local.indexOf('[preset.1]');
  if(second>=0)local=local.slice(0,second);
  fs.writeFileSync(presets,local);

  fs.appendFileSync(presets,'\n; KEEP_USER_SIGNING_AND_VERSION\n');
  let src=fs.readFileSync(presets,'utf8');src=src.replace('version/code=7','version/code=987').replace(/\n/g,'\r\n');fs.writeFileSync(presets,src);
  fs.writeFileSync(path.join(root,'unrelated.txt'),'USER WORK');
  const target=path.join(root,'scripts/system/boot.gd'), old=fs.readFileSync(target);
  fs.appendFileSync(target,'\n# user changed boot\n');
  assert.throws(()=>install(pkg,root),/Local file differs/);
  assert.equal(fs.existsSync(path.join(root,'assets/branding/jade_seal_master.png')),false);
  fs.writeFileSync(target,old);
  fs.writeFileSync(path.join(root,'.git/index.lock'),'');
  assert.throws(()=>install(pkg,root),/index.lock/);
  fs.unlinkSync(path.join(root,'.git/index.lock'));
  install(pkg,root);
  const result=fs.readFileSync(presets,'utf8');
  assert(result.includes('; KEEP_USER_SIGNING_AND_VERSION'));
  if(src.includes('version/code=987')) assert(result.includes('version/code=987'));
  assert.equal(result.replace(/\r\n/g,'').includes('\n'),false);
  assert.equal(fs.readFileSync(path.join(root,'unrelated.txt'),'utf8'),'USER WORK');
  const before=fs.readFileSync(target);install(pkg,root);assert.deepEqual(fs.readFileSync(target),before);
  assert.throws(()=>configMerge(Buffer.from('[application]\nconfig/icon="custom.png"\n'),[{section:'application',key:'config/icon',before:'"old.png"',after:'"new.png"'}]),/changed locally/);
  const payload=path.join(pkg,'payload/scripts/system/boot.gd'), original=fs.readFileSync(payload);
  try {fs.appendFileSync(payload,'tampered');assert.throws(()=>install(pkg,root),/Package hash mismatch/);} finally {fs.writeFileSync(payload,original);}
  const logger=console.log;console.log=()=>{};
  try {publish(root,manifest);} finally {console.log=logger;}
  const committed=cp.spawnSync('git',['show','HEAD:export_presets.cfg'],{cwd:root,encoding:'utf8'});
  assert.equal(committed.status,0);assert(!committed.stdout.includes('KEEP_USER_SIGNING_AND_VERSION'));
  assert(!committed.stdout.includes('version/code=987'));
  assert(fs.readFileSync(presets,'utf8').includes('KEEP_USER_SIGNING_AND_VERSION'));
  console.log('BRANDING_PUBLISHER_QA=PASS; LOCAL_BARE_REMOTE_ONLY; branding-only config staging; user settings remain unstaged');
  console.log('BRANDING_INSTALLER_QA=PASS; preserve-local-config, CRLF, unrelated-work, preflight-conflict, lock, idempotency, tamper');
} finally {fs.rmSync(root,{recursive:true,force:true});}
