extends Node2D

## Nine Heavens Star Palace — one authored world-space environment for 3-1 to 3-5.
## Cached visual-only CanvasItem. No collision, gameplay state or per-frame work.

const EDGE_A: Texture2D = preload("res://assets/world/chapter_three/palace_edge_a.png")
const EDGE_B: Texture2D = preload("res://assets/world/chapter_three/palace_edge_b.png")
const GARDEN_A: Texture2D = preload("res://assets/world/chapter_three/cloud_garden_a.png")
const GARDEN_B: Texture2D = preload("res://assets/world/chapter_three/cloud_garden_b.png")
const LANTERN_A: Texture2D = preload("res://assets/world/chapter_three/sky_lantern_a.png")
const LANTERN_B: Texture2D = preload("res://assets/world/chapter_three/sky_lantern_b.png")
const PAVILION: Texture2D = preload("res://assets/world/chapter_three/astral_pavilion.png")
const RUINS: Texture2D = preload("res://assets/world/chapter_three/celestial_ruins.png")
const CAUSEWAY: Texture2D = preload("res://assets/world/chapter_three/starstone_causeway.png")

const HOME := Vector2(326.0, 577.0)
const SEED: int = 3092026
const WORLD_SPAN: int = 12
const WORLD_SPACING_X: float = 600.0
const WORLD_SPACING_Y: float = 660.0

# x, y, scale, artwork index. Rebuilt once per scene, with deterministic seed.
var _scenery: Array[Vector4] = []
var _causeway_patches: Array[Vector3] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build_layout()
	queue_redraw()


func _build_layout() -> void:
	_scenery.clear()
	_causeway_patches.clear()

	# First screen uses paired palace silhouettes and clouds on the shoulders.
	# Visuals are underneath every playable entity; these do not block passage.
	var first_view: Array[Vector4] = [
		Vector4(-305.0, -515.0, 0.88, 0),
		Vector4(306.0, -500.0, 0.88, 1),
		Vector4(-292.0, -185.0, 0.90, 2),
		Vector4(295.0, -172.0, 0.90, 3),
		Vector4(-324.0, 160.0, 0.90, 0),
		Vector4(320.0, 187.0, 0.91, 1),
		Vector4(-299.0, 476.0, 0.94, 2),
		Vector4(304.0, 480.0, 0.94, 3),
		Vector4(-410.0, 717.0, 0.96, 7),
		Vector4(390.0, -688.0, 0.96, 7),
		Vector4(-212.0, -355.0, 0.59, 4),
		Vector4(218.0, -358.0, 0.59, 5),
		Vector4(-204.0, 362.0, 0.60, 4),
		Vector4(206.0, 369.0, 0.60, 5),
		Vector4(-215.0, 610.0, 0.68, 6),
		Vector4(223.0, -603.0, 0.68, 6),
	]
	for item: Vector4 in first_view:
		_scenery.append(Vector4(HOME.x + item.x, HOME.y + item.y,
			item.z, item.w))

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for cy: int in range(-WORLD_SPAN, WORLD_SPAN + 1):
		for cx: int in range(-WORLD_SPAN, WORLD_SPAN + 1):
			if rng.randf() < 0.14:
				continue
			var scenery_point := HOME + Vector2(
				float(cx) * WORLD_SPACING_X + rng.randf_range(-114.0, 114.0),
				float(cy) * WORLD_SPACING_Y + rng.randf_range(-124.0, 124.0)
			)
			if scenery_point.distance_to(HOME) < 890.0:
				continue
			if absf(scenery_point.x - _get_path_x(scenery_point.y)) < 244.0:
				continue
			var artwork: int = rng.randi_range(0, 8)
			var size_v: float = rng.randf_range(0.68, 1.04)
			_scenery.append(Vector4(scenery_point.x, scenery_point.y, size_v,
				float(artwork)))

	_scenery.sort_custom(_sort_by_art)

	# Subdued paving fragments, not a repeating bright summoning circle.
	for index: int in range(-30, 31):
		var y: float = HOME.y + float(index) * 292.0
		var x: float = _get_path_x(y)
		var drift: float = sin(float(index) * 1.63) * 21.0
		_causeway_patches.append(Vector3(x + drift, y, 0.78))


func _sort_by_art(a: Vector4, b: Vector4) -> bool:
	return a.w < b.w


func _get_path_x(y: float) -> float:
	return HOME.x + sin(y * 0.00150 + 0.3) * 82.0 + sin(y * 0.00330 + 1.5) * 33.0


func _draw() -> void:
	for patch: Vector3 in _causeway_patches:
		_draw_texture_at(CAUSEWAY, Vector2(patch.x, patch.y),
			Vector2(310.0, 350.0) * patch.z,
			Color(1.0, 1.0, 1.0, 0.43))

	for data: Vector4 in _scenery:
		var artwork: Texture2D = EDGE_A
		var bounds: Vector2 = Vector2(375.0, 625.0)
		var opacity: float = 0.92
		match int(data.w):
			0:
				artwork = EDGE_A
				bounds = Vector2(375.0, 625.0)
			1:
				artwork = EDGE_B
				bounds = Vector2(375.0, 625.0)
			2:
				artwork = GARDEN_A
				bounds = Vector2(370.0, 610.0)
			3:
				artwork = GARDEN_B
				bounds = Vector2(370.0, 610.0)
			4:
				artwork = LANTERN_A
				bounds = Vector2(245.0, 395.0)
			5:
				artwork = LANTERN_B
				bounds = Vector2(245.0, 395.0)
			6:
				artwork = PAVILION
				bounds = Vector2(345.0, 420.0)
				opacity = 0.90
			7:
				artwork = RUINS
				bounds = Vector2(310.0, 440.0)
				opacity = 0.90
			8:
				artwork = CAUSEWAY
				bounds = Vector2(310.0, 350.0)
				opacity = 0.76
			_:
				continue
		_draw_texture_at(artwork, Vector2(data.x, data.y),
			bounds * data.z, Color(1.0, 1.0, 1.0, opacity))


func _draw_texture_at(artwork: Texture2D, center: Vector2,
	size_v: Vector2, tint: Color) -> void:
	var target := Rect2(center - size_v * 0.5, size_v)
	draw_texture_rect(artwork, target, false, tint)
