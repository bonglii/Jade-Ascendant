# Jade Rewarded Units — 2026-10-20

## Pasang satu paket ini

Paket ini mencakup batch Premium Reliability sebelumnya beserta pemisahan unit iklan. Jika paket sebelumnya belum dipasang, tidak perlu menjalankan dua installer atau mengekspor dua AAB. Bila sudah dipasang, file yang identik dilewati.

Ekstrak folder Jade-Rewarded-Units ke D:\Godot\tools. Jalankan dari CMD:

```
D:\Godot\tools\Jade-Rewarded-Units\apply_and_publish.cmd
```

Launcher melakukan pemeriksaan seluruh file sebelum menulis, backup, QA terisolasi, memeriksa kandidat native yang sudah ada, commit/push branch checkpoint, deploy dua Worker untuk batch reliability yang disertakan, lalu membuka editor produksi yang dikelola launcher. Export satu RELEASE AAB dan tutup editor. Verifikasi AAB memerlukan rewarded_units_revision=1 dan commit sumber yang cocok. Tidak ada pengujian pembelian ulang yang diperlukan.

Jika terputus, jalankan launcher yang sama. Tahap yang sudah selesai dicatat. Jangan menjalankan launcher lama sesudah paket baru ini dipasang.

## Perubahan baru

- Empat unit dipetakan secara eksplisit: Odyssey dice, Paviliun, revive, dan bonus umum. Tidak ada fallback ke unit bersama.
- Satu pengelola UMP/consent, satu iklan fullscreen aktif, empat cache/retry/status independen. Cache digunakan sekali dan diganti; kedaluwarsa 55 menit; load tanpa callback diberi timeout lalu retry hanya untuk unit tersebut.
- Debug menggunakan test ID Google, release menggunakan empat ID pemilik yang telah diberikan. App ID/publisher/ID ganda dicegah.
- SSV Odyssey hanya membawa nonce untuk unit dice yang lama. Nonce dibersihkan ketika iklan lain ditampilkan atau consent berubah. Verifikasi tanda tangan dan receipt server dari batch sebelumnya dipertahankan.
- Callback hadiah lama tidak boleh membayar akun baru bila akun berubah saat video berjalan.
- Copy support menampilkan status dice/pavilion/revive/general. Metadata export dan pemeriksa AAB mendeteksi build sebelum pemisahan unit.

## Nilai yang dipasang

App ID: ca-app-pub-3082528078187093~9576090733

| Unit | ID | Reward AdMob |
|---|---|---|
| Rewarded_Event_Dice | ca-app-pub-3082528078187093/8339864838 | 1 Dice |
| Rewarded_Pavilion_Pull | ca-app-pub-3082528078187093/2136559730 | 1 PavilionSeal |
| Rewarded_Revive | ca-app-pub-3082528078187093/9686167686 | 1 Revive |
| Rewarded_General_Bonus | ca-app-pub-3082528078187093/9338683323 | 1 Bonus |

General dipakai offline_cultivation_double, liveops_boss_hunt_double, liveops_treasure_hunt_double. Offer baru yang belum aktif tidak ikut diaktifkan. Bonus AdMob bukan angka Spirit Stones; nilainya tetap dihitung domain pemilik bonus.

## Pengaturan AdMob oleh pemilik akun

Rename unit lama menjadi Rewarded_Event_Dice tanpa mengganti ID, reward Dice, atau callback /v1/odyssey/ssv. Ketiga unit baru adalah STANDARD rewarded, Partner bidding tidak dicentang. Kosongkan SSV ketiga unit baru; jangan arahkan semuanya ke callback Odyssey yang khusus dadu. Rewarded legacy masih memakai callback SDK + grant ID, guard save, batas/anti-replay domain yang sudah ada; jangan menyebutnya SSV server.

Matikan Pod iklan per unit untuk menghindari rangkaian video, dan matikan High-engagement ads di App settings bila menginginkan waktu menuju reward maksimal 30 detik pada inventaris yang dicakup Google. Kode game tidak dapat mengubah kedua setelan dashboard itu, menentukan tepat 60 detik total, atau menjamin ketersediaan iklan Google. Tidak ada pengaturan dashboard yang diubah dari lingkungan ini.

## Aturan reward yang dipertahankan

Odyssey: 2 receipt dadu per akun per hari, server authoritative. Paviliun: 1 seal per hari dengan maksimal 7 per siklus lama. Contoh 2 summon/hari dalam diskusi belum diterapkan sebagai perubahan ekonomi. Revive tetap satu per run; bonus umum mengikuti domain masing-masing; global guard legacy tidak dihapus. Pemisahan cache tidak berarti menggandakan semua jatah. Batas legacy bersifat lokal/profil, bukan ledger SSV lintas perangkat.

Live production IAP dan paid gameplay tidak dikunci ulang. Tidak ada perubahan SKU/harga/paid balance, save schema, izin, kunci rahasia, sertifikat, DNS Windows, jadwal cron, native Kotlin/AAR, atau cabang main.

## QA dan rollout

Lihat EVIDENCE untuk hasil aktual. EVIDENCE/previous_batch memuat bukti render batch sebelumnya yang tidak diulang hanya karena konfigurasi iklan berubah. Pengujian baru memakai SDK GDScript aktual dan native transport double; tidak membuat tayangan/credit palsu pada server live. Commit GitHub baru hanya ada setelah publisher pada PC pemilik sukses; launcher mencetak link commit sebenarnya.

Setelah AAB diunggah dan dipasang dari Play, lakukan satu pemeriksaan dadu sampai Reward Granted dan satu free seal Paviliun. Itu bukti layanan iklan live yang tidak bisa digantikan test lokal. Tidak perlu mengulang test payment.
