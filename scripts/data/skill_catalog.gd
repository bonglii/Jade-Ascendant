extends RefCounted

## Shared presentation and resonance requirements; no progression mutations.

const SWORD_DAO_RESONANCE_REQUIRED_SPIRIT_SWORD_LEVEL: int = 3

const SWORD_DAO_RESONANCE_REQUIRED_SWORD_INTENT_LEVEL: int = 2

const YIN_YANG_REVERSAL_REQUIRED_BLADES_LEVEL: int = 3

const YIN_YANG_REVERSAL_REQUIRED_QI_SHIELD_LEVEL: int = 2

const HEAVENLY_TRIBULATION_REQUIRED_SWORD_RAIN_LEVEL: int = 3

const HEAVENLY_TRIBULATION_REQUIRED_THUNDER_LEVEL: int = 3

const WEAPON_UPGRADE_IDS: Array[String] = [
	"spirit_sword",
	"fire_orb",
	"thunder_talisman",
	"yin_yang_blades",
	"heavenly_sword_rain",
	"eight_trigrams_formation"
]

const RESONANCE_UPGRADE_IDS: Array[String] = [
	"sword_dao_resonance",
	"yin_yang_reversal",
	"heavenly_tribulation"
]

const ICON_PATHS: Dictionary = {
	"heavenweaver_compass":"res://assets/ui/liveops/odyssey/compass.png",
	"spirit_sword": "res://assets/ui/level_up/skill_art/spirit_sword.png",
	"fire_orb": "res://assets/ui/level_up/skill_art/fire_orb.png",
	"thunder_talisman": "res://assets/ui/level_up/skill_art/thunder_talisman.png",
	"yin_yang_blades": "res://assets/ui/level_up/skill_art/yin_yang_blades.png",
	"heavenly_sword_rain": "res://assets/ui/level_up/skill_art/heavenly_sword_rain.png",
	"eight_trigrams_formation": "res://assets/ui/level_up/skill_art/eight_trigrams_formation.png",
	"power": "res://assets/ui/level_up/skill_art/power.png",
	"attack_speed": "res://assets/ui/level_up/skill_art/attack_speed.png",
	"movement_speed": "res://assets/ui/level_up/skill_art/movement_speed.png",
	"body_refinement": "res://assets/ui/level_up/skill_art/body_refinement.png",
	"qi_shield": "res://assets/ui/level_up/skill_art/qi_shield.png",
	"spiritual_insight": "res://assets/ui/level_up/skill_art/spiritual_insight.png",
	"iron_body": "res://assets/ui/level_up/skill_art/iron_body.png",
	"blood_qi": "res://assets/ui/level_up/skill_art/blood_qi.png",
	"sword_intent": "res://assets/ui/level_up/skill_art/sword_intent.png",
	"sword_dao_resonance": "res://assets/ui/level_up/skill_art/v4/sword_dao_resonance.png",
	"yin_yang_reversal": "res://assets/ui/level_up/skill_art/yin_yang_reversal.png",
	"heavenly_tribulation": "res://assets/ui/level_up/skill_art/heavenly_tribulation.png"
}

const UPGRADE_IDS: Array[String] = [
	"spirit_sword",
	"fire_orb",
	"power",
	"attack_speed",
	"movement_speed",
	"body_refinement",
	"qi_shield",
	"thunder_talisman",
	"yin_yang_blades",
	"heavenly_sword_rain",
	"eight_trigrams_formation",
	"spiritual_insight",
	"iron_body",
	"blood_qi",
	"sword_intent",
	"sword_dao_resonance",
	"yin_yang_reversal",
	"heavenly_tribulation"
]

static func get_upgrade_display_name(upgrade_id: String) -> String:
	if upgrade_id == "heavenweaver_compass": return "Heavenweaver Compass"
	match upgrade_id:
		"spirit_sword":
			return "Spirit Sword"
		"fire_orb":
			return "Fire Orb"
		"power":
			return "Power"
		"attack_speed":
			return "Attack Speed"
		"movement_speed":
			return "Swift Qi"
		"body_refinement":
			return "Body Refinement"
		"qi_shield":
			return "Qi Shield"
		"thunder_talisman":
			return "Thunder Talisman"
		"yin_yang_blades":
			return "Yin-Yang Blades"
		"heavenly_sword_rain":
			return "Heavenly Sword Rain"
		"eight_trigrams_formation":
			return "Eight Trigrams Formation"
		"spiritual_insight":
			return "Spiritual Insight"
		"iron_body":
			return "Iron Body"
		"blood_qi":
			return "Blood Qi"
		"sword_intent":
			return "Sword Intent"
		"sword_dao_resonance":
			return "Sword Dao Resonance"
		"yin_yang_reversal":
			return "Yin-Yang Reversal"
		"heavenly_tribulation":
			return "Heavenly Tribulation"
	return upgrade_id


static func get_upgrade_description(upgrade_id: String) -> String:
	match upgrade_id:
		"spirit_sword":
			return "Milestones add a second sword and pierce."
		"fire_orb":
			return "Heavy flame orb; milestones empower Cinder Bloom."
		"power":
			return "Condense martial force to amplify all damage."
		"attack_speed":
			return "Shorten timed attacks. Chain and Glaive turn extra tempo at their casting limit into stronger hits. Orbit speed is unchanged."
		"movement_speed":
			return "Channel swift qi through the body to move faster."
		"body_refinement":
			return "Temper the body to expand vitality."
		"qi_shield":
			return "Block incoming hits with qi charges. A block starts 0.3s protection, so rapid hits during that window do not consume more charges."
		"thunder_talisman":
			return "Chain lightning; milestones reach more enemies."
		"yin_yang_blades":
			return "Wide 144px orbit: Lv.1/3/5/7 gives 2/3/4/6 blades. Lv.7 balances 3 Yin + 3 Yang. Shared target hit interval stays 0.5s; Reversal expands the orbit to 173px."
		"heavenly_sword_rain":
			return "Heavenly strikes; refine strike count and radius."
		"eight_trigrams_formation":
			return "Refine Bagua damage, radius, duration, and count."
		"spiritual_insight":
			return "Deepen comprehension for more battle EXP."
		"iron_body":
			return "Harden the body to reduce incoming damage."
		"blood_qi":
			return "Repeated kills restore HP more often."
		"sword_intent":
			return "Sharpen sword intent to raise critical chance."
		"sword_dao_resonance":
			return "Spirit Sword hits may launch a resonance sword."
		"yin_yang_reversal":
			return "Qi Shield blocks awaken an empowered orbit."
		"heavenly_tribulation":
			return "Sword Rain impacts may call Heavenly Lightning."
	return "Refine this cultivation path for the current run."


static func get_category(id: String) -> String:
	if WEAPON_UPGRADE_IDS.has(id): return "WEAPONS"
	if RESONANCE_UPGRADE_IDS.has(id): return "SYNERGIES"
	return "PASSIVES"

static func get_requirements(id: String) -> Dictionary:
	match id:
		"sword_dao_resonance":
			return {"spirit_sword": SWORD_DAO_RESONANCE_REQUIRED_SPIRIT_SWORD_LEVEL, "sword_intent": SWORD_DAO_RESONANCE_REQUIRED_SWORD_INTENT_LEVEL}
		"yin_yang_reversal":
			return {"yin_yang_blades": YIN_YANG_REVERSAL_REQUIRED_BLADES_LEVEL, "qi_shield": YIN_YANG_REVERSAL_REQUIRED_QI_SHIELD_LEVEL}
		"heavenly_tribulation":
			return {"heavenly_sword_rain": HEAVENLY_TRIBULATION_REQUIRED_SWORD_RAIN_LEVEL, "thunder_talisman": HEAVENLY_TRIBULATION_REQUIRED_THUNDER_LEVEL}
	return {}

static func get_related_synergies(id: String) -> Array[String]:
	var result: Array[String] = []
	for synergy: String in RESONANCE_UPGRADE_IDS:
		if get_requirements(synergy).has(id): result.append(synergy)
	return result

static func get_icon_path(upgrade_id: String, armament_id: String = "") -> String:
	# Pure resolver: actual run identity must be supplied by the caller.
	if upgrade_id == "spirit_sword" and not armament_id.is_empty():
		var visual: Script = load("res://scripts/ui/equipment_visual_catalog.gd")
		var path: String = visual.get_icon_path(armament_id)
		if not path.is_empty(): return path
	return str(ICON_PATHS.get(upgrade_id, ""))
