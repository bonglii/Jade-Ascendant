extends "res://scripts/world/verdant_qi_valley_decor.gd"

const StageMotifs = preload("res://scripts/world/stage_motifs.gd")

const VISUAL_SIGNATURES: Dictionary = {
	2: "bamboo_mist_pass",
	3: "ruined_jade_shrine",
	4: "storm_peak_approach",
	5: "sovereign_celestial_gate",
	6: "heart_of_verdant_heaven",
}

@export_range(2, 6, 1) var stage_id: int = 2
var feature_instances: Array[Vector3] = []


func get_visual_signature() -> String:
	return str(VISUAL_SIGNATURES.get(stage_id, "verdant_valley"))


func _build_distribution() -> void:
	super._build_distribution()
	feature_instances.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8012026 + stage_id * 137

	# Each trial opens with a deterministic landmark composition around the
	# spawn area. These are visual only and intentionally stay outside the
	# immediate combat footprint so they never masquerade as collision.
	for signature_data: Vector3 in _get_signature_landmarks():
		var point: Vector2 = START_POSITION + Vector2(signature_data.x, signature_data.y)
		feature_instances.append(Vector3(point.x, point.y, signature_data.z))

	# Far-field repetition keeps the world from becoming empty, while the
	# signature composition does the heavy identity work close to the player.
	var scatter_count: int = _get_scatter_count()
	for index: int in range(scatter_count):
		var point: Vector2 = _random_world_position(rng, 600.0)
		feature_instances.append(Vector3(point.x, point.y, rng.randf_range(0.82, 1.34)))

	# Storm Peak and the Celestial Gate should read as harsher stone spaces,
	# not the same lush valley with a different tint.
	if stage_id == 4 or stage_id == 5 or stage_id == 6:
		grass_instances.resize(int(grass_instances.size() * 0.28))
		spirit_plant_instances.resize(int(spirit_plant_instances.size() * 0.22))
	elif stage_id == 3:
		grass_instances.resize(int(grass_instances.size() * 0.62))
		spirit_plant_instances.resize(int(spirit_plant_instances.size() * 0.55))


func _get_signature_landmarks() -> Array[Vector3]:
	match stage_id:
		2:
			# Bamboo corridor: tall groves frame the route without closing it.
			return [
				Vector3(-240.0, -190.0, 1.28),
				Vector3(230.0, -155.0, 1.18),
				Vector3(-285.0, 125.0, 1.10),
				Vector3(275.0, 175.0, 1.32),
				Vector3(-155.0, -405.0, 0.96),
				Vector3(135.0, 420.0, 1.02),
				Vector3(-390.0, 330.0, 0.90),
				Vector3(405.0, -320.0, 0.94),
			]
		3:
			# Broken shrine courtyard: paired fragments and a rear altar silhouette.
			return [
				Vector3(-250.0, -165.0, 1.08),
				Vector3(250.0, -155.0, 1.02),
				Vector3(-300.0, 205.0, 0.90),
				Vector3(300.0, 215.0, 0.94),
				Vector3(15.0, -390.0, 1.34),
			]
		4:
			# Storm approach: sparse ritual pillars create a wind-scoured pass.
			return [
				Vector3(-260.0, -175.0, 1.24),
				Vector3(265.0, -145.0, 1.18),
				Vector3(-320.0, 225.0, 1.02),
				Vector3(315.0, 250.0, 1.08),
				Vector3(-120.0, -430.0, 0.94),
				Vector3(150.0, 445.0, 0.92),
			]
		5:
			# Final avenue: one dominant northern gate, one secondary southern gate,
			# and restrained side sentries. The finale should read as a processional
			# route toward the Sovereign, not a random scatter of shrine props.
			return [
				Vector3(0.0, -470.0, 1.58),
				Vector3(0.0, 520.0, 1.34),
				Vector3(-320.0, -115.0, 0.76),
				Vector3(320.0, 115.0, 0.76),
			]
		6:
			return [
				Vector3(-285.0, -245.0, 1.18),
				Vector3(285.0, -245.0, 1.18),
				Vector3(-285.0, 245.0, 1.18),
				Vector3(285.0, 245.0, 1.18),
				Vector3(0.0, -500.0, 1.48),
			]
		_:
			return []


func _get_scatter_count() -> int:
	match stage_id:
		2:
			return 62
		3:
			return 28
		4:
			return 24
		5:
			return 8
		6:
			return 10
		_:
			return 24


func _draw() -> void:
	for data: Vector4 in rock_instances:
		_draw_rock(data)
	for data: Vector4 in grass_instances:
		_draw_grass_tuft(data)
	if stage_id == 3:
		for data: Vector4 in ruin_instances:
			_draw_ruin_fragment(data)
	if stage_id == 5:
		_draw_gate_approach()
		_draw_sovereign_processional_arches()
	if stage_id == 6:
		_draw_ascension_sanctum()
	for data: Vector3 in feature_instances:
		StageMotifs.draw_motif(self, stage_id, Vector2(data.x, data.y), data.z)
	if stage_id == 3:
		_draw_cultivation_landmark(START_POSITION + Vector2(20, -290))


func _draw_gate_approach() -> void:
	# A broad ceremonial avenue, painted below characters and attack warnings.
	var stone: Color = Color(0.12, 0.20, 0.17, 0.48)
	var gold_edge: Color = Color(0.45, 0.36, 0.17, 0.45)
	for index: int in range(-12, 22):
		var y: float = START_POSITION.y + index * 110.0
		draw_rect(Rect2(START_POSITION.x - 100, y, 198, 96), stone)
		draw_line(Vector2(START_POSITION.x - 108, y), Vector2(START_POSITION.x - 108, y + 96), gold_edge, 2.0)
		draw_line(Vector2(START_POSITION.x + 108, y), Vector2(START_POSITION.x + 108, y + 96), gold_edge, 2.0)

	# Broken transverse seal bands make the finale read as a ritual avenue, not
	# merely a greener stone floor. They remain low contrast and non-circular so
	# they cannot be mistaken for active danger telegraphs.
	for seal_index: int in range(-4, 7):
		var seal_y: float = START_POSITION.y + seal_index * 220.0 + 44.0
		draw_line(
			Vector2(START_POSITION.x - 82.0, seal_y),
			Vector2(START_POSITION.x + 82.0, seal_y),
			Color(0.70, 0.55, 0.24, 0.20),
			2.0,
			true
		)

func _draw_sovereign_processional_arches() -> void:
	# Large non-colliding architectural silhouettes establish hierarchy for the
	# Chapter 1 finale. These are deliberately rectangular/architectural rather
	# than circular so they never resemble active combat telegraphs.
	var jade_dark: Color = Color(0.055, 0.13, 0.115, 0.92)
	var jade_mid: Color = Color(0.12, 0.25, 0.21, 0.78)
	var gold: Color = Color(0.78, 0.61, 0.25, 0.72)
	var gold_soft: Color = Color(0.78, 0.61, 0.25, 0.26)

	var arch_centers: Array[Vector2] = [
		START_POSITION + Vector2(0.0, -365.0),
		START_POSITION + Vector2(0.0, 405.0),
	]
	var arch_scales: Array[float] = [1.0, 0.82]

	for index: int in range(arch_centers.size()):
		var center: Vector2 = arch_centers[index]
		var s: float = arch_scales[index]
		var half_width: float = 178.0 * s
		var column_h: float = 150.0 * s
		var column_w: float = 24.0 * s
		var base_y: float = center.y + 72.0 * s
		var top_y: float = base_y - column_h

		for side: int in [-1, 1]:
			var x: float = center.x + half_width * float(side)
			draw_rect(
				Rect2(
					Vector2(x - column_w * 0.5, top_y),
					Vector2(column_w, column_h)
				),
				jade_dark
			)
			draw_line(
				Vector2(x - 4.0 * s, top_y + 9.0 * s),
				Vector2(x - 4.0 * s, base_y - 6.0 * s),
				gold_soft,
				maxf(1.5, 2.2 * s),
				true
			)
			draw_rect(
				Rect2(
					Vector2(x - 34.0 * s, base_y - 10.0 * s),
					Vector2(68.0 * s, 16.0 * s)
				),
				jade_mid
			)

		# Wide ceremonial lintel and lifted roof profile.
		draw_rect(
			Rect2(
				Vector2(center.x - half_width - 20.0 * s, top_y - 16.0 * s),
				Vector2((half_width + 20.0 * s) * 2.0, 18.0 * s)
			),
			jade_dark
		)
		draw_polyline(
			PackedVector2Array([
				Vector2(center.x - half_width - 36.0 * s, top_y - 14.0 * s),
				Vector2(center.x - half_width * 0.48, top_y - 32.0 * s),
				Vector2(center.x, top_y - 55.0 * s),
				Vector2(center.x + half_width * 0.48, top_y - 32.0 * s),
				Vector2(center.x + half_width + 36.0 * s, top_y - 14.0 * s),
			]),
			gold,
			maxf(2.0, 3.0 * s),
			true
		)
		draw_line(
			Vector2(center.x - half_width, top_y + 4.0 * s),
			Vector2(center.x + half_width, top_y + 4.0 * s),
			gold_soft,
			maxf(1.5, 2.5 * s),
			true
		)

	# Processional side seals. They are low-contrast and outside the central
	# combat lane, so they add ceremony without competing with actors or hazards.
	for side: int in [-1, 1]:
		for row: int in range(3):
			var x: float = START_POSITION.x + float(side) * 252.0
			var y: float = START_POSITION.y - 220.0 + float(row) * 220.0
			draw_rect(Rect2(x - 18.0, y - 34.0, 36.0, 68.0), jade_dark)
			draw_rect(Rect2(x - 11.0, y - 23.0, 22.0, 31.0), Color(0.56, 0.42, 0.17, 0.24))
			draw_line(Vector2(x, y - 19.0), Vector2(x, y + 2.0), gold_soft, 2.0, true)
			draw_line(Vector2(x - 7.0, y - 9.0), Vector2(x + 7.0, y - 9.0), gold_soft, 1.5, true)


func _draw_ascension_sanctum() -> void:
	var center: Vector2 = START_POSITION
	var jade: Color = Color(0.30, 0.70, 0.52, 0.24)
	var gold: Color = Color(0.86, 0.68, 0.28, 0.28)
	for radius: float in [150.0, 235.0, 330.0]:
		draw_arc(center, radius, 0.0, TAU, 64, jade, 3.0, true)
	for index: int in range(8):
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
		draw_line(center + direction * 110.0, center + direction * 355.0, gold, 2.0, true)
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -112.0), center + Vector2(112.0, 0.0),
		center + Vector2(0.0, 112.0), center + Vector2(-112.0, 0.0),
		center + Vector2(0.0, -112.0),
	])
	draw_polyline(diamond, Color(0.70, 0.91, 0.63, 0.30), 3.0, true)
