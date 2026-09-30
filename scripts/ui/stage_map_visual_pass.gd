extends Control

## Journey Map visual-only pass. Installed as a child of StageSelect, then moved
## behind the existing map nodes. JourneyManager, rewards and save ownership stay
## unchanged; existing stage buttons and their signal connections remain intact.
## The approved realm/stage artwork is reused, not copied or regenerated.

const JourneyArtCatalog = preload("res://scripts/ui/journey_art_catalog.gd")

const MAP_NODE_LIMIT: int = 12
const PATH_CURVE_STEPS: int = 22
const PEARL: Color = Color(0.97, 0.93, 0.82, 1.0)

var _chapter_id: int = 1
var _accent: Color = Color(0.28, 0.79, 0.64, 1.0)
var _stages: Array[Dictionary] = []
var _installed: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	# StageSelect builds its map synchronously in its own _ready(). Child _ready
	# runs before parent _ready; deferred installation sees the finished map.
	call_deferred("_install_into_stage_map")


func _install_into_stage_map() -> void:
	if _installed or not is_inside_tree():
		return
	var stage_screen: Control = get_parent() as Control
	if stage_screen == null:
		return
	var stage_map: ScrollContainer = stage_screen.get("map_scroll") as ScrollContainer
	if not is_instance_valid(stage_map):
		push_warning("StageMapVisualPass: StageSelect map has not been built.")
		return

	_chapter_id = int(stage_screen.get("chapter_id"))
	var profile_value: Variant = stage_screen.get("realm_profile")
	if profile_value is Dictionary:
		var profile: Dictionary = profile_value
		var accent_value: Variant = profile.get("accent")
		if accent_value is Color:
			_accent = accent_value

	var references_value: Variant = stage_screen.get("_stage_node_refs")
	if not (references_value is Dictionary):
		return
	var stage_references: Dictionary = references_value
	# The button's direct parent is the real journey canvas. This is more
	# reliable than get_child(0): ScrollContainer owns internal scrollbars.
	var canvas: Control = null
	for raw_refs: Variant in stage_references.values():
		if not (raw_refs is Dictionary):
			continue
		var entry: Dictionary = raw_refs
		var map_button: Button = entry.get("button") as Button
		if is_instance_valid(map_button):
			canvas = map_button.get_parent() as Control
			break
	if canvas == null or canvas.get_parent() != stage_map:
		push_warning("StageMapVisualPass: map canvas is missing.")
		return

	var artwork_value: Variant = stage_screen.get("stage_textures")
	var stage_artwork: Dictionary = {}
	if artwork_value is Dictionary:
		stage_artwork = artwork_value

	var stage_ids: Array = JourneyArtCatalog.get_presentation_stage_ids(
		_chapter_id, JourneyManager.get_stage_ids(_chapter_id)
	)
	for raw_stage_id: Variant in stage_ids:
		if _stages.size() >= MAP_NODE_LIMIT:
			break
		var stage_id: int = int(raw_stage_id)
		var stage_refs: Dictionary = stage_references.get(stage_id, {})
		var button: Button = stage_refs.get("button") as Button
		if not is_instance_valid(button):
			continue
		var stage_art: Texture2D = stage_artwork.get(stage_id) as Texture2D
		var status: String = "LOCKED"
		if JourneyManager.is_stage_unlocked(_chapter_id, stage_id):
			status = (
				"CLEARED"
				if JourneyManager.is_stage_cleared(_chapter_id, stage_id)
				else "CURRENT"
			)
		_stages.append({
			"id": stage_id,
			"point": button.position + button.size * 0.5,
			"art": stage_art,
			"status": status,
			"boss": bool(stage_refs.get("is_boss", false)),
		})

	if _stages.is_empty():
		return

	# Preserve the original Line2D colors and per-segment progression states.
	# Only the geometric shape changes: the zigzag becomes a flowing Qi trail.
	_round_existing_route(canvas)

	# Reparent a passive Control into the map itself so it scrolls exactly with
	# the nodes. move_child(0) keeps its artwork BEHIND all gameplay controls.
	reparent(canvas, false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.move_child(self, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_installed = true
	queue_redraw()


func _round_existing_route(canvas: Control) -> void:
	for child: Node in canvas.get_children():
		var route: Line2D = child as Line2D
		if route == null:
			continue
		var original: PackedVector2Array = route.points
		if original.size() == _stages.size() and original.size() > 2:
			var whole_route: PackedVector2Array = PackedVector2Array()
			for idx: int in range(original.size() - 1):
				var segment: PackedVector2Array = _bezier_segment(
					original[idx], original[idx + 1]
				)
				for segment_index: int in range(segment.size()):
					if idx > 0 and segment_index == 0:
						continue
					whole_route.append(segment[segment_index])
			route.points = whole_route
		elif original.size() == 2:
			route.points = _bezier_segment(original[0], original[1])
		else:
			continue
		route.joint_mode = Line2D.LINE_JOINT_ROUND
		route.begin_cap_mode = Line2D.LINE_CAP_ROUND
		route.end_cap_mode = Line2D.LINE_CAP_ROUND


func _bezier_segment(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var delta_y: float = finish.y - start.y
	var ctrl_a: Vector2 = start + Vector2(0.0, delta_y * 0.44)
	var ctrl_b: Vector2 = finish - Vector2(0.0, delta_y * 0.44)
	var curve: PackedVector2Array = PackedVector2Array()
	for step: int in range(PATH_CURVE_STEPS + 1):
		var t: float = float(step) / float(PATH_CURVE_STEPS)
		var inv: float = 1.0 - t
		curve.append(
			start * inv * inv * inv
			+ ctrl_a * 3.0 * inv * inv * t
			+ ctrl_b * 3.0 * inv * t * t
			+ finish * t * t * t
		)
	return curve


func _draw() -> void:
	if not _installed or _stages.is_empty() or size.x < 1.0:
		return
	_draw_floating_embers()
	for idx: int in range(_stages.size()):
		var stage_data: Dictionary = _stages[idx]
		var point: Vector2 = stage_data["point"]
		_draw_ink_wash(point, idx, bool(stage_data["boss"]))
		_draw_landmark(stage_data)
		_draw_seal_tracery(point, stage_data)
		if bool(stage_data["boss"]):
			_draw_boss_sanctum(point)


func _draw_floating_embers() -> void:
	# Deterministic, motionless motes: no _process() loop, particles, or shader.
	# They add atmospheric depth without draining the mobile rendering budget.
	for i: int in range(54):
		var px: float = 16.0 + fposmod(float(i * 139 + _chapter_id * 43), maxf(size.x - 32.0, 1.0))
		var py: float = 17.0 + fposmod(float(i * 211 + _chapter_id * 79), maxf(size.y - 34.0, 1.0))
		var radius: float = 0.9 if i % 3 else 1.6
		draw_circle(Vector2(px, py), radius, _ink(_accent, 0.11 if i % 4 else 0.23))


func _draw_ink_wash(point: Vector2, index: int, is_boss: bool) -> void:
	var wide: float = 165.0 if is_boss else 115.0
	var left: float = maxf(14.0, point.x - wide)
	var right: float = minf(size.x - 14.0, point.x + wide)
	var center: Vector2 = Vector2((left + right) * 0.5, point.y)
	var rim_color: Color = _ink(_accent, 0.13 if is_boss else 0.065)
	for layer: int in range(3):
		draw_arc(
			center,
			wide + float(layer) * 15.0,
			PI * 0.20,
			PI * 0.82,
			28,
			_ink(rim_color, rim_color.a / float(layer + 1)),
			1.6,
			true
		)
	if index % 2 == 0:
		draw_line(point + Vector2(-118.0, 75.0), point + Vector2(-20.0, 103.0), _ink(_accent, 0.12), 2.0, true)
	else:
		draw_line(point + Vector2(20.0, 103.0), point + Vector2(118.0, 75.0), _ink(_accent, 0.12), 2.0, true)


func _draw_landmark(stage_data: Dictionary) -> void:
	var art: Texture2D = stage_data["art"] as Texture2D
	if art == null:
		return
	var point: Vector2 = stage_data["point"]
	var is_boss: bool = bool(stage_data["boss"])
	var width_value: float = 282.0 if is_boss else 246.0
	var height_value: float = 138.0 if is_boss else 124.0
	var portrait := Rect2(
		Vector2(point.x - width_value * 0.5, point.y - height_value * 0.5),
		Vector2(width_value, height_value)
	)
	var locked: bool = str(stage_data["status"]) == "LOCKED"
	var opacity: float = 0.085 if locked else (0.27 if is_boss else 0.21)
	# This is a quiet stage-specific landscape imprint behind the actual seal,
	# not an interactive panel or a second UI card that obscures labels.
	_draw_cover_art(art, portrait, opacity)
	draw_rect(portrait.grow(4.0), _ink(_accent, 0.12 if locked else 0.27), false, 1.2, true)
	var corners: Color = _ink(PEARL, 0.11 if locked else 0.35)
	var corner: float = 15.0
	for x: float in [portrait.position.x, portrait.end.x]:
		var horizontal: float = 1.0 if x == portrait.position.x else -1.0
		for y: float in [portrait.position.y, portrait.end.y]:
			var vertical: float = 1.0 if y == portrait.position.y else -1.0
			draw_line(Vector2(x, y), Vector2(x + horizontal * corner, y), corners, 1.4, true)
			draw_line(Vector2(x, y), Vector2(x, y + vertical * corner), corners, 1.4, true)
	# Ink-stamp text intentionally not generated: all names/statuses stay in
	# StageSelect's existing readable, manager-backed plate Controls.


func _draw_cover_art(art: Texture2D, destination: Rect2, opacity: float) -> void:
	var source_size: Vector2 = art.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var target_aspect: float = destination.size.x / destination.size.y
	var source_aspect: float = source_size.x / source_size.y
	var source_region: Rect2 = Rect2(Vector2.ZERO, source_size)
	if source_aspect > target_aspect:
		source_region.size.x = source_size.y * target_aspect
		source_region.position.x = (source_size.x - source_region.size.x) * 0.5
	else:
		source_region.size.y = source_size.x / target_aspect
		source_region.position.y = (source_size.y - source_region.size.y) * 0.5
	draw_texture_rect_region(art, destination, source_region, Color(1.0, 1.0, 1.0, opacity))


func _draw_seal_tracery(point: Vector2, stage_data: Dictionary) -> void:
	var is_boss: bool = bool(stage_data["boss"])
	var locked: bool = str(stage_data["status"]) == "LOCKED"
	var radius: float = 111.0 if is_boss else 83.0
	var alpha: float = 0.11 if locked else (0.46 if is_boss else 0.30)
	draw_arc(point, radius, PI * 0.15, PI * 0.83, 32, _ink(_accent, alpha), 1.5, true)
	draw_arc(point, radius, PI * 1.16, PI * 1.83, 32, _ink(_accent, alpha), 1.5, true)
	var star_color: Color = _ink(PEARL, alpha * 0.75)
	for angle_index: int in range(8):
		var angle: float = float(angle_index) * TAU / 8.0
		var start: Vector2 = point + Vector2.from_angle(angle) * (radius - 4.0)
		var finish: Vector2 = point + Vector2.from_angle(angle) * (radius + 5.0)
		draw_line(start, finish, star_color, 1.5, true)


func _draw_boss_sanctum(point: Vector2) -> void:
	var crown_center: Vector2 = point
	match _chapter_id:
		1:
			_draw_leaf_array(crown_center)
		2:
			_draw_crimson_moon(crown_center)
		3:
			_draw_star_array(crown_center)
		_:
			_draw_arcane_circles(crown_center)


func _draw_leaf_array(center: Vector2) -> void:
	var jade: Color = _ink(_accent, 0.38)
	for i: int in range(5):
		var side: float = float(i - 2)
		var stem: Vector2 = center + Vector2(side * 24.0, -61.0)
		var tip: Vector2 = stem + Vector2(side * 8.0, -26.0)
		draw_line(stem, tip, jade, 2.0, true)
		draw_line(tip, tip + Vector2(-9.0, 14.0), jade, 1.1, true)
		draw_line(tip, tip + Vector2(9.0, 14.0), jade, 1.1, true)
	_draw_arcane_circles(center)


func _draw_crimson_moon(center: Vector2) -> void:
	var moon: Vector2 = center + Vector2(0.0, -69.0)
	draw_arc(moon, 21.0, -PI * 0.72, PI * 0.72, 36, _ink(_accent, 0.58), 2.8, true)
	draw_arc(moon + Vector2(7.0, 0.0), 20.0, -PI * 0.69, PI * 0.69, 36, _ink(PEARL, 0.27), 1.1, true)
	_draw_arcane_circles(center)


func _draw_star_array(center: Vector2) -> void:
	var star_color: Color = _ink(_accent, 0.52)
	var stars: PackedVector2Array = PackedVector2Array([
		center + Vector2(-55.0, -77.0),
		center + Vector2(-20.0, -47.0),
		center + Vector2(24.0, -90.0),
		center + Vector2(59.0, -45.0),
		center + Vector2(2.0, -31.0),
	])
	draw_polyline(stars, star_color, 1.7, true)
	for p: Vector2 in stars:
		draw_circle(p, 3.2, star_color)
	_draw_arcane_circles(center)


func _draw_arcane_circles(center: Vector2) -> void:
	for i: int in range(2):
		draw_arc(
			center,
			99.0 + float(i) * 12.0,
			PI * 1.16,
			PI * 1.84,
			42,
			_ink(_accent, 0.28 if i == 0 else 0.12),
			2.1,
			true
		)


func _ink(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
