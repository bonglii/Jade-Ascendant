extends "res://scripts/world/verdant_qi_valley_decor.gd"

const ChapterThreeCatalog = preload("res://scripts/data/chapter_three_catalog.gd")

const VISUAL_SIGNATURES: Dictionary = {
	1: "cloudsea_star_gate",
	2: "astral_mirror_causeway",
	3: "constellation_sword_court",
	4: "ninefold_heaven_terrace",
	5: "celestial_star_palace",
}

@export_range(1, 5, 1) var stage_id: int = 1

var celestial_features: Array[Vector4] = []

func get_visual_signature() -> String:
	return str(VISUAL_SIGNATURES.get(stage_id, "nine_heavens_star_palace"))

func _build_distribution() -> void:
	super._build_distribution()
	celestial_features.clear()

	# Nine Heavens is open, architectural and airy. It deliberately removes most
	# inherited valley vegetation while keeping the proven single-CanvasItem path.
	grass_instances.resize(int(grass_instances.size() * (0.18 if stage_id <= 2 else 0.08)))
	spirit_plant_instances.resize(int(spirit_plant_instances.size() * 0.12))
	ruin_instances.resize(int(ruin_instances.size() * (0.52 if stage_id >= 3 else 0.30)))
	rock_instances.resize(int(rock_instances.size() * 0.62))
	stele_instances.resize(int(stele_instances.size() * 0.45))

	var rng := RandomNumberGenerator.new()
	rng.seed = 3092026 + stage_id * 307
	for signature: Vector4 in _get_signature_features():
		celestial_features.append(signature)
	for index: int in range(_get_scatter_count()):
		var point: Vector2 = _random_world_position(rng, 600.0)
		celestial_features.append(
			Vector4(point.x, point.y, rng.randf_range(0.72, 1.18), float((index + stage_id) % 3))
		)

func _get_signature_features() -> Array[Vector4]:
	match stage_id:
		1:
			return [
				Vector4(326.0, 90.0, 1.45, 0.0),
				Vector4(40.0, 430.0, 1.00, 2.0),
				Vector4(610.0, 410.0, 1.00, 2.0),
			]
		2:
			return [
				Vector4(95.0, 265.0, 1.08, 1.0),
				Vector4(555.0, 290.0, 1.08, 1.0),
				Vector4(326.0, 120.0, 1.22, 1.0),
			]
		3:
			return [
				Vector4(326.0, 120.0, 1.38, 2.0),
				Vector4(90.0, 460.0, 0.92, 2.0),
				Vector4(562.0, 460.0, 0.92, 2.0),
			]
		4:
			return [
				Vector4(326.0, 105.0, 1.48, 0.0),
				Vector4(120.0, 390.0, 0.95, 0.0),
				Vector4(532.0, 390.0, 0.95, 0.0),
			]
		5:
			return [
				Vector4(326.0, 52.0, 1.72, 0.0),
				Vector4(326.0, 420.0, 1.30, 2.0),
			]
		_:
			return []

func _get_scatter_count() -> int:
	match stage_id:
		1: return 28
		2: return 24
		3: return 20
		4: return 18
		5: return 14
		_: return 18

func _draw() -> void:
	var profile: Dictionary = ChapterThreeCatalog.get_stage(stage_id)
	var accent: Color = profile.get("accent", Color(0.68, 0.82, 0.98))
	var gold := Color(0.98, 0.84, 0.49, 1.0)

	for data: Vector4 in rock_instances:
		_draw_cloudstone(data, accent)
	for data: Vector4 in grass_instances:
		_draw_star_reeds(data, accent)
	for data: Vector4 in spirit_plant_instances:
		_draw_astral_bloom(data, accent, gold)
	for data: Vector4 in ruin_instances:
		_draw_palace_fragment(data, accent, gold)
	for data: Vector4 in celestial_features:
		_draw_celestial_feature(data, accent, gold)

	_draw_stage_floor_identity(accent, gold)

func _draw_cloudstone(data: Vector4, accent: Color) -> void:
	var center := Vector2(data.x, data.y)
	var radius: float = data.z
	var angle: float = data.w
	var base: Array[Vector2] = [
		Vector2(-0.92, -0.10), Vector2(-0.48, -0.62), Vector2(0.18, -0.72),
		Vector2(0.82, -0.30), Vector2(0.78, 0.36), Vector2(0.24, 0.68),
		Vector2(-0.52, 0.55),
	]
	var points := PackedVector2Array()
	for point: Vector2 in base:
		points.append(center + point.rotated(angle) * radius)
	draw_circle(center + Vector2(3.0, 7.0), radius * 0.70, Color(0.005, 0.008, 0.030, 0.34))
	draw_colored_polygon(points, Color(0.105, 0.125, 0.205, 0.94))
	draw_polyline(points, Color(accent, 0.30), 1.2, true)
	draw_line(center - Vector2(radius * 0.28, 0.0), center + Vector2(radius * 0.32, 0.0), Color(accent, 0.20), 1.2, true)

func _draw_star_reeds(data: Vector4, accent: Color) -> void:
	var center := Vector2(data.x, data.y)
	var length: float = data.z
	var angle: float = data.w
	for index: int in range(4):
		var direction := Vector2(float(index - 2) * 0.12, -1.0).rotated(angle * 0.16).normalized()
		draw_line(center, center + direction * length * (0.72 + 0.08 * index), Color(accent, 0.34), 1.15, true)
	draw_circle(center, length * 0.12, Color(accent, 0.18))

func _draw_astral_bloom(data: Vector4, accent: Color, gold: Color) -> void:
	var center := Vector2(data.x, data.y)
	var radius: float = data.z
	draw_circle(center, radius * 1.25, Color(accent, 0.035))
	for index: int in range(4):
		var petal := center + Vector2.RIGHT.rotated(PI * 0.5 * index) * radius * 0.46
		draw_circle(petal, radius * 0.22, Color(accent, 0.28))
	draw_circle(center, radius * 0.16, Color(gold, 0.52))

func _draw_palace_fragment(data: Vector4, accent: Color, gold: Color) -> void:
	var center := Vector2(data.x, data.y)
	var size_value: float = data.z
	var angle: float = data.w
	var tangent := Vector2.RIGHT.rotated(angle)
	var normal := tangent.orthogonal()
	var half_w := size_value * 0.66
	var half_h := size_value * 0.30
	var points := PackedVector2Array([
		center - tangent * half_w - normal * half_h,
		center + tangent * half_w - normal * half_h,
		center + tangent * half_w + normal * half_h,
		center - tangent * half_w + normal * half_h,
	])
	draw_colored_polygon(points, Color(0.12, 0.13, 0.22, 0.90))
	draw_polyline(points, Color(accent, 0.26), 1.2, true)
	draw_line(center - tangent * size_value * 0.28, center + tangent * size_value * 0.28, Color(gold, 0.24), 1.2, true)

func _draw_celestial_feature(data: Vector4, accent: Color, gold: Color) -> void:
	var center := Vector2(data.x, data.y)
	var scale_value: float = data.z
	var kind: int = int(data.w)
	match kind:
		0:
			_draw_star_gate(center, scale_value, accent, gold)
		1:
			_draw_astral_mirror(center, scale_value, accent, gold)
		_:
			_draw_constellation_array(center, scale_value, accent, gold)

func _draw_star_gate(center: Vector2, scale_value: float, accent: Color, gold: Color) -> void:
	var h := 76.0 * scale_value
	var w := 58.0 * scale_value
	draw_line(center + Vector2(-w, h), center + Vector2(-w, -h * 0.55), Color(accent, 0.48), 4.0, true)
	draw_line(center + Vector2(w, h), center + Vector2(w, -h * 0.55), Color(accent, 0.48), 4.0, true)
	draw_line(center + Vector2(-w * 1.15, -h * 0.52), center + Vector2(w * 1.15, -h * 0.52), Color(gold, 0.55), 4.0, true)
	draw_line(center + Vector2(-w * 0.82, -h * 0.72), center + Vector2(w * 0.82, -h * 0.72), Color(accent, 0.36), 2.0, true)
	draw_circle(center + Vector2(0.0, -h * 0.70), 4.5 * scale_value, Color(gold, 0.62))

func _draw_astral_mirror(center: Vector2, scale_value: float, accent: Color, gold: Color) -> void:
	var r := 36.0 * scale_value
	draw_circle(center, r, Color(accent, 0.06))
	draw_arc(center, r, 0.0, TAU, 32, Color(accent, 0.52), 2.0, true)
	draw_arc(center, r * 0.68, -0.6, PI + 0.6, 24, Color(gold, 0.50), 1.5, true)
	draw_line(center + Vector2(-r * 0.8, r * 0.48), center + Vector2(r * 0.72, -r * 0.42), Color(0.92, 0.88, 1.0, 0.20), 1.4, true)

func _draw_constellation_array(center: Vector2, scale_value: float, accent: Color, gold: Color) -> void:
	var r := 42.0 * scale_value
	draw_arc(center, r, 0.0, TAU, 36, Color(accent, 0.30), 1.5, true)
	var stars: Array[Vector2] = [
		Vector2(-0.58, -0.20), Vector2(-0.20, -0.58), Vector2(0.30, -0.34),
		Vector2(0.58, 0.10), Vector2(0.14, 0.52), Vector2(-0.42, 0.40),
	]
	for index: int in range(stars.size()):
		var point := center + stars[index] * r
		draw_circle(point, 2.4 * scale_value, Color(gold, 0.64))
		if index > 0:
			var previous := center + stars[index - 1] * r
			draw_line(previous, point, Color(accent, 0.24), 1.0, true)

func _draw_stage_floor_identity(accent: Color, gold: Color) -> void:
	var center := START_POSITION
	match stage_id:
		1:
			draw_arc(center, 124.0, PI, TAU, 36, Color(accent, 0.16), 2.0, true)
		2:
			for radius: float in [74.0, 116.0]:
				draw_arc(center, radius, 0.0, TAU, 40, Color(accent, 0.13), 1.4, true)
		3:
			_draw_constellation_array(center, 1.55, accent, gold)
		4:
			for step: int in range(5):
				var y := center.y + 120.0 - float(step) * 42.0
				var half_w := 138.0 - float(step) * 16.0
				draw_line(Vector2(center.x - half_w, y), Vector2(center.x + half_w, y), Color(gold, 0.13), 2.0, true)
		5:
			for index: int in range(9):
				var angle := TAU * float(index) / 9.0 - PI * 0.5
				var star := center + Vector2.RIGHT.rotated(angle) * 108.0
				draw_circle(star, 3.0, Color(gold, 0.22))
			draw_arc(center, 126.0, 0.0, TAU, 48, Color(accent, 0.15), 2.0, true)
