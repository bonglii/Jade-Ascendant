# Batch 1–7 — uji Android terarah

Status author: belum ada HP tersambung. Headless QA bukan bukti tampilan, suara, gesture HP atau frame time. Nomor 8–10 tetap menunggu sampai pemeriksaan perangkat ini ditutup.

Gunakan HP tester dan build AAB baru dari source batch ini. Pertahankan data/save utama. Jika sebuah kondisi belum tersedia di profil tester, tandai **belum diuji**; jangan menghapus data utama untuk memaksakan kondisi tersebut.

1. Jalankan `apply_and_check.cmd` dari ZIP. Pemasang membuat backup dan memeriksa source, lalu menjalankan QA pada save terisolasi. Tidak membuat commit, push atau deploy.
2. Export melalui `backend\player_identity\export_production.cmd` yang sudah dipakai. Tetap gunakan signing, native bridge dan konfigurasi produksi yang ada. Atur versionCode berikutnya lewat alur rilis biasa; paket ini tidak menimpa nomor versi lokal.
3. Pasang build tersebut melalui alur tester yang biasa, sambungkan USB debugging, dan buka game. Jalankan `android_playtest.cmd`, lalu isi **versionCode yang benar-benar terpasang**. Script memverifikasi package, bukan menebak dari preset repo.
4. Ikuti tujuh pemeriksaan di terminal. Isi `p` jika lulus, `f` jika ada masalah, `s` jika belum diuji. Screenshot diambil setelah setiap langkah; catatan dan log package disamarkan untuk email/token.

| Pemeriksaan | Hasil yang harus terlihat |
|---|---|
| Victory → Home → buka ulang | Continue run selesai tidak muncul, reward tidak berulang. |
| Run belum selesai → Home → Continue | Stage, waktu, HP dan skill pulih dari checkpoint. |
| Campaign aktif + progres lama | Chapter pertama /5, total 25; cache/achievement/ladder tidak memerlukan 1-6. Rekor/klaim lama tetap ada. |
| Guest kosong + equipment pertama | Kosong diarahkan ke Cultivation terjangkau/Journey. Setelah mendapat equipment, panduan bintang/level masih dapat muncul. |
| English / Indonesia | HERO, detail, harga, receipt, panduan dan counter pilihan mengikuti pilihan bahasa; nama art/item tetap konsisten. |
| Build + antrean pilihan | Hint cocok dengan skill yang dimiliki, satu upgrade per tap, counter turun, arena tetap pause hingga pilihan terakhir, heal normal per level. |
| Gesture, layar, audio, performa | Swipe pertama dari kartu/tombol tidak memicu aksi; Back/tap sengaja berfungsi; tidak terpotong pada portrait sempit; audio/background/resume wajar. Mainkan combat ramai setidaknya 10 menit dan catat stutter/panas/crash. |

Hasil disimpan di `.local/player_followup_android/<waktu>/session.json` beserta screenshot, log game dan `android-gfxinfo.txt`. File gfxinfo dapat kosong/tidak merekam renderer Godot; jangan mengubahnya menjadi klaim FPS. Checklist lengkap berarti semua observasi owner terisi lulus dan screenshot tersedia. Penilaian visual/audio serta frame time tetap harus ditinjau dari perangkat yang menjalankannya.

Untuk lokasi berbeda, teruskan `--project "folder project" --adb "folder\adb.exe"`. Jika beberapa HP tersambung, tambahkan `--serial ID`. Script tidak memasang aplikasi, menghapus data, menekan tombol reward atau melakukan pembelian.
