# Jade Ascendant — Google Sign-In setup and release boundary

## Current implementation

Google Sign-In adalah identity feature opsional pada Android. Guest mode tetap tersedia.

Current source:
- `scripts/managers/google_account_manager.gd`
- `scripts/ui/google_account_entry.gd`
- `scripts/ui/google_account_card.gd`
- tracked `addons/GodotFirebaseAndroid/`
- Firebase autoload enabled in `project.godot`

Behavior:
- existing signed-in Firebase Google session dapat bypass account-choice screen;
- signed-out player melihat pilihan Google atau Guest pada fresh launch;
- Google sign-in/sign-out tidak menghapus atau mengganti local gameplay save;
- Google Login tidak upload/download/merge/switch/restore gameplay progress;
- Cloud Save tidak aktif.

## Firebase / Android configuration

Untuk build Android yang benar-benar memakai Google Sign-In:

1. Firebase Android app package harus cocok dengan
   `com.yungdevstudio.jadeascendant`.
2. Daftarkan signing SHA yang relevan (debug/release/Play App Signing sesuai flow).
3. Enable Google provider di Firebase Authentication.
4. Gunakan `google-services.json` yang sesuai dengan project/package/signing setup.
5. Pastikan Android build template dan Firebase addon configuration benar.
6. Export/install build pada device dengan Google Play services.
7. Uji Guest, sign-in, relaunch/restored session, sign-out, dan failure fallback.

Jangan menaruh service-account private key atau admin credential di client/repository.

## Identity privacy boundary

`GoogleAccountManager` menggunakan authenticated UID sebagai private identity boundary.
UID:
- tidak boleh muncul di UI snapshot;
- tidak boleh ditulis ke gameplay save;
- tidak boleh dicatat ke debug log;
- bukan bukti bahwa gameplay progress sudah dibackup.

Account UI boleh menampilkan display name yang diberikan provider untuk status pemain.

## Save boundary

Authentication dan gameplay save adalah domain berbeda.

Login sukses tidak boleh:
- memilih save lain;
- overwrite local save;
- memulai cloud upload;
- memulai cloud download;
- melakukan merge;
- melakukan restore;
- memberikan entitlement/economy authority.

Sign-out juga tidak boleh menghapus gameplay save lokal.

## Release privacy / Data safety

Privacy policy repository saat ini harus menyatakan secara konsisten:
- Google Sign-In opsional;
- Guest tersedia;
- Firebase/Google menyediakan authentication service;
- gameplay save tetap lokal;
- Google Login bukan backup/restore;
- Cloud Save tidak tersedia;
- third-party Google services memiliki praktik data/privacy masing-masing.

Publisher tetap wajib memverifikasi Play Data safety terhadap exact native SDK, exact AAB,
live Firebase/Play configuration, dan praktik operasional sebenarnya.

## Device QA

Minimum device cases:
- Android tanpa provider/config lengkap gagal aman dan Guest tetap bisa main;
- successful Google login;
- relaunch dengan restored auth session;
- sign-out;
- Guest/local progress sebelum dan sesudah login tetap sama;
- tidak ada UID/token/email sensitif di log publik;
- network/config failure tidak merusak save.

Lihat `docs/release/DEVICE_QA.md`.

## Future cloud boundary

Cloud Save bukan bagian dari Google Login.

Aktivasi cloud di masa depan harus tetap mengikuti:
`docs/architecture/CLOUD_SAVE_PRODUCTION_APPROVAL_BOUNDARY.md`

Jangan menggunakan cleanup, login QA, atau keberhasilan Firebase Authentication sebagai
alasan untuk mengaktifkan cloud production.
