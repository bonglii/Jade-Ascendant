extends RefCounted

## Realm-specific 6 normal + 2 elite identities. Shared AI lives in production.
const VISUAL_SET_ID: StringName = &"frostveil"

const ENEMIES: Dictionary = {
	1: {"display_name": "Frostveil Blade Disciple", "sprite_frames_path": "res://assets/enemy/chapter4/enemy_1_frostveil_blade_disciple_spriteframes.tres"},
	2: {"display_name": "Mirror Script Adept", "sprite_frames_path": "res://assets/enemy/chapter4/enemy_2_mirror_script_adept_spriteframes.tres", "projectile_frames_path": "res://assets/enemy/chapter4/frostveil_talisman_projectile_spriteframes.tres", "attack_pattern": &"predictive_pair", "predictive_lead_time": 0.26, "pair_angle_degrees": 8.0, "spread_angle_degrees": 14.0},
	3: {"display_name": "Frostfang Pursuer", "sprite_frames_path": "res://assets/enemy/chapter4/enemy_3_frostfang_pursuer_spriteframes.tres", "movement_pattern": &"sky_weave", "frenzy_threshold": 0.44, "frenzy_speed_multiplier": 1.26, "weave_strength": 0.34, "weave_frequency": 4.1},
	4: {"display_name": "Hoarfrost Array Sage", "sprite_frames_path": "res://assets/enemy/chapter4/enemy_4_hoarfrost_array_sage_spriteframes.tres", "cast_pattern": &"constellation_ring", "pattern_spacing": 78.0, "presentation_theme": VISUAL_SET_ID},
	5: {"display_name": "Rimeveil Assassin", "sprite_frames_path": "res://assets/enemy/chapter4/enemy_5_rimeveil_assassin_spriteframes.tres"},
	6: {"display_name": "Glacier Ward Golem", "sprite_frames_path": "res://assets/enemy/chapter4/enemy_6_glacier_ward_golem_spriteframes.tres", "presentation_theme": VISUAL_SET_ID},
}

const ELITES: Dictionary = {
	1: {"display_name": "Rimebound Iron General", "sprite_frames_path": "res://assets/enemy/chapter4/elite_1_rimebound_iron_general_spriteframes.tres"},
	2: {"display_name": "Whiteout Oracle", "sprite_frames_path": "res://assets/enemy/chapter4/elite_2_whiteout_oracle_spriteframes.tres", "presentation_theme": VISUAL_SET_ID},
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
