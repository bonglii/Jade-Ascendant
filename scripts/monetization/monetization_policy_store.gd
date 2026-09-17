extends RefCounted

## Operational monetization policy state.
## This is intentionally separate from player progression saves: it stores only
## anti-abuse timing/count data and never owns currency, inventory or entitlement
## value. Writes use a small atomic primary/rollback/backup sequence.

const SAVE_PATH: String = "user://monetization_policy.save"
const SAVE_VERSION: int = 1


func load_state() -> Dictionary:
	var current_unix: int = _get_unix_time()
	var current_day: int = _get_day_bucket(current_unix)

	var state: Dictionary = _read_valid_state(SAVE_PATH)
	if state.is_empty():
		state = _read_valid_state(SAVE_PATH + ".backup")
		if not state.is_empty():
			# Restore a valid backup so future starts use the recovered primary.
			save_state(state)

	if state.is_empty():
		return _default_state(current_day)

	var stored_day: int = int(state.get("day_bucket", current_day))
	if stored_day < 0:
		stored_day = current_day

	# A newer real day resets daily placement counters. A backwards system clock
	# never rewinds the stored bucket, which avoids an easy clock-reset bypass.
	if current_day > stored_day:
		state["day_bucket"] = current_day
		state["placement_counts"] = {}
		save_state(state)

	return state


func save_state(state: Dictionary) -> bool:
	var normalized: Dictionary = _normalize_state(state)
	if normalized.is_empty():
		return false

	var staging_path: String = SAVE_PATH + ".tmp"
	var rollback_path: String = SAVE_PATH + ".rollback"
	var backup_path: String = SAVE_PATH + ".backup"

	if not _remove_if_present(staging_path):
		return false
	if not _remove_if_present(rollback_path):
		return false

	var staging: FileAccess = FileAccess.open(
		staging_path,
		FileAccess.WRITE
	)
	if staging == null:
		return false
	staging.store_var(normalized)
	staging.flush()
	staging.close()

	if _read_valid_state(staging_path) != normalized:
		_remove_if_present(staging_path)
		return false

	var had_primary: bool = FileAccess.file_exists(SAVE_PATH)
	if had_primary:
		if _rename(SAVE_PATH, rollback_path) != OK:
			_remove_if_present(staging_path)
			return false

	if _rename(staging_path, SAVE_PATH) != OK:
		if had_primary:
			_rename(rollback_path, SAVE_PATH)
		_remove_if_present(staging_path)
		return false

	if _read_valid_state(SAVE_PATH) != normalized:
		_remove_if_present(SAVE_PATH)
		if had_primary:
			_rename(rollback_path, SAVE_PATH)
		return false

	if had_primary and FileAccess.file_exists(rollback_path):
		if _remove_if_present(backup_path):
			if _rename(rollback_path, backup_path) != OK:
				# Primary is already committed and validated. A backup promotion
				# failure is non-fatal; remove the orphan if possible.
				_remove_if_present(rollback_path)
		else:
			_remove_if_present(rollback_path)

	return true


func _read_valid_state(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var loaded: Variant = file.get_var()
	file.close()
	if not loaded is Dictionary:
		return {}

	return _normalize_state(loaded as Dictionary)


func _normalize_state(state: Dictionary) -> Dictionary:
	if not state.get("version") is int:
		return {}
	if int(state.get("version", -1)) != SAVE_VERSION:
		return {}
	if not _is_nonnegative_integer(state.get("day_bucket")):
		return {}
	if not _is_nonnegative_integer(state.get("last_reward_unix")):
		return {}

	var raw_counts: Variant = state.get("placement_counts")
	if not raw_counts is Dictionary:
		return {}

	var counts: Dictionary = {}
	for raw_key: Variant in raw_counts.keys():
		if not raw_key is String:
			return {}
		var key: String = str(raw_key).strip_edges()
		if key.is_empty():
			return {}
		var raw_count: Variant = raw_counts[raw_key]
		if not _is_nonnegative_integer(raw_count):
			return {}
		counts[key] = int(raw_count)

	return {
		"version": SAVE_VERSION,
		"day_bucket": int(state["day_bucket"]),
		"last_reward_unix": int(state["last_reward_unix"]),
		"placement_counts": counts
	}


func _default_state(current_day: int) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"day_bucket": maxi(current_day, 0),
		"last_reward_unix": 0,
		"placement_counts": {}
	}


func _is_nonnegative_integer(value: Variant) -> bool:
	if value is int:
		return int(value) >= 0
	if not value is float:
		return false
	var numeric: float = float(value)
	return (
		is_finite(numeric)
		and numeric >= 0.0
		and numeric < 9007199254740992.0
		and floorf(numeric) == numeric
	)


func _get_unix_time() -> int:
	return maxi(int(floor(Time.get_unix_time_from_system())), 0)


func _get_day_bucket(unix_time: int) -> int:
	return int(unix_time / 86400)


func _rename(source_path: String, target_path: String) -> Error:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(target_path)
	)


func _remove_if_present(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return (
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(path)
		) == OK
	)
