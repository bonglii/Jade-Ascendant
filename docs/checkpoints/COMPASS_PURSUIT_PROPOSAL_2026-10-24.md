# Heavenweaver Compass — rancangan untuk persetujuan

Status: APPROVED and implemented in the combined batch. The original design below is retained; measured final behavior is in COMPASS_BALANCE_2026-10-24.md and INTERFACE_CHANGES_2026-10-24.md.

## Peran
Senjata event legenda dengan pengejaran berkelanjutan untuk melindungi ruang di sekitar Lin Yue. Tetap mengikuti ownership, event authorization, level permanen/star, mastery dan run-report yang sudah ada.

## Target dan gerak
Satu naga giok terus aktif ketika ada musuh valid dalam jangkauan. Cari dari posisi Lin Yue, pilih musuh terdekat; ikuti posisi aktual target, bukan titik bekasnya. Target diperiksa berkala (rencana 0,15 detik) dan memakai hysteresis agar tidak zig-zag saat dua musuh sama dekat. Mati/keluar jangkauan segera melepas target. Ancaman baru yang jauh lebih dekat boleh memutus pengejaran lama. Tanpa musuh, naga kembali mengorbit kompas; saat pause/background tidak memberi hit.

Gunakan jangkauan saat ini sebagai titik awal audit: 320 unit musuh biasa, 230 boss. Ini parameter rancangan yang harus diuji terhadap boss bergerak dan arena; tidak menjanjikan range tak terbatas.

## Damage dan upgrade
Animasi terus bergerak, tetapi damage memakai interval hit per target, bukan setiap frame. Titik awal desain: interval 0,45 detik dengan batas minimum 0,25 detik setelah Attack Speed. Damage per tick diturunkan/ditakar dari anggaran DPS senjata lama; ini target desain, belum hasil pengukuran. Power/crit/set tetap lewat PlayerStats dan RunCombatLedger. Tidak ada tick ganda dalam frame yang sama, critical/resonance proc dibatasi, damage terbatas pada HP loss aktual.

- Lv.1: satu naga, fokus ancaman terdekat.
- Lv.3: belokan dan perpindahan target lebih lincah; feedback kompas lebih kuat.
- Lv.5: bayangan naga memberi serangan susulan terukur, bukan proc rekursif.
- Lv.7: dua naga berbagi dua ancaman terdekat. Jika hanya ada boss, gabungan hit tetap mengikuti anggaran single-target; bukan otomatis dua kali DPS.

Lv.3/5/7 adalah level skill combat. Level permanen dan star senjata tetap terpisah, tanpa mengubah biaya duplikat, rarity, unlock atau ledger.

## VFX
Tubuh naga bersegmen dengan kepala yang mengikuti arah gerak, jejak giok–emas memudar, inti kompas berputar halus dan impact berbentuk kelopak/cahaya pendek. Dua naga punya aksen berbeda agar lintasan terbaca. Tidak ada kilatan full-screen atau garis panjang yang menyamarkan musuh. Reduced Effects mempertahankan hit timing dan target dengan segmen/partikel lebih sedikit.

## Bukti wajib sebelum dianggap selesai
Uji target bergerak, target mati di tengah pengejaran, ancaman lebih dekat, boss sendirian, gerombolan dan Continue. Bandingkan real applied damage level awal/akhir dengan senjata lama dan beberapa weapon pembanding; check hitbox/VFX, tempo floor, proc dan batas node/partikel. Implementasi hanya setelah user menerima rancangan ini.
