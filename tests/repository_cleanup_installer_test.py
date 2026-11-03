"""Actual PowerShell cleanup, restore, repeat and refusal fixtures. No owner files."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,tempfile,threading,time
ROOT=Path(__file__).resolve().parents[1]
def digest(b):return hashlib.sha256(b).hexdigest()
def snapshot(root):return {p.relative_to(root).as_posix():digest(p.read_bytes()) for p in root.rglob('*') if p.is_file() and '.git' not in p.relative_to(root).parts}
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--package',type=Path,required=True);parser.add_argument('--pwsh',required=True);parser.add_argument('--result',type=Path,required=True);args=parser.parse_args()
    package=args.package.resolve();manifest=json.loads((package/'cleanup_manifest.json').read_text());proof=json.loads((ROOT/'docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json').read_text())
    needed=set(manifest['reference_guard'])|set(proof['inputs'])|{'.gitignore','docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json','release/native/JadeMonetizationNativeBridge-production-candidate.aar'}
    needed|={r['path'] for r in manifest['removals']}|{r['canonical'] for r in manifest['removals']}
    work=Path(tempfile.mkdtemp(prefix='jade_cleanup_qa_',dir='/tmp'));golden=work/'golden';golden.mkdir()
    for relative in needed:
        got=subprocess.run(['git','show',manifest['base_commit']+':'+relative],cwd=ROOT,capture_output=True,check=True).stdout
        p=golden/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(got)
    for cmd in [['init','-q'],['config','user.name','Fixture'],['config','user.email','qa@example.invalid'],['checkout','-qb','work/cleanup-fixture'],['add','--all'],['commit','-qm','isolated baseline']]:subprocess.run(['git',*cmd],cwd=golden,check=True,capture_output=True)
    results=[]
    def run(folder,pkg,mode,log,receipt=None):
        env=os.environ.copy();env.update(POWERSHELL_TELEMETRY_OPTOUT='1',POWERSHELL_UPDATECHECK='Off')
        cmd=[args.pwsh,'-NoLogo','-NoProfile','-File',str(pkg/'cleanup_project.ps1'),'-ProjectPath',str(folder),'-PackageRoot',str(pkg),'-Mode',mode]
        if receipt:cmd+=['-ReceiptPath',str(receipt)]
        r=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=150);text=r.stdout+r.stderr;(work/log).write_text(text);return r.returncode,text
    cases=['audit','apply_restore_repeat','crlf_bom','modified_asset','unreviewed_source','active_export','native_mismatch','payload_corruption','concurrent_rollback','restore_conflict']
    for name in cases:
        owner=work/name;shutil.copytree(golden,owner);pkg=work/(name+'_package');shutil.copytree(package,pkg)
        for p in ['.godot/protected.bin','.local/receipt.keep','artifacts/protected.aab','backups/save.keep']:
            f=owner/p;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(b'protected fixture data')
        changed=owner/'scripts/ui/liveops/celestial_treasury_screen.gd'
        if name=='crlf_bom':changed.write_bytes(b'\xef\xbb\xbf'+changed.read_bytes().replace(b'\n',b'\r\n'))
        removal=owner/manifest['removals'][0]['path']
        if name=='modified_asset':removal.write_bytes(removal.read_bytes()+b'owner art edit')
        if name=='unreviewed_source':(owner/'scripts/owner_new.gd').write_text('extends Node\n')
        if name=='active_export':
            p=owner/'.local/production_native_export/active.json';p.parent.mkdir(parents=True,exist_ok=True);p.write_text('{}')
        if name=='native_mismatch':
            p=owner/next(k for k in proof['inputs'] if k.endswith('.kt'));p.write_bytes(p.read_bytes()+b'\n// changed\n')
        if name=='payload_corruption':
            p=pkg/manifest['updates'][0]['payload'];p.write_bytes(p.read_bytes()+b'\n# corrupt\n')
        before=snapshot(owner);stop=threading.Event();edited=threading.Event();late=owner/manifest['removals'][-1]['path'];late_bytes=late.read_bytes()+b'\n# concurrent owner edit\n';old_code=digest(changed.read_bytes())
        def concurrent():
            while not stop.wait(.001):
                if digest(changed.read_bytes())!=old_code:late.write_bytes(late_bytes);edited.set();return
        worker=threading.Thread(target=concurrent,daemon=True) if name=='concurrent_rollback' else None
        if worker:worker.start()
        try:code,text=run(owner,pkg,'Audit' if name=='audit' else 'Apply',name+'.log')
        finally:
            stop.set()
            if worker:worker.join(timeout=3)
        if name=='audit':assert code==0 and 'SOURCE_WRITES=0' in text and snapshot(owner)==before,text[-2500:]
        elif name in ['apply_restore_repeat','crlf_bom','restore_conflict']:
            assert code==0 and 'REPOSITORY_CLEANUP_APPLY=PASS' in text,text[-2500:]
            assert all(not (owner/r['path']).exists() for r in manifest['removals'])
            assert b'spirit_messages_jade_frame.png' in changed.read_bytes()
            if name=='crlf_bom':assert changed.read_bytes().startswith(b'\xef\xbb\xbf') and b'\r\n' in changed.read_bytes()
            receipts=list((pkg/'results').glob('*/APPLY_RECEIPT.json'));assert len(receipts)==1;receipt=receipts[0]
            after=snapshot(owner);again,out=run(owner,pkg,'Apply',name+'-repeat.log');assert again==0 and 'SOURCE_WRITES=0' in out and snapshot(owner)==after,out[-2500:]
            if name=='restore_conflict':
                changed.write_bytes(changed.read_bytes()+b'\n# owner subsequent edit\n');before_restore=snapshot(owner)
                rc,restored=run(owner,pkg,'Restore',name+'-restore.log',receipt);assert rc!=0 and snapshot(owner)==before_restore
            else:
                rc,restored=run(owner,pkg,'Restore',name+'-restore.log',receipt);assert rc==0 and snapshot(owner)==before,restored[-2500:]
                rc,restored=run(owner,pkg,'Restore',name+'-restore-repeat.log',receipt);assert rc==0 and 'FILES=0' in restored and snapshot(owner)==before
        else:
            assert code!=0,(name,'unexpected apply')
            if name=='concurrent_rollback':
                assert edited.is_set() and 'ROLLBACK_REQUIRES_REVIEW' not in text,text[-2500:]
                before[manifest['removals'][-1]['path']]=digest(late_bytes)
            assert snapshot(owner)==before,(name,text[-2500:])
        results.append({'case':name,'status':'PASS'});print(name,'PASS',flush=True)
    args.result.write_text(json.dumps({'scope':'REAL_POWERSHELL_7_LINUX_FIXTURES_NOT_WINDOWS','cases':results,'failures':0,'evidence_dir':str(work)},indent=2)+'\n')
if __name__=='__main__':main()
