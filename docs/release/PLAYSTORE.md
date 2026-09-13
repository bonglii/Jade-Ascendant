# Dari proyek ke Google Play

Disusun 9 September 2026. Sasaran paket: Godot 4.7.2, Android portrait, ARM64, API minimum 24, target API 36, AAB release bertanda tangan. Ini jalur menyiapkan calon rilis; persetujuan Google Play belum diperoleh.

## 1. Persiapan sekali di PC

- Pasang JDK 17 dan Android SDK. Atur Java SDK Path serta Android SDK Path melalui **Editor Settings → Export → Android** di Godot.
- Pasang export templates yang **persis cocok dengan Godot 4.7.2** melalui menu pengelola template Godot.
- Android SDK harus memuat platform **36**. Gunakan NDK r28b (28.1.13356709) dan komponen build yang dibutuhkan template Godot. Panduan Godot masih dapat memperlihatkan SDK 35 sebagai contoh; preset paket ini menargetkan 36 karena persyaratan Play yang berlaku. [Panduan Godot Android](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html), [persyaratan target API Google Play](https://developer.android.com/google/play/requirements/target-sdk).
- Untuk tombol pembuat kunci dan pemeriksaan tanda tangan, arahkan `JAVA_HOME` ke folder JDK atau tambahkan folder `bin` JDK ke PATH.

Android Studio menyediakan SDK Manager untuk pemasangan komponen. Proses Gradle pertama membutuhkan internet untuk dependensi build. Game yang diekspor tetap memakai konfigurasi offline.

## 1B. Android environment preflight

Jalankan `PERIKSA_ANDROID.bat` sebelum mengisi identitas atau membuat AAB. Gate ini memeriksa JDK 17+, Android SDK, `platform-tools/adb`, Android Platform API 36, Build-Tools minimal 35.0.1, Command-line Tools, Godot 4.7.2 export templates, serta preset AAB/ARM64. Hasil terstruktur ditulis ke `artifacts/android-preflight.json`.

Jika ada FAIL, perbaiki hanya komponen yang ditandai. Script membaca `ANDROID_HOME`, `ANDROID_SDK_ROOT`, lokasi default `%LOCALAPPDATA%\Android\Sdk`, dan Android SDK Path yang tersimpan di Godot. Untuk Java, helper juga membaca `JAVA_HOME`, PATH, dan Java SDK Path Godot.

## 2. Identitas dan kebijakan

Jalankan `SIAPKAN_RILIS.bat`. Isi package name yang menjadi identitas final game, nama penerbit, email dukungan, dan URL HTTPS kebijakan privasi milikmu. Script menolak contoh `com.example...` dan data kosong. Setelah aplikasi diterbitkan, mengganti package name berarti aplikasi berbeda.

Script membuat `release/privacy-policy.html` dari template EN/ID. **Baca dan sesuaikan komitmen tentang penanganan email dukungan**, lalu terbitkan HTML tersebut di URL yang kamu isi. Pastikan URL dapat dibuka tanpa login. Paket ini belum menerbitkan halaman itu. Nama penerbit, URL, dan email juga masuk ke layar privasi game.

`release/release_config.json` menyimpan nilai publik dan versi; tidak menyimpan password. Untuk update berikutnya, naikkan `version_code` sebelum membangun AAB baru.

## 3. Kunci dan build

1. Jalankan `BUAT_KUNCI_UPLOAD.bat` jika belum memiliki upload key. Masukkan identitas dan password melalui keytool. Gunakan password kunci yang sama dengan password keystore. Simpan cadangan pribadi; jangan masukkan ke ZIP untuk dibagikan.
2. Jalankan `BUAT_AAB.bat`. Pemeriksaan Godot dilakukan ulang pada salinan terpisah sebelum export. Pilih keystore yang sudah kamu miliki jika memakai kunci lain. Password hanya diberikan ke proses build melalui environment, kemudian dipulihkan/dibersihkan.
3. Bila sukses, ambil `artifacts/JadeAscendant-1.0.0.aab` dan `artifacts/aab-build-report.json`.

AAB membutuhkan Gradle dan kunci release. Tombol menggunakan flag Godot `--install-android-build-template` bersama `--export-release`. [Export Android](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html), [CLI Godot](https://docs.godotengine.org/en/latest/tutorials/editor/command_line_tutorial.html).

Pemeriksaan bundle memeriksa keberadaan native ARM64, alignment segmen ELF minimal 16 KB, dan tanda tangan JAR. **Itu belum memeriksa APK hasil distribusi, perilaku pada perangkat 16 KB, manifest akhir, atau kelulusan Play.** Periksa APK hasil bundle dengan APK Analyzer/`zipalign` serta emulator/perangkat 16 KB. [Panduan Android 16 KB](https://developer.android.com/guide/practices/page-sizes).

## 4. Uji sebelum produksi

Gunakan matriks `DEVICE_QA.md`. Jalankan seluruh lima trial tanpa memaksa boss melalui script uji. Periksa portrait dengan notch, Android Back, background/resume, suara, panas, save, menang/kalah, dan semua perlengkapan. Laporan FPS serta hasil perangkat harus diisi dari pengukuran nyata.

`AMBIL_SCREENSHOT.bat` membuat salinan dengan save terpisah. Mainkan game dan tekan F12 untuk menangkap viewport asli. Pilih minimal dua screenshot ponsel yang representatif; utamakan gameplay. Periksa ukuran hasil, isi, dan tampilan pada Android. Jangan memakai banner sebagai screenshot gameplay. Berkas ikon 512×512 RGBA dan feature graphic 1024×500 RGB ada di `release/store/`. [Persyaratan aset listing](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

## 5. Isi Play Console

Buat aplikasi dari akun penerbitmu dan unggah AAB ke **Internal testing** terlebih dahulu. Bahan teks EN/ID ada di `STORE_LISTING.md`. Periksa package, version code, target SDK sebenarnya, permission, dan peringatan kompatibilitas yang dibaca Play dari AAB.

| Bagian | Dasar pengisian edisi ini |
|---|---|
| App access | Game tidak memerlukan login atau kredensial reviewer |
| Ads | Tidak ada iklan pada edisi offline ini |
| Pembelian dalam aplikasi | Tidak ada integrasi pembayaran/produk uang nyata pada edisi ini |
| Data safety | Sumber saat ini tidak memiliki SDK pengiriman data; gunakan worksheet di bawah dan cocokkan dengan bundle akhir |
| Privacy policy | URL aktif milik penerbit, sesuai HTML yang sudah ditinjau |
| Content rating | Jawab kuesioner berdasarkan pertarungan fantasi yang benar-benar tampil; jangan menebak rating akhirnya |
| Target audience | Pilih audiens yang memang dituju; gaya pixel art tidak otomatis berarti ditujukan untuk anak-anak |
| Pricing/distribution | Keputusan penerbit di Console; belum ditetapkan dalam paket |

Untuk akun developer pribadi baru yang terkena persyaratan pengujian, Google meminta closed test dengan sedikitnya **12 tester** yang tetap ikut selama **14 hari berturut-turut** sebelum permohonan akses produksi. Ikuti status yang tampil pada akunmu. [Persyaratan pengujian akun pribadi](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).

## Worksheet Data safety

Paket saat ini menyimpan progres serta preferensi di perangkat, tidak memiliki HTTP client/SDK analitik aktif, dan permission internet nonaktif. Offline-only local storage berbeda dari data yang dikirim keluar perangkat. Berdasarkan sumber ini, jawaban awal untuk pengumpulan/pembagian data game adalah **tidak**; penerbit harus mencocokkannya dengan AAB final, plugin tambahan, dan kegiatan dukungan yang sebenarnya. Formulir serta kebijakan tetap perlu diisi. [Penjelasan Data safety Google Play](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).

Jika nanti menambah iklan, billing, cloud save, analytics, atau crash reporting, tinjau ulang formulir, kebijakan, consent, serta permission. Jangan menggunakan deklarasi offline ini untuk build yang telah memiliki SDK tersebut.

## Syarat menandai rilis siap unggah

- Pemeriksaan Godot lulus pada revisi yang dibangun.
- AAB release bertanda tangan berhasil dibuat dan diverifikasi.
- Target/permission/ABI akhir sesuai, termasuk pemeriksaan native 16 KB dan APK/perangkat.
- Uji nyata serta pre-launch report telah ditinjau dan masalah utama ditutup.
- Screenshot berasal dari game nyata; identitas, privasi, dan hak penggunaan aset telah diperiksa.
- Formulir Console selesai dan jalur testing akun terpenuhi.

Paket sumber ini belum memenuhi seluruh syarat di atas dari lingkungan pengerjaan. Tidak ada aplikasi yang dikirim atau dipublikasikan oleh paket ini secara otomatis.
