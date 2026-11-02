# Jade Ascendant — Batch 8–10

Implementasi disiapkan di branch `work/player-8-10-20261027`, di atas base `057ed76` dan source batch 1–7 yang sudah dites pemilik. Belum ada commit, push, deployment, AAB export, pemasangan ke project Windows, atau tes perangkat Android.

## R2 — pemeriksaan bridge yang sudah terpasang

R1 keliru mewajibkan hash satu build locked historis. Ini bisa menghentikan source installer pada project yang sudah memakai bridge produksi, walaupun installer tidak menulis file tersebut.

R2 mencatat hash bridge asli dan mempertahankan byte-nya selama pemasangan dan QA. Bridge asli tidak dipromosikan menjadi candidate tepercaya. Candidate untuk export tetap wajib cocok dengan binary, seluruh 50 input native, provenance, serta pin helper/exporter. Helper export membuat backup dari hash asli yang benar dan mengembalikannya setelah export/galat; file yang diubah proses lain tidak ditimpa saat recovery. Receipt export R1 tetap bisa dipulihkan.

Paket penuh R2 menerima baseline batch 1–7 dan file R1 yang cocok dengan byte paket yang pernah dikirim. File lokal lain yang bertabrakan tetap ditahan. Tidak perlu memasang R1 ulang. Jika ada sesi export yang belum dipulihkan, installer menahannya dan mengarahkan ke recovery yang sudah ada.

R2 lolos 9 tes Node, 40 pemeriksaan overlay dalam 14 skenario PowerShell, serta integrasi dari baseline batch 1–7 dan paket R1 yang benar-benar dikirim. Error asli R1 berhasil direproduksi memakai AAR produksi lama, lalu pemasangan R2 mempertahankan byte bridge, main, staging dan edit lokal. VerifyOnly/RecoverOnly juga dijalankan pada PowerShell Linux. Cache QA dan penahanan perubahan bridge di tengah QA diuji dengan callback simulasi yang diberi label terpisah.

Source game, AAR candidate, 50 input kompilasi native dan sembilan gate pembayaran tidak berubah pada perbaikan R2. Bukti gameplay/JVM/server R1 dipakai kembali; pengujian R2 terfokus pada installer, preservation dan recovery. Belum ada bukti eksekusi Windows, AAB export atau tes Android baru.

## Perubahan

- **8 — Sumpah Giok:** opsi replay 1-3 sesudah clear pertama. Satu altar aman pada wave 5; butuh jendela penuh 22 detik sebelum wave 7. Kumpulkan 8 detik di lingkaran; keluar menghentikan charge, sedangkan timer terus berjalan. Pause menghentikan keduanya. Continue membawa posisi, waktu dan progres yang sama. Badge kosmetik Keeper of the Oath serta fragmen cerita baru masuk bersama transaksi Victory yang berhasil. Tidak ada tambahan currency, EXP atau stat.
- **8 — Heavenly Trials:** lima pola v2 dengan telegraph dan jalur keluar, versi minggu/sesi/checkpoint yang tetap, serta negosiasi kemampuan client. Sesi lama tetap v1. Payload start untuk v1 tetap persis format server lama, sehingga update client dapat dipasang sebelum backend v2 diterbitkan. Tidak ada rotasi atau hadiah baru yang diaktifkan.
- **9 — Chronicles:** 11 kisah Lin Yue dalam Indonesia/Inggris, terbuka dari clear yang sah atau badge ritual. Library mempunyai empat tab dalam dua kolom. Kisah bisa dibaca ulang; akses dari stage detail dan Victory menjadi aksi sekunder yang bisa dilewati.
- **10 — Kartu run:** hasil Victory dan Records memakai satu snapshot run final, termasuk armament serta skill utility run tersebut. Feed 1080×1350 dan Story 1080×1920. Alias mati secara default. Data parsial tidak mendapat medal atau total damage rekaan. Trials hanya dapat membagikan hasil yang sudah dikonfirmasi server, terikat ke request yang sama. Fallback lama tidak mengambil build Journey.

PNG disimpan memakai pemilih file Android; Bagikan membuka menu sistem dan tidak mengaku berhasil mengirim. Tidak ada auto-post, hadiah share, email, UID, wallet atau receipt pada kartu. Jalur native menggunakan provider cache terbatas dan Storage Access Framework, tanpa izin akses seluruh foto.

## Bukti

| Pemeriksaan | Hasil |
|---|---:|
| Objektif, cerita, kartu, transaksi, layout dan swipe | 199 PASS |
| Arena Trials v1/v2, final hit dan Continue | 57 PASS |
| Recovery, account binding, ad isolation dan dua format start | 26 PASS |
| Server/admin Trials | 20 PASS |
| Native debug + release JVM | 242 PASS |
| Installer, konflik, binary, branch dan provenance | 6 PASS |
| Gate konfigurasi pembayaran produksi | 9 PASS |

Installer juga dijalankan pada clone Linux terisolasi: 60 file dipasang, rerun mengubah nol file, dan main/staging/edit lokal tetap utuh.

Godot 4.7.2 headless; layout Indonesia/Inggris pada 320×568 dan 360×800. PNG benar-benar dirender dan disimpan, kemudian diperiksa visual. Penolakan transaksi Victory yang disengaja membuktikan badge tetap terkunci jika commit gagal. Satu log ERROR di antara marker `EXPECTED_ATOMIC_FAILURE_BEGIN/END` adalah bagian dari tes ini; tidak ada error runtime lain atau kebocoran saat keluar.

AAR candidate dibangun penuh dengan 121 tes di masing-masing varian. Seluruh 50 input native, hash binary, flags produksi, JNI dan dependensi Play Integrity dipasangkan pada provenance dan pin exporter yang baru. AAR locked yang terpasang tidak diganti. Sembilan gate pembayaran, budget reward, SKU dan alur ad/SSV tetap dipertahankan.

Evidence batch 1–7 yang tidak terdampak dipakai kembali, berdasarkan laporan tes pemilik dan QA sebelumnya. Tidak dilakukan pengulangan seluruh 416 pemeriksaannya.

## Batas verifikasi

Belum ada bukti dari Android untuk chooser/file provider, cancel, notch, GPU, audio nyata, frame time atau tekanan combat ritual. Belum ada eksekusi installer PowerShell/Windows atau AAB export. Uji native JVM dan headless tidak menggantikan pemeriksaan tersebut.

Backend v2 dan dashboard telah disiapkan sebagai source. Deployment dan penjadwalan rotasi v2 adalah tindakan terpisah yang belum dilakukan; memasang paket tidak mengaktifkannya.
