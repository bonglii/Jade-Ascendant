# Jade Ascendant — audit cleaning menyeluruh, 3 November 2026

Audit memakai source GitHub dbe1c73422f431dce9234aa29efc3374b17a13e8 sesudah batch menu/player. Owner melaporkan sudah menjalankan apply/check CMD. Audit ini tidak mengakses drive Windows owner; pemindai lokal disertakan untuk file tambahan di PC.

Source cleanup: https://github.com/bonglii/Jade-Ascendant/tree/work/repo-cleanup-20261103

## Hasil utama

4.762 file sekitar 513,4 MB diinventarisasi; aset sekitar 493,4 MB. Audit memeriksa hash duplikat, literal path, UID Godot, class_name, relative plugin paths, pola path dinamis, exclusion export, sumber QA/CI, metadata native dan kandidat tanpa consumer yang diketahui. Label kandidat bukan izin penghapusan.

| Kelompok | Keputusan dan alasan |
|---|---|
| Dua pasangan PNG identik | Empat file (dua PNG + dua metadata import) dirapikan, 5.099.298 byte dari working tree. Pixel dan parameter import canonical identik. |
| QA source: 429 file, sekitar 1,48 MB | Dipertahankan: fixture regresi dan launcher/CI. Sudah dikecualikan dari export Android. |
| Bukti QA: 19 log sekitar 608 KB | Dipertahankan untuk provenance/checkpoint/recovery; docs juga sudah dikecualikan dari export. |
| Master art: 17 gambar, 33.857.711 byte | Dipertahankan untuk repacking/editing; lima folder source sudah memakai Godot ignore. Nama sources tidak berarti sampah. |
| SDK/vendor | Dipertahankan, termasuk komponen yang dipanggil lewat global class registry/editor. AdMob hold tidak menghapus kebutuhan menjaga SDK. |
| Kandidat aset unik/legacy/held | Dicatat per file dalam audit JSON; tidak dihapus otomatis. Aura yang ditahan dan referensi karakter lama tetap. |
| Empat kelompok duplikat lain, 37.679 byte berlebih | Dipertahankan: halaman privacy/account deletion pada lokasi publishing berbeda serta konfigurasi Gradle/SDK. |
| Cache, save, backup, receipt, recovery, signing dan build Android | Tidak dihapus. Pemindai lokal hanya menghitung metadata ignored roots dan melabeli file lokal; tidak membaca isi cache/signing untuk cleanup. |

## Perubahan tepat

1. Hapus salinan lama assets/ui/main_menu/home_celestial_realm_bg.png dan metadata import-nya. Tidak ada consumer runtime/UID yang ditemukan; gambar identik tetap ada di assets/ui/cultivation/cultivation_celestial_realm_bg.png.
2. Hapus salinan assets/ui/liveops/treasury_production/treasury_window_frame.png dan metadata import-nya. Treasury dialihkan ke assets/ui/liveops/mail/spirit_messages_jade_frame.png yang identik byte dan parameter import.
3. Tambahkan ignore bytecode Python agar hasil pengujian pengembang tidak menjadi source baru. Source test tetap dipertahankan.
4. Tambahkan audit referensi pengembang dan paket PowerShell Windows tanpa Python/Node. Audit default hanya membaca; apply dibatasi empat file tersebut, satu referensi Treasury, dan ignore Python. Tidak ada operasi git clean/reset/force-push atau pemangkasan histori.

Git history tetap menyimpan original. Backup saat apply juga tetap menyimpan byte asli, jadi 5,1 MB bukan klaim pengurangan total disk atau AAB. Tidak export, rebuild native, deploy, mengganti versi release atau mengaktifkan iklan.

## Validasi

- Identitas PNG dan parameter import dibandingkan sebelum konsolidasi; canonical images tidak berubah.
- Godot 4.7.2 exact binary yang sama, fresh import dan 8 resource/scene assertions: PASS, tanpa SCRIPT ERROR/ERROR. Home, Cultivate, Mail dan Treasury benar-benar dimuat pada userdata QA sementara. Ini headless dependency smoke, bukan native GUI/phone baru. Review 243 capture dan QA gameplay 341 yang input-nya tetap digunakan kembali.
- Fixture parser referensi: 11 assertions mencakup UID, class_name SDK, format dinamis, listing direktori, ignored source master dan audit tanpa penghapusan.
- 10 skenario inti PowerShell Linux: audit tanpa tulisan, apply/restore/repeat, CRLF+BOM, aset diedit, source baru, export aktif, native mismatch, payload rusak, rollback edit bersamaan dan konflik saat restore: PASS. Final read-only audit juga PASS, SOURCE_WRITES=0. Guard tambahan membatasi manifest ke empat removal/two update yang direview dan mengunci 52 input/candidate R2; manifest yang mencoba target protected atau proof kosong ditolak. Windows owner belum diuji author.
- Seluruh 52 input native dan candidate AAR cocok; hash candidate tetap 2171f13f36cf8d90988fd20248f879653104625c8481b91d3fb0a4303fb098ea. SDK, sembilan gate pembayaran dan AdMob hold tetap.

## Pakai di PC owner

Ekstrak paket ke folder baru. Jalankan audit_cleanup.cmd saat ingin melihat daftar file lokal tambahan. Hasil LOCAL_AUDIT.json memuat inventory, duplikat, file untracked, metadata ignored roots, status native, dan source yang berbeda dari snapshot yang direview. Tidak ada source yang ditulis pada mode ini.

apply_cleanup.cmd hanya untuk cleanup terbatas di atas, setelah Godot ditutup dan exporter existing selesai memulihkan bridge. Pemeriksaan 800 file source runtime, native, preimage dan payload harus cocok sebelum tulisan pertama. Source baru/diedit atau PNG berubah menghentikan operasi; pertahankan edit tersebut untuk review.

Backup byte asli dan APPLY_RECEIPT.json ada di results dalam folder paket. restore_cleanup.cmd dengan path receipt pertama memulihkan originals dan menolak menimpa edit baru. Apply dan restore dapat diulang. Jangan memasang ulang paket menu lama sesudah cleanup tanpa restore dahulu.

AAB yang sedang ditunggu dan branch menu/player sebelumnya tetap terpisah. Pemasangan cleanup Windows dan hasil HP tetap berdasarkan log owner berikutnya. Pemeriksaan exact-SHA CI dan pengiriman paket dicatat dalam delivery receipt.
