# Jade Ascendant — Current source/release status

Dokumen ini adalah snapshot **current product truth**, bukan histori kronologis. Histori
perubahan detail tetap berada di Git.

## Runtime

- Godot 4.7.2
- Android portrait
- package `com.yungdevstudio.jadeascendant`
- version `1.0.4`
- versionCode `4`
- minSdk 24 / targetSdk 36
- arm64-v8a
- INTERNET enabled
- VIBRATE enabled
- five Journey chapters wired

## Save / identity

- Gameplay progress tetap local-device save.
- Google Sign-In tersedia secara opsional pada Android yang dikonfigurasi.
- Guest mode tetap tersedia.
- Google identity tidak mengganti ownership gameplay save.
- Google Login tidak upload/download/merge/switch/restore gameplay progress.
- Authenticated UID adalah private identity boundary dan tidak boleh diekspos di UI,
  log, atau gameplay save.

## Monetization

- Google Mobile Ads terintegrasi untuk optional rewarded ads.
- Google UMP digunakan untuk applicable privacy choices.
- Google Play Billing terintegrasi.
- Enam active Celestial Jade consumable dipetakan ke Google Play products.
- PENDING tidak grant.
- Interrupted eligible purchase dapat dipulihkan melalui Restore Purchases.
- Local purchase-token replay protection mencegah exact token memberi reward dua kali.
- Production server-side purchase-token verification belum terintegrasi.

## Cloud

Cloud production tetap fail-closed:
- Cloud Save disabled
- cloud write disabled
- restore disabled
- automatic restore disabled
- cloud-wins disabled
- server economy write disabled

Production activation tetap membutuhkan explicit human approval sesuai
`backend/cloud_save/production_approval_boundary.json`.

## Release entrypoints

- `PERIKSA_GAME.bat`
- `PERIKSA_ANDROID.bat`
- `SIAPKAN_RILIS.bat`
- `BUAT_AAB.bat`

Release readiness hanya boleh dinilai dari exact source SHA + exact-SHA CI + exact AAB
+ device/Play Console evidence yang relevan.
