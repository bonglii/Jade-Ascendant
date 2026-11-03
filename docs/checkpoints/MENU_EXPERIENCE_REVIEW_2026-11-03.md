# Jade Ascendant — Menu & Player Experience, 3 November 2026

Batch lanjutan yang disetujui owner pada “oke kalau begitu kita mulai”. Satu paket kumulatif mempertahankan Player Content 18 item yang telah PASS, hotfix warning, native R2 dan semua save/recovery. Branch baru mengisolasi candidate AAB lama.

Source: https://github.com/bonglii/Jade-Ascendant/tree/work/menu-player-experience-20261103
Base candidate: fe4b33b8a7d8595219462e912bf86eb7e6f9ca91. Checkpoint implementasi antara: 7074a278ec7c8e9f037c90519908ed21a8ac63e9. Manifest paket final menunjuk source tepat, receipt delivery melengkapi status ini.

## Perubahan yang dapat dicoba

| Area | Hasil batch |
|---|---|
| Home | Satu target koleksi yang dipin; recovery/Continue tetap didahulukan. |
| Cultivate | Dampak awal run berikutnya, batas cooldown/TEMPO yang jujur, kesiapan spesialisasi Lv.10 dan mastery. |
| Gear/preset | Tiga preset existing mendapat preview seluruh loadout sebelum/sesudah; memakai level/bintang dan ownership existing. |
| Run review | A/B menampilkan perubahan faktual; timeline sepuluh detik mencatat HP aktual sesudah defense dan sumber hit. Continue menyimpan metadata opsional; data lama tetap unknown. |
| Latihan | Sembilan mode: tujuh existing ditambah pola guardian tunggal dan itinerary mingguan lokal. Pola memakai serangan boss produksi; rekor dibatasi, terisolasi akun dan hanya dibandingkan pada kit/rules yang sama. Tidak memberi reward/mastery/clear. |
| Journey | Opsi variasi arah kedatangan musuh biasa pada run baru; jumlah, stat, radius, slot elite dan boss tetap. Continue membekukan pilihannya; default OFF. |
| Warning/audio | Opsi garis/simbol kontras tinggi dengan radius/timing asli; satu voice cue bahaya, cooldown dan ducking terbatas, memakai audio yang sudah disetujui. |
| Hero/Library | Akses langsung ke latihan serta konteks build/boss/jurnal. |
| Daily/Events | Identitas daily, weekly dan milestone Journey; reward hub memakai snapshot current atau earned grace yang cocok. Tidak ada nominal reward karangan. |
| Weekly Trials | Panduan counterplay dan diagram ilustratif; diagram bukan hitbox/timer live. |
| Lima event milestone | Sumber progress dan tindakan berikutnya di popup produksi existing. |
| Odyssey | Panduan rute, lap dan masa klaim berdasarkan snapshot; progres yang belum diketahui ditulis menunggu, bukan 0/72 terkonfirmasi. Tidak mengaktifkan campaign. |
| Pemain kembali | Popup Meditation dan tujuh hari diaudit; tombol disabled lebih kontras dan menyatakan iklan tidak tersedia selama hold, termasuk sebelum Qi siap. Claim/cooldown authority existing dipertahankan. |
| Pavilion | Panduan target/build untuk dua mode dan jaminan existing; biaya/paid ownership tetap. |
| Mail/Treasury | Mail claimable dan expiry terdekat didahulukan; bantuan pending delivery/Restore tanpa pembelian ulang. |
| Settings | Preview kenyamanan, opsi kontras/variasi arah dan label EN/ID. |

Tema memakai kembali artwork xianxia jade/perunggu, frame record, sanctum, font dan suara yang telah disetujui. Tidak ada redraw player, mata uang/senjata/set baru atau perubahan harga/HP/damage global.

## Bukti author dan batasnya

- Runtime fresh: menu 60, content 98, clarity 66, restart/Continue 6, native Trials 57 dan direction 54: **341 checks, 0 failure**. Seluruh log final diperiksa sampai proses selesai, tanpa SCRIPT ERROR/ERROR. Log awal Trials headless gagal pada gesture karena tidak memiliki touchscreen hint; inherited suite diperbaiki pada wrapper fixture dan lulus melalui native window.
- Bukti native: 60 scene awal, 85 focused termasuk inset/popup, 40 panduan final, 10 returning player, 12 pemeriksaan penutup, 21 capture gesture dan 15 pilot. Area yang diulang untuk perbaikan adalah capture tambahan, bukan fitur atau tes manusia yang berbeda.
- Native review menggunakan Godot 4.7.2 resmi, X11/Xvfb, Mesa llvmpipe, emulasi touch dan audio Dummy. EN/ID, 360×640 dan 405×860, safe inset sintetis; detail capture/interaksi final ada di evidence/receipt.
- Pilot native memakai tombol Home → Realm → Stage → Begin Trial, melihat tutorial awal lalu memakai tombol Skip yang terlihat, menggerakkan player melalui keyboard dan menjalankan combat produksi. Dua mode latihan baru dijalankan. Swipe pertama pada kartu preset benar-benar menggulir, tanpa pindah scene/aplikasi preset. Ini input pilot, bukan manusia menamatkan semua mode atau bukti retention.
- Guide Escape 10/10, swipe kartu Settings, perbandingan preset, popup milestone di atas Home, reward row mingguan dan panduan bilingual diperiksa. Capture fixture memakai akun/data sementara; angka contoh tidak membuktikan live service.
- Native R2 preflight cocok dengan **52 input** dan AAR candidate 2171f13f36cf8d90988fd20248f879653104625c8481b91d3fb0a4303fb098ea. Tidak rebuild JVM/native; bukti historis yang tidak berubah dipakai kembali.
- Ada warning teardown renderer Linux berupa RefCounted dengan reference count 0, juga direproduksi pada candidate lama: 26 pada baseline, 27 pada source ini, tanpa orphan Node/SCRIPT ERROR. Kedua versi bersih pada uji headless yang sama. Warning dicatat, tidak disembunyikan sebagai teardown bersih. Driver software juga tidak mendukung V-Sync. Ini tetap perlu dilihat pada QA Windows/HP.

Installer PowerShell nyata: 9 skenario / 0 gagal, termasuk tiga baseline (18ff, fe4, e258), merge independen, konflik, recovery aktif, rollback setelah tulisan nyata, CRLF/BOM dan payload rusak; 5 pemasangan ulang tanpa perubahan source. Rollback memakai edit bersamaan terkontrol setelah environment menolak capability setpriv. Arsip final dan status penyimpanan dicatat dalam delivery receipt. Bukti yang pernah hilang ketika workspace kedaluwarsa tetap berlabel historis; log/screenshot baru tidak direkonstruksi sebagai bukti palsu.

## Batas rilis

AdMob hold **ON**, tanpa tanggal aktivasi otomatis. Sembilan gate pembayaran, paid ownership, pending receipts, refund, wallet dan pemulihan tetap. Tidak deploy backend, aktivasi event, notifikasi, analytics rollout, export AAB atau upload Play.

Windows Player Content sebelumnya tetap PASS berdasarkan owner 3 November. **Pemasangan/QA Windows batch menu ini, AAB baru dan tes HP belum dikonfirmasi.** Candidate lama/main tidak diubah. Owner menjadi pemeriksa kedua setelah menjalankan launcher kumulatif; jangan mengulang recovery lama yang sudah PASS.

Paket: ekstrak ke folder baru, tutup Godot, tunggu sesi exporter existing memulihkan bridge bila aktif, lalu jalankan apply_and_test.cmd. Target MENU_EXPERIENCE_WINDOWS_QA=PASS. Jika QA terhenti sesudah source dipasang, lanjutkan qa_only.cmd; jangan menghapus save/cache/receipt/recovery marker. Sesudah Windows PASS, pemilihan build AAB tetap keputusan owner karena candidate sebelumnya mungkin sedang diuji.
