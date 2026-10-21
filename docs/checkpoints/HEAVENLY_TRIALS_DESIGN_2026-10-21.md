# Heavenly Trials — rancangan dan preview

Status: konsep visual dan sistem untuk ditinjau; belum dipasang, diuji sebagai gameplay baru, dipush, atau diaktifkan di server. Persetujuan user pada 21 Oktober 2026 membuka kembali scope desain tantangan mingguan yang sebelumnya dijeda. Implementasi mengikuti peninjauan preview ini.

## Tujuan dan posisi

Heavenly Ladder yang sudah ada mencatat milestone clear campaign satu kali. Heavenly Trials menyediakan tantangan combat yang berulang setiap minggu, memakai kontrol gerak, auto attack, Lin Yue, weapon/build dan boss 2D yang sudah ada. Letaknya di Celestial Events, bukan mengganti Daily Trials, Heavenly Ladder, Dragon Odyssey atau Personal Combat Records.

Source yang diperiksa: working agreement/continuity; katalog chapter1/3 dan profil boss5 realm; SpriteFrames/atlas boss 2D dan Lin Yue; event identity, Heavenly Ladder, ekonomi/pity/cadence dan mekanisme event/reward existing. Grounding memakai source pada commit227cedb dan pekerjaan Stage Records yang sudah dikemas; pemasangan/push Stage Records di PC belum dikonfirmasi oleh output user. Art preview adalah konsep, bukan screenshot game yang sudah berjalan.

## Alur pemain

Celestial Events > Heavenly Trials > pilih tingkat > lihat aturan singkat dan reward > mulai sesi > selesaikan combat/boss > ringkasan hasil + klaim > opsional bonus iklan atau coba lagi untuk memperbaiki rekor.

- Syarat masuk: clear1-5. Masuk gratis, percobaan tidak dibatasi; tidak menambah tiket/dadu/stamina baru.
- Foundation: terbuka setelah clear1-5.
- Tempering: terbuka setelah clear2-5.
- Ascension: terbuka setelah clear3-5.
- Tier memakai pool boss yang sesuai progres, dipilih dari preset yang tersedia. Pemain baru tidak dipaksa melawan boss realm yang belum terbuka untuk memperoleh hadiah Foundation.
- Target durasi desain2–3 menit per percobaan; ini belum hasil ukur. Wave/level-up/boss timing dan loadout harus ditentukan melalui probe combat sebelum implementasi dianggap selesai. Tidak menjanjikan stage campaign existing otomatis berdurasi2–3 menit.
- Arena membatasi lari dari boss tetapi tetap menyediakan area aman untuk menghindari telegraph. Gerak/auto attack tetap sesuai game. Ikon skill dalam mockup adalah indikator, bukan keputusan menambahkan tombol attack manual.
- Clear memberi hadiah mingguan. Survivor (tanpa mati/revive) dan Untouched (tanpa HP berkurang) adalah target mastery kosmetik/rekor; bukan syarat hadiah dasar. Shield block tidak sama dengan HP damage.
- Tidak menjual skor, medali, kelulusan, atau akses percobaan tambahan. Equipment/permanent progression tetap berpengaruh sesuai sistem game; ini bukan janji kompetisi dengan stat yang disetarakan.

## Rotasi berulang

Default: reset Senin04:00 WIB (Minggu21:00 UTC), dihitung server. Dashboard menampilkan tanggal lokal, timezone dan UTC dengan jelas. Jam perangkat tidak menentukan pergantian minggu.

Pool tema awal yang diusulkan:

| Tema | Aturan arena utama | Cara melawan |
|---|---|---|
| Jade Wind | Jalur angin diberi tanda sebelum dilepas | Pindah ke sisi aman sebelum sapuan |
| Scarlet Rite | Burst serangan berfase dengan jeda yang jelas | Hindari burst, serang pada recovery |
| Starfall | Titik petir ditandai sebelum jatuh | Bergerak keluar marker, hindari tumpukan efek |
| Froststep | Zona dingin terbatas, area aman tetap terbuka | Pilih rute tanpa mengunci gerak pemain |
| Sunforge | Gelombang arena dengan jalur lolos yang terbaca | Pindah jalur mengikuti timing gelombang |

Satu aturan utama per minggu. Nilai cooldown, jumlah bahaya, HP/damage dan target durasi belum dibakukan; ukur pola serangan real dan tekanan damage pada tiap tier, lalu batasi efek/crowd untuk HP. Tidak menaikkan semua HP sebagai pengganti variasi gameplay. Telegraph harus cocok dengan hitbox, delay dan arah damage. Boss dan Lin Yue tetap memakai animasi/frame existing; tidak mengubahnya menjadi 3D/isometric RPG.

Preset/config mempunyai ID dan versi yang tetap untuk satu minggu. Admin bisa menjadwalkan rotasi otomatis; perubahan konfigurasi tidak boleh menukar aturan/reward sesi yang sudah dimulai. Minggu baru punya ID berbeda, sehingga klaim lama tidak bisa diputar ulang untuk hadiah baru.

## Budget reward awal — usulan, belum ekonomi produksi

| Tingkat | Celestial Jade | Pavilion Seal | Spirit Stone |
|---|---:|---:|---:|
| Foundation |40|1|600|
| Tempering |40|1|600|
| Ascension |40|1|600|
| Batas akun per minggu |120|3|1.800|

Hadiah sekali per tier per minggu. Rekor/perfect run tidak mengulang hadiah. Harga single pull existing100 Jade dan900 untuk10 pulls; jumlah di atas adalah budget, bukan jaminan jumlah/rarity hasil summon. Benchmark cadence existing: daily-completion20 Jade dan bonus7 active days160 Jade +4 Seal. Sumber lain seperti login/event/iklan harus ikut simulasi total sebelum budget diterapkan. Jangan menjanjikan perolehan kalender tertentu atau memutuskan budget hanya dari satu sumber pendapatan.

Foundation tetap memberi40 Jade +1 Seal +600 Stone kepada pemain eligible yang menang. Semua tier membutuhkan kemenangan; ini bukan login grant. Hadiah earned Jade tetap terpisah dari saldo purchased Jade.

## Monetisasi konsisten dengan event board

### Bonus iklan opsional

- Placement dan unit terpisah: calon nama `Rewarded_Heavenly_Trials`. Belum dibuat/dikonfigurasi; jangan menumpang Dice/Pavilion jika mengaburkan laporan placement.
- Satu bonus Stone per klaim tier, maksimum3 per akun per minggu.
- Base claim tidak menunggu iklan. Setelah base reward benar-benar diberikan, opsional ad memberi tambahan600 Stone untuk tier itu. Jadi Stone tier menjadi1.200; Jade dan Seal tetap.
- Batas penuh dengan3 bonus:120 Jade +3 Seal +3.600 Stone. Ini angka desain; tetap memerlukan audit ekonomi gabungan.
- Preload saat startup/idle event tanpa menampilkan iklan otomatis. Status eksplisit: loading, ready, verifying, granted, unavailable. Hanya tampilkan GRANTED setelah konfirmasi reward.
- Hadiah menunggu callback/SSV sesuai kontrak yang dipilih. Reopen/app kill/timeout harus memulihkan verifikasi nonce yang sama; tidak menyuruh pemain menonton ulang untuk callback yang terlambat. Tidak mengarang cap durasi/jumlah materi iklan yang ditayangkan AdMob.

### Event Shop / Trial Support Pack

- Tombol EVENT SHOP membuka toko milik event. Item/payload di kiri, harga lokal Google Play dan tombol beli di kanan. Pembelian langsung dari baris paket, tidak memindahkan pemain ke Treasury untuk memilih produk lain.
- Paket draft:550 Jade +2 Pavilion Seal, maksimum1 pembelian akun/minggu. Dedicated consumable SKU dan harga ditentukan saat konfigurasi Play Console, bukan mengarang harga Rp75rb/89rb di source atau mockup.
- Reward pack tidak memberi clear, medali, skor, atau percobaan yang tak dimiliki pemain gratis. Pemain tetap menjalani tantangan yang sama.
- Produk/offer ID, konten, batas dan eligibility dibekukan saat checkout. Receipt server yang sama hanya dikreditkan sekali. Pembatalan/decline segera melepas status checkout saat hasil pembatalan sudah pasti; pending/reconciliation harus punya status jelas dan tidak memblokir seluruh UI tanpa batas.
- Jika pembayaran valid selesai setelah minggu berganti, konten berbayar tetap wajib dikirim menurut offer yang dibeli. Jangan menolak barang yang sudah dibayar hanya karena event berakhir. Refund/void/hold existing tetap berlaku pada Jade dan bonus terkait.
- Saldo paid/local, Play/App Check/auth, restore/dedup dan proteksi refund yang sudah live tidak boleh dilemahkan. SKU dan unit iklan baru memang memerlukan konfigurasi akun pemilik; ditangani setelah kode/paket implementasi siap, tanpa meminta rahasia di chat.

## UI / UX / VFX

Preview menunjukkan3 kondisi: hub mingguan, combat boss, dan hasil/klaim. Emerald/jade + gold, scenic artwork terbaca, rounded cards, tombol embossed, red dot klaim dan headline singkat. Menu tidak diganti menjadi deretan paragraf panjang. Banner cukup ringkas agar tiga tier dan CTA jelas; konten tambahan dapat discroll dengan shared mobile policy.

- Satu CTA utama ENTER TRIAL. Tier locked menjelaskan syarat. Misi/rewards/shop/popup tidak bisa ditumpuk dengan spam tap.
- Hub memakai ringkasan cache yang valid untuk first paint. Sesi/auth/preset diprewarm saat startup. Claim, retry dan background refresh tidak memudarkan seluruh tombol berkali-kali atau mengulang sign-in setiap aksi.
- Claim All untuk reward earned yang tersedia; satu ringkasan reward agregat, tanpa popup beruntun. Badge hanya untuk hal yang benar-benar dapat diambil/ditindaklanjuti, bukan memaksa kunjungan ke toko atau tontonan.
- Badge konsisten dari Home > Celestial Events > Heavenly Trials > Rewards. Hilang setelah claim terkonfirmasi, tidak hilang hanya karena layar dibuka.
- Event kedaluwarsa berhenti menerima sesi baru. Earned reward yang belum diambil mendapat grace48 jam; setelahnya diselesaikan lewat satu pengiriman mailbox agregat dengan kunci idempotensi. Tidak menghasilkan surat/gift harian tanpa alasan.
- Card featured Home menghilang ketika weekly core selesai/claimed, atau tidak ada lagi aksi eligible. Akses replay/rekor dan shop yang masih valid tetap tersedia lewat daftar event sesuai filter status, tanpa dot palsu. Penanganan detail archive/completed harus konsisten dengan kebijakan visibility existing.
- Visual: gate aktif perlahan, tier terpilih mendapat halo tipis, transisi medan singkat, warning telegraph berniat jelas, medali menyala berurutan setelah hasil final. Reduced effects mempertahankan telegraph, melepas partikel dekoratif.
- Aset/spine layout harus dibaca di320/390, safe area kamera HP, font/border konsisten, tidak ada scrollbar tampak atau matte hitam keras. Gambar di dalam border di-clip dan tidak mengembang minimum width.

## Dashboard

Satu panel Heavenly Trials: status Draft / Scheduled / Live / Grace / Ended, kalender lokal +UTC, rotasi mingguan,3 tier, allowlist boss/rule, preview reward dan budget mingguan. Preview sebagai pemain sebelum publish; audit log versioned; pause entry dengan alasan, jangan mematikan kredit pembelian yang sudah sah. Jadwal tidak auto-live hanya karena deploy.

Bisa mengatur tema, boss, aturan dari preset, reward, grace, eligibility dan offer yang sudah dikenali client. Tidak mengirim arbitrary script/assets lewat config. Rotasi aset/mekanik yang sudah tersedia tidak perlu AAB baru; penambahan rule, mekanik, art atau SKU client yang belum didukung memerlukan update yang sesuai.

## Batas authority / keselamatan progres

- Personal Stage Records hanya statistik. Jangan mengubahnya menjadi bukti tunggal untuk mencetak hadiah mingguan server.
- Backend memiliki week ID, config version, entitlement sesi dan kunci reward/account/week/tier. Claim harus idempotent, bounded dan terkait sesi yang diterima. Sesi/reward tidak boleh digandakan dengan account switch, device kedua, request replay atau reconnect.
- Jangan mengklaim server sudah menyimulasikan semua combat atau membuktikan zero-hit dari laporan client. Batas validasi combat dan trust model harus diaudit saat implementasi; medali personal bukan leaderboard dengan anti-cheat kompetitif.
- Kontrak reward mengikuti jalur server delivery yang sesuai untuk earned currency, tidak menulis sendiri paid wallet. Operasi perubahan save memiliki rollback/commit boundary jelas.
- Aktif campaign checkpoint tidak dihapus diam-diam untuk membuka Trials. Tentukan resume/cancel/isolasi session state sebelum entry; Continue trial harus tetap memakai config snapshot yang sama. Tidak mencampur clear reward mingguan dengan first-clear campaign.

## Rencana implementasi setelah preview ditinjau

1. Bekukan desain scope; catat keputusan dan audit biaya/tempo/reward.
2. Client sesi trial, UI/event card/red dots + shared scroll, actual boss arena/rule, report dan Continue.
3. Backend config/schedule/session/reward ledger + delivery idempotent; dashboard kontrol dan audit.
4. Optional ad placement + direct event pack; protections tetap. Konfigurasi unit/SKU pemilik menyusul sesudah hasil konkret siap.
5. Validasi terarah: real combat hitbox/telegraph/crowd, save/restart/rollover/double claim/account switch, ad late SSV, cancel/pending/purchase/refund boundaries, all UI narrow/swipe and actual render. Reuse bukti unchanged.
6. Satu paket Windows dengan hash, backup, resumable QA/publish/deploy/export yang tidak bergantung folder unduhan lama. URL commit nyata hanya setelah push. Main tetap tidak diubah.

## Catatan kontinuitas

Tidak ada implementasi Heavenly Trials di source game dalam pekerjaan preview ini. Stage Records tetap batch terpisah yang sudah dikemas, bukan sesuatu yang perlu dikerjakan ulang. Source/aset existing sudah diinspeksi sebelum konsep dibuat. Desain tambahan event/weekly kini sudah diminta user, menggantikan status scope desain yang sebelumnya parked; aktivasi server belum terjadi.
