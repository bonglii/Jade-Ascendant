extends Node2D

## Verdant Qi Valley — Stage 1 environment props refinement.
## Purely visual: no collision, no gameplay ownership, no save state.
## Drawn on one CanvasItem to keep the mobile render footprint predictable.

const WORLD_EXTENT: float = 7200.0
const START_POSITION: Vector2 = Vector2(326.0, 577.0)
const START_CLEAR_RADIUS: float = 220.0
const DECOR_SEED: int = 14012026

const CLUSTER_COUNT: int = 62
const ROCKS_PER_CLUSTER_MIN: int = 2
const ROCKS_PER_CLUSTER_MAX: int = 5
const GRASS_PER_CLUSTER_MIN: int = 7
const GRASS_PER_CLUSTER_MAX: int = 13
const PLANTS_PER_CLUSTER_MIN: int = 1
const PLANTS_PER_CLUSTER_MAX: int = 3
const RUIN_CLUSTER_CHANCE: float = 0.32

const STARTER_CLUSTER_OFFSETS: Array[Vector2] = [
	Vector2(-360.0, -250.0),
	Vector2(340.0, -260.0),
	Vector2(-390.0, 260.0),
	Vector2(390.0, 300.0),
	Vector2(-120.0, 430.0),
	Vector2(170.0, -430.0),
]

var rock_instances: Array[Vector4] = []
var grass_instances: Array[Vector4] = []
var spirit_plant_instances: Array[Vector4] = []
var ruin_instances: Array[Vector4] = []
var stele_instances: Array[Vector4] = []

var landmark_position: Vector2 = START_POSITION + Vector2(-205.0, 360.0)
var spirit_stele_position: Vector2 = START_POSITION + Vector2(245.0, -300.0)


func _ready() -> void:
	_build_distribution()
	queue_redraw()


func _build_distribution() -> void:
	rock_instances.clear()
	grass_instances.clear()
	spirit_plant_instances.clear()
	ruin_instances.clear()
	stele_instances.clear()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = DECOR_SEED

	# Curated starter clusters ensure the first combat screen already reads
	# as Verdant Qi Valley while keeping the immediate player spawn clean.
	for starter_offset: Vector2 in STARTER_CLUSTER_OFFSETS:
		_build_cluster(
			rng,
			START_POSITION + starter_offset,
			150.0,
			true
		)

	# Wider world uses clustered distribution rather than sparse uniform noise.
	# This creates pockets of vegetation/ruins separated by breathing room.
	for cluster_index: int in range(CLUSTER_COUNT):
		var cluster_center: Vector2 = _random_world_position(rng, 520.0)
		var cluster_radius: float = rng.randf_range(120.0, 230.0)
		var include_ruin: bool = rng.randf() <= RUIN_CLUSTER_CHANCE
		_build_cluster(rng, cluster_center, cluster_radius, include_ruin)

	# A few distant steles give the valley recurring man-made silhouettes.
	for stele_index: int in range(18):
		var stele_center: Vector2 = _random_world_position(rng, 620.0)
		var stele_scale: float = rng.randf_range(0.72, 1.16)
		var stele_rotation: float = rng.randf_range(-0.22, 0.22)
		stele_instances.append(
			Vector4(stele_center.x, stele_center.y, stele_scale, stele_rotation)
		)


func _build_cluster(
	rng: RandomNumberGenerator,
	cluster_center: Vector2,
	cluster_radius: float,
	include_ruin: bool
) -> void:
	var rock_count: int = rng.randi_range(ROCKS_PER_CLUSTER_MIN, ROCKS_PER_CLUSTER_MAX)
	var grass_count: int = rng.randi_range(GRASS_PER_CLUSTER_MIN, GRASS_PER_CLUSTER_MAX)
	var plant_count: int = rng.randi_range(PLANTS_PER_CLUSTER_MIN, PLANTS_PER_CLUSTER_MAX)

	for rock_index: int in range(rock_count):
		var rock_center: Vector2 = _cluster_position(rng, cluster_center, cluster_radius)
		if rock_center.distance_to(START_POSITION) < START_CLEAR_RADIUS:
			continue
		var rock_size: float = rng.randf_range(18.0, 44.0)
		var rock_rotation: float = rng.randf_range(-PI, PI)
		rock_instances.append(Vector4(rock_center.x, rock_center.y, rock_size, rock_rotation))

	for grass_index: int in range(grass_count):
		var grass_center: Vector2 = _cluster_position(rng, cluster_center, cluster_radius * 1.08)
		if grass_center.distance_to(START_POSITION) < 145.0:
			continue
		var grass_size: float = rng.randf_range(10.0, 21.0)
		var grass_rotation: float = rng.randf_range(-0.65, 0.65)
		grass_instances.append(Vector4(grass_center.x, grass_center.y, grass_size, grass_rotation))

	for plant_index: int in range(plant_count):
		var plant_center: Vector2 = _cluster_position(rng, cluster_center, cluster_radius * 0.82)
		if plant_center.distance_to(START_POSITION) < 275.0:
			continue
		var plant_size: float = rng.randf_range(10.0, 17.0)
		var plant_rotation: float = rng.randf_range(-PI, PI)
		spirit_plant_instances.append(Vector4(plant_center.x, plant_center.y, plant_size, plant_rotation))

	if include_ruin:
		var ruin_count: int = rng.randi_range(1, 3)
		for ruin_index: int in range(ruin_count):
			var ruin_center: Vector2 = _cluster_position(rng, cluster_center, cluster_radius * 0.62)
			if ruin_center.distance_to(START_POSITION) < 330.0:
				continue
			var ruin_size: float = rng.randf_range(30.0, 62.0)
			var ruin_rotation: float = rng.randf_range(-PI, PI)
			ruin_instances.append(Vector4(ruin_center.x, ruin_center.y, ruin_size, ruin_rotation))


func _cluster_position(
	rng: RandomNumberGenerator,
	cluster_center: Vector2,
	cluster_radius: float
) -> Vector2:
	var angle: float = rng.randf_range(0.0, TAU)
	var radius: float = sqrt(rng.randf()) * cluster_radius
	return cluster_center + Vector2(cos(angle), sin(angle)) * radius


func _random_world_position(
	rng: RandomNumberGenerator,
	clear_radius: float
) -> Vector2:
	var candidate: Vector2 = Vector2.ZERO
	for attempt: int in range(16):
		candidate = Vector2(
			rng.randf_range(-WORLD_EXTENT, WORLD_EXTENT),
			rng.randf_range(-WORLD_EXTENT, WORLD_EXTENT)
		)
		if candidate.distance_to(START_POSITION) >= clear_radius:
			return candidate
	return candidate


func _draw() -> void:
	for rock_data: Vector4 in rock_instances:
		_draw_rock(rock_data)

	for grass_data: Vector4 in grass_instances:
		_draw_grass_tuft(grass_data)

	for plant_data: Vector4 in spirit_plant_instances:
		_draw_spirit_plant(plant_data)

	for ruin_data: Vector4 in ruin_instances:
		_draw_ruin_fragment(ruin_data)

	for stele_data: Vector4 in stele_instances:
		_draw_spirit_stele(stele_data)

	_draw_cultivation_landmark(landmark_position)
	_draw_spirit_stele(Vector4(spirit_stele_position.x, spirit_stele_position.y, 1.08, -0.08))


func _draw_rock(data: Vector4) -> void:
	var center: Vector2 = Vector2(data.x, data.y)
	var radius: float = data.z
	var rotation_angle: float = data.w

	var points: PackedVector2Array = PackedVector2Array()
	var local_points: Array[Vector2] = [
		Vector2(-0.90, -0.12),
		Vector2(-0.50, -0.68),
		Vector2(0.18, -0.83),
		Vector2(0.78, -0.40),
		Vector2(0.88, 0.24),
		Vector2(0.32, 0.72),
		Vector2(-0.40, 0.62),
	]
	for local_point: Vector2 in local_points:
		points.append(center + local_point.rotated(rotation_angle) * radius)

	draw_circle(
		center + Vector2(3.0, 7.0),
		radius * 0.72,
		Color(0.002, 0.014, 0.015, 0.36)
	)
	draw_colored_polygon(points, Color(0.075, 0.145, 0.125, 0.96))
	draw_polyline(points, Color(0.16, 0.31, 0.26, 0.46), 1.15, true)
	draw_line(
		center + Vector2(-0.35, -0.25).rotated(rotation_angle) * radius,
		center + Vector2(0.42, 0.08).rotated(rotation_angle) * radius,
		Color(0.23, 0.45, 0.34, 0.42),
		1.5,
		true
	)
	draw_circle(
		center + Vector2(-0.18, -0.22).rotated(rotation_angle) * radius,
		radius * 0.13,
		Color(0.12, 0.38, 0.26, 0.38)
	)


func _draw_grass_tuft(data: Vector4) -> void:
	var center: Vector2 = Vector2(data.x, data.y)
	var blade_length: float = data.z
	var rotation_angle: float = data.w
	var grass_color: Color = Color(0.12, 0.38, 0.24, 0.68)
	var grass_light: Color = Color(0.18, 0.48, 0.30, 0.48)
	var grass_dark: Color = Color(0.035, 0.17, 0.11, 0.54)

	for blade_index: int in range(6):
		var normalized_index: float = float(blade_index) - 2.5
		var blade_angle: float = rotation_angle + normalized_index * 0.17
		var blade_scale: float = 0.70 + 0.08 * float((blade_index + 2) % 3)
		var endpoint: Vector2 = center + Vector2(
			cos(blade_angle),
			sin(blade_angle) - 1.1
		).normalized() * blade_length * blade_scale
		var blade_color: Color = grass_light if blade_index == 2 or blade_index == 3 else grass_color
		draw_line(center, endpoint, blade_color, 1.35, true)

	draw_circle(center, blade_length * 0.18, grass_dark)


func _draw_spirit_plant(data: Vector4) -> void:
	var center: Vector2 = Vector2(data.x, data.y)
	var radius: float = data.z
	var rotation_angle: float = data.w
	var stem_color: Color = Color(0.09, 0.38, 0.26, 0.70)
	var petal_color: Color = Color(0.24, 0.67, 0.50, 0.46)
	var core_color: Color = Color(0.43, 0.82, 0.61, 0.46)

	draw_circle(center, radius * 1.15, Color(0.12, 0.50, 0.36, 0.055))
	draw_line(
		center + Vector2(0.0, radius * 0.75),
		center,
		stem_color,
		1.3,
		true
	)

	for petal_index: int in range(5):
		var angle: float = rotation_angle + TAU * float(petal_index) / 5.0
		var petal_center: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.50
		draw_circle(petal_center, radius * 0.26, petal_color)

	draw_circle(center, radius * 0.23, core_color)
	draw_arc(
		center,
		radius * 0.86,
		0.0,
		TAU,
		20,
		Color(0.18, 0.58, 0.44, 0.18),
		1.0,
		true
	)


func _draw_ruin_fragment(data: Vector4) -> void:
	var center: Vector2 = Vector2(data.x, data.y)
	var ruin_size: float = data.z
	var rotation_angle: float = data.w

	var body_points: PackedVector2Array = PackedVector2Array()
	var body_local: Array[Vector2] = [
		Vector2(-0.72, -0.45),
		Vector2(0.55, -0.54),
		Vector2(0.76, 0.23),
		Vector2(0.20, 0.56),
		Vector2(-0.64, 0.42),
	]
	for local_point: Vector2 in body_local:
		body_points.append(center + local_point.rotated(rotation_angle) * ruin_size)

	draw_circle(center + Vector2(3.0, 7.0), ruin_size * 0.72, Color(0.002, 0.014, 0.015, 0.28))
	draw_colored_polygon(body_points, Color(0.085, 0.145, 0.135, 0.94))
	draw_polyline(body_points, Color(0.22, 0.39, 0.34, 0.48), 1.4, true)

	var crack_start: Vector2 = center + Vector2(-0.22, -0.20).rotated(rotation_angle) * ruin_size
	var crack_mid: Vector2 = center + Vector2(0.05, 0.03).rotated(rotation_angle) * ruin_size
	var crack_end: Vector2 = center + Vector2(0.32, 0.28).rotated(rotation_angle) * ruin_size
	draw_line(crack_start, crack_mid, Color(0.22, 0.62, 0.44, 0.32), 1.2, true)
	draw_line(crack_mid, crack_end, Color(0.22, 0.62, 0.44, 0.24), 1.2, true)

	var rune_center: Vector2 = center + Vector2(0.10, -0.08).rotated(rotation_angle) * ruin_size
	draw_arc(
		rune_center,
		ruin_size * 0.16,
		0.0,
		TAU,
		14,
		Color(0.37, 0.72, 0.52, 0.22),
		1.0,
		true
	)


func _draw_spirit_stele(data: Vector4) -> void:
	var center: Vector2 = Vector2(data.x, data.y)
	var stele_scale: float = data.z
	var rotation_angle: float = data.w
	var half_width: float = 24.0 * stele_scale
	var half_height: float = 47.0 * stele_scale

	var local_points: Array[Vector2] = [
		Vector2(-half_width, half_height),
		Vector2(-half_width * 0.86, -half_height * 0.66),
		Vector2(-half_width * 0.42, -half_height),
		Vector2(half_width * 0.45, -half_height * 0.92),
		Vector2(half_width, -half_height * 0.48),
		Vector2(half_width * 0.92, half_height),
	]
	var world_points: PackedVector2Array = PackedVector2Array()
	for local_point: Vector2 in local_points:
		world_points.append(center + local_point.rotated(rotation_angle))

	draw_circle(center + Vector2(4.0, 9.0), half_width * 0.95, Color(0.002, 0.014, 0.015, 0.32))
	draw_colored_polygon(world_points, Color(0.080, 0.150, 0.140, 0.96))
	draw_polyline(world_points, Color(0.24, 0.43, 0.37, 0.52), 1.4, true)

	var rune_axis: Vector2 = Vector2(0.0, -1.0).rotated(rotation_angle)
	var tangent: Vector2 = Vector2(1.0, 0.0).rotated(rotation_angle)
	var rune_center: Vector2 = center - rune_axis * 4.0
	draw_line(
		rune_center - tangent * 10.0,
		rune_center + tangent * 10.0,
		Color(0.34, 0.75, 0.56, 0.34),
		1.5,
		true
	)
	draw_line(
		rune_center - rune_axis * 13.0,
		rune_center + rune_axis * 14.0,
		Color(0.34, 0.75, 0.56, 0.26),
		1.3,
		true
	)
	draw_circle(rune_center, 3.5, Color(0.43, 0.83, 0.62, 0.30))


func _draw_cultivation_landmark(center: Vector2) -> void:
	# Broken top-down cultivation dais placed close enough to be discovered
	# during the opening moments, but outside the immediate combat spawn area.
	var outer_radius: float = 118.0
	var middle_radius: float = 84.0
	var inner_radius: float = 45.0

	draw_circle(center + Vector2(8.0, 11.0), outer_radius, Color(0.002, 0.015, 0.016, 0.34))
	draw_circle(center, outer_radius * 0.93, Color(0.045, 0.105, 0.095, 0.52))
	draw_arc(
		center,
		outer_radius,
		0.12,
		5.66,
		64,
		Color(0.15, 0.34, 0.29, 0.72),
		10.0,
		true
	)
	draw_arc(
		center,
		middle_radius,
		0.52,
		6.02,
		56,
		Color(0.20, 0.54, 0.40, 0.42),
		4.0,
		true
	)
	draw_arc(
		center,
		inner_radius,
		0.0,
		TAU,
		40,
		Color(0.24, 0.66, 0.49, 0.34),
		2.0,
		true
	)

	for pillar_index: int in range(8):
		if pillar_index == 2 or pillar_index == 6:
			continue
		var angle: float = TAU * float(pillar_index) / 8.0
		var pillar_center: Vector2 = center + Vector2(cos(angle), sin(angle)) * 101.0
		var tangent: Vector2 = Vector2(-sin(angle), cos(angle))
		draw_line(
			pillar_center - tangent * 13.0,
			pillar_center + tangent * 13.0,
			Color(0.14, 0.31, 0.27, 0.76),
			9.0,
			true
		)
		draw_circle(pillar_center, 4.5, Color(0.30, 0.66, 0.49, 0.28))

	# Quiet Bagua geometry: readable as ancient cultivation architecture,
	# intentionally softer than any active combat telegraph.
	for line_index: int in range(4):
		var angle: float = PI * 0.25 + PI * 0.5 * float(line_index)
		var axis: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(
			center - axis * 35.0,
			center + axis * 35.0,
			Color(0.24, 0.67, 0.50, 0.22),
			2.0,
			true
		)

	draw_circle(center, 16.0, Color(0.08, 0.23, 0.18, 0.72))
	draw_circle(center, 8.0, Color(0.34, 0.79, 0.58, 0.28))
