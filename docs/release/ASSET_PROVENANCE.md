# Jade Ascendant — Asset provenance

Dokumen ini mencatat provenance yang memang dapat dibuktikan dari source tree saat ini.
Dokumen ini **bukan** bukti kepemilikan hak atas semua aset proyek. Untuk aset yang
asal/lisensinya belum didokumentasikan, penerbit tetap wajib menyimpan bukti hak
distribusi yang sesuai.

## Visual / project assets

- Aset baseline karakter, musuh, boss, UI, world, branding, serta turunannya tetap
  dianggap aset proyek/publisher sesuai catatan proyek yang tersedia.
- Beberapa aset visual dan branding dibuat atau diproses selama pengerjaan proyek.
- Dokumen ini tidak menebak lisensi untuk aset yang tidak memiliki bukti/notice yang
  tersedia di repository.
- Vendored SDK/addon di `addons/` adalah dependency pihak ketiga dan tidak boleh
  dianggap sebagai aset original Jade Ascendant hanya karena file-nya tracked.

## Audio aktif

Audio aktif berada di:

`assets/audio/presentation_v2/`

Source notice kanonik untuk audio pihak ketiga:

`assets/audio/presentation_v2/THIRD_PARTY_AUDIO_NOTICES.md`

Notice tersebut saat ini mencatat sumber berikut:

| Sumber | Penggunaan / catatan yang didokumentasikan |
|---|---|
| WAFU Sound Works — WAFU Vol.19 “The Road Down” | Music context dan layer ritual/stinger; notice proyek mencatat penggunaan komersial/nonkomersial, modifikasi/remix/loop/layering, credit opsional, dan larangan redistribusi standalone |
| Atelier Magicae / Ririsaurus / Riri Hinasaki | Layer Fantasy UI Sound Effects / Fantasy UI SFX Vol.2; notice proyek mencatat penggunaan komersial/nonkomersial/personal, modifikasi sebagai layer, credit opsional, dan larangan redistribusi |
| R4orce — Clean UI: 20 Minimal Interaction Sounds | Layer UI taktil; notice proyek mencatat lisensi non-exclusive/royalty-free untuk proyek personal/komersial serta modifikasi, dengan larangan redistribusi standalone |
| lentikula — Basic Spell Impacts | Layer sumber Fire/Lightning; notice proyek mencatat CC0 |
| rubberduck — 100 CC0 metal and wood SFX | Layer fisik kayu/logam; notice proyek mencatat CC0 melalui OpenGameArt |
| Hove Audio — Sword Combat Sound Effects Pack Free Version | Layer sword whoosh/ring; notice proyek mencatat royalty-free game/film use dan credit tidak diwajibkan |

Jangan menambahkan klaim lisensi yang lebih luas daripada notice sumber. Jika notice
atau aset audio berubah, perbarui dokumen ini bersamaan dengan
`THIRD_PARTY_AUDIO_NOTICES.md`.

## Release rule

Sebelum distribusi:
1. pastikan hak/izin untuk aset baseline dan aset baru terdokumentasi;
2. pertahankan notice/attribution yang diwajibkan;
3. jangan menganggap file bebas dipakai hanya karena tidak memiliki watermark;
4. audit ulang provenance jika SDK, font, texture pack, musik, SFX, atau aset pihak
   ketiga baru ditambahkan.
