# Jade Ascendant — Google Play release checklist

Dokumen ini adalah checklist source/release saat ini. Jawaban final Play Console tetap
harus diverifikasi oleh publisher terhadap **exact AAB yang diunggah** dan konfigurasi
live Console pada saat rilis.

## 1. Current Android identity

- Engine: Godot 4.7.2
- Package: `com.yungdevstudio.jadeascendant`
- Version: `1.0.4`
- Version code: `4`
- Portrait
- minSdk 24
- targetSdk 36
- arm64-v8a
- Gradle build enabled
- INTERNET permission enabled
- VIBRATE permission enabled

Jangan gunakan dokumen lama yang menyebut build offline-only, INTERNET disabled, tanpa
ads, tanpa billing, atau tanpa account.

## 2. Canonical local release flow

1. `PERIKSA_GAME.bat`
2. `PERIKSA_ANDROID.bat`
3. review/update publisher values melalui `SIAPKAN_RILIS.bat`
4. pastikan privacy policy yang dipublikasikan sama dengan build truth
5. `BUAT_AAB.bat`
6. verifikasi report/artifact AAB
7. upload ke Internal testing lebih dulu
8. jalankan `docs/release/DEVICE_QA.md` pada build yang sama

Build helper/preflight tidak menggantikan Play review atau device QA.

## 3. Account / Firebase Authentication

Current game:
- Google Sign-In opsional;
- Guest mode tersedia;
- tidak ada forced authentication;
- Google Login adalah identity boundary, bukan Cloud Save;
- login/sign-out tidak boleh mengganti gameplay save lokal.

Sebelum release:
- package Firebase harus sama dengan package AAB;
- signing SHA yang relevan harus terdaftar;
- Google provider harus aktif;
- real-device sign-in, restored session, sign-out, dan Guest fallback harus diuji;
- privacy policy dan Data safety harus sesuai exact SDK/data flow.

## 4. Ads / consent

Current game:
- Google Mobile Ads terintegrasi;
- rewarded ads bersifat opsional;
- Google UMP menyediakan applicable privacy choices;
- monetization debug diagnostics hanya untuk debug/test path yang memang diizinkan.

Sebelum release:
- verifikasi production AdMob app/ad-unit configuration;
- verifikasi UMP/consent behavior pada region/device yang relevan;
- verifikasi reward hanya diberikan setelah completion;
- cancel/failure/no-fill tidak boleh memberi reward.

## 5. Google Play Billing

Production-shaped billing provider aktif untuk enam Celestial Jade consumable:
- `jade_pouch_100`
- `jade_pouch_550`
- `jade_pouch_1200`
- `jade_pouch_2500`
- `jade_pouch_6500`
- `jade_pouch_14000`

Current client behavior:
- harga uang berasal dari Google Play product details;
- PENDING tidak memberi reward;
- consumable difinalisasi setelah local reward/save berhasil;
- interrupted purchase dapat dipulihkan melalui Restore Purchases;
- exact purchase-token replay dilindungi secara lokal dari double grant.

Security limitation:
- production server-side purchase-token verification dengan Google Play Developer API
  **belum terintegrasi**;
- jangan menyebut purchase flow server-authoritative atau server-verified.

Publisher wajib memverifikasi product status, pricing, tester eligibility, dan purchase
behavior di live Play Console / license-test environment.

## 6. Privacy / Data safety

Privacy policy harus konsisten dengan build:
- local gameplay save;
- optional Google Sign-In + Guest;
- Google Login tidak membackup gameplay;
- Cloud Save tidak tersedia;
- optional rewarded ads + UMP;
- Google Play Billing;
- support email handling;
- Google/Firebase/Ads/Billing processing mengikuti service yang relevan.

Jangan menyalin jawaban Data safety dari dokumen historis. Isi berdasarkan exact final
AAB, SDK yang benar-benar terkandung di bundle, konfigurasi live, dan praktik publisher.

## 7. Cloud claims

Production Cloud Save/restore tetap disabled/fail-closed. Store listing, reviewer notes,
screenshots, dan support copy tidak boleh menjanjikan:
- cloud backup;
- account-based gameplay recovery;
- automatic restore;
- cloud-wins;
- server-authoritative economy.

## 8. Live Play Console verification

Publisher harus memeriksa langsung, karena nilai ini tidak bisa dipastikan hanya dari
repository:
- App access / reviewer instructions;
- Ads declaration;
- Data safety;
- Content rating;
- Target audience / children-related settings;
- IAP product activation/pricing/availability;
- privacy-policy URL;
- country/device availability;
- testing-track requirements;
- policy warnings;
- Play App Signing identity;
- exact manifest/SDK findings dari uploaded AAB.

Jangan hard-code jawaban Console yang belum diverifikasi.

## 9. Release evidence before production

Minimum:
- exact Git SHA dicatat;
- required CI pada SHA tersebut green;
- AAB bertanda tangan berhasil;
- artifact SHA-256 dicatat;
- Internal testing install berhasil;
- device QA matrix terisi;
- Google/Guest boundary diuji;
- rewarded ads + UMP diuji;
- billing purchase/PENDING/recovery diuji;
- privacy/store copy cocok dengan shipped build;
- Cloud Save tetap fail-closed kecuali ada approval eksplisit terpisah.
