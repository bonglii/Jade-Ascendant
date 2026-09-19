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

const ICON_MAILBOX: Texture2D = preload(
	"res://assets/ui/liveops/mailbox.png"
)
const ICON_SEVEN_DAY: Texture2D = preload(
	"res://assets/ui/liveops/seven_day.png"
)
const ICON_EVENT_CENTER: Texture2D = preload(
	"res://assets/ui/liveops/event_center.png"
)
const ICON_TREASURY: Texture2D = preload(
	"res://assets/ui/liveops/treasury.png"
)

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const MAILBOX_SCENE: String = "res://scenes/ui/mailbox_screen.tscn"
const NEW_PLAYER_EVENT_SCENE: String = (
	"res://scenes/ui/new_player_event_screen.tscn"
)
const EVENT_CENTER_SCENE: String = (
	"res://scenes/ui/event_center_screen.tscn"
)
const TREASURY_SCENE: String = (
	"res://scenes/ui/celestial_treasury_screen.tscn"
)

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

var _attached_home_id: int = 0
var _home_left_dock: VBoxContainer = null
var _home_right_dock: VBoxContainer = null
var _mail_badge: Button = null
var _login_badge: Button = null
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
	_attach_to_home_if_needed()

	_date_check_elapsed += delta
	if _date_check_elapsed < DATE_CHECK_INTERVAL:
		return
	_date_check_elapsed = 0.0

	var current_date: String = _get_current_date_key()
	if current_date == _last_date_key:
		return
	_last_date_key = current_date
	if _record_current_active_day():
		_refresh_home_badges()


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

	for mail_id: String in MAIL_ORDER:
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


func _record_current_active_day() -> bool:
	var active_days: int = get_active_login_day_count()
	if active_days >= LOGIN_DAY_COUNT:
		return false

	var current_date: String = _get_current_date_key()
	if current_date.is_empty():
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


func get_active_login_day_count() -> int:
	var count: int = 0
	for entry: String in _get_ledger():
		if entry.begins_with(ACTIVE_PREFIX):
			count += 1
	return clampi(count, 0, LOGIN_DAY_COUNT)


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
	_refresh_home_badges()
	return true


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
	for mail_id: String in MAIL_ORDER:
		var mail: Dictionary = get_mail(mail_id)
		if not mail.is_empty():
			entries.append(mail)
	return entries


func is_mail_read(mail_id: String) -> bool:
	return MAIL_READ_PREFIX + mail_id in _get_ledger()


func is_mail_claimed(mail_id: String) -> bool:
	var mail: Dictionary = MAIL_CATALOG.get(mail_id, {})
	var reward: Dictionary = mail.get("reward", {})
	if reward.is_empty():
		return true
	return MAIL_CLAIM_PREFIX + mail_id in _get_ledger()


func get_mail_unread_count() -> int:
	var count: int = 0
	for mail_id: String in MAIL_ORDER:
		if not is_mail_read(mail_id):
			count += 1
	return count


func get_mail_claimable_count() -> int:
	var count: int = 0
	for mail_id: String in MAIL_ORDER:
		var mail: Dictionary = MAIL_CATALOG.get(mail_id, {})
		var reward: Dictionary = mail.get("reward", {})
		if not reward.is_empty() and not is_mail_claimed(mail_id):
			count += 1
	return count


func mark_all_mail_read() -> bool:
	var ledger: Array[String] = _get_ledger()
	var changed: bool = false
	for mail_id: String in MAIL_ORDER:
		var marker: String = MAIL_READ_PREFIX + mail_id
		if marker in ledger:
			continue
		ledger.append(marker)
		changed = true
	if not changed:
		return true
	var saved: bool = _commit_ledger(ledger)
	if saved:
		_refresh_home_badges()
	return saved


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
	_refresh_home_badges()
	return true


func get_home_mail_badge_count() -> int:
	return maxi(
		get_mail_unread_count(),
		get_mail_claimable_count()
	)


func _attach_to_home_if_needed() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var scene: Node = tree.current_scene
	if scene.scene_file_path != MAIN_MENU_SCENE:
		_attached_home_id = 0
		_home_left_dock = null
		_home_right_dock = null
		_mail_badge = null
		_login_badge = null
		return

	var scene_id: int = int(scene.get_instance_id())
	if _attached_home_id == scene_id:
		return

	var home_ui: Control = scene.get_node_or_null("HomeUI") as Control
	if home_ui == null:
		return

	_attached_home_id = scene_id
	_build_home_live_ui(home_ui)
	_refresh_home_badges()


func _build_home_live_ui(home_ui: Control) -> void:
	_home_left_dock = VBoxContainer.new()
	_home_left_dock.name = "LiveOpsLeftDock"
	_home_left_dock.anchor_left = 0.0
	_home_left_dock.anchor_top = 0.39
	_home_left_dock.anchor_right = 0.0
	_home_left_dock.anchor_bottom = 0.39
	_home_left_dock.offset_left = 10.0
	_home_left_dock.offset_top = -118.0
	_home_left_dock.offset_right = 100.0
	_home_left_dock.offset_bottom = 162.0
	_home_left_dock.add_theme_constant_override("separation", 6)
	_home_left_dock.z_index = 12
	home_ui.add_child(_home_left_dock)

	var mail_button: Button = _make_home_shortcut(
		tr("MAIL"),
		ICON_MAILBOX,
		Color(0.30, 0.88, 0.78, 1.0)
	)
	mail_button.pressed.connect(
		func() -> void: _open_live_scene(MAILBOX_SCENE)
	)
	_home_left_dock.add_child(mail_button)
	_mail_badge = _add_badge(mail_button)

	var login_button: Button = _make_home_shortcut(
		tr("7-DAY"),
		ICON_SEVEN_DAY,
		Color(0.98, 0.76, 0.30, 1.0)
	)
	login_button.pressed.connect(
		func() -> void: _open_live_scene(NEW_PLAYER_EVENT_SCENE)
	)
	_home_left_dock.add_child(login_button)
	_login_badge = _add_badge(login_button)

	var event_button: Button = _make_home_shortcut(
		tr("EVENTS"),
		ICON_EVENT_CENTER,
		Color(0.42, 0.78, 0.96, 1.0)
	)
	event_button.pressed.connect(
		func() -> void: _open_live_scene(EVENT_CENTER_SCENE)
	)
	_home_left_dock.add_child(event_button)

	# Keep the unfinished real-money entry out of release builds until Google
	# Play Billing is connected and purchase recovery has passed device QA.
	if OS.is_debug_build():
		_home_right_dock = VBoxContainer.new()
		_home_right_dock.name = "LiveOpsRightDock"
		_home_right_dock.anchor_left = 1.0
		_home_right_dock.anchor_top = 0.39
		_home_right_dock.anchor_right = 1.0
		_home_right_dock.anchor_bottom = 0.39
		_home_right_dock.offset_left = -100.0
		_home_right_dock.offset_top = -44.0
		_home_right_dock.offset_right = -10.0
		_home_right_dock.offset_bottom = 52.0
		_home_right_dock.z_index = 12
		home_ui.add_child(_home_right_dock)

		var treasury_button: Button = _make_home_shortcut(
			tr("TREASURY"),
			ICON_TREASURY,
			Color(0.98, 0.76, 0.30, 1.0)
		)
		treasury_button.pressed.connect(
			func() -> void: _open_live_scene(TREASURY_SCENE)
		)
		_home_right_dock.add_child(treasury_button)


func _make_home_shortcut(
	label_text: String,
	icon_texture: Texture2D,
	accent: Color
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(90.0, 86.0)
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override(
		"normal",
		_make_shortcut_style(
			Color(0.002, 0.020, 0.028, 0.58),
			Color(accent.r, accent.g, accent.b, 0.34)
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_shortcut_style(
			Color(0.004, 0.050, 0.058, 0.82),
			Color(accent.r, accent.g, accent.b, 0.82)
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_shortcut_style(
			Color(0.002, 0.030, 0.038, 0.92),
			Color(accent.r, accent.g, accent.b, 0.72)
		)
	)

	var visual := VBoxContainer.new()
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual.offset_left = 4.0
	visual.offset_top = 2.0
	visual.offset_right = -4.0
	visual.offset_bottom = -4.0
	visual.add_theme_constant_override("separation", -2)
	visual.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(visual)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(66.0, 66.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual.add_child(icon)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override(
		"font_color",
		Color(0.96, 0.92, 0.80, 1.0)
	)
	label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.94)
	)
	label.add_theme_constant_override("shadow_offset_y", 2)
	visual.add_child(label)

	return button


func _make_shortcut_style(
	background: Color,
	border: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.44)
	style.shadow_size = 5
	return style


func _add_badge(button: Button) -> Button:
	var badge := Button.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.focus_mode = Control.FOCUS_NONE
	badge.anchor_left = 1.0
	badge.anchor_top = 0.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 0.0
	badge.offset_left = -23.0
	badge.offset_top = -5.0
	badge.offset_right = 3.0
	badge.offset_bottom = 21.0
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_stylebox_override("normal", _make_badge_style())
	badge.add_theme_stylebox_override("hover", _make_badge_style())
	badge.add_theme_stylebox_override("pressed", _make_badge_style())
	button.add_child(badge)
	return badge


func _make_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.90, 0.14, 0.08, 0.99)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.76, 0.30, 1.0)
	style.shadow_color = Color(0.90, 0.14, 0.08, 0.50)
	style.shadow_size = 4
	return style


func _set_badge(badge: Button, count: int) -> void:
	if badge == null or not is_instance_valid(badge):
		return
	badge.visible = count > 0
	badge.text = str(mini(count, 9)) + ("+" if count > 9 else "")


func _refresh_home_badges() -> void:
	_set_badge(_mail_badge, get_home_mail_badge_count())
	_set_badge(_login_badge, get_login_claimable_count())


func _open_live_scene(scene_path: String) -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_error("LiveOpsManager: scene tidak ditemukan: " + scene_path)
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		scene_path,
		1
	)
	if change_error != OK:
		push_error(
			"LiveOpsManager: gagal membuka scene. Error code: "
			+ str(change_error)
		)
