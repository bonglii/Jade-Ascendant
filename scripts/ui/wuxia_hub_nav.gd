extends Control

## Jade Ascendant shared five-tab mobile navigation.
## Commercial Icon Pass:
## - exact 20% hit target per tab remains unchanged
## - authored full-color icons replace procedural line drawings
## - active/inactive geometry never shifts
## - Trials claim badge remains manager-driven
## - navigation authority stays in SceneTransitionManager

@export_enum(
	"Home",
	"Cultivation",
	"Hero",
	"Trials",
	"Pavilion"
) var active_tab: int = 0

const UiTokens = preload("res://scripts/ui/jade_ui_tokens.gd")

const HOME_SCENE: String = "res://scenes/ui/main_menu.tscn"
const CULTIVATION_SCENE: String = "res://scenes/ui/cultivation_menu.tscn"
const EQUIPMENT_SCENE: String = "res://scenes/ui/equipment_screen.tscn"
const DAILY_QUEST_SCENE: String = "res://scenes/ui/daily_quest_screen.tscn"
const PAVILION_SCENE: String = "res://scenes/ui/pavilion_screen.tscn"

const ICON_HOME: Texture2D = preload(
	"res://assets/ui/icons/navigation/home.png"
)
const ICON_CULTIVATE: Texture2D = preload(
	"res://assets/ui/icons/navigation/cultivate.png"
)
const ICON_HERO: Texture2D = preload(
	"res://assets/ui/icons/navigation/hero.png"
)
const ICON_TRIALS: Texture2D = preload(
	"res://assets/ui/icons/navigation/trials.png"
)
const ICON_PAVILION: Texture2D = preload(
	"res://assets/ui/icons/navigation/pavilion.png"
)

const TAB_DATA: Array[Dictionary] = [
	{
		"label_key": "HOME",
		"scene": HOME_SCENE,
		"icon": ICON_HOME,
	},
	{
		"label_key": "CULTIVATE",
		"scene": CULTIVATION_SCENE,
		"icon": ICON_CULTIVATE,
	},
	{
		"label_key": "HERO",
		"scene": EQUIPMENT_SCENE,
		"icon": ICON_HERO,
	},
	{
		"label_key": "TRIALS",
		"scene": DAILY_QUEST_SCENE,
		"icon": ICON_TRIALS,
	},
	{
		"label_key": "PAVILION",
		"scene": PAVILION_SCENE,
		"icon": ICON_PAVILION,
	},
]

var tab_buttons: Array[Button] = []
var tab_labels: Array[Label] = []
var tab_icons: Array[TextureRect] = []

var trials_badge: Label = null
var hovered_tab: int = -1
var pressed_tab: int = -1

var badge_refresh_elapsed: float = 0.0
var motion_refresh_elapsed: float = 0.0
var motion_phase: float = 0.0
var last_trials_badge_count: int = -1

var shell_style := StyleBoxFlat.new()
var active_cell_style := StyleBoxFlat.new()
var hover_cell_style := StyleBoxFlat.new()
var pressed_cell_style := StyleBoxFlat.new()


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, UiTokens.NAV_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_shared_styles()
	_build_tabs()
	_refresh_notification_badge()
	set_process(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
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

	_configure_cell_style(
		active_cell_style,
		Color(0.010, 0.095, 0.094, 0.96),
		UiTokens.with_alpha(UiTokens.GOLD, 0.82),
		4
	)
	_configure_cell_style(
		hover_cell_style,
		Color(0.015, 0.105, 0.100, 0.54),
		UiTokens.with_alpha(UiTokens.JADE, 0.48),
		0
	)
	_configure_cell_style(
		pressed_cell_style,
		Color(0.003, 0.050, 0.057, 0.99),
		UiTokens.with_alpha(UiTokens.JADE_BRIGHT, 0.76),
		0
	)


func _configure_cell_style(
	style: StyleBoxFlat,
	background: Color,
	border: Color,
	shadow_size: int
) -> void:
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = UiTokens.NAV_CELL_RADIUS
	style.corner_radius_top_right = UiTokens.NAV_CELL_RADIUS
	style.corner_radius_bottom_left = UiTokens.NAV_CELL_RADIUS
	style.corner_radius_bottom_right = UiTokens.NAV_CELL_RADIUS
	style.shadow_color = UiTokens.with_alpha(UiTokens.JADE, 0.14)
	style.shadow_size = shadow_size


func _build_tabs() -> void:
	for child_node: Node in get_children():
		remove_child(child_node)
		child_node.queue_free()

	tab_buttons.clear()
	tab_labels.clear()
	tab_icons.clear()
	trials_badge = null
	hovered_tab = -1
	pressed_tab = -1

	var tab_count: int = TAB_DATA.size()
	for tab_index: int in range(tab_count):
		var tab_data: Dictionary = TAB_DATA[tab_index]
		var button := Button.new()
		button.name = (
			str(tab_data.get("label_key", "TAB"))
			.capitalize()
			.replace(" ", "")
			+ "Tab"
		)
		button.flat = true
		button.text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		button.keep_pressed_outside = false
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.disabled = str(tab_data.get("scene", "")).is_empty()
		_apply_empty_button_styles(button)
		add_child(button)

		button.anchor_left = float(tab_index) / float(tab_count)
		button.anchor_top = 0.0
		button.anchor_right = float(tab_index + 1) / float(tab_count)
		button.anchor_bottom = 1.0

		button.pressed.connect(_on_tab_pressed.bind(tab_index))
		button.mouse_entered.connect(_on_tab_hover.bind(tab_index, true))
		button.mouse_exited.connect(_on_tab_hover.bind(tab_index, false))
		button.focus_entered.connect(_on_tab_hover.bind(tab_index, true))
		button.focus_exited.connect(_on_tab_hover.bind(tab_index, false))
		button.button_down.connect(_on_tab_button_down.bind(tab_index))
		button.button_up.connect(_on_tab_button_up.bind(tab_index))
		tab_buttons.append(button)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = tab_data.get("icon") as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.anchor_left = 0.5
		icon.anchor_top = 0.0
		icon.anchor_right = 0.5
		icon.anchor_bottom = 0.0
		icon.offset_left = -23.0
		icon.offset_top = 3.0
		icon.offset_right = 23.0
		icon.offset_bottom = 49.0
		button.add_child(icon)
		tab_icons.append(icon)

		var label := Label.new()
		label.name = "Label"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.anchor_left = 0.0
		label.anchor_top = 0.0
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.offset_top = 49.0
		label.offset_bottom = -5.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(
			"font_size",
			UiTokens.NAV_LABEL_FONT_SIZE
		)
		label.add_theme_color_override(
			"font_shadow_color",
			Color(0.0, 0.0, 0.0, 0.90)
		)
		label.add_theme_constant_override("shadow_offset_y", 2)
		button.add_child(label)
		tab_labels.append(label)

		if tab_index == 3:
			trials_badge = _create_trials_badge(button)

	_refresh_translated_labels()
	_refresh_tab_visuals()


func _apply_empty_button_styles(button: Button) -> void:
	for state: String in [
		"normal",
		"hover",
		"pressed",
		"focus",
		"disabled",
	]:
		button.add_theme_stylebox_override(
			state,
			StyleBoxEmpty.new()
		)


func _refresh_translated_labels() -> void:
	for tab_index: int in range(
		mini(tab_labels.size(), TAB_DATA.size())
	):
		var key: String = str(
			TAB_DATA[tab_index].get("label_key", "TAB")
		)
		tab_labels[tab_index].text = tr(key)
		tab_buttons[tab_index].tooltip_text = tr(key)


func _create_trials_badge(button: Button) -> Label:
	var badge := Label.new()
	badge.name = "ClaimBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override(
		"font_color",
		UiTokens.GOLD_BRIGHT
	)
	badge.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.82)
	)
	badge.add_theme_constant_override("shadow_offset_y", 1)

	var style := StyleBoxFlat.new()
	style.bg_color = UiTokens.with_alpha(
		UiTokens.CINNABAR,
		0.99
	)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = UiTokens.GOLD_BRIGHT
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = UiTokens.with_alpha(
		UiTokens.CINNABAR,
		0.34
	)
	style.shadow_size = 3
	badge.add_theme_stylebox_override("normal", style)

	button.add_child(badge)
	badge.anchor_left = 0.5
	badge.anchor_top = 0.0
	badge.anchor_right = 0.5
	badge.anchor_bottom = 0.0
	badge.offset_left = 12.0
	badge.offset_top = 1.0
	badge.offset_right = 31.0
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
			"" if claimable_total == 1 else "s",
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
	_refresh_tab_visuals()
	queue_redraw()


func _on_tab_button_down(tab_index: int) -> void:
	pressed_tab = tab_index
	_refresh_tab_visuals()
	queue_redraw()


func _on_tab_button_up(tab_index: int) -> void:
	if pressed_tab == tab_index:
		pressed_tab = -1
	_refresh_tab_visuals()
	queue_redraw()


func _refresh_tab_visuals() -> void:
	for tab_index: int in range(tab_labels.size()):
		var label: Label = tab_labels[tab_index]
		var icon: TextureRect = tab_icons[tab_index]

		if tab_index == active_tab:
			label.add_theme_color_override(
				"font_color",
				UiTokens.GOLD_BRIGHT
			)
			icon.modulate = Color.WHITE
		elif tab_index == hovered_tab:
			label.add_theme_color_override(
				"font_color",
				UiTokens.JADE_BRIGHT
			)
			icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
		elif tab_index == pressed_tab:
			label.add_theme_color_override(
				"font_color",
				UiTokens.JADE_BRIGHT
			)
			icon.modulate = Color(0.84, 1.0, 0.94, 0.96)
		else:
			label.add_theme_color_override(
				"font_color",
				Color(0.74, 0.81, 0.79, 0.96)
			)
			icon.modulate = Color(0.68, 0.76, 0.74, 0.68)


func _on_tab_pressed(tab_index: int) -> void:
	pressed_tab = -1
	_refresh_tab_visuals()

	if SceneTransitionManager.is_transitioning:
		return
	if tab_index < 0 or tab_index >= TAB_DATA.size():
		return
	if tab_index == active_tab:
		return

	var scene_path: String = str(
		TAB_DATA[tab_index].get("scene", "")
	)
	if scene_path.is_empty():
		return
	if not ResourceLoader.exists(scene_path):
		push_error(
			"HubNav: scene tab tidak ditemukan: "
			+ scene_path
		)
		return

	var direction: int = 1 if tab_index > active_tab else -1
	var change_error: Error = (
		SceneTransitionManager.transition_menu_to(
			scene_path,
			direction
		)
	)
	if change_error != OK:
		push_error(
			"HubNav: gagal membuka tab "
			+ str(TAB_DATA[tab_index].get("label_key", ""))
			+ ". Error code: "
			+ str(change_error)
		)


func _draw() -> void:
	var nav_width: float = size.x
	var nav_height: float = size.y
	if nav_width <= 0.0 or nav_height <= 0.0:
		return

	draw_style_box(
		shell_style,
		Rect2(
			Vector2(2.0, 3.0),
			Vector2(
				maxf(nav_width - 4.0, 1.0),
				maxf(nav_height - 7.0, 1.0)
			)
		)
	)
	_draw_shell_accents(nav_width, nav_height)

	for tab_index: int in range(tab_buttons.size()):
		var button: Button = tab_buttons[tab_index]
		var left_edge: float = button.position.x
		var top_edge: float = button.position.y
		var tab_width: float = button.size.x
		var tab_height: float = button.size.y
		var bottom_edge: float = top_edge + tab_height

		if tab_index > 0:
			draw_line(
				Vector2(left_edge, top_edge + 18.0),
				Vector2(left_edge, bottom_edge - 15.0),
				UiTokens.with_alpha(
					UiTokens.JADE_SOFT,
					0.14
				),
				1.0,
				true
			)

		var cell_rect := Rect2(
			Vector2(left_edge + 5.0, top_edge + 6.0),
			Vector2(
				maxf(tab_width - 10.0, 1.0),
				maxf(tab_height - 12.0, 1.0)
			)
		)

		if tab_index == pressed_tab:
			draw_style_box(pressed_cell_style, cell_rect)
		elif tab_index == active_tab:
			draw_style_box(active_cell_style, cell_rect)
		elif tab_index == hovered_tab:
			draw_style_box(hover_cell_style, cell_rect)

		if tab_index == active_tab:
			var icon_center := Vector2(
				left_edge + tab_width * 0.5,
				top_edge + UiTokens.NAV_ICON_CENTER_Y
			)
			_draw_active_aura(icon_center)
			_draw_active_marker(
				left_edge,
				tab_width,
				bottom_edge
			)


func _draw_shell_accents(
	nav_width: float,
	nav_height: float
) -> void:
	var top_y := 7.0
	draw_line(
		Vector2(18.0, top_y),
		Vector2(nav_width * 0.41, top_y),
		UiTokens.with_alpha(UiTokens.GOLD, 0.36),
		1.0,
		true
	)
	draw_line(
		Vector2(nav_width * 0.59, top_y),
		Vector2(nav_width - 18.0, top_y),
		UiTokens.with_alpha(UiTokens.JADE, 0.32),
		1.0,
		true
	)
	draw_line(
		Vector2(14.0, nav_height - 7.0),
		Vector2(nav_width - 14.0, nav_height - 7.0),
		UiTokens.with_alpha(UiTokens.JADE_SOFT, 0.14),
		1.0,
		true
	)


func _draw_active_aura(icon_center: Vector2) -> void:
	var pulse := 0.0
	if not SettingsManager.reduced_effects:
		pulse = sin(motion_phase * 2.35) * 0.5 + 0.5
	var radius := UiTokens.NAV_ICON_RADIUS + 5.0 + pulse * 1.5
	draw_circle(
		icon_center,
		radius + 5.0,
		UiTokens.with_alpha(
			UiTokens.JADE,
			0.045 + pulse * 0.025
		)
	)
	draw_arc(
		icon_center,
		radius,
		0.0,
		TAU,
		32,
		UiTokens.with_alpha(UiTokens.GOLD, 0.34),
		1.25,
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
		Vector2(left_edge + tab_width * 0.34, marker_y),
		Vector2(left_edge + tab_width * 0.66, marker_y),
		UiTokens.with_alpha(
			UiTokens.JADE_BRIGHT,
			0.92
		),
		2.0,
		true
	)
	var marker := PackedVector2Array([
		Vector2(center_x, marker_y - 3.0),
		Vector2(center_x + 3.0, marker_y),
		Vector2(center_x, marker_y + 3.0),
		Vector2(center_x - 3.0, marker_y),
	])
	draw_colored_polygon(
		marker,
		UiTokens.with_alpha(
			UiTokens.GOLD_BRIGHT,
			0.90
		)
	)
