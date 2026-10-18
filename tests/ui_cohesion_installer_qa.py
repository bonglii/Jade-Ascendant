from pathlib import Path
import tempfile,subprocess,json,hashlib,sys
repo=Path(__file__).resolve().parents[1];pkg=Path(sys.argv[1]).resolve();m=json.loads((pkg/'manifest.json').read_text())
with tempfile.TemporaryDirectory(prefix='jade-warning-install-') as tmp:
 root=Path(tmp)
 def git(*args):return subprocess.check_output(['git',*args],cwd=root,stderr=subprocess.DEVNULL)
 git('init','-b',m['branch']);git('config','user.name','QA');git('config','user.email','qa@example.invalid')
 for f in m['files']:
  if f['before'] is None:continue
  p=root/f['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(subprocess.check_output(['git','show',m['base']+':'+f['path']],cwd=repo))
 git('add','.');git('commit','-m','fixture baseline');remote=root/'.local/remote.git';remote.parent.mkdir();git('init','--bare',str(remote));git('remote','add','origin',str(remote));git('push','origin',m['branch'])
 p=root/'scripts/ui/home_sanctuary_presenter.gd';original=p.read_bytes();p.write_bytes(original+b'\n# LOCAL_WORK\n')
 cmd=['node',str(pkg/'apply_ui_cohesion.cjs'),str(pkg),str(root)]
 failed=subprocess.run(cmd+['--install-only'],capture_output=True,text=True);assert failed.returncode!=0 and 'Local file differs' in failed.stderr
 assert not (root/'docs/checkpoints/HOME_HERO_COHESION.md').exists()
 p.write_bytes(original)
 notes=root/'docs/checkpoints/LESSONS.md';notes.write_text(notes.read_text()+'\nKEEP_UNRELATED_LOCAL_NOTES\n')
 settings=root/'export_presets.cfg';settings.write_text('KEEP_USER_VERSION_AND_SIGNING')
 for i in range(2):
  r=subprocess.run(cmd+['--install-only'],capture_output=True,text=True);assert r.returncode==0,r.stdout+r.stderr
  if i:assert 'CHANGED=0' in r.stdout
 r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0,r.stdout+r.stderr
 assert 'UI_COHESION_PUBLISHED=PASS' in r.stdout
 assert settings.read_text()=='KEEP_USER_VERSION_AND_SIGNING'
 assert 'KEEP_UNRELATED_LOCAL_NOTES' in notes.read_text()
 assert 'KEEP_UNRELATED_LOCAL_NOTES' not in git('show','HEAD:docs/checkpoints/LESSONS.md').decode()
 for f in m['files']:
  if f.get('append'):continue
  assert (root/f['path']).read_bytes()==(pkg/'payload'/f['path']).read_bytes()
 # A seven-file presentation package is valid; do not reintroduce arbitrary minimum counts.
 minimal=root/'.local/minimal-package';(minimal/'payload').mkdir(parents=True)
 data=b'MINIMAL_VALID_UPDATE';(minimal/'payload/qa-one-file.txt').write_bytes(data)
 (minimal/'manifest.json').write_text(json.dumps({'format':1,'branch':m['branch'],'files':[{'path':'qa-one-file.txt','before':None,'sha256':hashlib.sha256(data).hexdigest()}]}))
 small=subprocess.run(['node',str(pkg/'apply_ui_cohesion.cjs'),str(minimal),str(root),'--install-only'],capture_output=True,text=True)
 assert small.returncode==0,small.stdout+small.stderr
 print('UI_COHESION_INSTALLER_QA=PASS; single-file manifest; source-conflict atomic preflight; idempotent; local notes/settings preserved; scoped commit/push to local bare fixture')
