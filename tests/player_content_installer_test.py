"""Real PowerShell installer fixtures in disposable Git projects; Linux author QA."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
def sha(data):return hashlib.sha256(data).hexdigest()
def text(data):return data.decode('utf-8-sig').replace('\r\n','\n')
def snapshot(folder):
 return {str(p.relative_to(folder)):sha(p.read_bytes()) for p in folder.rglob('*') if p.is_file() and '.git' not in p.relative_to(folder).parts and '.local' not in p.relative_to(folder).parts}
def golden(ref,folder,paths):
 folder.mkdir()
 for relative in paths:
  got=subprocess.run(['git','show',ref+':'+relative],cwd=ROOT,capture_output=True)
  if got.returncode:continue
  target=folder/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(got.stdout)
 for args in [['init','-q'],['config','user.name','Jade Fixture'],['config','user.email','qa@example.invalid'],['checkout','-qb','work/fixture-owner'],['add','--all'],['commit','-qm','isolated fixture baseline']]:subprocess.run(['git']+args,cwd=folder,check=True,capture_output=True)
def run(pwsh,package,folder,log,restricted=False):
 prefix=[shutil.which('setpriv'),'--bounding-set=-dac_override,-dac_read_search'] if restricted else []
 if restricted:assert prefix[0], 'setpriv required for the root permission-denial fixture'
 env=os.environ.copy();env['POWERSHELL_TELEMETRY_OPTOUT']='1';env['POWERSHELL_UPDATECHECK']='Off'
 p=subprocess.run(prefix+[pwsh,'-NoLogo','-NoProfile','-File',str(package/'apply_and_test.ps1'),'-ProjectPath',str(folder),'-PackageRoot',str(package),'-ApplyOnly'],capture_output=True,text=True,timeout=120,env=env)
 output=p.stdout+p.stderr;log.write_text(output);return p.returncode,output
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--package',required=True);parser.add_argument('--pwsh',required=True);parser.add_argument('--result',required=True);parser.add_argument('--cases');args=parser.parse_args()
 package=Path(args.package).resolve();manifest=json.loads((package/'manifest.json').read_text());proof=json.loads((ROOT/'docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json').read_text())
 scope={x['path'] for x in manifest['files']}|set(proof['inputs'])|{'project.godot','AGENTS.md','docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json','release/native/JadeMonetizationNativeBridge-production-candidate.aar','addons/JadeMonetizationNativeBridge/bin/release/JadeMonetizationNativeBridge-release.aar','backend/player_identity/export_production.ps1','backend/player_identity/production_native_overlay.ps1'}
 work=Path(tempfile.mkdtemp(prefix='jade_player_content_installer_qa_',dir=ROOT.parent));results=[];repeats=0
 bases={'a5':'a5d2bf42586067ef1ef4d6460b7a4d291f9b869b','755':'75578e09ef3f5ff2756a1d877d8e4f82c73751be','4c94':'4c94ebc930682c9d1deafdee5e09941093b8953b','b4cd':'b4cd3ae3cdc0aebe7ea901e866131629b2b8d46d','417a':'417a437696306239783ed0e3d918cb60709ea071'}
 cases=['a5','755','4c94','b4cd','crlf_bom','independent_edit','source_conflict','new_file_collision','payload_corruption','candidate_corruption','native_source_corruption','active_recovery','missing_tracked','rollback']
 if args.cases:
  cases=args.cases.split(',');assert all(name in set(bases)|{'crlf_bom','independent_edit','source_conflict','new_file_collision','payload_corruption','candidate_corruption','native_source_corruption','active_recovery','missing_tracked','rollback'} for name in cases)
 needed={name if name in bases else 'a5' for name in cases}
 for label in needed:golden(bases[label],work/('golden_'+label),scope)
 for name in cases:
  folder=work/('owner project '+name);shutil.copytree(work/('golden_'+(name if name in bases else 'a5')),folder)
  pkg=work/('package '+name);shutil.copytree(package,pkg,ignore=shutil.ignore_patterns('backups'))
  owner='# OWNER independent note: jangan hilangkan.';changed=folder/'scripts/managers/settings_manager.gd'
  if name=='crlf_bom':changed.write_bytes(b'\xef\xbb\xbf'+text(changed.read_bytes()).replace('\n','\r\n').encode())
  if name=='independent_edit':changed.write_text(changed.read_text()+'\n'+owner+'\n')
  if name=='source_conflict':
   p=folder/'scripts/ui/stage_select.gd';old='JourneyManager.active_run_chapter_id, JourneyManager.active_run_stage_id';assert old in p.read_text();p.write_text(p.read_text().replace(old,'999, 999'))
  if name=='new_file_collision':
   p=folder/'scripts/data/run_path_policy.gd';p.parent.mkdir(parents=True,exist_ok=True);p.write_text('extends RefCounted\n# unrelated owner file\n')
  if name=='payload_corruption':
   p=pkg/'payload/scripts/ui/stage_select.gd';p.write_text(p.read_text()+'\n# corrupt payload\n')
  if name=='candidate_corruption':
   p=folder/'release/native/JadeMonetizationNativeBridge-production-candidate.aar';p.write_bytes(p.read_bytes()+b'corrupt')
  if name=='native_source_corruption':
   p=folder/next(k for k in proof['inputs'] if k.endswith('.kt'));p.write_bytes(p.read_bytes()+b'\n// unknown native change\n')
  if name=='active_recovery':
   p=folder/'.local/production_native_export/active.json';p.parent.mkdir(parents=True,exist_ok=True);p.write_text('{}')
  if name=='missing_tracked':changed.unlink()
  read_only=folder/'scripts/ui';before_mtime=(folder/'project.godot').stat().st_mtime_ns
  if name=='rollback':read_only.chmod(0o555)
  before=snapshot(folder)
  try:code,output=run(args.pwsh,pkg,folder,work/(name+'.log'),restricted=name=='rollback' and os.geteuid()==0)
  finally:
   if name=='rollback':read_only.chmod(0o755)
  success=name in bases or name in ['crlf_bom','independent_edit']
  if success:
   assert code==0 and 'PLAYER_CONTENT_APPLY=PASS' in output,(name,output[-2400:])
   for entry in manifest['files']:
    p=folder/entry['path'];assert p.is_file(),(name,'missing',entry['path'])
    if name=='independent_edit' and p==changed:assert owner in p.read_text()
    else:assert sha(text(p.read_bytes()).encode())==entry['sha256'],(name,entry['path'])
   assert 'PLAYER_CONTENT_WINDOWS_QA=NOT_RUN' in output
   if name=='crlf_bom':assert changed.read_bytes().startswith(b'\xef\xbb\xbf') and b'\r\n' in changed.read_bytes()
   after=snapshot(folder);again_code,again=run(args.pwsh,pkg,folder,work/(name+'-repeat.log'))
   assert again_code==0 and 'SOURCE_WRITES=0' in again,(name,'repeat',again[-1500:])
   assert snapshot(folder)==after,(name,'repeat changed source');repeats+=1
  else:
   assert code!=0,(name,'unexpected apply');assert snapshot(folder)==before,(name,'failed operation changed source')
   if name=='rollback':
    assert 'NATIVE_SOURCE_BINARY_MATCH=PASS' in output and 'ROLLBACK_REQUIRES_REVIEW' not in output
    assert (folder/'project.godot').stat().st_mtime_ns!=before_mtime,'No real write transaction was exercised'
  results.append({'case':name,'status':'PASS','source_changed_only_when_expected':True});print(name,'PASS',flush=True)
 result={'scope':'REAL_POWERSHELL_7_LINUX_DISPOSABLE_FIXTURES_NOT_WINDOWS','cases':results,'case_count':len(results),'repeat_cases':repeats,'failures':0,'evidence_dir':str(work)}
 Path(args.result).write_text(json.dumps(result,indent=2));print(json.dumps(result),flush=True)
if __name__=='__main__':main()
