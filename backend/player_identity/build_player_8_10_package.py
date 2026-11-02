"""Build a portable source delta against the owner-tested 1–7 package."""
import argparse, hashlib, json, pathlib, shutil, subprocess, zipfile
PARENT_SHA='b5718303c5cbd3351401b8759a4dfc8dc25e5103c12928b2c25419468b1cfa44'
R1_SHA='fdc2ec06af7e9e0f923f1edf0ced3fe4307e01a4816df25bbff287714af88711'
BASE='057ed76f186940374d2cabe1ecb307a0114d3106'
def sha(data):return hashlib.sha256(data).hexdigest()
def build(repo,baseline,parent,folder,previous=None):
    assert sha(parent.read_bytes())==PARENT_SHA,'Wrong tested parent package'
    if folder.exists():shutil.rmtree(folder)
    folder.mkdir(parents=True)
    tracked=set(subprocess.check_output(['git','ls-files','-z'],cwd=repo).decode().split('\0'))
    with zipfile.ZipFile(parent) as old:
        parent_names=set(old.namelist())
        paths=[]
        for root in ['scripts','backend','tests','docs/checkpoints','release/native']:
            for f in (repo/root).rglob('*'):
                relative=f.relative_to(repo).as_posix()
                if not f.is_file() or f.suffix=='.uid' or any(part in ['build','.gradle','node_modules','__pycache__'] for part in f.parts):continue
                baseline_file=baseline/relative
                if baseline_file.is_file() and baseline_file.read_bytes()==f.read_bytes() and relative!='docs/checkpoints/CURRENT_WORK.json':continue
                paths.append(relative)
        rows=[]
        for relative in sorted(set(paths)):
            incoming=(repo/relative).read_bytes();key='incoming/'+relative
            if key in parent_names:base=old.read(key)
            elif relative in tracked:base=subprocess.check_output(['git','show',BASE+':'+relative],cwd=repo)
            else:base=None
            if base==incoming and relative!='docs/checkpoints/CURRENT_WORK.json':continue
            for root,data in [('incoming',incoming),('base',base)]:
                if data is not None:
                    target=folder/root/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
            rows.append({'path':relative,'kind':'binary' if relative.endswith('.aar') else 'text','sha256':sha(incoming),'base_sha256':None if base is None else sha(base)})
    if previous is not None:
        assert sha(previous.read_bytes())==R1_SHA,'Previous batch must be the exact delivered R1 ZIP'
        with zipfile.ZipFile(previous) as prior:
            names=set(prior.namelist())
            for row in rows:
                key='incoming/'+row['path']
                if key not in names:continue
                data=prior.read(key)
                if sha(data)==row['sha256']:continue
                target=folder/'previous'/row['path'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
                row['previous_sha256']=sha(data)
    manifest={'format':'jade.player-8-10.v1','batch':'PLAYER_IMPLEMENTATION_8_10_2026-10-27','base':BASE,'parent_package_sha256':PARENT_SHA,'revision':'R2','previous_package_sha256':R1_SHA if previous else None,'files':rows}
    (folder/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for name in ['player_8_10_package.cjs','player_8_10_tools.cjs','player_8_10_native_check.cjs']:shutil.copyfile(repo/'backend/player_identity'/name,folder/name)
    (folder/'run.cjs').write_text("'use strict';\nrequire('./player_8_10_package.cjs').run({folder:__dirname}).catch(error=>{console.error('PLAYER_8_10_STOPPED: '+error.message);process.exitCode=1;});\n")
    (folder/'apply_and_check.cmd').write_text('@echo off\nsetlocal\ncd /d "%~dp0"\nnode "%~dp0run.cjs" %*\nif errorlevel 1 (\n echo.\n echo Pemasangan atau QA berhenti. Baca pesan di atas; jangan lanjut export.\n pause\n exit /b 1\n)\necho.\necho Batch 8-10 terpasang dan QA selesai. Lanjutkan checklist Android.\npause\n')
    launcher=folder/'apply_and_check.cmd';launcher.write_bytes(launcher.read_text().replace('\n','\r\n').encode('ascii'))
    shutil.copyfile(repo/'docs/checkpoints/PLAYER_8_10_ANDROID_CHECKLIST.md',folder/'ANDROID_CHECKLIST.md')
    shutil.copyfile(repo/'docs/checkpoints/PLAYER_8_10_DELIVERY_2026-10-27.md',folder/'CHANGES.md')
    (folder/'README.txt').write_text('''JADE ASCENDANT — PLAYER BATCH 8–10 R2

R2 memperbaiki syarat hash bridge lama. Bridge dalam addons dipertahankan
persis; candidate baru tetap diverifikasi. Export memakai backup dan restore
hash asli yang benar, termasuk bila project sudah memakai bridge produksi.
Paket penuh ini mendukung project sebelum R1 serta file R1 yang dikenali.
Tidak perlu memasang ulang R1.

Paket ini meneruskan batch 1–7 yang sudah dites.
Ekstrak seluruh ZIP, tutup Godot, lalu klik apply_and_check.cmd sekali.
Default project: D:\\Godot\\project\\jade-ascendant. Node/Git/Godot yang sudah ada dipakai.

Lokasi lain:
  apply_and_check.cmd --project "folder project" --godot "folder\\Godot_console.exe"
Periksa tanpa mengubah source:
  apply_and_check.cmd --project "folder project" --check-only

Installer membuat branch kerja baru dari HEAD yang sama, membuat backup dan
menjaga edit lokal/staging. Konflik atau native provenance yang berbeda akan
menghentikan seluruh rencana sebelum source ditulis. Rerun aman; QA dengan
input yang sama dipakai ulang. Receipt ada di .local\\player_8_10_batch.

Native candidate terbaru sudah disertakan dan dipasangkan ke seluruh 50 input,
flags, hash dan pin exporter. AAR yang sudah ada dalam addons tetap tidak diganti oleh
installer. Sembilan gate pembayaran tidak diubah. Tidak ada commit/push,
deployment, aktivasi rotasi, signing atau export AAB otomatis.

Sesudah pemasangan dan QA lulus, gunakan exporter produksi yang sudah ada:
  backend\\player_identity\\export_production.cmd
Gunakan versionCode rilis berikutnya lalu tes build baru di HP mengikuti
ANDROID_CHECKLIST.md. Hasil compile/headless belum membuktikan chooser,
performa, GPU, audio atau gestur di perangkat Android.

Client baru tetap memakai payload v1 pada rotasi lama. Aturan v2 hanya aktif
jika backend dan rotasinya diterbitkan secara terpisah; paket tidak melakukan itu.

CHANGES.md menjelaskan hasil dan batas QA. evidence berisi log/receipt serta
PNG hasil renderer. Semua source delta berada di incoming dan base.
''',encoding='utf-8')
    print(json.dumps({'folder':str(folder),'files':len(rows),'new_files':sum(r['base_sha256'] is None for r in rows)}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--repo',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[2]);p.add_argument('--baseline',type=pathlib.Path,required=True);p.add_argument('--parent',type=pathlib.Path,required=True);p.add_argument('--folder',type=pathlib.Path,required=True);p.add_argument('--previous',type=pathlib.Path);a=p.parse_args();build(a.repo.resolve(),a.baseline.resolve(),a.parent.resolve(),a.folder.resolve(),a.previous.resolve() if a.previous else None)
