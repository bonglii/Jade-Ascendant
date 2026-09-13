extends "res://scripts/world/verdant_qi_valley_decor.gd"

const ChapterTwoCatalog = preload(
	"res://scripts/data/chapter_two_catalog.gd"
)

const VISUAL_SIGNATURES: Dictionary = {
	1: "moonlit_bloodwood",
	2: "cinnabar_veil_pass",
	3: "scarlet_ritual_court",
	4: "blood_moon_ascension_stair",
	5: "crimson_moon_sanctum",
}

@export_range(1, 5, 1) var stage_id: int = 1

var feature_instances: Array[Vector3] = []

func get_visual_signature() -> String:
	return str(
		VISUAL_SIGNATURES.get(
			stage_id,
			"crimson_moon_sect"
		)
	)

func _build_distribution() -> void:
	super._build_distribution()
	feature_instances.clear()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12092026 + stage_id * 211

	# Chapter 2 is drier, darker and more architectural than Verdant Qi Valley.
	# Keep only a controlled amount of inherited distribution data.
	match stage_id:
		1:
			grass_instances.resize(
				int(grass_instances.size() * 0.52)
			)
			spirit_plant_instances.resize(
				int(spirit_plant_instances.size() * 0.38)
			)
			ruin_instances.resize(
				int(ruin_instances.size() * 0.32)
			)
		2:
			grass_instances.resize(
				int(grass_instances.size() * 0.34)
			)
			spirit_plant_instances.resize(
				int(spirit_plant_instances.size() * 0.26)
			)
			ruin_instances.resize(
				int(ruin_instances.size() * 0.45)
			)
		3:
			grass_instances.resize(
				int(grass_instances.size() * 0.16)
			)
			spirit_plant_instances.resize(
				int(spirit_plant_instances.size() * 0.12)
			)
			ruin_instances.resize(
				int(ruin_instances.size() * 0.70)
			)
		4:
			grass_instances.resize(
				int(grass_instances.size() * 0.10)
			)
			spirit_plant_instances.resize(
				int(spirit_plant_instances.size() * 0.08)
			)
			ruin_instances.resize(
				int(ruin_instances.size() * 0.44)
			)
		5:
			grass_instances.resize(
				int(grass_instances.size() * 0.08)
			)
			spirit_plant_instances.resize(
				int(spirit_plant_instances.size() * 0.08)
			)
			ruin_instances.resize(
				int(ruin_instances.size() * 0.58)
			)

	for signature_data: Vector3 in _get_signature_landmarks():
		var point: Vector2 = (
			START_POSITION
			+ Vector2(
				signature_data.x,
				signature_data.y
			)
		)
		feature_instances.append(
			Vector3(
				point.x,
				point.y,
				signature_data.z
			)
		)

	var scatter_count: int = _get_scatter_count()
	for index: int in range(scatter_count):
		var point: Vector2 = _random_world_position(
			rng,
			580.0
		)
		feature_instances.append(
			Vector3(
				point.x,
				point.y,
				rng.randf_range(0.78, 1.20)
			)
		)

func _get_signature_landmarks() -> Array[Vector3]:
	match stage_id:
		1:
			return [
				Vector3(-260.0, -180.0, 1.30),
				Vector3(245.0, -150.0, 1.15),
				Vector3(-305.0, 190.0, 1.06),
				Vector3(295.0, 225.0, 1.24),
				Vector3(-110.0, -430.0, 0.92),
				Vector3(150.0, 430.0, 0.94),
			]
		2:
			return [
				Vector3(-255.0, -155.0, 1.12),
				Vector3(260.0, -145.0, 1.12),
				Vector3(-315.0, 235.0, 0.96),
				Vector3(305.0, 250.0, 0.96),
				Vector3(0.0, -410.0, 1.22),
			]
		3:
			return [
				Vector3(-290.0, -185.0, 1.00),
				Vector3(290.0, -185.0, 1.00),
				Vector3(-290.0, 215.0, 1.00),
				Vector3(290.0, 215.0, 1.00),
				Vector3(0.0, -425.0, 1.30),
			]
		4:
			return [
				Vector3(-235.0, -205.0, 1.12),
				Vector3(235.0, -205.0, 1.12),
				Vector3(-270.0, 160.0, 1.00),
				Vector3(270.0, 160.0, 1.00),
				Vector3(0.0, -450.0, 1.36),
			]
		5:
			return [
				Vector3(0.0, -490.0, 1.58),
				Vector3(0.0, 505.0, 1.28),
				Vector3(-330.0, -110.0, 0.86),
				Vector3(330.0, 110.0, 0.86),
			]
		_:
			return []

func _get_scatter_count() -> int:
	match stage_id:
		1:
			return 40
		2:
			return 32
		3:
			return 20
		4:
			return 18
		5:
			return 10
		_:
			return 20

func _draw() -> void:
	var profile: Dictionary = ChapterTwoCatalog.get_stage(
		stage_id
	)
	var accent: Color = profile.get(
		"accent",
		Color(0.82, 0.20, 0.29)
	)

	for data: Vector4 in rock_instances:
		_draw_crimson_rock(data, accent)

	for data: Vector4 in grass_instances:
		_draw_black_reeds(data, accent)

	for data: Vector4 in spirit_plant_instances:
		_draw_moon_bloom(data, accent)

	for data: Vector4 in ruin_instances:
		_draw_cinnabar_fragment(data, accent)

	_draw_stage_floor_identity(accent)

	for data: Vector3 in feature_instances:
		_draw_stage_motif(
			Vector2(data.x, data.y),
			data.z,
			accent
		)

func _draw_crimson_rock(
	data: Vector4,
	accent: Color
) -> void:
	var center: Vector2 = Vector2(data.x, data.y)
	var radius: float = data.z
	var rotation_angle: float = data.w
	var local_points: Array[Vector2] = [
		Vector2(-0.90, -0.12),
		Vector2(-0.48, -0.70),
		Vector2(0.20, -0.82),
		Vector2(0.80, -0.36),
		Vector2(0.86, 0.27),
		Vector2(0.30, 0.73),
		Vector2(-0.42, 0.60),
	]
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in local_points:
		points.append(
			center
			+ point.rotated(rotation_angle) * radius
		)

	draw_circle(
		center + Vector2(3.0, 7.0),
		radius * 0.70,
		Color(0.004, 0.004, 0.008, 0.42)
	)
	draw_colored_polygon(
		points,
		Color(0.075, 0.050, 0.062, 0.97)
	)
	draw_polyline(
		points,
		Color(accent, 0.20),
		1.20,
		true
	)
	draw_line(
		center + Vector2(-0.36, -0.16) * radius,
		center + Vector2(0.36, 0.12) * radius,
		Color(accent, 0.18),
		1.35,
		true
	)

func _draw_black_reeds(
	data: Vector4,
	accent: Color
) -> void:
	var center: Vector2 = Vector2(data.x, data.y)
	var length: float = data.z
	var rotation_angle: float = data.w
	for index: int in range(5):
		var offset: float = float(index - 2) * 0.16
		var direction: Vector2 = Vector2(
			offset,
			-1.0
		).rotated(rotation_angle * 0.18)
		var tip: Vector2 = (
			center
			+ direction.normalized()
			* length
			* (0.72 + 0.07 * float(index % 3))
		)
		draw_line(
			center,
			tip,
			Color(0.16, 0.08, 0.11, 0.58),
			1.25,
			true
		)
	draw_circle(
		center,
		length * 0.16,
		Color(accent, 0.10)
	)

func _draw_moon_bloom(
	data: Vector4,
	accent: Color
) -> void:
	var center: Vector2 = Vector2(data.x, data.y)
	var radius: float = data.z
	var rotation_angle: float = data.w
	draw_circle(
		center,
		radius * 1.20,
		Color(accent, 0.035)
	)
	for index: int in range(5):
		var angle: float = (
			rotation_angle
			+ TAU * float(index) / 5.0
		)
		var petal: Vector2 = (
			center
			+ Vector2.RIGHT.rotated(angle)
			* radius * 0.48
		)
		draw_circle(
			petal,
			radius * 0.25,
			Color(accent, 0.30)
		)
	draw_circle(
		center,
		radius * 0.20,
		Color(0.92, 0.67, 0.48, 0.38)
	)

func _draw_cinnabar_fragment(
	data: Vector4,
	accent: Color
) -> void:
	var center: Vector2 = Vector2(data.x, data.y)
	var size_value: float = data.z
	var rotation_angle: float = data.w
	var tangent: Vector2 = Vector2.RIGHT.rotated(
		rotation_angle
	)
	var normal: Vector2 = tangent.orthogonal()
	var half_w: float = size_value * 0.62
	var half_h: float = size_value * 0.34
	var points: PackedVector2Array = PackedVector2Array([
		center - tangent * half_w - normal * half_h,
		center + tangent * half_w - normal * half_h,
		center + tangent * half_w + normal * half_h,
		center - tangent * half_w + normal * half_h,
	])
	draw_colored_polygon(
		points,
		Color(0.105, 0.060, 0.070, 0.92)
	)
	draw_polyline(
		points,
		Color(accent, 0.28),
		1.30,
		true
	)
	draw_line(
		center - tangent * size_value * 0.26,
		center + tangent * size_value * 0.26,
		Color(0.92, 0.48, 0.30, 0.22),
		1.35,
		true
	)

func _draw_stage_floor_identity(
	accent: Color
) -> void:
	match stage_id:
		2:
			_draw_veil_lane(accent)
		3:
			_draw_ritual_court(accent)
		4:
			_draw_ascension_stair(accent)
		5:
			_draw_sanctum_avenue(accent)

func _draw_veil_lane(accent: Color) -> void:
	for side: int in [-1, 1]:
		var x: float = (
			START_POSITION.x
			+ float(side) * 185.0
		)
		draw_line(
			Vector2(x, START_POSITION.y - 520.0),
			Vector2(x, START_POSITION.y + 520.0),
			Color(accent, 0.14),
			3.0,
			true
		)
		for index: int in range(-2, 3):
			var y: float = START_POSITION.y + index * 205.0
			draw_line(
				Vector2(x - 26.0, y - 38.0),
				Vector2(x + 18.0, y + 34.0),
				Color(accent, 0.18),
				1.5,
				true
			)

func _draw_ritual_court(accent: Color) -> void:
	var court_rect: Rect2 = Rect2(
		START_POSITION - Vector2(250.0, 250.0),
		Vector2(500.0, 500.0)
	)
	draw_rect(
		court_rect,
		Color(0.12, 0.055, 0.045, 0.18),
		false,
		4.0
	)
	for index: int in range(3):
		var inset: float = 60.0 + index * 45.0
		draw_rect(
			Rect2(
				START_POSITION - Vector2(inset, inset),
				Vector2(inset * 2.0, inset * 2.0)
			),
			Color(accent, 0.10 + 0.025 * index),
			false,
			1.5
		)

func _draw_ascension_stair(accent: Color) -> void:
	for index: int in range(-5, 8):
		var y: float = START_POSITION.y + index * 92.0
		var width: float = 205.0 - absf(float(index)) * 3.0
		draw_rect(
			Rect2(
				START_POSITION.x - width * 0.5,
				y,
				width,
				64.0
			),
			Color(0.10, 0.055, 0.085, 0.30)
		)
		draw_line(
			Vector2(START_POSITION.x - width * 0.5, y),
			Vector2(START_POSITION.x + width * 0.5, y),
			Color(accent, 0.14),
			1.7,
			true
		)

func _draw_sanctum_avenue(accent: Color) -> void:
	for index: int in range(-10, 16):
		var y: float = START_POSITION.y + index * 112.0
		draw_rect(
			Rect2(
				START_POSITION.x - 108.0,
				y,
				216.0,
				96.0
			),
			Color(0.105, 0.050, 0.060, 0.34)
		)
		draw_line(
			Vector2(START_POSITION.x - 115.0, y),
			Vector2(START_POSITION.x - 115.0, y + 96.0),
			Color(accent, 0.16),
			1.8,
			true
		)
		draw_line(
			Vector2(START_POSITION.x + 115.0, y),
			Vector2(START_POSITION.x + 115.0, y + 96.0),
			Color(accent, 0.16),
			1.8,
			true
		)

func _draw_stage_motif(
	center: Vector2,
	scale_value: float,
	accent: Color
) -> void:
	match stage_id:
		1:
			_draw_bloodwood(center, scale_value, accent)
		2:
			_draw_veil_pillar(center, scale_value, accent)
		3:
			_draw_ritual_pillar(center, scale_value, accent)
		4:
			_draw_ascent_pillar(center, scale_value, accent)
		5:
			_draw_sanctum_gate(center, scale_value, accent)

func _draw_bloodwood(
	center: Vector2,
	scale_value: float,
	accent: Color
) -> void:
	var s: float = scale_value
	var trunk: Color = Color(0.13, 0.055, 0.070, 0.94)
	draw_line(
		center,
		center + Vector2(0.0, -92.0 * s),
		trunk,
		13.0 * s,
		true
	)
	for side: int in [-1, 1]:
		draw_line(
			center + Vector2(0.0, -48.0 * s),
			center + Vector2(
				42.0 * float(side) * s,
				-83.0 * s
			),
			trunk,
			7.0 * s,
			true
		)
		draw_circle(
			center + Vector2(
				48.0 * float(side) * s,
				-90.0 * s
			),
			21.0 * s,
			Color(accent, 0.13)
		)
	draw_circle(
		center + Vector2(0.0, -98.0 * s),
		25.0 * s,
		Color(accent, 0.16)
	)

func _draw_veil_pillar(
	center: Vector2,
	scale_value: float,
	accent: Color
) -> void:
	var s: float = scale_value
	draw_rect(
		Rect2(
			center + Vector2(-11.0, -92.0) * s,
			Vector2(22.0, 92.0) * s
		),
		Color(0.12, 0.065, 0.075, 0.94)
	)
	draw_line(
		center + Vector2(-30.0, -78.0) * s,
		center + Vector2(32.0, -52.0) * s,
		Color(accent, 0.34),
		3.0 * s,
		true
	)
	draw_line(
		center + Vector2(28.0, -55.0) * s,
		center + Vector2(-24.0, -26.0) * s,
		Color(accent, 0.20),
		2.0 * s,
		true
	)

func _draw_ritual_pillar(
	center: Vector2,
	scale_value: float,
	accent: Color
) -> void:
	var s: float = scale_value
	draw_rect(
		Rect2(
			center + Vector2(-18.0, -84.0) * s,
			Vector2(36.0, 84.0) * s
		),
		Color(0.13, 0.072, 0.064, 0.94)
	)
	var seal_center: Vector2 = (
		center + Vector2(0.0, -45.0) * s
	)
	draw_rect(
		Rect2(
			seal_center - Vector2(11.0, 16.0) * s,
			Vector2(22.0, 32.0) * s
		),
		Color(accent, 0.23)
	)
	draw_line(
		seal_center + Vector2(0.0, -11.0) * s,
		seal_center + Vector2(0.0, 10.0) * s,
		Color(0.95, 0.68, 0.42, 0.52),
		2.0 * s,
		true
	)

func _draw_ascent_pillar(
	center: Vector2,
	scale_value: float,
	accent: Color
) -> void:
	var s: float = scale_value
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(-20.0, 0.0) * s,
		center + Vector2(-14.0, -78.0) * s,
		center + Vector2(0.0, -104.0) * s,
		center + Vector2(17.0, -72.0) * s,
		center + Vector2(22.0, 0.0) * s,
	])
	draw_colored_polygon(
		points,
		Color(0.085, 0.055, 0.09, 0.96)
	)
	draw_polyline(
		points,
		Color(accent, 0.28),
		2.0 * s,
		true
	)

func _draw_sanctum_gate(
	center: Vector2,
	scale_value: float,
	accent: Color
) -> void:
	var s: float = scale_value
	var half_width: float = 82.0 * s
	var top_y: float = center.y - 92.0 * s
	for side: int in [-1, 1]:
		var x: float = center.x + half_width * float(side)
		draw_rect(
			Rect2(
				x - 10.0 * s,
				top_y,
				20.0 * s,
				92.0 * s
			),
			Color(0.11, 0.055, 0.065, 0.96)
		)
	draw_rect(
		Rect2(
			center.x - half_width - 14.0 * s,
			top_y - 14.0 * s,
			(half_width + 14.0 * s) * 2.0,
			16.0 * s
		),
		Color(0.11, 0.055, 0.065, 0.96)
	)
	draw_line(
		Vector2(
			center.x - half_width - 25.0 * s,
			top_y - 12.0 * s
		),
		Vector2(
			center.x + half_width + 25.0 * s,
			top_y - 12.0 * s
		),
		Color(0.93, 0.61, 0.31, 0.56),
		3.0 * s,
		true
	)
	draw_circle(
		center + Vector2(0.0, -49.0 * s),
		18.0 * s,
		Color(accent, 0.18)
	)
