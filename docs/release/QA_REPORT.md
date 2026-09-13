# Laporan pemeriksaan kandidat rilis

Build **JA-RELEASE-CANDIDATE-20260909** · 9 September 2026 · Godot sasaran **4.7.2.stable.official.ed1daf0bf**.

**SOURCE PASS bukan RELEASE PASS.** Executable Godot tidak tersedia di lingkungan pengerjaan. Tidak ada hasil kompilasi GDScript, permainan berjalan, build Android, tanda tangan, atau performa perangkat yang diklaim dari pemeriksaan Python.

## Hasil yang benar-benar dijalankan

| Pemeriksaan | Hasil | Makna / batas |
|---|---|---|
| `tools/validate_release.py` | **PASS, 27/27** | Referensi literal, ID scene/resource, delimiter/fungsi, katalog stage/item, format terjemahan, audio, PNG, preset export |
| `tools/validate_phase0.py --static-only` | **PASS** | Referensi sumber dan resource resolve; engine tidak dijalankan |
| Empat helper Python | **PASS** | `py_compile` dan AST Python; tidak menguji PowerShell/Godot |
| Boss scene dan SpriteFrames | **PASS** | SHA-256 sama dengan ZIP baseline; perubahan cropping/atlas lama tidak tertimpa |
| Adaptive foreground / monochrome | **PASS** | Siluet alpha dalam lingkaran aman pusat; radius terjauh 125,501 / 109,501 dari batas 132 piksel |
| Referensi export | **PASS** | Tidak ada referensi literal produksi ke aset yang dikecualikan |
| Enam wrapper Windows | **PASS sumber** | Mode dan tujuan dispatcher sesuai; belum dijalankan di Windows |
| Deskripsi singkat EN/ID | **PASS** | Masing-masing paling banyak 80 karakter |

Rincian terstruktur ada di `QA_SOURCE_RESULTS.json`. Katalog memuat lima destination trial, 16 item, 389 pesan Indonesia, tiga musik Ogg dan 16 SFX WAV. WAV berisi sample 16-bit tanpa puncak clipping; ini bukan listening test. Banner 1024×500 memakai RGB tanpa alpha; ikon Play 512×512 RGBA di bawah 1 MiB.

Pemeriksa sumber adalah pemindai referensi dan data, **bukan parser GDScript**. Pemeriksaan itu tidak dapat membuktikan tipe/API engine, urutan signal, performa, collision, atau tata letak runtime benar.

## Uji engine yang disiapkan, belum dijalankan

`tests/phase0_smoke.gd` dan launcher terisolasi menyiapkan pemeriksaan berikut:

- Import semua resource/script/scene dan 17 autoload.
- Home → Journey → lima stage, checkpoint, kembali Home, Continue dengan identitas stage, kalah/Retry dan victory/reward.
- Backup checkpoint, legacy v1, tipe field rusak, versi masa depan, terminal checkpoint dan pencegahan reward berulang.
- Rekonstruksi jurnal transaksi yang terputus dan replay idempoten; proteksi perubahan saat recovery.
- Forge dan meditasi, konversi item duplikat, MAX 7 pada enam jurus, katalog achievement/daily.
- Batas penyimpanan feedback, opsi bahasa, settings dan scene hub tambahan.
- Callback reward mock duplikat, cancel dan timeout; provider mock hanya untuk debug.
- Penguncian hasil apabila boss dan pemain mati hampir bersamaan.

Status seluruh kasus engine di atas: **NOT_RUN**. Kode harness adalah alat mencari masalah, bukan bukti bahwa semua asersi telah lewat.

Pada Windows, jalankan `PERIKSA_GAME.bat`. Laporan berada di `artifacts/check-TANGGAL-JAM/`: `import.log`, `smoke.log`, `summary.json`. Launcher membuat proyek sementara dan folder save dengan token unik sebelum engine diimpor. Log harus memuat `JADE_PHASE0_PASS` tanpa error/warning yang ditolak gate. `BUAT_AAB.bat` meminta pemeriksaan baru pada revisi yang dibangun.

## Gate yang masih terbuka

| Gate | Status saat ZIP diserahkan |
|---|---|
| Godot import, parser, runtime smoke | **NOT_RUN** |
| Windows PowerShell / BAT execution | **NOT_RUN** |
| Listening test, UX dua bahasa, seluruh trial dimainkan normal | **NOT_RUN** |
| Export Android / AAB / signature / manifest final | **NOT_RUN** |
| Native ELF 16 KB / APK alignment / perangkat 16 KB | **NOT_RUN** |
| Android device, RAM/FPS/panas/background/ANR | **NOT_RUN** |
| Gameplay screenshot aktual | **NOT_RUN** |
| Identitas penerbit, URL privasi aktif, keystore | **BELUM DIISI PENERBIT** |
| Play Console dan review | **NOT_SUBMITTED** |

Angka FPS 30/60 merupakan pilihan batas frame rate. Itu bukan benchmark. Gunakan `DEVICE_QA.md` untuk mencatat perangkat dan hasil nyata.

## Batas produk yang perlu tetap terlihat

Animasi tambahan memakai transform/efek frame yang ada; spritesheet attack/hurt/death baru lengkap untuk semua aktor belum dibuat. Lima encounter memakai atlas boss yang sama dengan profil perilaku masing-masing. Monetisasi produksi/SDK/receipt/consent belum terintegrasi; edisi ini offline tanpa iklan dan pembelian uang nyata. Rincian roadmap ada di `STATUS_DAN_PERUBAHAN.md`.

Checkpoint memulihkan wave dan stat pemain, bukan posisi seluruh musuh atau HP boss. Autosave awal sekitar 15 detik, selanjutnya 20 detik, serta saat pergantian wave dan background yang memungkinkan; pilihan breakthrough yang terbuka ditunda. Progress counter nonmilestone dapat tertinggal sekitar dua detik. Force-stop dapat kehilangan perubahan sejak snapshot terakhir. Tidak ada cloud save.

Save & Return Home sekarang tetap membuka pause apabila penyimpanan checkpoint gagal, sehingga UI tidak menyatakan save berhasil lalu meninggalkan sesi. Joystick melepas simulated input ketika aplikasi kehilangan fokus/background. Kedua perbaikan ini masih memerlukan uji runtime di perangkat.

## Integritas ZIP

Paket adalah overlay kumulatif **file baru/pengganti lengkap saja** terhadap `jade-ascendant(5).zip`, mencakup perbaikan Phase 0 dan Phase 1. Manifest root `CHANGE_MANIFEST.json` memuat hash baseline dan hash setiap file di dalam ZIP, kecuali manifest itu sendiri. Metadata kemasan tidak menandakan engine PASS.

ZIP diperiksa CRC dan diekstrak di atas salinan baseline untuk mencocokkan isi dengan source kandidat serta menjalankan ulang pemeriksaan sumber. Tidak ada cache impor, private key, password atau APK/AAB yang dimasukkan. Baca `MULAI_DI_SINI.md` untuk cara menerapkannya ke proyek lama.
