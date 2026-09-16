extends RefCounted

## Presentation grouping and conservative gameplay resonance for the permanent equipment collection.
## Gameplay bonuses are derived from equipped IDs only; no save fields are required.
##
## Resonance tiers used by runtime presentation and gameplay:
## 0-1 pieces: no set aura / no gameplay bonus
## 2 pieces: awakened trace
## 3 pieces: stable resonance
## 4 pieces: strong resonance
## 5 pieces: full resonance

const SET_ORDER: Array[String] = [
	"verdant_wanderer",
	"mistbound_disciple",
	"moon_seal",
	"crimson_shadow",
	"nine_heavens",
	"jade_bastion",
	"stillwater_mirror",
	"solar_meridian"
]

const SETS: Dictionary = {
	"verdant_wanderer": {
		"display_name": "VERDANT WANDERER",
		"items": [
			"wanderer_jade_jian",
			"verdant_qi_robe",
			"jade_guard_bracer",
			"cloudstep_boots",
			"spirit_jade_pendant"
		]
	},
	"mistbound_disciple": {
		"display_name": "MISTBOUND DISCIPLE",
		"items": [
			"mistveil_jian",
			"bamboo_weave_robe",
			"jade_edge_bracer",
			"miststride_boots",
			"qi_reservoir_pendant"
		]
	},
	"moon_seal": {
		"display_name": "MOON-SEAL CONSTELLATION",
		"items": [
			"spirit_seal_fan",
			"moonthread_robe",
			"mirror_edge_bracer",
			"starstep_boots",
			"shrine_seal_pendant"
		]
	},
	"crimson_shadow": {
		"display_name": "CRIMSON SHADOW",
		"items": [
			"cinnabar_moon_saber",
			"ward_keeper_robe",
			"stormcall_bracer",
			"shadowstep_boots",
			"sword_heart_pendant"
		]
	},
	"nine_heavens": {
		"display_name": "NINE HEAVENS ASCENDANT",
		"items": [
			"nine_heavens_star_sword",
			"sovereign_mantle",
			"tribulation_bracer",
			"cloudtreader_boots",
			"ascendant_heart"
		]
	},
	"jade_bastion": {
		"display_name": "JADE BASTION",
		"items": [
			"mountain_ward_jian",
			"stone_meridian_robe",
			"earthseal_bracer",
			"rootstep_boots",
			"guardian_jade_pendant"
		]
	},
	"stillwater_mirror": {
		"display_name": "STILLWATER MIRROR",
		"items": [
			"stillwater_mirror_blade",
			"glassmoon_robe",
			"reflection_bracer",
			"silent_ripple_boots",
			"mirror_heart_pendant"
		]
	},
	"solar_meridian": {
		"display_name": "SOLAR MERIDIAN",
		"items": [
			"sunfire_dragon_jian",
			"dawn_meridian_robe",
			"solar_edict_bracer",
			"sunstride_boots",
			"golden_core_pendant"
		]
	}
}

# Each tier is incremental. A 5-piece set receives the 2/3/4/5 bonuses combined.
# Values stay intentionally small because individual equipment already contributes stats.
const SET_IDENTITIES: Dictionary = {
	"verdant_wanderer": "Balanced survival • healing • mobility",
	"mistbound_disciple": "Mobile tempo • cooldown • moving damage",
	"moon_seal": "Growth • critical precision • recovery",
	"crimson_shadow": "Low-HP aggression • critical damage",
	"nine_heavens": "Endgame tempo • damage • critical precision",
	"jade_bastion": "Defense • shield • sustain",
	"stillwater_mirror": "Stationary precision • critical burst",
	"solar_meridian": "High-HP mastery • offense • tempo"
}

const TIER_DESCRIPTIONS: Dictionary = {
	"verdant_wanderer": {
		2: "+4 Max HP",
		3: "+2% Movement",
		4: "+0.10 Blood Qi healing",
		5: "+0.75 Level-up healing"
	},
	"mistbound_disciple": {
		2: "+2% Movement",
		3: "-2% Weapon-art cooldown",
		4: "+2% Damage while moving",
		5: "+1% Movement • -1% Weapon-art cooldown"
	},
	"moon_seal": {
		2: "+2.5% EXP",
		3: "+1% Critical chance",
		4: "+0.5 Level-up healing",
		5: "+1.5% EXP • +0.5% Critical chance"
	},
	"crimson_shadow": {
		2: "+1.5% Damage",
		3: "+3% Damage at ≤50% HP",
		4: "+1.5% Critical chance at ≤50% HP",
		5: "+6% Critical damage"
	},
	"nine_heavens": {
		2: "+1% Damage",
		3: "-1.5% Weapon-art cooldown",
		4: "+0.75% Critical chance",
		5: "+2% EXP"
	},
	"jade_bastion": {
		2: "+5 Max HP",
		3: "+1 Starting Qi Shield",
		4: "+0.10 Blood Qi healing",
		5: "+0.75 Level-up healing"
	},
	"stillwater_mirror": {
		2: "+1% Critical chance",
		3: "+4% Damage while stationary",
		4: "+5% Critical damage",
		5: "-1.5% Weapon-art cooldown"
	},
	"solar_meridian": {
		2: "+1% Damage",
		3: "+4% Damage at ≥80% HP",
		4: "+1% Critical chance",
		5: "-2% Weapon-art cooldown"
	}
}

const GAMEPLAY_TIERS: Dictionary = {
	"verdant_wanderer": {
		2: {"max_health_flat": 4.0},
		3: {"movement_speed_bonus": 0.02},
		4: {"blood_qi_heal_bonus": 0.10},
		5: {"level_up_heal_flat": 0.75}
	},
	"mistbound_disciple": {
		2: {"movement_speed_bonus": 0.02},
		3: {"attack_cooldown_reduction": 0.02},
		4: {"moving_damage_bonus": 0.02},
		5: {
			"movement_speed_bonus": 0.01,
			"attack_cooldown_reduction": 0.01
		}
	},
	"moon_seal": {
		2: {"experience_bonus": 0.025},
		3: {"critical_chance_bonus": 0.01},
		4: {"level_up_heal_flat": 0.50},
		5: {
			"experience_bonus": 0.015,
			"critical_chance_bonus": 0.005
		}
	},
	"crimson_shadow": {
		2: {"damage_bonus": 0.015},
		3: {"low_health_damage_bonus": 0.03},
		4: {"low_health_critical_chance_bonus": 0.015},
		5: {"critical_damage_bonus": 0.06}
	},
	"nine_heavens": {
		2: {"damage_bonus": 0.01},
		3: {"attack_cooldown_reduction": 0.015},
		4: {"critical_chance_bonus": 0.0075},
		5: {"experience_bonus": 0.02}
	},
	"jade_bastion": {
		2: {"max_health_flat": 5.0},
		3: {"starting_shield_charges": 1.0},
		4: {"blood_qi_heal_bonus": 0.10},
		5: {"level_up_heal_flat": 0.75}
	},
	"stillwater_mirror": {
		2: {"critical_chance_bonus": 0.01},
		3: {"stationary_damage_bonus": 0.04},
		4: {"critical_damage_bonus": 0.05},
		5: {"attack_cooldown_reduction": 0.015}
	},
	"solar_meridian": {
		2: {"damage_bonus": 0.01},
		3: {"high_health_damage_bonus": 0.04},
		4: {"critical_chance_bonus": 0.01},
		5: {"attack_cooldown_reduction": 0.02}
	}
}

static func get_set_data(set_id: String) -> Dictionary:
	if not SETS.has(set_id):
		return {}
	return (SETS[set_id] as Dictionary).duplicate(true)

static func get_display_name(set_id: String) -> String:
	return str(get_set_data(set_id).get("display_name", ""))

static func get_identity(set_id: String) -> String:
	return str(SET_IDENTITIES.get(set_id, ""))

static func get_tier_description(set_id: String, tier: int) -> String:
	var tier_data: Dictionary = TIER_DESCRIPTIONS.get(set_id, {})
	return str(tier_data.get(tier, ""))

static func get_tier_descriptions(set_id: String) -> Dictionary:
	var tier_data: Dictionary = TIER_DESCRIPTIONS.get(set_id, {})
	return tier_data.duplicate(true)

static func get_piece_count(set_id: String, equipped_item_ids: Array[String]) -> int:
	var set_data: Dictionary = get_set_data(set_id)
	if set_data.is_empty():
		return 0
	var count: int = 0
	var raw_items: Array = set_data.get("items", [])
	for raw_item_id in raw_items:
		if equipped_item_ids.has(str(raw_item_id)):
			count += 1
	return count

static func get_dominant_set_state(equipped_item_ids: Array[String]) -> Dictionary:
	var best_set_id: String = ""
	var best_count: int = 0

	for set_id: String in SET_ORDER:
		var piece_count: int = get_piece_count(set_id, equipped_item_ids)
		if piece_count > best_count:
			best_set_id = set_id
			best_count = piece_count

	return {
		"set_id": best_set_id,
		"display_name": get_display_name(best_set_id),
		"piece_count": best_count,
		"max_pieces": 5,
		"resonant": best_count >= 2,
		"full_resonance": best_count >= 5
	}

static func get_set_id_for_item(item_id: String) -> String:
	for set_id: String in SET_ORDER:
		var set_data: Dictionary = get_set_data(set_id)
		var raw_items: Array = set_data.get("items", [])
		if raw_items.has(item_id):
			return set_id
	return ""

static func get_piece_ids(set_id: String) -> Array[String]:
	var result: Array[String] = []
	var set_data: Dictionary = get_set_data(set_id)
	var raw_items: Array = set_data.get("items", [])
	for raw_item_id in raw_items:
		result.append(str(raw_item_id))
	return result

static func get_active_piece_ids(
	set_id: String,
	equipped_item_ids: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	for item_id: String in get_piece_ids(set_id):
		if equipped_item_ids.has(item_id):
			result.append(item_id)
	return result

static func get_missing_piece_ids(
	set_id: String,
	equipped_item_ids: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	for item_id: String in get_piece_ids(set_id):
		if not equipped_item_ids.has(item_id):
			result.append(item_id)
	return result

static func get_resonance_label(piece_count: int) -> String:
	match clampi(piece_count, 0, 5):
		5:
			return "FULL RESONANCE"
		4:
			return "STRONG RESONANCE"
		3:
			return "STABLE RESONANCE"
		2:
			return "AWAKENED"
		1:
			return "DORMANT"
		_:
			return "NO RESONANCE"

static func get_gameplay_bonus(
	stat_id: String,
	equipped_item_ids: Array[String]
) -> float:
	# Gameplay follows the same dominant-set identity used by presentation. This
	# avoids hidden 2+2 stacking when the UI/VFX only communicates one resonance.
	var state: Dictionary = get_dominant_set_state(equipped_item_ids)
	var set_id: String = str(state.get("set_id", ""))
	var piece_count: int = int(state.get("piece_count", 0))
	if set_id.is_empty() or piece_count < 2:
		return 0.0

	var total: float = 0.0
	var set_tiers: Dictionary = GAMEPLAY_TIERS.get(set_id, {})
	for tier: int in [2, 3, 4, 5]:
		if piece_count < tier:
			break
		var tier_data: Dictionary = set_tiers.get(tier, {})
		total += float(tier_data.get(stat_id, 0.0))
	return total
