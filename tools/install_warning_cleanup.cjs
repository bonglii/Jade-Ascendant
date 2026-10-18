'use strict';
// Node avoids Windows PowerShell command shadowing and quoting differences.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const normalize = b => b.toString('utf8').replace(/\r\n/g, '\n');
function runGit(root, args, input) {
  const r = cp.spawnSync('git', args, {cwd:root, encoding:'utf8', shell:false, input});
  if (r.error || r.status !== 0) throw Error(`git ${args[0]} failed: ${r.stderr || r.error}`);
  return r.stdout.trim();
}
function safe(root, rel) {
  if (typeof rel !== 'string' || !rel || rel.includes('\\') || rel.split('/').some(x => !x || x === '.' || x === '..') || path.isAbsolute(rel)) throw Error('Invalid package path');
  const full = path.resolve(root, rel);
  let at = full;
  while (at !== path.dirname(at) && at !== root) {
    if (fs.existsSync(at) && fs.lstatSync(at).isSymbolicLink()) throw Error(`Symlink not allowed: ${rel}`);
    at = path.dirname(at);
  }
  return full;
}
function configMerge(buf, changes) {
  const original = buf.toString('utf8');
  const newline = original.includes('\r\n') ? '\r\n' : '\n';
  const lines = original.replace(/\r\n/g, '\n').split('\n');
  // Export preset indices/counts are local editor state, not a package contract.
  if (changes.some(c => /^preset\.\d+\.options$/.test(c.section))) {
    const template = new Map(changes.map(c => [c.key, c]));
    template.set('splash_screen/disable_godot_boot_splash', {key:'splash_screen/disable_godot_boot_splash', before:'false', after:'true'});
    const android = [];
    for (let i = 0; i < lines.length; i++) {
      const match = /^\[(preset\.\d+)\]$/.exec(lines[i]);
      if (!match) continue;
      let end = i + 1;
      while (end < lines.length && !/^\[/.test(lines[end])) end++;
      if (lines.slice(i + 1, end).some(line => /^platform\s*=\s*"Android"\s*$/.test(line))) android.push(match[1] + '.options');
    }
    if (!android.length) throw Error('No Android export preset found; nothing installed.');
    changes = [];
    for (const section of android) {
      if (!lines.includes(`[${section}]`)) lines.push('', `[${section}]`);
      for (const c of template.values()) changes.push({...c, section, missingAllowed:true});
    }
  }
  for (const c of changes) {
    const start = lines.indexOf(`[${c.section}]`);
    if (start < 0) throw Error(`Missing section ${c.section}`);
    let end = start + 1;
    while (end < lines.length && !/^\[/.test(lines[end])) end++;
    const matches = [];
    for (let i = start + 1; i < end; i++) if (lines[i].startsWith(c.key + '=')) matches.push(i);
    if (matches.length > 1) throw Error(`Duplicate configuration key ${c.key}`);
    if (matches.length) {
      const i = matches[0], value = lines[i].slice(c.key.length + 1);
      if (value !== c.before && value !== c.after) throw Error(`Configuration changed locally: ${c.section}/${c.key}`);
      lines[i] = c.key + '=' + c.after;
    } else {
      if (c.before !== null && !c.missingAllowed) throw Error(`Missing configuration key ${c.key}`);
      lines.splice(end, 0, c.key + '=' + c.after);
    }
  }
  return Buffer.from(lines.join(newline));
}
function install(pkg, root) {
  root = fs.realpathSync(root);
  const manifest = JSON.parse(fs.readFileSync(path.join(pkg, 'manifest.json'), 'utf8'));
  if (manifest.format !== 1 || !Array.isArray(manifest.files) || manifest.files.length < 10) throw Error('Invalid package manifest');
  const branch = runGit(root, ['branch', '--show-current']);
  if (branch !== manifest.branch) throw Error(`Use branch ${manifest.branch}; current=${branch}`);
  const lock = runGit(root, ['rev-parse', '--git-path', 'index.lock']);
  if (fs.existsSync(path.resolve(root, lock))) throw Error('Git index.lock exists; no files changed. Check active Git processes.');
  const writes = [], seen = new Set();
  for (const f of manifest.files) {
    if (seen.has(f.path)) throw Error('Duplicate package path');
    seen.add(f.path);
    const dest = safe(root, f.path);
    const payload = fs.readFileSync(safe(path.resolve(pkg, 'payload'), f.path));
    if (hash(payload) !== f.sha256) throw Error(`Package hash mismatch: ${f.path}`);
    const current = fs.existsSync(dest) ? fs.readFileSync(dest) : null;
    let next = payload;
    if (f.config) {
      if (!current) throw Error(`Missing config ${f.path}`);
      next = configMerge(current, f.config);
    } else if (f.append) {
      if (typeof f.appendText !== 'string' || !Buffer.from(f.appendText).equals(payload)) throw Error('Invalid append section');
      if (!current) throw Error(`Missing notes ${f.path}`);
      next = normalize(current).includes(normalize(payload).trim()) ? current : Buffer.concat([current, Buffer.from('\n'), payload]);
    } else if (current && hash(current) !== f.sha256 && hash(current) !== f.before && !(f.text && hash(Buffer.from(normalize(current))) === f.beforeNormalized)) {
      throw Error(`Local file differs; nothing installed: ${f.path}`);
    } else if (!current && f.before !== null) throw Error(`Missing original file: ${f.path}`);
    if (!current || !current.equals(next)) writes.push({dest, rel:f.path, current, next});
  }
  const backup = path.join(root, '.local', 'warning_cleanup_install', crypto.randomUUID());
  fs.mkdirSync(backup, {recursive:true});
  for (const w of writes) {
    if (w.current) { const b = path.join(backup, w.rel); fs.mkdirSync(path.dirname(b), {recursive:true}); fs.writeFileSync(b, w.current); }
  }
  fs.writeFileSync(path.join(backup, 'new-files.json'), JSON.stringify(writes.filter(w => !w.current).map(w => w.rel)));
  try {
    for (const w of writes) { fs.mkdirSync(path.dirname(w.dest), {recursive:true}); fs.writeFileSync(w.dest, w.next); }
  } catch (e) {
    for (const w of writes) { if (w.current) fs.writeFileSync(w.dest, w.current); else if (fs.existsSync(w.dest)) fs.unlinkSync(w.dest); }
    throw e;
  }
  console.log(`WARNING_CLEANUP_INSTALL=PASS; CHANGED=${writes.length}; BACKUP=${backup}`);
  return manifest;
}
function publish(root, manifest) {
  const branch = manifest.branch;
  const allowed = new Set(manifest.files.map(f => f.path));
  const staged = runGit(root, ['diff', '--cached', '--name-only', '-z']).split('\0').filter(Boolean);
  if (staged.length) throw Error('Files are already staged; installation preserved. Commit or unstage those separately before publishing.');
  runGit(root, ['fetch', 'origin', `refs/heads/${branch}`]);
  const remote = runGit(root, ['rev-parse', 'FETCH_HEAD']);
  runGit(root, ['merge-base', '--is-ancestor', remote, 'HEAD']);
  const outgoing = runGit(root, ['diff', '--name-only', `${remote}..HEAD`]).split('\n').filter(Boolean);
  if (outgoing.some(p => !allowed.has(p))) throw Error('Unrelated local commits would be pushed; review separately. No force push.');
  for (const f of manifest.files) {
    if (f.config || f.append) {
      // Stage branding-only changes; keep local version/signing/notes unstaged.
      const original = Buffer.from(runGit(root, ['show', `HEAD:${f.path}`]) + '\n');
      const payload = fs.readFileSync(path.join(root, f.path));
      let stagedContent;
      if (f.config) stagedContent = configMerge(original, f.config);
      else {
        if (typeof f.appendText !== 'string' || hash(Buffer.from(f.appendText)) !== f.sha256) throw Error('Invalid append section');
        const addition = Buffer.from(f.appendText);
        if (!normalize(payload).includes(normalize(addition).trim())) throw Error('Installed lesson section missing');
        stagedContent = normalize(original).includes(normalize(addition).trim()) ? original : Buffer.concat([original, Buffer.from('\n'), addition]);
      }
      const blob = runGit(root, ['hash-object', '-w', '--stdin'], stagedContent);
      runGit(root, ['update-index', '--add', '--cacheinfo', `100644,${blob},${f.path}`]);
    } else runGit(root, ['add', '--', `:(literal)${f.path}`]);
  }
  runGit(root, ['diff', '--cached', '--check']);
  if (runGit(root, ['diff', '--cached', '--name-only'])) runGit(root, ['commit', '-m', 'fix(warnings): resolve ternary types and check all enabled categories']);
  runGit(root, ['push', 'origin', `HEAD:refs/heads/${branch}`]);
  const commit = runGit(root, ['rev-parse', 'HEAD']);
  console.log(`WARNING_CLEANUP_PUBLISHED=PASS\nhttps://github.com/bonglii/Jade-Ascendant/commit/${commit}`);
}
if (require.main === module) {
  try {
    const pkg = path.resolve(process.argv[2] || '.');
    const root = path.resolve(process.argv[3] || 'D:/Godot/project/jade-ascendant');
    const m = install(pkg, root);
    if (!process.argv.includes('--install-only')) publish(root, m);
  } catch (e) { console.error(`WARNING_CLEANUP_STOPPED: ${e.message}`); process.exitCode = 1; }
}
module.exports = {install, configMerge, publish};
