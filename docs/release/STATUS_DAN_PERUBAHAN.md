# Status implementasi dan perubahan

Build `JA-RELEASE-CANDIDATE-20260909`. Baseline pembanding: sumber `jade-ascendant(5).zip`. Paket merupakan overlay kumulatif file baru/pengganti lengkap. Identitas stage 1-1…1-5, enam jurus, empat item awal, empat slot, dan domain save lama tetap digunakan.

## Status roadmap

| Phase | Hasil dalam paket | Batas yang tersisa |
|---|---|---|
| 0 — Audit/harness | Perbaikan validasi checkpoint, proteksi versi, jalur Continue, alat pemeriksaan terisolasi | Runtime Godot belum dijalankan di lingkungan ini |
| 1 — Tema | Tiga aset Qi/weapon pengganti; blade/jian sesuai wuxia; aset legacy tak terpakai dikecualikan dari export | Audit tampilan pada perangkat |
| 2 — Animasi | Idle breathing, gestur serangan, hurt feedback, ghost/death fade pada frame aktor yang ada | **Bukan** spritesheet baru dengan 6 frame attack / 3 frame hurt / 6 frame death untuk semua karakter; target frame-by-frame penuh masih terbuka |
| 3 — Combat | MAX 7 enam jurus, arc petir, rune Fire Orb, trail jian, formasi trigram, telegraph, pickup magnet, feedback terbatas | Timing, keterbacaan, resonance dan balance perlu playtest; tidak ada hit-stop baru |
| 4 — Audio | 3 loop musik 64 detik; 16 SFX; crossfade, mixer, voice budget, pause background | Belum ada listening test/runtime audio |
| 5 — Chapter 1 | Lima scene trial, komposisi musuh, boss profile, hazard, dekor/thumbnail masing-masing | Boss memakai atlas karakter yang sama dengan varian perilaku; bukan lima spritesheet boss baru |
| 6 — Ekonomi | 16 item, konversi duplikat, 14 achievement, 3 dari 9 daily quest, hadiah stage | Angka merupakan rancangan awal, belum hasil balancing pemain |
| 7 — Pavilion | Forge dengan mata uang hasil bermain, meditasi harian, tiga pilihan aura; adapter offline dan debug test provider | **Tidak ada** AdMob/billing/consent SDK, pembelian nyata, backend entitlement atau iklan produksi |
| 8 — UX | Home terpisah, navigasi aktif, safe-area/scroll, volume, efek rendah, shake, FPS, getaran, pilihan EN/ID, privasi/lisensi | 389 pesan inti ID; nama jurus/item/realm dipertahankan. Copy tambahan dan layout kedua bahasa masih perlu QA |
| 9 — Performa | Penyimpanan feedback 96 + 16 arc, 10 voice SFX, magnet/penggabungan XP, cap musuh stage baru, polling terbatasi | Belum ada pengukuran FPS, panas, RAM, ANR, atau benchmark Android |
| 10 — Save/QA | Validasi tipe permanen, backup, jurnal transaksi, klaim dan penutupan run, proteksi hasil menang/kalah berbarengan, smoke tambahan | Simulasi interruption ditulis; proses/perangkat nyata belum diuji |
| 11 — Android | AAB, ARM64, min API 24/target 36, ikon/adaptive/monochrome, build dan signing helper | Publisher values, SDK/templates, keystore, AAB dan pemeriksaan perangkat belum tersedia di lingkungan ini |
| 12 — Play Store | Listing EN/ID, ikon/banner, template privasi, worksheet Data safety, panduan Console/capture | URL belum di-host; screenshot gameplay belum diambil; formulir akun belum diisi |
| 13 — Release gate | Pemeriksaan sumber dan overlay; hasil/batas tercatat | **Belum release PASS**; engine, build, device, dan Play gate masih terbuka |

## Home dan perjalanan

Home menampilkan Lin Yue, ringkasan realm, Continue, Enter Journey, akses daily/achievement, pengaturan, dan navigasi hub. Pilihan stage berada di Journey. Mulai trial baru tetap meminta konfirmasi bila checkpoint ada. Continue mengambil identitas dari checkpoint tervalidasi, sehingga memilih trial lain tidak mengubah sesi yang dilanjutkan.

| ID | Trial | Identitas arena dan encounter |
|---|---|---|
| 1-1 | Verdant Awakening | Lembah Qi, rumput roh, penanda kultivasi; Trial Guardian; tempo lama dipertahankan |
| 1-2 | Bamboo Mist Pass | Bambu dan kabut; penyergap jarak jauh; Mistblade Warden yang lebih bergerak |
| 1-3 | Ruined Jade Shrine | Pilar/kuil rusak, lentera, segel; ward hazard; Jade Shrine Keeper |
| 1-4 | Storm Peak Approach | Batu gelap, obelisk, motif angin; petir bertanda; Stormpeak Herald |
| 1-5 | Sovereign's Celestial Gate | Gerbang/pagoda, segel emas; gelombang campuran; Jade Valley Sovereign dua fase |

Dekor bersifat visual. Hazard memiliki peringatan area sebelum damage dan membersihkan diri. Stage 5 membuka status Chapter Complete tanpa membuat stage 1-6 yang tidak ada. Resource atlas/cropping boss dari baseline dipertahankan; script boss menerima profil baru.

## Perubahan keseimbangan yang disengaja

- Trial 1 tetap 5 detik per wave dengan 100 Batu Roh untuk first/repeat clear. Trial tambahan memiliki wave lebih panjang serta profil boss sendiri; lihat `BALANCE.md`.
- Tiga jurus yang sebelumnya dapat terus naik sekarang berhenti pada Level 7, sama dengan tiga jurus lain. Continue juga membatasi level tersimpan pada batas ini.
- Magnet XP dasar radius 52 ditambahkan; bonus radius dari perlengkapan dibatasi 72. Melebihi 160 pickup menggabungkan nilai ke pickup yang ada sehingga jumlah node dibatasi tanpa membuang XP.
- Item duplikat berubah menjadi Pecahan Pemurnian: common 5, rare 12, epic 30, legendary 75 per salinan tambahan. Item lama yang bertumpuk dinormalisasi menjadi satu item + pecahan, sekali saat load/save. Kepemilikan pertama tetap ada.
- Stage 2–5 memberi item khas pada clear. Setelah dimiliki, hadiah tersebut menjadi pecahan. Preview dan hasil hadiah menunjukkan barang yang diterima setelah konversi.
- Harga forge dan efek tambahan item dicatat eksplisit. Empat item awal serta formula dasar permanent cultivation dipertahankan. Tidak ada pengali damage baru yang menumpuk tanpa batas.

## Penyimpanan dan pemulihan

Tujuh domain lama tetap schema v1. Domain **pavilion** v1 ditambahkan, sehingga sekarang ada **8 domain: 7 permanen dan 1 active-run**. Preferensi perangkat tetap di `settings.cfg`, terpisah dari progres permainan.

Field `active_quest_ids` pada daily bersifat tambahan; save lama mempertahankan tiga quest lamanya untuk hari aktif tersebut. Field terminal `ended` pada checkpoint menandai run yang telah selesai. Identitas `config/name="jade-ascendant"` dipertahankan agar nama folder save desktop tidak berpindah.

RewardManager menulis nilai akhir mata uang/inventori bersama flag klaim terkait atau penutupan Journey/checkpoint melalui jurnal `transaction.journal`. Replay menulis snapshot akhir, bukan menambah hadiah lagi. Pembelian cultivation menyimpan potongan biaya dan kenaikan level dalam satu transaksi. UI menolak memulai run/perubahan perlengkapan ketika pemulihan atau proteksi save permanen aktif.

Jurnal tidak menggunakan backup historis agar transaksi usang tidak diputar ulang di atas progres lebih baru. Save biasa tetap memakai staging, flush, rollback dan backup. Ini bukan jaminan kebal terhadap semua kerusakan storage. Jika muncul pesan recovery yang terus berulang, simpan salinan data dan log; jangan menghapus save untuk menghilangkan pesan. Versi save yang lebih baru memerlukan versi game yang sesuai.

Checkpoint tidak menyimpan seluruh posisi musuh atau HP boss. Continue membangun kembali encounter dari wave/stat pemain yang tersimpan, sehingga boss dapat dimulai lagi dengan HP penuh. Progres nonmilestone dapat tertinggal sekitar interval save terakhir saat proses dihentikan paksa.

## Monetisasi edisi ini

Edisi yang disiapkan adalah **offline tanpa iklan dan pembelian uang nyata**. Pavilion memakai hasil bermain. Harga distribusi aplikasi ditentukan penerbit melalui Play Console.

`MonetizationManager` adalah batas integrasi untuk fase berikutnya. Provider produksi saat ini selalu menyatakan unavailable. Debug provider hanya untuk harness dan dikecualikan dari export. Harness memeriksa callback reward duplikat, pembatalan, timeout, cooldown dan batas per-placement selama proses. Ini belum memenuhi kebutuhan monetisasi nyata: masih perlu SDK, consent, cap persisten, validasi receipt/entitlement, pemulihan pembelian, deklarasi data, serta pengujian produk melalui akun Play.

## File dan penelusuran perubahan

`CHANGE_MANIFEST.json` berisi path serta SHA-256 setiap file pengganti/tambahan, kecuali manifest itu sendiri. `ASSET_PROVENANCE.md` menjelaskan asal aset dan batas pemeriksaannya. ZIP ini tidak menyertakan cache impor, keystore, password, atau seluruh proyek baseline.
