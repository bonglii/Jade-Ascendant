"""Build the cumulative, preimage-checked Windows package; no deployment/export."""
from pathlib import Path
import argparse,hashlib,json,subprocess,shutil
ROOT=Path(__file__).resolve().parents[2]
BASES={'owner-a5':'a5d2bf42586067ef1ef4d6460b7a4d291f9b869b','review-755':'75578e09ef3f5ff2756a1d877d8e4f82c73751be','plan-1ace':'1ace7af0e322b582ebaf942ff56b0d7053d897ab','implementation-4c94':'4c94ebc930682c9d1deafdee5e09941093b8953b'}
def canonical(data):return data.decode('utf-8-sig').replace('\r\n','\n')
def digest(data):return hashlib.sha256(data).hexdigest()
def build(destination,source_commit):
 destination.mkdir(parents=True,exist_ok=True)
 listing=json.loads((ROOT/'docs/checkpoints/PLAYER_CONTENT_BATCH_FILES_2026-11-02.json').read_text())
 manifest={'batch':'PLAYER_REVIEW_CONTENT_20261102','source_commit':source_commit,'source_branch':'work/player-review-batch-20261102','native_candidate':'UNCHANGED_R2_52_INPUTS','supported_bases':BASES,'files':[]}
 written=[]
 def save(name,data):
  path=destination/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data);written.append(name)
 for relative in listing['files']:
  path=Path(relative)
  if path.is_absolute() or '..' in path.parts or '\\' in relative:raise ValueError('Unsafe source path')
  content=canonical((ROOT/path).read_bytes()).encode()
  save('payload/'+relative,content)
  item={'path':relative,'sha256':digest(content),'bases':[]}
  seen={}
  for label,sha in BASES.items():
   result=subprocess.run(['git','show',sha+':'+relative],cwd=ROOT,capture_output=True)
   if result.returncode:continue
   old=canonical(result.stdout).encode();old_hash=digest(old)
   if old_hash in seen:continue
   name='base/'+label+'/'+relative;save(name,old);seen[old_hash]=name
   item['bases'].append({'file':name,'sha256':old_hash})
  manifest['files'].append(item)
 save('manifest.json',(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode())
 save('apply_and_test.ps1',(ROOT/'tools/player_content_batch/Install.ps1').read_bytes())
 for name,flags in [('apply_and_test.cmd',''),('qa_only.cmd','-QaOnly ')]:
  body='@echo off\r\nsetlocal\r\npowershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply_and_test.ps1" '+flags+'%*\r\nset "JADE_CONTENT_EXIT=%ERRORLEVEL%"\r\necho.\r\npause\r\nendlocal & exit /b %JADE_CONTENT_EXIT%\r\n'
  save(name,body.encode('ascii'))
 report=ROOT/'docs/checkpoints/PLAYER_CONTENT_BATCH_REVIEW_2026-11-02.md'
 if report.exists():save('REVIEW.md',report.read_bytes())
 readme=f'''# Jade Ascendant — Player Content Batch, 2 November 2026

Satu paket kumulatif untuk seluruh 18 masukan dan temuan runtime. Tema memakai kembali frame jade/perunggu, sanctum, sprite dan pola boss yang telah disetujui.

Source: https://github.com/bonglii/Jade-Ascendant/tree/work/player-review-batch-20261102
Revision paket: {source_commit}

## Pasang dan periksa
1. Ekstrak ke folder baru. Tutup Godot dan biarkan recovery/export bridge yang aktif selesai melalui prosedur yang sudah ada.
2. Jalankan **apply_and_test.cmd**. Default project `D:\\Godot\\project\\jade-ascendant`.
3. Pemasangan memeriksa candidate/native R2 dan semua source lebih dahulu. Konflik berhenti sebelum source ditulis. Edit independen digabung tiga arah; backup byte asli dan receipt ada di `backups/` di dalam folder paket.
4. Target akhir: `PLAYER_CONTENT_WINDOWS_QA=PASS`. QA memakai userdata sementara tersendiri; save owner tidak digunakan. Sebuah jendela uji kecil akan terbuka untuk pemeriksaan menu.
5. Kalau source sudah terpasang tetapi QA berhenti, jalankan **qa_only.cmd**. Jangan hapus save, cache import, receipt atau recovery marker.

Path khusus melalui PowerShell:
`powershell -NoProfile -ExecutionPolicy Bypass -File .\\apply_and_test.ps1 -ProjectPath 'D:\\Godot\\project\\jade-ascendant' -GodotPath 'D:\\Godot\\Godot_v4.7.2-stable_win64_console.exe'`

## Letak fitur
- Library → Jurnal Kultivator → Pelataran Latihan: tujuh mode, setup art/level, latihan boss yang sudah ditemui, pertahanan tiga segel, teknik enam art, ujian setara, pemecah pelindung dan gauntlet tiga boss.
- Jurnal → Run Terakhir → Bandingkan Dua Run; Catatan Teknik menyimpan hasil pribadi di perangkat ini.
- Journey: altar opsional mulai wave 3; tiap art Lv.5 menawarkan fokus boss, sapuan kelompok, atau jalur seimbang. Continue menyimpan pilihannya.
- Chronicles: lima fragmen baru, masing-masing setelah clear stage 3 realm terkait.
- Trials: preview hadiah memakai snapshot minggu yang cocok; risiko pribadi opsional mempertahankan budget hadiah/aturan medali server.
- Daily: target ringan baru berlaku pada reset; nominal hadiah rotasi lama dipertahankan. Hari lama dan klaim yang sudah ada tetap berlaku.
- Settings: opsi ornamen player ringan tetap mempertahankan bentuk serangan dan peringatan musuh.

## Status terpisah
Author QA dan batasnya tercatat di REVIEW.md/evidence. Pemasangan Windows batch ini belum dianggap PASS sampai launcher dijalankan di project owner. Native candidate R2 tidak dibangun ulang; input/binary-nya cocok dengan receipt sebelumnya. Mitigasi request iklan aktif di source ini dan tidak diaktifkan otomatis menurut kalender. IAP/gates pembayaran tetap dipertahankan.

Tidak ada deploy backend, export AAB, upload Play Console atau tes HP yang dilakukan oleh installer. Sesudah Windows PASS, gunakan exporter produksi yang sudah ada untuk build baru. Jangan menganggap AdMob pulih hanya dari tanggal.
'''
 save('README.md',readme.encode())
 save('PACKAGE_FILES.json',(json.dumps(sorted(written+['PACKAGE_FILES.json']),indent=2)+'\n').encode())
 return manifest,written
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--output-dir',required=True);parser.add_argument('--source-commit',required=True);args=parser.parse_args()
 manifest,written=build(Path(args.output_dir).resolve(),args.source_commit)
 print(json.dumps({'output':args.output_dir,'source_files':len(manifest['files']),'package_files':len(written)}))
