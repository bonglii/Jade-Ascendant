# Jade Ascendant — batch pemain 1–7

Base `057ed76f186940374d2cabe1ecb307a0114d3106`, branch author `work/player-followup-1-7-20261026`. Implementasi client selesai dan QA lokal lulus. Pemeriksaan HP pada nomor 7 belum dilakukan; nomor 8–10 tetap diparkir sampai batch ini ditutup.

| No. | Hasil implementasi | Bukti lokal |
|---|---|---|
| 1 | Penulis checkpoint menolak save setelah Victory; callback pause/EXP terlambat tidak membuka lagi run selesai. Continue run belum selesai tetap bekerja. | Boss produksi benar-benar di-spawn/dikalahkan; dua writer ditolak, reward tetap sekali, Home tidak menawarkan Continue. |
| 2 | Home, Journey, cache, achievement dan Heavenly Ladder memakai 25 stage aktif. Chapter pertama /5; achievement realm dan summit dapat dicapai. | Canonical 26 termasuk 1-6 tetap tersimpan; achievement legacy yang sudah earned tetap terlihat/claimable. Harga dan nilai reward tidak diubah. |
| 3 | Guide membaca backpack dan kemampuan membeli Cultivation. Backpack kosong diarahkan ke aksi yang dapat dilakukan; tutorial equipment masih tersedia saat item pertama datang. | Kosong/mampu/tidak mampu, kedua bahasa, flag sekali tampil dan geometri 320×568 diperiksa. Tidak ada item gratis/spend dari panduan. |
| 4 | HERO/detail/harga/filter/slot, guide dan judul receipt mengikuti en/id. Format diterjemahkan sebelum angka dimasukkan. | Kedua locale dibuka pada scene HERO yang sebenarnya; inventory/balance tetap sama. Nama art/item dipertahankan. |
| 5 | Kartu skill menampilkan peran atau progres syarat sinergi sesuai build; Chain dan Glaive mendapat petunjuk peran yang sesuai. | Syarat memakai SkillCatalog produksi; hint tidak mengubah RNG/pilihan, tidak over-target atau mempromosikan resonance yang sudah diperoleh. |
| 6 | Counter sisa pilihan diperbarui saat EXP berlebih. Combat terus pause antar pilihan; pilihan beruntun melewati intro panjang. | Kurva EXP, heal per level, signal dan restart wounded checkpoint tetap benar; rapid tap dan callback pilihan/iklan lama ditolak. |
| 7 | Pencatat uji Android siap: verifikasi versionCode, checklist, screenshot, log package tersamarkan dan gfxinfo. | Dua parser/redaction test lulus. Belum ada phone/GPU/audio/frame-time/Windows-export PASS. |

QA terisolasi pada Godot 4.7.2: 416 pemeriksaan runtime — follow-up58, full-heal20 + restart4, player-direction53, equipment142 + restart6, stage-records84, Heavenly Trials49. Installer6 dan parser Android2 juga lulus. Kontrak produksi menyatakan `GATES=9`, target existing production.

Runtime exit terakhir bersih dari script errors/resource leaks. Suite yang tidak berubah menggunakan bukti PASS sebelumnya dari batch gabungan ini; hanya regression follow-up yang dijalankan lagi setelah perbaikan hint/generation dan fixture. Proses ini bukan uji pemain manusia atau bukti retensi.

Exit Victory normal baseline sudah benar. Defek yang direproduksi adalah **save checkpoint eksplisit yang terlambat setelah Victory**, yang sebelumnya menghidupkan kembali Continue. Guard menutup kedua jalur writer tanpa menebak bahwa semua checkpoint stage yang sudah pernah menang harus dibuang. Tidak ada migrasi yang menghapus save lama secara heuristik.

ZIP diekstrak dan dipasang pada clone terpisah: 29 file cocok hash manifest, pemasangan ulang `CHANGED=0`, main/HEAD, staging owner dan file sentinel konfigurasi tetap. Ini bukti fixture Linux, bukan Windows owner.

Pemasang menggunakan backup dan merge tiga arah. Semua konflik diperiksa sebelum file source ditulis. Pemasangan ulang tidak menimpa edit lain dan memakai receipt QA hanya untuk source serta engine yang sama. Kegagalan/interupsi QA baru membatalkan status PASS saat ini. Source berada di branch kerja pada HEAD yang sama; tidak ada commit, push, deploy, reset, clean, perubahan main, export preset/signing/native AAR atau pembelian otomatis.

Batas akhir: source siap dipasang, tetapi belum terpasang pada komputer owner, belum commit/push/deploy/export, dan belum diuji di Android. Jalankan `apply_and_check.cmd`; setelah build baru terpasang di HP melalui alur rilis biasa, jalankan `android_playtest.cmd`. Lihat `PLAYER_BATCH_1_7_ANDROID_2026-10-26.md` untuk kriteria penutupan nomor 7.
