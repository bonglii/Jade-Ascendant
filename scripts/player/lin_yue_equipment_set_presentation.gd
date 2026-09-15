extends Node2D

## Equipment-set runtime resonance for Lin Yue.
##
## Presentation only:
## - reads EquipmentManager equipped state
## - no damage/stat/save/inventory mutations
## - no transient particle nodes; uses bounded CanvasItem drawing
## - starts at 2 matching pieces
## - Reduced Effects keeps a static readable version of the resonance
##
## Actual numerical set bonuses are intentionally deferred to the balance gate.

const EquipmentSetCatalog = preload("res://scripts/data/equipment_set_catalog.gd")

const GROUND_CENTER: Vector2 = Vector2(0.0, 30.0)
const BODY_CENTER: Vector2 = Vector2(0.0, 4.0)
const ELLIPSE_SEGMENTS: int = 44

var active_set_id: String = ""
var active_piece_count: int = 0
var elapsed: float = 0.0
var reduced_effects: bool = false


func _ready() -> void:
	_refresh_from_managers()

	if not EquipmentManager.equipment_changed.is_connected(_on_equipment_changed):
		EquipmentManager.equipment_changed.connect(_on_equipment_changed)

	if not SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if EquipmentManager.equipment_changed.is_connected(_on_equipment_changed):
		EquipmentManager.equipment_changed.disconnect(_on_equipment_changed)

	if SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.disconnect(_on_settings_changed)


func _on_equipment_changed(_slot_id: String, _item_id: String) -> void:
	_refresh_from_managers()


func _on_settings_changed() -> void:
	_refresh_from_managers()


func _refresh_from_managers() -> void:
	var equipped_item_ids: Array[String] = []
	for slot_id: String in EquipmentManager.get_slot_ids():
		var item_id: String = (
			EquipmentManager.get_runtime_equipped_item_id(slot_id)
		)
		if not item_id.is_empty():
			equipped_item_ids.append(item_id)

	var state: Dictionary = EquipmentSetCatalog.get_dominant_set_state(equipped_item_ids)
	active_set_id = str(state.get("set_id", ""))
	active_piece_count = int(state.get("piece_count", 0))
	reduced_effects = SettingsManager.reduced_effects

	var visible_resonance: bool = active_piece_count >= 2
	set_process(visible_resonance and not reduced_effects)
	queue_redraw()

	if visible_resonance:
		DebugLogger.system(
			"Equipment Set Runtime: %s %d/5 | Reduced Effects: %s"
			% [
				EquipmentSetCatalog.get_display_name(active_set_id),
				active_piece_count,
				str(reduced_effects)
			]
		)


func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, 1000.0)
	queue_redraw()


func _draw() -> void:
	if active_piece_count < 2 or active_set_id.is_empty():
		return

	var palette: Array[Color] = _get_palette(active_set_id)
	var primary: Color = palette[0]
	var secondary: Color = palette[1]

	_draw_body_presence(primary, secondary)
	_draw_ground_resonance(primary, secondary)

	if active_piece_count >= 3:
		_draw_piece_orbit(primary, secondary)

	if active_piece_count >= 4:
		_draw_rising_wisps(primary, secondary)

	if active_piece_count >= 5:
		_draw_full_resonance(primary, secondary)


func _get_palette(set_id: String) -> Array[Color]:
	match set_id:
		"mistbound_disciple":
			return [
				Color(0.30, 0.82, 1.00, 1.0),
				Color(0.70, 0.94, 1.00, 1.0)
			]
		"moon_seal":
			return [
				Color(0.47, 0.67, 1.00, 1.0),
				Color(0.78, 0.52, 1.00, 1.0)
			]
		"crimson_shadow":
			return [
				Color(1.00, 0.25, 0.24, 1.0),
				Color(0.92, 0.48, 0.18, 1.0)
			]
		"nine_heavens":
			return [
				Color(1.00, 0.76, 0.26, 1.0),
				Color(0.35, 0.88, 1.00, 1.0)
			]
		_:
			return [
				Color(0.22, 0.94, 0.70, 1.0),
				Color(0.56, 1.00, 0.83, 1.0)
			]


func _phase(speed: float = 1.0) -> float:
	if reduced_effects:
		return 0.0
	return elapsed * speed


func _pulse(minimum: float, maximum: float, speed: float) -> float:
	if reduced_effects:
		return (minimum + maximum) * 0.5
	var wave: float = (sin(_phase(speed)) + 1.0) * 0.5
	return lerpf(minimum, maximum, wave)


func _ellipse_points(
	center: Vector2,
	radius_x: float,
	radius_y: float,
	angle_offset: float = 0.0
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(ELLIPSE_SEGMENTS + 1):
		var angle: float = TAU * float(index) / float(ELLIPSE_SEGMENTS)
		var point := Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		).rotated(angle_offset)
		points.append(center + point)
	return points


func _draw_body_presence(primary: Color, secondary: Color) -> void:
	var strength: float = 0.75 + 0.08 * float(active_piece_count - 2)
	var breathing: float = _pulse(0.92, 1.05, 1.35)

	draw_circle(
		BODY_CENTER,
		46.0 * breathing,
		Color(primary.r, primary.g, primary.b, 0.025 * strength)
	)
	draw_circle(
		BODY_CENTER,
		30.0 * breathing,
		Color(secondary.r, secondary.g, secondary.b, 0.040 * strength)
	)


func _draw_ground_resonance(primary: Color, secondary: Color) -> void:
	var tier: float = float(active_piece_count - 1)
	var radius_x: float = 34.0 + tier * 4.0
	var radius_y: float = 13.0 + tier * 1.4
	var angle_offset: float = _phase(0.20)
	var alpha: float = _pulse(0.25, 0.42, 1.5)

	draw_polyline(
		_ellipse_points(GROUND_CENTER, radius_x, radius_y, angle_offset),
		Color(primary.r, primary.g, primary.b, alpha),
		2.25,
		true
	)
	draw_polyline(
		_ellipse_points(
			GROUND_CENTER,
			radius_x * 0.70,
			radius_y * 0.70,
			-angle_offset
		),
		Color(secondary.r, secondary.g, secondary.b, alpha * 0.68),
		1.4,
		true
	)

	# Five short marks make the equipment-piece relationship readable without UI text.
	for index in range(5):
		var angle: float = -PI * 0.86 + float(index) * PI * 0.43
		var lit: bool = index < active_piece_count
		var mark_color: Color = primary if lit else Color(primary.r, primary.g, primary.b, 0.11)
		var point := GROUND_CENTER + Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		)
		draw_circle(
			point,
			2.2 if lit else 1.4,
			Color(mark_color.r, mark_color.g, mark_color.b, 0.82 if lit else 0.11)
		)


func _draw_piece_orbit(primary: Color, secondary: Color) -> void:
	var orbit_angle: float = _phase(0.46)
	var orbit_radius: float = 31.0 + float(active_piece_count) * 1.8

	for index in range(active_piece_count):
		var angle: float = (
			orbit_angle
			+ float(index) * TAU / float(active_piece_count)
		)
		var squash: float = 0.42
		var point := BODY_CENTER + Vector2(
			cos(angle) * orbit_radius,
			sin(angle) * orbit_radius * squash
		)
		var color: Color = primary if index % 2 == 0 else secondary
		draw_circle(
			point,
			2.0 + 0.25 * float(active_piece_count - 3),
			Color(color.r, color.g, color.b, 0.72)
		)


func _draw_rising_wisps(primary: Color, secondary: Color) -> void:
	var wisp_count: int = 4 if active_piece_count == 4 else 6

	for index in range(wisp_count):
		var ratio: float = float(index) / float(wisp_count)
		var angle: float = ratio * TAU + _phase(0.34)
		var base := BODY_CENTER + Vector2(
			cos(angle) * 31.0,
			19.0 + sin(angle) * 7.0
		)
		var sway: float = sin(_phase(1.2) + float(index) * 1.7) * 4.0
		var height: float = 22.0 + float(index % 3) * 5.0
		var color: Color = primary if index % 2 == 0 else secondary

		var points := PackedVector2Array([
			base,
			base + Vector2(sway * 0.45, -height * 0.48),
			base + Vector2(sway, -height)
		])
		draw_polyline(
			points,
			Color(color.r, color.g, color.b, 0.25),
			1.6,
			true
		)


func _draw_full_resonance(primary: Color, secondary: Color) -> void:
	var orbit_rotation: float = _phase(0.30)
	var crown_center := BODY_CENTER + Vector2(0.0, -28.0)
	var radius: float = 12.0 * _pulse(0.92, 1.08, 1.8)

	var star := PackedVector2Array()
	for index in range(11):
		var angle: float = (
			-PI * 0.5
			+ float(index) * TAU / 10.0
			+ orbit_rotation
		)
		var point_radius: float = radius if index % 2 == 0 else radius * 0.45
		star.append(
			crown_center
			+ Vector2(cos(angle), sin(angle)) * point_radius
		)

	draw_polyline(
		star,
		Color(primary.r, primary.g, primary.b, 0.58),
		1.8,
		true
	)
	draw_circle(
		crown_center,
		3.0,
		Color(secondary.r, secondary.g, secondary.b, 0.62)
	)

	var full_alpha: float = _pulse(0.23, 0.40, 1.1)
	draw_arc(
		BODY_CENTER,
		48.0,
		orbit_rotation,
		orbit_rotation + PI * 1.35,
		36,
		Color(primary.r, primary.g, primary.b, full_alpha),
		2.0,
		true
	)
	draw_arc(
		BODY_CENTER,
		42.0,
		-orbit_rotation,
		-orbit_rotation + PI * 1.15,
		36,
		Color(secondary.r, secondary.g, secondary.b, full_alpha * 0.78),
		1.4,
		true
	)
