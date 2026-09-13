extends RefCounted

## Shared content definitions. Journey owns unlock/save state; encounter owners
## consume this data before their _ready methods run. Existing stage IDs stay fixed.
const STAGES: Dictionary = {
	1: {
		"display_name": "Verdant Awakening",
		"scene_path": "res://scenes/levels/level_1.tscn",
		"implemented": true, "is_chapter_boss": false,
		"description": "An open valley of spirit grass and ancient cultivation markers.",
		"encounter_hint": "Valley disciples • Trial Guardian",
		"accent": Color(0.30, 0.82, 0.65),
		"ground": Color(0.020, 0.067, 0.061),
		"moss": Color(0.041, 0.145, 0.108),
		"stone": Color(0.028, 0.087, 0.083),
		"mist": Color(0.055, 0.26, 0.19),
		# First trial is deliberately shorter than later stages, but long enough
		# for onboarding, two difficulty steps, and a meaningful build arc.
		"wave_duration": 14.0, "difficulty_interval": 60.0,
		"spawn_interval": 2.0, "enemy_cap": 64,
		"enemy_bands": [], "elite_schedule": {4: 1, 8: 2},
		"hazard_kind": 0, "hazard_interval": 0.0,
		"boss_name": "Valley Trial Guardian", "boss_style": 0,
		"boss_stats": {},
		"first_clear_stones": 100, "repeat_clear_stones": 100,
		"repeat_clear_shards": 1,
	},
	2: {
		"display_name": "Bamboo Mist Pass",
		"scene_path": "res://scenes/levels/stage_1_2.tscn",
		"implemented": true, "is_chapter_boss": false,
		"description": "Mist curls between bamboo groves. Watch the flanks for shadowblades.",
		"encounter_hint": "Ranged ambushers • Mobile Mistblade Warden",
		"accent": Color(0.48, 0.82, 0.63),
		"ground": Color(0.024, 0.055, 0.052),
		"moss": Color(0.080, 0.17, 0.095),
		"stone": Color(0.047, 0.10, 0.10),
		"mist": Color(0.30, 0.47, 0.42),
		"wave_duration": 18.0, "difficulty_interval": 90.0,
		"spawn_interval": 2.0, "enemy_cap": 80,
		"enemy_bands": [
			{"from_wave": 1, "weights": [45, 35, 0, 0, 20, 0]},
			{"from_wave": 4, "weights": [25, 30, 10, 0, 35, 0]},
			{"from_wave": 7, "weights": [15, 25, 15, 5, 35, 5]}
		],
		"elite_schedule": {4: 1, 8: 2},
		"hazard_kind": 0, "hazard_interval": 0.0,
		"boss_name": "Mistblade Warden", "boss_style": 1,
		# Stage 1-2 is the first real boss check after onboarding. Keep the Warden
		# clearly below the Stage 1-3 Keeper, but give both phases enough life to
		# be played instead of evaporating under a mature Wave-10 build.
		"boss_stats": {"max_hp": 2200.0, "speed": 90.0, "melee_distance": 90.0,
			"ranged_distance": 240.0, "phase_two_hp_ratio": 0.55,
			"phase_transition_invulnerability": 0.65,
			"ranged_attack_cooldown": 3.2, "phase_two_ranged_attack_cooldown": 2.5,
			"radial_projectile_count": 6, "phase_two_radial_projectile_count": 8},
		"first_clear_stones": 150, "repeat_clear_stones": 100,
		"repeat_clear_shards": 1,
	},
	3: {
		"display_name": "Ruined Jade Shrine",
		"scene_path": "res://scenes/levels/stage_1_3.tscn",
		"implemented": true, "is_chapter_boss": false,
		"description": "Broken shrines awaken old wards. Leave the closing seal before it ignites.",
		"encounter_hint": "Ward keepers • Shrine seals • Jade Shrine Keeper",
		"accent": Color(0.70, 0.83, 0.59),
		"ground": Color(0.048, 0.065, 0.059),
		"moss": Color(0.115, 0.15, 0.105),
		"stone": Color(0.12, 0.15, 0.145),
		"mist": Color(0.27, 0.38, 0.28),
		"wave_duration": 20.0, "difficulty_interval": 90.0,
		"spawn_interval": 2.2, "enemy_cap": 80,
		"enemy_bands": [
			{"from_wave": 1, "weights": [45, 10, 0, 25, 0, 20]},
			{"from_wave": 4, "weights": [25, 10, 10, 30, 0, 25]},
			{"from_wave": 7, "weights": [15, 10, 10, 30, 5, 30]}
		],
		"elite_schedule": {4: 1, 8: 1},
		"hazard_kind": 1, "hazard_interval": 12.0,
		"boss_name": "Jade Shrine Keeper", "boss_style": 2,
		# Stage 1-3 is the first encounter where a mature run build can stack
		# several arts at once. The Keeper therefore uses a real two-phase ward
		# instead of relying on a tiny HP pool that can be erased in one burst.
		"boss_stats": {"max_hp": 3200.0, "speed": 42.0,
			"phase_two_hp_ratio": 0.55, "phase_transition_invulnerability": 0.9,
			"ranged_attack_cooldown": 3.8, "phase_two_ranged_attack_cooldown": 2.8,
			"shockwave_cooldown": 3.6, "shockwave_telegraph_duration": 0.9},
		"first_clear_stones": 175, "repeat_clear_stones": 110,
		"repeat_clear_shards": 2,
	},
	4: {
		"display_name": "Storm Peak Approach",
		"scene_path": "res://scenes/levels/stage_1_4.tscn",
		"implemented": true, "is_chapter_boss": false,
		"description": "Wind scours dark jade stone. Dodge marked lightning before the Herald arrives.",
		"encounter_hint": "Storm Cultivators • Lightning • Stormpeak Herald",
		"accent": Color(0.51, 0.73, 0.94),
		"ground": Color(0.024, 0.038, 0.069),
		"moss": Color(0.059, 0.10, 0.15),
		"stone": Color(0.10, 0.13, 0.20),
		"mist": Color(0.28, 0.39, 0.56),
		"wave_duration": 22.0, "difficulty_interval": 90.0,
		"spawn_interval": 2.0, "enemy_cap": 88,
		"enemy_bands": [
			{"from_wave": 1, "weights": [45, 35, 10, 10, 0, 0]},
			{"from_wave": 4, "weights": [25, 30, 15, 15, 10, 5]},
			{"from_wave": 7, "weights": [15, 30, 15, 15, 15, 10]}
		],
		"elite_schedule": {4: 2, 8: 2},
		"hazard_kind": 2, "hazard_interval": 11.0,
		"boss_name": "Stormpeak Herald", "boss_style": 3,
		# By Stage 1-4 the run has more upgrade opportunities than the Shrine.
		# Give the Herald enough effective life to execute both storm phases,
		# while the short phase ward prevents burst from deleting the transition.
		"boss_stats": {"max_hp": 4200.0, "speed": 55.0, "ranged_distance": 340.0,
			"phase_two_hp_ratio": 0.55, "phase_transition_invulnerability": 0.9,
			"ranged_attack_cooldown": 3.0, "phase_two_ranged_attack_cooldown": 2.25,
			"lightning_telegraph_duration": 1.0},
		"first_clear_stones": 200, "repeat_clear_stones": 120,
		"repeat_clear_shards": 2,
	},
	5: {
		"display_name": "Sovereign's Celestial Gate",
		"scene_path": "res://scenes/levels/stage_1_5.tscn",
		"implemented": true, "is_chapter_boss": true,
		"description": "Cross the golden seals and face the Jade Valley Sovereign's awakened phase.",
		"encounter_hint": "Mixed disciples • Celestial seals • Two-phase Sovereign",
		"accent": Color(0.94, 0.79, 0.40),
		"ground": Color(0.026, 0.059, 0.060),
		"moss": Color(0.080, 0.14, 0.125),
		"stone": Color(0.10, 0.15, 0.14),
		"mist": Color(0.39, 0.40, 0.23),
		"wave_duration": 26.0, "difficulty_interval": 100.0,
		"spawn_interval": 1.9, "enemy_cap": 96,
		"enemy_bands": [
			{"from_wave": 1, "weights": [40, 25, 15, 10, 5, 5]},
			{"from_wave": 4, "weights": [25, 20, 15, 15, 15, 10]},
			{"from_wave": 7, "weights": [15, 20, 15, 15, 20, 15]}
		],
		"elite_schedule": {4: 1, 6: 2, 8: 2},
		"hazard_kind": 1, "hazard_interval": 14.0,
		"boss_name": "Jade Valley Sovereign", "boss_style": 0,
		# Chapter finale: preserve the Sovereign's full three-pattern kit, but give
		# both phases enough effective life to be played. The short ceremonial ward
		# prevents a mature Wave-10 build from deleting Phase 2 on the threshold hit.
		"boss_stats": {"max_hp": 6000.0, "attack_damage": 8.0,
			"phase_two_hp_ratio": 0.55, "phase_transition_invulnerability": 1.0,
			"ranged_attack_cooldown": 2.8, "phase_two_ranged_attack_cooldown": 2.1},
		"first_clear_stones": 300, "repeat_clear_stones": 150,
		"repeat_clear_shards": 3,
	}
}

static func get_stage(stage_id: int) -> Dictionary:
	var data: Dictionary = STAGES.get(stage_id, STAGES[1])
	return data.duplicate(true)
