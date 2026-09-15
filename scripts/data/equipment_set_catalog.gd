extends RefCounted

## Presentation grouping for the 25 permanent equipment items.
## This catalog does NOT change equipment stats, rarity, ownership, save data, or balance.
## Set gameplay bonuses are intentionally deferred to the later balance gate.
##
## Resonance tiers used by runtime presentation:
## 0-1 pieces: no set aura
## 2 pieces: awakened trace
## 3 pieces: stable resonance
## 4 pieces: strong resonance
## 5 pieces: full resonance

const SET_ORDER: Array[String] = [
	"verdant_wanderer",
	"mistbound_disciple",
	"moon_seal",
	"crimson_shadow",
	"nine_heavens"
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
	}
}

static func get_set_data(set_id: String) -> Dictionary:
	if not SETS.has(set_id):
		return {}
	return (SETS[set_id] as Dictionary).duplicate(true)

static func get_display_name(set_id: String) -> String:
	return str(get_set_data(set_id).get("display_name", ""))

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

