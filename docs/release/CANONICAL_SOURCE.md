# Jade Ascendant — Canonical Source Policy

## Source authority

Source authority adalah **repository Git yang tracked pada branch + exact commit SHA**.
Jika ZIP, handoff, folder lokal lama, atau catatan historis berbeda dari exact Git
commit, Git commit tersebut yang menjadi referensi source.

Yang termasuk source authority ketika tracked pada commit:
- `project.godot`
- `export_presets.cfg`
- `scripts/`, `scenes/`, `assets/`, `tests/`, `tools/`
- `addons/` yang memang dibutuhkan build
- `backend/` untuk cloud safety source
- `docs/` dan release documentation
- tracked release configuration di `release/`

Old patch ZIP, chat handoff, dan laporan QA historis bukan pengganti source authority.

## Generated / machine-local state

Bukan source authority:
- `.godot/` dan import/editor cache lokal
- `artifacts/`
- APK/AAB hasil build
- log, screenshot, temporary report, ad-hoc ZIP
- keystore/private key dan secret
- machine-local Android/JDK paths
- file build/cache yang dihasilkan toolchain

Generated output tidak boleh dipakai untuk menimpa tracked source tanpa audit.

## Canonical validation entrypoints

- `PERIKSA_GAME.bat` — production Godot smoke/check entrypoint.
- `PERIKSA_ANDROID.bat` — Android + AdMob release preflight.
- `SIAPKAN_RILIS.bat` — publisher/release configuration.
- `BUAT_AAB.bat` — guarded Android release AAB build.

`PERIKSA_GAME.bat` tetap merupakan production smoke entrypoint. Jangan menghidupkan
kembali validator/harness lama yang sudah retired hanya karena namanya pernah muncul
di dokumen historis.

## Android release truth

Current tracked release identity:
- package `com.yungdevstudio.jadeascendant`
- version `1.0.4`
- versionCode `4`
- minSdk `24`
- targetSdk `36`
- arm64-v8a
- INTERNET enabled
- VIBRATE enabled

Nilai final tetap harus diverifikasi dari exact AAB/Play Console sebelum publish.

## Cloud production boundary

Cloud source tetap fail-closed. `backend/cloud_save/production_approval_boundary.json`
adalah approval fuse kanonik.

Cleanup, documentation sync, atau repo hygiene **tidak** memberi izin untuk:
- deploy Firebase production;
- menambah callable production;
- mengaktifkan Cloud Save/write;
- mengaktifkan restore/automatic restore/cloud-wins;
- mengaktifkan server economy write;
- mengubah billing plan;
- merge QA ke main.

Semua activation tersebut memerlukan explicit human approval sesuai boundary file.

## Fresh clone rule

Fresh pull/clone baru dianggap canonical working base setelah exact commit yang dipilih:
1. sudah di-push;
2. exact-SHA CI yang diwajibkan hijau;
3. whole-repo recursive hygiene audit bersih.
