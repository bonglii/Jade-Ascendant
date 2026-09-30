extends SceneTree

## Non-mutating Gate C audit: verify permanent progression contracts and
## preview rewards without touching player saves or creating an active run.
const Art = preload("res://scripts/ui/journey_art_catalog.gd")
const Visual = preload("res://scripts/ui/journey_visual_catalog.gd")
const ChapterFour = preload("res://scripts/data/chapter_four_catalog.gd")
const ChapterFive = preload("res://scripts/data/chapter_five_catalog.gd")
const JourneyScript = preload("res://scripts/managers/journey_manager.gd")

var _issues: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Do not mutate any real autoload's stage keys or SaveManager domain.
	var manager: Node = JourneyScript.new()
	_check(manager.call("get_chapter_ids") == [1, 2, 3, 4, 5], "chapter identity list")
	_check(manager.call("get_stage_ids", 4) == [1, 2, 3, 4, 5], "chapter 4 trials")
	_check(manager.call("get_stage_ids", 5) == [1, 2, 3, 4, 5], "chapter 5 trials")
	_test_unlock(manager, 3, 5, "4-1")
	_test_unlock(manager, 4, 1, "4-2")
	_test_unlock(manager, 4, 5, "5-1")
	_test_unlock(manager, 5, 4, "5-5")
	manager.free()
	for chapter_id: int in [4, 5]:
		var definitions: Dictionary = ChapterFour.STAGES if chapter_id == 4 else ChapterFive.STAGES
		var vista_path: String = Art.get_realm_vista_path(chapter_id)
		_check(ResourceLoader.exists(vista_path), "realm vista %d" % chapter_id)
		_check(str(Visual.get_chapter_profile(chapter_id).get("realm_motif", "")) in ["frostveil", "solar_nirvana"], "realm profile %d" % chapter_id)
		_check(Art.get_presentation_stage_ids(chapter_id, [1, 2, 3, 4, 5]) == [1, 2, 3, 4, 5], "stage map ids %d" % chapter_id)
		for stage_id: int in range(1, 6):
			var stage_data: Dictionary = definitions.get(stage_id, {})
			_check(not stage_data.is_empty(), "stage data %d-%d" % [chapter_id, stage_id])
			_check(bool(stage_data.get("implemented", false)), "not playable %d-%d" % [chapter_id, stage_id])
			_check(ResourceLoader.exists(str(stage_data.get("scene_path", ""))), "scene %d-%d" % [chapter_id, stage_id])
			_check(ResourceLoader.exists(Art.get_stage_art_path(chapter_id, stage_id)), "stage art %d-%d" % [chapter_id, stage_id])
			for state: String in ["BOSS", "LOCKED", "CURRENT", "CLEARED"]:
				_check(ResourceLoader.exists(Art.get_node_seal_path(chapter_id, state)), "seal %d / %s" % [chapter_id,state])
			_check(RewardManager.has_stage_clear_reward_definition(chapter_id, stage_id), "reward definition %d-%d" % [chapter_id,stage_id])
			var first: Dictionary = RewardManager.get_stage_clear_reward(chapter_id, stage_id, true)
			var repeat: Dictionary = RewardManager.get_stage_clear_reward(chapter_id, stage_id, false)
			_check(int(first.get("spirit_stone", -1)) == int(stage_data.get("first_clear_stones", -2)), "first-clear stones %d-%d" % [chapter_id,stage_id])
			_check(int(repeat.get("spirit_stone", -1)) == int(stage_data.get("repeat_clear_stones", -2)), "repeat stones %d-%d" % [chapter_id,stage_id])
			_check(int(first.get("hero_exp", -1)) == int(round(float(stage_data.get("hero_exp_base", 0))*1.5)), "first EXP %d-%d" % [chapter_id,stage_id])
			_check(int(repeat.get("hero_exp", -1)) == int(stage_data.get("hero_exp_base", -2)), "repeat EXP %d-%d" % [chapter_id,stage_id])
			_check((first.get("items", {}) as Dictionary).is_empty(), "first-clear should not give items %d-%d" % [chapter_id,stage_id])
			var repeat_items: Dictionary = repeat.get("items", {})
			_check(repeat_items.size() == 1 and int(repeat_items.get(InventoryManager.REFINEMENT_SHARD, 0)) == int(stage_data.get("repeat_clear_shards", -1)), "repeat shards %d-%d" % [chapter_id,stage_id])
	_check(Art.get_presentation_stage_ids(1,[1,2,3,4,5,6]) == [1,2,3,4,5], "legacy 1-6 remains hidden")
	if _issues.is_empty():
		print("REALM_EXPANSION_GATE_C_PASS: 5 realms / 10 new trials / unlock / rewards / art / legacy")
		quit(0)
		return
	for issue: String in _issues:
		push_error("Gate C: " + issue)
	print("REALM_EXPANSION_GATE_C_FAIL: %d findings" % _issues.size())
	quit(1)

func _test_unlock(manager: Node, from_chapter: int, from_stage: int, expected_key: String) -> void:
	manager.set("unlocked_stage_keys", [])
	manager.call("_unlock_next_stage", from_chapter, from_stage)
	_check(expected_key in (manager.get("unlocked_stage_keys") as Array), "unlock %d-%d => %s" % [from_chapter, from_stage, expected_key])

func _check(result: bool, label: String) -> void:
	if not result:
		_issues.append(label)
