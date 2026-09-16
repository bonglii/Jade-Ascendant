extends RefCounted

## Chapter 3 — Nine Heavens Star Palace encounter identity catalog.
##
## The proven enemy_1..enemy_6 and elite_1..elite_2 scenes/scripts remain the
## technical foundation. This catalog owns Chapter 3 art, names, ability
## palettes, and behavior-profile deltas so the celestial roster plays
## differently instead of being a pure visual reskin.

const VISUAL_SET_ID: StringName = &"nine_heavens"

const ENEMIES: Dictionary = {
	1: {
		"display_name": "Cloudsea Sword Disciple",
		"sprite_frames": preload(
			"res://assets/enemy/chapter3/enemy_1_cloudsea_sword_disciple_spriteframes.tres"
		),
		"art_ready": true,
	},
	2: {
		"display_name": "Astral Talisman Seer",
		"sprite_frames": preload(
			"res://assets/enemy/chapter3/enemy_2_astral_talisman_seer_spriteframes.tres"
		),
		"projectile_frames": preload(
			"res://assets/enemy/chapter3/enemy_2_astral_talisman_projectile_spriteframes.tres"
		),
		"presentation_theme": VISUAL_SET_ID,
		"attack_pattern": &"predictive_pair",
		"predictive_lead_time": 0.32,
		"pair_angle_degrees": 5.0,
		"art_ready": true,
	},
	3: {
		"display_name": "Skybound Pursuer",
		"sprite_frames": preload(
			"res://assets/enemy/chapter3/enemy_3_skybound_pursuer_spriteframes.tres"
		),
		"movement_pattern": &"sky_weave",
		"weave_strength": 0.42,
		"weave_frequency": 4.8,
		"art_ready": true,
	},
	4: {
		"display_name": "Constellation Array Adept",
		"sprite_frames": preload(
			"res://assets/enemy/chapter3/enemy_4_constellation_array_adept_spriteframes.tres"
		),
		"presentation_theme": VISUAL_SET_ID,
		"cast_pattern": &"constellation_ring",
		"pattern_spacing": 78.0,
		"art_ready": true,
	},
	5: {
		"display_name": "Voidstar Blade Dancer",
		"sprite_frames": preload(
			"res://assets/enemy/chapter3/enemy_5_voidstar_blade_dancer_spriteframes.tres"
		),
		"art_ready": true,
	},
	6: {
		"display_name": "Heavenly Ward Sentinel",
		"sprite_frames": preload(
			"res://assets/enemy/chapter3/enemy_6_heavenly_ward_sentinel_spriteframes.tres"
		),
		"presentation_theme": VISUAL_SET_ID,
		"art_ready": true,
	},
}

const ELITES: Dictionary = {
	1: {
		"display_name": "Starforged Iron Guardian",
		"sprite_frames": preload(
			"res://assets/enemy/chapter3/elite_1_starforged_iron_guardian_spriteframes.tres"
		),
		"art_ready": true,
	},
	2: {
		"display_name": "Ninefold Thunder Oracle",
		"sprite_frames": preload(
			"res://assets/enemy/chapter3/elite_2_ninefold_thunder_oracle_spriteframes.tres"
		),
		"presentation_theme": VISUAL_SET_ID,
		"art_ready": true,
	},
}

static func get_enemy(archetype_id: int) -> Dictionary:
	var data: Dictionary = ENEMIES.get(archetype_id, {})
	return data.duplicate(false)

static func get_elite(archetype_id: int) -> Dictionary:
	var data: Dictionary = ELITES.get(archetype_id, {})
	return data.duplicate(false)

static func is_production_ready() -> bool:
	for data: Dictionary in ENEMIES.values():
		if not bool(data.get("art_ready", false)):
			return false
		if data.get("sprite_frames") == null:
			return false
	for data: Dictionary in ELITES.values():
		if not bool(data.get("art_ready", false)):
			return false
		if data.get("sprite_frames") == null:
			return false
	return true
