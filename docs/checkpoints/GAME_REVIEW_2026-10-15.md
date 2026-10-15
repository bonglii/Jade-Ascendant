# Jade Ascendant — penilaian game, 15 Oktober 2026

Penilaian dari kode produksi, aset yang dipakai, render Godot dan fixture runtime terisolasi. Ini bukan klaim sudah memainkan seluruh game di HP atau mengukur retensi pemain. Acuan kode: Home Sanctuary `6719f50`, kemudian batch premium ini. Rilis tetap ditunda sesuai instruksi.

## Penilaian jujur

Identitas game sudah kuat: Lin Yue, tema xianxia/wuxia, senjata dengan pola serang berbeda, empat bagian armor untuk pasif set, serta laporan damage per sumber. Masalah terbesarnya sekarang adalah konsistensi pengalaman dan kesiapan layanan akun/pembayaran. Menambah banyak konten sebelum dua bagian ini jelas akan memperbanyak pekerjaan perbaikan.

| Area | Penilaian pemain | Tindakan batch ini / batas bukti |
| --- | --- | --- |
| Presentasi | Home punya arah jelas; hasil run dan Settings tertinggal. | Bingkai/background hasil dan Settings baru, tinggi hasil mengikuti isi, preset visual. Render native diperiksa. |
| Hero & sentuhan | Sulit membandingkan loadout jika ikut tergeser; glow saat swipe memberi kesan salah tekan. | Loadout dipasang tetap, backpack 5 kolom bergeser sendiri, bintang/border diperkuat, dropdown dibatasi, hover sentuh dan scrollbar ditangani bersama. |
| Kepercayaan hasil | Ikon starter bisa salah saat weapon berubah; “reward secured” tanpa receipt menyesatkan. | Ikon memakai identitas weapon dalam run; teks secured hanya mengikuti entri grant yang ada. Ledger, HP loss, killing hit dan checkpoint dipertahankan. |
| Efek set | Identitas efek sudah sesuai pasif, tapi terlalu samar di arena. | Alpha dinaikkan 1.4× dengan clamp dan fade lama; tidak menambah partikel, damage atau biaya draw. |
| Akun | Login Google belum berarti progres otomatis aman di cloud. Callback lama dan koneksi buruk perlu ditangani. | Korelasi akun/token, nonce HTTP, retry token sekali, route DNS HTTPS cadangan dan ringkasan bantuan. Cloud Save belum aktif; tidak ada merge/upload progres. |
| Monetisasi | Belum layak disebut siap jual bila pembelian belum terbukti masuk, dipakai dan pulih tanpa kredit ganda. | Perbaikan shared JWT, refresh signing key dan kesiapan App Check native. Gate pembayaran tetap sesuai status bukti. Belum ada klaim transaksi Play produksi lulus. |
| Event | Infrastruktur banner/mail/broadcast sudah berguna. Nilai bermain perlu tujuan yang berbeda, bukan hanya hadiah berbeda. | Dashboard dan reward tidak diubah spekulatif. Event berotasi dengan modifier pertarungan dan tujuan koleksi adalah arah berikutnya setelah transaksi/akun selesai. |
| Jangka panjang | Duplikat + level weapon memberi tujuan, tetapi biaya target maksimal dapat terasa panjang. | Data aktual diekspor dan simulasi di bawah dijelaskan. Tidak ada buff HP, pengubahan odds atau biaya secara sembarang. |
| Performa HP | Tes desktop tidak membuktikan frame pacing atau jaringan semua provider. | Pinned UI tidak rebuild saat scroll, VFX hanya alpha, profil memakai request thread dan retry terbatas. Hasil HP ramai sebelumnya tidak diuji ulang tanpa perubahan combat. |

## Data ekonomi yang benar-benar tersedia

Ekspor runtime: 26 stage, 56 equipment aktif, 11 set. Empat armor/accessory memberi set bonus; weapon berdiri sendiri. Duplikat identik untuk naik bintang. Level weapon permanen terpisah, cap 10/20/30/40/50, damage +1% per level sesuai implementasi saat ini.

Default offline gacha: common 60%, rare 29%, epic 9%, legendary 2%. Pity rare+/epic+/legendary pada 10/30/50. Satu pull: 100 Jade atau 1 Seal; sepuluh: 900 Jade atau 10 Seal. Bonus penyelesaian harian 20 Jade. Siklus active-day memberi 160 Jade + 4 Seal, dengan cap iklan 7 per siklus. Ini bukan janji pendapatan kalender mingguan dan bukan jaminan iklan selalu tersedia.

Simulasi 1.000 kampanye, seed 13102026, target tetap, semua rarity terisi, pity awal kosong, default offline: rata-rata target pertama 41.904 pull; lima kopi 208.539; median 209; p95 282; maksimum teramati 397; batas keras model 495. Ini bukan odds banner live atau jumlah hari wajib untuk pemain. Saran desain: jelaskan pity/target dan duplikat lebih awal; ukur akuisisi pemain nyata sebelum memutuskan menaikkan rate atau menjual paket baru.

Login hari 1–7 pada ekspor ini memberi 100/190/260/350/440/600/1000 Spirit Stone. Idle tier 1→26 memberi 48→198 Spirit Stone/jam dan 12→60 Hero EXP/jam. Reward stage 5-5: first clear 4800 Stone +1635 Hero EXP; repeat 2475 +1090. Nilai ini berasal dari definisi, bukan pengukuran pendapatan per jam saat dimainkan.

Stage 5-5 memiliki boss HP 55.800, damage 17, cap musuh 110, multiplier HP musuh 2.35, wave 33 detik dan interval kenaikan difficulty 108 detik. Jangan membaca angka HP ini sendirian sebagai bukti boss terlalu tebal: butuh damage build aktual, gerak target, durasi arena dan pressure serangan. Review keseimbangan sebelumnya tetap berlaku; batch UI tidak mengulang audit combat yang tidak berubah.

## Yang masih memerlukan akses/bukti eksternal

1. Rebuild AAR yang memuat perbaikan App Check, lalu re-export Android. Launcher disediakan; CI build/JVM/JNI juga ditambahkan. Sukses kompilasi berbeda dari token Play Integrity yang berhasil di perangkat.
2. Deploy worker profil memakai config lokal yang benar, tanpa migrasi DB. Shared JWT juga perlu masuk deployment IAP staging melalui prosedur staging yang sudah ada. Perubahan source lokal belum mengubah worker live.
3. Bukti Play sandbox: pembelian nyata tester, kredit tepat satu kali, restore/retry setelah restart, penolakan akun lain, refund/void dan paid wallet/delivery yang benar. Tidak perlu transaksi uang asli untuk menyelesaikan bukti sandbox.
4. Uji HP pada minimal dua jaringan dan akun baru. Fallback DNS menangani sebagian kegagalan resolver; tidak menjamin hostname melewati filter semua ISP. Custom domain studio memerlukan domain yang dimiliki dan akses DNS; tidak dibuat nama/domain palsu.
5. Cloud Save, event baru dan perubahan ekonomi besar membutuhkan rancangan/siklus implementasi sendiri. Tidak ada fitur palsu yang diberi status selesai di batch ini. Ide event di atas masih rekomendasi, bukan konten yang sudah dipasang.

Acuan resmi build: https://developer.android.com/build/releases/agp-8-13-0-release-notes ; App Check: https://firebase.google.com/docs/app-check/android/play-integrity-provider .
