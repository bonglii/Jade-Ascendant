extends Control

## Five-tab portrait hub navigation.
## Every tab owns an exact 20% horizontal slice of this Control.
## Icons, labels, active chrome, hover chrome and separators all use the
## same tab rect so they cannot drift out of horizontal alignment.

@export_enum("Home", "Cultivation", "Hero", "Trials", "Pavilion") var active_tab: int = 0

const HOME_SCENE: String = "res://scenes/ui/main_menu.tscn"
const PAVILION_SCENE: String = "res://scenes/ui/pavilion_screen.tscn"
const CULTIVATION_SCENE: String = "res://scenes/ui/cultivation_menu.tscn"
const EQUIPMENT_SCENE: String = "res://scenes/ui/equipment_screen.tscn"
const DAILY_QUEST_SCENE: String = "res://scenes/ui/daily_quest_screen.tscn"
const TAB_DATA: Array = [
	{"label": "HOME", "scene": HOME_SCENE},
	{"label": "CULTIVATE", "scene": CULTIVATION_SCENE},
	{"label": "HERO", "scene": EQUIPMENT_SCENE},
	{"label": "TRIALS", "scene": DAILY_QUEST_SCENE},
	{"label": "PAVILION", "scene": PAVILION_SCENE}
]

const LABEL_TOP: float = 43.0
const LABEL_BOTTOM_MARGIN: float = 4.0
const ICON_Y: float = 22.0
const NAV_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/wuxia/nav_frame.png")
const NAV_ACTIVE_TEXTURE: Texture2D = preload("res://assets/ui/wuxia/nav_active.png")

var tab_buttons: Array[Button] = []
var tab_labels: Array[Label] = []
var trials_badge: Label = null
var hovered_tab: int = -1
var badge_refresh_elapsed: float = 0.0
var last_trials_badge_count: int = -1
var nav_frame_style: StyleBoxTexture = StyleBoxTexture.new()
var nav_active_style: StyleBoxTexture = StyleBoxTexture.new()

func _ready() -> void:
	_configure_asset_styles()
	custom_minimum_size = Vector2(0.0, 82.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_tabs()
	_refresh_notification_badge()
	call_deferred("_refresh_after_layout")

func _configure_asset_styles() -> void:
	nav_frame_style.texture = NAV_FRAME_TEXTURE
	nav_frame_style.texture_margin_left = 34.0
	nav_frame_style.texture_margin_top = 18.0
	nav_frame_style.texture_margin_right = 34.0
	nav_frame_style.texture_margin_bottom = 18.0
	nav_frame_style.content_margin_left = 0.0
	nav_frame_style.content_margin_top = 0.0
	nav_frame_style.content_margin_right = 0.0
	nav_frame_style.content_margin_bottom = 0.0

	nav_active_style.texture = NAV_ACTIVE_TEXTURE
	nav_active_style.texture_margin_left = 20.0
	nav_active_style.texture_margin_top = 16.0
	nav_active_style.texture_margin_right = 20.0
	nav_active_style.texture_margin_bottom = 16.0
	nav_active_style.content_margin_left = 0.0
	nav_active_style.content_margin_top = 0.0
	nav_active_style.content_margin_right = 0.0
	nav_active_style.content_margin_bottom = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_label_rects()
		queue_redraw()

func _build_tabs() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	tab_buttons.clear()
	tab_labels.clear()
	trials_badge = null

	var tab_count: int = TAB_DATA.size()
	for index: int in range(tab_count):
		var data: Dictionary = TAB_DATA[index]
		var button: Button = Button.new()
		button.name = str(data.get("label", "Tab")).capitalize().replace(" ", "") + "Tab"
		button.flat = true
		button.text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.disabled = str(data.get("scene", "")).is_empty()
		_apply_empty_button_styles(button)
		add_child(button)

		var left_ratio: float = float(index) / float(tab_count)
		var right_ratio: float = float(index + 1) / float(tab_count)
		button.anchor_left = left_ratio
		button.anchor_top = 0.0
		button.anchor_right = right_ratio
		button.anchor_bottom = 1.0
		button.offset_left = 0.0
		button.offset_top = 0.0
		button.offset_right = 0.0
		button.offset_bottom = 0.0

		button.pressed.connect(_on_tab_pressed.bind(index))
		button.mouse_entered.connect(_on_tab_hover.bind(index, true))
		button.mouse_exited.connect(_on_tab_hover.bind(index, false))
		button.focus_entered.connect(_on_tab_hover.bind(index, true))
		button.focus_exited.connect(_on_tab_hover.bind(index, false))
		tab_buttons.append(button)

		var label: Label = Label.new()
		label.name = "Label"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = str(data.get("label", "TAB"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		button.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_top = LABEL_TOP
		label.offset_bottom = -LABEL_BOTTOM_MARGIN
		tab_labels.append(label)

		if index == 3:
			trials_badge = _create_trials_badge(button)

	_refresh_tab_label_colors()

func _refresh_after_layout() -> void:
	_sync_label_rects()
	queue_redraw()

func _sync_label_rects() -> void:
	var count: int = mini(tab_buttons.size(), tab_labels.size())
	for index: int in range(count):
		var button: Button = tab_buttons[index]
		var label: Label = tab_labels[index]
		if button == null or label == null:
			continue

		# Deliberately use explicit local coordinates instead of inherited
		# minimum-size offsets. The label center is therefore exactly
		# button.size.x * 0.5 on every resize/aspect ratio.
		label.anchor_left = 0.0
		label.anchor_top = 0.0
		label.anchor_right = 0.0
		label.anchor_bottom = 0.0
		label.position = Vector2(0.0, LABEL_TOP)
		label.size = Vector2(
			button.size.x,
			maxf(button.size.y - LABEL_TOP - LABEL_BOTTOM_MARGIN, 1.0)
		)

func _apply_empty_button_styles(button: Button) -> void:
	var empty_normal: StyleBoxEmpty = StyleBoxEmpty.new()
	var empty_hover: StyleBoxEmpty = StyleBoxEmpty.new()
	var empty_pressed: StyleBoxEmpty = StyleBoxEmpty.new()
	var empty_focus: StyleBoxEmpty = StyleBoxEmpty.new()
	var empty_disabled: StyleBoxEmpty = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_normal)
	button.add_theme_stylebox_override("hover", empty_hover)
	button.add_theme_stylebox_override("pressed", empty_pressed)
	button.add_theme_stylebox_override("focus", empty_focus)
	button.add_theme_stylebox_override("disabled", empty_disabled)

func _create_trials_badge(button: Button) -> Label:
	var badge: Label = Label.new()
	badge.name = "ClaimBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color", Color(1.0, 0.93, 0.70, 1.0))

	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	# Cinnabar-seal treatment: still universal notification red, but it belongs
	# to the jade/gold visual language instead of looking like a generic dot.
	badge_style.bg_color = Color(0.58, 0.055, 0.045, 0.98)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = Color(0.96, 0.74, 0.30, 0.98)
	badge_style.corner_radius_top_left = 9
	badge_style.corner_radius_top_right = 9
	badge_style.corner_radius_bottom_left = 9
	badge_style.corner_radius_bottom_right = 9
	badge.add_theme_stylebox_override("normal", badge_style)

	button.add_child(badge)
	# Anchor to the Trials icon instead of the outer corner of the whole tab.
	# This makes the badge read as an icon state, not a floating overlay.
	badge.anchor_left = 0.5
	badge.anchor_top = 0.0
	badge.anchor_right = 0.5
	badge.anchor_bottom = 0.0
	badge.offset_left = 8.0
	badge.offset_top = 3.0
	badge.offset_right = 26.0
	badge.offset_bottom = 21.0
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
	trials_badge.text = "9+" if claimable_total > 9 else str(claimable_total)
	trials_badge.tooltip_text = (
		"%d Trials reward%s ready to claim" % [
			claimable_total,
			"" if claimable_total == 1 else "s"
		]
		if claimable_total > 0
		else ""
	)

func _process(delta: float) -> void:
	badge_refresh_elapsed += delta
	if badge_refresh_elapsed < 0.25:
		return
	badge_refresh_elapsed = 0.0
	_refresh_notification_badge()

func _on_tab_hover(index: int, hovered: bool) -> void:
	if hovered:
		hovered_tab = index
	elif hovered_tab == index:
		hovered_tab = -1
	_refresh_tab_label_colors()
	queue_redraw()

func _refresh_tab_label_colors() -> void:
	for index: int in range(tab_labels.size()):
		var label: Label = tab_labels[index]
		if index == active_tab:
			label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.40, 1.0))
		elif index == hovered_tab:
			label.add_theme_color_override("font_color", Color(0.58, 0.96, 0.84, 1.0))
		else:
			label.add_theme_color_override("font_color", Color(0.60, 0.69, 0.68, 0.90))

func _on_tab_pressed(index: int) -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if index < 0 or index >= TAB_DATA.size():
		return
	if index == active_tab:
		return

	var data: Dictionary = TAB_DATA[index]
	var scene_path: String = str(data.get("scene", ""))
	if scene_path.is_empty():
		return
	if not ResourceLoader.exists(scene_path):
		push_error("HubNav: scene tab tidak ditemukan: " + scene_path)
		return

	var direction: int = 1 if index > active_tab else -1
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		scene_path,
		direction
	)
	if change_error != OK:
		push_error(
			"HubNav: gagal membuka tab "
			+ str(data.get("label", ""))
			+ ". Error code: "
			+ str(change_error)
		)

func _draw() -> void:
	var width: float = size.x
	var height: float = size.y
	if width <= 0.0 or height <= 0.0:
		return

	var body_rect: Rect2 = Rect2(Vector2(0.0, 0.0), Vector2(width, height))
	if NAV_FRAME_TEXTURE != null:
		draw_style_box(nav_frame_style, body_rect)
	draw_line(
		Vector2(10.0, 6.0),
		Vector2(width - 10.0, 6.0),
		Color(0.24, 0.88, 0.76, 0.24),
		1.0,
		true
	)

	var tab_count: int = tab_buttons.size()
	for index: int in range(tab_count):
		var button: Button = tab_buttons[index]
		if button == null:
			continue

		var left: float = button.position.x
		var top: float = button.position.y
		var button_width: float = button.size.x
		var button_height: float = button.size.y
		var bottom: float = top + button_height

		if index > 0:
			draw_line(
				Vector2(left, top + 14.0),
				Vector2(left, bottom - 10.0),
				Color(0.18, 0.58, 0.53, 0.13),
				1.0,
				true
			)

		if index == active_tab:
			var active_rect: Rect2 = Rect2(
				Vector2(left + 5.0, top + 6.0),
				Vector2(
					maxf(button_width - 10.0, 1.0),
					maxf(button_height - 12.0, 1.0)
				)
			)
			if NAV_ACTIVE_TEXTURE != null:
				draw_style_box(nav_active_style, active_rect)
			draw_line(
				Vector2(left + button_width * 0.28, bottom - 7.0),
				Vector2(left + button_width * 0.72, bottom - 7.0),
				Color(0.34, 0.96, 0.80, 0.92),
				2.0,
				true
			)
		elif index == hovered_tab:
			draw_rect(
				Rect2(
					Vector2(left + 5.0, top + 8.0),
					Vector2(button_width - 10.0, button_height - 14.0)
				),
				Color(0.08, 0.30, 0.27, 0.18),
				true
			)

		var icon_center: Vector2 = Vector2(
			left + button_width * 0.5,
			top + ICON_Y
		)
		var icon_color: Color = _get_icon_color(index)
		_draw_tab_icon(index, icon_center, icon_color)

func _get_icon_color(index: int) -> Color:
	if index == active_tab:
		return Color(1.0, 0.84, 0.40, 1.0)
	if index == hovered_tab:
		return Color(0.34, 0.96, 0.80, 1.0)
	return Color(0.58, 0.70, 0.68, 0.88)

func _draw_tab_icon(index: int, center: Vector2, color: Color) -> void:
	match index:
		0:
			_draw_journey_icon(center, color)
		1:
			_draw_cultivation_icon(center, color)
		2:
			_draw_hero_icon(center, color)
		3:
			_draw_trials_icon(center, color)
		_:
			_draw_pavilion_icon(center, color)

func _draw_journey_icon(center: Vector2, color: Color) -> void:
	var diamond: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -11.0),
		center + Vector2(11.0, 0.0),
		center + Vector2(0.0, 11.0),
		center + Vector2(-11.0, 0.0)
	])
	draw_polyline(_close_polyline(diamond), color, 2.0, true)
	draw_circle(center, 3.0, color)
	draw_line(center + Vector2(0.0, -7.0), center + Vector2(0.0, 7.0), color, 1.4, true)

func _draw_cultivation_icon(center: Vector2, color: Color) -> void:
	draw_arc(center, 11.0, 0.0, TAU, 32, color, 2.0, true)
	draw_arc(center + Vector2(0.0, -3.0), 5.0, 0.0, PI, 16, color, 1.4, true)
	draw_arc(center + Vector2(0.0, 3.0), 5.0, PI, TAU, 16, color, 1.4, true)
	draw_circle(center + Vector2(0.0, -5.0), 1.5, color)
	draw_circle(center + Vector2(0.0, 5.0), 1.5, color)

func _draw_hero_icon(center: Vector2, color: Color) -> void:
	draw_line(center + Vector2(-8.0, 9.0), center + Vector2(8.0, -9.0), color, 2.3, true)
	draw_line(center + Vector2(-8.0, -9.0), center + Vector2(8.0, 9.0), color, 2.3, true)
	draw_line(center + Vector2(-11.0, 5.5), center + Vector2(-5.0, 11.0), color, 1.8, true)
	draw_line(center + Vector2(11.0, 5.5), center + Vector2(5.0, 11.0), color, 1.8, true)

func _draw_trials_icon(center: Vector2, color: Color) -> void:
	var rect: Rect2 = Rect2(center + Vector2(-9.0, -11.0), Vector2(18.0, 22.0))
	draw_line(rect.position + Vector2(4.0, 6.0), rect.position + Vector2(14.0, 6.0), color, 1.4, true)
	draw_line(rect.position + Vector2(4.0, 10.0), rect.position + Vector2(11.0, 10.0), color, 1.4, true)
	draw_line(center + Vector2(-4.0, 5.0), center + Vector2(-1.0, 8.0), color, 1.8, true)
	draw_line(center + Vector2(-1.0, 8.0), center + Vector2(5.0, 2.0), color, 1.8, true)
	var corners: PackedVector2Array = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		rect.position
	])
	draw_polyline(corners, color, 2.0, true)

func _draw_pavilion_icon(center: Vector2, color: Color) -> void:
	draw_line(center + Vector2(-12.0, -3.0), center + Vector2(0.0, -11.0), color, 2.0, true)
	draw_line(center + Vector2(0.0, -11.0), center + Vector2(12.0, -3.0), color, 2.0, true)
	draw_line(center + Vector2(-10.0, -2.0), center + Vector2(10.0, -2.0), color, 1.8, true)
	draw_line(center + Vector2(-7.0, -2.0), center + Vector2(-7.0, 10.0), color, 1.8, true)
	draw_line(center + Vector2(7.0, -2.0), center + Vector2(7.0, 10.0), color, 1.8, true)
	draw_line(center + Vector2(-10.0, 10.0), center + Vector2(10.0, 10.0), color, 2.0, true)

func _close_polyline(points: PackedVector2Array) -> PackedVector2Array:
	var closed: PackedVector2Array = points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed
