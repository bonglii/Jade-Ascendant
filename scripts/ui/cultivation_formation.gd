extends Control

## Cultivation Meridian Ritual Array — production presentation/selection layer.
## ProgressionManager state is supplied by CultivationMenu; this script owns no save/economy authority.

signal path_selected(path_id: String)

const UI_FONT: Font = preload("res://addons/admob/assets/fonts/NotoSansSC-Regular.otf")

const PATH_IDS: Array[String] = ["vitality", "sword_power", "swift_qi"]
const PATH_TITLES: Dictionary = {
	"vitality": "VITALITY",
	"sword_power": "SWORD POWER",
	"swift_qi": "SWIFT QI",
}
const PATH_SHORT: Dictionary = {
	"vitality": "BODY",
	"sword_power": "SWORD DAO",
	"swift_qi": "FLOWING QI",
}
const PATH_COLORS: Dictionary = {
	"vitality": Color(0.34, 0.98, 0.67, 1.0),
	"sword_power": Color(1.0, 0.76, 0.25, 1.0),
	"swift_qi": Color(0.28, 0.86, 1.0, 1.0),
}
const PATH_ICONS: Dictionary = {
	"vitality": preload("res://assets/ui/cultivation/meridian_vitality.png"),
	"sword_power": preload("res://assets/ui/cultivation/meridian_sword_power.png"),
	"swift_qi": preload("res://assets/ui/cultivation/meridian_swift_qi.png"),
}
const CORE_ICON: Texture2D = preload(
	"res://assets/ui/cultivation/meridian_dao_core.png"
)

const GOLD := Color(0.98, 0.79, 0.32, 1.0)
const JADE := Color(0.28, 0.93, 0.73, 1.0)
const OBSIDIAN := Color(0.001, 0.014, 0.022, 1.0)
const PRESS_SCROLL_CANCEL_DISTANCE: int = 6

var state: Dictionary = {}
var selected_path: String = "vitality"
var hovered_path: String = ""
var celebration_path: String = ""
var celebration_strength: float = 0.0
var motion_phase: float = 0.0
var redraw_elapsed: float = 0.0

var node_buttons: Dictionary = {}
var node_icons: Dictionary = {}
var node_titles: Dictionary = {}
var node_levels: Dictionary = {}
var node_kickers: Dictionary = {}
var core_icon: TextureRect = null
var core_title: Label = null
var core_level: Label = null
var core_kicker: Label = null
var press_scroll_y: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout_array)
	_build_nodes()
	set_process(true)
	call_deferred("_layout_array")
	queue_redraw()


func _process(delta: float) -> void:
	if not _reduced_effects_enabled():
		motion_phase = fmod(motion_phase + delta, 1000.0)
	if celebration_strength > 0.0:
		celebration_strength = maxf(celebration_strength - delta * 1.25, 0.0)
		if is_zero_approx(celebration_strength):
			celebration_path = ""
	redraw_elapsed += delta
	if redraw_elapsed >= 0.055:
		redraw_elapsed = 0.0
		queue_redraw()


func set_state(new_state: Dictionary, new_selected_path: String) -> void:
	state = new_state.duplicate(true)
	if PATH_IDS.has(new_selected_path):
		selected_path = new_selected_path
	_refresh_labels()
	_layout_array()
	queue_redraw()


func set_selected_path(path_id: String) -> void:
	if not PATH_IDS.has(path_id):
		return
	selected_path = path_id
	_refresh_labels()
	queue_redraw()


func celebrate(path_id: String) -> void:
	if not PATH_IDS.has(path_id):
		return
	celebration_path = path_id
	celebration_strength = 1.0
	queue_redraw()


func _build_nodes() -> void:
	core_icon = _icon(CORE_ICON)
	core_icon.name = "DaoCoreIcon"
	add_child(core_icon)

	core_kicker = _label("INNER SEA", 12, Color(0.53, 0.80, 0.74, 0.96))
	core_kicker.name = "CoreKicker"
	add_child(core_kicker)

	core_title = _label("DAO CORE", 20, Color(1.0, 0.88, 0.56, 1.0))
	core_title.name = "DaoCoreTitle"
	add_child(core_title)

	core_level = _label("4 / 30", 15, Color(0.48, 0.98, 0.84, 1.0))
	core_level.name = "DaoCoreLevel"
	add_child(core_level)

	for path_id: String in PATH_IDS:
		var button := Button.new()
		button.name = path_id.capitalize().replace("_", "") + "RitualHit"
		button.flat = true
		button.text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		button.keep_pressed_outside = false
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_empty_styles(button)
		button.button_down.connect(_on_path_button_down.bind(path_id))
		button.pressed.connect(_on_path_pressed.bind(path_id))
		button.mouse_entered.connect(_on_hover_changed.bind(path_id, true))
		button.mouse_exited.connect(_on_hover_changed.bind(path_id, false))
		button.focus_entered.connect(_on_hover_changed.bind(path_id, true))
		button.focus_exited.connect(_on_hover_changed.bind(path_id, false))
		add_child(button)
		node_buttons[path_id] = button

		var icon := _icon(PATH_ICONS[path_id] as Texture2D)
		icon.name = path_id.capitalize().replace("_", "") + "RitualIcon"
		add_child(icon)
		node_icons[path_id] = icon

		var kicker := _label(str(PATH_SHORT[path_id]), 13, Color(0.55, 0.70, 0.67, 0.98))
		add_child(kicker)
		node_kickers[path_id] = kicker

		var title := _label(str(PATH_TITLES[path_id]), 18, Color(0.86, 0.92, 0.90, 1.0))
		add_child(title)
		node_titles[path_id] = title

		var level := _label("LV 0 / 10", 14, Color(0.67, 0.77, 0.75, 0.96))
		add_child(level)
		node_levels[path_id] = level

	_refresh_labels()


func _icon(texture: Texture2D) -> TextureRect:
	var result := TextureRect.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return result


func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.text = value
	result.add_theme_font_override("font", UI_FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_constant_override("outline_size", 2)
	result.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	return result


func _apply_empty_styles(button: Button) -> void:
	for state_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())


func _refresh_labels() -> void:
	var total_level: int = 0
	var total_max: int = 0
	for path_id: String in PATH_IDS:
		var path_state: Dictionary = state.get(path_id, {})
		total_level += int(path_state.get("level", 0))
		total_max += int(path_state.get("max_level", 10))

	if core_level != null:
		core_level.text = "%d / %d" % [total_level, total_max]

	for path_id: String in PATH_IDS:
		var path_state: Dictionary = state.get(path_id, {})
		var level: int = int(path_state.get("level", 0))
		var max_level: int = maxi(int(path_state.get("max_level", 10)), 1)
		var maxed: bool = bool(path_state.get("maxed", false))
		var selected: bool = path_id == selected_path
		var accent: Color = PATH_COLORS[path_id]

		var kicker := node_kickers.get(path_id) as Label
		var title := node_titles.get(path_id) as Label
		var level_label := node_levels.get(path_id) as Label
		if kicker != null:
			kicker.text = "PERFECTED" if maxed else str(PATH_SHORT[path_id])
			kicker.add_theme_color_override(
				"font_color",
				Color(1.0, 0.84, 0.39, 1.0) if maxed else Color(0.59, 0.76, 0.72, 0.98)
			)
		if title != null:
			title.add_theme_color_override(
				"font_color",
				accent if selected else Color(0.82, 0.88, 0.86, 0.96)
			)
		if level_label != null:
			level_label.text = "LV %d / %d" % [level, max_level]
			level_label.add_theme_color_override(
				"font_color",
				Color(1.0, 0.89, 0.58, 1.0) if selected else Color(0.65, 0.77, 0.74, 0.96)
			)


func _layout_array() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return

	var width: float = size.x
	var height: float = size.y
	var basis: float = minf(width, height)
	var core_size: float = clampf(basis * 0.27, 112.0, 152.0)
	var node_size: float = clampf(basis * 0.21, 88.0, 122.0)
	var hit_size: float = node_size + 42.0
	var label_width: float = clampf(width * 0.33, 132.0, 196.0)
	var center := Vector2(width * 0.50, height * 0.50)

	if core_icon != null:
		core_icon.position = center - Vector2.ONE * core_size * 0.5
		core_icon.size = Vector2.ONE * core_size
	if core_kicker != null:
		core_kicker.position = Vector2(center.x - 82.0, center.y + core_size * 0.39)
		core_kicker.size = Vector2(164.0, 19.0)
	if core_title != null:
		core_title.position = Vector2(center.x - 92.0, center.y + core_size * 0.39 + 17.0)
		core_title.size = Vector2(184.0, 27.0)
	if core_level != null:
		core_level.position = Vector2(center.x - 76.0, center.y + core_size * 0.39 + 43.0)
		core_level.size = Vector2(152.0, 23.0)

	# Equal-radius triangular composition around the Dao Core. This keeps the
	# three meridians visually equidistant instead of one path feeling cramped
	# while another floats too far away.
	var orbit_radius: float = minf(width, height) * 0.36
	var centers: Dictionary = {
		"sword_power": center + Vector2.UP * orbit_radius,
		"vitality": center + Vector2.RIGHT.rotated(PI * 5.0 / 6.0) * orbit_radius,
		"swift_qi": center + Vector2.RIGHT.rotated(PI / 6.0) * orbit_radius,
	}

	for path_id: String in PATH_IDS:
		var node_center: Vector2 = centers[path_id]
		var button := node_buttons.get(path_id) as Button
		var icon := node_icons.get(path_id) as TextureRect
		var kicker := node_kickers.get(path_id) as Label
		var title := node_titles.get(path_id) as Label
		var level_label := node_levels.get(path_id) as Label
		if button == null or icon == null or kicker == null or title == null or level_label == null:
			continue

		button.position = node_center - Vector2.ONE * hit_size * 0.5
		button.size = Vector2.ONE * hit_size
		icon.position = node_center - Vector2.ONE * node_size * 0.5
		icon.size = Vector2.ONE * node_size

		var label_y := node_center.y + node_size * 0.43
		kicker.position = Vector2(node_center.x - label_width * 0.5, label_y)
		kicker.size = Vector2(label_width, 18.0)
		title.position = Vector2(node_center.x - label_width * 0.5, label_y + 16.0)
		title.size = Vector2(label_width, 24.0)
		level_label.position = Vector2(node_center.x - label_width * 0.5, label_y + 39.0)
		level_label.size = Vector2(label_width, 21.0)


func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return

	var center := Vector2(size.x * 0.50, size.y * 0.50)
	var radius: float = minf(size.x, size.y) * 0.31
	_draw_ritual_field(center, radius)
	_draw_channels(center)
	_draw_core(center, radius)
	_draw_path_nodes()


func _draw_ritual_field(center: Vector2, radius: float) -> void:
	var pulse: float = 0.0
	if not _reduced_effects_enabled():
		pulse = sin(motion_phase * 1.22) * 0.5 + 0.5

	for ring_index: int in range(5):
		var ring_radius := radius + float(ring_index) * 15.0
		var ring_color := JADE if ring_index % 2 == 0 else GOLD
		draw_arc(
			center,
			ring_radius,
			0.0,
			TAU,
			96,
			Color(ring_color.r, ring_color.g, ring_color.b, 0.055 + float(ring_index == 0) * 0.04),
			1.0 + float(ring_index == 0) * 0.4,
			true
		)

	for spoke_index: int in range(12):
		var angle := TAU * float(spoke_index) / 12.0 + motion_phase * 0.012
		var inner := center + Vector2.RIGHT.rotated(angle) * (radius - 16.0)
		var outer := center + Vector2.RIGHT.rotated(angle) * (radius + 35.0 + pulse * 2.0)
		draw_line(inner, outer, Color(0.39, 0.91, 0.79, 0.055), 1.0, true)

	var diamond_extent := radius * 0.62
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -diamond_extent),
		center + Vector2(diamond_extent, 0.0),
		center + Vector2(0.0, diamond_extent),
		center + Vector2(-diamond_extent, 0.0),
		center + Vector2(0.0, -diamond_extent),
	])
	draw_polyline(diamond, Color(GOLD.r, GOLD.g, GOLD.b, 0.11), 1.0, true)


func _draw_channels(center: Vector2) -> void:
	for path_id: String in PATH_IDS:
		var target := _node_center(path_id)
		var selected: bool = path_id == selected_path
		var path_state: Dictionary = state.get(path_id, {})
		var level: int = int(path_state.get("level", 0))
		var max_level: int = maxi(int(path_state.get("max_level", 10)), 1)
		var progress: float = clampf(float(level) / float(max_level), 0.0, 1.0)
		var accent: Color = PATH_COLORS[path_id]

		draw_line(center, target, Color(0.0, 0.0, 0.0, 0.62), 7.0, true)
		draw_line(
			center,
			target,
			Color(accent.r, accent.g, accent.b, 0.54 if selected else 0.16),
			3.0 if selected else 1.4,
			true
		)
		draw_line(
			center,
			center.lerp(target, progress),
			Color(GOLD.r, GOLD.g, GOLD.b, 0.92 if selected else 0.38),
			2.0 if selected else 1.0,
			true
		)

		if selected:
			for bead_index: int in range(3):
				var t := fmod(motion_phase * 0.23 + float(bead_index) * 0.29, 1.0)
				var bead := center.lerp(target, t)
				draw_circle(bead, 2.0, Color(accent.r, accent.g, accent.b, 0.90))


func _draw_core(center: Vector2, radius: float) -> void:
	var core_radius: float = clampf(radius * 0.43, 46.0, 69.0)
	var pulse: float = 0.0 if _reduced_effects_enabled() else (sin(motion_phase * 1.9) * 0.5 + 0.5)
	var celestial_white := Color(0.94, 1.0, 0.99, 1.0)

	# The Dao Core is the visual axis of the entire Cultivate screen. Use a
	# restrained white-celestial bloom so the yin-yang reads immediately even
	# against the brighter approved sanctuary artwork.
	for halo_index: int in range(7, 0, -1):
		var ratio := float(halo_index) / 7.0
		draw_circle(
			center,
			core_radius + ratio * 30.0,
			Color(celestial_white.r, celestial_white.g, celestial_white.b, 0.010 + ratio * 0.009)
		)

	draw_line(
		Vector2(center.x, center.y - core_radius - 58.0),
		Vector2(center.x, center.y + core_radius + 58.0),
		Color(0.96, 1.0, 0.98, 0.10 + pulse * 0.025),
		1.2,
		true
	)
	draw_arc(center, core_radius + 8.0, 0.0, TAU, 72, Color(0.96, 1.0, 0.98, 0.72), 1.7, true)
	draw_arc(
		center,
		core_radius + 16.0 + pulse * 1.8,
		-PI * 0.74,
		PI * 0.74,
		64,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.64),
		1.5,
		true
	)


func _draw_path_nodes() -> void:
	var basis: float = minf(size.x, size.y)
	var node_radius: float = clampf(basis * 0.095, 38.0, 58.0)
	for path_id: String in PATH_IDS:
		var center := _node_center(path_id)
		var path_state: Dictionary = state.get(path_id, {})
		var maxed: bool = bool(path_state.get("maxed", false))
		var affordable: bool = bool(path_state.get("affordable", false))
		var selected: bool = path_id == selected_path
		var hovered: bool = path_id == hovered_path
		var accent: Color = PATH_COLORS[path_id]

		if selected or hovered:
			draw_circle(center, node_radius + 17.0, Color(accent.r, accent.g, accent.b, 0.045))
			draw_arc(
				center,
				node_radius + 12.0,
				0.0,
				TAU,
				64,
				Color(accent.r, accent.g, accent.b, 0.92 if selected else 0.42),
				2.1 if selected else 1.2,
				true
			)

		if affordable and not maxed:
			var orbit_angle := 0.0 if _reduced_effects_enabled() else motion_phase * 0.76
			var orbit_point := center + Vector2.RIGHT.rotated(orbit_angle) * (node_radius + 16.0)
			draw_circle(orbit_point, 4.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.98))
			draw_circle(orbit_point, 8.5, Color(GOLD.r, GOLD.g, GOLD.b, 0.10))

		if maxed:
			draw_arc(center, node_radius + 7.0, 0.0, TAU, 48, Color(GOLD.r, GOLD.g, GOLD.b, 0.78), 1.5, true)

		if celebration_path == path_id and celebration_strength > 0.0:
			var burst_radius := node_radius + 15.0 + (1.0 - celebration_strength) * 46.0
			draw_arc(
				center,
				burst_radius,
				0.0,
				TAU,
				72,
				Color(accent.r, accent.g, accent.b, celebration_strength * 0.94),
				3.0,
				true
			)
			draw_arc(
				center,
				burst_radius + 10.0,
				0.0,
				TAU,
				72,
				Color(GOLD.r, GOLD.g, GOLD.b, celebration_strength * 0.62),
				1.3,
				true
			)


func _node_center(path_id: String) -> Vector2:
	var center := Vector2(size.x * 0.50, size.y * 0.50)
	var orbit_radius: float = minf(size.x, size.y) * 0.36
	match path_id:
		"sword_power":
			return center + Vector2.UP * orbit_radius
		"vitality":
			return center + Vector2.RIGHT.rotated(PI * 5.0 / 6.0) * orbit_radius
		"swift_qi":
			return center + Vector2.RIGHT.rotated(PI / 6.0) * orbit_radius
		_:
			return center


func _on_path_button_down(path_id: String) -> void:
	var scroll := _find_scroll_ancestor()
	press_scroll_y[path_id] = scroll.scroll_vertical if scroll != null else 0


func _on_path_pressed(path_id: String) -> void:
	if not PATH_IDS.has(path_id):
		return
	var scroll := _find_scroll_ancestor()
	if scroll != null:
		var start_scroll: int = int(press_scroll_y.get(path_id, scroll.scroll_vertical))
		if absi(scroll.scroll_vertical - start_scroll) >= PRESS_SCROLL_CANCEL_DISTANCE:
			return
	set_selected_path(path_id)
	path_selected.emit(path_id)


func _find_scroll_ancestor() -> ScrollContainer:
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor is ScrollContainer:
			return cursor as ScrollContainer
		cursor = cursor.get_parent()
	return null


func _on_hover_changed(path_id: String, hovering: bool) -> void:
	if hovering:
		hovered_path = path_id
	elif hovered_path == path_id:
		hovered_path = ""
	queue_redraw()


func _reduced_effects_enabled() -> bool:
	return is_instance_valid(SettingsManager) and bool(SettingsManager.reduced_effects)
