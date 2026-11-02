'use strict';
// Owner-operated Android evidence. Never installs, clears data, claims rewards or buys anything.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process'),readline=require('node:readline/promises');
const PACKAGE='com.yungdevstudio.jadeascendant';
const steps=[
 ['victory','Menang satu stage, kembali Home, tutup/buka game. Continue untuk run yang selesai tidak muncul; reward tidak dobel.'],
 ['continue','Mulai run yang belum selesai, pause > Home, buka Continue. Stage, skill, HP dan waktu pulih sesuai checkpoint.'],
 ['campaign','Cek Home dan Journey: Chapter 1 memakai /5, campaign aktif 25. Pada profil yang memenuhi syarat, cache/achievement/ladder bisa diambil tanpa 1-6. Progres lama tetap ada.'],
 ['guide','Pada Guest uji yang baru menang 1-1: backpack kosong memberi Cultivation yang terjangkau atau Journey. Setelah memperoleh equipment, panduan bintang/level yang sesuai muncul. Jangan hapus save utama untuk membuat kondisi ini.'],
 ['language','Ganti en/id. Periksa HERO, detail item, harga upgrade, receipt hadiah, panduan dan pilihan level-up. Angka/nama item tetap benar.'],
 ['build_queue','Dapatkan EXP berlebih hingga ada beberapa pilihan. Counter turun satu per satu, pertarungan tetap pause, tiap level heal normal, satu pilihan tidak terpilih dua kali. Petunjuk sinergi sesuai skill yang dimiliki.'],
 ['touch_audio','Tes swipe pertama dari kartu/tombol HERO dan popup, tap sengaja, Back, layar portrait sempit, boss ramai, audio serta background/resume. Catat teks terpotong, tap nyasar, stutter atau audio putus.']
];
function redact(text){return text.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi,'[email]').replace(/(bearer\s+)[\w.\-]+/gi,'$1[redacted]').replace(/((?:token|nonce|authorization|id_token|access_token)\s*[=:]\s*)[^\s,;]+/gi,'$1[redacted]');}
function packageVersion(text){return{version_code:/(?:^|\s)versionCode=(\d+)/m.exec(text)?.[1]||'',version_name:/(?:^|\s)versionName=([^\s]+)/m.exec(text)?.[1]||''};}
async function run(args=process.argv.slice(2)){
 const value=flag=>{const i=args.indexOf(flag);return i<0?'':args[i+1]||'';};
 const root=path.resolve(value('--project')||process.env.JADE_PROJECT||'D:/Godot/project/jade-ascendant');
 const adb=value('--adb')||process.env.ADB_PATH||'D:/SDK/platform-tools/adb.exe';
 const expected=value('--expected-version-code');
 if(!/^\d+$/.test(expected))throw Error('Isi versionCode AAB batch baru: --expected-version-code <angka>. Bukti dari build lama tidak dihitung.');
 if(!fs.existsSync(path.join(root,'project.godot')))throw Error('Project tidak ditemukan: '+root);
 const execute=(argv,{binary=false,optional=false}={})=>{
  const r=spawnSync(adb,argv,{encoding:binary?null:'utf8',windowsHide:true,maxBuffer:20*1024*1024});
  if(r.error||r.status!==0){if(optional)return null;throw Error('ADB: '+(r.error?.message||String(r.stderr||r.stdout)));}
  return r.stdout;
 };
 const rows=String(execute(['devices'])).split(/\r?\n/).map(x=>/^(\S+)\s+device$/.exec(x.trim())).filter(Boolean).map(x=>x[1]);
 const serial=value('--serial')||(rows.length===1?rows[0]:'');
 if(!serial||!rows.includes(serial))throw Error('Sambungkan satu HP dengan USB debugging aktif, atau pilih --serial <id>. Tidak ada data dihapus.');
 const shell=(argv,options)=>execute(['-s',serial,'shell',...argv],options);
 const version=packageVersion(String(shell(['dumpsys','package',PACKAGE])));
 if(version.version_code!==expected)throw Error('HP masih memakai versionCode '+version.version_code+'; yang diminta '+expected+'. Pasang build batch baru melalui alur tester yang biasa.');
 const id=new Date().toISOString().replace(/[:.]/g,'-');
 const output=path.join(root,'.local/player_followup_android',id);fs.mkdirSync(output,{recursive:true});
 const state={batch:'PLAYER_BATCH_1_7_2026-10-26',started_utc:new Date().toISOString(),package:PACKAGE,version,device:{model:String(shell(['getprop','ro.product.model'])).trim(),android:String(shell(['getprop','ro.build.version.release'])).trim(),sdk:String(shell(['getprop','ro.build.version.sdk'])).trim(),resolution:String(shell(['wm','size'])).trim()},steps:{},android_tested:false,device_checklist_complete:false,frame_time_proof:'Not established by checklist or headless QA',render_review:'Owner observations; screenshots saved for review'};
 const installReceipt=path.join(root,'.local/player_followup_batch/receipt.json');
 if(fs.existsSync(installReceipt)){const r=JSON.parse(fs.readFileSync(installReceipt));state.source={base:r.base,head:r.head,qa_key:r.qa_key||null,local_qa:!!r.local_qa};}
 const save=()=>fs.writeFileSync(path.join(output,'session.json'),JSON.stringify(state,null,2)+'\n');
 save();
 const ui=readline.createInterface({input:process.stdin,output:process.stdout});
 try{
  console.log('Buka Jade Ascendant pada HP. Gunakan profil tester. Setelah setiap langkah: p=lulus, f=masalah, s=belum diuji.\nBukti tersimpan di '+output);
  for(const [key,instruction]of steps){
   console.log('\n'+key.toUpperCase()+': '+instruction);
   let outcome='';while(!['p','f','s'].includes(outcome))outcome=(await ui.question('Hasil [p/f/s]: ')).trim().toLowerCase();
   const note=await ui.question('Catatan singkat (Enter jika kosong): ');
   const png=execute(['-s',serial,'exec-out','screencap','-p'],{binary:true,optional:true});
   let screenshot=null;if(png&&png.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))){screenshot=key+'.png';fs.writeFileSync(path.join(output,screenshot),png);}
   state.steps[key]={result:{p:'pass',f:'fail',s:'not_tested'}[outcome],note:redact(note),screenshot,utc:new Date().toISOString()};save();
  }
  const pid=String(shell(['pidof',PACKAGE],{optional:true})||'').trim().split(/\s+/)[0];
  if(/^\d+$/.test(pid)){
   const text=execute(['-s',serial,'logcat','-d','--pid='+pid,'-v','threadtime'],{optional:true});
   if(text)fs.writeFileSync(path.join(output,'game-log-redacted.txt'),redact(String(text)));
  }
  const frames=shell(['dumpsys','gfxinfo',PACKAGE,'framestats'],{optional:true});
  if(frames)fs.writeFileSync(path.join(output,'android-gfxinfo.txt'),redact(String(frames)));
  state.android_tested=Object.values(state.steps).some(x=>x.result!=='not_tested');
  state.device_checklist_complete=steps.every(([key])=>state.steps[key]?.result==='pass'&&state.steps[key]?.screenshot);
  state.finished_utc=new Date().toISOString();save();
  console.log('\nANDROID_CHECKLIST='+(state.device_checklist_complete?'COMPLETE_OWNER_REPORTED':'INCOMPLETE')+'; FRAME_TIME_PROOF=REQUIRES_REVIEW\n'+path.join(output,'session.json'));
 }finally{ui.close();save();}
 return state;
}
if(require.main===module)run().catch(e=>{console.error('ANDROID_FOLLOWUP_STOPPED: '+e.message);process.exitCode=1;});
module.exports={run,redact,packageVersion,steps};
