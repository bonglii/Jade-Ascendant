extends Node

signal stage_completed(
	chapter_id: int,
	stage_id: int,
	was_first_clear: bool
)

## Journey Manager
## Mengelola metadata Chapter/Stage, progres unlock, pilihan stage,
## dan identitas run aktif.
## Manager ini TIDAK mengelola Wave, combat, reward, atau isi checkpoint.

const SAVE_PATH := "user://journey.save"
const SAVE_VERSION := 1

const DEFAULT_CHAPTER_ID := 1
const DEFAULT_STAGE_ID := 1
const NO_ACTIVE_ID := 0

const ChapterOneCatalog = preload("res://scripts/data/chapter_one_catalog.gd")
const ChapterTwoCatalog = preload("res://scripts/data/chapter_two_catalog.gd")
const ChapterThreeCatalog = preload("res://scripts/data/chapter_three_catalog.gd")
const CHAPTERS := {
	1: {
		"display_name": "Verdant Qi Valley",
		"stages": ChapterOneCatalog.STAGES
	},
	2: {
		"display_name": "Crimson Moon Sect",
		"stages": ChapterTwoCatalog.STAGES
	},
	3: {
		"display_name": "Nine Heavens Star Palace",
		"stages": ChapterThreeCatalog.STAGES
	}
}

var selected_chapter_id: int = DEFAULT_CHAPTER_ID
var selected_stage_id: int = DEFAULT_STAGE_ID

var active_run_chapter_id: int = NO_ACTIVE_ID
var active_run_stage_id: int = NO_ACTIVE_ID

var unlocked_stage_keys: Array = []
var cleared_stage_keys: Array = []

func _ready() -> void:
	_load_progress()
	_ensure_valid_state()
	_save_progress()
	DebugLogger.system(str(
		"JourneyManager aktif! Selected: Chapter ",
		selected_chapter_id,
		" Stage ",
		selected_stage_id
	))

func get_stage_key(chapter_id: int, stage_id: int) -> String:
	return str(chapter_id) + "-" + str(stage_id)

func has_chapter(chapter_id: int) -> bool:
	return CHAPTERS.has(chapter_id)

func get_chapter_ids() -> Array:
	var chapter_ids: Array = []
	for raw_chapter_id in CHAPTERS.keys():
		chapter_ids.append(int(raw_chapter_id))
	chapter_ids.sort()
	return chapter_ids

func get_stage_ids(chapter_id: int) -> Array:
	var stage_ids: Array = []
	if not has_chapter(chapter_id):
		return stage_ids
	var chapter_data: Dictionary = CHAPTERS[chapter_id]
	var stages: Dictionary = chapter_data.get("stages", {})
	for raw_stage_id in stages.keys():
		stage_ids.append(int(raw_stage_id))
	stage_ids.sort()
	return stage_ids

func is_chapter_unlocked(chapter_id: int) -> bool:
	if not has_chapter(chapter_id):
		return false
	var chapter_data: Dictionary = CHAPTERS[chapter_id]
	var stages: Dictionary = chapter_data.get("stages", {})
	for raw_stage_id in stages.keys():
		var stage_id := int(raw_stage_id)
		if is_stage_unlocked(chapter_id, stage_id):
			return true
	return false

func get_chapter_progress(chapter_id: int) -> Dictionary:
	var progress := {
		"total_stages": 0,
		"unlocked_stages": 0,
		"cleared_stages": 0
	}
	if not has_chapter(chapter_id):
		return progress
	var chapter_data: Dictionary = CHAPTERS[chapter_id]
	var stages: Dictionary = chapter_data.get("stages", {})
	for raw_stage_id in stages.keys():
		var stage_id := int(raw_stage_id)
		progress["total_stages"] += 1
		if is_stage_unlocked(chapter_id, stage_id):
			progress["unlocked_stages"] += 1
		if is_stage_cleared(chapter_id, stage_id):
			progress["cleared_stages"] += 1
	return progress

func select_chapter(chapter_id: int) -> bool:
	if not has_chapter(chapter_id):
		return false
	if not is_chapter_unlocked(chapter_id):
		return false
	selected_chapter_id = chapter_id
	_save_progress()
	return true

func has_stage(chapter_id: int, stage_id: int) -> bool:
	if not has_chapter(chapter_id):
		return false
	var chapter_data: Dictionary = CHAPTERS[chapter_id]
	var stages: Dictionary = chapter_data.get("stages", {})
	return stages.has(stage_id)

func get_chapter_data(chapter_id: int) -> Dictionary:
	if not has_chapter(chapter_id):
		return {}
	var chapter_data: Dictionary = CHAPTERS[chapter_id]
	return chapter_data.duplicate(true)

func get_stage_data(chapter_id: int, stage_id: int) -> Dictionary:
	if not has_stage(chapter_id, stage_id):
		return {}
	var chapter_data: Dictionary = CHAPTERS[chapter_id]
	var stages: Dictionary = chapter_data["stages"]
	var stage_data: Dictionary = stages[stage_id]
	return stage_data.duplicate(true)

func is_stage_implemented(chapter_id: int, stage_id: int) -> bool:
	var stage_data := get_stage_data(chapter_id, stage_id)
	if stage_data.is_empty():
		return false
	return bool(stage_data.get("implemented", false))

func is_stage_unlocked(chapter_id: int, stage_id: int) -> bool:
	return get_stage_key(chapter_id, stage_id) in unlocked_stage_keys

func is_stage_cleared(chapter_id: int, stage_id: int) -> bool:
	return get_stage_key(chapter_id, stage_id) in cleared_stage_keys

func select_stage(chapter_id: int, stage_id: int) -> bool:
	if not has_stage(chapter_id, stage_id):
		return false
	if not is_stage_unlocked(chapter_id, stage_id):
		return false
	if not is_stage_implemented(chapter_id, stage_id):
		return false
	selected_chapter_id = chapter_id
	selected_stage_id = stage_id
	_save_progress()
	return true

func get_selected_stage_data() -> Dictionary:
	return get_stage_data(selected_chapter_id, selected_stage_id)

func begin_selected_stage() -> String:
	if SaveManager.is_progress_read_only():
		return ""
	if not is_stage_unlocked(selected_chapter_id, selected_stage_id):
		return ""
	if not is_stage_implemented(selected_chapter_id, selected_stage_id):
		return ""
	var stage_data := get_selected_stage_data()
	var scene_path := str(stage_data.get("scene_path", ""))
	if scene_path.is_empty():
		return ""
	active_run_chapter_id = selected_chapter_id
	active_run_stage_id = selected_stage_id
	_save_progress()
	return scene_path

func has_active_run() -> bool:
	return (
		active_run_chapter_id != NO_ACTIVE_ID
		and active_run_stage_id != NO_ACTIVE_ID
		and has_stage(active_run_chapter_id, active_run_stage_id)
	)

func get_active_stage_data() -> Dictionary:
	if not has_active_run():
		return {}
	return get_stage_data(active_run_chapter_id, active_run_stage_id)

func get_active_stage_scene_path() -> String:
	var stage_data := get_active_stage_data()
	if stage_data.is_empty():
		return ""
	return str(stage_data.get("scene_path", ""))

func restore_active_run(chapter_id: int, stage_id: int) -> bool:
	if not has_stage(chapter_id, stage_id):
		return false
	if not is_stage_implemented(chapter_id, stage_id):
		return false
	active_run_chapter_id = chapter_id
	active_run_stage_id = stage_id
	selected_chapter_id = chapter_id
	selected_stage_id = stage_id
	_append_unique_stage_key(
		unlocked_stage_keys,
		get_stage_key(chapter_id, stage_id)
	)
	_save_progress()
	return true

func complete_active_stage(persist_now: bool = true) -> bool:
	if not has_active_run():
		return false
	var completed_chapter_id := active_run_chapter_id
	var completed_stage_id := active_run_stage_id
	var completed_key := get_stage_key(
		completed_chapter_id,
		completed_stage_id
	)
	var was_first_clear := completed_key not in cleared_stage_keys
	_append_unique_stage_key(cleared_stage_keys, completed_key)
	_unlock_next_stage(completed_chapter_id, completed_stage_id)
	clear_active_run(false)
	if not persist_now:
		return was_first_clear
	_save_progress()
	stage_completed.emit(
		completed_chapter_id,
		completed_stage_id,
		was_first_clear
	)
	return was_first_clear

func clear_active_run(save_now: bool = true) -> void:
	active_run_chapter_id = NO_ACTIVE_ID
	active_run_stage_id = NO_ACTIVE_ID
	if save_now:
		_save_progress()

func _unlock_next_stage(chapter_id: int, stage_id: int) -> void:
	var stage_ids := get_stage_ids(chapter_id)
	var stage_index := stage_ids.find(stage_id)
	if stage_index >= 0 and stage_index + 1 < stage_ids.size():
		var next_stage_id := int(stage_ids[stage_index + 1])
		_append_unique_stage_key(
			unlocked_stage_keys,
			get_stage_key(chapter_id, next_stage_id)
		)
		# Realm 1 production presentation now ends at Stage 1-5. Keep legacy
		# Stage 1-6 unlockable only for old saves/regression compatibility, while
		# opening the real next Realm immediately after the visible finale.
		if chapter_id == 1 and stage_id == 5:
			_unlock_first_stage_of_next_chapter(chapter_id)
		return
	_unlock_first_stage_of_next_chapter(chapter_id)

func _unlock_first_stage_of_next_chapter(chapter_id: int) -> void:
	var chapter_ids := get_chapter_ids()
	var chapter_index := chapter_ids.find(chapter_id)
	if chapter_index < 0 or chapter_index + 1 >= chapter_ids.size():
		return
	var next_chapter_id := int(chapter_ids[chapter_index + 1])
	var next_chapter_stage_ids := get_stage_ids(next_chapter_id)
	if next_chapter_stage_ids.is_empty():
		return
	var first_stage_id := int(next_chapter_stage_ids[0])
	_append_unique_stage_key(
		unlocked_stage_keys,
		get_stage_key(next_chapter_id, first_stage_id)
	)

func _append_unique_stage_key(target: Array, stage_key: String) -> void:
	if stage_key not in target:
		target.append(stage_key)

func _ensure_valid_state() -> void:
	unlocked_stage_keys = _normalize_stage_keys(unlocked_stage_keys)
	cleared_stage_keys = _normalize_stage_keys(cleared_stage_keys)
	_append_unique_stage_key(
		unlocked_stage_keys,
		get_stage_key(DEFAULT_CHAPTER_ID, DEFAULT_STAGE_ID)
	)
	for chapter_id: int in get_chapter_ids():
		for stage_id: int in get_stage_ids(chapter_id):
			if is_stage_cleared(chapter_id, stage_id):
				_append_unique_stage_key(unlocked_stage_keys, get_stage_key(chapter_id, stage_id))
				_unlock_next_stage(chapter_id, stage_id)
	if (
		not has_stage(selected_chapter_id, selected_stage_id)
		or not is_stage_unlocked(selected_chapter_id, selected_stage_id)
		or not is_stage_implemented(selected_chapter_id, selected_stage_id)
	):
		selected_chapter_id = DEFAULT_CHAPTER_ID
		selected_stage_id = DEFAULT_STAGE_ID
	if (
		active_run_chapter_id != NO_ACTIVE_ID
		or active_run_stage_id != NO_ACTIVE_ID
	):
		if (
			not has_stage(active_run_chapter_id, active_run_stage_id)
			or not is_stage_implemented(
				active_run_chapter_id,
				active_run_stage_id
			)
		):
			active_run_chapter_id = NO_ACTIVE_ID
			active_run_stage_id = NO_ACTIVE_ID

func _normalize_stage_keys(value: Variant) -> Array:
	var normalized: Array = []
	if not value is Array:
		return normalized
	for raw_key in value:
		var stage_key := str(raw_key)
		if stage_key.is_empty():
			continue
		_append_unique_stage_key(normalized, stage_key)
	return normalized

func _save_progress() -> void:
	var save_data: Dictionary = build_save_data()
	var io_result: Dictionary = SaveManager.write_save_data(
		"journey",
		save_data
	)
	if not bool(io_result.get("success", false)):
		push_error("JourneyManager: gagal menyimpan journey progress.")

func _load_progress() -> void:
	var io_result: Dictionary = SaveManager.read_save_data("journey")
	if not bool(io_result.get("exists", false)):
		return
	if not bool(io_result.get("success", false)):
		push_warning("JourneyManager: journey.save tidak dapat dibuka.")
		return
	var save_data: Dictionary = io_result.get("data", {})
	selected_chapter_id = int(
		save_data.get("selected_chapter_id", DEFAULT_CHAPTER_ID)
	)
	selected_stage_id = int(
		save_data.get("selected_stage_id", DEFAULT_STAGE_ID)
	)
	active_run_chapter_id = int(
		save_data.get("active_run_chapter_id", NO_ACTIVE_ID)
	)
	active_run_stage_id = int(
		save_data.get("active_run_stage_id", NO_ACTIVE_ID)
	)
	unlocked_stage_keys = save_data.get("unlocked_stage_keys", [])
	cleared_stage_keys = save_data.get("cleared_stage_keys", [])

func build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"selected_chapter_id": selected_chapter_id,
		"selected_stage_id": selected_stage_id,
		"active_run_chapter_id": active_run_chapter_id,
		"active_run_stage_id": active_run_stage_id,
		"unlocked_stage_keys": unlocked_stage_keys.duplicate(),
		"cleared_stage_keys": cleared_stage_keys.duplicate()
	}
