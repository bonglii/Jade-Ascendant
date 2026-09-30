extends SceneTree

## Resource-and-geometry-only smoke; never begin an active run or write saves.
const ChapterFour = preload("res://scripts/data/chapter_four_catalog.gd")
const ChapterFive = preload("res://scripts/data/chapter_five_catalog.gd")
const FrostRoster = preload("res://scripts/data/chapter_four_enemy_visual_catalog.gd")
const SolarRoster = preload("res://scripts/data/chapter_five_enemy_visual_catalog.gd")
const BossArt = preload("res://scripts/data/realm_boss_visual_catalog.gd")
const RealmSpell = preload("res://scripts/enemy/realm_boss_telegraph.gd")

const SIGNATURES: Dictionary = {
	4: ["frost_fork", "mirror_cross", "lotus_bloom", "bell_toll", "frost_crown"],
	5: ["sun_pillar", "forge_cross", "phoenix_wings", "eclipse_wheel", "nine_suns"]
}

var errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_roster(4, FrostRoster)
	_check_roster(5, SolarRoster)
	_check_realm(4, ChapterFour.STAGES)
	_check_realm(5, ChapterFive.STAGES)
	_check_shapes()
	if errors.is_empty():
		print("REALM_EXPANSION_GATE_B_PASS: 26 character atlases / 10 boss signatures / 10 scenes / damage scaling")
		quit(0)
		return
	for issue: String in errors:
		push_error(issue)
	print("REALM_EXPANSION_GATE_B_FAIL: %d findings" % errors.size())
	quit(1)


func _check_roster(realm_id: int, data_script: Script) -> void:
	var data: Dictionary = data_script.get("ENEMIES")
	var elites: Dictionary = data_script.get("ELITES")
	_check(data.size() == 6, "Roster normal count %d" % realm_id)
	_check(elites.size() == 2, "Roster elite count %d" % realm_id)
	for key: Variant in data.keys():
		var entry: Dictionary = data_script.call("get_enemy", int(key))
		_check_frames(entry.get("sprite_frames"), "Normal %d/%d" % [realm_id,int(key)])
		if int(key) == 2:
			var projectile: SpriteFrames = entry.get("projectile_frames") as SpriteFrames
			_check(projectile != null and projectile.has_animation(&"fly"), "Projectile %d" % realm_id)
	for key: Variant in elites.keys():
		var entry: Dictionary = data_script.call("get_elite", int(key))
		_check_frames(entry.get("sprite_frames"), "Elite %d/%d" % [realm_id,int(key)])


func _check_frames(raw_frames: Variant, context: String) -> void:
	var frames: SpriteFrames = raw_frames as SpriteFrames
	_check(frames != null, context + " missing SpriteFrames")
	if frames == null:
		return
	for animation: StringName in [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"cast_left", &"cast_right", &"run_left", &"qi_step_right", &"windup_left", &"dash_right", &"phase2_left"]:
		_check(frames.has_animation(animation), context + " missing " + str(animation))


func _check_realm(realm_id: int, definitions: Dictionary) -> void:
	_check(definitions.size() == 5, "Expected 5 stages for %d" % realm_id)
	var previous_hp: float = 0.0
	var previous_damage: float = 0.0
	for stage_id: int in range(1,6):
		var profile: Dictionary = definitions.get(stage_id,{})
		if profile.is_empty():
			_check(false, "Missing %d-%d" % [realm_id,stage_id])
			continue
		_check(bool(profile.get("implemented", false)), "Gate C integration requires implemented trial %d-%d" % [realm_id,stage_id])
		_check(not bool(profile.get("boss_visual_placeholder", true)), "Boss art is placeholder %d-%d" % [realm_id,stage_id])
		_check(str(profile.get("boss_signature", "")) == str(SIGNATURES[realm_id][stage_id-1]), "Wrong signature %d-%d" % [realm_id,stage_id])
		_check(int(profile.get("realm_stage_id", 0)) == stage_id, "Boss visual stage id %d-%d" % [realm_id,stage_id])
		_check(float(profile.get("enemy_damage_multiplier", 0.0)) >= previous_damage, "Damage scaling regression %d-%d" % [realm_id,stage_id])
		previous_damage = float(profile.get("enemy_damage_multiplier", 0.0))
		_check(int(profile.get("enemy_cap", 200)) <= 110, "Mobile enemy cap %d-%d" % [realm_id,stage_id])
		var stats: Dictionary = profile.get("boss_stats", {})
		var hp: float = float(stats.get("max_hp",0.0))
		_check(hp > previous_hp, "Boss HP progression %d-%d" % [realm_id,stage_id])
		previous_hp = hp
		_check(str(profile.get("hazard_pattern", "")) != "", "No hazard %d-%d" % [realm_id,stage_id])
		var frames: SpriteFrames = BossArt.get_frames(realm_id,stage_id)
		_check_frames(frames, "Boss %d-%d" % [realm_id,stage_id])
		var scene_path: String = str(profile.get("scene_path", ""))
		_check(ResourceLoader.exists(scene_path), "Missing stage scene " + scene_path)
		_check(ResourceLoader.exists("res://assets/world/chapter%d/landmark_%d.png" % [realm_id,stage_id]), "Missing stage landmark %d-%d" % [realm_id,stage_id])
		var source: Resource = ResourceLoader.load(scene_path, "PackedScene")
		_check(source is PackedScene, "Stage scene invalid %d-%d" % [realm_id,stage_id])


func _check_shapes() -> void:
	var spell: Node2D = RealmSpell.new()
	spell.set("aim", Vector2.RIGHT)
	var hits: Dictionary = {
		"frost_fork": [Vector2(175,65), Vector2(-100,-100)],
		"mirror_cross": [Vector2(100,100),Vector2(100,0)],
		"lotus_bloom": [Vector2(120,0),Vector2(100,57)],
		"bell_toll": [Vector2(130,0),Vector2(97,0)],
		"frost_crown": [Vector2(190,0),Vector2(190,80)],
		"sun_pillar": [Vector2(185,0),Vector2(185,90)],
		"forge_cross": [Vector2(200,0),Vector2(200,200)],
		"phoenix_wings": [Vector2(185,65),Vector2(200,0)],
		"eclipse_wheel": [Vector2(135,60),Vector2(155,0)],
		"nine_suns": [Vector2(154,0),Vector2.ZERO],
	}
	for pattern_name: String in hits.keys():
		spell.set("pattern", pattern_name)
		var points: Array = hits[pattern_name]
		_check(spell.call("contains_world_point",points[0]), "Signature hit geometry " + pattern_name)
		_check(not spell.call("contains_world_point",points[1]), "Signature safe geometry " + pattern_name)
	spell.free()


func _check(condition: bool, explanation: String) -> void:
	if not condition:
		errors.append(explanation)
