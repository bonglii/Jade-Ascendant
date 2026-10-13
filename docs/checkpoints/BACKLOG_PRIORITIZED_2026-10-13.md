# Jade Ascendant — backlog gabungan dan urutan prioritas
Tanggal: 13 Oktober 2026

List ini menggantikan urutan lama. Semua 12 tambahan pengguna digabungkan dengan audit HP/damage/economy/weapon/VFX dan integrasi iklan yang sudah disepakati. Item yang dibuka kembali oleh pengguna tetap dianggap belum selesai di perangkat, meskipun patch sebelumnya sudah dikirim.

| Urutan | Paket pekerjaan | Cakupan list | Status |
|---|---|---|---|
| 1A | Performa menu dan input sentuhan | Perpindahan menu, loading Trials, hover saat scroll di LiveOps dan menu lain; Guest tidak tertahan inisialisasi akun | Patch tahap pertama selesai; perlu export dan QA HP |
| 1B | Profiling Google asli dan keramaian musuh | Latency native Google, DNS/token/server bila relevan; frame-time/physics/VFX saat musuh ramai | Timing ditambahkan; pembuktian Google memerlukan log HP. Crowds belum dituning |
| 2 | Mailbox dan boss notices | Surat terpotong/melewati kertas, posisi sync, responsive reader; nama dan warning boss premium dengan posisi center atas di bawah HUD | Prioritas perbaikan berikutnya. Patch notice sebelumnya bukan bukti hasil APK terbaru |
| 3 | Audit combat, economy dan loop progres | HP player/musuh, damage, weapon dan Mastery/set, scaling/density wave; currency, harga, duplikat, rate/pity; peluang skill yang sudah dimiliki; magnet EXP; congratulation level-up | Belum dikerjakan dalam patch performa |
| 4 | Premium combat art dan gerak | Main character terasa berjalan; semua enemy/boss, pola serangan, lightning; semua skill book UI/UX/VFX; identitas tiap weapon | Audit aset/frame/animasi nyata dahulu. Generate aset bila hasilnya diperlukan |
| 5 | Hasil pertarungan dan Trials visual | Victory/defeat/reward premium. Redesign Trials jika performa sudah stabil tetapi presentasi masih kurang | Gameplay/reward authority tetap terpisah dari visual |
| 6 | Pengumuman in-game dari dashboard | Admin mengirim popup ke seluruh pemain; UI konsisten, anti-spam, status dibaca, masa aktif/prioritas sesuai kebutuhan | Fitur baru; belum terimplementasi |
| 7 | Integrasi iklan | Rewarded ad free 1x pull di Paviliun; batas frekuensi dan grant aman setelah iklan terverifikasi | Setelah audit economy, tidak mendahului balance |

## Aturan implementasi
- Performa lebih dulu supaya polish berikutnya tidak menambah lag; jangan mengurangi musuh, HP/damage, peluang skill atau hadiah secara diam-diam.
- Mailbox/boss yang dilaporkan masih buruk harus diverifikasi di build terbaru, bukan ditandai selesai dari jumlah tes saja.
- Magnet mengambil EXP yang memang sudah ada. Tidak menciptakan EXP baru. Kandidat drop awal untuk diuji: elite atau milestone sekitar tiga wave, dengan syarat ada EXP yang cukup tertinggal; frekuensi final ditetapkan melalui audit.
- Bias skill membantu menaikkan skill yang dipilih, tetapi tetap mempertahankan pilihan baru. Angka peluang belum diubah sebelum mengukur pool/level cap aktual.
- Level-up dibedakan antara level Hero permanen dan level run agar celebration tidak menggandakan skill-choice/reward.
- Pengumuman dashboard yang dimaksud adalah popup di dalam game. Push notification OS/background adalah scope terpisah jika kelak diminta.
- Persetujuan generate asset tetap berlaku; tema xianxia/wuxia, inspeksi sumber dulu, premium dan konsisten.
- IAP yang diparkir tetap tidak diubah; link commit hanya setelah push terverifikasi.

## Hasil tahap 1A
Trials tidak lagi membangun kartu UI lama yang akan disembunyikan. Bagian aktif dibangun bertahap (maksimal dua kartu baru per batch atau batas kerja empat milidetik sebelum yield). Bagian lainnya dibangun saat dibuka dan kemudian dipertahankan. Prewarm mengikutsertakan dua scene Trials dan melepaskan cache ketika masuk gameplay.

Guard sentuhan menonaktifkan tampilan hover desktop yang disintesis pada touch, mempertahankan warna tekan/eligibility dan mouse desktop, serta mengikuti kontrol popup dan perubahan tema. Nav dan meridian custom menggunakan policy yang sama. Ini adalah perbaikan presentasi touch, bukan klaim semua gesture aktivasi baru sudah diganti.

Guest boleh masuk ke game lokal saat anonymous identity disiapkan. Login/link/sign-out Google yang benar tetap diserialisasi. Log ACCOUNT_LATENCY merekam nama operasi dan durasi tanpa UID/token, sehingga bottleneck native dapat dibuktikan. Belum ada klaim provider Google menjadi lebih cepat di HP.
