extends RefCounted

## Realm-specific 6 normal + 2 elite identities. Shared AI lives in production.
const VISUAL_SET_ID: StringName = &"solar_nirvana"

const ENEMIES: Dictionary = {
	1: {"display_name": "Sunbound Blade Disciple", "sprite_frames_path": "res://assets/enemy/chapter5/enemy_1_sunbound_blade_disciple_spriteframes.tres"},
	2: {"display_name": "Gilded Flame Talismanist", "sprite_frames_path": "res://assets/enemy/chapter5/enemy_2_gilded_flame_talismanist_spriteframes.tres", "projectile_frames_path": "res://assets/enemy/chapter5/solar_nirvana_talisman_projectile_spriteframes.tres", "attack_pattern": &"spread_three", "predictive_lead_time": 0.26, "pair_angle_degrees": 8.0, "spread_angle_degrees": 14.0},
	3: {"display_name": "Ashwing Pursuer", "sprite_frames_path": "res://assets/enemy/chapter5/enemy_3_ashwing_pursuer_spriteframes.tres", "movement_pattern": &"blood_frenzy", "frenzy_threshold": 0.44, "frenzy_speed_multiplier": 1.26, "weave_strength": 0.34, "weave_frequency": 4.1},
	4: {"display_name": "Solar Array Priest", "sprite_frames_path": "res://assets/enemy/chapter5/enemy_4_solar_array_priest_spriteframes.tres", "cast_pattern": &"scarlet_trident", "pattern_spacing": 78.0, "presentation_theme": VISUAL_SET_ID},
	5: {"display_name": "Cinderveil Assassin", "sprite_frames_path": "res://assets/enemy/chapter5/enemy_5_cinderveil_assassin_spriteframes.tres"},
	6: {"display_name": "Bronze Furnace Guardian", "sprite_frames_path": "res://assets/enemy/chapter5/enemy_6_bronze_furnace_guardian_spriteframes.tres", "presentation_theme": VISUAL_SET_ID},
}

const ELITES: Dictionary = {
	1: {"display_name": "Molten Iron Colossus", "sprite_frames_path": "res://assets/enemy/chapter5/elite_1_molten_iron_colossus_spriteframes.tres"},
	2: {"display_name": "Nine-Sun Flame Oracle", "sprite_frames_path": "res://assets/enemy/chapter5/elite_2_nine_sun_flame_oracle_spriteframes.tres", "presentation_theme": VISUAL_SET_ID},
}

static var _enemy_cache: Dictionary = {}
static var _elite_cache: Dictionary = {}


static func _resolve_entry(entry: Dictionary) -> Dictionary:
	var output: Dictionary = entry.duplicate(false)
	var art_path: String = str(entry.get("sprite_frames_path", ""))
	output["sprite_frames"] = ResourceLoader.load(art_path, "SpriteFrames") if ResourceLoader.exists(art_path) else null
	if entry.has("projectile_frames_path"):
		var projectile_path: String = str(entry["projectile_frames_path"])
		output["projectile_frames"] = ResourceLoader.load(projectile_path, "SpriteFrames") if ResourceLoader.exists(projectile_path) else null
	return output


static func get_enemy(archetype_id: int) -> Dictionary:
	if not _enemy_cache.has(archetype_id):
		_enemy_cache[archetype_id] = _resolve_entry(ENEMIES.get(archetype_id, {}))
	return (_enemy_cache[archetype_id] as Dictionary).duplicate(false)


static func get_elite(archetype_id: int) -> Dictionary:
	if not _elite_cache.has(archetype_id):
		_elite_cache[archetype_id] = _resolve_entry(ELITES.get(archetype_id, {}))
	return (_elite_cache[archetype_id] as Dictionary).duplicate(false)


static func is_production_ready() -> bool:
	if ENEMIES.size() != 6 or ELITES.size() != 2:
		return false
	for item: Dictionary in ENEMIES.values():
		if not ResourceLoader.exists(str(item.get("sprite_frames_path", ""))):
			return false
		if item.has("projectile_frames_path") and not ResourceLoader.exists(str(item.get("projectile_frames_path", ""))):
			return false
	for item: Dictionary in ELITES.values():
		if not ResourceLoader.exists(str(item.get("sprite_frames_path", ""))):
			return false
	return true
