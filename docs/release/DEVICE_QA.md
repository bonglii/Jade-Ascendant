# Jade Ascendant — Release device QA matrix

Isi matriks ini untuk **AAB release yang sama** dengan build yang akan dikirim.
Catat version/versionCode, Git SHA, SHA-256 AAB, model perangkat, Android version,
renderer, tanggal, dan penguji. Status default adalah **NOT_RUN** sampai bukti device
untuk AAB tersebut tersedia.

Smoke otomatis membantu regresi, tetapi tidak menggantikan uji perangkat nyata.

| Kelompok | Skenario | Lulus bila | Status |
|---|---|---|---|
| Instalasi | Fresh install dan update di atas save lama yang didukung | Boot normal; save yang didukung terbaca; tidak reset diam-diam | NOT_RUN |
| Portrait | 16:9, 19.5:9, 20:9, tablet, notch/inset | Tombol/teks tidak tertutup, terpotong, atau overlap material | NOT_RUN |
| Input | Joystick, multi-touch, Android Back | Gerak berhenti saat dilepas; tidak stuck setelah pindah aplikasi | NOT_RUN |
| Tutorial | Pemain baru sampai breakthrough pertama | Semua langkah bisa diselesaikan tanpa soft-lock | NOT_RUN |
| Trial 1–5 | Selesaikan masing-masing tanpa forced event | Boss/unlock/reward/Retry/Home diproses tepat | NOT_RUN |
| Lifecycle | Background/resume saat combat, pause, upgrade | State kembali aman; audio tidak nyangkut | NOT_RUN |
| Process interruption | Force-stop sebelum/sesudah claim/forge/win | Tidak double grant; save pulih atau tetap terlindungi | NOT_RUN |
| Save recovery | Primary rusak, backup valid, future version | Recovery/protection bekerja; tidak reset diam-diam | NOT_RUN |
| Equipment | Equip/unequip roster aktif dan efek khusus | Stat/effect sesuai; tidak mutate gear secara ilegal saat run | NOT_RUN |
| Daily/local time | Pergantian hari dan clock rollback | Claim/task lokal tidak mudah digandakan dengan rollback | NOT_RUN |
| Bahasa | EN↔ID, label panjang, angka, reward | Tidak ada placeholder bocor atau layout rusak | NOT_RUN |
| Audio | Music/SFX/master, reset, transisi | Mixer/loop/voice state konsisten | NOT_RUN |
| Accessibility | Reduced effects, shake, damage numbers, vibration | Setting langsung berlaku dan telegraph tetap jelas | NOT_RUN |
| Performance | 15 menit + wave padat | Catat FPS/frame time, memory, heat; tidak crash/leak terus-menerus | NOT_RUN |
| 16 KB | Device/emulator page size 16 KB dari APK hasil AAB | Boot, gameplay, save, audio normal | NOT_RUN |
| Guest | Fresh launch → Play as Guest | Guest masuk game tanpa login wajib dan local save normal | NOT_RUN |
| Google Sign-In | Login pada Android yang dikonfigurasi | Login selesai; UI hanya menampilkan status/name yang aman | NOT_RUN |
| Google session | Login → relaunch → sign out | Session dapat dipulihkan oleh provider; sign out tidak menghapus local progress | NOT_RUN |
| Login/save boundary | Guest progress → Google login → sign out → relaunch | Tidak ada upload/download/merge/switch/restore gameplay save | NOT_RUN |
| Rewarded ads | Complete/cancel/fail/no-fill | Reward hanya setelah completion; cancel/fail tidak grant | NOT_RUN |
| Rewarded limits | Placement/cooldown/cycle limit yang aktif | Tidak bisa double grant atau melewati limit | NOT_RUN |
| UMP/privacy | Region/device/config yang memerlukan privacy options | Consent/privacy UI muncul/terbuka saat diwajibkan | NOT_RUN |
| Billing catalog | Query product details | Enam Celestial Jade product aktif memetakan ke game ID yang benar | NOT_RUN |
| Billing purchase | Success/cancel/PENDING | PENDING tidak grant; cancel tidak grant; success save+reward tepat sekali | NOT_RUN |
| Billing recovery | Interrupt purchase lalu Restore Purchases | Eligible purchase pulih tanpa double grant | NOT_RUN |
| Network loss | Putus koneksi saat login/ads/billing | Service gagal aman; gameplay/local save tidak korup | NOT_RUN |
| Privacy/support | Privacy URL, support email, in-game disclosures | Link valid dan copy sesuai fitur build | NOT_RUN |

Target desain 60 FPS pada perangkat menengah dan opsi 30 FPS adalah target, bukan hasil
benchmark. Catat median/p95 frame time, FPS minimum, memory awal/akhir, dan gejala
thermal throttling.

Gameplay save tetap lokal. Google Login bukan backup save. Cloud Save/restore produksi
tidak tersedia, jadi device QA tidak boleh menganggap akun Google sebagai recovery
progres.

Untuk store screenshot, gunakan capture dari gameplay/UI nyata. Jangan memalsukan
unlock, currency, purchase, atau content state.
