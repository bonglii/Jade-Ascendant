# UI reliability follow-up — 15 Oktober 2026

Melanjutkan batch premium `05a9778db7349bc2f5882d104b1641a01ab3774d`. Dua screenshot yang dikirim diperiksa langsung, lalu source dan scene aktual ditelusuri. Tidak membuat ulang gambar, main menu, equipment atau efek yang sudah disetujui.

## Yang diubah

| Keluhan | Perubahan dan dampak |
| --- | --- |
| Settings ON hanya “O” | Status ON/OFF atau AKTIF/MATI memakai Label terpisah dari native switch. Kebijakan clip tombol tidak lagi memotong CheckButton. Nilai pengaturan tetap mengikuti SettingsManager dan disimpan seperti sebelumnya. |
| Tombol Home kecil / Enter Journey terpotong | CTA diperlebar dan diperbesar. Pada layar sempit CTA berada di baris penuh tersendiri; Continue berbagi baris jika ada checkpoint. Teks penuh ENTER JOURNEY dipertahankan. All Events punya target sentuh ≥44px, ikon header ≥48px, label shortcut diperbesar. Tata letak diperiksa memakai lebar glyph sebenarnya. |
| Resource bar berbeda antar menu / kurang terlihat | Home, Cultivation, Hero, Trials, Achievement dan Pavilion memakai frame, tinggi, ikon dan aturan font yang sama. Ikon 26–40px, angka 14–26px sesuai ruang dan saldo. Angka dipisahkan dari plus, tetap di tengah vertikal. Saldo besar memakai singkatan seperlunya; tooltip memuat angka persis. Host safe-area masing-masing menu tetap digunakan. |
| Hero lama dibuka | Satu komposisi awal menggantikan dua build. Tidak membuat style CTA yang langsung dibuang oleh rarity card. Rarity styles dibagi dalam halaman. Font serif memakai aset yang sudah tersedia. Texture yang diminta hub ditahan saat berpindah menu lalu dilepas saat masuk combat; tidak memuat seluruh katalog yang belum dibutuhkan. Filter tetap memperbarui backpack tanpa membangun ulang equipment terpasang. |
| + Celestial Jade salah arah | Membuka halaman Heavenly Treasury yang sudah ada, termasuk enam produk asli. Bisa dibuka dari setiap wallet hub sebagai modal, lalu kembali ke halaman yang sama. Tidak otomatis memulai checkout atau memberi Jade. + Stone tetap ke Trials; + Seal ke Pavilion. |

## Yang tidak diubah

- Artwork Lin Yue, background, equipment dan rarity artwork; tidak ada aset gambar baru.
- HP, damage, skill, pasif set, attack pattern, drop rate, pity, harga atau isi reward.
- Save schema, duplikat, bintang dan level weapon.
- Desain mailbox/dashboard, Google login, token, DNS dan backend autentikasi dari batch sebelumnya.
- Konfigurasi IAP, product ID, harga Play, authority gate, deployment Cloudflare, AAR/APK/AAB. Tombol + mengakses UI pembelian; kesiapan transaksi tetap mengikuti provider dan proteksi yang ada.

## Hasil verifikasi

- Godot 4.7.2 Linux native renderer: **733 assertion PASS**. ON/OFF dan AKTIF/MATI; viewport 320×568, 390×844, 648×1152, 720×1600, 896×504; semua wallet hub; saldo 96/9999/123456/1234567890; Treasury, host scene, tidak ada pembelian/grant; cache dilepas saat masuk gameplay.
- Regresi Hero upgrade/equip/stale-action: **734 PASS**.
- Regresi Home/nav/checkpoint/safe bounds: **193 PASS**. Ekspektasi sumber Seal dipindah ke indeks 2; Jade diuji sebagai Treasury di matriks baru.
- Regresi batch premium Settings/Hero/results: **160 PASS**.
- Profiling fixture headless dengan 56 equipment: baseline dua build sekitar 430–461 ms total CPU build; sesudah perubahan satu build, sekitar 278 ms pembukaan awal dan 201 ms saat texture hub sudah tertahan. Contoh native renderer mencatat sekitar 232–258 ms per build. Ini pengukuran fixture desktop, bukan janji angka FPS/waktu HP. Log `Hero UI ready | builds ... | build ... ms` membantu mengukur perangkat yang sebenarnya.
- Render Home 390/720, Settings dan Hero 720 diperiksa. Tidak ada SCRIPT ERROR pada matriks final. Beberapa fixture standalone masih menyisakan resource saat process teardown; tidak dihitung sebagai pembuktian memory leak gameplay.
- Tidak mengulang audit combat, server atau monetisasi yang tidak berubah.

## Yang masih perlu / tidak dinyatakan selesai

Re-export Android diperlukan agar perubahan client masuk ke HP. Waktu buka Hero dan safe-area pada perangkat I2212 yang asli belum diukur di executor ini. IAP live, App Check, transaksi tester/refund, deployment dan rebuild native tetap mengikuti daftar pending batch premium. Membuka Treasury tidak berarti gate produksi dibuka.

GitHub belum dapat ditulis dari sesi ini: Git HTTPS tidak memiliki credential dan integrasi mengembalikan 403 pada percobaan batch sebelumnya. Commit lokal tidak diberi URL GitHub palsu. Publisher yang disertakan dapat memublikasikan gabungan path dua paket yang sudah disetujui, menjaga branch checkpoint dan menolak force push/unrelated staged changes.

Kesalahan dan pencegahannya dicatat di LESSONS.md: clip CheckButton, wallet Home-only, build Hero ganda, asumsi modal hanya Home, serta akses Continue sebelum ada. Catatan umum tersebut dan aturan ringkasan paket dicerminkan di dokumen ini; generic LESSONS/AGENTS tidak dimasukkan ke patch portabel untuk menghindari konflik dokumentasi yang sudah pernah terjadi.
