# Jade Ascendant — aura dan prioritas perbaikan fitur

Tanggal: 28 Oktober 2026.

Pendapat gue: fondasi game ini sudah cukup lengkap. Rasa yang perlu kita kuatkan adalah **bertarung enak, memahami pilihan build, lalu punya tujuan yang jelas setelah kembali ke menu**. Penambahan fitur berikutnya sebaiknya membantu tiga hal itu.

Audit ini membaca source `057ed76f186940374d2cabe1ecb307a0114d3106` dan paket Paviliun yang pengguna konfirmasikan sudah terpasang serta lulus QA Windows. Penilaian rasa di bawah merupakan pertimbangan developer dari alur dan implementasi; ini belum menjadi hasil playtest Android menyeluruh, studi retensi, atau pengukuran FPS HP. Status operasional event/server tidak ditebak dari keberadaan kodenya.

## Aura yang diperbaiki dalam batch ini

| Aura | Identitas baru |
|---|---|
| Shrinekeeper | Daun teratai giok dan filamen energi yang naik di sisi tubuh. |
| Sovereign | Lengkungan emas dan mahkota kecil dengan cahaya yang tenang. |
| Astral Crown | Tujuh bintang dan orbit yang mengitari tubuh. |
| Jade Ascendant | Dua aliran qi, mahkota teratai dan aksen emas. |

Model geometri dipakai bersama oleh player dan preview. Preview memakai animasi idle asli beserta durasi setiap frame, transform body produksi dan material body yang sudah ada. Efek tampil di belakang tubuh; aura tetap kosmetik. Mode hemat mempertahankan bentuk yang dapat dibedakan tanpa animasi aura terus-menerus. Harga, syarat, kepemilikan, stat, collision, summon, save dan pembayaran tidak diubah.

## Tiga temuan source yang paling konkret

1. **Bahasa belum seragam.** `refine_onboarding.gd:63` menulis judul dan penjelasan berbahasa Indonesia langsung. `hero_unified_screen.gd:530` juga memuat beberapa keterangan campuran; `heavenly_trials_screen.gd:115` memuat penjelasan Inggris dinamis. Sejumlah string ini tidak ditemukan dalam katalog lokalisasi yang diperiksa. Kita perlu memeriksa lookup dan tampilan kedua locale, lalu mendaftarkan teks dengan pola terjemahan yang konsisten.
2. **Pemilihan Daily Quest belum membaca progres.** `daily_quest_manager.gd:523` mengambil dua quest per kategori melalui hash tanggal. Pool mencakup level 12 dan empat clear stage. Ini bukan bukti quest mustahil, tetapi pemain awal dan pemain akhir dapat menerima beban yang sama. Perbaikannya: syarat kelayakan berdasarkan progres, sambil mempertahankan kestabilan pilihan per hari dan aturan grant.
3. **Panduan sudah informatif, jalur tindakan masih dapat dipersingkat.** Detail equipment di Library (`skill_book_screen.gd:146`) menjelaskan unlock dan cara perolehan melalui teks. Arena latihan memakai skill produksi, pilihan Lv.1/3/5/7 dan target bergerak (`training_ground.gd`). Tombol demo khusus di detail Hero saat ini terbatas pada Binding dan Glaive (`hero_unified_screen.gd:557`). Kita dapat menghubungkan item/build ke fitur yang sudah ada dengan konteks yang jelas, tanpa melakukan spend atau equip otomatis.

## Cakupan seluruh fitur

P0 berarti bukti HP yang perlu diprioritaskan; bukan pernyataan ada bug. P1 adalah calon batch perbaikan berikutnya. P2 adalah pengembangan setelah alur inti terasa baik.

| Fitur | Yang sudah ada dan perlu dipertahankan | Masukan dan hasil yang dituju | Urutan |
|---|---|---|---|
| Combat dan kontrol | Auto-attack, joystick, weapon produksi, batas cooldown dan laporan damage. | Uji pelepasan jempol, pause/Continue dan perpindahan arah saat layar ramai. Gerak serta serangan harus tetap terasa dapat diprediksi. | P0 |
| Enemy dan boss | Sprite per chapter, pola serangan, peringatan dan hit-test yang berbagi geometri. | Cocokkan peringatan, momen hit dan ruang menghindar pada HP dengan build penuh. Perbaiki keterbacaan berdasarkan bukti, lalu nilai kebutuhan perubahan difficulty. | P0 |
| Kinerja dan kenyamanan | Preset Battery/Balanced/Premium, pembatas efek dan FPS. | Ukur frame-time, panas dan input pada wave sepi, wave padat dan boss. Uji efek aura bersama set/cultivation. Label preset mengikuti efek yang benar-benar berkurang. | P0 |
| Onboarding dan bahasa | Panduan setelah 1-1, penjelasan bintang/level weapon, hint unlock. | Rapikan dua bahasa dan pendekkan instruksi menjadi tindakan yang relevan saat pemain membutuhkannya. Jangan menambah rangkaian popup baru. | P1 |
| Home dan arah pemain | Continue/recovery lebih dulu; kartu chapter memiliki kontrak PILIH BAB yang stabil. | Beri akses sekunder ringkas ke tujuan lanjutan: hadiah siap, mastery atau koleksi. Pertahankan tombol utama dan prioritas Continue. | P1 |
| Journey dan chapter | Stage authored, syarat unlock, preview reward dan rekor pribadi. | Buat pencapaian berikutnya mudah terbaca: syarat, hadiah dan tujuan replay. Cerita transisi chapter bisa dikembangkan lewat aset/lore yang sudah ada. | P1/P2 |
| Hero, equipment dan preset | Perbandingan gear, bonus set empat bagian, weapon independen, preset build. | Hubungkan detail item ke asal barang dan uji build; tampilkan dampak yang relevan tanpa menyamakan angka stat dengan DPS. Preset yang sudah ada tidak perlu dibangun ulang. | P1 |
| Skill dan upgrade selama run | Refinement, pilihan berbobot serta evaluasi cooldown/cap. | Seragamkan penjelasan manfaat setiap pilihan pada level sekarang. Bandingkan perilaku serangan dan kondisi pasif, termasuk saat cap tercapai. | P1 |
| Cultivation dan mastery | Tiga jalur permanen, pilihan mastery dan Golden Core trial. | Tampilkan milestone yang sedang dikejar dan alasan memilih cabang. Manfaat pilihan harus dapat dihubungkan ke gaya main, dengan kurva harga/stat yang tetap sampai ada bukti balance. | P1 |
| Arena latihan dan Library | Panduan set/weapon, dummy bergerak, skill produksi dan laporan uji. | Buat jalur dari build ke latihan lebih pendek. Cantumkan tipe target serta kondisi pengukuran; target HP sangat besar saat ini tidak mewakili semua matchup boss. Tambahkan skenario uji bertahap. | P1 |
| Summon, target dan pity | Mode earned/paid terpisah, biaya tepat, Fate, reveal dan riwayat. | Pertahankan hasil yang mudah ditindaklanjuti. Perjelas perbedaan target koleksi, Wish target dan jaminan rarity di semua pintu masuk, memakai sumber data yang sama. | P1 |
| Tempa dan ekonomi | Pembelian/tempa berbasis Batu Roh; harga dan syarat produksi yang sudah ada. | Jelaskan bahwa tempa saat ini memperoleh item yang belum dimiliki; bintang membutuhkan duplikat identik. Jalur farming perlu terbaca sebelum mempertimbangkan rebalance. | P1 |
| Aura dan identitas visual | Empat kosmetik dan pilihan plain, biaya/unlock yang terpisah dari combat. | Polish bentuk dan gerak selesai di source batch ini. Berikutnya cek skala, kontras dan tumpukan efek di HP; thumbnail/copy harus sesuai efek aktual. | Sekarang/P0 |
| Daily Quest, achievement dan reward | Rotasi harian, claim-all, siklus hari aktif dan presenter receipt. | Sesuaikan kelayakan quest dengan progres dan ukur waktu menyelesaikan satu sesi. Buat reward siap klaim jelas, dengan dot yang berarti dan proses grant yang tetap aman. | P1 |
| Idle/meditasi | Akumulasi berbatas, preview hasil dan klaim atomik. | Kaitkan hasil yang akan diklaim dengan target upgrade pemain. Batas akumulasi dan waktu tersedia perlu terbaca tanpa menambah mata uang baru. | P2 |
| Heavenly Trials dan endgame | Weekly session, tema/modifier, tiga tier dan hadiah yang ditangani server. | Gunakan variasi aturan yang sudah ada. Tunjukkan tujuan dan cara menghadapi tema sebelum masuk, lalu satu target perbaikan setelah selesai. Aktivasi rotasi tetap proses operasional tersendiri. | P2 |
| Event, Boss Hunt dan Odyssey | Hub event, progres milestone, agenda, Mail dan klaim yang terverifikasi. | Buat satu tujuan event yang paling relevan menonjol: progres, hadiah berikutnya dan deadline. Uji jalur milestone-ke-Mail sampai item terpakai. Hindari menambah mode serupa sebelum loop ini jelas. | P2 |
| Akun, save dan recovery | Isolasi akun, pending-command recovery, Continue dan backup. | Uji koneksi terputus, restart dan pindah perangkat dengan skenario terarah. Pesan harus menjelaskan tindakan berikutnya sambil menjaga checkpoint dan ledger. | P0 |
| Iklan dan pembelian | Iklan opsional, harga Play, grant terverifikasi dan sembilan gate produksi. | Jaga alasan tombol nonaktif tetap spesifik: koneksi, kuota, cooldown atau saldo. Perubahan harga/promo membutuhkan audit ekonomi tersendiri. | Pertahankan/P2 |
| Audio, UI dan aksesibilitas | Routing suara, ducking/cue, kontrol volume, tema dan touch-scroll bersama. | Perkuat perbedaan dinamika boss terhadap Journey dengan cue yang sudah ada. Uji keterdengaran peringatan, ukuran teks, kontras dan reduced effects pada layar kecil. | P2 |
| Hasil run dan replay | Damage ledger, review defeat/victory, rekor dan jurnal run. | Jadikan laporan memberi satu langkah perbaikan yang didukung data run. Data penyebab pukulan yang belum tercatat harus tetap dinyatakan tidak diketahui. | P1 |

## Urutan batch yang gue pilih

**Batch berikutnya: kejelasan progres.** Rapikan lokalisasi onboarding/Hero/Trials, kelayakan Daily Quest untuk progres awal, serta jalur Library/Hero menuju perolehan item dan latihan. Ini memberi manfaat yang langsung terasa tanpa menambah beban sistem combat.

**Sesudahnya: rasa bertarung di HP.** Ambil bukti dari tiga kondisi beban, lalu perbaiki bagian telegraph, kontrol, suara atau tumpukan efek yang benar-benar bermasalah. Gunakan laporan run dan latihan yang sudah ada untuk menguji perubahan. Jangan menetapkan buff/nerf merata dari kesan source saja.

**Berikutnya: alasan kembali bermain.** Kembangkan rotasi Trials/event yang tersedia, target mastery/koleksi dan presentasi pencapaian chapter. Nilai hasilnya dengan sesi pemain nyata. Leaderboard, mode baru atau sistem mata uang baru belum menjadi prioritas dari audit ini.

## Batas implementasi dan validasi

Batch ini hanya mengubah presentasi aura serta preview dan menambahkan QA/checkpoint/audit. Fitur lain pada tabel adalah usulan, belum dikerjakan. Tidak ada native bridge, SDK, manifest Android, backend, harga, reward, saldo, stat atau sembilan gate pembayaran yang diubah.

Model aura lulus 50 pemeriksaan Godot terisolasi: bentuk berbeda, triangulasi polygon, batas area, siklus, reuse buffer, mode hemat, kepemilikan, pause saat tersembunyi dan transform preview. Angka itu bukan bukti render GPU atau FPS Android. Pratinjau video memakai geometri yang diekspor langsung dari model produksi; antialiasing Canvas dan body shader dapat berbeda dari native Godot. QA Windows baru dan tes HP untuk batch aura masih tahap terpisah dari PASS Paviliun yang sebelumnya dilaporkan pengguna.

## Referensi metode

- Source fitur yang dirujuk di atas, `player_journal.gd`, `player_goal_catalog.gd`, `idle_cultivation_manager.gd`, `realm_boss_telegraph.gd`, `audio_manager.gd`, dan `settings_manager.gd`.
- Audit lama `PLAYER_JOURNEY_AUDIT_2026-10-22.md` dan `PLAYER_DIRECTION_AUDIT_2026-10-21.md` dipakai untuk mengenali pekerjaan yang sudah selesai, bukan mengulang batch.
- Android UX: https://developer.android.com/quality/user-experience
- Android game power/performance: https://developer.android.com/games/optimize/power
- Godot CanvasItem drawing lifecycle: https://docs.godotengine.org/en/stable/classes/class_canvasitem.html
