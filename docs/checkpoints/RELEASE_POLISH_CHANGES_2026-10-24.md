# Release polish — 24 Oktober 2026

Base: 9ca46e7d8498c0998a17536e5f1793fe153a074a. Branch checkpoint/iap-fasttrack-20261010.

| Permintaan | Perubahan |
| --- | --- |
| Mailbox lama saat klaim/hapus | Claim/delete yang tiba saat list/read latar berjalan kini mengambil jalur prioritas setelah jeda pendek, termasuk klik pada 1500 ms pertama. Token dan sesi yang sudah hangat tetap digunakan. Delete All tidak membuat request bila tidak ada surat yang boleh dihapus. Lease, receipt, ACK, dan save tetap menjadi authority. |
| Iklan lambat / dadu telat | Cache general/meditation diprioritaskan; cache kedaluwarsa disegarkan saat resume. Pengecekan receipt dadu dimulai segera dari callback earned, lalu memakai jeda 0,4–15 detik yang dibatasi. SDK callback tidak memberikan dadu lokal: jumlah dan banner REWARD GRANTED mengikuti receipt server dengan nonce yang benar. |
| Semua sound terasa prototype | Seluruh cue aktif memakai 87 efek suara V3: rekaman material yang diedit/layer, variasi hit delapan keluarga, UI/claim/equip/upgrade, summon, boss, victory/defeat. Empat musik Home/Journey/Boss/Pavilion diganti dengan musik berlisensi bernuansa Asia. Credit dan lisensi tersedia di menu Credits. PCM mono 44,1 kHz untuk efek; Ogg stereo untuk musik. |
| Cooldown Paviliun | Tombol menampilkan detik cooldown dan hitung mundur reset harian. Kuota yang berlaku tetap satu rewarded Seal per hari dengan batas tujuh per siklus; reset harian 00:00 UTC/07:00 WIB. Syarat pemulihan siklus dijelaskan. |
| Shadow hitam popup | Lapisan penutup di rates/target/history/Server Armory dan popup Odyssey diperingan menjadi tint giok tipis; shadow panel tambahan dihilangkan. Isi popup tetap opaque supaya teks terbaca. |
| Popup target / flash besar-kecil | Kategori weapon/set memakai panel yang sama dan ukuran stabil. Panel beserta anaknya menunggu fit pertama; pilihan memuat artwork dan nama item sebenarnya. Kategori default mengikuti jenis target yang disimpan. Armory menyesuaikan tinggi konten dan menampilkan gambar item yang dipilih. |
| Efek rate-up kurang mewah | Halo dan dragon artwork yang sudah konsisten dengan sanctum dipakai lebih jelas; pola lingkar geometris pada preview disisihkan. Rasio asli gambar equipment dipertahankan. |
| Locked kurang terlihat | Notice besar menyebut clear stage 1–5; label LOCKED tidak pecah baris. Rates sebelum unlock menampilkan rate dasar dengan penjelasan, bukan empat angka nol. |
| Achievement Claim All | Footer aktif untuk Daily dan Achievement. Satu tindakan menggunakan manager reward yang sudah ada; preview mencakup mata uang terkait. Menekan ulang tidak menggandakan hadiah. |
| Gacha kaku / nama bocor | Identitas disembunyikan sebelum seal terbuka, tween lama dihentikan, ruang hasil disiapkan sejak awal. Gambar tidak diregangkan; Continue tetap muat pada layar pendek. Rarity tetap berbeda, dan reveal all tetap bekerja. |

Bukti author: cold import tanpa ERROR; mailbox 44 checks dan inbox 78 checks; rewarded routing 66; tiga skenario delivery/provider/ad interaction; picker 117; gacha 701; Trials 406; run report 176. Renderer X11/Mesa: 22 pemeriksaan batch, 159 gesture/layout, pixel proof empat rarity (sebelum reveal sama, sesudah berbeda). Integritas 87 WAV + empat Ogg dan sembilan gate produksi lulus.

Jeda jaringan/AdMob dan kedatangan callback SSV tetap bergantung pada layanan/jaringan. Bukti fixture bukan benchmark perangkat atau klaim hadiah instan. Tidak ada pembelian nyata baru, deploy Worker, aktivasi event, pengiriman notifikasi, native/AAR rebuild, atau Android playtest pada author batch ini.

Gunakan publisher portable satu kali; replay memakai receipt tahap yang sudah selesai. Sesudah sync dan exact-SHA CI berhasil, gunakan exporter produksi yang sudah ada untuk satu AAB kandidat.
