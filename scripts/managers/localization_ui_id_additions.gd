extends RefCounted

## Pre-RC Indonesian localization completeness layer.
## Additive only: proper names (Lin Yue, Jade Ascendant, weapon/item/realm names)
## stay unchanged while player-facing UI copy receives Indonesian coverage.
static var _installed: bool = false

const INDONESIAN: Dictionary = {
	# Shared / recovery
	"SAVE RECOVERY REQUIRED": "PEMULIHAN SAVE DIPERLUKAN",

	# Settings
	"COMFORT": "KENYAMANAN",
	"Combat Presentation": "Presentasi Pertempuran",
	"Tune motion and combat feedback without changing game balance.": "Sesuaikan gerakan dan umpan balik pertempuran tanpa mengubah keseimbangan game.",
	"Reduced flashes & effects": "Kurangi kilatan & efek",
	"Vibration feedback": "Umpan balik getaran",
	"SYSTEM": "SISTEM",
	"Display & Language": "Tampilan & Bahasa",
	"Choose the performance target and interface language for this device.": "Pilih target performa dan bahasa antarmuka untuk perangkat ini.",
	"60 FPS  •  SMOOTH": "60 FPS  •  HALUS",
	"30 FPS  •  BATTERY SAVER": "30 FPS  •  HEMAT BATERAI",
	"PRIVACY, SUPPORT & CREDITS": "PRIVASI, BANTUAN & KREDIT",

	# Journey / realm / stage selection
	"CURRENT CULTIVATION PATH": "JALUR KULTIVASI SAAT INI",
	"Choose a realm above to inspect its trials and continue the journey.": "Pilih alam di atas untuk melihat ujiannya dan melanjutkan perjalanan.",
	"Unlocked realms can be revisited  •  Cleared progress is permanent": "Alam yang terbuka dapat diulang  •  Progres yang tuntas bersifat permanen",
	"Realm data is unavailable.": "Data alam tidak tersedia.",
	"NO PROGRESS DATA": "TIDAK ADA DATA PROGRES",
	"CLEARED %d/%d   •   UNLOCKED %d/%d": "TUNTAS %d/%d   •   TERBUKA %d/%d",
	"REALM %02d  •  CLEARED %d/%d  •  UNLOCKED %d/%d": "ALAM %02d  •  TUNTAS %d/%d  •  TERBUKA %d/%d",
	"FINAL ENCOUNTER": "PERTARUNGAN TERAKHIR",
	"REPLAY AVAILABLE": "DAPAT DIULANG",
	"REPLAY REWARD": "HADIAH PENGULANGAN",
	"SELECT REALM": "PILIH ALAM",
	"ASCENSION REALMS": "ALAM KEABADIAN",
	"PERMANENT JOURNEY": "PERJALANAN PERMANEN",
	"REWARD": "HADIAH",
	"CHAPTER 01": "BAB 01",
	"0 / 5 COMPLETE": "0 / 5 SELESAI",

	# Backpack / equipment
	"RELIC CODEX  %d / %d": "KODEKS RELIK  %d / %d",
	"Use Refinement Shards to forge or ascend equipment.": "Gunakan Pecahan Pemurnian untuk menempa atau menaikkan bintang perlengkapan.",
	"CORE PASSIVE  •  %s": "PASIF INTI  •  %s",
	"BACKPACK  •  CULTIVATION COLLECTION": "TAS  •  KOLEKSI KULTIVASI",
	"OWNED 0 UNIQUE  •  0 TOTAL": "DIMILIKI 0 UNIK  •  0 TOTAL",
	"EQUIPPED 0 / 5": "TERPASANG 0 / 5",
	"RELIC CODEX  0 / 25": "KODEKS RELIK  0 / 25",
	"RELIC VAULT  •  TAP TO INSPECT": "BRANKAS RELIK  •  KETUK UNTUK MEMERIKSA",
	"No items match this filter.": "Tidak ada item yang sesuai filter ini.",
	"SIGNATURE EFFECT": "EFEK KHAS",
	"NEXT CORE PASSIVE\nPREVIEW": "PASIF INTI BERIKUT\nPRATINJAU",
	"Core passive increases; Signature Effect stays fixed.": "Pasif inti meningkat; Efek Khas tetap.",
	"MARTIAL LOADOUT  •  ASCENSION PATH": "PERLENGKAPAN BELA DIRI  •  JALAN KEABADIAN",
	"WANDERING CULTIVATOR  •  JADE PATH": "KULTIVATOR PENGEMBARA  •  JALAN GIOK",
	"JADE WANDERER  •  QI ATTUNEMENT": "PENGEMBARA GIOK  •  PENYELARASAN QI",
	"ARSENAL  •  TAP TO INSPECT": "ARSENAL  •  KETUK UNTUK MEMERIKSA",
	"ROBE  •  BODY WARD": "JUBAH  •  PERLINDUNGAN TUBUH",
	"ITEM NAME": "NAMA ITEM",
	"RARITY  •  STARS  •  CORE PASSIVE": "RARITAS  •  BINTANG  •  PASIF INTI",
	"LOADOUT IMPACT  •  NO CHANGE": "DAMPAK LOADOUT  •  TIDAK BERUBAH",
	"★☆☆☆☆  →  ★★☆☆☆\nSHARDS  0 / 0": "★☆☆☆☆  →  ★★☆☆☆\nPECAHAN  0 / 0",

	# Trials / achievements / daily
	"Permanent milestones across combat, cultivation and the journey.": "Tonggak permanen dalam pertempuran, kultivasi, dan perjalanan.",
	"%d OF %d RECORDS DISCOVERED": "%d DARI %d CATATAN DITEMUKAN",
	"CLAIM ALL  •  %d": "AMBIL SEMUA  •  %d",
	"ALL REWARDS SETTLED": "SEMUA HADIAH TELAH DIAMBIL",
	"No eternal records are available yet.": "Belum ada catatan abadi.",
	"PERMANENT RECORD": "CATATAN PERMANEN",
	"CLAIM": "AMBIL",
	"LOCAL CYCLE": "SIKLUS LOKAL",
	"NO REWARDS READY": "BELUM ADA HADIAH SIAP",
	"Daily disciplines complete. Settle any remaining rewards before the local cycle resets.": "Disiplin harian selesai. Ambil hadiah tersisa sebelum siklus lokal direset.",
	"Complete today's disciplines to advance the daily cultivation cycle.": "Selesaikan disiplin hari ini untuk memajukan siklus kultivasi harian.",
	"No daily disciplines are active for this cycle.": "Tidak ada disiplin harian aktif untuk siklus ini.",
	"DAILY DISCIPLINE": "DISIPLIN HARIAN",
	"TRIAL HALL": "BALAI UJIAN",
	"CULTIVATION RECORDS": "CATATAN KULTIVASI",
	"ETERNAL ARCHIVE  •  PERMANENT MILESTONES": "ARSIP ABADI  •  TONGGAK PERMANEN",
	"Eternal Records": "Catatan Abadi",
	"Permanent milestones across the cultivation journey.": "Tonggak permanen sepanjang perjalanan kultivasi.",
	"STONES": "BATU ROH",
	"ETERNAL RECORD COMPLETION": "PENYELESAIAN CATATAN ABADI",
	"0 OF 0 RECORDS DISCOVERED": "0 DARI 0 CATATAN DITEMUKAN",
	"DAILY CULTIVATION  •  LOCAL CYCLE": "KULTIVASI HARIAN  •  SIKLUS LOKAL",
	"Daily Disciplines": "Disiplin Harian",
	"COMPLETE": "SELESAI",
	"0 / 3 COMPLETE": "0 / 3 SELESAI",

	# Game over / tutorial
	"RECOVERY RESULT": "HASIL PEMULIHAN",
	"DAO ESSENCE COULD NOT BE RECOVERED": "ESENSI DAO TIDAK DAPAT DIPULIHKAN",
	"CHOOSE 1 CULTIVATION PATH": "PILIH 1 JALUR KULTIVASI",
	"TOUCH & DRAG TO MOVE": "SENTUH & GESER UNTUK BERGERAK",
	"STAY MOBILE • WEAPONS AUTO-CAST": "TERUS BERGERAK • SENJATA MENYERANG OTOMATIS",
	"COLLECT ESSENCE • FILL EXP": "KUMPULKAN ESENSI • ISI EXP",
	"FILL EXP TO BREAK THROUGH": "PENUHI EXP UNTUK MENEMBUS BATAS",

	# Pavilion economy / summon
	"Spirit Stone": "Batu Roh",
	"Celestial Jade": "Giok Langit",
	"Pavilion Seal": "Segel Paviliun",
	"Sanctum of Refinement": "Ruang Suci Pemurnian",
	"Cultivate, forge, and call equipment from the Celestial Pavilion.": "Berkultivasi, menempa, dan memanggil perlengkapan dari Paviliun Langit.",
	"NO WISH TARGET": "TANPA TARGET WISH",
	"SUMMON ×10": "PANGGIL ×10",
	"SUMMON ×1": "PANGGIL ×1",
	"DROP RATES & PITY RULES": "PELUANG DROP & ATURAN PITY",
	"DAILY RESONANCE": "RESONANSI HARIAN",
	"MEDITATE • +20 SPIRIT STONES": "MEDITASI • +20 BATU ROH",
	"COSMETIC ATTUNEMENT": "PENYELARASAN KOSMETIK",
	"Realm-clear auras are free. Prestige auras use earned currencies only and never add combat power.": "Aura dari penyelesaian alam gratis. Aura prestise memakai mata uang hasil bermain dan tidak menambah kekuatan tempur.",
	"DETERMINISTIC SAFETY NET": "JAMINAN DETERMINISTIK",
	"Common/Rare may use Spirit Stones. Epic/Legendary use Summon or Refinement Shard forging.": "Perlengkapan Umum/Langka dapat memakai Batu Roh. Epik/Legendaris memakai Panggilan atau tempa Pecahan Pemurnian.",
	"RARITY": "RARITAS",
	"PLAYER-FIRST ECONOMY": "EKONOMI BERPIHAK PADA PEMAIN",
	"Odds visible • Forge safety net • No forced purchase": "Peluang transparan • Jaminan tempa • Tanpa pembelian paksa",
	"QUEST CADENCE %d/%d • +%d JADE/DAY\n7TH ACTIVE DAY • +%d JADE +%d SEALS": "RITME QUEST %d/%d • +%d GIOK/HARI\nHARI AKTIF KE-7 • +%d GIOK +%d SEGEL",
	"SAVE RECOVERY REQUIRED • REOPEN THE GAME BEFORE CHANGING ECONOMY STATE": "PEMULIHAN SAVE DIPERLUKAN • BUKA ULANG GAME SEBELUM MENGUBAH EKONOMI",
	"FORGE SEALED DURING ACTIVE GAMEPLAY • SUMMON OWNERSHIP REMAINS PERMANENT": "PENEMPAAN TERKUNCI SELAMA GAMEPLAY AKTIF • KEPEMILIKAN HASIL PANGGILAN TETAP PERMANEN",
	"LOCKED • CLEAR 1-%d": "TERKUNCI • TUNTASKAN 1-%d",
	"SUMMON UNLOCKS AFTER CLEARING CHAPTER %d • STAGE %d": "PANGGILAN TERBUKA SETELAH MENUNTASKAN BAB %d • UJIAN %d",
	"SUMMON UNLOCKS AFTER 1-%d": "PANGGILAN TERBUKA SETELAH 1-%d",
	"CLEAR CHAPTER %d • STAGE %d TO UNLOCK SUMMON": "TUNTASKAN BAB %d • UJIAN %d UNTUK MEMBUKA PANGGILAN",
	"Rare+ ≤10 • Epic+ ≤30 • Legendary ≤50 once a Legendary pool is unlocked.": "Langka+ ≤10 • Epik+ ≤30 • Legendaris ≤50 setelah pool Legendaris terbuka.",
	"Wish: natural Legendary has 50% target preference. One miss activates Wish Fate; the next Legendary is guaranteed to be that target. Changing the target clears Fate.": "Wish: Legendaris alami memiliki preferensi target 50%. Sekali meleset mengaktifkan Takdir Wish; Legendaris berikutnya dijamin menjadi target tersebut. Mengganti target menghapus Takdir.",
	"Current rates reflect your unlocked pool. Missing rarity chance is redistributed to the nearest available rarity.": "Peluang saat ini mengikuti pool yang telah terbuka. Peluang raritas yang belum tersedia dialihkan ke raritas terdekat yang tersedia.",
	"Legendary pity is paused until a Legendary equipment item is progression-unlocked.": "Pity Legendaris dijeda sampai perlengkapan Legendaris terbuka melalui progres.",
	"HIDE DROP RATES": "SEMBUNYIKAN PELUANG DROP",
	"Initiate Gift claimed • +10 Pavilion Seals.": "Hadiah Inisiasi diambil • +10 Segel Paviliun.",
	"%d Celestial Jade": "%d Giok Langit",
	"%d Pavilion Seal%s": "%d Segel Paviliun%s",
	"Summon complete • %s": "Panggilan selesai • %s",
	" • +%d Refinement Shards": " • +%d Pecahan Pemurnian",
	"Legendary Wish cleared.": "Wish Legendaris dihapus.",
	"Legendary Wish set • %s": "Wish Legendaris dipasang • %s",
	"ATTUNED ✓": "SELARAS ✓",
	"OWNED • ATTUNE": "DIMILIKI • SELARASKAN",
	"CLEAR %d-%d": "TUNTASKAN %d-%d",
	"REQUIRES %s": "MEMERLUKAN %s",
	"%d STONES + %d SHARDS": "%d BATU ROH + %d PECAHAN",
	"OWNED • EQUIP FROM HERO": "DIMILIKI • PASANG DARI HERO",
	"LOCKED • CLEAR %d-%d": "TERKUNCI • TUNTASKAN %d-%d",
	"%d STONES": "%d BATU ROH",
	"%d SHARDS": "%d PECAHAN",
	"SUMMON • OR FORGE": "PANGGIL • ATAU TEMPA",
	"FORGE • %d SHARDS": "TEMPA • %d PECAHAN",
	"Aura attuned.": "Aura diselaraskan.",

	# Privacy / credits section headings not covered by feature-local copy
	"PLAYER TRUST": "KEPERCAYAAN PEMAIN",
	"Privacy & Support": "Privasi & Bantuan",
	"DATA CONTROL": "KONTROL DATA",
	"OPTIONAL FEEDBACK": "UMPAN BALIK OPSIONAL",
	"EXTERNAL APPS": "APLIKASI EKSTERNAL",
	"Links & support": "Tautan & bantuan",
	"SUPPORT": "BANTUAN",
	"ARCHIVE": "ARSIP",
	"Credits & Licenses": "Kredit & Lisensi",
	"Jade Ascendant • Open-source notices and acknowledgements": "Jade Ascendant • Pemberitahuan sumber terbuka dan ucapan terima kasih",
	"BACK TO PRIVACY": "KEMBALI KE PRIVASI",
}


static func install() -> void:
	if _installed:
		return

	var translation := Translation.new()
	translation.locale = "id"

	for raw_message_id in INDONESIAN:
		var message_id: String = str(raw_message_id)
		translation.add_message(
			message_id,
			str(INDONESIAN[message_id])
		)

	TranslationServer.add_translation(translation)
	_installed = true
