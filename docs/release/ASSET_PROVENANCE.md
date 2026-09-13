# Asal aset dan catatan distribusi

Catatan ini menjelaskan berkas yang digunakan; bukan bukti kepemilikan hak atas seluruh aset unggahan.

| Kelompok | Asal yang diketahui | Catatan |
|---|---|---|
| Lin Yue, musuh, atlas boss, key art, tekstur UI/world dari baseline | Disediakan dalam ZIP proyek pengguna | Dokumen lisensi/kontrak sumber tidak disertakan. Penerbit perlu memastikan hak distribusi komersial dan atribusi yang diperlukan |
| Tiga PNG weapon/Qi pengganti Phase 1 | Dihasilkan dalam pengerjaan proyek: jade jian, pasangan blade, Qi shard | Dipakai melalui import dan scene baru; bukan salinan weapon Arthurian yang dikecualikan |
| Chapter 2 enemy identity sprites | Turunan internal dari sprite enemy baseline proyek, diproses ulang untuk silhouette, palette black/crimson/gold, ritual marks, veils, armor accents, dan VFX identity Crimson Moon | Mempertahankan layout frame/behavior existing; tidak menambahkan aset pihak ketiga ke build |
| Chapter 3 enemy identity sprites | Turunan internal dari sprite enemy baseline proyek, diproses ulang untuk palette indigo/cloud-white/star-gold, celestial crests, cloud ribbons, starforged armor, dan VFX identity Nine Heavens | Mempertahankan layout frame/behavior existing; tidak menambahkan aset pihak ketiga ke build |
| Musik dan SFX baru | Sintesis prosedural melalui `tools/generate_audio.py` | 3 Ogg + 16 WAV. Tidak memakai sampel/rekaman eksternal. Manifest audio dan generator tersedia |
| Motif arena, trigram, arc, trails dan feedback | Geometri GDScript yang ditulis untuk proyek | Tidak memuat gambar dari layanan eksternal |
| Ikon item tambahan | SVG yang memperluas empat ikon slot dalam proyek | Bentuk slot dipertahankan; warna/ornamen kelangkaan dibedakan |
| Ikon aplikasi, adaptive layers, banner | SVG asli dari `tools/generate_branding.py`, diekspor memakai Inkscape | Sumber vektor tersedia. Teks pada banner memakai font sistem DejaVu saat rasterisasi; tidak mendistribusikan binary font tersebut |
| Font lama `bitbybit` | File dari baseline tanpa dokumen lisensi terlampir | Referensi di Level_1 diganti dengan font fallback Godot; folder font legacy dikecualikan dari export |
| Engine dan dependensi bawaannya | Godot Engine/export template yang dipakai penerbit | Layar Credits & Licenses menampilkan teks lisensi dan pemberitahuan dari Engine API pada build tersebut |

Aset Arthurian/legacy yang sudah dipastikan tidak direferensikan oleh patch dikecualikan melalui preset. File lama tetap berada pada proyek pengguna; tidak perlu dihapus untuk menerapkan patch.

Sebelum distribusi, lengkapi bukti asal/hak untuk aset baseline milikmu. Jika menambahkan SDK, font, texture pack, atau musik pihak ketiga, tambahkan pula lisensi serta atribusi yang diwajibkan. Jangan menyimpulkan bahwa sebuah aset bebas digunakan hanya karena tidak mengandung watermark.
