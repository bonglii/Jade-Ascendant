extends RefCounted

## Combat-only armament presentation profiles.
## Equipment stats remain authoritative in equipment_catalog.gd.
## Profiles change starter attack presentation without changing damage,
## cooldown, checkpoint schema, collision, or permanent equipment data.

const DEFAULT_PROFILE: Dictionary = {
	"style_id": "spirit_sword",
	"combat_display_name": "Spirit Sword",
	"motif": "none",
	"sprite_visible": true,
	"sprite_tint": Color(1.0, 1.0, 1.0, 1.0),
	"trail_glow": Color(0.22, 0.90, 0.84, 0.10),
	"trail_main": Color(0.27, 0.90, 0.85, 0.38),
	"trail_core": Color(0.78, 1.0, 0.94, 0.72),
	"trail_glow_width": 12.0,
	"trail_main_width": 5.5,
	"trail_core_width": 2.0,
	"impact_main": Color(0.36, 0.96, 0.84, 0.94),
	"impact_core": Color(0.84, 1.0, 0.96, 1.0),
	"impact_accent": Color(0.30, 0.78, 1.0, 0.74),
	"impact_scale": 1.0
}

const PROFILES: Dictionary = {
	"wanderer_jade_jian": {
		"style_id": "wanderer_jade_jian",
		"combat_display_name": "Wanderer's Jade Jian",
		"motif": "jade_mark",
		"sprite_tint": Color(0.88, 1.0, 0.94, 1.0),
		"trail_glow": Color(0.26, 0.96, 0.72, 0.12),
		"trail_main": Color(0.34, 0.94, 0.76, 0.44),
		"trail_core": Color(0.86, 1.0, 0.94, 0.82),
		"impact_main": Color(0.32, 0.94, 0.70, 0.94),
		"impact_core": Color(0.88, 1.0, 0.95, 1.0),
		"impact_accent": Color(0.74, 0.92, 0.48, 0.76),
		"impact_scale": 1.02
	},
	"mistveil_jian": {
		"style_id": "mistveil_jian",
		"combat_display_name": "Mistveil Jian",
		"motif": "mist_ribbons",
		"sprite_tint": Color(0.72, 0.90, 1.0, 0.86),
		"trail_glow": Color(0.36, 0.66, 1.0, 0.13),
		"trail_main": Color(0.52, 0.78, 1.0, 0.44),
		"trail_core": Color(0.88, 0.96, 1.0, 0.82),
		"trail_glow_width": 15.0,
		"trail_main_width": 4.4,
		"trail_core_width": 1.5,
		"impact_main": Color(0.48, 0.72, 1.0, 0.90),
		"impact_core": Color(0.90, 0.96, 1.0, 0.98),
		"impact_accent": Color(0.66, 0.84, 1.0, 0.68),
		"impact_scale": 1.08
	},
	"spirit_seal_fan": {
		"style_id": "spirit_seal_fan",
		"combat_display_name": "Spirit-Seal Fan",
		"motif": "seal_fan",
		"sprite_visible": false,
		"trail_glow": Color(0.50, 0.90, 0.82, 0.11),
		"trail_main": Color(0.64, 0.92, 0.84, 0.38),
		"trail_core": Color(1.0, 0.88, 0.56, 0.78),
		"trail_glow_width": 13.5,
		"trail_main_width": 4.0,
		"trail_core_width": 1.5,
		"impact_main": Color(0.52, 0.92, 0.82, 0.92),
		"impact_core": Color(1.0, 0.94, 0.68, 1.0),
		"impact_accent": Color(0.90, 0.72, 0.30, 0.76),
		"impact_scale": 1.05
	},
	"cinnabar_moon_saber": {
		"style_id": "cinnabar_moon_saber",
		"combat_display_name": "Cinnabar Moon Saber",
		"motif": "moon_saber",
		"sprite_tint": Color(1.0, 0.72, 0.66, 0.96),
		"trail_glow": Color(1.0, 0.22, 0.20, 0.12),
		"trail_main": Color(0.94, 0.30, 0.26, 0.44),
		"trail_core": Color(1.0, 0.82, 0.58, 0.84),
		"trail_glow_width": 14.0,
		"trail_main_width": 5.0,
		"trail_core_width": 1.7,
		"impact_main": Color(0.94, 0.28, 0.24, 0.94),
		"impact_core": Color(1.0, 0.86, 0.62, 1.0),
		"impact_accent": Color(1.0, 0.54, 0.22, 0.78),
		"impact_scale": 1.10
	},
	"nine_heavens_star_sword": {
		"style_id": "nine_heavens_star_sword",
		"combat_display_name": "Nine Heavens Star Sword",
		"motif": "star_sword",
		"sprite_tint": Color(0.84, 0.84, 1.0, 1.0),
		"trail_glow": Color(0.46, 0.40, 1.0, 0.14),
		"trail_main": Color(0.62, 0.58, 1.0, 0.46),
		"trail_core": Color(1.0, 0.92, 0.62, 0.88),
		"trail_glow_width": 15.0,
		"trail_main_width": 4.6,
		"trail_core_width": 1.6,
		"impact_main": Color(0.64, 0.58, 1.0, 0.96),
		"impact_core": Color(1.0, 0.96, 0.74, 1.0),
		"impact_accent": Color(0.50, 0.84, 1.0, 0.82),
		"impact_scale": 1.12
	},
	"mountain_ward_jian": {
		"style_id": "mountain_ward_jian",
		"combat_display_name": "Mountain Ward Jian",
		"motif": "ward_jian",
		"sprite_tint": Color(0.78, 0.94, 0.72, 1.0),
		"trail_glow": Color(0.46, 0.72, 0.36, 0.13),
		"trail_main": Color(0.58, 0.82, 0.46, 0.44),
		"trail_core": Color(0.96, 0.82, 0.46, 0.84),
		"trail_glow_width": 14.5,
		"trail_main_width": 5.8,
		"trail_core_width": 2.0,
		"impact_main": Color(0.50, 0.80, 0.42, 0.94),
		"impact_core": Color(0.98, 0.88, 0.56, 1.0),
		"impact_accent": Color(0.40, 0.94, 0.72, 0.76),
		"impact_scale": 1.08
	},
	"stillwater_mirror_blade": {
		"style_id": "stillwater_mirror_blade",
		"combat_display_name": "Stillwater Mirror Blade",
		"motif": "mirror_blade",
		"sprite_tint": Color(0.86, 0.98, 1.0, 0.96),
		"trail_glow": Color(0.38, 0.82, 1.0, 0.11),
		"trail_main": Color(0.58, 0.90, 1.0, 0.40),
		"trail_core": Color(0.96, 1.0, 1.0, 0.86),
		"trail_glow_width": 13.5,
		"trail_main_width": 4.2,
		"trail_core_width": 1.4,
		"impact_main": Color(0.58, 0.88, 1.0, 0.92),
		"impact_core": Color(0.98, 1.0, 1.0, 1.0),
		"impact_accent": Color(0.68, 0.72, 1.0, 0.74),
		"impact_scale": 1.06
	},
	"sunfire_dragon_jian": {
		"style_id": "sunfire_dragon_jian",
		"combat_display_name": "Sunfire Dragon Jian",
		"motif": "sunfire_dragon",
		"sprite_tint": Color(1.0, 0.88, 0.58, 1.0),
		"trail_glow": Color(1.0, 0.42, 0.10, 0.15),
		"trail_main": Color(1.0, 0.58, 0.16, 0.48),
		"trail_core": Color(1.0, 0.94, 0.66, 0.90),
		"trail_glow_width": 16.0,
		"trail_main_width": 5.2,
		"trail_core_width": 1.8,
		"impact_main": Color(1.0, 0.54, 0.14, 0.96),
		"impact_core": Color(1.0, 0.96, 0.70, 1.0),
		"impact_accent": Color(1.0, 0.32, 0.12, 0.80),
		"impact_scale": 1.14
	}
}

static func get_profile(armament_id: String) -> Dictionary:
	var profile: Dictionary = DEFAULT_PROFILE.duplicate(true)
	if PROFILES.has(armament_id):
		profile.merge(PROFILES[armament_id], true)
	profile["armament_id"] = armament_id
	return profile
