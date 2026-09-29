extends Node2D

## Chapter 2 battlefield V1 — aggressive authored composition.
## One deterministic Crimson Moon Sect battlefield for 2-1 through 2-5.
## Visual-only scenery: no collision, no timers, no gameplay state.

const EDGE_A: Texture2D = preload("res://assets/world/chapter_two/obsidian_edge_a.png")
const EDGE_B: Texture2D = preload("res://assets/world/chapter_two/obsidian_edge_b.png")
const PILLAR_A: Texture2D = preload("res://assets/world/chapter_two/ritual_pillar_a.png")
const PILLAR_B: Texture2D = preload("res://assets/world/chapter_two/ritual_pillar_b.png")
const SHRINE: Texture2D = preload("res://assets/world/chapter_two/moon_shrine.png")
const ROCKERY: Texture2D = preload("res://assets/world/chapter_two/lava_rockery.png")
const DAIS: Texture2D = preload("res://assets/world/chapter_two/ritual_dais.png")
const TREES: Texture2D = preload("res://assets/world/chapter_two/charred_trees.png")

const HOME := Vector2(326.0, 577.0)
const SEED: int = 2102026
const WORLD_SPAN: int = 12
const WORLD_SPACING_X: float = 610.0
const WORLD_SPACING_Y: float = 665.0

var _scenery: Array[Vector4] = []
var _dais_patches: Array[Vector3] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build_layout()
	queue_redraw()


func _build_layout() -> void:
	_scenery.clear()
	_dais_patches.clear()

	# Curated first combat view: a ritual avenue flanked by sect props.
	var first_view: Array[Vector4] = [
		Vector4(-300.0, -520.0, 0.93, 0),
		Vector4(300.0, -505.0, 0.93, 1),
		Vector4(-306.0, -220.0, 0.82, 2),
		Vector4(305.0, -220.0, 0.82, 3),
		Vector4(-330.0, 155.0, 0.91, 0),
		Vector4(330.0, 180.0, 0.91, 1),
		Vector4(-300.0, 480.0, 0.82, 7),
		Vector4(315.0, 485.0, 0.82, 7),
		Vector4(-370.0, 720.0, 0.94, 5),
		Vector4(380.0, -695.0, 0.94, 5),
		Vector4(-210.0, -375.0, 0.60, 2),
		Vector4(210.0, -375.0, 0.60, 3),
		Vector4(-195.0, 360.0, 0.61, 2),
		Vector4(200.0, 360.0, 0.61, 3),
		Vector4(-238.0, 585.0, 0.74, 4),
		Vector4(238.0, -595.0, 0.74, 4),
		Vector4(0.0, -610.0, 0.82, 6),
		Vector4(0.0, 640.0, 0.82, 6),
	]
	for item: Vector4 in first_view:
		_scenery.append(Vector4(
			HOME.x + item.x, HOME.y + item.y, item.z, item.w
		))

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for cy: int in range(-WORLD_SPAN, WORLD_SPAN + 1):
		for cx: int in range(-WORLD_SPAN, WORLD_SPAN + 1):
			if rng.randf() < 0.15:
				continue
			var p := HOME + Vector2(
				float(cx) * WORLD_SPACING_X + rng.randf_range(-125.0, 125.0),
				float(cy) * WORLD_SPACING_Y + rng.randf_range(-132.0, 132.0)
			)
			if p.distance_to(HOME) < 930.0:
				continue
			var avenue_x := _get_path_x(p.y)
			if absf(p.x - avenue_x) < 240.0:
				continue
			var kind: int = rng.randi_range(0, 7)
			var size_v: float = rng.randf_range(0.70, 1.08)
			_scenery.append(Vector4(p.x, p.y, size_v, float(kind)))

	_scenery.sort_custom(_sort_by_art)

	for index: int in range(-28, 29):
		var y: float = HOME.y + float(index) * 308.0
		var x: float = _get_path_x(y)
		var jitter: float = sin(float(index) * 1.43) * 32.0
		_dais_patches.append(Vector3(x + jitter, y, 0.80))


func _sort_by_art(a: Vector4, b: Vector4) -> bool:
	return a.w < b.w


func _get_path_x(y: float) -> float:
	return HOME.x + sin(y * 0.00142 + 0.9) * 85.0 + sin(y * 0.0031 + 0.2) * 28.0


func _draw() -> void:
	for patch: Vector3 in _dais_patches:
		_draw_texture_at(DAIS, Vector2(patch.x, patch.y),
			Vector2(300.0, 300.0) * patch.z, Color(1.0, 1.0, 1.0, 0.34))

	for data: Vector4 in _scenery:
		var art: Texture2D = EDGE_A
		var art_size: Vector2 = Vector2(370.0, 620.0)
		var opacity: float = 0.92
		match int(data.w):
			0:
				art = EDGE_A
				art_size = Vector2(370.0, 620.0)
			1:
				art = EDGE_B
				art_size = Vector2(370.0, 620.0)
			2:
				art = PILLAR_A
				art_size = Vector2(260.0, 420.0)
			3:
				art = PILLAR_B
				art_size = Vector2(260.0, 420.0)
			4:
				art = SHRINE
				art_size = Vector2(340.0, 520.0)
				opacity = 0.93
			5:
				art = ROCKERY
				art_size = Vector2(340.0, 340.0)
			6:
				art = DAIS
				art_size = Vector2(320.0, 320.0)
				opacity = 0.46
			7:
				art = TREES
				art_size = Vector2(220.0, 400.0)
				opacity = 0.88
			_:
				continue
		_draw_texture_at(art, Vector2(data.x, data.y),
			art_size * data.z, Color(1.0, 1.0, 1.0, opacity))


func _draw_texture_at(art: Texture2D, center: Vector2,
	size_v: Vector2, tint: Color) -> void:
	var bounds := Rect2(center - size_v * 0.5, size_v)
	draw_texture_rect(art, bounds, false, tint)
