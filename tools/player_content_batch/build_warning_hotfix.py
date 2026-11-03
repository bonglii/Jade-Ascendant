"""Two-file warning follow-up for the installed Player Content batch."""
from pathlib import Path
import argparse,hashlib,json,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[2]
FILES=['scripts/managers/monetization_manager.gd','scripts/ui/refine_onboarding.gd']
BASE='18ff78656bcdc58891ba3c1442506bc115a17cad'
def canonical(data):return data.decode('utf-8-sig').replace('\r\n','\n').encode()
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output-dir',required=True);parser.add_argument('--source-commit',required=True);parser.add_argument('--evidence-dir');parser.add_argument('--zip-output');args=parser.parse_args()
 out=Path(args.output_dir).resolve();out.mkdir(parents=True,exist_ok=True);written=[]
 def save(name,data):
  path=out/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data);written.append(name)
 manifest={'batch':'PLAYER_REVIEW_CONTENT_20261102','hotfix':'PLAYER_CONTENT_WARNINGS_20261103','source_commit':args.source_commit,'source_branch':'work/player-review-batch-20261102','base_content_commit':BASE,'files':[]}
 for name in FILES:
  data=canonical((ROOT/name).read_bytes())
  if args.source_commit!='WORKING_TREE_QA':assert data==canonical(subprocess.check_output(['git','show',args.source_commit+':'+name],cwd=ROOT)),name
  old=canonical(subprocess.check_output(['git','show',BASE+':'+name],cwd=ROOT));base='base/player-content/'+name
  save('payload/'+name,data);save(base,old)
  manifest['files'].append({'path':name,'sha256':sha(data),'bases':[{'file':base,'sha256':sha(old)}]})
 save('manifest.json',(json.dumps(manifest,indent=2)+'\n').encode())
 # Reuse the native/recovery guard, recognized ancestors, backups and atomic rollback.
 installer=(ROOT/'tools/player_content_batch/Install.ps1').read_bytes()
 save('apply_hotfix.ps1',installer)
 body='@echo off\r\nsetlocal\r\nset "POWERSHELL_TELEMETRY_OPTOUT=1"\r\nset "POWERSHELL_UPDATECHECK=Off"\r\npowershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply_hotfix.ps1" -ApplyOnly %*\r\nset "JADE_WARNING_EXIT=%ERRORLEVEL%"\r\necho.\r\necho Hotfix ini tidak mengulang QA gameplay. Buka kembali Godot setelah APPLY=PASS.\r\npause\r\nendlocal & exit /b %JADE_WARNING_EXIT%\r\n'
 save('apply_hotfix.cmd',body.encode('ascii'))
 save('README.md',('''# Jade Ascendant — Warning Hotfix, 3 November 2026

Untuk Player Content yang sudah terpasang dan Windows PASS. Dua perubahan source:
- ads_suspended menjadi metode instance sesuai pemanggilan melalui autoload; nilai/hold iklan tidak berubah.
- Variabel scene pada cabang onboarding menjadi refreshed_scene; alur panduan tidak berubah.

Ekstrak, tutup Godot, jalankan apply_hotfix.cmd. Bila exporter masih aktif, biarkan ia memulihkan bridge terlebih dahulu; guard recovery tidak dilewati. Default project D:\\Godot\\project\\jade-ascendant. Setelah PLAYER_CONTENT_APPLY=PASS, buka kembali Godot dan periksa warning. Kemudian lanjut exporter produksi existing.

Paket memakai installer source/native/recovery yang telah diverifikasi, backup byte asli dan rollback atomik. Konflik berhenti sebelum source ditulis. Tidak ada reset, pembersihan cache/save, perubahan IAP/native/ads setting, deploy atau export AAB.

Launcher memakai ApplyOnly: pesan WINDOWS_QA=NOT_RUN berarti hotfix ini tidak menjalankan ulang suite gameplay. Konfirmasi Windows Player Content sebelumnya tetap berlaku; pemasangan/pemeriksaan editor untuk hotfix di mesin owner belum dikonfirmasi.

Author mereproduksi kedua pesan screenshot dengan dua kelas warning dijadikan error pada editor Godot 4.7.2. Setelah fix, editor import bersih; project.godot dipulihkan identik dan jeda iklan tetap aktif. Tidak menonaktifkan warning untuk menyembunyikan masalah. Bukti di evidence.

Source commit: '''+args.source_commit+'\n').encode())
 if args.evidence_dir:
  evidence=Path(args.evidence_dir).resolve()
  for path in sorted(evidence.rglob('*')):
   if path.is_symlink():raise ValueError('No evidence symlinks')
   if path.is_file():save('evidence/'+path.relative_to(evidence).as_posix(),path.read_bytes())
 save('PACKAGE_SHA256.json',(json.dumps({name:sha((out/name).read_bytes()) for name in sorted(written)},indent=2)+'\n').encode())
 result={'source_commit':args.source_commit,'payload_files':len(FILES),'package_files':len(written),'directory':str(out)}
 if args.zip_output:
  archive=Path(args.zip_output).resolve();archive.parent.mkdir(parents=True,exist_ok=True)
  with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as bundle:
   for name in sorted(written):bundle.write(out/name,name)
  with zipfile.ZipFile(archive) as bundle:
   assert bundle.testzip() is None
   for name,value in json.loads(bundle.read('PACKAGE_SHA256.json')).items():assert sha(bundle.read(name))==value,name
  result.update(zip=str(archive),bytes=archive.stat().st_size,sha256=sha(archive.read_bytes()),verified=True)
 print(json.dumps(result))
if __name__=='__main__':main()
