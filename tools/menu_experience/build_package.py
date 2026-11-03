"""Build the cumulative, preimage-checked Windows package; no deployment/export."""
from pathlib import Path
import argparse,hashlib,json,subprocess,shutil,zipfile
ROOT=Path(__file__).resolve().parents[2]
BASES={'owner-a5':'a5d2bf42586067ef1ef4d6460b7a4d291f9b869b','review-755':'75578e09ef3f5ff2756a1d877d8e4f82c73751be','plan-1ace':'1ace7af0e322b582ebaf942ff56b0d7053d897ab','implementation-4c94':'4c94ebc930682c9d1deafdee5e09941093b8953b','runtime-b4cd':'b4cd3ae3cdc0aebe7ea901e866131629b2b8d46d','recovery-417a':'417a437696306239783ed0e3d918cb60709ea071'}
BASES.update({'experience-7074':'7074a278ec7c8e9f037c90519908ed21a8ac63e9','content-18ff':'18ff78656bcdc58891ba3c1442506bc115a17cad','candidate-fe4':'fe4b33b8a7d8595219462e912bf86eb7e6f9ca91','experience-e258':'e258d4f980d5d521f339a9a0c81f636943061200'})
def canonical(data):return data.decode('utf-8-sig').replace('\r\n','\n')
def digest(data):return hashlib.sha256(data).hexdigest()
def build(destination,source_commit,evidence=None):
 destination.mkdir(parents=True,exist_ok=True)
 listing=json.loads((ROOT/'docs/checkpoints/MENU_EXPERIENCE_FILES_2026-11-03.json').read_text())
 manifest={'batch':'MENU_PLAYER_EXPERIENCE_20261103','source_commit':source_commit,'source_branch':'work/menu-player-experience-20261103','native_candidate':'UNCHANGED_R2_52_INPUTS','supported_bases':BASES,'files':[]}
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
 save('apply_and_test.ps1',(ROOT/'tools/menu_experience/Install.ps1').read_bytes())
 for name,flags in [('apply_and_test.cmd',''),('qa_only.cmd','-QaOnly ')]:
  body='@echo off\r\nsetlocal\r\nset "POWERSHELL_TELEMETRY_OPTOUT=1"\r\nset "POWERSHELL_UPDATECHECK=Off"\r\npowershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply_and_test.ps1" '+flags+'%*\r\nset "JADE_CONTENT_EXIT=%ERRORLEVEL%"\r\necho.\r\npause\r\nendlocal & exit /b %JADE_CONTENT_EXIT%\r\n'
  save(name,body.encode('ascii'))
 report=ROOT/'docs/checkpoints/MENU_EXPERIENCE_REVIEW_2026-11-03.md'
 if report.exists():save('REVIEW.md',report.read_bytes())
 readme=f"""# Jade Ascendant — Menu & Player Experience, 3 November 2026

Satu paket kumulatif: 18-item Player Content yang sudah PASS, hotfix warning, dan 22 acceptance item batch menu/player terbaru. Source: https://github.com/bonglii/Jade-Ascendant/tree/work/menu-player-experience-20261103
Revision paket: {source_commit}

1. Ekstrak ke folder baru. Tutup Godot. Bila exporter aktif, tunggu bridge asli selesai dipulihkan lewat prosedur existing.
2. Jalankan **apply_and_test.cmd**. Default project D:\\Godot\\project\\jade-ascendant. Tetap pada branch kerja; main/production ditolak.
3. Target: **MENU_EXPERIENCE_WINDOWS_QA=PASS**. Kalau source terpasang dan QA terhenti, gunakan **qa_only.cmd**. Simpan log/backup untuk review.

Installer memeriksa 52 input native R2 dan binary yang sama, memvalidasi hash/preimage, melakukan merge independen terhadap Git HEAD yang dikenali, backup byte asli, penggantian atomik dan rollback transaksi gagal. Konflik berhenti sebelum tulisan source. Save, import cache, receipt dan recovery owner tidak dihapus. QA memakai userdata sementara. Tidak commit/push/deploy/export/AAB/upload Play.

Fitur utama: Home target koleksi; Cultivate dampak run berikutnya; preview 3 preset existing; perbandingan run faktual; timeline hit 10 detik; 9 mode latihan termasuk pola tunggal/itinerary mingguan lokal dan rekor kit cocok; variasi arah realm opsional; warning kontras tinggi; prioritas cue audio; konteks Events/Odyssey/Mail/Pavilion/Settings dan akses latihan langsung. Semua memakai tema jade/perunggu xianxia existing. Baca REVIEW.md untuk detail/bukti dan batasannya.

Author Linux/native GUI bukan Windows owner atau Android. Pemasangan Windows batch baru, AAB, upload dan HP tetap belum dikonfirmasi sampai ada hasil nyata. AdMob hold tetap ON; tidak pulih otomatis menurut tanggal. Semua sembilan gate pembayaran tetap.
"""
 save('README.md',readme.encode())
 if evidence:
  for path in sorted(evidence.rglob('*')):
   if path.is_symlink():raise ValueError('Evidence links are not packaged')
   if path.is_file():save('evidence/'+path.relative_to(evidence).as_posix(),path.read_bytes())
 save('PACKAGE_FILES.json',(json.dumps(sorted(written+['PACKAGE_FILES.json','PACKAGE_SHA256.json']),indent=2)+'\n').encode())
 checksums={name:digest((destination/name).read_bytes()) for name in sorted(written)}
 save('PACKAGE_SHA256.json',(json.dumps(checksums,indent=2)+'\n').encode())
 return manifest,written
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--output-dir',required=True);parser.add_argument('--source-commit',required=True);parser.add_argument('--evidence-dir');parser.add_argument('--zip-output');args=parser.parse_args()
 destination=Path(args.output_dir).resolve()
 manifest,written=build(destination,args.source_commit,Path(args.evidence_dir).resolve() if args.evidence_dir else None)
 result={'output':str(destination),'source_files':len(manifest['files']),'package_files':len(written),'source_commit':args.source_commit}
 if args.zip_output:
  archive=Path(args.zip_output).resolve();archive.parent.mkdir(parents=True,exist_ok=True)
  with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as bundle:
   for name in sorted(written):bundle.write(destination/name,name)
  with zipfile.ZipFile(archive) as bundle:
   assert bundle.testzip() is None
   assert sorted(bundle.namelist())==sorted(written)
   for name,expected in json.loads(bundle.read('PACKAGE_SHA256.json')).items():assert digest(bundle.read(name))==expected,name
  result.update(zip=str(archive),zip_bytes=archive.stat().st_size,zip_sha256=digest(archive.read_bytes()),zip_verified=True)
 print(json.dumps(result))
