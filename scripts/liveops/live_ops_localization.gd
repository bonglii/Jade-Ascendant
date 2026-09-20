extends RefCounted

static var _installed: bool = false

const INDONESIAN: Dictionary = {
	"MAIL": "SURAT",
	"7-DAY": "7 HARI",
	"EVENTS": "EVENT",
	"TREASURY": "TREASURY",

	"LIVE SERVICES": "LAYANAN LANGIT",
	"Mailbox": "Kotak Surat",
	"Messages, gifts, and system notices from the Jade Sanctuary.": "Pesan, hadiah, dan pemberitahuan dari Pesanggrahan Giok.",
	"NO MAIL": "TIDAK ADA SURAT",
	"Your mailbox is empty.": "Kotak suratmu kosong.",
	"JADE SANCTUARY": "PESANGGRAHAN GIOK",
	"CELESTIAL PAVILION": "PAVILIUN LANGIT",
	"Welcome, Wandering Cultivator": "Selamat Datang, Kultivator Pengembara",
	"Your first steps on the immortal path have begun. Accept these supplies and prepare for the trials ahead.": "Langkah pertamamu di jalan keabadian telah dimulai. Terima bekal ini dan bersiap menghadapi ujian.",
	"Seven Days of Ascension": "Tujuh Hari Menuju Keabadian",
	"Return on seven active days to unlock newcomer supplies. Missed calendar days do not erase your progress.": "Kembali pada tujuh hari aktif untuk membuka bekal pemain baru. Hari kalender yang terlewat tidak menghapus progresmu.",
	"ATTACHMENT": "LAMPIRAN",
	"CLAIM ATTACHMENT": "AMBIL LAMPIRAN",
	"CLAIMED": "DIAMBIL",
	"READ": "DIBACA",
	"‹  HOME": "‹  BERANDA",

	"NEW CULTIVATOR EVENT": "EVENT KULTIVATOR BARU",
	"Seven active days. No calendar punishment. Your progress waits for you.": "Tujuh hari aktif. Tidak ada hukuman karena melewatkan hari kalender. Progresmu tetap menunggu.",
	"ACTIVE DAY %d / %d": "HARI AKTIF %d / %d",
	"DAY %d": "HARI %d",
	"AVAILABLE": "TERSEDIA",
	"LOCKED": "TERKUNCI",
	"CLAIM REWARD": "AMBIL HADIAH",
	"UNLOCKS ON ACTIVE DAY %d": "TERBUKA PADA HARI AKTIF %d",
	"ALL SEVEN DAYS COMPLETE": "TUJUH HARI SELESAI",
	"Your newcomer journey is complete. Keep ascending.": "Perjalanan pemain barumu selesai. Teruslah menapaki jalan keabadian.",

	"EVENT CENTER": "PUSAT EVENT",
	"Celestial Events": "Event Langit",
	"Live activities and returning-player reasons without cluttering the sanctuary.": "Aktivitas berkala dan alasan untuk kembali bermain tanpa memenuhi layar utama.",
	"NEW PLAYER": "PEMAIN BARU",
	"Open Seven Days": "BUKA TUJUH HARI",
	"DAILY": "HARIAN",
	"Daily Cultivation": "Kultivasi Harian",
	"Complete daily disciplines and settle available rewards.": "Selesaikan disiplin harian dan ambil hadiah yang tersedia.",
	"OPEN DAILY TRIALS": "BUKA UJIAN HARIAN",
	"OPTIONAL": "OPSIONAL",
	"Celestial Patronage": "Dukungan Langit",
	"Optional rewarded ads remain inside the Pavilion and never block progression.": "Iklan berhadiah opsional tetap berada di Paviliun dan tidak menghalangi progres.",
	"OPEN PAVILION": "BUKA PAVILIUN",
	"%d REWARD READY": "%d HADIAH SIAP",
	"%d REWARDS READY": "%d HADIAH SIAP",
	"COMPLETED": "SELESAI",

	"STORE PREVIEW": "PRATINJAU TOKO",
	"Celestial Treasury": "Treasury Langit",
	"Google Play prices will be localized by the store when Billing is connected.": "Harga Google Play akan mengikuti mata uang lokal saat Billing terhubung.",
	"DEBUG PREVIEW • PURCHASES DISABLED": "PRATINJAU DEBUG • PEMBELIAN DINONAKTIFKAN",
	"CURRENT BALANCE": "SALDO SAAT INI",
	"%d CELESTIAL JADE": "%d GIOK LANGIT",
	"%d PAVILION SEALS": "%d SEGEL PAVILIUN",
	"JADE POUCH": "KANTONG GIOK",
	"JADE SATCHEL": "TAS GIOK",
	"JADE CASKET": "PETI GIOK",
	"JADE VAULT": "BRANKAS GIOK",
	"JADE TREASURY": "TREASURY GIOK",
	"ASCENDANT RESERVE": "CADANGAN ASCENDANT",
	"STARTER SUPPORT PACK": "PAKET DUKUNGAN PEMULA",
	"MONTHLY JADE BLESSING": "BERKAH GIOK BULANAN",
	"%d JADE": "%d GIOK",
	"%d JADE + %d SEALS": "%d GIOK + %d SEGEL",
	"%d JADE NOW + %d/DAY • %d DAYS": "%d GIOK SEKARANG + %d/HARI • %d HARI",
	"BILLING NEXT": "BILLING BERIKUTNYA",
	"Prices are intentionally not hardcoded.": "Harga sengaja tidak ditulis langsung di dalam game.",
	"CELESTIAL TREASURY": "TREASURY LANGIT",
	"Prices are loaded directly from Google Play. No price is hardcoded.": "Harga dimuat langsung dari Google Play. Tidak ada harga yang ditulis manual.",
	"GOOGLE PLAY BILLING • CHECKING": "GOOGLE PLAY BILLING • MEMERIKSA",
	"GOOGLE PLAY BILLING • READY": "GOOGLE PLAY BILLING • SIAP",
	"GOOGLE PLAY BILLING • %s": "GOOGLE PLAY BILLING • %s",
	"Purchases are optional and do not block progression.": "Pembelian bersifat opsional dan tidak menghalangi progres.",
	"RESTORE PURCHASES": "PULIHKAN PEMBELIAN",
	"PRICE FROM GOOGLE PLAY": "HARGA DARI GOOGLE PLAY",
	"CHECKING STORE...": "MEMERIKSA TOKO...",
	"COMING LATER • PURCHASE FLOW NOT ENABLED YET": "SEGERA HADIR • ALUR PEMBELIAN BELUM DIAKTIFKAN",
	"NOT AVAILABLE YET": "BELUM TERSEDIA",
	"COMING LATER": "SEGERA HADIR",
	"OWNED": "SUDAH DIMILIKI",
	"PURCHASED": "SUDAH DIBELI",
	"PURCHASE • %s": "BELI • %s",
	"OPENING GOOGLE PLAY...": "MEMBUKA GOOGLE PLAY...",
	"Waiting for Google Play purchase result...": "Menunggu hasil pembelian dari Google Play...",
	"Purchase is not available right now.": "Pembelian belum tersedia saat ini.",
	"Checking Google Play for recoverable purchases...": "Memeriksa pembelian yang dapat dipulihkan dari Google Play...",
	"PURCHASE SAVED • REWARD DELIVERED": "PEMBELIAN TERSIMPAN • HADIAH DITERIMA",
	"UNAVAILABLE": "TIDAK TERSEDIA",
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
