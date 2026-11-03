"""Portable audit/allowlisted cleanup package. Does not export, deploy or clean owner files."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[2]
BASE='dbe1c73422f431dce9234aa29efc3374b17a13e8'
def digest(b):return hashlib.sha256(b).hexdigest()
def canonical(b):return b.decode('utf-8-sig').replace('\r\n','\n').encode()
def base_bytes(relative):return subprocess.check_output(['git','show',BASE+':'+relative],cwd=ROOT)
def build(out,source,evidence=None):
    out.mkdir(parents=True,exist_ok=True)
    removals=json.loads((ROOT/'docs/checkpoints/REPOSITORY_CLEANUP_FILES_2026-11-03.json').read_text())
    manifest={'batch':'REPOSITORY_CLEANUP_20261103','source_commit':source,'base_commit':BASE,'updates':[],'removals':removals,'reference_guard':{}}
    for row in removals:
        if digest(base_bytes(row['path']))!=row['sha256']:raise ValueError('Preimage differs from reviewed base')
        if not row['path'].endswith('.import') and digest((ROOT/row['canonical']).read_bytes())!=row['sha256']:raise ValueError('Canonical pixels changed')
    relative='scripts/ui/liveops/celestial_treasury_screen.gd';target=out/'payload'/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(canonical((ROOT/relative).read_bytes()))
    manifest['updates'].append({'path':relative,'kind':'replace','before_sha256':digest(canonical(base_bytes(relative))),'after_sha256':digest(target.read_bytes()),'payload':'payload/'+relative})
    manifest['updates'].append({'path':'.gitignore','kind':'append_ignore','lines':['# Reproducible Python developer bytecode (source tests remain tracked)','__pycache__/','*.py[cod]']})
    paths=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0')[:-1]
    for relative in paths:
        p=ROOT/relative
        if not p.is_file() or (relative!='project.godot' and not relative.startswith(('scripts/','scenes/','assets/','addons/'))):continue
        if p.suffix not in {'.cs','.gd','.tscn','.tres','.gdshader','.gdextension','.cfg','.godot','.json'}:continue
        hashes=[digest(canonical(p.read_bytes()))]
        if relative==manifest['updates'][0]['path']:hashes.append(manifest['updates'][0]['before_sha256'])
        manifest['reference_guard'][relative]=list(dict.fromkeys(hashes))
    (out/'cleanup_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    shutil.copy2(ROOT/'tools/repo_hygiene/cleanup_project.ps1',out/'cleanup_project.ps1')
    for name,mode in [('audit_cleanup','Audit'),('apply_cleanup','Apply'),('restore_cleanup','Restore')]:
        script='@echo off\r\nsetlocal\r\nset "POWERSHELL_TELEMETRY_OPTOUT=1"\r\nset "POWERSHELL_UPDATECHECK=Off"\r\npowershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0cleanup_project.ps1" -Mode '+mode+(' -ReceiptPath' if mode=='Restore' else '')+' %*\r\nset "JADE_CLEANUP_EXIT=%ERRORLEVEL%"\r\necho.\r\npause\r\nendlocal & exit /b %JADE_CLEANUP_EXIT%\r\n'
        (out/(name+'.cmd')).write_bytes(script.encode('ascii'))
    readme='''# Jade Ascendant — Repository Cleanup, 3 November 2026

Source: https://github.com/bonglii/Jade-Ascendant/tree/work/repo-cleanup-20261103
Game/menu batch sudah terpisah; paket ini hanya audit dan cleanup terbatas.

1. Ekstrak ke folder baru. **audit_cleanup.cmd** menjalankan inventory lokal read-only; SOURCE_WRITES=0. Default project D:\\Godot\\project\\jade-ascendant. Hasil lengkap dicetak di LOCAL_AUDIT_REPORT.
2. **apply_cleanup.cmd** khusus penghapusan empat file duplikat yang telah direview (dua PNG + dua metadata import), pengalihan satu referensi Treasury ke PNG Mail identik dan penambahan ignore bytecode Python. Tutup Godot dan tunggu exporter existing memulihkan bridge lebih dahulu. Gunakan branch kerja, bukan main/production.
3. Apply memeriksa 800 source runtime yang direview, native 52 input/candidate, payload dan hash file. Source berbeda, PNG diedit, reparse point atau recovery aktif menghentikan operasi sebelum tulisan. Jangan memaksa guard atau menimpa edit lokal untuk mengejar PASS.
4. Backup byte asli dan APPLY_RECEIPT.json tersimpan di results dalam folder paket. Pengulangan apply tidak menulis source lagi. Untuk memulihkan, jalankan **restore_cleanup.cmd "path lengkap ke APPLY_RECEIPT.json pertama"**. Restore menolak menimpa edit baru.

Tidak menghapus test/CI, QA evidence, master art, SDK, save, Godot cache, backup, receipt, recovery, signing data atau AAB/APK. Master art 33.9 MB sudah diabaikan Godot dan tetap diperlukan untuk repacking. Gambar canonical identik dan parameter import sama. Working tree berkurang 5,099,298 byte; Git history dan backup tetap menyimpan originals. Pengurangan ukuran AAB belum diukur karena tidak export.

Audit lokal melihat file di PC owner yang tidak tersedia di author. Tidak memerlukan Python/Node. Status Windows/HP dan AAB tidak disimpulkan dari fixture Linux. Jangan memasang ulang paket menu lama sesudah cleanup; restore cleanup dahulu bila perlu kembali ke snapshot lama.
'''
    (out/'README.md').write_text(readme)
    report=ROOT/'docs/checkpoints/REPOSITORY_CLEANUP_REVIEW_2026-11-03.md'
    if report.exists():shutil.copy2(report,out/'REVIEW.md')
    if evidence:
        for p in evidence.rglob('*'):
            if p.is_symlink():raise ValueError('No evidence symlinks')
            if p.is_file():
                target=out/'evidence'/p.relative_to(evidence);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
    checksums={p.relative_to(out).as_posix():digest(p.read_bytes()) for p in out.rglob('*') if p.is_file() and p.name!='PACKAGE_SHA256.json'}
    (out/'PACKAGE_SHA256.json').write_text(json.dumps(checksums,indent=2)+'\n')
    return manifest
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--source-commit',required=True);p.add_argument('--evidence',type=Path);p.add_argument('--zip',type=Path);a=p.parse_args();m=build(a.output.resolve(),a.source_commit,a.evidence)
    if a.zip:
        with zipfile.ZipFile(a.zip,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for f in sorted(a.output.rglob('*')):
                if f.is_file():z.write(f,f.relative_to(a.output).as_posix())
        with zipfile.ZipFile(a.zip) as z:
            assert z.testzip() is None
            for name,h in json.loads(z.read('PACKAGE_SHA256.json')).items():assert digest(z.read(name))==h
        print(json.dumps({'zip':str(a.zip.resolve()),'bytes':a.zip.stat().st_size,'sha256':digest(a.zip.read_bytes()),'entries':len(z.namelist()),'crc_checksums':'PASS','runtime_guard_files':len(m['reference_guard'])}))
