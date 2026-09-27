extends Control

## HOME PRODUCTION PRESENTER V1
## Approved Home LAB V10 promoted to production.
##
## Presentation/navigation only:
## - JourneyManager remains chapter/stage authority.
## - MainMenu keeps checkpoint/continue authority.
## - LiveOpsManager keeps live-event/reward authority.
## - PavilionManager keeps Meditation/Pavilion authority.
## - HubResourceBarManager owns the shared top wallet.
## - WuxiaHubNav owns the bottom navigation.

const MEDITATION_ICON: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/meditation_premium.png"
)
const EVENT_CENTER_ICON: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/event_center_premium.png"
)
const SEVEN_DAY_ICON: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/seven_day_premium.png"
)
const MAILBOX_ICON: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/mailbox_premium.png"
)
const TREASURY_ICON: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/treasury_premium.png"
)
const CLAIMABLE_BADGE: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/notification_claimable_premium.png"
)
const SETTINGS_ICON: Texture2D = preload(
	"res://assets/ui/icons/settings.svg"
)

const EVENT_CENTER_SCENE: String = "res://scenes/ui/event_center_screen.tscn"
const SEVEN_DAY_SCENE: String = "res://scenes/ui/new_player_event_screen.tscn"
const MAILBOX_SCENE: String = "res://scenes/ui/mailbox_screen.tscn"
const TREASURY_SCENE: String = "res://scenes/ui/celestial_treasury_screen.tscn"
const SETTINGS_SCENE: String = "res://scenes/ui/settings_screen.tscn"

const MOBILE_SCROLL_DEADZONE: int = 6
const GOLD := Color(0.95, 0.76, 0.34, 1.0)
const GOLD_BRIGHT := Color(1.0, 0.88, 0.52, 1.0)
const JADE := Color(0.31, 0.91, 0.76, 1.0)
const JADE_SOFT := Color(0.43, 0.97, 0.83, 1.0)
const TEXT := Color(0.94, 0.99, 0.97, 1.0)

var event_scroll: ScrollContainer = null
var event_press_scroll_y: Dictionary = {}
var journey_deck_shell: Control = null
var meditation_button: Button = null

var chapter_label: Label = null
var realm_title: Label = null
var progress_label: Label = null
var next_path_label: Label = null
var realm_progress: ProgressBar = null
var journey_button: Button = null
var continue_button: Button = null

var event_button: Button = null
var seven_day_button: Button = null
var mailbox_button: Button = null
var treasury_button: Button = null
var event_badge: TextureRect = null
var seven_day_badge: TextureRect = null
var mailbox_badge: TextureRect = null


func _ready() -> void:
	_hide_legacy_home_chrome()
	_build_readability_grounding()
	_build_identity()
	_build_top_right_settings()
	_build_event_rail()
	_build_journey_deck()
	_build_meditation()
	_connect_runtime_signals()
	_refresh_all()
	get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("_hide_legacy_liveops_docks")
	call_deferred("_configure_mobile_scroll")
	call_deferred("_position_meditation")


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)


func _main_menu() -> Node:
	return get_tree().current_scene


func _hide_legacy_home_chrome() -> void:
	var home_ui := get_parent()
	if home_ui == null:
		return
	for node_path in ["TopBar", "ActionGlass", "HomeActions"]:
		var legacy := home_ui.get_node_or_null(node_path) as Control
		if legacy != null:
			legacy.visible = false


func _hide_legacy_liveops_docks() -> void:
	var home_ui := get_parent()
	if home_ui == null:
		return
	for node_name in ["LiveOpsLeftDock", "LiveOpsRightDock"]:
		var legacy := home_ui.get_node_or_null(node_name) as Control
		if legacy != null:
			legacy.visible = false


func _on_tree_node_added(node: Node) -> void:
	if node == null:
		return
	if str(node.name) in ["LiveOpsLeftDock", "LiveOpsRightDock"]:
		if node.get_parent() == get_parent() and node is Control:
			(node as Control).visible = false


func _build_readability_grounding() -> void:
	var lower := ColorRect.new()
	lower.name = "HomeProductionLowerGlass"
	lower.anchor_left = 0.0
	lower.anchor_top = 0.56
	lower.anchor_right = 1.0
	lower.anchor_bottom = 1.0
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower.color = Color(0.0, 0.010, 0.018, 0.38)
	add_child(lower)
	move_child(lower, 0)


func _build_identity() -> void:
	var eyebrow := _label("JADE SANCTUARY", 13, JADE_SOFT)
	eyebrow.anchor_left = 0.04
	eyebrow.anchor_top = 0.0
	eyebrow.anchor_right = 0.96
	eyebrow.anchor_bottom = 0.0
	eyebrow.offset_top = 76.0
	eyebrow.offset_bottom = 101.0
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(eyebrow)

	var identity := Button.new()
	identity.name = "LinYueIdentityButton"
	identity.anchor_left = 0.19
	identity.anchor_top = 0.0
	identity.anchor_right = 0.81
	identity.anchor_bottom = 0.0
	identity.offset_top = 99.0
	identity.offset_bottom = 132.0
	identity.text = "LIN YUE  •  WANDERING CULTIVATOR"
	identity.flat = true
	identity.focus_mode = Control.FOCUS_NONE
	identity.mouse_filter = Control.MOUSE_FILTER_PASS
	identity.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	identity.keep_pressed_outside = false
	identity.add_theme_font_size_override("font_size", 18)
	identity.add_theme_color_override(
		"font_color",
		Color(0.985, 0.96, 0.84, 1.0)
	)
	identity.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.88, 0.52, 1.0)
	)
	identity.pressed.connect(_open_profile)
	add_child(identity)


func _build_top_right_settings() -> void:
	# Preserve the familiar Home Settings placement: upper-right, directly
	# below the shared resource wallet and above the LiveOps rail.
	var settings_button := Button.new()
	settings_button.name = "HomeSettingsButton"
	settings_button.anchor_left = 1.0
	settings_button.anchor_top = 0.0
	settings_button.anchor_right = 1.0
	settings_button.anchor_bottom = 0.0
	settings_button.offset_left = -66.0
	settings_button.offset_top = 80.0
	settings_button.offset_right = -14.0
	settings_button.offset_bottom = 132.0
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	settings_button.keep_pressed_outside = false
	settings_button.icon = SETTINGS_ICON
	settings_button.expand_icon = true
	settings_button.tooltip_text = "Settings"
	settings_button.add_theme_stylebox_override(
		"normal",
		_feature_style(
			Color(0.002, 0.025, 0.034, 0.86),
			Color(0.76, 0.82, 0.86, 0.46),
			8
		)
	)
	settings_button.add_theme_stylebox_override(
		"hover",
		_feature_style(
			Color(0.006, 0.060, 0.070, 0.96),
			Color(0.96, 0.78, 0.36, 0.90),
			12
		)
	)
	settings_button.add_theme_stylebox_override(
		"pressed",
		_feature_style(
			Color(0.002, 0.036, 0.044, 1.0),
			Color(0.43, 0.97, 0.83, 0.88),
			4
		)
	)
	settings_button.pressed.connect(
		_open_menu_scene.bind(SETTINGS_SCENE)
	)
	add_child(settings_button)


func _open_profile() -> void:
	var menu := _main_menu()
	if menu != null and menu.has_method("_open_profile_sheet"):
		menu.call("_open_profile_sheet")


func _build_event_rail() -> void:
	var rail_shell := PanelContainer.new()
	rail_shell.name = "PremiumLiveOpsRail"
	rail_shell.anchor_left = 1.0
	rail_shell.anchor_top = 0.0
	rail_shell.anchor_right = 1.0
	rail_shell.anchor_bottom = 0.0
	rail_shell.offset_left = -118.0
	rail_shell.offset_top = 154.0
	rail_shell.offset_right = -8.0
	rail_shell.offset_bottom = 582.0
	rail_shell.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.001, 0.018, 0.026, 0.62),
			Color(0.86, 0.67, 0.27, 0.28),
			16,
			10
		)
	)
	add_child(rail_shell)

	event_scroll = ScrollContainer.new()
	event_scroll.name = "EventRailScroll"
	event_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_scroll.offset_left = 6.0
	event_scroll.offset_top = 8.0
	event_scroll.offset_right = -6.0
	event_scroll.offset_bottom = -8.0
	event_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	event_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	event_scroll.scroll_deadzone = MOBILE_SCROLL_DEADZONE
	rail_shell.add_child(event_scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 11)
	event_scroll.add_child(box)

	var rail_title := _label("LIVE OPS", 12, GOLD_BRIGHT)
	rail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rail_title)

	event_button = _event_button(EVENT_CENTER_ICON, "EVENT", Color(1.0, 0.37, 0.26, 1.0))
	event_button.pressed.connect(_open_live_popup.bind(EVENT_CENTER_SCENE))
	box.add_child(event_button)
	event_badge = _add_notification_badge(event_button)

	seven_day_button = _event_button(SEVEN_DAY_ICON, "7-DAY", Color(1.0, 0.84, 0.50, 1.0))
	seven_day_button.pressed.connect(_open_live_popup.bind(SEVEN_DAY_SCENE))
	box.add_child(seven_day_button)
	seven_day_badge = _add_notification_badge(seven_day_button)

	mailbox_button = _event_button(MAILBOX_ICON, "MAIL", Color(0.48, 0.91, 1.0, 1.0))
	mailbox_button.pressed.connect(_open_live_popup.bind(MAILBOX_SCENE))
	box.add_child(mailbox_button)
	mailbox_badge = _add_notification_badge(mailbox_button)

	if OS.get_name() == "Android" or OS.is_debug_build():
		treasury_button = _event_button(
			TREASURY_ICON,
			"TREASURY",
			Color(1.0, 0.66, 0.25, 1.0)
		)
		treasury_button.pressed.connect(_open_live_popup.bind(TREASURY_SCENE))
		box.add_child(treasury_button)



func _event_button(
	icon_texture: Texture2D,
	label_text: String,
	accent: Color
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 96.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.keep_pressed_outside = false
	button.add_theme_stylebox_override(
		"normal",
		_feature_style(
			Color(accent.r * 0.07, accent.g * 0.07, accent.b * 0.07, 0.93),
			Color(accent.r, accent.g, accent.b, 0.72),
			10
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_feature_style(
			Color(accent.r * 0.11, accent.g * 0.11, accent.b * 0.11, 0.99),
			Color(accent.r, accent.g, accent.b, 1.0),
			17
		)
	)

	var icon := TextureRect.new()
	icon.anchor_left = 0.5
	icon.anchor_top = 0.0
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.0
	icon.offset_left = -33.0
	icon.offset_top = 4.0
	icon.offset_right = 33.0
	icon.offset_bottom = 70.0
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	var label := _label(label_text, 13, TEXT)
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 0.0
	label.offset_top = 72.0
	label.offset_bottom = 95.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

	button.button_down.connect(_on_event_button_down.bind(button))
	return button


func _on_event_button_down(button: Button) -> void:
	if event_scroll == null:
		return
	event_press_scroll_y[button.get_instance_id()] = event_scroll.scroll_vertical


func _event_scroll_changed(button: Button) -> bool:
	if event_scroll == null or button == null:
		return false
	var key := button.get_instance_id()
	var start_y := int(event_press_scroll_y.get(key, event_scroll.scroll_vertical))
	event_press_scroll_y.erase(key)
	return absi(event_scroll.scroll_vertical - start_y) >= MOBILE_SCROLL_DEADZONE


func _open_live_popup(scene_path: String) -> void:
	var sender := get_viewport().gui_get_focus_owner() as Button
	if sender != null and _event_scroll_changed(sender):
		return
	var live_ops := get_node_or_null("/root/LiveOpsManager")
	if live_ops != null and live_ops.has_method("open_live_popup"):
		live_ops.call("open_live_popup", scene_path)
		return
	_open_menu_scene(scene_path)


func _open_menu_scene(scene_path: String) -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return
	SceneTransitionManager.transition_menu_to(scene_path, 1)


func _build_journey_deck() -> void:
	journey_deck_shell = PanelContainer.new()
	journey_deck_shell.name = "PremiumJourneyDeck"
	journey_deck_shell.anchor_left = 0.055
	journey_deck_shell.anchor_top = 1.0
	journey_deck_shell.anchor_right = 0.945
	journey_deck_shell.anchor_bottom = 1.0
	journey_deck_shell.offset_top = -368.0
	journey_deck_shell.offset_bottom = -96.0
	journey_deck_shell.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.001, 0.016, 0.025, 0.90),
			Color(0.87, 0.69, 0.29, 0.58),
			19,
			14
		)
	)
	add_child(journey_deck_shell)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 13)
	journey_deck_shell.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	box.add_child(meta)
	chapter_label = _label("", 12, GOLD_BRIGHT)
	var chapter_pill := PanelContainer.new()
	chapter_pill.add_theme_stylebox_override(
		"panel",
		_pill_style(Color(0.13, 0.075, 0.008, 0.95), Color(GOLD.r, GOLD.g, GOLD.b, 0.55))
	)
	chapter_pill.add_child(chapter_label)
	meta.add_child(chapter_pill)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(spacer)

	progress_label = _label("", 12, JADE_SOFT)
	var progress_pill := PanelContainer.new()
	progress_pill.add_theme_stylebox_override(
		"panel",
		_pill_style(Color(0.008, 0.080, 0.072, 0.94), Color(JADE.r, JADE.g, JADE.b, 0.55))
	)
	progress_pill.add_child(progress_label)
	meta.add_child(progress_pill)

	realm_title = _label("", 26, TEXT)
	realm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(realm_title)

	next_path_label = _label("", 13, Color(0.80, 0.89, 0.85, 1.0))
	next_path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(next_path_label)

	realm_progress = ProgressBar.new()
	realm_progress.custom_minimum_size = Vector2(0.0, 11.0)
	realm_progress.show_percentage = false
	realm_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	realm_progress.add_theme_stylebox_override(
		"background",
		_meter_style(Color(0.0, 0.022, 0.028, 0.94), Color(0.25, 0.49, 0.45, 0.34))
	)
	realm_progress.add_theme_stylebox_override(
		"fill",
		_meter_style(Color(0.22, 0.84, 0.68, 0.98), Color(0.98, 0.80, 0.36, 0.88))
	)
	box.add_child(realm_progress)

	journey_button = Button.new()
	journey_button.custom_minimum_size = Vector2(0.0, 62.0)
	journey_button.text = "ENTER JOURNEY"
	journey_button.add_theme_font_size_override("font_size", 20)
	journey_button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.76, 1.0))
	journey_button.add_theme_stylebox_override(
		"normal",
		_feature_style(Color(0.014, 0.105, 0.086, 0.99), GOLD, 14)
	)
	journey_button.add_theme_stylebox_override(
		"hover",
		_feature_style(Color(0.022, 0.145, 0.116, 1.0), GOLD_BRIGHT, 18)
	)
	journey_button.mouse_filter = Control.MOUSE_FILTER_PASS
	journey_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	journey_button.keep_pressed_outside = false
	journey_button.pressed.connect(_call_main_menu.bind("_on_journey_pressed"))
	box.add_child(journey_button)

	continue_button = Button.new()
	continue_button.custom_minimum_size = Vector2(0.0, 50.0)
	continue_button.add_theme_font_size_override("font_size", 17)
	continue_button.add_theme_color_override("font_color", Color(0.86, 0.97, 1.0, 1.0))
	continue_button.add_theme_stylebox_override(
		"normal",
		_feature_style(Color(0.007, 0.060, 0.083, 0.96), Color(0.35, 0.79, 1.0, 0.72), 7)
	)
	continue_button.mouse_filter = Control.MOUSE_FILTER_PASS
	continue_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	continue_button.keep_pressed_outside = false
	continue_button.pressed.connect(_call_main_menu.bind("_on_continue_pressed"))
	box.add_child(continue_button)


func _call_main_menu(method_name: String) -> void:
	var menu := _main_menu()
	if menu != null and menu.has_method(method_name):
		menu.call(method_name)


func _build_meditation() -> void:
	meditation_button = Button.new()
	meditation_button.name = "MeditationFeature"
	meditation_button.text = ""
	meditation_button.mouse_filter = Control.MOUSE_FILTER_PASS
	meditation_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	meditation_button.keep_pressed_outside = false
	meditation_button.add_theme_stylebox_override(
		"normal",
		_feature_style(Color(0.002, 0.064, 0.070, 0.90), Color(0.56, 0.98, 0.83, 0.84), 20)
	)
	meditation_button.add_theme_stylebox_override(
		"hover",
		_feature_style(Color(0.008, 0.118, 0.112, 0.98), Color(0.76, 1.0, 0.92, 1.0), 26)
	)
	meditation_button.pressed.connect(_open_spirit_meditation)
	add_child(meditation_button)

	var icon := TextureRect.new()
	icon.anchor_left = 0.5
	icon.anchor_top = 0.0
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.0
	icon.offset_left = -48.0
	icon.offset_top = 8.0
	icon.offset_right = 48.0
	icon.offset_bottom = 110.0
	icon.texture = MEDITATION_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meditation_button.add_child(icon)

	var title := _label("MEDITATION", 15, TEXT)
	title.anchor_left = 0.0
	title.anchor_top = 0.0
	title.anchor_right = 1.0
	title.anchor_bottom = 0.0
	title.offset_top = 111.0
	title.offset_bottom = 134.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meditation_button.add_child(title)

	var state := _label("READY", 13, GOLD_BRIGHT)
	state.anchor_left = 0.0
	state.anchor_top = 0.0
	state.anchor_right = 1.0
	state.anchor_bottom = 0.0
	state.offset_top = 136.0
	state.offset_bottom = 157.0
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meditation_button.add_child(state)


func _open_spirit_meditation() -> void:
	var idle_manager := get_node_or_null("/root/IdleCultivationManager")
	if idle_manager == null:
		push_warning("HomeProductionPresenter: IdleCultivationManager unavailable.")
		return

	var idle_presenter := idle_manager.get_node_or_null("IdleCultivationPresenter")
	if idle_presenter == null or not idle_presenter.has_method("_open_popup"):
		push_warning("HomeProductionPresenter: IdleCultivationPresenter unavailable.")
		return

	idle_presenter.call("_open_popup")


func _position_meditation() -> void:
	await get_tree().process_frame
	if meditation_button == null or journey_deck_shell == null:
		return
	var button_size := Vector2(118.0, 162.0)
	var target_x := (
		journey_deck_shell.position.x
		+ journey_deck_shell.size.x
		- button_size.x
	)
	var target_y := journey_deck_shell.position.y - button_size.y - 12.0
	target_x = clampf(target_x, 0.0, maxf(size.x - button_size.x, 0.0))
	target_y = clampf(target_y, 132.0, maxf(size.y - button_size.y - 108.0, 132.0))
	meditation_button.position = Vector2(target_x, target_y)
	meditation_button.size = button_size


func _connect_runtime_signals() -> void:
	var live_ops := get_node_or_null("/root/LiveOpsManager")
	if live_ops != null and live_ops.has_signal("live_ops_changed"):
		if not live_ops.live_ops_changed.is_connected(_refresh_all):
			live_ops.live_ops_changed.connect(_refresh_all)


func _refresh_all() -> void:
	_refresh_journey()
	_refresh_liveops_badges()


func _refresh_journey() -> void:
	var chapter_id := int(JourneyManager.selected_chapter_id)
	var chapter: Dictionary = JourneyManager.get_chapter_data(chapter_id)
	var progress: Dictionary = JourneyManager.get_chapter_progress(chapter_id)
	var cleared := int(progress.get("cleared_stages", 0))
	var total := maxi(int(progress.get("total_stages", 5)), 1)

	chapter_label.text = "CHAPTER %02d" % chapter_id
	realm_title.text = str(chapter.get("display_name", "Jade Sanctuary")).to_upper()
	progress_label.text = "%d / %d COMPLETE" % [cleared, total]
	realm_progress.max_value = float(total)
	realm_progress.value = float(clampi(cleared, 0, total))

	var next_stage := clampi(cleared + 1, 1, total)
	next_path_label.text = "NEXT  •  STAGE %d-%d  •  YOUR PATH TO ASCENSION" % [
		chapter_id,
		next_stage,
	]

	var menu := _main_menu()
	var has_checkpoint := false
	if menu != null and menu.has_method("_has_checkpoint"):
		has_checkpoint = bool(menu.call("_has_checkpoint"))
	continue_button.visible = has_checkpoint
	continue_button.disabled = not has_checkpoint
	continue_button.text = "CONTINUE RUN"
	if has_checkpoint and menu != null and menu.has_method("_get_continue_button_text"):
		continue_button.text = str(menu.call("_get_continue_button_text"))

	var read_only := SaveManager.is_progress_read_only()
	journey_button.disabled = read_only
	if read_only:
		continue_button.disabled = true


func _refresh_liveops_badges() -> void:
	var live_ops := get_node_or_null("/root/LiveOpsManager")
	if live_ops == null:
		_set_badge(event_badge, false)
		_set_badge(seven_day_badge, false)
		_set_badge(mailbox_badge, false)
		return

	var login_ready := false
	var mail_ready := false
	if live_ops.has_method("get_login_claimable_count"):
		login_ready = int(live_ops.call("get_login_claimable_count")) > 0
	if live_ops.has_method("get_home_mail_badge_count"):
		mail_ready = int(live_ops.call("get_home_mail_badge_count")) > 0

	_set_badge(event_badge, login_ready or mail_ready)
	_set_badge(seven_day_badge, login_ready)
	_set_badge(mailbox_badge, mail_ready)


func _add_notification_badge(parent_control: Control) -> TextureRect:
	var badge := TextureRect.new()
	badge.anchor_left = 1.0
	badge.anchor_top = 0.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 0.0
	badge.offset_left = -31.0
	badge.offset_top = 2.0
	badge.offset_right = -3.0
	badge.offset_bottom = 30.0
	badge.texture = CLAIMABLE_BADGE
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_control.add_child(badge)
	return badge


func _set_badge(badge: TextureRect, visible_value: bool) -> void:
	if badge != null and is_instance_valid(badge):
		badge.visible = visible_value


func _configure_mobile_scroll() -> void:
	if event_scroll == null:
		return
	event_scroll.scroll_deadzone = MOBILE_SCROLL_DEADZONE
	event_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var mobile_display := OS.has_feature("android") or OS.has_feature("ios")
	event_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_SHOW_NEVER
		if mobile_display
		else ScrollContainer.SCROLL_MODE_AUTO
	)
	_configure_scroll_descendants(event_scroll)


func _configure_scroll_descendants(root: Node) -> void:
	for child: Node in root.get_children():
		if child is Control:
			var control := child as Control
			if control.mouse_filter == Control.MOUSE_FILTER_STOP:
				control.mouse_filter = Control.MOUSE_FILTER_PASS
		_configure_scroll_descendants(child)


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _panel_style(background: Color, border: Color, radius: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = shadow_size
	return style


func _feature_style(background: Color, border: Color, shadow_size: int) -> StyleBoxFlat:
	var style := _panel_style(background, border, 15, shadow_size)
	style.content_margin_left = 7.0
	style.content_margin_top = 7.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 7.0
	return style


func _pill_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, 9, 0)
	style.content_margin_left = 9.0
	style.content_margin_top = 3.0
	style.content_margin_right = 9.0
	style.content_margin_bottom = 3.0
	return style


func _meter_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style
