extends Control

## Jade Ascendant shared five-tab mobile navigation.
##
## Global Consistency Pass:
## - exact 20% hit target per tab remains unchanged
## - active/inactive states never move their layout geometry
## - no legacy bitmap frame dependency; chrome is resolution-independent
## - Indonesian/English labels use the existing localization system
## - notification badge remains manager-driven
## - reduced-effects preference disables ambient breathing animation
##
## Navigation authority stays in SceneTransitionManager.

@export_enum("Home", "Cultivation", "Hero", "Trials", "Pavilion") var active_tab: int = 0

const UiTokens = preload("res://scripts/ui/jade_ui_tokens.gd")

const HOME_SCENE: String = "res://scenes/ui/main_menu.tscn"
const PAVILION_SCENE: String = "res://scenes/ui/pavilion_screen.tscn"
const CULTIVATION_SCENE: String = "res://scenes/ui/cultivation_menu.tscn"
const EQUIPMENT_SCENE: String = "res://scenes/ui/equipment_screen.tscn"
const DAILY_QUEST_SCENE: String = "res://scenes/ui/daily_quest_screen.tscn"

const TAB_DATA: Array[Dictionary] = [
	{
		"label_key": "HOME",
		"scene": HOME_SCENE,
		"tooltip_key": "HOME"
	},
	{
		"label_key": "CULTIVATE",
		"scene": CULTIVATION_SCENE,
		"tooltip_key": "CULTIVATE"
	},
	{
		"label_key": "HERO",
		"scene": EQUIPMENT_SCENE,
		"tooltip_key": "HERO"
	},
	{
		"label_key": "TRIALS",
		"scene": DAILY_QUEST_SCENE,
		"tooltip_key": "TRIALS"
	},
	{
		"label_key": "PAVILION",
		"scene": PAVILION_SCENE,
		"tooltip_key": "PAVILION"
	}
]

var tab_buttons: Array[Button] = []
var tab_labels: Array[Label] = []

var trials_badge: Label = null
var hovered_tab: int = -1
var pressed_tab: int = -1

var badge_refresh_elapsed: float = 0.0
var motion_refresh_elapsed: float = 0.0
var motion_phase: float = 0.0
var last_trials_badge_count: int = -1

var shell_style: StyleBoxFlat = StyleBoxFlat.new()
var active_cell_style: StyleBoxFlat = StyleBoxFlat.new()
var hover_cell_style: StyleBoxFlat = StyleBoxFlat.new()
var pressed_cell_style: StyleBoxFlat = StyleBoxFlat.new()


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, UiTokens.NAV_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_shared_styles()
	_build_tabs()
	_refresh_notification_badge()

	call_deferred("_refresh_after_layout")
	set_process(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_label_rects()
		queue_redraw()
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_translated_labels()


func _process(delta: float) -> void:
	badge_refresh_elapsed += delta
	if badge_refresh_elapsed >= UiTokens.BADGE_REFRESH_INTERVAL:
		badge_refresh_elapsed = 0.0
		_refresh_notification_badge()

	if SettingsManager.reduced_effects:
		return

	motion_phase = fmod(motion_phase + delta, 1000.0)
	motion_refresh_elapsed += delta

	if motion_refresh_elapsed >= UiTokens.MOTION_REDRAW_INTERVAL:
		motion_refresh_elapsed = 0.0
		queue_redraw()


func _build_shared_styles() -> void:
	shell_style.bg_color = UiTokens.with_alpha(
		UiTokens.OBSIDIAN,
		0.965
	)
	shell_style.border_width_left = 1
	shell_style.border_width_top = 1
	shell_style.border_width_right = 1
	shell_style.border_width_bottom = 1
	shell_style.border_color = UiTokens.with_alpha(
		UiTokens.GOLD,
		0.58
	)
	shell_style.corner_radius_top_left = UiTokens.NAV_SHELL_RADIUS
	shell_style.corner_radius_top_right = UiTokens.NAV_SHELL_RADIUS
	shell_style.corner_radius_bottom_left = UiTokens.NAV_SHELL_RADIUS
	shell_style.corner_radius_bottom_right = UiTokens.NAV_SHELL_RADIUS
	shell_style.shadow_color = Color(0.0, 0.0, 0.0, 0.56)
	shell_style.shadow_size = 9

	active_cell_style.bg_color = Color(0.010, 0.095, 0.094, 0.95)
	active_cell_style.border_width_left = 1
	active_cell_style.border_width_top = 1
	active_cell_style.border_width_right = 1
	active_cell_style.border_width_bottom = 1
	active_cell_style.border_color = UiTokens.with_alpha(
		UiTokens.GOLD,
		0.82
	)
	active_cell_style.corner_radius_top_left = UiTokens.NAV_CELL_RADIUS
	active_cell_style.corner_radius_top_right = UiTokens.NAV_CELL_RADIUS
	active_cell_style.corner_radius_bottom_left = UiTokens.NAV_CELL_RADIUS
	active_cell_style.corner_radius_bottom_right = UiTokens.NAV_CELL_RADIUS
	active_cell_style.shadow_color = UiTokens.with_alpha(
		UiTokens.JADE,
		0.13
	)
	active_cell_style.shadow_size = 4

	hover_cell_style.bg_color = Color(0.015, 0.105, 0.100, 0.48)
	hover_cell_style.border_width_left = 1
	hover_cell_style.border_width_top = 1
	hover_cell_style.border_width_right = 1
	hover_cell_style.border_width_bottom = 1
	hover_cell_style.border_color = UiTokens.with_alpha(
		UiTokens.JADE,
		0.42
	)
	hover_cell_style.corner_radius_top_left = UiTokens.NAV_CELL_RADIUS
	hover_cell_style.corner_radius_top_right = UiTokens.NAV_CELL_RADIUS
	hover_cell_style.corner_radius_bottom_left = UiTokens.NAV_CELL_RADIUS
	hover_cell_style.corner_radius_bottom_right = UiTokens.NAV_CELL_RADIUS

	pressed_cell_style.bg_color = Color(0.003, 0.050, 0.057, 0.98)
	pressed_cell_style.border_width_left = 1
	pressed_cell_style.border_width_top = 1
	pressed_cell_style.border_width_right = 1
	pressed_cell_style.border_width_bottom = 1
	pressed_cell_style.border_color = UiTokens.with_alpha(
		UiTokens.JADE_BRIGHT,
		0.74
	)
	pressed_cell_style.corner_radius_top_left = UiTokens.NAV_CELL_RADIUS
	pressed_cell_style.corner_radius_top_right = UiTokens.NAV_CELL_RADIUS
	pressed_cell_style.corner_radius_bottom_left = UiTokens.NAV_CELL_RADIUS
	pressed_cell_style.corner_radius_bottom_right = UiTokens.NAV_CELL_RADIUS


func _build_tabs() -> void:
	for child_node: Node in get_children():
		remove_child(child_node)
		child_node.queue_free()

	tab_buttons.clear()
	tab_labels.clear()
	trials_badge = null
	hovered_tab = -1
	pressed_tab = -1

	var tab_count: int = TAB_DATA.size()

	for tab_index: int in range(tab_count):
		var tab_data: Dictionary = TAB_DATA[tab_index]
		var tab_button := Button.new()

		tab_button.name = (
			str(tab_data.get("label_key", "TAB"))
			.capitalize()
			.replace(" ", "")
			+ "Tab"
		)
		tab_button.flat = true
		tab_button.text = ""
		tab_button.focus_mode = Control.FOCUS_ALL
		tab_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab_button.disabled = str(tab_data.get("scene", "")).is_empty()

		_apply_empty_button_styles(tab_button)
		add_child(tab_button)

		var left_ratio: float = float(tab_index) / float(tab_count)
		var right_ratio: float = float(tab_index + 1) / float(tab_count)

		tab_button.anchor_left = left_ratio
		tab_button.anchor_top = 0.0
		tab_button.anchor_right = right_ratio
		tab_button.anchor_bottom = 1.0
		tab_button.offset_left = 0.0
		tab_button.offset_top = 0.0
		tab_button.offset_right = 0.0
		tab_button.offset_bottom = 0.0

		tab_button.pressed.connect(
			_on_tab_pressed.bind(tab_index)
		)
		tab_button.mouse_entered.connect(
			_on_tab_hover.bind(tab_index, true)
		)
		tab_button.mouse_exited.connect(
			_on_tab_hover.bind(tab_index, false)
		)
		tab_button.focus_entered.connect(
			_on_tab_hover.bind(tab_index, true)
		)
		tab_button.focus_exited.connect(
			_on_tab_hover.bind(tab_index, false)
		)
		tab_button.button_down.connect(
			_on_tab_button_down.bind(tab_index)
		)
		tab_button.button_up.connect(
			_on_tab_button_up.bind(tab_index)
		)

		tab_buttons.append(tab_button)

		var tab_label := Label.new()
		tab_label.name = "Label"
		tab_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tab_label.add_theme_font_size_override(
			"font_size",
			UiTokens.NAV_LABEL_FONT_SIZE
		)
		tab_label.add_theme_color_override(
			"font_shadow_color",
			Color(0.0, 0.0, 0.0, 0.88)
		)
		tab_label.add_theme_constant_override(
			"shadow_offset_y",
			2
		)
		tab_button.add_child(tab_label)

		tab_label.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		tab_labels.append(tab_label)

		if tab_index == 3:
			trials_badge = _create_trials_badge(tab_button)

	_refresh_translated_labels()
	_refresh_tab_label_colors()


func _refresh_translated_labels() -> void:
	var count: int = mini(
		tab_labels.size(),
		TAB_DATA.size()
	)

	for tab_index: int in range(count):
		var tab_data: Dictionary = TAB_DATA[tab_index]
		var label_key: String = str(
			tab_data.get("label_key", "TAB")
		)
		var tooltip_key: String = str(
			tab_data.get("tooltip_key", label_key)
		)

		tab_labels[tab_index].text = tr(label_key)

		if tab_index < tab_buttons.size():
			tab_buttons[tab_index].tooltip_text = tr(tooltip_key)

	_sync_label_rects()
	queue_redraw()


func _refresh_after_layout() -> void:
	_sync_label_rects()
	queue_redraw()


func _sync_label_rects() -> void:
	var count: int = mini(
		tab_buttons.size(),
		tab_labels.size()
	)

	for tab_index: int in range(count):
		var tab_button: Button = tab_buttons[tab_index]
		var tab_label: Label = tab_labels[tab_index]

		if tab_button == null or tab_label == null:
			continue

		tab_label.anchor_left = 0.0
		tab_label.anchor_top = 0.0
		tab_label.anchor_right = 0.0
		tab_label.anchor_bottom = 0.0
		tab_label.position = Vector2(
			0.0,
			UiTokens.NAV_LABEL_TOP
		)
		tab_label.size = Vector2(
			tab_button.size.x,
			maxf(
				tab_button.size.y
				- UiTokens.NAV_LABEL_TOP
				- UiTokens.NAV_LABEL_BOTTOM_MARGIN,
				1.0
			)
		)


func _apply_empty_button_styles(tab_button: Button) -> void:
	tab_button.add_theme_stylebox_override(
		"normal",
		StyleBoxEmpty.new()
	)
	tab_button.add_theme_stylebox_override(
		"hover",
		StyleBoxEmpty.new()
	)
	tab_button.add_theme_stylebox_override(
		"pressed",
		StyleBoxEmpty.new()
	)
	tab_button.add_theme_stylebox_override(
		"focus",
		StyleBoxEmpty.new()
	)
	tab_button.add_theme_stylebox_override(
		"disabled",
		StyleBoxEmpty.new()
	)


func _create_trials_badge(tab_button: Button) -> Label:
	var badge := Label.new()
	badge.name = "ClaimBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 7)
	badge.add_theme_color_override(
		"font_color",
		UiTokens.GOLD_BRIGHT
	)
	badge.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.80)
	)
	badge.add_theme_constant_override(
		"shadow_offset_y",
		1
	)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = UiTokens.with_alpha(
		UiTokens.CINNABAR,
		0.98
	)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = UiTokens.with_alpha(
		UiTokens.GOLD_BRIGHT,
		0.94
	)
	badge_style.corner_radius_top_left = 9
	badge_style.corner_radius_top_right = 9
	badge_style.corner_radius_bottom_left = 9
	badge_style.corner_radius_bottom_right = 9
	badge_style.shadow_color = UiTokens.with_alpha(
		UiTokens.CINNABAR,
		0.28
	)
	badge_style.shadow_size = 3

	badge.add_theme_stylebox_override(
		"normal",
		badge_style
	)

	tab_button.add_child(badge)

	badge.anchor_left = 0.5
	badge.anchor_top = 0.0
	badge.anchor_right = 0.5
	badge.anchor_bottom = 0.0
	badge.offset_left = 13.0
	badge.offset_top = 3.0
	badge.offset_right = 30.0
	badge.offset_bottom = 20.0

	return badge


func _refresh_notification_badge() -> void:
	if trials_badge == null:
		return

	var claimable_total: int = (
		AchievementManager.get_claimable_count()
		+ DailyQuestManager.get_claimable_count()
	)

	if claimable_total == last_trials_badge_count:
		return

	last_trials_badge_count = claimable_total
	trials_badge.visible = claimable_total > 0
	trials_badge.text = (
		"9+"
		if claimable_total > 9
		else str(claimable_total)
	)
	trials_badge.tooltip_text = (
		"%d Trials reward%s ready to claim"
		% [
			claimable_total,
			"" if claimable_total == 1 else "s"
		]
		if claimable_total > 0
		else ""
	)


func _on_tab_hover(
	tab_index: int,
	is_hovered_now: bool
) -> void:
	if is_hovered_now:
		hovered_tab = tab_index
	elif hovered_tab == tab_index:
		hovered_tab = -1

	_refresh_tab_label_colors()
	queue_redraw()


func _on_tab_button_down(tab_index: int) -> void:
	pressed_tab = tab_index
	queue_redraw()


func _on_tab_button_up(tab_index: int) -> void:
	if pressed_tab == tab_index:
		pressed_tab = -1
	queue_redraw()


func _refresh_tab_label_colors() -> void:
	for tab_index: int in range(tab_labels.size()):
		var tab_label: Label = tab_labels[tab_index]

		if tab_index == active_tab:
			tab_label.add_theme_color_override(
				"font_color",
				UiTokens.GOLD_BRIGHT
			)
		elif tab_index == hovered_tab:
			tab_label.add_theme_color_override(
				"font_color",
				UiTokens.JADE_BRIGHT
			)
		else:
			tab_label.add_theme_color_override(
				"font_color",
				Color(0.74, 0.81, 0.79, 0.96)
			)


func _on_tab_pressed(tab_index: int) -> void:
	pressed_tab = -1

	if SceneTransitionManager.is_transitioning:
		return

	if tab_index < 0 or tab_index >= TAB_DATA.size():
		return

	if tab_index == active_tab:
		return

	var tab_data: Dictionary = TAB_DATA[tab_index]
	var scene_path: String = str(
		tab_data.get("scene", "")
	)

	if scene_path.is_empty():
		return

	if not ResourceLoader.exists(scene_path):
		push_error(
			"HubNav: scene tab tidak ditemukan: "
			+ scene_path
		)
		return

	var transition_direction: int = (
		1
		if tab_index > active_tab
		else -1
	)

	var change_error: Error = (
		SceneTransitionManager.transition_menu_to(
			scene_path,
			transition_direction
		)
	)

	if change_error != OK:
		push_error(
			"HubNav: gagal membuka tab "
			+ str(tab_data.get("label_key", ""))
			+ ". Error code: "
			+ str(change_error)
		)


func _draw() -> void:
	var nav_width: float = size.x
	var nav_height: float = size.y

	if nav_width <= 0.0 or nav_height <= 0.0:
		return

	var shell_rect := Rect2(
		Vector2(2.0, 3.0),
		Vector2(
			maxf(nav_width - 4.0, 1.0),
			maxf(nav_height - 7.0, 1.0)
		)
	)

	draw_style_box(shell_style, shell_rect)

	_draw_shell_accents(
		nav_width,
		nav_height
	)

	var tab_count: int = tab_buttons.size()

	for tab_index: int in range(tab_count):
		var tab_button: Button = tab_buttons[tab_index]
		if tab_button == null:
			continue

		var left_edge: float = tab_button.position.x
		var top_edge: float = tab_button.position.y
		var tab_width: float = tab_button.size.x
		var tab_height: float = tab_button.size.y
		var bottom_edge: float = top_edge + tab_height

		if tab_index > 0:
			draw_line(
				Vector2(left_edge, top_edge + 18.0),
				Vector2(left_edge, bottom_edge - 15.0),
				UiTokens.with_alpha(
					UiTokens.JADE_SOFT,
					0.16
				),
				1.0,
				true
			)

		var cell_rect := Rect2(
			Vector2(left_edge + 5.0, top_edge + 7.0),
			Vector2(
				maxf(tab_width - 10.0, 1.0),
				maxf(tab_height - 14.0, 1.0)
			)
		)

		if tab_index == pressed_tab:
			draw_style_box(
				pressed_cell_style,
				cell_rect
			)
		elif tab_index == active_tab:
			draw_style_box(
				active_cell_style,
				cell_rect
			)
		elif tab_index == hovered_tab:
			draw_style_box(
				hover_cell_style,
				cell_rect
			)

		var icon_center := Vector2(
			left_edge + tab_width * 0.5,
			top_edge + UiTokens.NAV_ICON_CENTER_Y
		)

		if tab_index == active_tab:
			_draw_active_aura(icon_center)
			_draw_active_marker(
				left_edge,
				tab_width,
				bottom_edge
			)

		var icon_color: Color = _get_icon_color(tab_index)
		_draw_tab_icon(
			tab_index,
			icon_center,
			icon_color
		)


func _draw_shell_accents(
	nav_width: float,
	nav_height: float
) -> void:
	var top_y: float = 7.0

	draw_line(
		Vector2(18.0, top_y),
		Vector2(nav_width * 0.41, top_y),
		UiTokens.with_alpha(
			UiTokens.GOLD,
			0.38
		),
		1.0,
		true
	)
	draw_line(
		Vector2(nav_width * 0.59, top_y),
		Vector2(nav_width - 18.0, top_y),
		UiTokens.with_alpha(
			UiTokens.JADE,
			0.34
		),
		1.0,
		true
	)

	var center_x: float = nav_width * 0.5
	var center_diamond := PackedVector2Array([
		Vector2(center_x, top_y - 2.5),
		Vector2(center_x + 3.5, top_y + 1.0),
		Vector2(center_x, top_y + 4.5),
		Vector2(center_x - 3.5, top_y + 1.0)
	])
	draw_colored_polygon(
		center_diamond,
		UiTokens.with_alpha(
			UiTokens.GOLD_BRIGHT,
			0.72
		)
	)

	draw_line(
		Vector2(14.0, nav_height - 7.0),
		Vector2(nav_width - 14.0, nav_height - 7.0),
		UiTokens.with_alpha(
			UiTokens.JADE_SOFT,
			0.16
		),
		1.0,
		true
	)


func _draw_active_aura(icon_center: Vector2) -> void:
	var pulse_value: float = 0.0

	if not SettingsManager.reduced_effects:
		pulse_value = (
			sin(motion_phase * 2.35) * 0.5
			+ 0.5
		)

	var glow_radius: float = (
		UiTokens.NAV_ICON_RADIUS
		+ pulse_value * 1.8
	)
	var glow_alpha: float = (
		0.065
		+ pulse_value * 0.035
	)

	draw_circle(
		icon_center,
		glow_radius + 6.0,
		UiTokens.with_alpha(
			UiTokens.JADE,
			glow_alpha
		)
	)

	draw_arc(
		icon_center,
		glow_radius,
		0.0,
		TAU,
		32,
		UiTokens.with_alpha(
			UiTokens.GOLD,
			0.42
		),
		1.4,
		true
	)

	draw_arc(
		icon_center,
		glow_radius - 3.0,
		-PI * 0.75,
		PI * 0.18,
		22,
		UiTokens.with_alpha(
			UiTokens.JADE_BRIGHT,
			0.58
		),
		1.2,
		true
	)


func _draw_active_marker(
	left_edge: float,
	tab_width: float,
	bottom_edge: float
) -> void:
	var marker_y: float = bottom_edge - 7.5
	var center_x: float = left_edge + tab_width * 0.5

	draw_line(
		Vector2(left_edge + tab_width * 0.33, marker_y),
		Vector2(left_edge + tab_width * 0.67, marker_y),
		UiTokens.with_alpha(
			UiTokens.JADE_BRIGHT,
			0.90
		),
		2.0,
		true
	)

	var marker := PackedVector2Array([
		Vector2(center_x, marker_y - 3.0),
		Vector2(center_x + 3.0, marker_y),
		Vector2(center_x, marker_y + 3.0),
		Vector2(center_x - 3.0, marker_y)
	])
	draw_colored_polygon(
		marker,
		UiTokens.with_alpha(
			UiTokens.GOLD_BRIGHT,
			0.88
		)
	)


func _get_icon_color(tab_index: int) -> Color:
	if tab_index == pressed_tab:
		return UiTokens.JADE_BRIGHT

	if tab_index == active_tab:
		return UiTokens.GOLD_BRIGHT

	if tab_index == hovered_tab:
		return UiTokens.JADE_BRIGHT

	return UiTokens.with_alpha(
		UiTokens.TEXT_MUTED,
		0.92
	)


func _draw_tab_icon(
	tab_index: int,
	icon_center: Vector2,
	icon_color: Color
) -> void:
	if tab_index == active_tab:
		var shadow_color := Color(
			0.0,
			0.0,
			0.0,
			0.58
		)
		_draw_icon_shape(
			tab_index,
			icon_center + Vector2(1.2, 2.0),
			shadow_color
		)

	_draw_icon_shape(
		tab_index,
		icon_center,
		icon_color
	)


func _draw_icon_shape(
	tab_index: int,
	icon_center: Vector2,
	icon_color: Color
) -> void:
	match tab_index:
		0:
			_draw_journey_icon(icon_center, icon_color)
		1:
			_draw_cultivation_icon(icon_center, icon_color)
		2:
			_draw_hero_icon(icon_center, icon_color)
		3:
			_draw_trials_icon(icon_center, icon_color)
		_:
			_draw_pavilion_icon(icon_center, icon_color)


func _draw_journey_icon(
	icon_center: Vector2,
	icon_color: Color
) -> void:
	var outer_diamond := PackedVector2Array([
		icon_center + Vector2(0.0, -10.5),
		icon_center + Vector2(10.5, 0.0),
		icon_center + Vector2(0.0, 10.5),
		icon_center + Vector2(-10.5, 0.0)
	])

	draw_polyline(
		_close_polyline(outer_diamond),
		icon_color,
		1.9,
		true
	)

	draw_circle(
		icon_center,
		2.6,
		icon_color
	)

	draw_line(
		icon_center + Vector2(0.0, -6.4),
		icon_center + Vector2(0.0, 6.4),
		icon_color,
		1.35,
		true
	)

	draw_line(
		icon_center + Vector2(-5.0, 0.0),
		icon_center + Vector2(5.0, 0.0),
		UiTokens.with_alpha(
			icon_color,
			0.72
		),
		1.0,
		true
	)


func _draw_cultivation_icon(
	icon_center: Vector2,
	icon_color: Color
) -> void:
	draw_arc(
		icon_center,
		10.5,
		0.0,
		TAU,
		32,
		icon_color,
		1.9,
		true
	)

	draw_arc(
		icon_center + Vector2(0.0, -3.1),
		5.0,
		0.0,
		PI,
		16,
		icon_color,
		1.3,
		true
	)

	draw_arc(
		icon_center + Vector2(0.0, 3.1),
		5.0,
		PI,
		TAU,
		16,
		icon_color,
		1.3,
		true
	)

	draw_circle(
		icon_center + Vector2(0.0, -5.0),
		1.45,
		icon_color
	)
	draw_circle(
		icon_center + Vector2(0.0, 5.0),
		1.45,
		icon_color
	)


func _draw_hero_icon(
	icon_center: Vector2,
	icon_color: Color
) -> void:
	draw_line(
		icon_center + Vector2(-8.0, 9.0),
		icon_center + Vector2(8.0, -9.0),
		icon_color,
		2.1,
		true
	)
	draw_line(
		icon_center + Vector2(-8.0, -9.0),
		icon_center + Vector2(8.0, 9.0),
		icon_color,
		2.1,
		true
	)

	draw_line(
		icon_center + Vector2(-11.0, 5.5),
		icon_center + Vector2(-5.0, 11.0),
		icon_color,
		1.6,
		true
	)
	draw_line(
		icon_center + Vector2(11.0, 5.5),
		icon_center + Vector2(5.0, 11.0),
		icon_color,
		1.6,
		true
	)

	draw_circle(
		icon_center,
		2.0,
		UiTokens.with_alpha(
			UiTokens.GOLD,
			icon_color.a * 0.72
		)
	)


func _draw_trials_icon(
	icon_center: Vector2,
	icon_color: Color
) -> void:
	var paper_rect := Rect2(
		icon_center + Vector2(-8.5, -10.5),
		Vector2(17.0, 21.0)
	)

	var corners := PackedVector2Array([
		paper_rect.position,
		Vector2(paper_rect.end.x, paper_rect.position.y),
		paper_rect.end,
		Vector2(paper_rect.position.x, paper_rect.end.y),
		paper_rect.position
	])

	draw_polyline(
		corners,
		icon_color,
		1.9,
		true
	)

	draw_line(
		paper_rect.position + Vector2(4.0, 5.5),
		paper_rect.position + Vector2(13.0, 5.5),
		icon_color,
		1.2,
		true
	)
	draw_line(
		paper_rect.position + Vector2(4.0, 9.5),
		paper_rect.position + Vector2(10.8, 9.5),
		icon_color,
		1.2,
		true
	)

	draw_line(
		icon_center + Vector2(-4.0, 5.0),
		icon_center + Vector2(-1.1, 7.7),
		icon_color,
		1.7,
		true
	)
	draw_line(
		icon_center + Vector2(-1.1, 7.7),
		icon_center + Vector2(5.0, 1.8),
		icon_color,
		1.7,
		true
	)


func _draw_pavilion_icon(
	icon_center: Vector2,
	icon_color: Color
) -> void:
	draw_line(
		icon_center + Vector2(-12.0, -3.0),
		icon_center + Vector2(0.0, -10.5),
		icon_color,
		1.9,
		true
	)
	draw_line(
		icon_center + Vector2(0.0, -10.5),
		icon_center + Vector2(12.0, -3.0),
		icon_color,
		1.9,
		true
	)

	draw_line(
		icon_center + Vector2(-10.0, -2.0),
		icon_center + Vector2(10.0, -2.0),
		icon_color,
		1.6,
		true
	)

	draw_line(
		icon_center + Vector2(-7.0, -2.0),
		icon_center + Vector2(-7.0, 9.5),
		icon_color,
		1.6,
		true
	)
	draw_line(
		icon_center + Vector2(7.0, -2.0),
		icon_center + Vector2(7.0, 9.5),
		icon_color,
		1.6,
		true
	)

	draw_line(
		icon_center + Vector2(-10.0, 9.5),
		icon_center + Vector2(10.0, 9.5),
		icon_color,
		1.9,
		true
	)

	draw_circle(
		icon_center + Vector2(0.0, 2.8),
		1.7,
		UiTokens.with_alpha(
			UiTokens.GOLD,
			icon_color.a * 0.72
		)
	)


func _close_polyline(
	points: PackedVector2Array
) -> PackedVector2Array:
	var closed_points: PackedVector2Array = points.duplicate()

	if not closed_points.is_empty():
		closed_points.append(closed_points[0])

	return closed_points
