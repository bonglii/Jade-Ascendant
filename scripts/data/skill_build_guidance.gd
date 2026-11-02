extends RefCounted
## Pure presentation: no RNG, grants, equipment changes or availability decisions.
const Skills = preload("res://scripts/data/skill_catalog.gd")
const ROLES: Dictionary = {
	"spirit_sword": ["PRIMARY • Refine your equipped attack.", "UTAMA • Perkuat serangan senjata aktif."],
	"fire_orb": ["AREA BURST • Punish clustered enemies.", "LEDAKAN AREA • Hantam musuh berkelompok."],
	"thunder_talisman": ["CHAIN • Reach enemies beyond the first hit.", "RANTAI • Jangkau musuh di balik target awal."],
	"yin_yang_blades": ["ORBIT • Cover nearby threats while moving.", "ORBIT • Jaga area dekat sambil bergerak."],
	"heavenly_sword_rain": ["AREA STRIKES • Pressure groups from above.", "SERANGAN AREA • Tekan kelompok dari atas."],
	"eight_trigrams_formation": ["ZONE • Keep enemies inside the formation.", "ZONA • Tahan musuh di dalam formasi."],
	"power": ["DAMAGE • Supports your current attacks.", "DAMAGE • Memperkuat serangan yang dimiliki."],
	"attack_speed": ["TEMPO • Faster casts; orbit speed is unchanged.", "TEMPO • Cast lebih cepat; kecepatan orbit tetap."],
	"movement_speed": ["MOBILITY • Reposition and escape pressure.", "MOBILITAS • Atur posisi dan hindari kepungan."],
	"body_refinement": ["SURVIVAL • More maximum HP and a small heal.", "BERTAHAN • Tambah HP maksimum dan sedikit heal."],
	"qi_shield": ["BLOCK • Add protection against incoming hits.", "BLOK • Tambah perlindungan dari serangan."],
	"spiritual_insight": ["GROWTH • More EXP for later breakthroughs.", "PERTUMBUHAN • Tambah EXP untuk level berikutnya."],
	"iron_body": ["DEFENSE • Reduce damage from hits taken.", "PERTAHANAN • Kurangi damage yang diterima."],
	"blood_qi": ["RECOVERY • Kills trigger healing more often.", "PEMULIHAN • Kill memicu heal lebih sering."],
	"sword_intent": ["CRITICAL • Improve your critical-hit chance.", "KRITIS • Tambah peluang serangan kritis."],
	"sword_dao_resonance": ["SYNERGY READY • Empowers your primary attack.", "SINERGI SIAP • Perkuat serangan senjata utama."],
	"yin_yang_reversal": ["SYNERGY READY • Blocks empower the orbit.", "SINERGI SIAP • Blok memperkuat orbit."],
	"heavenly_tribulation": ["SYNERGY READY • Sword Rain can call lightning.", "SINERGI SIAP • Sword Rain dapat memicu petir."]
}

static func hint(id: String, levels: Dictionary, armament: String = "", indonesian: bool = false) -> String:
	var language: int = 1 if indonesian else 0
	# Pair hints appear only when the other prerequisite is already in the build.
	# Requirements come from the same catalog as production unlocks.
	for resonance: String in Skills.get_related_synergies(id):
		if int(levels.get(resonance, 0)) > 0:
			continue
		var requirements: Dictionary = Skills.get_requirements(resonance)
		var partner: String = ""
		for prerequisite: String in requirements:
			if prerequisite != id:
				partner = prerequisite
		if partner.is_empty() or int(levels.get(partner, 0)) <= 0:
			continue
		var short_names: Dictionary = {"spirit_sword":"Primary" if not indonesian else "Utama", "sword_intent":"Intent", "yin_yang_blades":"Blades", "qi_shield":"Shield", "heavenly_sword_rain":"Rain", "thunder_talisman":"Thunder"}
		var parts: Array[String] = []
		for prerequisite: String in requirements:
			parts.append("%s %d/%d" % [str(short_names[prerequisite]), mini(int(levels.get(prerequisite, 0)), int(requirements[prerequisite])), int(requirements[prerequisite])])
		return ("SINERGI • " if indonesian else "SYNERGY • ") + " + ".join(parts)
	if id == "spirit_sword":
		if armament == "jade_binding_chain":
			return ["CONTROL • Bind groups before knot judgment.", "KONTROL • Ikat kelompok sebelum knot judgment."][language]
		if armament == "celestial_returning_glaive":
			return ["RETURN PATH • Move to steer the returning blade.", "JALUR BALIK • Arahkan bilah lewat gerakanmu."][language]
	return str(ROLES.get(id, ["Refine your current build.", "Perkuat build saat ini."])[language])
