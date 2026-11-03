# Jade Ascendant — Player Content Batch

Batch 2 November 2026; finalisasi 3 November 2026 (WIB).

Seluruh 18 masukan telah diimplementasikan sebagai satu batch. Tema memakai kembali frame jade/perunggu, sanctum, sprite, ilustrasi Chronicles dan pola boss yang sudah disetujui. Redraw Lin Yue yang dibatalkan dan aura kosmetik yang ditahan tetap tidak dimasukkan.

Source: branch work/player-review-batch-20261102, turunan source owner a5d2bf42586067ef1ef4d6460b7a4d291f9b869b. SHA tepat dicatat dalam manifest.json paket. Main dan layanan produksi tidak diubah. ZIP adalah patch kumulatif, bukan seluruh repository.

## Seluruh masukan dan hasilnya

| No. | Masukan | Implementasi dan letaknya |
|---|---|---|
| 1 | Hadiah Trials akurat | Preview mengikuti snapshot minggu yang cocok, termasuk minggu sebelumnya/grace; bonus membaca Stones minggu tersebut. Angka tetap 40/1/600 dihapus. |
| 2 | Iklan tidak tersedia | monetization/ads_suspended=true menahan jalur init/load iklan client. Pavilion membedakan kuota dan ketersediaan penayangan. Tidak memberi reward palsu atau mengaktifkan iklan dari kalender. |
| 3 | Saran setelah kalah | Petunjuk boss mengikuti gaya encounter, dengan arah ke Jurnal → Arsip Boss → Latihan. Hit, HP loss dan rincian damage tetap ada. |
| 4 | Daily lebih ringan | Aturan v2 pada reset berikutnya: combat 20/50, level 5/7, clear 1/2. Hari yang sudah diterbitkan mempertahankan aturan lama. ID dan nominal reward rotasi tetap. |
| 5 | Build dan bahasa | Panduan Home/Pavilion diperbarui; role build, uraian set/senjata, 18 uraian skill dan tindakan Library dilokalkan. Nama art/item/realm dipertahankan. Caption navigasi diperjelas. |
| 6 | Practice jelas | TOTAL BUILD, rincian sumber dan jendela 15/30/60 detik. Angka memakai applied HP loss; starter dan art pilihan dapat sama-sama berkontribusi. |
| 7 | Latihan boss | Guardian Bab 1 yang sudah ditemui atau stage-nya pernah di-clear memakai actor/pola produksi. Tanpa clear Journey atau currency. |
| 8 | Pertahanan Segel | Mode 75 detik, tiga segel Jade Oath, masing-masing 8 detik pengisian sambil menghindari musuh. |
| 9 | Cerita realm | Lima fragmen bilingual menambah 11 Chronicles menjadi 16. Masing-masing terbuka setelah clear stage 3 realm terkait. |
| 10 | Risiko Trials | Pilihan pribadi opsional: pola 7 detik versus standar 9 detik, incoming damage +15%. Tersimpan per akun/sesi; reward dan aturan medali server tetap. |
| 11 | Altar berkah | Mulai wave 3: Bara +12% direct-art damage/−10% gerak; Angin +10% gerak/−8% damage; pilihan seimbang tersedia. Continue menyimpan pilihan. |
| 12 | Prioritas target | Pecahkan Pelindung: ward bearer memberi minion dekat pengurangan damage 35%; hancurkan pemberi pelindung dahulu. Encounter terisolasi tanpa XP drop/reward. |
| 13 | Misi teknik | Enam art pada kit tetap Lv.5; perlu tiga target dan jumlah hit art yang dipilih. Catatan pribadi per akun/perangkat, tanpa mastery XP baru. |
| 14 | Build seragam | Mode 60 detik: 100 HP, power/tempo dasar, art Lv.3, tanpa equipment/cultivation/mastery. Kepemilikan asli tetap. |
| 15 | Dua run | Jurnal → Run Terakhir: pilih A/B dan lihat waktu, level, hit, HP loss, damage/DPS, gear dan jalur. Data lama/parsial atau stage/hasil berbeda diberi konteks. |
| 16 | Gauntlet | Tiga guardian Bab 1 yang sudah dikenal, berurutan, batas 180 detik. HP dibawa antarpertarungan. Tanpa currency baru. |
| 17 | Combat terbaca | Settings → Ornamen Player Ringan menyembunyikan jejak/flourish tambahan. Bentuk serangan, peringatan musuh dan opsi kenyamanan lama dipertahankan. |
| 18 | Cabang art | Lv.5: Fokus +20% boss/−10% musuh lain; Sapuan +15% musuh lain/−10% boss; Seimbang memakai damage asli. Tersimpan saat Continue. |

Tujuh mode tersedia melalui Library → Jurnal Kultivator → Pelataran Latihan. Latihan boss dan gauntlet memerlukan encounter yang dikenal. Mode tambahan tidak menambah ekonomi currency/mastery kedua.

## Temuan tambahan yang sudah diperbaiki

- Loading pertama memakai chapter/stage pilihan, sehingga tidak menampilkan Stage 0-0 sebelum aktivasi run.
- Angka enum JSON diperiksa sebagai angka bulat berbatas sebelum konversi. Ruleset, stage dan risiko tidak gagal karena JSON menghasilkan float.
- Training memakai parent Control penuh untuk safe area. Joystick hanya menerima input ketika latihan berjalan dan setup tertutup; swipe dropdown tidak tertangkap joystick di belakangnya.
- Esc menutup setup dan modal altar/art. Back pada pilihan mempertahankan seimbang/tanpa berkah tanpa meninggalkan scene.
- Fitting detail Library berhenti saat scene dilepas atau popup diganti. Pergantian detail/ukuran/menu cepat sebelumnya dapat memanggil get_tree pada node yang sudah terlepas.
- Keterangan Yin-Yang menyebut interval hit per bilah sesuai R2; koreksi teks tidak mengubah koefisien, interval atau collider.
- Installer memilih ancestor yang cocok dengan file pada Git HEAD. Baseline masa depan tidak dapat dipakai untuk meloloskan konflik secara diam-diam.

## Balance dan ekonomi

Cabang art memberi peran boss/kelompok dengan penalti nyata; seimbang tetap tersedia. Gabungan cabang+altar memberi pengali direct-art 0,828–1,344 sebelum bonus/crit existing; gerak altar 0,90 atau 1,10. Tidak menambah projectile, hitbox, cooldown atau emitter. Tick DoT set tidak mendapat pengali cabang/altar kedua; interaksi berbasis hit existing dipertahankan.

Daily tetap enam quest dengan budget reward langsung rotasi sebelumnya 300–340 Stones. Hari lama tidak diganti di tengah hari. Risiko Trials memberi tantangan pribadi dengan reward server yang sama. Latihan, teknik dan perbandingan run bukan otoritas wallet, ownership atau leaderboard.

Damage diukur melalui actor/ledger produksi dan applied HP loss, termasuk killing hit. Fixture gauntlet menghormati phase gate: threshold hit, penghabisan timer ward secara eksplisit, lalu killing hit. Ini bukti logika, belum bukti clear manusia atau balance seluruh chapter di HP.

## Bukti dan batas QA

| Bukti | Hasil dan cakupan |
|---|---|
| Runtime sebelumnya | 251 checks/0 fail: content 98, Trials 27, clarity 66, restart 6, direction 54. Launcher PowerShell lengkap PASS pada Unix. Dipakai kembali untuk mekanik yang tidak diubah; bukan fresh full-run sesi lanjutan. |
| Installer sebelumnya | 14 skenario dan 6 repeat PASS, termasuk source/native, recovery, corrupt payload, BOM/CRLF, konflik dan rollback. |
| Installer lanjutan | Enam skenario terfokus dan empat repeat PASS: a5, 417a, CRLF/BOM, edit independen, konflik dan recovery aktif. |
| Native R2 | Pemeriksaan baru cocok dengan 52 input dan AAR SHA256 2171f13f36cf8d90988fd20248f879653104625c8481b91d3fb0a4303fb098ea. Tidak dibangun ulang. JVM 248 adalah bukti R2 historis. |
| GUI sebelumnya | 82 render/aspect EN/ID sudah diperiksa sebelum putus. Raw files hilang bersama workspace; checkpoint dipertahankan tanpa membuat screenshot/log lama palsu. |
| GUI lanjutan | Capture asli 360×640/405×860 EN/ID; native swipe dropdown, Esc setup/altar/art, Run A/B, toggle/restore ornamen dan popup detail diperiksa. Capture, metadata, log dan receipt terpilih ada di evidence. |
| Lingkungan | Godot 4.7.2 official, Linux Xvfb/Mesa compatibility, input X11 dengan emulasi touch, audio Dummy. Bukan Android touch, mix audio, thermal, battery atau FPS HP. |

Recovery/Windows R2 tidak diulang. Receipt lama dibedakan dari log baru. Percobaan harness yang gagal tetap dijelaskan: dependensi XKB, fokus keyboard popup, dan fitting detail setelah detach. Teardown fixture dibenahi; pemeriksaan akhir Library dan Settings selesai tanpa error/leak warning. Error tidak disaring agar seolah PASS.

## Pasang dan lanjutkan

Ekstrak satu ZIP, tutup Godot, jalankan **apply_and_test.cmd**. Default project D:\Godot\project\jade-ascendant. Installer memeriksa source/native/recovery sebelum menulis, menyimpan backup byte asli, menggabungkan edit independen dan menolak konflik sebelum source berubah. Tidak ada reset/clean/force-push atau penghapusan save/cache/receipt.

Target Windows: **PLAYER_CONTENT_WINDOWS_QA=PASS**. Jika source sudah terpasang tetapi QA berhenti, gunakan **qa_only.cmd**. Sesudah Windows batch baru PASS, gunakan backend\player_identity\export_production.cmd dan pertahankan terminal sampai bridge asli dipulihkan.

Recovery dan Windows R2 lama tetap PASS berdasarkan konfirmasi owner. **Windows batch konten baru, AAB dan tes HP belum dikonfirmasi.** Tidak ada backend deploy, aktivasi event, notifikasi atau upload Play Console. Status AdMob tidak ditentukan dari kalender; penyebab spesifik penangguhan belum diketahui.
