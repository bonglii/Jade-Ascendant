extends Control

const LiveOpsUi = preload(
	"res://scripts/ui/liveops/live_ops_ui.gd"
)

const ICON_SEVEN_DAY: Texture2D = preload(
	"res://assets/ui/liveops/seven_day.png"
)
const ICON_DAILY: Texture2D = preload(
	"res://assets/ui/icons/actions/daily.png"
)
const ICON_PAVILION: Texture2D = preload(
	"res://assets/ui/icons/navigation/pavilion.png"
)

const ICON_EVENT_CENTER: Texture2D = preload(
	"res://assets/ui/liveops/event_center.png"
)

const DAILY_SCENE: String = "res://scenes/ui/daily_quest_screen.tscn"
const PAVILION_SCENE: String = "res://scenes/ui/pavilion_screen.tscn"
const NEW_PLAYER_SCENE: String = (
	"res://scenes/ui/new_player_event_screen.tscn"
)

var content: VBoxContainer
var live_ops: Node


func _ready() -> void:
	live_ops = get_node_or_null("/root/LiveOpsManager")
	if live_ops == null:
		push_error("EventCenterScreen: LiveOpsManager tidak tersedia.")
		return

	SceneTransitionManager.set_back_handler(_back)
	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("EVENT CENTER"),
		tr("Celestial Events"),
		tr(
			"Live activities and returning-player reasons without "
			+ "cluttering the sanctuary."
		),
		ICON_EVENT_CENTER
	)
	content = shell["content"] as VBoxContainer
	(shell["back_button"] as Button).pressed.connect(_back)
	_build_cards()


func _add_feature_icon(
	parent: Container,
	texture: Texture2D,
	size_value: float = 58.0
) -> void:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(size_value, size_value)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)



func _build_cards() -> void:
	var newcomer := LiveOpsUi.make_card(
		content,
		Color(0.96, 0.78, 0.34, 1.0)
	)
	_add_feature_icon(newcomer, ICON_SEVEN_DAY, 62.0)
	LiveOpsUi.add_label(
		newcomer,
		tr("NEW PLAYER"),
		11,
		Color(0.96, 0.78, 0.34, 1.0)
	)
	LiveOpsUi.add_label(
		newcomer,
		tr("Seven Days of Ascension"),
		20
	)
	var claimable: int = live_ops.get_login_claimable_count()
	var progress_text: String = tr("ACTIVE DAY %d / %d") % [
		live_ops.get_active_login_day_count(),
		live_ops.LOGIN_DAY_COUNT,
	]
	if live_ops.is_new_player_event_complete():
		progress_text += "  •  " + tr("COMPLETED")
	elif claimable > 0:
		progress_text += "  •  " + (
			tr("%d REWARD READY") % claimable
			if claimable == 1
			else tr("%d REWARDS READY") % claimable
		)
	LiveOpsUi.add_label(
		newcomer,
		progress_text,
		13,
		Color(0.78, 0.88, 0.80, 1.0)
	)
	LiveOpsUi.add_action_button(
		newcomer,
		tr("Open Seven Days"),
		func() -> void: _open(NEW_PLAYER_SCENE),
		true
	)

	var daily := LiveOpsUi.make_card(
		content,
		Color(0.32, 0.84, 0.74, 1.0)
	)
	_add_feature_icon(daily, ICON_DAILY, 58.0)
	LiveOpsUi.add_label(
		daily,
		tr("DAILY"),
		11,
		Color(0.32, 0.84, 0.74, 1.0)
	)
	LiveOpsUi.add_label(daily, tr("Daily Cultivation"), 20)
	LiveOpsUi.add_label(
		daily,
		tr(
			"Complete daily disciplines and settle available rewards."
		),
		13
	)
	LiveOpsUi.add_action_button(
		daily,
		tr("OPEN DAILY TRIALS"),
		func() -> void: _open(DAILY_SCENE),
		false
	)

	var patronage := LiveOpsUi.make_card(
		content,
		Color(0.42, 0.72, 0.94, 1.0)
	)
	_add_feature_icon(patronage, ICON_PAVILION, 58.0)
	LiveOpsUi.add_label(
		patronage,
		tr("OPTIONAL"),
		11,
		Color(0.42, 0.72, 0.94, 1.0)
	)
	LiveOpsUi.add_label(
		patronage,
		tr("Celestial Patronage"),
		20
	)
	LiveOpsUi.add_label(
		patronage,
		tr(
			"Optional rewarded ads remain inside the Pavilion and "
			+ "never block progression."
		),
		13
	)
	LiveOpsUi.add_action_button(
		patronage,
		tr("OPEN PAVILION"),
		func() -> void: _open(PAVILION_SCENE),
		false
	)


func _open(scene_path: String) -> void:
	if bool(get_meta("liveops_popup", false)) and scene_path == NEW_PLAYER_SCENE:
		var manager: Node = get_node_or_null("/root/LiveOpsManager")
		if manager != null and manager.has_method("open_live_popup"):
			manager.call("open_live_popup", scene_path)
			return
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		scene_path,
		1
	)
	if change_error != OK:
		push_error(
			"EventCenterScreen: gagal membuka scene. Error code: "
			+ str(change_error)
		)


func _back() -> void:
	LiveOpsUi.return_home(self)
