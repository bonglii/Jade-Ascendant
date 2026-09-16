extends SceneTree

## Run ONLY through PERIKSA_GAME.bat or tools/validate_phase0.py. That launcher isolates user://
## before autoload initialization. This script also refuses an unmarked run.
## These checks verify contracts and smoke flows, not Android or visual quality.

const CHECKPOINT_SCRIPT_PATH: String = "res://scripts/managers/checkpoint_manager.gd"
const HUB_SCRIPT_PATH: String = "res://scripts/ui/MainMenu.gd"
const HUB_PATH: String = "res://scenes/ui/main_menu.tscn"
const STAGE_PATH: String = "res://scenes/levels/level_1.tscn"
const CHAPTER_SELECT_PATH: String = "res://scenes/ui/chapter_select.tscn"
const JOURNEY_PATH: String = "res://scenes/ui/stage_select.tscn"
const TRIAL_GUARDIAN_FRAMES_PATH: String = "res://assets/enemy/boss_1_valley_trial_guardian_spriteframes.tres"
const SOVEREIGN_FRAMES_PATH: String = "res://assets/enemy/boss_1_jade_valley_sovereign_spriteframes.tres"
const MISTBLADE_FRAMES_PATH: String = "res://assets/enemy/boss_1_mistblade_warden_spriteframes.tres"
const SHRINE_KEEPER_FRAMES_PATH: String = "res://assets/enemy/boss_1_jade_shrine_keeper_spriteframes.tres"
const STORMPEAK_HERALD_FRAMES_PATH: String = "res://assets/enemy/boss_1_stormpeak_herald_spriteframes.tres"
const BLOODWOOD_MOONSTALKER_FRAMES_PATH: String = "res://assets/enemy/boss_2_bloodwood_moonstalker_spriteframes.tres"
const CINNABAR_VEIL_ASSASSIN_FRAMES_PATH: String = "res://assets/enemy/boss_2_cinnabar_veil_assassin_spriteframes.tres"
const SCARLET_RITE_KEEPER_FRAMES_PATH: String = "res://assets/enemy/boss_2_scarlet_rite_keeper_spriteframes.tres"
const BLOOD_MOON_ASCENDANT_FRAMES_PATH: String = "res://assets/enemy/boss_2_blood_moon_ascendant_spriteframes.tres"
const CRIMSON_MOON_SECT_MASTER_FRAMES_PATH: String = "res://assets/enemy/boss_2_crimson_moon_sect_master_spriteframes.tres"
const CLOUDSEA_GATE_WARDEN_FRAMES_PATH: String = "res://assets/enemy/chapter3/boss_3_cloudsea_gate_warden_spriteframes.tres"
const ASTRAL_MIRROR_DAOIST_FRAMES_PATH: String = "res://assets/enemy/chapter3/boss_3_astral_mirror_daoist_spriteframes.tres"
const CONSTELLATION_SWORD_SAINT_FRAMES_PATH: String = "res://assets/enemy/chapter3/boss_3_constellation_sword_saint_spriteframes.tres"
const NINEFOLD_HEAVEN_ARBITER_FRAMES_PATH: String = "res://assets/enemy/chapter3/boss_3_ninefold_heaven_arbiter_spriteframes.tres"
const STAR_PALACE_CELESTIAL_SOVEREIGN_FRAMES_PATH: String = "res://assets/enemy/chapter3/boss_3_star_palace_celestial_sovereign_spriteframes.tres"
const NINE_HEAVENS_BOSS_PROJECTILE_FRAMES_PATH: String = "res://assets/enemy/chapter3/boss_3_astral_star_projectile_spriteframes.tres"
const STAGE_LANDMARK_PREVIEW_PATH: String = "res://scripts/ui/stage_landmark_preview.gd"
const JOURNEY_VISUAL_CATALOG_PATH: String = "res://scripts/ui/journey_visual_catalog.gd"
const CHAPTER_TWO_ENEMY_VISUAL_CATALOG_PATH: String = "res://scripts/data/chapter_two_enemy_visual_catalog.gd"
const CHAPTER_THREE_CATALOG_PATH: String = "res://scripts/data/chapter_three_catalog.gd"
const CHAPTER_THREE_ENEMY_VISUAL_CATALOG_PATH: String = "res://scripts/data/chapter_three_enemy_visual_catalog.gd"

var checks: int = 0
var failures: int = 0
var logger: Node
var saver: Variant
var journey: Variant
var transition: Variant
var CheckpointData: Variant
var HubScript: Variant
var loaded_scenes: int = 0
var loaded_scripts: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	logger = root.get_node_or_null("DebugLogger")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var token_index: int = args.find("--phase0-token")
	var token: String = ""
	if token_index >= 0 and token_index + 1 < args.size():
		token = args[token_index + 1]
	if (
		not token.begins_with("jade_phase0_")
		or str(ProjectSettings.get_setting("jade_phase0/token", "")) != token
		or not bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
		or str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")) != token
		or OS.get_user_data_dir().replace("\\", "/").get_file() != token
	):
		push_error("Use the supplied isolated Windows or Python launcher.")
		quit(2)
		return
	if logger == null or not logger.has_method("system"):
		push_error("Phase 0 requires the supplied DebugLogger replacement.")
		quit(1)
		return
	# Delay loading gameplay scripts until project autoload globals are registered.
	# Top-level preload() runs too early under --script and can report valid
	# autoload singleton names (DebugLogger, SceneTransitionManager, etc.) as missing.
	CheckpointData = load(CHECKPOINT_SCRIPT_PATH) as GDScript
	HubScript = load(HUB_SCRIPT_PATH) as GDScript
	if CheckpointData == null or HubScript == null:
		push_error("Phase 0 could not load checkpoint/hub scripts after autoload initialization.")
		quit(1)
		return
	_log("QA isolated namespace: " + token)
	_test_autoloads()
	if failures > 0:
		await _finish()
		return
	saver = root.get_node("SaveManager")
	journey = root.get_node("JourneyManager")
	transition = root.get_node("SceneTransitionManager")
	_test_resources("res://")
	_test_catalogs()
	_test_checkpoint_contracts()
	if failures == 0:
		await _test_runtime_flow()
	if failures == 0:
		await _test_added_stages()
	if failures == 0:
		await _test_chapter_two_stages()
	if failures == 0:
		await _test_chapter_three_stages()
	if failures == 0:
		await _test_release_contracts()
	await _finish()


func _log(message: String) -> void:
	logger.call("system", message)


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
	_log(("QA PASS | " if condition else "QA FAIL | ") + message)
	return condition


func _test_autoloads() -> void:
	var count: int = 0
	for property: Dictionary in ProjectSettings.get_property_list():
		var key: String = str(property.get("name", ""))
		if not key.begins_with("autoload/"):
			continue
		count += 1
		var autoload_name: String = key.trim_prefix("autoload/")
		_check(root.get_node_or_null(autoload_name) != null, "Autoload " + autoload_name)
	_check(count == 17, "Release candidate contains 17 autoloads")


func _test_resources(directory_path: String) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if not _check(directory != null, "Read resource directory " + directory_path):
		return
	var children: PackedStringArray = directory.get_directories()
	children.sort()
	for child: String in children:
		if child.begins_with(".") or child in ["__pycache__", "android", "artifacts"]:
			continue
		_test_resources(directory_path.path_join(child))
	var files: PackedStringArray = directory.get_files()
	files.sort()
	for filename: String in files:
		var path: String = directory_path.path_join(filename)
		if path == "res://tests/phase0_smoke.gd":
			continue
		if filename.get_extension() not in ["gd", "tscn", "tres", "gdshader"]:
			continue
		var resource: Resource = ResourceLoader.load(path)
		if not _check(resource != null, "Load " + path):
			continue
		if resource is GDScript:
			loaded_scripts += 1
			_check((resource as GDScript).can_instantiate(), "Compile " + path)
		if resource is PackedScene:
			loaded_scenes += 1
			var instance: Node = (resource as PackedScene).instantiate()
			_check(instance != null, "Instantiate off-tree " + path)
			if instance != null:
				instance.free()
		# Off-tree instances check construction only; _ready is exercised by
		# the actual hub/stage flow below, not by this resource sweep.


func _test_catalogs() -> void:
	var audit: Dictionary = saver.audit_save_architecture()
	_check(bool(audit.get("valid", false)), "Save catalog valid")
	_check(int(audit.get("domain_count", 0)) == 8, "Eight save domains")
	_check(int(audit.get("permanent_domain_count", 0)) == 7, "Seven permanent domains")
	_check(int(audit.get("active_run_domain_count", 0)) == 1, "One active-run domain")
	var landmark_script: GDScript = ResourceLoader.load(STAGE_LANDMARK_PREVIEW_PATH) as GDScript
	if _check(landmark_script != null, "Chapter-aware StageLandmarkPreview script loads"):
		var landmark_preview: Control = landmark_script.new() as Control
		_check(landmark_preview != null, "StageLandmarkPreview instantiates")
		if landmark_preview != null:
			landmark_preview.set("chapter_id", 2)
			landmark_preview.set("stage_id", 1)
			_check(int(landmark_preview.get("chapter_id")) == 2, "StageLandmarkPreview owns chapter identity")
			landmark_preview.free()
	_check(
		ResourceLoader.load(JOURNEY_VISUAL_CATALOG_PATH) != null,
		"Journey visual catalog supports future realm profiles"
	)
	# Chapter 3 Gate D exposes the completed Nine Heavens production catalog.
	# Progression must register the realm only after dedicated enemy/boss art exists.
	_check(
		ResourceLoader.load(CHAPTER_THREE_CATALOG_PATH) != null,
		"Chapter 3 production catalog loads"
	)
	var chapter_three_enemy_visual_catalog: Variant = ResourceLoader.load(
		CHAPTER_THREE_ENEMY_VISUAL_CATALOG_PATH
	)
	_check(
		chapter_three_enemy_visual_catalog != null,
		"Chapter 3 enemy production catalog loads"
	)

	var chapter_three_enemy_frames: Dictionary = {
		1: "res://assets/enemy/chapter3/enemy_1_cloudsea_sword_disciple_spriteframes.tres",
		2: "res://assets/enemy/chapter3/enemy_2_astral_talisman_seer_spriteframes.tres",
		3: "res://assets/enemy/chapter3/enemy_3_skybound_pursuer_spriteframes.tres",
		4: "res://assets/enemy/chapter3/enemy_4_constellation_array_adept_spriteframes.tres",
		5: "res://assets/enemy/chapter3/enemy_5_voidstar_blade_dancer_spriteframes.tres",
		6: "res://assets/enemy/chapter3/enemy_6_heavenly_ward_sentinel_spriteframes.tres",
	}
	var chapter_three_enemy_animation_contracts: Dictionary = {
		1: [&"walk_left", &"walk_right"],
		2: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"cast_left", &"cast_right"],
		3: [&"run_left", &"run_right"],
		4: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"cast_left", &"cast_right"],
		5: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"windup_left", &"windup_right", &"dash_left", &"dash_right", &"recovery_left", &"recovery_right"],
		6: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"pulse_left", &"pulse_right"],
	}
	for enemy_id: int in range(1, 7):
		var enemy_frames: SpriteFrames = ResourceLoader.load(
			str(chapter_three_enemy_frames[enemy_id])
		) as SpriteFrames
		if _check(
			enemy_frames != null,
			"Chapter 3 enemy %d dedicated SpriteFrames load" % enemy_id
		):
			for animation_name: StringName in chapter_three_enemy_animation_contracts[enemy_id]:
				_check(
					enemy_frames.has_animation(animation_name),
					"Chapter 3 enemy %d animation contract: %s"
					% [enemy_id, str(animation_name)]
				)

	var chapter_three_elite_frames: Dictionary = {
		1: "res://assets/enemy/chapter3/elite_1_starforged_iron_guardian_spriteframes.tres",
		2: "res://assets/enemy/chapter3/elite_2_ninefold_thunder_oracle_spriteframes.tres",
	}
	var chapter_three_elite_animation_contracts: Dictionary = {
		1: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"impact_left", &"impact_right"],
		2: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"cast_left", &"cast_right", &"qi_step_left", &"qi_step_right"],
	}
	for elite_id: int in range(1, 3):
		var elite_frames: SpriteFrames = ResourceLoader.load(
			str(chapter_three_elite_frames[elite_id])
		) as SpriteFrames
		if _check(
			elite_frames != null,
			"Chapter 3 elite %d dedicated SpriteFrames load" % elite_id
		):
			for animation_name: StringName in chapter_three_elite_animation_contracts[elite_id]:
				_check(
					elite_frames.has_animation(animation_name),
					"Chapter 3 elite %d animation contract: %s"
					% [elite_id, str(animation_name)]
				)

	var astral_projectile_frames: SpriteFrames = ResourceLoader.load(
		"res://assets/enemy/chapter3/enemy_2_astral_talisman_projectile_spriteframes.tres"
	) as SpriteFrames
	_check(
		astral_projectile_frames != null
		and astral_projectile_frames.has_animation(&"fly"),
		"Chapter 3 Astral Talisman projectile contract loads"
	)

	var enemy_spawner_script: GDScript = ResourceLoader.load(
		"res://scripts/enemy/enemy_spawner.gd"
	) as GDScript
	if _check(
		enemy_spawner_script != null,
		"EnemySpawner loads with Chapter 3 presentation mapping"
	):
		var identity_spawner: Node = enemy_spawner_script.new()
		identity_spawner.set(
			"stage_profile",
			{"enemy_visual_set": "nine_heavens"}
		)
		var identity_entry: Dictionary = identity_spawner.call(
			"get_stage_enemy_visual_entry",
			2,
			false
		)
		_check(
			str(identity_entry.get("display_name", ""))
			== "Astral Talisman Seer",
			"EnemySpawner resolves Nine Heavens enemy identity"
		)
		_check(
			str(identity_entry.get("presentation_theme", ""))
			== "nine_heavens",
			"Nine Heavens caster receives celestial VFX theme"
		)
		identity_spawner.free()

	var chapter_three_boss_frames: Dictionary = {
		1: CLOUDSEA_GATE_WARDEN_FRAMES_PATH,
		2: ASTRAL_MIRROR_DAOIST_FRAMES_PATH,
		3: CONSTELLATION_SWORD_SAINT_FRAMES_PATH,
		4: NINEFOLD_HEAVEN_ARBITER_FRAMES_PATH,
		5: STAR_PALACE_CELESTIAL_SOVEREIGN_FRAMES_PATH,
	}
	var chapter_three_boss_names: Array[String] = [
		"Cloudsea Gate Warden",
		"Astral Mirror Daoist",
		"Constellation Sword Saint",
		"Ninefold Heaven Arbiter",
		"Star Palace Celestial Sovereign",
	]
	var chapter_three_boss_animation_contract: Array[StringName] = [
		&"idle_left", &"idle_right",
		&"walk_left", &"walk_right",
		&"melee_left", &"melee_right",
		&"projectile_left", &"projectile_right",
		&"radial_left", &"radial_right",
		&"lightning_left", &"lightning_right",
		&"shockwave_left", &"shockwave_right",
		&"phase2_left", &"phase2_right",
	]
	for chapter_three_stage_id: int in range(1, 6):
		var chapter_three_frames_path: String = str(
			chapter_three_boss_frames.get(chapter_three_stage_id, "")
		)
		var chapter_three_frames: SpriteFrames = ResourceLoader.load(
			chapter_three_frames_path
		) as SpriteFrames
		if _check(
			chapter_three_frames != null,
			"Stage 3-%d dedicated boss SpriteFrames load" % chapter_three_stage_id
		):
			for animation_name: StringName in chapter_three_boss_animation_contract:
				_check(
					chapter_three_frames.has_animation(animation_name),
					"Stage 3-%d boss animation contract: %s"
					% [chapter_three_stage_id, str(animation_name)]
				)

	var nine_heavens_projectile_frames: SpriteFrames = ResourceLoader.load(
		NINE_HEAVENS_BOSS_PROJECTILE_FRAMES_PATH
	) as SpriteFrames
	_check(
		nine_heavens_projectile_frames != null
		and nine_heavens_projectile_frames.has_animation(&"fly"),
		"Nine Heavens boss projectile SpriteFrames contract loads"
	)

	var chapter_three_catalog_source: String = FileAccess.get_file_as_string(
		CHAPTER_THREE_CATALOG_PATH
	)
	_check(
		chapter_three_catalog_source.count("\"boss_visual_placeholder\": false") == 5,
		"Chapter 3 owns five dedicated production boss identities"
	)
	_check(
		chapter_three_catalog_source.count("\"implemented\": true") == 5,
		"Chapter 3 exposes five implemented production stages"
	)
	for boss_name: String in chapter_three_boss_names:
		_check(
			chapter_three_catalog_source.contains("\"boss_name\": \"" + boss_name + "\""),
			"Chapter 3 catalog boss identity: " + boss_name
		)

	var boss_script_source: String = FileAccess.get_file_as_string(
		"res://scripts/enemy/boss_1.gd"
	)
	for boss_name: String in chapter_three_boss_names:
		_check(
			boss_script_source.contains(boss_name),
			"Boss presentation maps Nine Heavens identity: " + boss_name
		)
	_check(
		boss_script_source.contains("return \"nine_heavens\" if _is_nine_heavens_boss() else \"\""),
		"Nine Heavens boss attacks opt into celestial hostile VFX theme"
	)

	_check(
		journey.has_chapter(3),
		"Journey registers Chapter 3 after production gates complete"
	)
	_check(
		not journey.is_chapter_unlocked(3),
		"Fresh progression keeps Chapter 3 locked before Stage 2-5 clear"
	)
	_check(
		int(journey.get_chapter_progress(3).get("total_stages", 0)) == 5,
		"Chapter 3 exposes exactly five production stages"
	)
	var chapter_three_stage_paths: Array[String] = [
		"res://scenes/levels/stage_3_1.tscn",
		"res://scenes/levels/stage_3_2.tscn",
		"res://scenes/levels/stage_3_3.tscn",
		"res://scenes/levels/stage_3_4.tscn",
		"res://scenes/levels/stage_3_5.tscn",
	]
	for stage_index: int in range(chapter_three_stage_paths.size()):
		_check(
			ResourceLoader.exists(
				chapter_three_stage_paths[stage_index],
				"PackedScene"
			),
			"Chapter 3 production scene 3-%d resolves" % (stage_index + 1)
		)
	var implemented: int = 0
	var placeholders: int = 0
	for raw_chapter_id: Variant in journey.get_chapter_ids():
		var chapter_id: int = int(raw_chapter_id)
		for raw_stage_id: Variant in journey.get_stage_ids(chapter_id):
			var stage_id: int = int(raw_stage_id)
			var data: Dictionary = journey.get_stage_data(chapter_id, stage_id)
			var path: String = str(data.get("scene_path", ""))
			if bool(data.get("implemented", false)):
				implemented += 1
				_check(not path.is_empty() and ResourceLoader.exists(path, "PackedScene"), "Implemented stage %d-%d resolves" % [chapter_id, stage_id])
			else:
				placeholders += 1
				_check(not journey.select_stage(chapter_id, stage_id), "Placeholder %d-%d cannot be selected" % [chapter_id, stage_id])
	_check(implemented == 15, "All fifteen v1.0 stages are implemented")
	_check(placeholders == 0, "No v1.0 Journey stage remains a placeholder")
	var stage_one: Dictionary = journey.get_stage_data(1, 1)
	var stage_two: Dictionary = journey.get_stage_data(1, 2)
	_check(int(stage_one.get("boss_style", -1)) == 0, "Stage 1-1 keeps the base encounter style")
	_check(str(stage_one.get("boss_name", "")) == "Valley Trial Guardian", "Stage 1-1 keeps the Valley Trial Guardian identity")
	var trial_guardian_frames: SpriteFrames = ResourceLoader.load(TRIAL_GUARDIAN_FRAMES_PATH) as SpriteFrames
	if _check(trial_guardian_frames != null, "Valley Trial Guardian bespoke SpriteFrames load"):
		for animation_name: StringName in [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"melee_left", &"melee_right", &"projectile_left", &"projectile_right", &"radial_left", &"radial_right", &"lightning_left", &"lightning_right", &"shockwave_left", &"shockwave_right", &"phase2_left", &"phase2_right"]:
			_check(trial_guardian_frames.has_animation(animation_name), "Trial Guardian animation contract: " + str(animation_name))
	_check(int(stage_two.get("boss_style", -1)) == 1, "Stage 1-2 keeps the Mistblade encounter identity")
	var mistblade_frames: SpriteFrames = ResourceLoader.load(MISTBLADE_FRAMES_PATH) as SpriteFrames
	if _check(mistblade_frames != null, "Mistblade Warden bespoke SpriteFrames load"):
		for animation_name: StringName in [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"melee_left", &"melee_right", &"projectile_left", &"projectile_right", &"radial_left", &"radial_right", &"shockwave_left", &"shockwave_right", &"phase2_left", &"phase2_right"]:
			_check(mistblade_frames.has_animation(animation_name), "Mistblade animation contract: " + str(animation_name))
	_check(float(stage_one.get("wave_duration", 0.0)) >= 12.0, "Stage 1-1 no longer uses smoke-test pacing")
	_check(float(stage_one.get("wave_duration", 999.0)) < float(stage_two.get("wave_duration", 0.0)), "Stage 1-1 remains the shortest onboarding trial")
	_check(int(stage_one.get("enemy_cap", 0)) > 0, "Stage 1-1 has a bounded enemy population")
	var mistblade_boss_stats: Dictionary = stage_two.get("boss_stats", {})
	_check(float(mistblade_boss_stats.get("max_hp", 0.0)) >= 1800.0, "Stage 1-2 Warden has production boss durability")
	_check(float(mistblade_boss_stats.get("phase_transition_invulnerability", 0.0)) > 0.0, "Stage 1-2 Warden protects its second phase from burst")
	var stage_three: Dictionary = journey.get_stage_data(1, 3)
	_check(int(stage_three.get("boss_style", -1)) == 2, "Stage 1-3 keeps the Shrine Keeper encounter identity")
	var shrine_frames: SpriteFrames = ResourceLoader.load(SHRINE_KEEPER_FRAMES_PATH) as SpriteFrames
	if _check(shrine_frames != null, "Jade Shrine Keeper bespoke SpriteFrames load"):
		for animation_name: StringName in [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"melee_left", &"melee_right", &"projectile_left", &"projectile_right", &"radial_left", &"radial_right", &"shockwave_left", &"shockwave_right", &"phase2_left", &"phase2_right"]:
			_check(shrine_frames.has_animation(animation_name), "Shrine Keeper animation contract: " + str(animation_name))
	var shrine_boss_stats: Dictionary = stage_three.get("boss_stats", {})
	_check(float(mistblade_boss_stats.get("max_hp", 0.0)) < float(shrine_boss_stats.get("max_hp", 0.0)), "Stage 1-2 Warden remains below Stage 1-3 Keeper durability")
	_check(float(shrine_boss_stats.get("max_hp", 0.0)) >= 2500.0, "Stage 1-3 Keeper has production boss durability")
	_check(float(shrine_boss_stats.get("phase_transition_invulnerability", 0.0)) > 0.0, "Stage 1-3 Keeper owns an explicit phase ward")
	var stage_four: Dictionary = journey.get_stage_data(1, 4)
	_check(int(stage_four.get("boss_style", -1)) == 3, "Stage 1-4 keeps the Stormpeak Herald encounter identity")
	var herald_frames: SpriteFrames = ResourceLoader.load(STORMPEAK_HERALD_FRAMES_PATH) as SpriteFrames
	if _check(herald_frames != null, "Stormpeak Herald bespoke SpriteFrames load"):
		for animation_name: StringName in [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"melee_left", &"melee_right", &"projectile_left", &"projectile_right", &"radial_left", &"radial_right", &"lightning_left", &"lightning_right", &"shockwave_left", &"shockwave_right", &"phase2_left", &"phase2_right"]:
			_check(herald_frames.has_animation(animation_name), "Stormpeak Herald animation contract: " + str(animation_name))
	var herald_boss_stats: Dictionary = stage_four.get("boss_stats", {})
	_check(float(herald_boss_stats.get("max_hp", 0.0)) >= 3500.0, "Stage 1-4 Herald has production boss durability")
	_check(float(herald_boss_stats.get("phase_transition_invulnerability", 0.0)) > 0.0, "Stage 1-4 Herald protects its second phase from burst")
	_check(int(stage_four.get("hazard_kind", 0)) == 2, "Stage 1-4 keeps the marked lightning hazard")
	var stage_five: Dictionary = journey.get_stage_data(1, 5)
	_check(int(stage_five.get("boss_style", -1)) == 0, "Stage 1-5 keeps the Sovereign encounter style")
	_check(str(stage_five.get("boss_name", "")) == "Jade Valley Sovereign", "Stage 1-5 keeps the Jade Valley Sovereign identity")
	var sovereign_frames: SpriteFrames = ResourceLoader.load(SOVEREIGN_FRAMES_PATH) as SpriteFrames
	if _check(sovereign_frames != null, "Jade Valley Sovereign dedicated SpriteFrames load"):
		for animation_name: StringName in [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"melee_left", &"melee_right", &"projectile_left", &"projectile_right", &"radial_left", &"radial_right", &"lightning_left", &"lightning_right", &"shockwave_left", &"shockwave_right", &"phase2_left", &"phase2_right"]:
			_check(sovereign_frames.has_animation(animation_name), "Sovereign animation contract: " + str(animation_name))
	var sovereign_boss_stats: Dictionary = stage_five.get("boss_stats", {})
	_check(bool(stage_five.get("is_chapter_boss", false)), "Stage 1-5 remains the Chapter 1 finale")
	_check(float(sovereign_boss_stats.get("max_hp", 0.0)) >= 5000.0, "Stage 1-5 Sovereign has finale-grade boss durability")
	_check(float(sovereign_boss_stats.get("max_hp", 0.0)) > float(herald_boss_stats.get("max_hp", 0.0)), "Chapter finale boss remains tougher than Stage 1-4")
	_check(float(sovereign_boss_stats.get("phase_transition_invulnerability", 0.0)) > 0.0, "Stage 1-5 Sovereign protects its awakened phase from burst")
	_check(int(stage_five.get("hazard_kind", 0)) == 1 and float(stage_five.get("hazard_interval", 0.0)) > 0.0, "Stage 1-5 keeps its Celestial seal hazard")
	_check(
		journey.has_chapter(2),
		"Chapter 2 Crimson Moon Sect is registered"
	)
	_check(
		journey.get_stage_ids(2) == [1, 2, 3, 4, 5],
		"Chapter 2 owns exactly five production stages"
	)
	_check(
		not journey.is_chapter_unlocked(2),
		"Fresh save keeps Chapter 2 locked until Chapter 1 is cleared"
	)
	_check(
		ResourceLoader.load(CHAPTER_TWO_ENEMY_VISUAL_CATALOG_PATH) != null,
		"Chapter 2 enemy visual catalog loads"
	)
	var chapter_two_enemy_frames: Dictionary = {
		1: "res://assets/enemy/chapter2/enemy_1_crimson_sect_initiate_spriteframes.tres",
		2: "res://assets/enemy/chapter2/enemy_2_cinnabar_talisman_adept_spriteframes.tres",
		3: "res://assets/enemy/chapter2/enemy_3_bloodwood_ravager_spriteframes.tres",
		4: "res://assets/enemy/chapter2/enemy_4_scarlet_array_disciple_spriteframes.tres",
		5: "res://assets/enemy/chapter2/enemy_5_moonveil_shadowblade_spriteframes.tres",
		6: "res://assets/enemy/chapter2/enemy_6_crimson_ward_keeper_spriteframes.tres",
	}
	var chapter_two_enemy_animation_contracts: Dictionary = {
		1: [&"walk_left", &"walk_right"],
		2: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"cast_left", &"cast_right"],
		3: [&"run_left", &"run_right"],
		4: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"cast_left", &"cast_right"],
		5: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"windup_left", &"windup_right", &"dash_left", &"dash_right", &"recovery_left", &"recovery_right"],
		6: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"pulse_left", &"pulse_right"],
	}
	for enemy_id: int in range(1, 7):
		var enemy_frames: SpriteFrames = ResourceLoader.load(
			str(chapter_two_enemy_frames[enemy_id])
		) as SpriteFrames
		if _check(
			enemy_frames != null,
			"Chapter 2 enemy %d dedicated SpriteFrames load" % enemy_id
		):
			for animation_name: StringName in chapter_two_enemy_animation_contracts[enemy_id]:
				_check(
					enemy_frames.has_animation(animation_name),
					"Chapter 2 enemy %d animation contract: %s"
					% [enemy_id, str(animation_name)]
				)

	var chapter_two_elite_frames: Dictionary = {
		1: "res://assets/enemy/chapter2/elite_1_scarlet_iron_enforcer_spriteframes.tres",
		2: "res://assets/enemy/chapter2/elite_2_blood_moon_ritualist_spriteframes.tres",
	}
	var chapter_two_elite_animation_contracts: Dictionary = {
		1: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"impact_left", &"impact_right"],
		2: [&"idle_left", &"idle_right", &"walk_left", &"walk_right", &"cast_left", &"cast_right", &"qi_step_left", &"qi_step_right"],
	}
	for elite_id: int in range(1, 3):
		var elite_frames: SpriteFrames = ResourceLoader.load(
			str(chapter_two_elite_frames[elite_id])
		) as SpriteFrames
		if _check(
			elite_frames != null,
			"Chapter 2 elite %d dedicated SpriteFrames load" % elite_id
		):
			for animation_name: StringName in chapter_two_elite_animation_contracts[elite_id]:
				_check(
					elite_frames.has_animation(animation_name),
					"Chapter 2 elite %d animation contract: %s"
					% [elite_id, str(animation_name)]
				)

	var chapter_one_enemy_scene: PackedScene = ResourceLoader.load(
		"res://scenes/enemy/enemy_1.tscn"
	) as PackedScene
	if _check(chapter_one_enemy_scene != null, "Chapter 1 Enemy 1 scene still loads"):
		var chapter_one_enemy: Node = chapter_one_enemy_scene.instantiate()
		var chapter_one_enemy_sprite := chapter_one_enemy.get_node_or_null(
			"AnimatedSprite2D"
		) as AnimatedSprite2D
		_check(
			chapter_one_enemy_sprite != null
			and chapter_one_enemy_sprite.sprite_frames != null
			and chapter_one_enemy_sprite.sprite_frames.resource_path
			== "res://assets/enemy/enemy_1_fallen_valley_disciple_spriteframes.tres",
			"Chapter 1 enemy presentation remains unchanged"
		)
		chapter_one_enemy.free()

	var chapter_two_boss_frames: Dictionary = {
		1: BLOODWOOD_MOONSTALKER_FRAMES_PATH,
		2: CINNABAR_VEIL_ASSASSIN_FRAMES_PATH,
		3: SCARLET_RITE_KEEPER_FRAMES_PATH,
		4: BLOOD_MOON_ASCENDANT_FRAMES_PATH,
		5: CRIMSON_MOON_SECT_MASTER_FRAMES_PATH,
	}
	var chapter_two_hp_curve: Array[float] = []
	for chapter_two_stage_id: int in range(1, 6):
		var chapter_two_stage: Dictionary = (
			journey.get_stage_data(
				2,
				chapter_two_stage_id
			)
		)
		var chapter_two_boss_stats: Dictionary = (
			chapter_two_stage.get(
				"boss_stats",
				{}
			)
		)
		chapter_two_hp_curve.append(
			float(
				chapter_two_boss_stats.get(
					"max_hp",
					0.0
				)
			)
		)
		_check(
			float(
				chapter_two_stage.get(
					"enemy_hp_multiplier",
					0.0
				)
			) >= 1.10,
			"Stage 2-%d accounts for post-Chapter-1 effective player power"
			% chapter_two_stage_id
		)
		_check(
			not bool(
				chapter_two_stage.get(
					"boss_visual_placeholder",
					true
				)
			),
			"Stage 2-%d owns dedicated production boss art"
			% chapter_two_stage_id
		)
		var chapter_two_frames_path: String = str(
			chapter_two_boss_frames.get(
				chapter_two_stage_id,
				""
			)
		)
		var chapter_two_frames: SpriteFrames = (
			ResourceLoader.load(
				chapter_two_frames_path
			) as SpriteFrames
		)
		if _check(
			chapter_two_frames != null,
			"Stage 2-%d dedicated boss SpriteFrames load"
			% chapter_two_stage_id
		):
			for animation_name: StringName in [
				&"idle_left", &"idle_right",
				&"walk_left", &"walk_right",
				&"melee_left", &"melee_right",
				&"projectile_left", &"projectile_right",
				&"radial_left", &"radial_right",
				&"lightning_left", &"lightning_right",
				&"shockwave_left", &"shockwave_right",
				&"phase2_left", &"phase2_right",
			]:
				_check(
					chapter_two_frames.has_animation(
						animation_name
					),
					"Stage 2-%d boss animation contract: %s"
					% [
						chapter_two_stage_id,
						str(animation_name),
					]
				)
	for curve_index: int in range(
		1,
		chapter_two_hp_curve.size()
	):
		_check(
			chapter_two_hp_curve[curve_index]
			> chapter_two_hp_curve[curve_index - 1],
			"Chapter 2 boss durability rises stage by stage"
		)
	_check(
		int(
			journey.get_stage_data(2, 2).get(
				"hazard_kind",
				0
			)
		) == 3,
		"Stage 2-2 introduces Moonbrand pressure"
	)
	_check(
		int(
			journey.get_stage_data(2, 3).get(
				"hazard_kind",
				0
			)
		) == 4,
		"Stage 2-3 introduces Cinnabar Burst pressure"
	)
	_check(
		bool(
			journey.get_stage_data(2, 5).get(
				"is_chapter_boss",
				false
			)
		),
		"Stage 2-5 is the Crimson Moon finale"
	)

	var reward_manager: Variant = root.get_node("RewardManager")
	for stage_id: int in range(1, 6):
		var stage_data: Dictionary = journey.get_stage_data(1, stage_id)
		var first_reward: Dictionary = reward_manager.get_stage_clear_reward(1, stage_id, true)
		var repeat_reward: Dictionary = reward_manager.get_stage_clear_reward(1, stage_id, false)
		_check(
			int(first_reward.get("spirit_stone", 0)) == int(stage_data.get("first_clear_stones", 0)),
			"Stage 1-%d first clear uses catalog Spirit Stones" % stage_id
		)
		_check(
			int(repeat_reward.get("spirit_stone", 0)) == int(stage_data.get("repeat_clear_stones", 0)),
			"Stage 1-%d repeat clear uses catalog Spirit Stones" % stage_id
		)
		var first_items: Variant = first_reward.get("items", {})
		var repeat_items: Variant = repeat_reward.get("items", {})
		_check(
			first_items is Dictionary and first_items.is_empty(),
			"Stage 1-%d first clear grants no equipment" % stage_id
		)
		_check(
			repeat_items is Dictionary
			and repeat_items.size() == 1
			and int(repeat_items.get("refinement_shard", 0))
			== int(stage_data.get("repeat_clear_shards", 0)),
			"Stage 1-%d repeat clear grants only catalog Refinement Shards" % stage_id
		)
	for stage_id: int in range(1, 6):
		var stage_data: Dictionary = (
			journey.get_stage_data(2, stage_id)
		)
		var first_reward: Dictionary = (
			reward_manager.get_stage_clear_reward(
				2,
				stage_id,
				true
			)
		)
		var repeat_reward: Dictionary = (
			reward_manager.get_stage_clear_reward(
				2,
				stage_id,
				false
			)
		)
		_check(
			int(first_reward.get("spirit_stone", 0))
			== int(
				stage_data.get(
					"first_clear_stones",
					0
				)
			),
			"Stage 2-%d first clear uses Chapter 2 catalog reward"
			% stage_id
		)
		_check(
			int(repeat_reward.get("spirit_stone", 0))
			== int(
				stage_data.get(
					"repeat_clear_stones",
					0
				)
			),
			"Stage 2-%d repeat clear uses Chapter 2 catalog reward"
			% stage_id
		)
		var first_items: Variant = first_reward.get(
			"items",
			{}
		)
		var repeat_items: Variant = repeat_reward.get(
			"items",
			{}
		)
		_check(
			first_items is Dictionary
			and first_items.is_empty(),
			"Stage 2-%d first clear keeps equipment outside stage-clear rewards"
			% stage_id
		)
		_check(
			repeat_items is Dictionary
			and repeat_items.size() == 1
			and int(repeat_items.get("refinement_shard", 0))
			== int(stage_data.get("repeat_clear_shards", 0)),
			"Stage 2-%d repeat clear grants only catalog Refinement Shards"
			% stage_id
		)

	for stage_id: int in range(1, 6):
		var stage_data: Dictionary = journey.get_stage_data(3, stage_id)
		var first_reward: Dictionary = reward_manager.get_stage_clear_reward(3, stage_id, true)
		var repeat_reward: Dictionary = reward_manager.get_stage_clear_reward(3, stage_id, false)
		_check(
			int(first_reward.get("spirit_stone", 0))
			== int(stage_data.get("first_clear_stones", 0)),
			"Stage 3-%d first clear uses Chapter 3 catalog reward" % stage_id
		)
		_check(
			int(repeat_reward.get("spirit_stone", 0))
			== int(stage_data.get("repeat_clear_stones", 0)),
			"Stage 3-%d repeat clear uses Chapter 3 catalog reward" % stage_id
		)
		var first_items: Variant = first_reward.get("items", {})
		var repeat_items: Variant = repeat_reward.get("items", {})
		_check(
			first_items is Dictionary
			and first_items.is_empty(),
			"Stage 3-%d first clear keeps equipment outside stage-clear rewards" % stage_id
		)
		_check(
			repeat_items is Dictionary
			and repeat_items.size() == 1
			and int(repeat_items.get("refinement_shard", 0))
			== int(stage_data.get("repeat_clear_shards", 0)),
			"Stage 3-%d repeat clear grants only catalog Refinement Shards" % stage_id
		)

	_log("QA catalog: %d implemented; %d placeholders" % [implemented, placeholders])
	var settings: Variant = root.get_node("SettingsManager")
	_check(settings.are_audio_buses_ready(), "Master/Music/SFX buses initialize")


func _fixture() -> Dictionary:
	return {
		"version": 1, "chapter_id": 1, "stage_id": 1,
		"survival_time": 12.0, "wave": 2, "wave_timer": 3.0,
		"difficulty_level": 1, "player_level": 2,
		"experience": 3, "experience_to_next_level": 12
	}


func _permanent_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for domain_id: String in saver.get_save_domain_ids_for_scope("permanent"):
		var path: String = saver.get_save_path(domain_id)
		for suffix: String in ["", ".backup", ".tmp", ".rollback"]:
			var artifact: String = path + suffix
			hashes[artifact] = FileAccess.get_sha256(artifact) if FileAccess.file_exists(artifact) else "MISSING"
	return hashes


func _reset_checkpoint() -> void:
	var result: Dictionary = saver.reset_active_run_saves()
	_check(bool(result.get("success", false)), "Reset active-run fixtures")


func _write_raw_fixture(payload: Variant) -> void:
	var file: FileAccess = FileAccess.open(saver.get_save_path("checkpoint"), FileAccess.WRITE)
	if not _check(file != null, "Open isolated checkpoint fixture"):
		return
	file.store_var(payload)
	file.close()


func _test_checkpoint_contracts() -> void:
	var before: Dictionary = _permanent_hashes()
	var checkpoint: Variant = CheckpointData.new()
	var hub: Variant = HubScript.new()
	_reset_checkpoint()
	_check(checkpoint._write_checkpoint_data(_fixture()), "First checkpoint writes through shared I/O")
	var second: Dictionary = _fixture()
	second["wave"] = 3
	_check(checkpoint._write_checkpoint_data(second), "Second checkpoint commits")
	_check(saver.has_save_backup("checkpoint"), "Second write produces a backup")
	var result: Dictionary = CheckpointData.read_checkpoint_result()
	_check(bool(result.get("success", false)) and int(result.get("data", {}).get("wave", 0)) == 3, "Round-trip latest wave")
	var legacy_fire_orb_checkpoint: Dictionary = _fixture()
	legacy_fire_orb_checkpoint["fire_orb_level"] = 3
	var normalized_legacy_fire_orb: Dictionary = CheckpointData.normalize_checkpoint_save_data(
		legacy_fire_orb_checkpoint
	)
	_check(
		bool(normalized_legacy_fire_orb.get("fire_orb_owned", false)),
		"Pre-acquisition checkpoint preserves legacy Fire Orb ownership"
	)
	var new_starter_checkpoint: Dictionary = _fixture()
	new_starter_checkpoint["fire_orb_owned"] = false
	var normalized_new_starter: Dictionary = CheckpointData.normalize_checkpoint_save_data(
		new_starter_checkpoint
	)
	_check(
		not bool(normalized_new_starter.get("fire_orb_owned", true)),
		"Explicit new starter checkpoint keeps Fire Orb unowned"
	)
	_write_raw_fixture("not a Dictionary")
	result = CheckpointData.read_checkpoint_result()
	_check(bool(result.get("success", false)) and bool(result.get("recovered", false)), "Invalid primary recovers valid backup")
	_check(int(result.get("data", {}).get("wave", 0)) == 2, "Recovery returns prior snapshot")
	_check(hub._has_checkpoint(), "Hub allows recovered checkpoint")
	var malformed_stats: Dictionary = _fixture()
	malformed_stats["current_health"] = []
	_write_raw_fixture(malformed_stats)
	result = CheckpointData.read_checkpoint_result()
	_check(bool(result.get("success", false)) and bool(result.get("recovered", false)), "Malformed checkpoint stats recover only a validated backup")
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(saver.get_save_path("checkpoint")))
	_check(remove_error == OK, "Remove isolated primary fixture")
	result = CheckpointData.read_checkpoint_result()
	_check(not bool(result.get("success", false)) and not saver.has_save_file("checkpoint"), "Missing primary does not resurrect stale backup")
	_check(not hub._has_checkpoint(), "Missing primary hides Continue")
	_reset_checkpoint()
	var future: Dictionary = _fixture()
	future["version"] = 2
	_write_raw_fixture(future)
	var future_hash: String = FileAccess.get_sha256(saver.get_save_path("checkpoint"))
	_check(not checkpoint._write_checkpoint_data(_fixture()), "Future schema blocks overwrite even without prior Continue")
	_check(FileAccess.get_sha256(saver.get_save_path("checkpoint")) == future_hash, "Future checkpoint bytes preserved")
	_check(not hub._has_checkpoint(), "Future checkpoint is not offered as Continue")
	_reset_checkpoint()
	var invalid_version: Dictionary = _fixture()
	invalid_version["version"] = []
	_write_raw_fixture(invalid_version)
	_check(not hub._has_checkpoint(), "Malformed schema type does not break the hub")
	for invalid_key: String in ["wave", "current_health", "fire_orb_level", "fire_orb_owned", "thunder_talisman_owned"]:
		_reset_checkpoint()
		var invalid_value: Dictionary = _fixture()
		invalid_value[invalid_key] = {"bad": "type"}
		_write_raw_fixture(invalid_value)
		_check(not hub._has_checkpoint(), "Reject malformed value: " + invalid_key)
	_reset_checkpoint()
	_write_raw_fixture({"version": 1})
	_check(not hub._has_checkpoint(), "Incomplete checkpoint hides Continue")
	_check(not checkpoint._write_checkpoint_data(_fixture()), "Unrecoverable primary is protected")
	_reset_checkpoint()
	var invalid_identity: Dictionary = _fixture()
	invalid_identity.erase("stage_id")
	_write_raw_fixture(invalid_identity)
	_check(not hub._has_checkpoint(), "Partial journey identity rejects Continue")
	_check(not checkpoint._write_checkpoint_data(_fixture()), "Invalid journey identity is preserved")
	_reset_checkpoint()
	var legacy: Dictionary = _fixture()
	legacy.erase("version")
	legacy.erase("chapter_id")
	legacy.erase("stage_id")
	_write_raw_fixture(legacy)
	result = CheckpointData.read_checkpoint_result()
	_check(bool(result.get("success", false)) and int(result.get("source_version", -1)) == 0, "Legacy v0 normalizes in memory")
	_check(hub._get_continue_scene_path() == STAGE_PATH, "Legacy routes to Stage 1-1")
	var source_data: Dictionary = saver.read_save_data("checkpoint").get("data", {})
	_check(not source_data.has("version"), "Hub read does not migrate legacy primary")
	_check(checkpoint._write_checkpoint_data(result.get("data", {})), "Legacy migration commits atomically")
	_check(saver.has_save_backup("checkpoint"), "Legacy bytes retained as backup")
	var unavailable: Dictionary = _fixture()
	unavailable["stage_id"] = 999
	_check(hub._resolve_continue_scene_path(unavailable).is_empty(), "Unknown stage cannot resume")
	var old_chapter: int = int(journey.active_run_chapter_id)
	var old_stage: int = int(journey.active_run_stage_id)
	journey.active_run_chapter_id = 1
	journey.active_run_stage_id = 2
	_check(hub._resolve_continue_scene_path(_fixture()) == STAGE_PATH, "Checkpoint identity overrides stale active Journey metadata")
	journey.active_run_chapter_id = old_chapter
	journey.active_run_stage_id = old_stage
	_reset_checkpoint()
	var protected: Dictionary = saver.delete_active_run_save("progression")
	_check(not bool(protected.get("success", false)), "Active-run API refuses permanent deletion")
	_check(_permanent_hashes() == before, "Checkpoint tests preserve all permanent primary/backup bytes")
	checkpoint.free()
	hub.free()


func _wait_for_scene(path: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and not transition.is_transitioning:
			return _check(true, "Transition completed: " + path)
	return _check(false, "Transition timed out: " + path)


func _skip_tutorial_for_smoke() -> void:
	var tutorial: Variant = current_scene.get_node_or_null("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")
	if tutorial != null and tutorial.tutorial_active:
		tutorial._on_skip_pressed()


func _test_runtime_flow() -> void:
	_check(change_scene_to_file("res://scenes/system/boot.tscn") == OK, "Start original Boot scene")
	if not await _wait_for_scene(HUB_PATH):
		return
	_check(not current_scene.call("_has_checkpoint"), "Clean boot has no Continue")
	if not await _open_journey_from_home():
		return
	current_scene.call("_on_start_pressed")
	if not await _wait_for_scene(STAGE_PATH):
		return
	var tutorial: Variant = current_scene.get_node_or_null("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")
	if tutorial != null:
		var previous_locale: String = TranslationServer.get_locale()
		TranslationServer.set_locale("id")
		tutorial.call(
			"_set_copy",
			"DAO GUIDANCE  •  1 / 5",
			"FLOWING STEPS",
			"Move Lin Yue to attune with the battlefield. Staying mobile is your first defense.",
			"OBJECTIVE • MOVE TO CONTINUE"
		)
		_check(str(tutorial.get("title_label").text) == "LANGKAH MENGALIR", "Fresh Stage 1-1 tutorial uses Indonesian catalog")
		_check(str(tutorial.get("continue_button").text) == "MULAI UJIAN", "Tutorial action button uses active locale")
		TranslationServer.set_locale(previous_locale)
	_skip_tutorial_for_smoke()
	var stage: Node = current_scene
	for node_path: String in ["player_1", "player_1/PlayerStats", "player_1/PlayerHealth", "player_1/WeaponManager", "HUD", "EnemySpawner", "WaveManager", "CheckPointManager", "VictoryManager", "GameOverManager"]:
		_check(stage.get_node_or_null(node_path) != null, "Stage dependency " + node_path)
	if failures > 0:
		return
	var hud: Variant = stage.get_node("HUD")
	hud._on_pause_pressed()
	_check(paused, "HUD pause")
	hud._on_resume_pressed()
	_check(not paused, "HUD resume")
	var player: Variant = stage.get_node("player_1")
	var weapons: Variant = player.get_node("WeaponManager")
	_check(
		weapons.get_weapons().size() == 1
		and weapons.get_weapon_by_name("Spirit Sword") != null
		and weapons.get_weapon_by_name("Fire Orb") == null,
		"Fresh run starts with Spirit Sword Lv1 only"
	)
	var level_up_panel: Variant = stage.get_node("HUD/LevelUpPanel")
	_check(
		level_up_panel.is_upgrade_available("fire_orb")
		and level_up_panel._is_new_weapon("fire_orb"),
		"Fire Orb is offered as a real NEW ART acquisition"
	)
	level_up_panel.apply_fire_orb_upgrade()
	var acquired_fire_orb: Variant = weapons.get_weapon_by_name("Fire Orb")
	_check(
		acquired_fire_orb != null and int(acquired_fire_orb.level) == 1,
		"Fire Orb acquisition creates Lv1 weapon without auto-upgrading"
	)

	var spirit_sword: Variant = weapons.get_weapon_by_name("Spirit Sword")
	var primary_target := Node2D.new()
	var secondary_near := Node2D.new()
	var secondary_far := Node2D.new()
	stage.add_child(primary_target)
	stage.add_child(secondary_near)
	stage.add_child(secondary_far)
	primary_target.global_position = player.global_position + Vector2(0.0, -120.0)
	secondary_near.global_position = player.global_position + Vector2(35.0, -150.0)
	secondary_far.global_position = player.global_position + Vector2(220.0, -150.0)
	var multi_target_candidates: Array[Node] = [
		primary_target,
		secondary_far,
		secondary_near,
	]
	_check(
		spirit_sword.resolve_secondary_attack_target(
			player.global_position,
			primary_target,
			multi_target_candidates
		) == secondary_near,
		"Dual Spirit Sword sends its second projectile to the nearest secondary enemy"
	)
	var primary_only_candidates: Array[Node] = [primary_target]
	_check(
		spirit_sword.resolve_secondary_attack_target(
			player.global_position,
			primary_target,
			primary_only_candidates
		) == primary_target,
		"Dual Spirit Sword falls back to the primary enemy instead of creating a center dead zone"
	)
	_check(
		not spirit_sword.get_secondary_origin_offset(
			player.global_position,
			primary_target.global_position
		).is_zero_approx(),
		"Same-target second Spirit Sword uses a safe non-overlapping spawn origin"
	)
	primary_target.free()
	secondary_near.free()
	secondary_far.free()

	weapons.add_thunder_talisman()
	weapons.add_yin_yang_blades()
	weapons.add_heavenly_sword_rain()
	weapons.add_eight_trigrams_formation()
	_check(weapons.get_weapons().size() == 6, "All six weapon controllers can be acquired in actual stage")
	player.speed = 242.0
	player.movement_speed_level = 2
	hud._on_pause_pressed()
	hud._on_pause_main_menu_pressed()
	if not await _wait_for_scene(HUB_PATH):
		return
	_check(current_scene.call("_has_checkpoint"), "Return to hub exposes valid Continue")
	current_scene.call("_on_continue_pressed")
	if not await _wait_for_scene(STAGE_PATH):
		return
	_skip_tutorial_for_smoke()
	player = current_scene.get_node("player_1")
	_check(is_equal_approx(float(player.speed), 242.0) and int(player.movement_speed_level) == 2, "Continue restores saved movement stats")
	weapons = player.get_node("WeaponManager")
	_check(weapons.get_weapons().size() == 6, "Continue restores six owned weapons")
	_check(journey.has_active_run(), "Continue restores active journey")
	var health: Variant = player.get_node("PlayerHealth")
	health.take_damage(1000000.0)
	_check(bool(current_scene.get_node("GameOverManager").get("game_over_triggered")), "Player defeat triggers Game Over")
	var game_over_ui: CanvasLayer = current_scene.get_node("GameOverUI") as CanvasLayer
	_check(game_over_ui != null and game_over_ui.visible, "Defeat result UI becomes visible")
	_check(game_over_ui.get("intro_tween") != null, "Defeat result UI starts presentation cadence")
	var defeated_sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_check(defeated_sprite != null and not defeated_sprite.visible, "Player source sprite yields to pooled death presentation")
	_check(not saver.has_save_file("checkpoint") and not saver.has_save_backup("checkpoint"), "Defeat clears checkpoint and backup")
	current_scene.get_node("VictoryManager").call("_on_boss_defeated")
	_check(not bool(current_scene.get_node("VictoryManager").get("victory_processed")), "Defeat blocks a competing Victory callback")
	current_scene.get_node("GameOverUI").call("_on_retry_pressed")
	if not await _wait_for_scene(STAGE_PATH):
		return
	_skip_tutorial_for_smoke()
	_check(not bool(current_scene.get_node("GameOverManager").get("game_over_triggered")), "Retry creates a fresh run")
	current_scene.get_node("EnemySpawner").call("spawn_boss")
	var boss: Variant = get_first_node_in_group("boss")
	if not _check(boss != null, "Boss initializes in actual stage"):
		return
	var trial_sprite: AnimatedSprite2D = boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_check(
		trial_sprite != null
		and trial_sprite.sprite_frames != null
		and trial_sprite.sprite_frames.resource_path == TRIAL_GUARDIAN_FRAMES_PATH,
		"Stage 1-1 boss applies bespoke Valley Trial Guardian SpriteFrames"
	)
	if trial_sprite != null:
		_check(
			trial_sprite.position.is_equal_approx(Vector2(0.0, -18.0))
			and trial_sprite.scale.is_equal_approx(Vector2(1.30, 1.30)),
			"Valley Trial Guardian keeps onboarding-grade visual scale and anchor"
		)
	var trial_collision: CollisionShape2D = boss.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var trial_capsule: CapsuleShape2D = null
	if trial_collision != null:
		trial_capsule = trial_collision.shape as CapsuleShape2D
	_check(trial_capsule != null, "Valley Trial Guardian uses a capsule gameplay footprint")
	if trial_capsule != null:
		_check(
			is_equal_approx(trial_capsule.radius, 18.0)
			and is_equal_approx(trial_capsule.height, 40.0)
			and trial_collision.position.is_equal_approx(Vector2(0.0, 12.0)),
			"Trial Guardian collider matches the compact lower-body footprint"
		)
	boss.take_damage(1000000.0)
	_check(bool(current_scene.get_node("VictoryManager").get("victory_processed")), "Boss defeat triggers Victory")
	_check(journey.is_stage_cleared(1, 1), "Victory marks Stage 1-1 cleared")
	current_scene.get_node("GameOverManager").call("_on_player_died")
	_check(not bool(current_scene.get_node("GameOverManager").get("game_over_triggered")), "Victory blocks a competing Game Over callback")
	_check(not saver.has_save_file("checkpoint") and not saver.has_save_backup("checkpoint"), "Victory clears checkpoint artifacts")
	var progression: Variant = root.get_node("ProgressionManager")
	var stones: int = int(progression.spirit_stone)
	current_scene.get_node("VictoryManager").call("_on_boss_defeated")
	_check(int(progression.spirit_stone) == stones, "Duplicate Victory callback does not grant again")
	current_scene.get_node("VictoryUI").call("_on_main_menu_pressed")
	if not await _wait_for_scene(HUB_PATH):
		return
	_check(not current_scene.call("_has_checkpoint"), "Victory hub has no stale Continue")
	if not await _open_journey_from_home():
		return
	current_scene.call("_on_start_pressed")
	if not await _wait_for_scene(STAGE_PATH):
		return
	_skip_tutorial_for_smoke()
	var future: Dictionary = _fixture()
	future["version"] = 2
	_write_raw_fixture(future)
	var protected_hash: String = FileAccess.get_sha256(saver.get_save_path("checkpoint"))
	current_scene.get_node("CheckPointManager").call("_load_continue")
	if not await _wait_for_scene(HUB_PATH):
		return
	_check(FileAccess.get_sha256(saver.get_save_path("checkpoint")) == protected_hash, "Failed runtime Continue returns to hub without overwrite")
	_check(not current_scene.call("_has_checkpoint"), "Rejected checkpoint is hidden from Continue")
	if not await _open_journey_from_home():
		return
	current_scene.call("_on_start_pressed")
	var modal: Control = current_scene.get("start_confirm_dialog") as Control
	_check(modal.visible, "Journey still confirms discarding an invalid checkpoint")
	modal.hide()
	_reset_checkpoint()
	_check(change_scene_to_file(HUB_PATH) == OK, "Return to Home after confirmation test")
	await _wait_for_scene(HUB_PATH)


func _open_journey_from_home() -> bool:
	current_scene.call("_on_journey_pressed")
	if not await _wait_for_scene(CHAPTER_SELECT_PATH):
		return false
	var chapter_id: int = int(journey.selected_chapter_id)
	current_scene.call("_on_chapter_pressed", chapter_id)
	return await _wait_for_scene(JOURNEY_PATH)


func _test_added_stages() -> void:
	for stage_id: int in range(2, 6):
		_check(journey.is_stage_unlocked(1, stage_id), "Previous clear unlocks stage 1-%d" % stage_id)
		_check(journey.select_stage(1, stage_id), "Select stage 1-%d" % stage_id)
		var profile: Dictionary = journey.get_stage_data(1, stage_id)
		var path: String = str(profile["scene_path"])
		if not await _open_journey_from_home():
			return
		current_scene.call("_on_start_pressed")
		if not await _wait_for_scene(path):
			return
		_check(int(current_scene.get("stage_id")) == stage_id, "Scene applies its own stage identity")
		var stage_decor: Node = current_scene.get_node("VerdantQiValleyDecor")
		_check(int(stage_decor.get("stage_id")) == stage_id, "Distinct stage decoration loaded")
		if stage_id >= 2:
			var expected_signature: Dictionary = {
				2: "bamboo_mist_pass",
				3: "ruined_jade_shrine",
				4: "storm_peak_approach",
				5: "sovereign_celestial_gate",
			}
			_check(
				stage_decor.has_method("get_visual_signature")
				and str(stage_decor.call("get_visual_signature")) == str(expected_signature.get(stage_id, "")),
				"Stage 1-%d exposes its bespoke environment signature" % stage_id
			)
		var wave: Variant = current_scene.get_node("WaveManager")
		_check(is_equal_approx(float(wave.wave_duration), float(profile["wave_duration"])), "Stage wave duration configured before play")
		wave.current_wave = 3
		wave.wave_timer = 4.25
		var hud: Variant = current_scene.get_node("HUD")
		hud._on_pause_pressed()
		hud._on_pause_main_menu_pressed()
		if not await _wait_for_scene(HUB_PATH):
			return
		# Deliberately browse another stage before Continue. The snapshot wins.
		journey.select_stage(1, 1)
		_check(current_scene.call("_get_continue_scene_path") == path, "Continue keeps the saved stage, not the browsed stage")
		current_scene.call("_on_continue_pressed")
		if not await _wait_for_scene(path):
			return
		_check(int(journey.active_run_stage_id) == stage_id, "Continue restores stage 1-%d identity" % stage_id)
		wave = current_scene.get_node("WaveManager")
		_check(int(wave.current_wave) == 3, "Continue restores the saved wave")
		if stage_id == 2:
			current_scene.get_node("player_1/PlayerHealth").call("take_damage", 1000000.0)
			current_scene.get_node("GameOverUI").call("_on_retry_pressed")
			if not await _wait_for_scene(path):
				return
			wave = current_scene.get_node("WaveManager")
			_check(int(wave.current_wave) == 1, "New stage Retry starts fresh in the correct arena")
		wave.current_wave = wave.final_wave
		var spawner: Variant = current_scene.get_node("EnemySpawner")
		spawner.spawn_boss()
		spawner.spawn_boss()
		_check(get_nodes_in_group("boss").size() == 1, "Boss spawning is idempotent")
		var boss: Variant = get_first_node_in_group("boss")
		if not _check(boss != null, "Stage boss initializes"):
			return
		_check(boss.get_encounter_display_name() == str(profile["boss_name"]), "Boss encounter name matches stage")
		if stage_id == 2:
			var mistblade_sprite: AnimatedSprite2D = boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			_check(
				mistblade_sprite != null
				and mistblade_sprite.sprite_frames != null
				and mistblade_sprite.sprite_frames.resource_path == MISTBLADE_FRAMES_PATH,
				"Stage 1-2 boss applies Mistblade bespoke SpriteFrames"
			)
			var mistblade_collision: CollisionShape2D = boss.get_node_or_null("CollisionShape2D") as CollisionShape2D
			var mistblade_capsule: CapsuleShape2D = null
			if mistblade_collision != null:
				mistblade_capsule = mistblade_collision.shape as CapsuleShape2D
			_check(mistblade_capsule != null, "Mistblade Warden uses a capsule gameplay footprint")
			if mistblade_capsule != null:
				_check(
					is_equal_approx(mistblade_capsule.radius, 18.0)
					and is_equal_approx(mistblade_capsule.height, 42.0)
					and mistblade_collision.position.is_equal_approx(Vector2(0.0, 15.0)),
					"Mistblade collider matches the audited lower-body footprint"
				)
		elif stage_id == 3:
			var shrine_sprite: AnimatedSprite2D = boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			_check(
				shrine_sprite != null
				and shrine_sprite.sprite_frames != null
				and shrine_sprite.sprite_frames.resource_path == SHRINE_KEEPER_FRAMES_PATH,
				"Stage 1-3 boss applies Jade Shrine Keeper bespoke SpriteFrames"
			)
			var shrine_collision: CollisionShape2D = boss.get_node_or_null("CollisionShape2D") as CollisionShape2D
			var shrine_capsule: CapsuleShape2D = null
			if shrine_collision != null:
				shrine_capsule = shrine_collision.shape as CapsuleShape2D
			_check(shrine_capsule != null, "Jade Shrine Keeper uses a capsule gameplay footprint")
			if shrine_capsule != null:
				_check(
					is_equal_approx(shrine_capsule.radius, 24.0)
					and is_equal_approx(shrine_capsule.height, 52.0)
					and shrine_collision.position.is_equal_approx(Vector2(0.0, 14.0)),
					"Shrine Keeper collider matches the audited heavy lower-body footprint"
				)
		elif stage_id == 4:
			var stormpeak_sprite: AnimatedSprite2D = boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			_check(
				stormpeak_sprite != null
				and stormpeak_sprite.sprite_frames != null
				and stormpeak_sprite.sprite_frames.resource_path == STORMPEAK_HERALD_FRAMES_PATH,
				"Stage 1-4 boss applies Stormpeak Herald bespoke SpriteFrames"
			)
			var stormpeak_collision: CollisionShape2D = boss.get_node_or_null("CollisionShape2D") as CollisionShape2D
			var stormpeak_capsule: CapsuleShape2D = null
			if stormpeak_collision != null:
				stormpeak_capsule = stormpeak_collision.shape as CapsuleShape2D
			_check(stormpeak_capsule != null, "Stormpeak Herald uses a capsule gameplay footprint")
			if stormpeak_capsule != null:
				_check(
					is_equal_approx(stormpeak_capsule.radius, 20.0)
					and is_equal_approx(stormpeak_capsule.height, 48.0)
					and stormpeak_collision.position.is_equal_approx(Vector2(0.0, 14.0)),
					"Stormpeak Herald collider matches the audited tall-caster lower-body footprint"
				)
		elif stage_id == 5:
			var sovereign_sprite: AnimatedSprite2D = boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			_check(
				sovereign_sprite != null
				and sovereign_sprite.sprite_frames != null
				and sovereign_sprite.sprite_frames.resource_path == SOVEREIGN_FRAMES_PATH,
				"Stage 1-5 boss applies dedicated Jade Valley Sovereign SpriteFrames"
			)
			if sovereign_sprite != null:
				_check(
					sovereign_sprite.position.is_equal_approx(Vector2(0.0, -27.0))
					and sovereign_sprite.scale.is_equal_approx(Vector2(1.65, 1.65)),
					"Jade Valley Sovereign uses finale-grade visual scale and anchor"
				)
			var sovereign_collision: CollisionShape2D = boss.get_node_or_null("CollisionShape2D") as CollisionShape2D
			var sovereign_capsule: CapsuleShape2D = null
			if sovereign_collision != null:
				sovereign_capsule = sovereign_collision.shape as CapsuleShape2D
			_check(sovereign_capsule != null, "Jade Valley Sovereign uses a capsule gameplay footprint")
			if sovereign_capsule != null:
				_check(
					is_equal_approx(sovereign_capsule.radius, 22.0)
					and is_equal_approx(sovereign_capsule.height, 50.0)
					and sovereign_collision.position.is_equal_approx(Vector2(0.0, 15.0)),
					"Sovereign collider matches the audited ceremonial lower-body footprint"
				)
		boss.take_damage(float(boss.max_hp) * 0.45)
		_check(int(boss.current_phase) == 2, "Stage boss enters the second phase")
		if float(boss.get("phase_transition_invulnerability")) > 0.0:
			var warded_hp: float = float(boss.current_hp)
			boss.take_damage(1000000.0)
			_check(is_equal_approx(float(boss.current_hp), warded_hp), "Opt-in phase ward rejects burst damage during transition")
			boss.call("update_phase_transition_timer", float(boss.get("phase_transition_invulnerability")) + 0.01)
		var progression: Variant = root.get_node("ProgressionManager")
		var before_stones: int = int(progression.spirit_stone)
		boss.take_damage(1000000.0)
		_check(journey.is_stage_cleared(1, stage_id), "Victory persists new stage clear")
		_check(int(progression.spirit_stone) - before_stones == int(profile["first_clear_stones"]), "Correct first-clear stage reward")
		var granted: int = int(progression.spirit_stone)
		current_scene.get_node("VictoryManager").call("_on_boss_defeated")
		_check(int(progression.spirit_stone) == granted, "Duplicate callback cannot grant twice")
		current_scene.get_node("VictoryUI").call("_on_main_menu_pressed")
		if not await _wait_for_scene(HUB_PATH):
			return
	_check(int(journey.get_chapter_progress(1)["cleared_stages"]) == 5, "All five Chapter 1 stages cleared")
	_check(not journey.is_stage_unlocked(1, 6), "Final clear creates no phantom stage")


func _test_chapter_two_stages() -> void:
	_check(
		journey.is_stage_unlocked(2, 1),
		"Clearing Chapter 1 unlocks Chapter 2 Stage 2-1"
	)

	var expected_signatures: Dictionary = {
		1: "moonlit_bloodwood",
		2: "cinnabar_veil_pass",
		3: "scarlet_ritual_court",
		4: "blood_moon_ascension_stair",
		5: "crimson_moon_sanctum",
	}
	var expected_boss_frames: Dictionary = {
		1: BLOODWOOD_MOONSTALKER_FRAMES_PATH,
		2: CINNABAR_VEIL_ASSASSIN_FRAMES_PATH,
		3: SCARLET_RITE_KEEPER_FRAMES_PATH,
		4: BLOOD_MOON_ASCENDANT_FRAMES_PATH,
		5: CRIMSON_MOON_SECT_MASTER_FRAMES_PATH,
	}
	var expected_boss_footprints: Dictionary = {
		1: [18.0, 42.0, Vector2(0.0, 14.0)],
		2: [17.0, 40.0, Vector2(0.0, 14.0)],
		3: [24.0, 54.0, Vector2(0.0, 15.0)],
		4: [19.0, 46.0, Vector2(0.0, 14.0)],
		5: [22.0, 50.0, Vector2(0.0, 15.0)],
	}

	for stage_id: int in range(1, 6):
		_check(
			journey.is_stage_unlocked(2, stage_id),
			"Previous clear unlocks stage 2-%d"
			% stage_id
		)
		_check(
			journey.select_stage(2, stage_id),
			"Select stage 2-%d"
			% stage_id
		)

		var profile: Dictionary = (
			journey.get_stage_data(2, stage_id)
		)
		var path: String = str(
			profile.get("scene_path", "")
		)

		if not await _open_journey_from_home():
			return

		current_scene.call("_on_start_pressed")
		if not await _wait_for_scene(path):
			return

		_check(
			int(current_scene.get("stage_id")) == stage_id,
			"Stage 2-%d scene owns its stage identity"
			% stage_id
		)

		var stage_decor: Node = current_scene.get_node(
			"VerdantQiValleyDecor"
		)
		_check(
			int(stage_decor.get("stage_id")) == stage_id,
			"Stage 2-%d loads Crimson Moon decor"
			% stage_id
		)
		_check(
			stage_decor.has_method("get_visual_signature")
			and str(
				stage_decor.call(
					"get_visual_signature"
				)
			) == str(
				expected_signatures.get(
					stage_id,
					""
				)
			),
			"Stage 2-%d exposes a distinct environment signature"
			% stage_id
		)

		var wave: Variant = current_scene.get_node(
			"WaveManager"
		)
		_check(
			is_equal_approx(
				float(wave.wave_duration),
				float(profile["wave_duration"])
			),
			"Stage 2-%d applies its production wave duration"
			% stage_id
		)

		var spawner: Variant = current_scene.get_node(
			"EnemySpawner"
		)
		_check(
			is_equal_approx(
				float(
					spawner.stage_profile.get(
						"enemy_hp_multiplier",
						0.0
					)
				),
				float(
					profile.get(
						"enemy_hp_multiplier",
						0.0
					)
				)
			),
			"Stage 2-%d passes its effective-power scaling to EnemySpawner"
			% stage_id
		)

		_check(
			str(spawner.stage_profile.get("enemy_visual_set", ""))
			== "crimson_moon",
			"Stage 2-%d selects Crimson Moon enemy identity" % stage_id
		)

		if stage_id == 1:
			var expected_enemy_paths: Array[String] = [
				"res://assets/enemy/chapter2/enemy_1_crimson_sect_initiate_spriteframes.tres",
				"res://assets/enemy/chapter2/enemy_2_cinnabar_talisman_adept_spriteframes.tres",
				"res://assets/enemy/chapter2/enemy_3_bloodwood_ravager_spriteframes.tres",
				"res://assets/enemy/chapter2/enemy_4_scarlet_array_disciple_spriteframes.tres",
				"res://assets/enemy/chapter2/enemy_5_moonveil_shadowblade_spriteframes.tres",
				"res://assets/enemy/chapter2/enemy_6_crimson_ward_keeper_spriteframes.tres",
			]
			var expected_enemy_names: Array[String] = [
				"Crimson Sect Initiate",
				"Cinnabar Talisman Adept",
				"Bloodwood Ravager",
				"Scarlet Array Disciple",
				"Moonveil Shadowblade",
				"Crimson Ward Keeper",
			]
			var enemy_scene_properties: Array[StringName] = [
				&"enemy_scene", &"enemy_2_scene", &"enemy_3_scene",
				&"enemy_4_scene", &"enemy_5_scene", &"enemy_6_scene",
			]
			for enemy_index: int in range(enemy_scene_properties.size()):
				var normal_scene := spawner.get(enemy_scene_properties[enemy_index]) as PackedScene
				var normal_enemy: Node = normal_scene.instantiate()
				spawner.apply_stage_enemy_identity(normal_enemy, enemy_index + 1)
				var normal_sprite := normal_enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
				_check(
					normal_sprite != null
					and normal_sprite.sprite_frames != null
					and normal_sprite.sprite_frames.resource_path == expected_enemy_paths[enemy_index],
					"Chapter 2 maps enemy archetype %d to dedicated presentation" % (enemy_index + 1)
				)
				_check(
					str(normal_enemy.get_meta("encounter_display_name", "")) == expected_enemy_names[enemy_index],
					"Chapter 2 maps enemy archetype %d display identity" % (enemy_index + 1)
				)
				normal_enemy.free()

			var elite_two_scene := spawner.elite_enemy_2_scene as PackedScene
			var elite_two: Node = elite_two_scene.instantiate()
			spawner.apply_stage_enemy_identity(elite_two, 2, true)
			var elite_two_sprite := elite_two.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			_check(
				elite_two_sprite != null
				and elite_two_sprite.sprite_frames != null
				and elite_two_sprite.sprite_frames.resource_path
				== "res://assets/enemy/chapter2/elite_2_blood_moon_ritualist_spriteframes.tres",
				"Chapter 2 replaces Storm Cultivator presentation with Blood Moon Ritualist"
			)
			_check(
				StringName(elite_two.get("presentation_theme")) == &"crimson_moon",
				"Blood Moon Ritualist uses Crimson Moon hostile VFX palette"
			)
			elite_two.free()

		# One cross-Chapter checkpoint/Continue proof is enough; the same manager
		# contract then owns stages 2-2..2-5.
		if stage_id == 1:
			wave.current_wave = 3
			wave.wave_timer = 4.5
			var hud: Variant = current_scene.get_node(
				"HUD"
			)
			hud._on_pause_pressed()
			hud._on_pause_main_menu_pressed()
			if not await _wait_for_scene(HUB_PATH):
				return

			journey.select_stage(1, 1)
			_check(
				current_scene.call(
					"_get_continue_scene_path"
				) == path,
				"Chapter 2 checkpoint wins over later Chapter 1 browsing"
			)
			current_scene.call("_on_continue_pressed")
			if not await _wait_for_scene(path):
				return

			_check(
				int(journey.active_run_chapter_id) == 2
				and int(journey.active_run_stage_id) == 1,
				"Continue restores Chapter 2 Stage 2-1 identity"
			)
			wave = current_scene.get_node(
				"WaveManager"
			)
			_check(
				int(wave.current_wave) == 3,
				"Continue restores Chapter 2 saved wave"
			)
			spawner = current_scene.get_node(
				"EnemySpawner"
			)

		wave.current_wave = wave.final_wave
		spawner.spawn_boss()
		spawner.spawn_boss()

		_check(
			get_nodes_in_group("boss").size() == 1,
			"Stage 2-%d boss spawning is idempotent"
			% stage_id
		)

		var boss: Variant = get_first_node_in_group(
			"boss"
		)
		if not _check(
			boss != null,
			"Stage 2-%d boss initializes"
			% stage_id
		):
			return

		_check(
			boss.get_encounter_display_name()
			== str(profile["boss_name"]),
			"Stage 2-%d boss encounter name matches catalog"
			% stage_id
		)
		var boss_sprite: AnimatedSprite2D = (
			boss.get_node_or_null(
				"AnimatedSprite2D"
			) as AnimatedSprite2D
		)
		_check(
			boss_sprite != null
			and boss_sprite.sprite_frames != null
			and boss_sprite.sprite_frames.resource_path
			== str(expected_boss_frames.get(stage_id, "")),
			"Stage 2-%d boss applies its dedicated SpriteFrames"
			% stage_id
		)
		var boss_collision: CollisionShape2D = (
			boss.get_node_or_null(
				"CollisionShape2D"
			) as CollisionShape2D
		)
		var boss_capsule: CapsuleShape2D = null
		if boss_collision != null:
			boss_capsule = (
				boss_collision.shape as CapsuleShape2D
			)
		_check(
			boss_capsule != null,
			"Stage 2-%d boss uses a capsule gameplay footprint"
			% stage_id
		)
		if boss_capsule != null:
			var footprint: Array = (
				expected_boss_footprints.get(
					stage_id,
					[]
				) as Array
			)
			_check(
				footprint.size() == 3
				and is_equal_approx(
					boss_capsule.radius,
					float(footprint[0])
				)
				and is_equal_approx(
					boss_capsule.height,
					float(footprint[1])
				)
				and boss_collision.position.is_equal_approx(
					footprint[2] as Vector2
				),
				"Stage 2-%d boss collider matches its grounded footprint"
				% stage_id
			)

		var boss_stats: Dictionary = profile.get(
			"boss_stats",
			{}
		)
		_check(
			is_equal_approx(
				float(boss.max_hp),
				float(
					boss_stats.get(
						"max_hp",
						0.0
					)
				)
			),
			"Stage 2-%d boss HP follows effective-power baseline"
			% stage_id
		)
		_check(
			is_equal_approx(
				float(
					boss.get(
						"projectile_damage"
					)
				),
				float(
					boss_stats.get(
						"projectile_damage",
						2.0
					)
				)
			),
			"Stage 2-%d boss projectile damage is profile-driven"
			% stage_id
		)

		boss.take_damage(
			float(boss.max_hp) * 0.45
		)
		_check(
			int(boss.current_phase) == 2,
			"Stage 2-%d boss reaches Phase 2"
			% stage_id
		)

		if (
			float(
				boss.get(
					"phase_transition_invulnerability"
				)
			) > 0.0
		):
			var warded_hp: float = float(
				boss.current_hp
			)
			boss.take_damage(1000000.0)
			_check(
				is_equal_approx(
					float(boss.current_hp),
					warded_hp
				),
				"Stage 2-%d phase ward rejects threshold burst"
				% stage_id
			)
			boss.call(
				"update_phase_transition_timer",
				float(
					boss.get(
						"phase_transition_invulnerability"
					)
				) + 0.01
			)

		var progression: Variant = root.get_node(
			"ProgressionManager"
		)
		var before_stones: int = int(
			progression.spirit_stone
		)
		boss.take_damage(1000000.0)

		_check(
			journey.is_stage_cleared(
				2,
				stage_id
			),
			"Victory persists Stage 2-%d clear"
			% stage_id
		)
		_check(
			int(progression.spirit_stone)
			- before_stones
			== int(
				profile["first_clear_stones"]
			),
			"Stage 2-%d grants the correct first-clear reward"
			% stage_id
		)

		var granted: int = int(
			progression.spirit_stone
		)
		current_scene.get_node(
			"VictoryManager"
		).call("_on_boss_defeated")
		_check(
			int(progression.spirit_stone) == granted,
			"Stage 2-%d duplicate Victory callback cannot grant twice"
			% stage_id
		)

		current_scene.get_node(
			"VictoryUI"
		).call("_on_main_menu_pressed")
		if not await _wait_for_scene(HUB_PATH):
			return

	_check(
		int(
			journey.get_chapter_progress(2).get(
				"cleared_stages",
				0
			)
		) == 5,
		"All five Chapter 2 stages clear through automated regression"
	)
	_check(
		not journey.is_stage_unlocked(2, 6),
		"Chapter 2 final clear creates no phantom Stage 2-6"
	)
	_check(
		journey.has_chapter(3),
		"Chapter 3 remains registered after Chapter 2 completion"
	)
	_check(
		journey.is_stage_unlocked(3, 1),
		"Clearing Stage 2-5 unlocks Chapter 3 Stage 3-1"
	)
	_check(
		journey.is_chapter_unlocked(3),
		"Clearing Stage 2-5 unlocks the Nine Heavens realm"
	)
	_check(
		not journey.is_stage_unlocked(3, 2),
		"Chapter 3 unlock starts at Stage 3-1 only"
	)


func _test_chapter_three_stages() -> void:
	_check(
		journey.is_stage_unlocked(3, 1),
		"Chapter 2 finale unlocks Chapter 3 Stage 3-1"
	)

	var expected_signatures: Dictionary = {
		1: "cloudsea_star_gate",
		2: "astral_mirror_causeway",
		3: "constellation_sword_court",
		4: "ninefold_heaven_terrace",
		5: "celestial_star_palace",
	}
	var expected_boss_frames: Dictionary = {
		1: CLOUDSEA_GATE_WARDEN_FRAMES_PATH,
		2: ASTRAL_MIRROR_DAOIST_FRAMES_PATH,
		3: CONSTELLATION_SWORD_SAINT_FRAMES_PATH,
		4: NINEFOLD_HEAVEN_ARBITER_FRAMES_PATH,
		5: STAR_PALACE_CELESTIAL_SOVEREIGN_FRAMES_PATH,
	}
	var expected_boss_footprints: Dictionary = {
		1: [20.0, 46.0, Vector2(0.0, 14.0)],
		2: [18.0, 42.0, Vector2(0.0, 14.0)],
		3: [20.0, 46.0, Vector2(0.0, 14.0)],
		4: [20.0, 48.0, Vector2(0.0, 15.0)],
		5: [23.0, 52.0, Vector2(0.0, 15.0)],
	}

	for stage_id: int in range(1, 6):
		_check(
			journey.is_stage_unlocked(3, stage_id),
			"Previous clear unlocks stage 3-%d" % stage_id
		)
		_check(
			journey.select_stage(3, stage_id),
			"Select stage 3-%d" % stage_id
		)

		var profile: Dictionary = journey.get_stage_data(3, stage_id)
		var path: String = str(profile.get("scene_path", ""))

		if not await _open_journey_from_home():
			return

		current_scene.call("_on_start_pressed")
		if not await _wait_for_scene(path):
			return

		_check(
			int(current_scene.get("stage_id")) == stage_id,
			"Stage 3-%d scene owns its stage identity" % stage_id
		)

		var stage_decor: Node = current_scene.get_node("VerdantQiValleyDecor")
		_check(
			int(stage_decor.get("stage_id")) == stage_id,
			"Stage 3-%d loads Nine Heavens decor" % stage_id
		)
		_check(
			stage_decor.has_method("get_visual_signature")
			and str(stage_decor.call("get_visual_signature"))
			== str(expected_signatures.get(stage_id, "")),
			"Stage 3-%d exposes a distinct environment signature" % stage_id
		)

		var wave: Variant = current_scene.get_node("WaveManager")
		_check(
			is_equal_approx(float(wave.wave_duration), float(profile["wave_duration"])),
			"Stage 3-%d applies its production wave duration" % stage_id
		)

		var spawner: Variant = current_scene.get_node("EnemySpawner")
		_check(
			is_equal_approx(
				float(spawner.stage_profile.get("enemy_hp_multiplier", 0.0)),
				float(profile.get("enemy_hp_multiplier", 0.0))
			),
			"Stage 3-%d passes its effective-power scaling to EnemySpawner" % stage_id
		)
		_check(
			str(spawner.stage_profile.get("enemy_visual_set", "")) == "nine_heavens",
			"Stage 3-%d selects Nine Heavens enemy identity" % stage_id
		)

		if stage_id == 1:
			var expected_enemy_paths: Array[String] = [
				"res://assets/enemy/chapter3/enemy_1_cloudsea_sword_disciple_spriteframes.tres",
				"res://assets/enemy/chapter3/enemy_2_astral_talisman_seer_spriteframes.tres",
				"res://assets/enemy/chapter3/enemy_3_skybound_pursuer_spriteframes.tres",
				"res://assets/enemy/chapter3/enemy_4_constellation_array_adept_spriteframes.tres",
				"res://assets/enemy/chapter3/enemy_5_voidstar_blade_dancer_spriteframes.tres",
				"res://assets/enemy/chapter3/enemy_6_heavenly_ward_sentinel_spriteframes.tres",
			]
			var expected_enemy_names: Array[String] = [
				"Cloudsea Sword Disciple",
				"Astral Talisman Seer",
				"Skybound Pursuer",
				"Constellation Array Adept",
				"Voidstar Blade Dancer",
				"Heavenly Ward Sentinel",
			]
			var enemy_scene_properties: Array[StringName] = [
				&"enemy_scene", &"enemy_2_scene", &"enemy_3_scene",
				&"enemy_4_scene", &"enemy_5_scene", &"enemy_6_scene",
			]
			for enemy_index: int in range(enemy_scene_properties.size()):
				var normal_scene := spawner.get(enemy_scene_properties[enemy_index]) as PackedScene
				var normal_enemy: Node = normal_scene.instantiate()
				spawner.apply_stage_enemy_identity(normal_enemy, enemy_index + 1)
				var normal_sprite := normal_enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
				_check(
					normal_sprite != null
					and normal_sprite.sprite_frames != null
					and normal_sprite.sprite_frames.resource_path == expected_enemy_paths[enemy_index],
					"Chapter 3 maps enemy archetype %d to dedicated presentation" % (enemy_index + 1)
				)
				_check(
					str(normal_enemy.get_meta("encounter_display_name", "")) == expected_enemy_names[enemy_index],
					"Chapter 3 maps enemy archetype %d display identity" % (enemy_index + 1)
				)
				normal_enemy.free()

			var elite_two_scene := spawner.elite_enemy_2_scene as PackedScene
			var elite_two: Node = elite_two_scene.instantiate()
			spawner.apply_stage_enemy_identity(elite_two, 2, true)
			var elite_two_sprite := elite_two.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			_check(
				elite_two_sprite != null
				and elite_two_sprite.sprite_frames != null
				and elite_two_sprite.sprite_frames.resource_path
				== "res://assets/enemy/chapter3/elite_2_ninefold_thunder_oracle_spriteframes.tres",
				"Chapter 3 maps elite 2 to Ninefold Thunder Oracle"
			)
			_check(
				StringName(elite_two.get("presentation_theme")) == &"nine_heavens",
				"Ninefold Thunder Oracle uses Nine Heavens hostile VFX palette"
			)
			elite_two.free()

		# One Chapter 3 checkpoint/Continue proof guards true active-stage identity.
		if stage_id == 1:
			wave.current_wave = 3
			wave.wave_timer = 4.25
			var hud: Variant = current_scene.get_node("HUD")
			hud._on_pause_pressed()
			hud._on_pause_main_menu_pressed()
			if not await _wait_for_scene(HUB_PATH):
				return

			journey.select_stage(1, 1)
			_check(
				current_scene.call("_get_continue_scene_path") == path,
				"Chapter 3 checkpoint wins over later Chapter 1 browsing"
			)
			current_scene.call("_on_continue_pressed")
			if not await _wait_for_scene(path):
				return
			_check(
				int(journey.active_run_chapter_id) == 3
				and int(journey.active_run_stage_id) == 1,
				"Continue restores Chapter 3 Stage 3-1 identity"
			)
			wave = current_scene.get_node("WaveManager")
			_check(
				int(wave.current_wave) == 3,
				"Continue restores Chapter 3 saved wave"
			)
			spawner = current_scene.get_node("EnemySpawner")

		wave.current_wave = wave.final_wave
		spawner.spawn_boss()
		spawner.spawn_boss()
		_check(
			get_nodes_in_group("boss").size() == 1,
			"Stage 3-%d boss spawning is idempotent" % stage_id
		)

		var boss: Variant = get_first_node_in_group("boss")
		if not _check(boss != null, "Stage 3-%d boss initializes" % stage_id):
			return
		_check(
			boss.get_encounter_display_name() == str(profile["boss_name"]),
			"Stage 3-%d boss encounter name matches catalog" % stage_id
		)
		var boss_sprite: AnimatedSprite2D = boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		_check(
			boss_sprite != null
			and boss_sprite.sprite_frames != null
			and boss_sprite.sprite_frames.resource_path == str(expected_boss_frames.get(stage_id, "")),
			"Stage 3-%d boss applies its dedicated SpriteFrames" % stage_id
		)
		var boss_collision: CollisionShape2D = boss.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var boss_capsule: CapsuleShape2D = null
		if boss_collision != null:
			boss_capsule = boss_collision.shape as CapsuleShape2D
		_check(boss_capsule != null, "Stage 3-%d boss uses a capsule gameplay footprint" % stage_id)
		if boss_capsule != null:
			var footprint: Array = expected_boss_footprints.get(stage_id, []) as Array
			_check(
				footprint.size() == 3
				and is_equal_approx(boss_capsule.radius, float(footprint[0]))
				and is_equal_approx(boss_capsule.height, float(footprint[1]))
				and boss_collision.position.is_equal_approx(footprint[2] as Vector2),
				"Stage 3-%d boss collider matches its grounded footprint" % stage_id
			)

		var boss_stats: Dictionary = profile.get("boss_stats", {})
		_check(
			is_equal_approx(float(boss.max_hp), float(boss_stats.get("max_hp", 0.0))),
			"Stage 3-%d boss HP follows Nine Heavens baseline" % stage_id
		)
		_check(
			is_equal_approx(
				float(boss.get("projectile_damage")),
				float(boss_stats.get("projectile_damage", 2.0))
			),
			"Stage 3-%d boss projectile damage is profile-driven" % stage_id
		)

		boss.take_damage(float(boss.max_hp) * 0.55)
		_check(int(boss.current_phase) == 2, "Stage 3-%d boss reaches Phase 2" % stage_id)
		if float(boss.get("phase_transition_invulnerability")) > 0.0:
			var warded_hp: float = float(boss.current_hp)
			boss.take_damage(1000000.0)
			_check(
				is_equal_approx(float(boss.current_hp), warded_hp),
				"Stage 3-%d phase ward rejects threshold burst" % stage_id
			)
			boss.call(
				"update_phase_transition_timer",
				float(boss.get("phase_transition_invulnerability")) + 0.01
			)

		var progression: Variant = root.get_node("ProgressionManager")
		var before_stones: int = int(progression.spirit_stone)
		boss.take_damage(1000000.0)
		_check(
			journey.is_stage_cleared(3, stage_id),
			"Victory persists Stage 3-%d clear" % stage_id
		)
		_check(
			int(progression.spirit_stone) - before_stones
			== int(profile["first_clear_stones"]),
			"Stage 3-%d grants the correct first-clear reward" % stage_id
		)
		var granted: int = int(progression.spirit_stone)
		current_scene.get_node("VictoryManager").call("_on_boss_defeated")
		_check(
			int(progression.spirit_stone) == granted,
			"Stage 3-%d duplicate Victory callback cannot grant twice" % stage_id
		)

		current_scene.get_node("VictoryUI").call("_on_main_menu_pressed")
		if not await _wait_for_scene(HUB_PATH):
			return

	_check(
		int(journey.get_chapter_progress(3).get("cleared_stages", 0)) == 5,
		"All five Chapter 3 stages clear through automated regression"
	)
	_check(
		not journey.is_stage_unlocked(3, 6),
		"Chapter 3 final clear creates no phantom Stage 3-6"
	)
	_check(
		not journey.has_chapter(4),
		"Chapter 3 finale creates no phantom Chapter 4"
	)
	_check(
		int(journey.get_chapter_progress(1).get("cleared_stages", 0))
		+ int(journey.get_chapter_progress(2).get("cleared_stages", 0))
		+ int(journey.get_chapter_progress(3).get("cleared_stages", 0)) == 15,
		"Automated progression clears all fifteen v1.0 stages"
	)


func _finish() -> void:
	paused = false
	var exit_code: int = 0 if failures == 0 else 1
	_log("QA totals: %d checks; %d failures; %d scripts; %d off-tree scenes" % [checks, failures, loaded_scripts, loaded_scenes])
	_log("JADE_PHASE0_PASS" if failures == 0 else "JADE_PHASE0_FAIL")
	_log("Manual/device/release gates remain unverified by this smoke runner.")
	await _cleanup_test_runtime()
	quit(exit_code)


func _cleanup_test_runtime() -> void:
	# The smoke runner opens real scenes and swaps test providers. Before quitting
	# the --script SceneTree, release those test-owned references explicitly so
	# Godot can finish deferred destruction and report genuine leaks only.
	paused = false
	if is_instance_valid(transition):
		transition.call("set_back_handler", Callable())

	var scene_to_release: Node = current_scene
	current_scene = null
	if is_instance_valid(scene_to_release):
		if scene_to_release.get_parent() != null:
			scene_to_release.get_parent().remove_child(scene_to_release)
		scene_to_release.free()

	# Let queue_free() calls issued by scenes/providers during the final QA frames
	# drain before the process exits. This does not suppress engine leak warnings.
	await process_frame
	await process_frame

	# AudioManager is an autoload and survives current_scene teardown. Some smoke
	# flows intentionally trigger level/victory/boss audio immediately before
	# exit. Stop playback and clear stream references explicitly, then give the
	# audio server several frames to retire playback objects before quit().
	var audio_manager: Node = root.get_node_or_null("AudioManager")
	if is_instance_valid(audio_manager):
		if audio_manager.has_method("release_runtime_audio"):
			audio_manager.call("release_runtime_audio")

	await process_frame
	await process_frame
	await process_frame
	await process_frame

	CheckpointData = null
	HubScript = null
	saver = null
	journey = null
	transition = null
	logger = null
	await process_frame


func _test_release_contracts() -> void:
	var inventory: Variant = root.get_node("InventoryManager")
	var progression: Variant = root.get_node("ProgressionManager")
	var equipment: Variant = root.get_node("EquipmentManager")
	var pavilion: Variant = root.get_node("PavilionManager")
	var daily: Variant = root.get_node("DailyQuestManager")
	var settings: Variant = root.get_node("SettingsManager")
	var reward_manager: Variant = root.get_node("RewardManager")
	var achievements: Variant = root.get_node("AchievementManager")
	_check(equipment.get_item_ids().size() == 40, "Equipment collection contains forty permanent items after Set Expansion")
	_check(
		equipment.get_slot_ids() == ["armament", "robe", "bracer", "boots", "pendant"],
		"Permanent loadout exposes one Dao Armament slot plus the four legacy slots"
	)
	for slot_id: String in equipment.get_slot_ids():
		_check(
			equipment.get_item_ids_for_slot(slot_id).size() == 8,
			"Equipment Set Expansion provides eight collection choices for slot " + slot_id
		)
	var armament_ids: Array[String] = equipment.get_item_ids_for_slot("armament")
	_check(
		armament_ids == [
			"cinnabar_moon_saber",
			"mistveil_jian",
			"mountain_ward_jian",
			"nine_heavens_star_sword",
			"spirit_seal_fan",
			"stillwater_mirror_blade",
			"sunfire_dragon_jian",
			"wanderer_jade_jian"
		],
		"Dao Armament collection exposes the five locked identities plus three set-expansion choices"
	)
	var foundation_armament: Dictionary = equipment.get_item_data("wanderer_jade_jian")
	_check(
		str(foundation_armament.get("slot", "")) == "armament"
		and str(foundation_armament.get("rarity", "")) == "common"
		and is_equal_approx(float(foundation_armament.get("damage_bonus", 0.0)), 0.03),
		"Wanderer's Jade Jian keeps the locked 3% common foundation passive"
	)
	var utility_armament: Dictionary = equipment.get_item_data("spirit_seal_fan")
	_check(
		is_equal_approx(float(utility_armament.get("experience_bonus", 0.0)), 0.05)
		and is_equal_approx(float(utility_armament.get("pickup_radius_bonus", 0.0)), 10.0),
		"Spirit-Seal Fan creates a growth/collection armament branch instead of another damage clone"
	)
	var mirror_bracer: Dictionary = equipment.get_item_data("mirror_edge_bracer")
	_check(
		float(mirror_bracer.get("damage_bonus", 0.0)) < float(equipment.get_item_data("jade_edge_bracer").get("damage_bonus", 0.0))
		and float(mirror_bracer.get("critical_chance_bonus", 0.0)) > float(equipment.get_item_data("jade_edge_bracer").get("critical_chance_bonus", 0.0)),
		"Mirror-Edge Bracer is a crit sidegrade rather than a strict Jade Edge upgrade"
	)
	var rarity_signature_ids: Array[String] = [
		"cinnabar_moon_saber",
		"nine_heavens_star_sword",
		"ward_keeper_robe",
		"sovereign_mantle",
		"stormcall_bracer",
		"tribulation_bracer",
		"shadowstep_boots",
		"starstep_boots",
		"cloudtreader_boots",
		"shrine_seal_pendant",
		"sword_heart_pendant",
		"ascendant_heart",
		"stillwater_mirror_blade",
		"glassmoon_robe",
		"reflection_bracer",
		"silent_ripple_boots",
		"mirror_heart_pendant",
		"sunfire_dragon_jian",
		"dawn_meridian_robe",
		"solar_edict_bracer",
		"sunstride_boots",
		"golden_core_pendant"
	]
	for signature_item_id: String in rarity_signature_ids:
		var signature_data: Dictionary = equipment.get_item_data(signature_item_id)
		_check(
			not str(signature_data.get("signature_effect_name", "")).is_empty()
			and not str(signature_data.get("signature_effect_description", "")).is_empty(),
			"Epic/Legendary signature effect is explicit for " + signature_item_id
		)
	var special_mechanic_keys: Array[String] = [
		"blood_qi_heal_bonus",
		"starting_shield_charges",
		"critical_damage_bonus",
		"pickup_radius_bonus",
		"low_health_damage_bonus",
		"attack_cooldown_reduction",
		"moving_damage_bonus",
		"level_up_heal_flat",
		"low_health_critical_chance_bonus"
	]
	for signature_item_id: String in rarity_signature_ids:
		var signature_data: Dictionary = equipment.get_item_data(signature_item_id)
		var has_special_mechanic: bool = false
		for mechanic_key: String in special_mechanic_keys:
			if signature_data.has(mechanic_key):
				has_special_mechanic = true
				break
		_check(
			has_special_mechanic,
			"Epic/Legendary runtime mechanic channel exists for " + signature_item_id
		)
	var previous_equipped: Dictionary = equipment.equipped_item_ids.duplicate(true)
	equipment.equipped_item_ids["armament"] = "cinnabar_moon_saber"
	equipment.equipped_item_ids["boots"] = "shadowstep_boots"
	equipment.equipped_item_ids["pendant"] = "sword_heart_pendant"
	_check(
		is_equal_approx(equipment.get_secondary_bonus("low_health_damage_bonus", 0.10), 0.06)
		and is_equal_approx(equipment.get_secondary_bonus("moving_damage_bonus", 0.08), 0.04)
		and is_equal_approx(equipment.get_secondary_bonus("low_health_critical_chance_bonus", 0.05), 0.03),
		"Conditional Epic equipment bonuses resolve through EquipmentManager"
	)
	equipment.equipped_item_ids["armament"] = "nine_heavens_star_sword"
	equipment.equipped_item_ids["boots"] = "starstep_boots"
	_check(
		is_equal_approx(equipment.get_secondary_bonus("attack_cooldown_reduction", 0.10), 0.06)
		and is_equal_approx(equipment.get_secondary_bonus("level_up_heal_flat", 4.0), 2.0),
		"Legendary tempo and Epic level recovery bonuses resolve through EquipmentManager"
	)
	equipment.equipped_item_ids = previous_equipped
	_check(
		equipment.get_equipped_item_id("armament").is_empty(),
		"Clean or legacy equipment state safely defaults the new armament slot to empty"
	)
	var rare_requirement: Dictionary = pavilion.get_item_unlock_requirement("jade_edge_bracer")
	var epic_requirement: Dictionary = pavilion.get_item_unlock_requirement("stormcall_bracer")
	var legendary_requirement: Dictionary = pavilion.get_item_unlock_requirement("tribulation_bracer")
	_check(
		int(rare_requirement.get("chapter_id", -1)) == 1
		and int(rare_requirement.get("stage_id", -1)) == 2,
		"Rare equipment enters during Chapter 1"
	)
	_check(
		int(epic_requirement.get("chapter_id", -1)) == 1
		and int(epic_requirement.get("stage_id", -1)) == 5,
		"Epic equipment waits for Chapter 1 completion"
	)
	_check(
		int(legendary_requirement.get("chapter_id", -1)) == 2
		and int(legendary_requirement.get("stage_id", -1)) == 5,
		"Legendary equipment waits for Chapter 2 completion"
	)

	var expansion_set_ids: Array[String] = [
		"jade_bastion",
		"stillwater_mirror",
		"solar_meridian"
	]
	var expansion_set_pieces: Dictionary = {
		"jade_bastion": [
			"mountain_ward_jian", "stone_meridian_robe", "earthseal_bracer",
			"rootstep_boots", "guardian_jade_pendant"
		],
		"stillwater_mirror": [
			"stillwater_mirror_blade", "glassmoon_robe", "reflection_bracer",
			"silent_ripple_boots", "mirror_heart_pendant"
		],
		"solar_meridian": [
			"sunfire_dragon_jian", "dawn_meridian_robe", "solar_edict_bracer",
			"sunstride_boots", "golden_core_pendant"
		]
	}
	var expected_expansion_rarity: Dictionary = {
		"jade_bastion": "rare",
		"stillwater_mirror": "epic",
		"solar_meridian": "legendary"
	}
	for set_id: String in expansion_set_ids:
		var raw_pieces: Array = expansion_set_pieces[set_id]
		var set_slots: Array[String] = []
		for raw_item_id: Variant in raw_pieces:
			var item_id: String = str(raw_item_id)
			var item_data: Dictionary = equipment.get_item_data(item_id)
			_check(not item_data.is_empty(), "Set Expansion catalog resolves " + item_id)
			var slot_id: String = str(item_data.get("slot", ""))
			if not set_slots.has(slot_id):
				set_slots.append(slot_id)
			_check(
				str(item_data.get("rarity", "")) == str(expected_expansion_rarity[set_id]),
				"Set Expansion rarity identity holds for " + item_id
			)
		set_slots.sort()
		_check(
			set_slots == ["armament", "boots", "bracer", "pendant", "robe"],
			"Set Expansion family covers every permanent slot: " + set_id
		)

	var bastion_requirement: Dictionary = pavilion.get_item_unlock_requirement("mountain_ward_jian")
	var mirror_requirement: Dictionary = pavilion.get_item_unlock_requirement("stillwater_mirror_blade")
	var solar_requirement: Dictionary = pavilion.get_item_unlock_requirement("sunfire_dragon_jian")
	_check(
		int(bastion_requirement.get("chapter_id", -1)) == 1
		and int(bastion_requirement.get("stage_id", -1)) == 5,
		"Jade Bastion enters the summon collection after Chapter 1 completion"
	)
	_check(
		int(mirror_requirement.get("chapter_id", -1)) == 2
		and int(mirror_requirement.get("stage_id", -1)) == 1,
		"Stillwater Mirror starts entering the summon collection in Chapter 2"
	)
	_check(
		int(solar_requirement.get("chapter_id", -1)) == 3
		and int(solar_requirement.get("stage_id", -1)) == 1,
		"Solar Meridian starts entering the summon collection in Chapter 3"
	)

	var summon_pool: Dictionary = pavilion.get_summon_pool_by_rarity()
	var summon_pool_total: int = 0
	for rarity_id: String in ["common", "rare", "epic", "legendary"]:
		summon_pool_total += (summon_pool.get(rarity_id, []) as Array).size()
	_check(summon_pool_total == 40, "Cleared v1 journey exposes all forty equipment items to the summon pool")
	_check(
		(summon_pool.get("common", []) as Array).size() == 5
		and (summon_pool.get("rare", []) as Array).size() == 13
		and (summon_pool.get("epic", []) as Array).size() == 12
		and (summon_pool.get("legendary", []) as Array).size() == 10,
		"Summon pool preserves rarity rates while expanding within-rarity collection diversity"
	)
	for set_id: String in expansion_set_ids:
		var rarity_id: String = str(expected_expansion_rarity[set_id])
		var rarity_pool: Array = summon_pool.get(rarity_id, [])
		for raw_item_id: Variant in expansion_set_pieces[set_id]:
			_check(
				rarity_pool.has(str(raw_item_id)),
				"Summon pool includes unlocked Set Expansion item " + str(raw_item_id)
			)

	var set_catalog_source: String = FileAccess.get_file_as_string(
		"res://scripts/data/equipment_set_catalog.gd"
	)
	for set_id: String in expansion_set_ids:
		_check(
			set_catalog_source.contains("\"" + set_id + "\": {"),
			"Equipment set catalog declares Set Expansion family " + set_id
		)
	_check(
		set_catalog_source.contains("\"stationary_damage_bonus\": 0.04")
		and set_catalog_source.contains("\"high_health_damage_bonus\": 0.04")
		and set_catalog_source.contains("\"starting_shield_charges\": 1.0"),
		"Set Expansion gameplay catalog exposes Bastion, Stillwater, and Solar identity mechanics"
	)

	# Gate 1.5 — equipment ascension is a permanent 1★–5★ progression layer.
	# Duplicates still collapse into Refinement Shards; ascension spends those
	# shards atomically with the equipment-star update. Signature mechanics are
	# deliberately excluded from star scaling.
	_check(equipment.MAX_ASCENSION_STAR == 5, "Equipment ascension caps at five stars")
	_check(equipment.get_item_star("wanderer_jade_jian") == 1, "Known equipment defaults safely to one star")
	_check(
		equipment.get_ascension_cost_for_star("wanderer_jade_jian", 2) == 5
		and equipment.get_ascension_cost_for_star("mistveil_jian", 2) == 12
		and equipment.get_ascension_cost_for_star("cinnabar_moon_saber", 2) == 30
		and equipment.get_ascension_cost_for_star("nine_heavens_star_sword", 2) == 75,
		"Two-star ascension cost equals one duplicate-equivalent by rarity"
	)
	_check(
		equipment.get_ascension_cost_for_star("wanderer_jade_jian", 5) == 25
		and equipment.get_ascension_cost_for_star("mistveil_jian", 5) == 60
		and equipment.get_ascension_cost_for_star("cinnabar_moon_saber", 5) == 150
		and equipment.get_ascension_cost_for_star("nine_heavens_star_sword", 5) == 375,
		"Five-star ascension cost equals five duplicate-equivalents by rarity"
	)
	_check(
		is_equal_approx(float(equipment.ASCENSION_CORE_MULTIPLIERS[5]), 1.20),
		"Five-star ascension adds twenty percent to core equipment passives only"
	)

	var ascension_equipped_before: Dictionary = equipment.equipped_item_ids.duplicate(true)
	var ascension_stars_before: Dictionary = equipment.ascension_stars.duplicate(true)
	var ascension_inventory_before: Dictionary = inventory.item_counts.duplicate(true)
	equipment.equipped_item_ids = {
		"armament": "wanderer_jade_jian",
		"robe": "",
		"bracer": "",
		"boots": "",
		"pendant": ""
	}
	equipment.ascension_stars = {}
	inventory.item_counts = {"wanderer_jade_jian": 1, "refinement_shard": 30}
	_check(equipment.can_modify_equipment(), "Ascension fixture is outside an active run")
	_check(equipment.can_ascend_item("wanderer_jade_jian"), "Owned one-star equipment can ascend when shards are sufficient")
	_check(equipment.ascend_item("wanderer_jade_jian"), "Ascension commits equipment star and shard spend together")
	_check(
		equipment.get_item_star("wanderer_jade_jian") == 2
		and inventory.get_item_count("refinement_shard") == 25,
		"Common 1★ to 2★ ascension spends exactly five Refinement Shards"
	)
	_check(
		is_equal_approx(equipment.get_damage_multiplier(), 1.0315),
		"Two-star Dao Armament applies its five-percent core-passive ascension multiplier"
	)
	equipment.ascension_stars["cinnabar_moon_saber"] = 5
	var ascended_epic: Dictionary = equipment.get_effective_item_data("cinnabar_moon_saber")
	_check(
		is_equal_approx(float(ascended_epic.get("damage_bonus", 0.0)), 0.096)
		and is_equal_approx(float(ascended_epic.get("critical_chance_bonus", 0.0)), 0.024)
		and is_equal_approx(float(ascended_epic.get("low_health_damage_bonus", 0.0)), 0.06),
		"Five-star scaling strengthens core passives without mutating Epic Signature Effect power"
	)
	var legacy_equipment_payload: Dictionary = {
		"version": 1,
		"equipped_item_ids": ascension_equipped_before.duplicate(true)
	}
	_check(
		saver._domain_value_types_valid(saver.get_save_path("equipment"), legacy_equipment_payload),
		"Legacy equipment v1 payload without ascension data remains valid"
	)
	var invalid_ascension_payload: Dictionary = legacy_equipment_payload.duplicate(true)
	invalid_ascension_payload["ascension_stars"] = {"wanderer_jade_jian": 6}
	_check(
		not saver._domain_value_types_valid(saver.get_save_path("equipment"), invalid_ascension_payload),
		"Equipment save validation rejects stars outside the 1★–5★ contract"
	)

	equipment.equipped_item_ids = ascension_equipped_before
	equipment.ascension_stars = ascension_stars_before
	inventory.item_counts = ascension_inventory_before
	_check(
		saver.write_save_batch({
			"equipment": equipment.build_equipment_save_data(),
			"inventory": {"version": inventory.SAVE_VERSION, "item_counts": ascension_inventory_before.duplicate(true)}
		}),
		"Ascension smoke fixture restores permanent equipment and inventory snapshots"
	)
	_check(
		reward_manager.get_game_over_reward_tier_id(10) == "late_failure",
		"Wave 10 boss failure keeps the late-failure reward tier"
	)
	_check(
		int(reward_manager.get_game_over_reward(10).get("spirit_stone", 0)) == 30,
		"Wave 10 boss failure grants the late consolation reward"
	)
	_check(achievements.get_achievement_ids().size() >= 18, "At least eighteen achievements after replay progression expansion")
	_check(achievements.get_target("chapter_two_master") == 5, "Chapter 2 completion achievement tracks five unique stages")
	_check(achievements.get_target("chapter_three_master") == 5, "Chapter 3 completion achievement tracks five unique stages")
	_check(achievements.get_target("jade_ascendant") == 15, "Jade Ascendant achievement tracks all fifteen unique stages")
	_check(achievements.get_target("trial_veteran_30") == 30, "Replay veteran achievement tracks thirty total stage clears")
	_check(daily.get_daily_quest_ids().size() == 3, "Three active daily disciplines")
	# Duplicate conversion must be deterministic and must not depend on equipment
	# previously granted by stage rewards. Stage clears no longer grant equipment,
	# so exercise both ownership states with explicit in-memory fixtures.
	var before_counts: Dictionary = inventory.item_counts.duplicate(true)

	inventory.item_counts = {}
	var preview: Dictionary = inventory.preview_add_items({"verdant_qi_robe": 2})
	_check(int(preview.get("verdant_qi_robe", 0)) == 1, "First equipment copy is retained from a clean inventory")
	_check(int(preview.get("refinement_shard", 0)) == 5, "One extra common copy becomes five shards")
	_check(inventory.item_counts.is_empty(), "Clean-inventory reward preview is pure")

	inventory.item_counts = {"verdant_qi_robe": 1}
	preview = inventory.preview_add_items({"verdant_qi_robe": 2})
	_check(int(preview.get("verdant_qi_robe", 0)) == 1, "Owned equipment remains capped at one usable copy")
	_check(int(preview.get("refinement_shard", 0)) == 10, "Two incoming common duplicates become ten shards when already owned")

	inventory.item_counts = before_counts
	_check(inventory.item_counts == before_counts, "Duplicate preview fixture restores inventory state")

	# Reproduce an interrupted multi-domain commit in the isolated directory.
	var progress_target: Dictionary = progression.build_progression_save_data()
	progress_target["spirit_stone"] = int(progress_target["spirit_stone"]) + 23
	var inventory_target: Dictionary = {"version": 1, "item_counts": before_counts.duplicate(true)}
	inventory_target["item_counts"]["refinement_shard"] = int(before_counts.get("refinement_shard", 0)) + 3
	var targets: Dictionary = {"progression": progress_target, "inventory": inventory_target}
	var journal: FileAccess = FileAccess.open(saver.TRANSACTION_PATH, FileAccess.WRITE)
	if not _check(journal != null, "Create interrupted transaction fixture"):
		return
	journal.store_var({"version": 1, "targets": targets})
	journal.flush()
	journal.close()
	_check(bool(saver.write_save_data("progression", progress_target)["success"]), "Simulate first domain committed before interruption")
	saver._recover_pending_transaction()
	_check(not saver.has_pending_transaction(), "Journal recovers remaining domains")
	_check(saver.read_save_data("inventory")["data"] == inventory_target, "Recovery restores exact inventory post-state")
	_check(saver.read_save_data("progression")["data"] == progress_target, "Recovery assigns exact currency post-state")
	# A second replay of the same intent cannot add the reward twice.
	journal = FileAccess.open(saver.TRANSACTION_PATH, FileAccess.WRITE)
	journal.store_var({"version": 1, "targets": targets})
	journal.close()
	saver._recover_pending_transaction()
	_check(saver.read_save_data("progression")["data"] == progress_target, "Journal replay is idempotent")
	progression.apply_progression_save_data(progress_target)
	inventory.item_counts = inventory_target["item_counts"].duplicate(true)

	# Invalid typed permanent data must recover a valid prior snapshot.
	var valid_inventory: Dictionary = inventory_target.duplicate(true)
	_check(bool(saver.write_save_data("inventory", valid_inventory)["success"]), "Create valid permanent backup")
	var corrupt: FileAccess = FileAccess.open(saver.get_save_path("inventory"), FileAccess.WRITE)
	corrupt.store_var({"version": 1, "item_counts": {"verdant_qi_robe": []}})
	corrupt.close()
	var recovery: Dictionary = saver.read_save_data("inventory")
	_check(bool(recovery.get("success", false)) and bool(recovery.get("recovered", false)), "Invalid item count type recovers validated backup")
	_check(recovery.get("data", {}) == valid_inventory, "Typed corruption preserves inventory value")
	var malformed: Dictionary = progression.build_progression_save_data()
	malformed["spirit_stone"] = []
	_check(not saver._domain_value_types_valid(saver.get_save_path("progression"), malformed), "Reject arrays before numeric conversion")

	# A terminal checkpoint is not a playable older snapshot, even with backup.
	var checkpoint: Variant = CheckpointData.new()
	_check(checkpoint._write_checkpoint_data(_fixture()), "Create terminal-checkpoint fixture")
	var terminal: Dictionary = _fixture()
	terminal["ended"] = true
	_check(saver.write_save_batch({"checkpoint": terminal}), "Commit terminal marker")
	_check(not bool(CheckpointData.read_checkpoint_result().get("success", false)), "Terminal checkpoint never resumes its live backup")
	_reset_checkpoint()
	checkpoint.free()

	var wallet: Dictionary = progression.build_progression_save_data()
	wallet["spirit_stone"] = 5000
	_check(saver.write_save_batch({"progression": wallet}), "Set isolated Pavilion wallet")
	progression.apply_progression_save_data(wallet)
	var price: int = int(equipment.get_item_data("jade_edge_bracer")["price"])
	_check(pavilion.acquire_equipment("jade_edge_bracer"), "Forge exchanges earned currency for unlocked equipment")
	_check(progression.spirit_stone == 5000 - price and inventory.get_item_count("jade_edge_bracer") == 1, "Forge charge and ownership commit together")
	_check(not pavilion.acquire_equipment("jade_edge_bracer"), "Double purchase is rejected")
	_check(progression.spirit_stone == 5000 - price, "Rejected double purchase consumes no currency")
	var before_meditation: int = int(progression.spirit_stone)
	_check(pavilion.claim_meditation(), "Daily meditation commits once")
	_check(not pavilion.claim_meditation(), "Repeated daily meditation cannot reward again")
	_check(int(progression.spirit_stone) == before_meditation + 20, "Meditation grants exactly twenty stones")

	# Postgame retention stays inside the existing Pavilion/save architecture.
	# Clearing 3-5 unlocks two optional prestige aura sinks; no new combat mode or
	# save schema is required for v1.0.
	var postgame_progression_before: Dictionary = progression.build_progression_save_data()
	var postgame_inventory_before: Dictionary = inventory.item_counts.duplicate(true)
	var postgame_pavilion_before: Dictionary = pavilion.state.duplicate(true)
	var postgame_journey_before: Dictionary = journey.build_save_data()
	var postgame_wallet: Dictionary = postgame_progression_before.duplicate(true)
	postgame_wallet["spirit_stone"] = 10000
	var postgame_counts: Dictionary = postgame_inventory_before.duplicate(true)
	postgame_counts[inventory.REFINEMENT_SHARD] = 200
	journey.cleared_stage_keys = postgame_journey_before.get("cleared_stage_keys", []).duplicate()
	if "3-5" not in journey.cleared_stage_keys:
		journey.cleared_stage_keys.append("3-5")
	pavilion.state = {"version": 1, "meditation_date": "", "cosmetic_id": "plain", "owned_cosmetics": ["plain"]}
	_check(
		saver.write_save_batch({
			"progression": postgame_wallet,
			"inventory": {"version": 1, "item_counts": postgame_counts},
			"pavilion": pavilion.state,
			"journey": journey.build_save_data()
		}),
		"Create isolated postgame prestige fixture"
	)
	progression.apply_progression_save_data(postgame_wallet)
	inventory.item_counts = postgame_counts.duplicate(true)
	_check(pavilion.COSMETICS.size() == 5, "Pavilion exposes five cosmetic aura identities")
	_check(pavilion.is_cosmetic_unlocked("astral_aura"), "Stage 3-5 unlocks Astral Crown Aura")
	_check(not pavilion.is_cosmetic_unlocked("ascendant_aura"), "Final prestige aura requires the Astral Crown first")
	var astral_cost: Dictionary = pavilion.get_cosmetic_cost("astral_aura")
	_check(
		int(astral_cost.get("spirit_stone", -1)) == 2500
		and int(astral_cost.get("refinement_shard", -1)) == 40,
		"Astral Crown uses the reviewed postgame currency sink"
	)
	var stones_before_astral: int = int(progression.spirit_stone)
	var shards_before_astral: int = inventory.get_item_count(inventory.REFINEMENT_SHARD)
	_check(pavilion.acquire_cosmetic("astral_aura"), "Postgame Astral Crown purchase commits")
	_check(
		int(progression.spirit_stone) == stones_before_astral - 2500
		and inventory.get_item_count(inventory.REFINEMENT_SHARD) == shards_before_astral - 40,
		"Astral Crown deducts both earned currencies exactly once"
	)
	_check(
		pavilion.is_cosmetic_owned("astral_aura")
		and pavilion.get_cosmetic_id() == "astral_aura",
		"Astral Crown becomes owned and attuned atomically"
	)
	_check(pavilion.is_cosmetic_unlocked("ascendant_aura"), "Astral ownership unlocks Jade Ascendant Halo")
	var ascendant_cost: Dictionary = pavilion.get_cosmetic_cost("ascendant_aura")
	_check(
		int(ascendant_cost.get("spirit_stone", -1)) == 5000
		and int(ascendant_cost.get("refinement_shard", -1)) == 90,
		"Jade Ascendant Halo uses the final prestige sink"
	)
	var stones_before_ascendant: int = int(progression.spirit_stone)
	var shards_before_ascendant: int = inventory.get_item_count(inventory.REFINEMENT_SHARD)
	_check(pavilion.acquire_cosmetic("ascendant_aura"), "Final prestige aura purchase commits")
	_check(
		int(progression.spirit_stone) == stones_before_ascendant - 5000
		and inventory.get_item_count(inventory.REFINEMENT_SHARD) == shards_before_ascendant - 90,
		"Final prestige aura deducts reviewed costs exactly once"
	)
	_check(
		pavilion.is_cosmetic_owned("ascendant_aura")
		and pavilion.get_cosmetic_id() == "ascendant_aura",
		"Final prestige aura becomes owned and attuned"
	)
	var stones_before_reacquire: int = int(progression.spirit_stone)
	var shards_before_reacquire: int = inventory.get_item_count(inventory.REFINEMENT_SHARD)
	_check(pavilion.acquire_cosmetic("ascendant_aura"), "Owned prestige aura can be re-attuned safely")
	_check(
		int(progression.spirit_stone) == stones_before_reacquire
		and inventory.get_item_count(inventory.REFINEMENT_SHARD) == shards_before_reacquire,
		"Re-attuning an owned prestige aura consumes no currency"
	)

	# Restore the exact pre-fixture permanent state before the remaining release checks.
	journey.selected_chapter_id = int(postgame_journey_before.get("selected_chapter_id", 1))
	journey.selected_stage_id = int(postgame_journey_before.get("selected_stage_id", 1))
	journey.active_run_chapter_id = int(postgame_journey_before.get("active_run_chapter_id", -1))
	journey.active_run_stage_id = int(postgame_journey_before.get("active_run_stage_id", -1))
	journey.unlocked_stage_keys = postgame_journey_before.get("unlocked_stage_keys", []).duplicate()
	journey.cleared_stage_keys = postgame_journey_before.get("cleared_stage_keys", []).duplicate()
	progression.apply_progression_save_data(postgame_progression_before)
	inventory.item_counts = postgame_inventory_before.duplicate(true)
	pavilion.state = postgame_pavilion_before.duplicate(true)
	_check(
		saver.write_save_batch({
			"progression": postgame_progression_before,
			"inventory": {"version": 1, "item_counts": postgame_inventory_before},
			"pavilion": postgame_pavilion_before,
			"journey": postgame_journey_before
		}),
		"Restore postgame prestige fixture"
	)

	saver._transaction_fault = true
	_check(not equipment.can_modify_equipment(), "Pending recovery seals equipment changes")
	_check(journey.begin_selected_stage().is_empty(), "Pending recovery prevents a fresh run")
	_check(not bool(saver.reset_active_run_saves()["success"]), "Pending recovery protects checkpoint artifacts")
	saver._transaction_fault = false

	for weapon_path: String in ["spirit_sword_weapon", "fire_orb_weapon", "thunder_talisman_weapon", "yin_yang_blades_weapon", "heavenly_sword_rain_weapon", "eight_trigrams_formation_weapon"]:
		var script: GDScript = load("res://scripts/weapon/" + weapon_path + ".gd") as GDScript
		var weapon: Variant = script.new()
		for index in range(15):
			weapon.upgrade()
		_check(int(weapon.level) == 7, "MAX 7 enforced: " + weapon_path)
		weapon.free()
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", [])
	_check(is_equal_approx(float(settings._read_volume(config, "master_volume", 0.8)), 0.8), "Invalid settings volume safely uses its default")
	settings.set_presentation("language", "id")
	_check(TranslationServer.translate("CONTINUE RUN") == "LANJUTKAN", "Indonesian message catalog is active")
	_check(
		TranslationServer.translate("CHOOSE YOUR PATH") == "PILIH JALURMU",
		"Level-up presentation has Indonesian coverage"
	)
	_check(
		TranslationServer.translate("BATTLE PAUSED") == "PERTEMPURAN DIJEDA",
		"Pause presentation has Indonesian coverage"
	)
	_check(
		TranslationServer.translate("CELESTIAL TRANSIT") == "PERJALANAN LANGIT",
		"Celestial loading presentation has Indonesian coverage"
	)
	_check(
		TranslationServer.translate("ABANDON CURRENT TRIAL?") == "TINGGALKAN UJIAN SAAT INI?",
		"Active-trial replacement modal has Indonesian coverage"
	)
	_check(
		TranslationServer.translate("CLEARED %d/%d    UNLOCKED %d/%d")
		== "TUNTAS %d/%d    TERBUKA %d/%d",
		"Formatted chapter progress has Indonesian coverage"
	)
	var shard_summary: String = reward_manager.get_reward_summary(
		reward_manager.create_reward_data(0, {"refinement_shard": 2})
	)
	_check(
		"Pecahan Pemurnian" in shard_summary,
		"Repeat-clear shard reward summary respects Indonesian localization"
	)
	settings.set_presentation("language", "en")
	var feedback: Variant = root.get_node("CombatFeedback")
	for index in range(1000):
		feedback.pulse(Vector2(float(index), 0.0))
	_check(feedback.effects.size() == 96 and feedback.arcs.size() == 16, "Combat visual storage stays bounded under bursts")
	feedback._reset_feedback()
	feedback.pulse(Vector2.ZERO, "formation")
	var formation_feedback_found: bool = false
	for effect_entry: Dictionary in feedback.effects:
		if str(effect_entry.get("kind", "")) != "formation":
			continue
		formation_feedback_found = true
		_check(float(effect_entry.get("duration", 1.0)) <= 0.25, "Eight Trigrams pooled pulse stays brief")
		_check(float(effect_entry.get("pulse_radius", 99.0)) <= 16.0, "Eight Trigrams pooled pulse stays compact")
		_check(float(effect_entry.get("pulse_alpha", 1.0)) <= 0.52, "Eight Trigrams pooled pulse stays restrained")
		break
	_check(formation_feedback_found, "Eight Trigrams pooled pulse contract is registered")
	feedback._reset_feedback()
	await _test_provider_contract()
	_test_hero_hub_localization_contract()
	_test_hero_hub_overhaul_contracts()
	_test_ui_master_polish_contracts()
	# Exercise new hub destinations in-tree, including generated labels.
	for scene_path: String in ["res://scenes/ui/pavilion_screen.tscn", "res://scenes/ui/privacy_screen.tscn", "res://scenes/ui/credits_screen.tscn", "res://scenes/ui/settings_screen.tscn", "res://scenes/ui/equipment_screen.tscn", "res://scenes/ui/backpack_screen.tscn"]:
		_check(change_scene_to_file(scene_path) == OK, "Open release hub screen " + scene_path)
		await process_frame
		await process_frame


func _test_hero_hub_localization_contract() -> void:
	var previous_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("id")
	var expected: Dictionary = {
		"LOADOUT": "PERLENGKAPAN",
		"MY EQUIPMENT  •  TAP AN ITEM FOR DETAILS": "PERLENGKAPAN SAYA  •  KETUK ITEM UNTUK DETAIL",
		"INVENTORY  •  TAP AN ITEM FOR DETAILS": "INVENTARIS  •  KETUK ITEM UNTUK DETAIL",
		"ALL": "SEMUA",
		"GEAR": "PAKAI",
		"MATERIAL": "BAHAN",
		"SORT  •  %s": "URUT  •  %s",
		"ASCENSION LOCKED": "ASCENSION TERKUNCI",
		"ASCEND TO %d★  •  %d SHARDS": "NAIK KE %d★  •  %d PECAHAN"
	}
	for message_id: String in expected:
		_check(
			TranslationServer.translate(message_id) == str(expected[message_id]),
			"Hero hub localization covers: " + message_id
		)
	TranslationServer.set_locale(previous_locale)


func _test_hero_hub_overhaul_contracts() -> void:
	var equipment_scene: PackedScene = load("res://scenes/ui/equipment_screen.tscn") as PackedScene
	_check(equipment_scene != null, "Hero Equipment overhaul scene loads")
	if equipment_scene != null:
		var equipment_root: Node = equipment_scene.instantiate()
		var preview: Node = equipment_root.find_child("HeroPreviewSprite", true, false)
		_check(preview is AnimatedSprite2D, "Hero Equipment owns animated Lin Yue paper-doll preview")
		if preview is AnimatedSprite2D:
			var preview_sprite: AnimatedSprite2D = preview as AnimatedSprite2D
			_check(
				preview_sprite.sprite_frames != null
				and preview_sprite.sprite_frames.has_animation(&"idle_down"),
				"Hero Equipment preview keeps Lin Yue idle animation contract"
			)
		var candidate_grid: Node = equipment_root.find_child("CandidateGrid", true, false)
		_check(
			candidate_grid is GridContainer and int((candidate_grid as GridContainer).columns) == 4,
			"Hero Equipment collection uses a compact four-column icon grid"
		)
		var candidate_scroll: Node = equipment_root.find_child("CandidateScroll", true, false)
		_check(
			candidate_scroll is ScrollContainer,
			"Hero Equipment owns a dedicated scrollable equipment collection"
		)
		var equipment_detail: Node = equipment_root.find_child("DetailPanel", true, false)
		_check(
			equipment_detail is PanelContainer and not (equipment_detail as PanelContainer).visible,
			"Hero Equipment details use progressive disclosure and start hidden"
		)
		_check(
			equipment_root.find_child("DetailCloseButton", true, false) is Button,
			"Hero Equipment detail sheet has a close affordance"
		)
		_check(
			equipment_root.find_child("SignatureEffectLabel", true, false) is Label,
			"Hero Equipment detail uses Signature Effect terminology"
		)
		for ascension_node_name: String in ["AscensionStatusLabel", "AscensionPreviewLabel", "AscendButton", "AscendHintLabel"]:
			_check(
				equipment_root.find_child(ascension_node_name, true, false) is Control,
				"Hero Equipment Ascension control exists: " + ascension_node_name
			)
		for slot_node_name: String in ["ArmamentButton", "RobeButton", "BracerButton", "PendantButton", "BootsButton"]:
			_check(
				equipment_root.find_child(slot_node_name, true, false) is Button,
				"Hero Equipment paper-doll slot exists: " + slot_node_name
			)
		equipment_root.free()

	var backpack_scene: PackedScene = load("res://scenes/ui/backpack_screen.tscn") as PackedScene
	_check(backpack_scene != null, "Hero Backpack overhaul scene loads")
	if backpack_scene != null:
		var backpack_root: Node = backpack_scene.instantiate()
		var item_grid: Node = backpack_root.find_child("ItemGrid", true, false)
		_check(
			item_grid is GridContainer and int((item_grid as GridContainer).columns) == 5,
			"Hero Backpack inventory uses a dense five-column icon grid"
		)
		var backpack_detail: Node = backpack_root.find_child("DetailPanel", true, false)
		_check(
			backpack_detail is PanelContainer and not (backpack_detail as PanelContainer).visible,
			"Hero Backpack details use progressive disclosure and start hidden"
		)
		_check(
			backpack_root.find_child("DetailCloseButton", true, false) is Button,
			"Hero Backpack detail sheet has a close affordance"
		)
		for filter_node_name: String in ["AllFilterButton", "EquipmentFilterButton", "MaterialFilterButton", "EquippedFilterButton", "SortButton"]:
			_check(
				backpack_root.find_child(filter_node_name, true, false) is Button,
				"Hero Backpack QoL control exists: " + filter_node_name
			)
		_check(
			backpack_root.find_child("SelectedActionButton", true, false) is Button,
			"Hero Backpack supports direct item action flow"
		)
		for ascension_node_name: String in ["AscensionStatusLabel", "AscensionPreviewLabel", "AscendButton", "AscendHintLabel"]:
			_check(
				backpack_root.find_child(ascension_node_name, true, false) is Control,
				"Hero Backpack Ascension control exists: " + ascension_node_name
			)
		backpack_root.free()


func _test_ui_master_polish_contracts() -> void:
	var master_theme: Theme = load("res://assets/ui/jade_ui_theme.tres") as Theme
	_check(master_theme != null, "Master UI polish theme loads")
	if master_theme != null:
		_check(master_theme.has_stylebox(&"scroll", &"VScrollBar"), "Master UI owns modern scrollbar track styling")
		_check(master_theme.has_stylebox(&"normal", &"OptionButton"), "Master UI owns compact OptionButton styling")

	var contracts: Dictionary = {
		"res://scenes/ui/main_menu.tscn": ["ActionGlass", "HomeActions", "HubNav"],
		"res://scenes/ui/cultivation_menu.tscn": ["HeaderPanel", "Formation", "DetailPanel", "HubNav"],
		"res://scenes/ui/achievement_screen.tscn": ["HeaderPanel", "SummaryPanel", "ListPanel", "HubNav"],
		"res://scenes/ui/daily_quest_screen.tscn": ["HeaderPanel", "SummaryPanel", "ListPanel", "CyclePanel", "HubNav"],
		"res://scenes/ui/pavilion_screen.tscn": ["Backdrop", "Scroll", "HubNav"],
		"res://scenes/ui/settings_screen.tscn": ["Header", "AudioCard", "MasterSlider", "MusicSlider", "SFXSlider"],
		"res://scenes/ui/privacy_screen.tscn": ["Backdrop", "Scroll", "Content"],
		"res://scenes/ui/credits_screen.tscn": ["Backdrop", "Scroll", "Content"]
	}
	for scene_path: String in contracts:
		var packed: PackedScene = load(scene_path) as PackedScene
		_check(packed != null, "Master UI scene loads: " + scene_path)
		if packed == null:
			continue
		var screen: Node = packed.instantiate()
		for raw_node_name in contracts[scene_path]:
			var node_name: String = str(raw_node_name)
			_check(screen.find_child(node_name, true, false) != null, "Master UI contract exists: " + scene_path + " :: " + node_name)
		screen.free()


func _test_provider_contract() -> void:
	var monetization: Variant = root.get_node("MonetizationManager")
	_check(not monetization.rewarded_available("qa"), "Offline build has no rewarded ad availability")
	var provider_script: GDScript = load("res://scripts/monetization/debug_provider.gd") as GDScript
	_check(monetization.use_test_provider(provider_script.new()), "Debug provider only attaches in a debug test")
	var completions: Array[int] = [0]
	var callback: Callable = func(_placement: String) -> void: completions[0] += 1
	monetization.rewarded_completed.connect(callback)
	_check(monetization.show_rewarded("qa"), "Begin provider request")
	await process_frame
	await process_frame
	_check(completions[0] == 1, "Duplicate SDK reward callback is consumed once")
	_check(not monetization.rewarded_available("qa"), "Placement and cooldown guards apply after reward")
	# Closure/cancel and timeout invalidate request IDs before a late reward.
	monetization.active_request = 777
	monetization.active_placement = "cancelled"
	monetization.reward_consumed = false
	monetization._on_request_finished(777, "cancelled")
	monetization._on_reward_confirmed(777)
	_check(completions[0] == 1, "Cancelled request ignores late completion")
	monetization.active_request = 778
	monetization.active_placement = "timeout"
	monetization.timeout_left = 0.01
	monetization._process(0.02)
	monetization._on_reward_confirmed(778)
	_check(completions[0] == 1, "Timed-out request ignores late completion")
	monetization.rewarded_completed.disconnect(callback)
	monetization.use_test_provider(load("res://scripts/monetization/offline_provider.gd").new())
