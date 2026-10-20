# Jade Mailbox Warm Session — 2026-10-20

## Jalankan satu launcher

Tutup Godot. Ekstrak folder Jade-Mailbox-Warm-Session ke D:\Godot\tools dan jalankan:

```
D:\Godot\tools\Jade-Mailbox-Warm-Session\apply_and_publish.cmd
```

Paket lanjutan untuk checkpoint 576afe5b399dcf4f25d4cf952cfe469dcdc69eb5. Seluruh paket sebelumnya sudah terpasang dan push terakhir diverifikasi sebelum pekerjaan dimulai. Jangan jalankan installer paket lama setelah paket ini.

Launcher memeriksa seluruh target sebelum menulis, backup file yang berubah, QA di profil terisolasi, validasi/reuse kandidat native lama, commit/push checkpoint dengan link GitHub sebenarnya, dan membuka editor produksi untuk satu export AAB. Metadata mailbox_session_revision=1 dan sumber commit harus cocok. Kalau koneksi terputus, jalankan launcher yang sama; tahap selesai disimpan. Tidak ada Worker deploy, migrasi D1, pembelian atau reset akun dalam batch ini.

## Perubahan

- Inbox server sudah disiapkan setelah profil login terhubung, bukan baru ketika layar surat dibuka. Data cache langsung tampil; refresh di belakang tiap180detik, hanya cek saat membuka jika cache berumur60detik atau lebih.
- HTTPS mailbox memakai HTTPClient yang dapat mempertahankan satu sambungan TLS untuk beberapa request. Claim/ACK/hapus tidak selalu membuat handshake baru. Socket yang ditutup server dipulihkan untuk request berikutnya; POST yang sudah dikirim dan hasilnya tidak pasti tidak direplay otomatis oleh transport.
- Token disimpan hanya di memori, terikat akun, dibatasi expiry90detik buffer/maks50menit. Akun berubah/401 membersihkan cache; server tetap memverifikasi token tiap request. Tidak ada perubahan DNS Windows, bypass TLS, rahasia tersimpan atau kredensial pada log.
- Claim/ACK/hapus diprioritaskan di depan pagination dan read receipt. Delapan surat tetap memakai satu claim batch dan satu ACK batch dengan journal/reward marker per surat. ACK server yang memang menandai surat terbaca menghindari request read berlebihan.
- Membuka mailbox langsung ke Inbox. Tidak otomatis memilih atau membaca surat pertama. Satu tap membuka surat; swipe tidak menandainya dibaca. Titik merah di pojok atas kartu menunjukkan belum dibaca, berada di dalam kartu dan mengikuti clipping scroll.
- Status baca tampil segera dan direkonsiliasi di belakang dengan intent per akun yang bisa pulih setelah offline/restart. Data halaman lama tidak menghidupkan lagi titik merah setelah surat sudah dibuka. Read receipt tidak mengunci tombol Claim.
- Delete All tetap menunggu respons sukses server. Mailbox tidak menghapus attachment belum diklaim atau lease claim yang belum selesai. Surat kosong juga dapat dihapus. Konfirmasi hapus tidak dibatalkan oleh halaman sinkronisasi lama yang baru tiba.
- Odyssey autoload menyiapkan snapshot event melalui request baca setelah akun siap, dan menggunakannya kembali saat event dibuka. Prewarm tidak memutar dadu, mereplay journal aksi, membuka iklan, ataupun melakukan pembelian. Refresh ulang tetap diperlukan saat data kedaluwarsa atau jaringan berubah.
- Copy Support menambahkan jumlah sambungan/reuse, aksi mailbox terakhir dan waktunya tanpa token atau UID privat.

## Yang dipertahankan

Desain/art mailbox yang disetujui, seluruh unit AdMob, batas harian, reward, keuangan dan production IAP. Native Kotlin/AAR tetap sama, 45input kandidat diverifikasi. Koneksi akun Google dan protokol event/SSV tidak dirombak. Cabang main tidak diubah; save pemain tidak disentuh oleh QA.

Membuka data cache dapat langsung dilakukan; claim dan delete tetap membutuhkan konfirmasi server. Jaringan baru, aplikasi disuspend, atau socket yang ditutup server bisa memerlukan koneksi lagi. Tidak ada janji koneksi internet permanen sejak satu kali membuka game.

## Pengujian

EVIDENCE berisi hasil aktual, termasuk HTTPClient/TLS sungguhan ke server loopback (bukan simulasi tayangan live), startup/read-only prewarm, owner/token fencing, reward journal dan inbox mobile. Satu negative TLS control sengaja memakai sertifikat yang tidak dipercaya dan wajib ditolak; diagnostik handshake pada kasus itu bukan kegagalan positif.

Sesudah update di HP cukup periksa sekali: buka Inbox, tap surat bertitik merah, Claim All lalu Delete All, dan buka-tutup event untuk cache. Tidak perlu mengulang test top-up.
