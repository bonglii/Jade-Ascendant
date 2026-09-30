extends Node2D

## One-time batched, collision-free Realm IV/V environmental illustration.
## Five original stage-specific monument designs per realm, shared floor style.
## Loaded lazily: only the selected stage's artwork occupies mobile memory.
@export_range(4, 5, 1) var realm_id: int = 4
@export_range(1, 5, 1) var stage_id: int = 1

const HOME: Vector2 = Vector2(326.0, 577.0)
const GRID_RADIUS: int = 10
const CELL_X: float = 650.0
const CELL_Y: float = 710.0
const SAFE_PATH_HALF_WIDTH: float = 220.0

var landmark: Texture2D
# Authored, transparent scenic fragments extracted from the approved Realm-IV arena.
# Frozen sprites are only loaded in Realm IV, never in Realm V.
const FROST_SCENERY_PATHS := [
	"res://assets/world/chapter4/frost_scenery/gate_courtyard.png",
	"res://assets/world/chapter4/frost_scenery/bell_balcony.png",
	"res://assets/world/chapter4/frost_scenery/glacier_walls.png",
	"res://assets/world/chapter4/frost_scenery/crystal_sentinel.png",
	"res://assets/world/chapter4/frost_scenery/snow_watchtower.png",
	"res://assets/world/chapter4/frost_scenery/frost_bridge.png",
	"res://assets/world/chapter4/frost_scenery/ice_cliff.png",
	"res://assets/world/chapter4/frost_scenery/shattered_altar.png",
	"res://assets/world/chapter4/frost_scenery/sleet_cracks.png",
	"res://assets/world/chapter4/frost_scenery/frozen_lotus_floor.png",
]

var frost_scenery: Array[Texture2D] = []
var frost_decor: Array[Vector4] = []  # x, y, scale, scenery ID
var frost_patches: Array[Vector4] = []  # x, y, scale, flooring ID

# Solar scenery uses a different authored palette/visual language than Frostveil.
# All 10 PNGs are derived from the two APPROVED Chapter-V illustrations.
# These textures load only in Chapter V and have no collision.
const SOLAR_SCENERY_PATHS := [
	"res://assets/world/chapter5/solar_scenery/sun_gate.png",
	"res://assets/world/chapter5/solar_scenery/phoenix_left.png",
	"res://assets/world/chapter5/solar_scenery/phoenix_right.png",
	"res://assets/world/chapter5/solar_scenery/banner_tower.png",
	"res://assets/world/chapter5/solar_scenery/sunforge_altar.png",
	"res://assets/world/chapter5/solar_scenery/solar_obelisk.png",
	"res://assets/world/chapter5/solar_scenery/brazier_left.png",
	"res://assets/world/chapter5/solar_scenery/brazier_right.png",
	"res://assets/world/chapter5/solar_scenery/sunstone_paving.png",
	"res://assets/world/chapter5/solar_scenery/phoenix_mandala.png",
]
var solar_scenery: Array[Texture2D] = []
var solar_decor: Array[Vector4] = []
var solar_patches: Array[Vector4] = []

var features: Array[Vector4] = []
var glyphs: Array[Vector3] = []

func _ready() -> void:
	z_index = -72
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if realm_id == 4:
		# Do NOT draw Gate-B geometric symbols as Chapter-IV scenery.
		# Only exact approved hand-painted fragments are used in Frostveil.
		for asset_path: String in FROST_SCENERY_PATHS:
			var art: Texture2D = ResourceLoader.load(asset_path, "Texture2D") as Texture2D
			if art == null:
				push_error("Frostveil art missing: " + asset_path)
				return
			frost_scenery.append(art)
	else:
		# Chapter V uses one-time batched, individually authored scenery stamps.
		# The previous repeated vector landmark is intentionally not displayed.
		for asset_path: String in SOLAR_SCENERY_PATHS:
			var art: Texture2D = ResourceLoader.load(asset_path, "Texture2D") as Texture2D
			if art == null:
				push_error("Solar Nirvana art missing: " + asset_path)
				return
			solar_scenery.append(art)
	_build_once()
	queue_redraw()

func _build_once() -> void:
	features.clear()
	glyphs.clear()
	if realm_id == 4:
		_build_frostveil_layout()
		return
	if realm_id == 5:
		_build_solar_layout()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 40005001 + realm_id * 1181 + stage_id * 223
	# First-screen landmarks frame the action; central movement route stays open.
	var near_props: Array[Vector3] = [
		Vector3(-310.0, -475.0, 0.80), Vector3(315.0, -461.0, 0.77),
		Vector3(-334.0, 40.0, 0.72), Vector3(346.0, 72.0, 0.73),
		Vector3(-330.0, 555.0, 0.75), Vector3(327.0, 570.0, 0.78),
	]
	for item: Vector3 in near_props:
		features.append(Vector4(HOME.x + item.x, HOME.y + item.y, item.z, 0.80))
	for gy: int in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for gx: int in range(-GRID_RADIUS, GRID_RADIUS + 1):
			if rng.randf() < 0.28:
				continue
			var at: Vector2 = HOME + Vector2(
				float(gx) * CELL_X + rng.randf_range(-155.0, 155.0),
				float(gy) * CELL_Y + rng.randf_range(-165.0, 165.0)
			)
			if at.distance_to(HOME) < 820.0:
				continue
			if absf(at.x - _path_x(at.y)) < SAFE_PATH_HALF_WIDTH:
				continue
			features.append(Vector4(at.x, at.y, rng.randf_range(0.72, 1.06), rng.randf_range(0.56, 0.84)))
	# Low-contrast floor ornaments are deterministic, no randomized per-frame work.
	for index: int in range(-26, 27):
		var y: float = HOME.y + float(index) * 310.0
		glyphs.append(Vector3(_path_x(y), y, rng.randf_range(0.65, 1.02)))


func _path_x(world_y: float) -> float:
	return HOME.x + sin(world_y * 0.0014 + float(stage_id)) * 67.0


func _draw() -> void:
	if realm_id == 4:
		_draw_frostveil()
		return
	if realm_id == 5:
		_draw_solar()
		return
	if landmark == null:
		return
	var accent: Color = Color(0.28, 0.68, 0.80, 0.16) if realm_id == 4 else Color(0.90, 0.52, 0.23, 0.16)
	var rune: Color = Color(0.57, 0.85, 0.98, 0.11) if realm_id == 4 else Color(1.0, 0.73, 0.40, 0.11)
	for mark: Vector3 in glyphs:
		var center: Vector2 = Vector2(mark.x, mark.y)
		var radius_value: float = 45.0 * mark.z
		draw_arc(center, radius_value, -0.9, 2.2, 24, rune, 2.0, true)
		draw_arc(center, radius_value, 2.55, 5.6, 24, accent, 2.0, true)
	for item: Vector4 in features:
		var size_v: Vector2 = Vector2(350.0, 440.0) * item.z
		var loc: Vector2 = Vector2(item.x, item.y)
		var tint: Color = Color(1.0, 1.0, 1.0, item.w)
		draw_texture_rect(landmark, Rect2(loc - size_v * 0.5, size_v), false, tint)


## Realm IV: curated art-first composition. Chapter II's proven approach:
## multiple differentiated hand-painted scenery stamps around an open avenue,
## deterministic world scatter, and subdued floor decals beneath combat.
## Visual-only; zero navigation/collision changes and zero per-frame work.
func _build_frostveil_layout() -> void:
	frost_decor.clear()
	frost_patches.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 441770 + stage_id * 519

	# Each trial has a distinct first-screen silhouette and focal location.
	# x/y relative to HOME, scale, index in FROST_SCENERY_PATHS.
	var compositions: Dictionary = {
		1: [
			Vector4(-270.0, -332.0, 1.00, 0.0),  # Silent Frost gate
			Vector4(270.0, -333.0, 0.96, 1.0),  # hanging bell cliff
			Vector4(-267.0, 80.0, 0.84, 2.0),
			Vector4(268.0, 60.0, 0.82, 3.0),
			Vector4(-265.0, 407.0, 0.89, 4.0),
			Vector4(264.0, 406.0, 0.90, 5.0),
			Vector4(-355.0, -9.0, 0.78, 6.0),
		],
		2: [
			Vector4(-260.0, -364.0, 1.08, 0.0),  # monastery gate dominant
			Vector4(281.0, -260.0, 0.88, 1.0),
			Vector4(-273.0, 139.0, 0.94, 4.0),
			Vector4(264.0, 110.0, 0.98, 2.0),
			Vector4(-296.0, 460.0, 0.89, 6.0),
			Vector4(260.0, 401.0, 0.98, 5.0),
		],
		3: [
			Vector4(-253.0, -325.0, 0.92, 2.0),
			Vector4(264.0, -315.0, 0.91, 3.0),
			Vector4(-269.0, 75.0, 0.92, 0.0),
			Vector4(261.0, 65.0, 0.90, 1.0),
			Vector4(-260.0, 404.0, 0.87, 4.0),
			Vector4(274.0, 380.0, 0.87, 5.0),
		],
		4: [
			Vector4(-267.0, -336.0, 0.99, 1.0),  # high bell corridor
			Vector4(276.0, -339.0, 1.00, 1.0),
			Vector4(-276.0, 34.0, 0.88, 2.0),
			Vector4(279.0, 56.0, 0.96, 3.0),
			Vector4(-268.0, 405.0, 0.91, 5.0),
			Vector4(265.0, 403.0, 0.95, 4.0),
			Vector4(-385.0, 630.0, 0.90, 6.0),
		],
		5: [
			Vector4(-251.0, -370.0, 1.02, 0.0),
			Vector4(257.0, -368.0, 1.02, 0.0),  # sovereign twin gates
			Vector4(-257.0, 55.0, 0.98, 3.0),
			Vector4(267.0, 52.0, 0.96, 3.0),
			Vector4(-261.0, 407.0, 1.0, 4.0),
			Vector4(269.0, 406.0, 0.98, 5.0),
			Vector4(0.0, -618.0, 0.90, 1.0),
		],
	}
	for item: Vector4 in compositions.get(stage_id, compositions[1]):
		frost_decor.append(Vector4(HOME.x + item.x, HOME.y + item.y, item.z, item.w))

	# Existing infinite-survivors floor remains passable. Mixed small and large
	# stamps avoid Chapter IV's former six identical blue gates impression.
	for gy: int in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for gx: int in range(-GRID_RADIUS, GRID_RADIUS + 1):
			if rng.randf() < 0.22:
				continue
			var at: Vector2 = HOME + Vector2(
				float(gx) * CELL_X + rng.randf_range(-145.0, 145.0),
				float(gy) * CELL_Y + rng.randf_range(-155.0, 155.0)
			)
			if at.distance_to(HOME) < 880.0:
				continue
			if absf(at.x - _path_x(at.y)) < SAFE_PATH_HALF_WIDTH:
				continue
			var choices: Array[int] = [0, 1, 2, 3, 4, 5, 6]
			var art_id: int = choices[rng.randi_range(0, choices.size() - 1)]
			frost_decor.append(Vector4(
				at.x, at.y, rng.randf_range(0.67, 1.02), float(art_id)
			))

	# Deeper ice fissures + frost-lotus engraving vary by trial, not five
	# identical centered circles that could resemble hostile telegraphs.
	var primary_decal: int = 9 if stage_id in [3, 5] else 8
	frost_patches.append(Vector4(HOME.x + 9.0, HOME.y + 9.0,
		1.02 if stage_id == 3 else 0.84, float(primary_decal)))
	if stage_id in [2, 5]:
		frost_patches.append(Vector4(HOME.x - 44.0, HOME.y - 366.0, 0.63, 7.0))
	if stage_id == 4:
		frost_patches.append(Vector4(HOME.x + 59.0, HOME.y + 399.0, 0.69, 8.0))
	for i: int in range(-16, 17):
		if abs(i) < 2:
			continue
		var y: float = HOME.y + float(i) * 410.0
		frost_patches.append(Vector4(_path_x(y) + rng.randf_range(-78.0, 78.0),
			y, rng.randf_range(0.62, 0.91), 8.0))


func _draw_frostveil() -> void:
	if frost_scenery.size() != FROST_SCENERY_PATHS.size():
		return
	# Ground cracks are opaque-geometry-free: read them as ambient world paint,
	# never as red/bright AoE warning shapes. Player/VFX draw above z -72.
	for patch: Vector4 in frost_patches:
		var texture: Texture2D = frost_scenery[int(patch.w)]
		var tex_size: Vector2 = Vector2(texture.get_width(), texture.get_height()) * patch.z
		var loc: Vector2 = Vector2(patch.x, patch.y)
		draw_texture_rect(texture, Rect2(loc - tex_size * 0.5, tex_size), false,
			Color(0.94, 0.98, 1.0, 0.36 if int(patch.w) == 9 else 0.29))

	# Stage-specific rich world-space monuments at edge/periphery. Different
	# widths/heights preserve the source painterly perspective without squeezing.
	for item: Vector4 in frost_decor:
		var texture: Texture2D = frost_scenery[int(item.w)]
		var tex_size: Vector2 = Vector2(texture.get_width(), texture.get_height()) * item.z
		var loc: Vector2 = Vector2(item.x, item.y)
		draw_texture_rect(texture, Rect2(loc - tex_size * 0.5, tex_size), false,
			Color(1.0, 1.0, 1.0, 0.95))


## Realm V: solar-furnace scenery constructed from the user's APPROVED
## panorama/arena, five DIFFERENT first-screen compositions. No fake walls,
## static world-space only; player and all enemy telegraphs remain above z -72.
func _build_solar_layout() -> void:
	solar_decor.clear()
	solar_patches.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 551770 + stage_id * 719
	# Relative to HOME: x, y, scale, artwork index. ID 8 & 9 are ground stamps.
	# Keep spawn area and combat-lane center free of apparent impassable props.
	var compositions: Dictionary = {
		1: [ # First Sun Stair -- ancient processional approach.
			Vector4(-270.0, -342.0, 0.96, 0.0),
			Vector4(275.0, -358.0, 0.91, 3.0),
			Vector4(-289.0, 65.0, 0.89, 6.0),
			Vector4(280.0, 81.0, 0.87, 7.0),
			Vector4(-275.0, 425.0, 0.88, 1.0),
			Vector4(265.0, 404.0, 0.84, 2.0),
		],
		2: [ # Sunforge Crucible -- tall metalwork and embers.
			Vector4(-262.0, -359.0, 1.05, 4.0),
			Vector4(269.0, -330.0, 0.93, 5.0),
			Vector4(-279.0, 93.0, 0.82, 3.0),
			Vector4(278.0, 108.0, 0.90, 0.0),
			Vector4(-281.0, 442.0, 0.84, 6.0),
			Vector4(278.0, 435.0, 0.91, 7.0),
		],
		3: [ # Phoenix Ash Expanse -- guardian statues + ash pavement.
			Vector4(-272.0, -340.0, 0.99, 1.0),
			Vector4(270.0, -340.0, 0.98, 2.0),
			Vector4(-281.0, 80.0, 0.84, 6.0),
			Vector4(281.0, 84.0, 0.87, 7.0),
			Vector4(-264.0, 431.0, 0.91, 3.0),
			Vector4(271.0, 422.0, 0.83, 5.0),
		],
		4: [ # Nine-Sun Eclipse Altar -- solar pillars and ritual gate.
			Vector4(-270.0, -362.0, 0.97, 5.0),
			Vector4(268.0, -362.0, 0.97, 5.0),
			Vector4(-287.0, 71.0, 0.89, 4.0),
			Vector4(283.0, 76.0, 0.89, 0.0),
			Vector4(-271.0, 436.0, 0.95, 6.0),
			Vector4(270.0, 428.0, 0.93, 7.0),
		],
		5: [ # Primordial Sun Throne -- paired imperial phoenix guardians.
			Vector4(-270.0, -360.0, 1.00, 1.0),
			Vector4(270.0, -359.0, 1.00, 2.0),
			Vector4(-278.0, 66.0, 0.96, 0.0),
			Vector4(274.0, 80.0, 0.94, 4.0),
			Vector4(-268.0, 434.0, 0.88, 6.0),
			Vector4(269.0, 441.0, 0.88, 7.0),
			Vector4(0.0, -647.0, 0.80, 5.0),
		],
	}
	for item: Vector4 in compositions.get(stage_id, compositions[1]):
		solar_decor.append(Vector4(
			HOME.x + item.x, HOME.y + item.y, item.z, item.w
		))

	# Sparse, authored-biome random distribution on the INFINITE arena.
	# No repeated prop mesh in center where boss attack indicators appear.
	for gy: int in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for gx: int in range(-GRID_RADIUS, GRID_RADIUS + 1):
			if rng.randf() < 0.40:
				continue
			var at: Vector2 = HOME + Vector2(
				float(gx) * CELL_X + rng.randf_range(-132.0, 132.0),
				float(gy) * CELL_Y + rng.randf_range(-145.0, 145.0)
			)
			if at.distance_to(HOME) < 850.0:
				continue
			if absf(at.x - _path_x(at.y)) < SAFE_PATH_HALF_WIDTH + 22.0:
				continue
			var art_id: int = rng.randi_range(0, 7)
			solar_decor.append(Vector4(
				at.x, at.y, rng.randf_range(0.64, 0.99), float(art_id)
			))

	# Ground motifs intentionally kept dark and dim. Bright telegraphs must
	# remain visually distinct and should NEVER be confused with world art.
	var centerpiece: int = 9 if stage_id in [3, 4, 5] else 8
	solar_patches.append(Vector4(
		HOME.x + 10.0, HOME.y + 16.0,
		0.88 if stage_id in [3, 5] else 0.72, float(centerpiece)
	))
	if stage_id in [2, 4]:
		solar_patches.append(Vector4(HOME.x + 26.0, HOME.y - 365.0, 0.65, 8.0))
	for index: int in range(-17, 18):
		if abs(index) < 2:
			continue
		var y: float = HOME.y + float(index) * 398.0
		solar_patches.append(Vector4(
			_path_x(y) + rng.randf_range(-70.0, 70.0),
			y, rng.randf_range(0.57, 0.87), 8.0
		))


func _draw_solar() -> void:
	if solar_scenery.size() != SOLAR_SCENERY_PATHS.size():
		return
	for item: Vector4 in solar_patches:
		var art: Texture2D = solar_scenery[int(item.w)]
		var size_v: Vector2 = Vector2(art.get_width(), art.get_height()) * item.z
		var loc: Vector2 = Vector2(item.x, item.y)
		draw_texture_rect(art, Rect2(loc - size_v * 0.5, size_v), false,
			Color(1.0, 0.96, 0.90, 0.28 if int(item.w) == 9 else 0.24))

	for item: Vector4 in solar_decor:
		var art: Texture2D = solar_scenery[int(item.w)]
		var size_v: Vector2 = Vector2(art.get_width(), art.get_height()) * item.z
		var loc: Vector2 = Vector2(item.x, item.y)
		draw_texture_rect(art, Rect2(loc - size_v * 0.5, size_v), false,
			Color(1.0, 1.0, 1.0, 0.92))
