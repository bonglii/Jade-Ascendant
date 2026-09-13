extends RefCounted

## Chapter 2 — Crimson Moon Sect enemy presentation catalog.
##
## Gameplay archetypes remain the proven enemy_1..enemy_6 and elite_1..elite_2
## scenes/scripts. This catalog owns Chapter 2 names, SpriteFrames, and
## presentation-only ability palette overrides.

const VISUAL_SET_ID: StringName = &"crimson_moon"

const ENEMIES: Dictionary = {
	1: {
		"display_name": "Crimson Sect Initiate",
		"sprite_frames": preload("res://assets/enemy/chapter2/enemy_1_crimson_sect_initiate_spriteframes.tres"),
	},
	2: {
		"display_name": "Cinnabar Talisman Adept",
		"sprite_frames": preload("res://assets/enemy/chapter2/enemy_2_cinnabar_talisman_adept_spriteframes.tres"),
		"projectile_frames": preload("res://assets/enemy/chapter2/enemy_2_cinnabar_talisman_projectile_spriteframes.tres"),
		"presentation_theme": VISUAL_SET_ID,
	},
	3: {
		"display_name": "Bloodwood Ravager",
		"sprite_frames": preload("res://assets/enemy/chapter2/enemy_3_bloodwood_ravager_spriteframes.tres"),
	},
	4: {
		"display_name": "Scarlet Array Disciple",
		"sprite_frames": preload("res://assets/enemy/chapter2/enemy_4_scarlet_array_disciple_spriteframes.tres"),
		"presentation_theme": VISUAL_SET_ID,
	},
	5: {
		"display_name": "Moonveil Shadowblade",
		"sprite_frames": preload("res://assets/enemy/chapter2/enemy_5_moonveil_shadowblade_spriteframes.tres"),
	},
	6: {
		"display_name": "Crimson Ward Keeper",
		"sprite_frames": preload("res://assets/enemy/chapter2/enemy_6_crimson_ward_keeper_spriteframes.tres"),
		"presentation_theme": VISUAL_SET_ID,
	},
}

const ELITES: Dictionary = {
	1: {
		"display_name": "Scarlet Iron Enforcer",
		"sprite_frames": preload("res://assets/enemy/chapter2/elite_1_scarlet_iron_enforcer_spriteframes.tres"),
	},
	2: {
		"display_name": "Blood Moon Ritualist",
		"sprite_frames": preload("res://assets/enemy/chapter2/elite_2_blood_moon_ritualist_spriteframes.tres"),
		"presentation_theme": VISUAL_SET_ID,
	},
}

static func get_enemy(archetype_id: int) -> Dictionary:
	var data: Dictionary = ENEMIES.get(archetype_id, {})
	return data.duplicate(false)

static func get_elite(archetype_id: int) -> Dictionary:
	var data: Dictionary = ELITES.get(archetype_id, {})
	return data.duplicate(false)
