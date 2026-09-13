# Pengujian perangkat — belum dijalankan

Isi untuk build AAB yang sama dengan yang akan diunggah. Catat versi, SHA-256, model perangkat, Android, RAM, renderer, tanggal, dan penguji. Status awal seluruh baris **NOT_RUN**. Smoke otomatis memaksa beberapa event; ia tidak menggantikan permainan utuh atau uji sentuhan.

| Kelompok | Skenario | Lulus bila | Status |
|---|---|---|---|
| Instalasi | Install baru dan update di atas save v1 lama | Bisa boot; progres/gear/claim lama terbaca | NOT_RUN |
| Portrait | 16:9, 19.5:9, 20:9, tablet, notch | Tombol dan teks tidak tertutup inset, terpotong, atau saling menimpa | NOT_RUN |
| Input | Joystick, multi-touch, kembali Android | Gerak berhenti saat dilepas; tidak tersangkut setelah pindah aplikasi | NOT_RUN |
| Tutorial | Pemain baru hingga breakthrough pertama | Semua langkah dapat diselesaikan; tidak ada jeda yang mengunci game | NOT_RUN |
| Trial 1–5 | Selesaikan masing-masing tanpa memaksa event | Boss, unlock, reward, Retry dan Home tepat satu kali | NOT_RUN |
| Akhir sesi | Boss dan pemain mati pada saat berdekatan | Hanya satu hasil dan satu jalur hadiah yang diproses | NOT_RUN |
| Continue | Pause → Home → pilih trial lain → Continue | Stage dan snapshot checkpoint tetap benar | NOT_RUN |
| Lifecycle | Background saat bertempur, jeda, dan pilihan upgrade | Suara berhenti di background; kembali dalam kondisi aman | NOT_RUN |
| Gangguan proses | Force-stop sebelum/sesudah klaim, forge, atau kemenangan | Tidak menambah hadiah dua kali; simpanan pulih atau tetap terlindungi | NOT_RUN |
| Save rusak | Primary rusak, backup valid, versi masa depan | Recovery valid atau mode proteksi; tidak mereset progres diam-diam | NOT_RUN |
| Perlengkapan | Equip/unequip 16 item; tiap efek khusus | Stat dan penjelasan sesuai; tidak mengubah gear di tengah sesi | NOT_RUN |
| Daily | Hari berganti saat game terbuka; jam dimundurkan | Tiga tugas aktif; klaim harian tidak terulang karena waktu mundur | NOT_RUN |
| Jurus | Keenam jurus Level 1→7 dan tiga resonance | Pilihan MAX menghilang; damage/visual sesuai; tidak ada projectile abadi | NOT_RUN |
| Bahasa | EN↔ID, label panjang, angka, reward duplikat | Kontrol terbaca; placeholder format tidak bocor; istilah konsisten | NOT_RUN |
| Audio | Music/SFX/master 0%, 100%, reset, 10 transisi | Mixer berfungsi; loop tidak klik; voice tidak menumpuk | NOT_RUN |
| Kenyamanan | Reduced effects, shake, angka damage, getaran | Pilihan segera berlaku dan tersimpan; telegraph tetap jelas | NOT_RUN |
| Performa | 15 menit dan semua jurus saat wave padat | Ukur FPS/frame time, memori, panas; tidak crash atau bocor terus-menerus | NOT_RUN |
| 16 KB | Emulator/perangkat page size 16 KB dan APK dari AAB | Boot, main, simpan, dan audio berjalan normal | NOT_RUN |
| Privasi | URL dan email dari Settings/Pavilion | Kebijakan publik sesuai penerbit; tautan berfungsi | NOT_RUN |

Target rancangan: 60 FPS pada perangkat menengah, pilihan 30 FPS untuk hemat daya. Ini **target**, bukan hasil benchmark. Catat median/p95 frame time, FPS terendah, memori awal/akhir, dan suhu/gejala throttling. Belum ada bukti perangkat yang menjamin target tersebut.

Checkpoint berkala dibuat sekitar setiap 20 detik setelah interval awal 15 detik, juga melalui alur jeda/background yang aman. Pilihan breakthrough yang masih terbuka tidak dijadikan checkpoint baru. Kill/progress nonmilestone digabung sekitar 2 detik. Karena ini save lokal, gangguan proses dapat kehilangan bagian progres setelah snapshot terakhir; tidak ada server atau cloud recovery.

Untuk screenshot toko: ambil gameplay lembah, shrine dengan telegraph, storm/guardian, pilihan breakthrough, dan satu menu progres. Tetap tampilkan antarmuka sebenarnya. Capture tool tidak memalsukan unlock atau memberikan konten yang tidak ada.
