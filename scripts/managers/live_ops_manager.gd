extends Node

## Home Live UI Phase 1
##
## Persistence strategy:
## - Reuses PavilionManager's permanent claimed_milestone_ids ledger with a
##   namespaced `liveops:` prefix.
## - Login activity/read flags are single-domain atomic writes.
## - Reward claims append their permanent claim marker to the Pavilion snapshot
##   passed into RewardManager, so reward + claim state commit atomically.
## - No new SaveManager domain or autoload is introduced.
##
## This intentionally keeps the first production pass small while remaining
## idempotent and safe across restarts.
signal live_ops_changed

const LiveOpsLocalization = preload(
	"res://scripts/liveops/live_ops_localization.gd"
)

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const ACTIVE_PREFIX: String = "liveops:new_player:active:"
const LOGIN_CLAIM_PREFIX: String = "liveops:new_player:claim:"
const MAIL_READ_PREFIX: String = "liveops:mail:read:"
const MAIL_CLAIM_PREFIX: String = "liveops:mail:claim:"

const LOGIN_DAY_COUNT: int = 7
const DATE_CHECK_INTERVAL: float = 20.0

const LOGIN_REWARDS: Dictionary = {
	1: {"spirit_stone": 100, "items": {}},
	2: {"spirit_stone": 150, "items": {"refinement_shard": 2}},
	3: {"spirit_stone": 200, "items": {"refinement_shard": 3}},
	4: {"spirit_stone": 250, "items": {"refinement_shard": 5}},
	5: {"spirit_stone": 300, "items": {"refinement_shard": 7}},
	6: {"spirit_stone": 400, "items": {"refinement_shard": 10}},
	7: {"spirit_stone": 600, "items": {"refinement_shard": 20}},
}

const MAIL_ORDER: Array[String] = [
	"welcome_initiate",
	"celestial_path_notice",
]

const MAIL_CATALOG: Dictionary = {
	"welcome_initiate": {
		"sender": "JADE SANCTUARY",
		"title": "Welcome, Wandering Cultivator",
		"body": (
			"Your first steps on the immortal path have begun. "
			+ "Accept these supplies and prepare for the trials ahead."
		),
		"reward": {
			"spirit_stone": 150,
			"items": {"refinement_shard": 3},
		},
	},
	"celestial_path_notice": {
		"sender": "CELESTIAL PAVILION",
		"title": "Seven Days of Ascension",
		"body": (
			"Return on seven active days to unlock newcomer supplies. "
			+ "Missed calendar days do not erase your progress."
		),
		"reward": {},
	},
}

var _active_live_popup: Control = null
var _active_live_popup_scene: String = ""
var _date_check_elapsed: float = 0.0
var _last_date_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	LiveOpsLocalization.install()
	_last_date_key = _get_current_date_key()
	_record_current_active_day()
	_audit_reward_catalog()
	DebugLogger.system(str(
		"LiveOps Phase 1 aktif | Active day: ",
		get_active_login_day_count(),
		"/",
		LOGIN_DAY_COUNT
	))


func _process(delta: float) -> void:
	_date_check_elapsed += delta
	if _date_check_elapsed < DATE_CHECK_INTERVAL:
		return
	_date_check_elapsed = 0.0

	var current_date: String = _get_current_date_key()
	if current_date == _last_date_key:
		return
	_last_date_key = current_date
	_record_current_active_day()


func _audit_reward_catalog() -> void:
	for day: int in range(1, LOGIN_DAY_COUNT + 1):
		var reward: Dictionary = get_login_reward(day)
		if not RewardManager.is_valid_reward(
			RewardManager.SOURCE_PAVILION,
			"live_ops_login_day_%d" % day,
			reward
		):
			push_error(
				"LiveOpsManager: invalid login reward catalog day "
				+ str(day)
			)

	var mail_ids: Array[String] = get_mail_ids()
	if mail_ids.size() != MAIL_ORDER.size():
		push_error(
			"LiveOpsManager: mailbox order contains duplicate or unknown IDs."
		)
	if mail_ids.size() != MAIL_CATALOG.size():
		push_error(
			"LiveOpsManager: mailbox catalog/order coverage is incomplete."
		)

	for mail_id: String in mail_ids:
		var mail: Dictionary = get_mail(mail_id)
		var reward: Dictionary = mail.get("reward", {})
		if reward.is_empty():
			continue
		if not RewardManager.is_valid_reward(
			RewardManager.SOURCE_PAVILION,
			"live_ops_mail_" + mail_id,
			reward
		):
			push_error(
				"LiveOpsManager: invalid mailbox reward " + mail_id
			)


func _get_current_date_key() -> String:
	if DailyQuestManager != null and DailyQuestManager.has_method(
		"get_current_date_key"
	):
		return str(DailyQuestManager.get_current_date_key())
	return Time.get_date_string_from_system()


func _get_ledger() -> Array[String]:
	var result: Array[String] = []
	var raw_ledger: Variant = PavilionManager.state.get(
		"claimed_milestone_ids",
		[]
	)
	if raw_ledger is Array:
		for raw_entry: Variant in raw_ledger:
			var entry: String = str(raw_entry)
			if entry.is_empty() or entry in result:
				continue
			result.append(entry)
	return result


func _build_pavilion_snapshot(ledger: Array[String]) -> Dictionary:
	var next_state: Dictionary = PavilionManager.state.duplicate(true)
	next_state["version"] = 1
	next_state["claimed_milestone_ids"] = ledger.duplicate()
	return next_state


func _apply_pavilion_snapshot(next_state: Dictionary) -> void:
	PavilionManager.state = next_state.duplicate(true)
	PavilionManager.pavilion_changed.emit()
	live_ops_changed.emit()


func _commit_ledger(ledger: Array[String]) -> bool:
	if SaveManager.is_progress_read_only():
		return false
	var next_state: Dictionary = _build_pavilion_snapshot(ledger)
	var result: Dictionary = SaveManager.write_save_data(
		"pavilion",
		next_state
	)
	if not bool(result.get("success", false)):
		return false
	_apply_pavilion_snapshot(next_state)
	return true


func _is_valid_date_key(date_key: String) -> bool:
	var value: String = date_key.strip_edges()
	if (
		value.length() != 10
		or value.substr(4, 1) != "-"
		or value.substr(7, 1) != "-"
	):
		return false

	var year_text: String = value.substr(0, 4)
	var month_text: String = value.substr(5, 2)
	var day_text: String = value.substr(8, 2)
	for numeric_part: String in [year_text, month_text, day_text]:
		for index: int in range(numeric_part.length()):
			var code: int = numeric_part.unicode_at(index)
			if code < 48 or code > 57:
				return false

	var year: int = int(year_text)
	var month: int = int(month_text)
	var day: int = int(day_text)
	if year < 1970 or month < 1 or month > 12 or day < 1:
		return false

	var max_day: int = 31
	match month:
		4, 6, 9, 11:
			max_day = 30
		2:
			var leap_year: bool = (
				year % 400 == 0
				or (year % 4 == 0 and year % 100 != 0)
			)
			max_day = 29 if leap_year else 28
	return day <= max_day


func _get_latest_active_date_key() -> String:
	var latest: String = ""
	for entry: String in _get_ledger():
		if not entry.begins_with(ACTIVE_PREFIX):
			continue
		var date_key: String = entry.trim_prefix(ACTIVE_PREFIX)
		if not _is_valid_date_key(date_key):
			continue
		if latest.is_empty() or date_key.casecmp_to(latest) > 0:
			latest = date_key
	return latest


func _record_active_date(date_key: String) -> bool:
	if get_active_login_day_count() >= LOGIN_DAY_COUNT:
		return false

	var current_date: String = date_key.strip_edges()
	if not _is_valid_date_key(current_date):
		return false

	# Offline v1 intentionally uses the local calendar, but progress itself is
	# monotonic: duplicate/backward dates cannot manufacture additional days.
	var latest: String = _get_latest_active_date_key()
	if not latest.is_empty() and current_date.casecmp_to(latest) <= 0:
		return false

	var marker: String = ACTIVE_PREFIX + current_date
	var ledger: Array[String] = _get_ledger()
	if marker in ledger:
		return false

	ledger.append(marker)
	if not _commit_ledger(ledger):
		return false

	DebugLogger.system(str(
		"LiveOps active login recorded | Day ",
		get_active_login_day_count(),
		" | ",
		current_date
	))
	return true


func _record_current_active_day() -> bool:
	return _record_active_date(_get_current_date_key())


func get_active_login_day_count() -> int:
	var seen_dates: Dictionary = {}
	for entry: String in _get_ledger():
		if not entry.begins_with(ACTIVE_PREFIX):
			continue
		var date_key: String = entry.trim_prefix(ACTIVE_PREFIX)
		if not _is_valid_date_key(date_key) or seen_dates.has(date_key):
			continue
		seen_dates[date_key] = true
	return clampi(seen_dates.size(), 0, LOGIN_DAY_COUNT)


func get_login_reward(day: int) -> Dictionary:
	if not LOGIN_REWARDS.has(day):
		return {}
	var reward: Dictionary = LOGIN_REWARDS[day]
	return reward.duplicate(true)


func is_login_day_unlocked(day: int) -> bool:
	return (
		day >= 1
		and day <= LOGIN_DAY_COUNT
		and day <= get_active_login_day_count()
	)


func is_login_day_claimed(day: int) -> bool:
	if day < 1 or day > LOGIN_DAY_COUNT:
		return false
	return LOGIN_CLAIM_PREFIX + str(day) in _get_ledger()


func get_login_claimable_count() -> int:
	var count: int = 0
	for day: int in range(1, LOGIN_DAY_COUNT + 1):
		if is_login_day_unlocked(day) and not is_login_day_claimed(day):
			count += 1
	return count


func is_new_player_event_complete() -> bool:
	for day: int in range(1, LOGIN_DAY_COUNT + 1):
		if not is_login_day_claimed(day):
			return false
	return true


func claim_login_day(day: int) -> bool:
	if (
		not is_login_day_unlocked(day)
		or is_login_day_claimed(day)
		or SaveManager.is_progress_read_only()
	):
		return false

	var reward: Dictionary = get_login_reward(day)
	if reward.is_empty():
		return false

	var ledger: Array[String] = _get_ledger()
	var claim_marker: String = LOGIN_CLAIM_PREFIX + str(day)
	ledger.append(claim_marker)
	var next_pavilion: Dictionary = _build_pavilion_snapshot(ledger)

	var result: Dictionary = RewardManager.grant_reward(
		RewardManager.SOURCE_PAVILION,
		"live_ops_login_day_%d" % day,
		reward,
		{"pavilion": next_pavilion}
	)
	if not bool(result.get("success", false)):
		return false

	_apply_pavilion_snapshot(next_pavilion)
	return true


func get_mail_ids() -> Array[String]:
	var result: Array[String] = []
	for mail_id: String in MAIL_ORDER:
		var normalized: String = mail_id.strip_edges()
		if (
			normalized.is_empty()
			or normalized in result
			or not MAIL_CATALOG.has(normalized)
		):
			continue
		result.append(normalized)
	return result


func get_mail(mail_id: String) -> Dictionary:
	if not MAIL_CATALOG.has(mail_id):
		return {}
	var catalog_mail: Dictionary = MAIL_CATALOG[mail_id]
	var mail: Dictionary = catalog_mail.duplicate(true)
	mail["id"] = mail_id
	mail["read"] = is_mail_read(mail_id)
	mail["claimed"] = is_mail_claimed(mail_id)
	return mail


func get_mail_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for mail_id: String in get_mail_ids():
		var mail: Dictionary = get_mail(mail_id)
		if not mail.is_empty():
			entries.append(mail)
	return entries


func is_mail_read(mail_id: String) -> bool:
	if not MAIL_CATALOG.has(mail_id):
		return false
	return MAIL_READ_PREFIX + mail_id in _get_ledger()


func is_mail_claimed(mail_id: String) -> bool:
	if not MAIL_CATALOG.has(mail_id):
		return false
	var mail: Dictionary = MAIL_CATALOG[mail_id]
	var reward: Dictionary = mail.get("reward", {})
	if reward.is_empty():
		return true
	return MAIL_CLAIM_PREFIX + mail_id in _get_ledger()


func get_mail_unread_count() -> int:
	var count: int = 0
	for mail_id: String in get_mail_ids():
		if not is_mail_read(mail_id):
			count += 1
	return count


func get_mail_claimable_count() -> int:
	var count: int = 0
	for mail_id: String in get_mail_ids():
		var mail: Dictionary = MAIL_CATALOG.get(mail_id, {})
		var reward: Dictionary = mail.get("reward", {})
		if not reward.is_empty() and not is_mail_claimed(mail_id):
			count += 1
	return count


func mark_all_mail_read() -> bool:
	var ledger: Array[String] = _get_ledger()
	var changed: bool = false
	for mail_id: String in get_mail_ids():
		var marker: String = MAIL_READ_PREFIX + mail_id
		if marker in ledger:
			continue
		ledger.append(marker)
		changed = true
	if not changed:
		return true
	return _commit_ledger(ledger)


func claim_mail(mail_id: String) -> bool:
	if (
		not MAIL_CATALOG.has(mail_id)
		or is_mail_claimed(mail_id)
		or SaveManager.is_progress_read_only()
	):
		return false

	var catalog_mail: Dictionary = MAIL_CATALOG[mail_id]
	var reward: Dictionary = catalog_mail.get("reward", {})
	if reward.is_empty():
		return false

	var ledger: Array[String] = _get_ledger()
	var read_marker: String = MAIL_READ_PREFIX + mail_id
	var claim_marker: String = MAIL_CLAIM_PREFIX + mail_id
	if read_marker not in ledger:
		ledger.append(read_marker)
	ledger.append(claim_marker)

	var next_pavilion: Dictionary = _build_pavilion_snapshot(ledger)
	var result: Dictionary = RewardManager.grant_reward(
		RewardManager.SOURCE_PAVILION,
		"live_ops_mail_" + mail_id,
		reward,
		{"pavilion": next_pavilion}
	)
	if not bool(result.get("success", false)):
		return false

	_apply_pavilion_snapshot(next_pavilion)
	return true


func get_home_mail_badge_count() -> int:
	return maxi(
		get_mail_unread_count(),
		get_mail_claimable_count()
	)


func open_live_popup(scene_path: String) -> void:
	if SceneTransitionManager.is_transitioning or not ResourceLoader.exists(scene_path, "PackedScene"):
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null or tree.current_scene.scene_file_path != MAIN_MENU_SCENE:
		SceneTransitionManager.transition_menu_to(scene_path, 1)
		return
	if is_instance_valid(_active_live_popup):
		_active_live_popup.hide()
		_active_live_popup.queue_free()
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	var popup := packed.instantiate() as Control
	if popup == null:
		return
	popup.set_meta("liveops_popup", true)
	popup.z_index = 100
	tree.current_scene.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_active_live_popup = popup
	_active_live_popup_scene = scene_path
	SceneTransitionManager.set_back_handler(close_live_popup)


func close_live_popup() -> void:
	var popup := _active_live_popup
	_active_live_popup = null
	_active_live_popup_scene = ""
	if is_instance_valid(popup):
		popup.hide()
		popup.queue_free()
	var tree := get_tree()
	if tree != null and tree.current_scene != null and tree.current_scene.has_method("handle_system_back"):
		SceneTransitionManager.set_back_handler(Callable(tree.current_scene, "handle_system_back"))
