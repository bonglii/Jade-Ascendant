# Balance yang diterapkan

Build JA-RELEASE-CANDIDATE-20260909. Angka di bawah berasal dari katalog sumber, **belum hasil playtest**. Stage 1 mempertahankan tempo serta bonus awal baseline. Perubahan numerik dijelaskan agar penyesuaian berikutnya dapat ditelusuri.

## Trial dan encounter

Wave dimulai pada 1; final encounter dimulai pada wave 10. Durasi menuju boss merupakan 9 × durasi wave, tanpa waktu pause, layar breakthrough, atau waktu mengalahkan boss.

| Trial | Detik/wave | Menuju boss | Interval difficulty | Spawn dasar | Cap musuh biasa | Boss HP | Batu Roh pertama/ulang |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1-1 Verdant Awakening | 5 | 45 dtk | 60 dtk | 2 dtk | Baseline tanpa cap baru | 500 | 100/100 |
| 1-2 Bamboo Mist Pass | 18 | 162 dtk | 90 dtk | 2 dtk | 80 | 580 | 150/100 |
| 1-3 Ruined Jade Shrine | 20 | 180 dtk | 90 dtk | 2.2 dtk | 80 | 720 | 175/110 |
| 1-4 Storm Peak Approach | 22 | 198 dtk | 90 dtk | 2 dtk | 88 | 880 | 200/120 |
| 1-5 Sovereign's Celestial Gate | 26 | 234 dtk | 100 dtk | 1.9 dtk | 96 | 1100 | 300/150 |

Cap berlaku pada jalur spawn reguler stage baru; elite dan boss mempunyai jalur encounter sendiri. Spawn dasar masih dipengaruhi difficulty/wave dari manager lama. Stage 1 memakai pemilihan musuh baseline. Semua boss memakai atlas baseline dengan profil perilaku berbeda; phase dua dimulai pada ambang HP baseline 60%.

| Trial | Elite pada wave | Hazard | Item clear |
|---|---|---|---|
| 1-1 | 4: tipe 1, 8: tipe 2 | Tidak ada | Verdant Qi Robe (pertama saja) |
| 1-2 | 4: tipe 1, 8: tipe 2 | Tidak ada | Miststride Boots |
| 1-3 | 4: tipe 1, 8: tipe 1 | Ward / 12 dtk | Ward Keeper Robe |
| 1-4 | 4: tipe 2, 8: tipe 2 | Petir / 11 dtk | Stormcall Bracer |
| 1-5 | 4: tipe 1, 6: tipe 2, 8: tipe 2 | Ward / 14 dtk | Sovereign Mantle |

Ward: radius 64, peringatan 1,25 detik, damage 5. Petir: radius 58, peringatan 1,1 detik, damage 6. Hazard aktif mulai wave 3, berhenti pada boss, maksimal empat instance; finale mulai wave 6 dapat memunculkan dua tanda dengan posisi yang sudah tetap.

## Perlengkapan dan forge

Harga Batu Roh **atau** Pecahan Pemurnian; bukan keduanya sekaligus. Satu item per ID, satu item per slot; item yang sudah dimiliki tidak dapat dibeli ulang. Trial pada kolom buka harus sudah cleared.

| Item | Rarity / slot | Bonus | Batu Roh / pecahan | Buka setelah trial |
|---|---|---|---:|---:|
| Verdant Qi Robe | common / robe | HP +10 | 80 / 10 | Awal |
| Jade Guard Bracer | common / bracer | Damage +5% | 80 / 10 | Awal |
| Cloudstep Boots | common / boots | Gerak +5% | 80 / 10 | Awal |
| Spirit Jade Pendant | common / pendant | XP +5% | 80 / 10 | Awal |
| Bamboo Weave Robe | rare / robe | HP +12; Gerak +2% | 200 / 30 | 2 |
| Jade Edge Bracer | rare / bracer | Damage +8%; Peluang kritis +1 poin persen | 200 / 30 | 2 |
| Miststride Boots | rare / boots | Gerak +8%; Radius pickup +12 | 200 / 30 | 2 |
| Qi Reservoir Pendant | rare / pendant | HP +2; XP +8% | 200 / 30 | 2 |
| Ward Keeper Robe | epic / robe | HP +16; Heal Blood Qi +0.25 HP | 450 / 75 | 3 |
| Stormcall Bracer | epic / bracer | Damage +10%; Peluang kritis +2.5 poin persen | 450 / 75 | 3 |
| Shadowstep Boots | epic / boots | Damage +2.5%; Gerak +10% | 450 / 75 | 3 |
| Shrine Seal Pendant | epic / pendant | XP +10%; Radius pickup +24 | 450 / 75 | 3 |
| Sovereign Mantle | legendary / robe | HP +18; Qi Shield awal +1 charge | 900 / 180 | 5 |
| Tribulation Bracer | legendary / bracer | Damage +12%; Peluang kritis +4 poin persen; Pengali kritis +0.15 | 900 / 180 | 5 |
| Cloudtreader Boots | legendary / boots | Gerak +12%; Radius pickup +48 | 900 / 180 | 5 |
| Ascendant Heart | legendary / pendant | XP +12%; Heal Blood Qi +0.5 HP | 900 / 180 | 5 |

Duplikat tambahan diubah per salinan: common **5**, rare **12**, epic **30**, legendary **75** pecahan. Stage 2–5 memberikan item yang sama pada repeat clear, sehingga berubah menjadi pecahan jika sudah dimiliki. Preview hadiah menghitung konversi tanpa mengubah save.

Bonus equipment dijumlahkan dalam jenisnya. Tambahan radius pickup dibatasi 72, tambahan heal Blood Qi 0,75 HP, tambahan multiplier kritis 0,15, dan shield awal satu charge. Heal tambahan hanya bekerja saat Blood Qi dimiliki. Continue memulihkan charge tersimpan, bukan memberikan shield awal lagi.

## Pemain, jurus, dan cultivation

- HP dasar arena tetap **100** melalui override scene; nilai default script 10 bukan HP awal arena ini. Vitality tetap +5 HP/level.
- Enam jurus aktif memiliki batas Level 7. Tiga jurus yang sebelumnya tidak dibatasi kini berhenti pada batas yang sama; level checkpoint dinormalisasi. Tiga resonance lama tetap memakai prasyaratnya.
- Permanent cultivation Vitality, Sword Power, Swift Qi tetap maksimal 10. Biaya level berikutnya `100 × (level saat ini + 1)`; total satu jalur dari 0 ke 10 = 5.500 Batu Roh. Sword Power tetap +0,10/level dan Swift Qi memakai faktor cooldown 0,95 per level serta minimum cooldown lama.
- Body Refinement tetap +2 HP/level; Qi Shield +1 charge/level; Iron Body tetap 5%/level maksimal 5; Blood Qi tetap heal dasar 1 HP dengan jumlah kill `20 − 2 × (level − 1)`, maksimal level 5.
- Magnet XP dasar radius 52; pickup mengecek target setiap 0,12 detik dan bergerak dengan kecepatan 310. Nilai pickup berlebih digabung ketika jumlah node mencapai 160.

## Sumber ekonomi lainnya

Meditasi Pavilion memberikan 20 Batu Roh sekali per tanggal lokal yang baru. Ada tiga quest aktif dari pool sembilan, dan 14 achievement. Reward kegagalan serta enam achievement lama tidak dinaikkan diam-diam; definisi tetap berada di RewardManager, AchievementManager, DailyQuestManager. Tidak ada gacha, paid revive, atau pembelian uang nyata. Jam perangkat masih menjadi sumber tanggal; tidak ada server anti-cheat.

## Yang harus diukur saat playtest

Catat waktu clear, level/jurus saat masuk boss, sumber damage terbanyak, kematian per trial, dan Batu Roh per menit untuk pemain baru serta pemain dengan equipment maksimum. Evaluasi jangkauan hazard pada layar kecil dan waktu yang diperlukan untuk membeli equipment/permanent cultivation. Jangan menyebut target FPS atau angka ekonomi sebagai hasil pengukuran sampai matriks perangkat diisi.
