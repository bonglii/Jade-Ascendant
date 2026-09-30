extends SceneTree

## Optional isolated catalog/resource QA. Does not instantiate a run, mutate
## JourneyManager, or touch real SaveManager domains.
const ChapterFour = preload("res://scripts/data/chapter_four_catalog.gd")
const ChapterFive = preload("res://scripts/data/chapter_five_catalog.gd")
const BossPatterns = [
	"frost_lance", "frost_mark", "mirror_gate", "frost_ring",
	"solar_lance", "ember_mark", "solar_fan", "solar_ring",
]
var _errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_catalog(4, ChapterFour.STAGES)
	_check_catalog(5, ChapterFive.STAGES)
	if _errors.is_empty():
		print("REALM_EXPANSION_GATE_A_PASS: 10 authored profiles / 10 scene paths / 8 attack types")
		quit(0)
		return
	for error_text: String in _errors:
		push_error(error_text)
	print("REALM_EXPANSION_GATE_A_FAIL: %d findings" % _errors.size())
	quit(1)

func _check_catalog(realm_id: int, definitions: Dictionary) -> void:
	_check(definitions.size() == 5, "Realm %d must define 5 trials" % realm_id)
	var last_boss_hp: float = 0.0
	for stage_id: int in range(1, 6):
		_check(definitions.has(stage_id), "Missing %d-%d" % [realm_id, stage_id])
		if not definitions.has(stage_id):
			continue
		var profile: Dictionary = definitions[stage_id]
		_check(int(profile.get("realm_id", 0)) == realm_id, "Wrong realm ID %d-%d" % [realm_id,stage_id])
		_check(bool(profile.get("implemented", false)), "Gate C must register complete trial %d-%d" % [realm_id,stage_id])
		_check(bool(profile.get("is_chapter_boss", false)) == (stage_id == 5), "Boss finale flag %d-%d" % [realm_id,stage_id])
		var scene_path: String = str(profile.get("scene_path", ""))
		_check(ResourceLoader.exists(scene_path), "Scene resource missing: " + scene_path)
		var scene_resource: Resource = ResourceLoader.load(scene_path, "PackedScene")
		_check(scene_resource is PackedScene, "Stage scene invalid: " + scene_path)
		var boss_stats: Dictionary = profile.get("boss_stats", {})
		var hp: float = float(boss_stats.get("max_hp", 0.0))
		_check(hp > last_boss_hp, "Non-increasing boss HP at %d-%d" % [realm_id,stage_id])
		last_boss_hp = hp
		_check(float(profile.get("wave_duration", 0.0)) >= 20.0, "Wave duration missing %d-%d" % [realm_id,stage_id])
		_check(int(profile.get("enemy_cap", 0)) <= 110, "Mobile enemy cap exceeded %d-%d" % [realm_id,stage_id])
		_check(int(profile.get("repeat_clear_shards", 0)) > 0, "No repeat shards %d-%d" % [realm_id,stage_id])
		var bands: Array = profile.get("enemy_bands", [])
		_check(bands.size() == 3, "Enemy band count %d-%d" % [realm_id,stage_id])
		for band: Dictionary in bands:
			var weights: Array = band.get("weights", [])
			var total: int = 0
			for entry: Variant in weights:
				total += int(entry)
			_check(weights.size() == 6 and total == 100, "Enemy band weights %d-%d" % [realm_id,stage_id])
		var patterns: Array = profile.get("boss_patterns", [])
		_check(patterns.size() >= 2, "Boss pattern variety %d-%d" % [realm_id,stage_id])
		for value: Variant in patterns:
			_check(value in BossPatterns, "Unrecognized boss attack %s" % str(value))

func _check(approved: bool, message: String) -> void:
	if not approved:
		_errors.append(message)
