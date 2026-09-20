extends RefCounted

## Feature-local Indonesian copy for AdMob/UMP surfaces.
## This is intentionally additive to the mature global localization catalog.
static var _installed: bool = false

const INDONESIAN: Dictionary = {
	"OPTIONAL REWARDED AD": "IKLAN BERHADIAH OPSIONAL",
	"WATCH AD • 2×": "TONTON IKLAN • 2×",
	"CLAIM 1×": "KLAIM 1×",
	"2× CLAIMED TODAY": "2× SUDAH DIKLAIM HARI INI",
	"2× AD • PREPARING": "IKLAN 2× • MENYIAPKAN",
	"2× AD UNAVAILABLE": "IKLAN 2× TIDAK TERSEDIA",
	"2× AFTER 10M": "2× SETELAH 10M",
	"2× AD • %dS": "IKLAN 2× • %dDTK",
	"AD PLAYING...": "IKLAN BERJALAN...",
	"Optional ad doubles this claim only • free 1× claim remains available.": "Iklan opsional hanya menggandakan klaim ini • klaim gratis 1× tetap tersedia.",
	"Watch the optional ad to receive exactly 2× the reward shown above.": "Tonton iklan opsional untuk menerima tepat 2× hadiah yang ditampilkan di atas.",
	"Ad closed before reward. Free 1× claim is still available.": "Iklan ditutup sebelum hadiah. Klaim gratis 1× masih tersedia.",
	"2× REWARD CLAIMED": "HADIAH 2× DIKLAIM",
	"CULTIVATION CLAIMED": "MEDITASI BERHASIL DIKLAIM",
	"REWARDS RECEIVED": "HADIAH DITERIMA",
	"Saved to your cultivation progress.": "Tersimpan ke progres kultivasimu.",
	"CONTINUE": "LANJUTKAN",
	"REVIVE • WATCH AD": "BANGKIT • TONTON IKLAN",
	"REVIVE USED": "BANGKIT SUDAH DIPAKAI",
	"REVIVE • PREPARING": "BANGKIT • MENYIAPKAN",
	"REVIVE UNAVAILABLE": "BANGKIT TIDAK TERSEDIA",
	"REVIVING...": "SEDANG BANGKIT...",
	"DAO HEART SHAKEN • REVIVE WINDOW": "HATI DAO TERGUNCANG • KESEMPATAN BANGKIT",
	"RECOVERY IF RUN ENDS": "HADIAH JIKA SESI DIAKHIRI",
	"RECOVERY PREVIEW": "PRATINJAU HADIAH",
	"Revive keeps this run. Retry starts the stage over. Return Home ends the run.": "Bangkit melanjutkan sesi ini. Coba Lagi mengulang ujian dari awal. Kembali ke Beranda mengakhiri sesi.",
	"Watch the optional ad to revive at 60% HP with brief protection.": "Tonton iklan opsional untuk bangkit dengan 60% HP dan perlindungan singkat.",
	"Rewarded revive is not available for this run.": "Bangkit berhadiah tidak tersedia untuk sesi ini.",
	"Rewarded revive failed. You can still Retry or Return Home.": "Bangkit berhadiah gagal. Kamu masih bisa Coba Lagi atau Kembali ke Beranda.",
	"Ad closed before revive. Retry and Return Home remain available.": "Iklan ditutup sebelum bangkit. Coba Lagi dan Kembali ke Beranda tetap tersedia.",
	"Run end could not be saved. Please try again.": "Akhir sesi belum dapat disimpan. Silakan coba lagi.",
	"Celestial Patronage": "Dukungan Langit",
	"Watch one optional rewarded ad to receive 1 Pavilion Seal. Reward is granted only after completion.": "Tonton satu iklan berhadiah opsional untuk menerima 1 Segel Paviliun. Hadiah hanya diberikan setelah iklan selesai.",
	"WATCH AD • +1 PAVILION SEAL": "TONTON IKLAN • +1 SEGEL PAVILIUN",
	"WATCH OPTIONAL AD • +1 PAVILION SEAL": "TONTON IKLAN OPSIONAL • +1 SEGEL PAVILIUN",
	"CLAIMED TODAY": "SUDAH DIAMBIL HARI INI",
	"%d / %d rewarded Seals remain this cycle": "%d / %d Segel berhadiah tersisa pada siklus ini",
	"NO REWARDED SEALS AVAILABLE": "TIDAK ADA SEGEL BERHADIAH TERSEDIA",
	"This cycle has no rewarded Seal claims remaining.": "Tidak ada klaim Segel berhadiah yang tersisa pada siklus ini.",
	"You already claimed today's rewarded Seal. Come back tomorrow.": "Segel berhadiah hari ini sudah diambil. Kembali lagi besok.",
	"REWARDED AD COOLING DOWN": "IKLAN BERHADIAH SEDANG JEDA",
	"Please wait briefly before requesting another rewarded ad.": "Tunggu sebentar sebelum meminta iklan berhadiah berikutnya.",
	"Preparing rewarded ad availability. This may take a moment.": "Menyiapkan iklan berhadiah. Proses ini mungkin membutuhkan sedikit waktu.",
	"REWARDED SEAL CLAIMED TODAY": "SEGEL IKLAN SUDAH DIAMBIL HARI INI",
	"REWARD PREPARING...": "HADIAH SEDANG DISIAPKAN...",
	"CYCLE LIMIT REACHED": "BATAS SIKLUS TERCAPAI",
	"SAVE RECOVERY REQUIRED": "PEMULIHAN SAVE DIPERLUKAN",
	"SUMMON LOCKED": "PANGGILAN TERKUNCI",
	"READY • OPTIONAL": "SIAP • OPSIONAL",
	"COOLDOWN • %d SEC": "JEDA • %d DETIK",
	"%d / %d REWARDED SEALS REMAIN THIS CYCLE": "%d / %d SEGEL IKLAN TERSISA PADA SIKLUS INI",
	"Once per day • up to 3 rewarded Seals per 7 active-day cycle.": "Sekali per hari • maksimal 3 Segel berhadiah per siklus 7 hari aktif.",
	"Reward granted. +%d Pavilion Seal.": "Hadiah diterima. +%d Segel Paviliun.",
	"Ad closed before reward. No Pavilion Seal granted.": "Iklan berakhir sebelum hadiah. Tidak ada Segel Paviliun yang diberikan.",
	"Rewarded ad unavailable. Try again shortly.": "Iklan berhadiah belum tersedia. Coba lagi sebentar.",
	"Reward could not be saved. Restart the game before watching another ad.": "Hadiah belum dapat disimpan. Mulai ulang game sebelum menonton iklan lain.",
	"REWARDED ADS UNAVAILABLE": "IKLAN BERHADIAH TIDAK TERSEDIA",
	"Reward is granted only after the ad confirms completion.": "Hadiah hanya diberikan setelah iklan mengonfirmasi penyelesaian.",
	"Your progress stays on your device.": "Progres permainan tetap tersimpan di perangkatmu.",
	"LOCAL GAME SAVE": "SAVE GAME LOKAL",
	"What stays on device": "Data yang tetap di perangkat",
	"Progress, equipment, achievements, daily trials, run checkpoints, and preferences are stored locally. Jade Ascendant has no player account or cloud save.": "Progres, perlengkapan, pencapaian, ujian harian, checkpoint sesi, dan preferensi disimpan secara lokal. Jade Ascendant tidak memiliki akun pemain atau cloud save.",
	"OPTIONAL REWARDED ADS": "IKLAN BERHADIAH OPSIONAL",
	"Google Mobile Ads & privacy": "Google Mobile Ads & privasi",
	"Optional means optional": "Opsional berarti tidak wajib",
	"On Android, optional rewarded ads use Google Mobile Ads. Google may process IP address, ad or device identifiers, ad interactions, and diagnostic information for advertising, analytics, and fraud prevention. UMP may present privacy choices where required.": "Di Android, iklan berhadiah opsional menggunakan Google Mobile Ads. Google dapat memproses alamat IP, ID iklan atau perangkat, interaksi iklan, dan informasi diagnostik untuk periklanan, analisis, serta pencegahan penipuan. UMP dapat menampilkan pilihan privasi jika diwajibkan.",
	"Rewarded ads are optional. No gameplay progress is removed for declining or not completing an ad, and a reward is granted only after the ad confirms completion.": "Iklan berhadiah bersifat opsional. Progres permainan tidak dikurangi jika pemain menolak atau tidak menyelesaikan iklan, dan hadiah hanya diberikan setelah iklan mengonfirmasi penyelesaian.",
	"AD PRIVACY OPTIONS": "PILIHAN PRIVASI IKLAN",
	"Privacy choices are provided by Google UMP when required for this device or region.": "Pilihan privasi disediakan oleh Google UMP jika diwajibkan untuk perangkat atau wilayah ini.",
	"Local progress can be removed from Android app storage or by uninstalling the game. Advertising and consent data handled by Google is governed separately by Google's services and your applicable privacy choices.": "Progres lokal dapat dihapus melalui penyimpanan aplikasi Android atau dengan mencopot game. Data iklan dan persetujuan yang ditangani Google diatur secara terpisah oleh layanan Google dan pilihan privasi yang berlaku.",
	"This version has no player account, cloud save, or real-money purchase flow.": "Versi ini tidak memiliki akun pemain, cloud save, atau alur pembelian dengan uang nyata."
}


static func install() -> void:
	if _installed:
		return
	var translation := Translation.new()
	translation.locale = "id"
	for raw_message_id in INDONESIAN:
		var message_id: String = str(raw_message_id)
		translation.add_message(message_id, str(INDONESIAN[message_id]))
	TranslationServer.add_translation(translation)
	_installed = true
