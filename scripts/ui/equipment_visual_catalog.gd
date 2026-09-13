extends RefCounted

## Presentation-only metadata for Hero equipment UI.
## Gameplay authority remains in EquipmentManager / InventoryManager.

const ITEM_ICON_PATHS: Dictionary = {
	"wanderer_jade_jian": "res://assets/weapons/sword/spirit_sword_jade_jian_96x64.png",
	"mistveil_jian": "res://assets/ui/equipment/mistveil_jian.svg",
	"spirit_seal_fan": "res://assets/ui/equipment/spirit_seal_fan.svg",
	"cinnabar_moon_saber": "res://assets/ui/equipment/cinnabar_moon_saber.svg",
	"nine_heavens_star_sword": "res://assets/ui/equipment/nine_heavens_star_sword.svg",
	"verdant_qi_robe": "res://assets/ui/equipment/verdant_qi_robe.svg",
	"jade_guard_bracer": "res://assets/ui/equipment/jade_guard_bracer.svg",
	"cloudstep_boots": "res://assets/ui/equipment/cloudstep_boots.svg",
	"spirit_jade_pendant": "res://assets/ui/equipment/spirit_jade_pendant.svg",
	"bamboo_weave_robe": "res://assets/ui/equipment/bamboo_weave_robe.svg",
	"moonthread_robe": "res://assets/ui/equipment/moonthread_robe.svg",
	"jade_edge_bracer": "res://assets/ui/equipment/jade_edge_bracer.svg",
	"mirror_edge_bracer": "res://assets/ui/equipment/mirror_edge_bracer.svg",
	"miststride_boots": "res://assets/ui/equipment/miststride_boots.svg",
	"qi_reservoir_pendant": "res://assets/ui/equipment/qi_reservoir_pendant.svg",
	"ward_keeper_robe": "res://assets/ui/equipment/ward_keeper_robe.svg",
	"stormcall_bracer": "res://assets/ui/equipment/stormcall_bracer.svg",
	"shadowstep_boots": "res://assets/ui/equipment/shadowstep_boots.svg",
	"starstep_boots": "res://assets/ui/equipment/starstep_boots.svg",
	"shrine_seal_pendant": "res://assets/ui/equipment/shrine_seal_pendant.svg",
	"sword_heart_pendant": "res://assets/ui/equipment/sword_heart_pendant.svg",
	"sovereign_mantle": "res://assets/ui/equipment/sovereign_mantle.svg",
	"tribulation_bracer": "res://assets/ui/equipment/tribulation_bracer.svg",
	"cloudtreader_boots": "res://assets/ui/equipment/cloudtreader_boots.svg",
	"ascendant_heart": "res://assets/ui/equipment/ascendant_heart.svg",
	"refinement_shard": "res://assets/ui/equipment/refinement_shard.svg"
}

const SLOT_ROLES: Dictionary = {
	"armament": "DAO ARMAMENT",
	"robe": "DEFENSIVE PASSIVE",
	"bracer": "OFFENSIVE PASSIVE",
	"boots": "MOBILITY PASSIVE",
	"pendant": "GROWTH PASSIVE"
}

const SLOT_FOCUS: Dictionary = {
	"armament": "DAO PATH",
	"robe": "BODY WARD",
	"bracer": "MARTIAL FORCE",
	"boots": "CLOUDSTEP",
	"pendant": "SPIRIT GROWTH"
}

const SLOT_TITLES: Dictionary = {
	"armament": "ARMAMENT",
	"robe": "ROBE",
	"bracer": "BRACER",
	"boots": "BOOTS",
	"pendant": "PENDANT"
}

const SLOT_SORT_ORDER: Dictionary = {
	"armament": 0,
	"robe": 1,
	"bracer": 2,
	"pendant": 3,
	"boots": 4
}

const RARITY_RANKS: Dictionary = {
	"common": 0,
	"rare": 1,
	"epic": 2,
	"legendary": 3
}

static func get_icon_path(item_id: String) -> String:
	return str(ITEM_ICON_PATHS.get(item_id, ""))

static func get_slot_role(slot_id: String) -> String:
	return str(SLOT_ROLES.get(slot_id, "PASSIVE EQUIPMENT"))

static func get_slot_focus(slot_id: String) -> String:
	return str(SLOT_FOCUS.get(slot_id, "MARTIAL RESONANCE"))

static func get_slot_title(slot_id: String) -> String:
	return str(SLOT_TITLES.get(slot_id, slot_id.to_upper()))

static func get_slot_sort_order(slot_id: String) -> int:
	return int(SLOT_SORT_ORDER.get(slot_id, 99))

static func get_rarity_rank(rarity_id: String) -> int:
	return int(RARITY_RANKS.get(rarity_id, 0))

static func get_rarity_color(rarity_id: String) -> Color:
	match rarity_id:
		"rare":
			return Color(0.32, 0.78, 0.92, 1.0)
		"epic":
			return Color(0.70, 0.42, 0.92, 1.0)
		"legendary":
			return Color(0.98, 0.72, 0.25, 1.0)
		_:
			return Color(0.52, 0.78, 0.68, 1.0)

static func get_signature_effect_name(item_data: Dictionary) -> String:
	var explicit_name: String = str(item_data.get("signature_effect_name", ""))
	if not explicit_name.is_empty():
		return explicit_name
	# Compatibility fallback for older local data during migration/testing.
	explicit_name = str(item_data.get("awakened_effect_name", ""))
	if not explicit_name.is_empty():
		return explicit_name
	return "NO SIGNATURE EFFECT"

static func get_signature_effect_description(item_data: Dictionary) -> String:
	var explicit_description: String = str(item_data.get("signature_effect_description", ""))
	if not explicit_description.is_empty():
		return explicit_description
	# Compatibility fallback for older local data during migration/testing.
	explicit_description = str(item_data.get("awakened_effect_description", ""))
	if not explicit_description.is_empty():
		return explicit_description
	return "This equipment currently grants its core passive only."

# Compatibility wrappers keep Backpack/older callers stable until Gate 1.6 UI cleanup.
static func get_awakened_effect_name(item_data: Dictionary) -> String:
	return get_signature_effect_name(item_data)

static func get_awakened_effect_description(item_data: Dictionary) -> String:
	return get_signature_effect_description(item_data)

static func get_stat_summary(item_data: Dictionary) -> String:
	var parts: Array[String] = []
	var numeric_labels: Dictionary = {
		"max_health_flat": "HP",
		"pickup_radius_bonus": "Pickup radius",
		"starting_shield_charges": "Starting shield",
		"blood_qi_heal_bonus": "Blood Qi healing"
	}
	for key in numeric_labels:
		if item_data.has(key):
			var value_text: String = _format_stat_number(float(item_data[key]))
			parts.append("+%s %s" % [value_text, TranslationServer.translate(str(numeric_labels[key]))])
	var percent_labels: Dictionary = {
		"damage_bonus": "Damage",
		"movement_speed_bonus": "Movement",
		"experience_bonus": "EXP",
		"critical_chance_bonus": "Critical chance",
		"critical_damage_bonus": "Critical damage"
	}
	for key in percent_labels:
		if item_data.has(key):
			var value_text: String = _format_stat_number(float(item_data[key]) * 100.0)
			parts.append("+%s%% %s" % [value_text, TranslationServer.translate(str(percent_labels[key]))])
	if parts.is_empty():
		return str(TranslationServer.translate("No stat bonus"))
	return " • ".join(parts)

static func _format_stat_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	var formatted: String = "%.2f" % value
	while formatted.ends_with("0"):
		formatted = formatted.left(formatted.length() - 1)
	if formatted.ends_with("."):
		formatted = formatted.left(formatted.length() - 1)
	return formatted
