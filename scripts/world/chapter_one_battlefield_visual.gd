extends Node2D

## Chapter 1 battlefield V2 — authored scenic composition from approved art.
## One deterministic world for 1-1 through 1-5, independent of stage_id.
## Decoration is one cached CanvasItem: no collision, timers, save fields,
## enemy interactions, random gameplay state or per-frame allocations.

const GROVE_A: Texture2D = preload("res://assets/world/chapter_one/bamboo_grove_a.png")
const GROVE_B: Texture2D = preload("res://assets/world/chapter_one/bamboo_grove_b.png")
const EDGE_A: Texture2D = preload("res://assets/world/chapter_one/forest_edge_a.png")
const EDGE_B: Texture2D = preload("res://assets/world/chapter_one/forest_edge_b.png")
const LANTERN: Texture2D = preload("res://assets/world/chapter_one/lantern_grove.png")
const ROCKERY: Texture2D = preload("res://assets/world/chapter_one/shrine_rockery.png")
const PATH: Texture2D = preload("res://assets/world/chapter_one/ancient_stone_path.png")

const HOME := Vector2(326.0, 577.0)
const SEED: int = 29092026
const WORLD_SPAN: int = 12
const WORLD_SPACING_X: float = 590.0
const WORLD_SPACING_Y: float = 655.0

# Vector4 = world x, world y, scale, material identity.
var _scenery: Array[Vector4] = []
var _path_patches: Array[Vector3] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build_layout()
	queue_redraw()


func _build_layout() -> void:
	_scenery.clear()
	_path_patches.clear()

	# Camera's first combat view is deliberately composed instead of waiting
	# for a distant RNG cluster. Vegetation frames the left/right of the path.
	var first_view: Array[Vector4] = [
		Vector4(-280.0, -500.0, 0.82, 0),
		Vector4(280.0, -480.0, 0.83, 1),
		Vector4(-278.0, -190.0, 0.91, 2),
		Vector4(291.0, -165.0, 0.94, 3),
		Vector4(-310.0, 175.0, 0.88, 0),
		Vector4(320.0, 195.0, 0.89, 1),
		Vector4(-284.0, 460.0, 0.92, 2),
		Vector4(300.0, 478.0, 0.89, 3),
		Vector4(-390.0, 720.0, 0.94, 0),
		Vector4(400.0, -690.0, 0.97, 1),
		# A pair of restrained lantern shrines guides the eye along the avenue.
		Vector4(-196.0, -354.0, 0.62, 4),
		Vector4(222.0, 359.0, 0.65, 4),
		Vector4(-220.0, 615.0, 0.76, 5),
		Vector4(237.0, -598.0, 0.76, 5),
	]
	for item: Vector4 in first_view:
		_scenery.append(Vector4(
			HOME.x + item.x, HOME.y + item.y, item.z, item.w
		))

	# Every Chapter 1 stage sees the same coordinated patches at a given
	# world position. The coarse cells deliberately leave combat-space gaps.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for cy: int in range(-WORLD_SPAN, WORLD_SPAN + 1):
		for cx: int in range(-WORLD_SPAN, WORLD_SPAN + 1):
			if rng.randf() < 0.14:
				continue
			var p := HOME + Vector2(
				float(cx) * WORLD_SPACING_X + rng.randf_range(-115.0, 115.0),
				float(cy) * WORLD_SPACING_Y + rng.randf_range(-125.0, 125.0)
			)
			# No automatic placements on top of curated starting composition.
			if p.distance_to(HOME) < 870.0:
				continue
			var path_x := _get_path_x(p.y)
			if absf(p.x - path_x) < 235.0:
				continue
			var kind: int = rng.randi_range(0, 5)
			var size_v: float = rng.randf_range(0.67, 1.08)
			_scenery.append(Vector4(p.x, p.y, size_v, float(kind)))

	# Group sprites by atlas texture to minimize draw-state changes on mobile.
	_scenery.sort_custom(_sort_by_art)

	# Painterly stone fragments guide the eye without a rigid tiled checkerboard.
	# These are image decals, under every fighter, hit effect, and pickup.
	for index: int in range(-30, 31):
		var y: float = HOME.y + float(index) * 288.0
		var x: float = _get_path_x(y)
		var jitter: float = sin(float(index) * 1.77) * 22.0
		_path_patches.append(Vector3(x + jitter, y, 0.78))


func _sort_by_art(a: Vector4, b: Vector4) -> bool:
	return a.w < b.w


func _get_path_x(y: float) -> float:
	return HOME.x + sin(y * 0.00165) * 96.0 + sin(y * 0.0036 + 1.7) * 37.0


func _draw() -> void:
	for patch: Vector3 in _path_patches:
		_draw_texture_at(PATH, Vector2(patch.x, patch.y),
			Vector2(290.0, 442.0) * patch.z, Color(1.0, 1.0, 1.0, 0.61))

	for data: Vector4 in _scenery:
		var art: Texture2D = GROVE_A
		var art_size: Vector2 = Vector2(352.0, 600.0)
		var opacity: float = 0.90
		match int(data.w):
			0:
				art = GROVE_A
				art_size = Vector2(352.0, 600.0)
			1:
				art = GROVE_B
				art_size = Vector2(352.0, 598.0)
			2:
				art = EDGE_A
				art_size = Vector2(360.0, 610.0)
			3:
				art = EDGE_B
				art_size = Vector2(360.0, 620.0)
			4:
				art = LANTERN
				art_size = Vector2(250.0, 360.0)
				opacity = 0.93
			5:
				art = ROCKERY
				art_size = Vector2(280.0, 435.0)
				opacity = 0.89
			_:
				continue
		_draw_texture_at(art, Vector2(data.x, data.y),
			art_size * data.z, Color(1.0, 1.0, 1.0, opacity))


func _draw_texture_at(art: Texture2D, center: Vector2,
	size_v: Vector2, tint: Color) -> void:
	var bounds := Rect2(center - size_v * 0.5, size_v)
	draw_texture_rect(art, bounds, false, tint)
