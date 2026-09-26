extends RefCounted

## Presentation-only tuning catalog for Pavilion summon VFX.
## Economy, pity, Wish Fate, inventory, and save state never belong here.
## Item-aware Qi Mist tint metadata allows reveal atmosphere to inherit a small,
## controlled color accent from the currently showcased equipment.

const COMMON_PROFILE: Dictionary = {
	"id": "common",
	"display_name": "JADE QI GATHERING",
	"accent": Color(0.38, 0.88, 0.62, 1.0),
	"secondary": Color(0.88, 0.74, 0.32, 1.0),
	# Common still receives a full cinematic contract, but it is deliberately
	# shorter and quieter than Rare so rarity hierarchy remains obvious.
	"anticipation_duration": 0.48,
	"impact_hold": 0.045,
	"reveal_delay": 0.18,
	"reveal_duration": 0.22,
	"settle_duration": 0.46,
	"gateway_peak_alpha": 0.18,
	"ritual_peak_alpha": 0.38,
	"mist_peak_alpha": 0.085,
	"talisman_peak_alpha": 0.08,
	"impact_peak_alpha": 0.50,
	"burst_peak_alpha": 0.36,
	"afterglow_peak_alpha": 0.10,
	"light_streak_peak_alpha": 0.22,
	"mote_count": 8,
	"mist_tint_strength": 0.16,
}


const RARE_PROFILE: Dictionary = {
	"id": "rare",
	"display_name": "JADE MIST INVOCATION",
	"accent": Color(0.28, 0.95, 0.78, 1.0),
	"secondary": Color(0.98, 0.78, 0.30, 1.0),
	"anticipation_duration": 0.86,
	"impact_hold": 0.070,
	"reveal_delay": 0.34,
	"reveal_duration": 0.32,
	"settle_duration": 0.78,
	"gateway_peak_alpha": 0.34,
	"ritual_peak_alpha": 0.76,
	"mist_peak_alpha": 0.110,
	"talisman_peak_alpha": 0.24,
	"impact_peak_alpha": 0.82,
	"burst_peak_alpha": 0.74,
	"afterglow_peak_alpha": 0.20,
	"light_streak_peak_alpha": 0.46,
	"mote_count": 14,
	"mist_tint_strength": 0.26,
}

const EPIC_PROFILE: Dictionary = {
	"id": "epic",
	"display_name": "VIOLET CONSTELLATION MANIFESTATION",
	"accent": Color(0.72, 0.48, 0.96, 1.0),
	"secondary": Color(0.98, 0.78, 0.30, 1.0),
	"anticipation_duration": 1.18,
	"impact_hold": 0.090,
	"reveal_delay": 0.42,
	"reveal_duration": 0.38,
	"settle_duration": 0.96,
	"gateway_peak_alpha": 0.28,
	"ritual_peak_alpha": 0.54,
	"mist_peak_alpha": 0.080,
	"impact_peak_alpha": 0.88,
	"burst_peak_alpha": 0.56,
	"afterglow_peak_alpha": 0.22,
	"mote_count": 18,
	"constellation_peak_alpha": 0.54,
	"spiral_peak_alpha": 0.22,
	"epic_seal_peak_alpha": 0.58,
	"crack_peak_alpha": 0.78,
	"mist_tint_strength": 0.24,
}

const LEGENDARY_PROFILE: Dictionary = {
	"id": "legendary",
	"display_name": "CELESTIAL MANDATE DESCENDS",
	"accent": Color(1.0, 0.76, 0.24, 1.0),
	"secondary": Color(0.84, 0.96, 1.0, 1.0),
	"anticipation_duration": 1.55,
	"impact_hold": 0.120,
	"reveal_delay": 0.58,
	"reveal_duration": 0.46,
	"settle_duration": 1.28,
	"gateway_peak_alpha": 0.22,
	"ritual_peak_alpha": 0.42,
	"mist_peak_alpha": 0.060,
	"impact_peak_alpha": 0.94,
	"burst_peak_alpha": 0.68,
	"mote_count": 20,
	"mandala_peak_alpha": 0.62,
	"beam_soft_peak_alpha": 0.20,
	"seal_fragment_peak_alpha": 0.28,
	"divine_spark_peak_alpha": 0.24,
	"beam_core_peak_alpha": 0.78,
	"crest_peak_alpha": 0.72,
	"crest_reveal_alpha": 0.30,
	"dragon_peak_alpha": 0.24,
	"result_halo_peak_alpha": 0.42,
	"mist_tint_strength": 0.18,
}

const EQUIPMENT_VISUALS: Dictionary = {
	"mistveil jian": {
		"mist_primary_tint": Color(0.46, 0.94, 1.00, 1.0),
		"mist_secondary_tint": Color(0.24, 0.90, 0.74, 1.0),
		"mist_tint_strength": 0.30,
	},
	"cinnabar moon saber": {
		"mist_primary_tint": Color(0.92, 0.46, 0.96, 1.0),
		"mist_secondary_tint": Color(1.00, 0.42, 0.58, 1.0),
		"mist_tint_strength": 0.26,
	},
	"nine heavens star sword": {
		"mist_primary_tint": Color(1.00, 0.82, 0.34, 1.0),
		"mist_secondary_tint": Color(0.54, 0.82, 1.00, 1.0),
		"mist_tint_strength": 0.18,
	},
}

static func get_profile(rarity_id: String) -> Dictionary:
	match rarity_id:
		"legendary":
			return LEGENDARY_PROFILE.duplicate(true)
		"epic":
			return EPIC_PROFILE.duplicate(true)
		"rare":
			return RARE_PROFILE.duplicate(true)
		"common":
			return COMMON_PROFILE.duplicate(true)
		_:
			return COMMON_PROFILE.duplicate(true)


static func get_profile_for_item(rarity_id: String, item_name: String) -> Dictionary:
	var profile: Dictionary = get_profile(rarity_id)
	var lookup_key: String = item_name.strip_edges().to_lower()
	if EQUIPMENT_VISUALS.has(lookup_key):
		var visual: Dictionary = EQUIPMENT_VISUALS[lookup_key]
		for key in visual.keys():
			profile[key] = visual[key]
	else:
		profile["mist_primary_tint"] = profile.get("accent", Color.WHITE)
		profile["mist_secondary_tint"] = profile.get("secondary", Color.WHITE)
	return profile
