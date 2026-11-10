extends Node2D
## World-space pockets of atmosphere. They sit above scenery and behind combat.
const PATCH = preload("res://assets/shaders/stage_atmosphere_patch.gdshader")
const SHRINE_ROCKERY = preload("res://assets/world/chapter_one/shrine_rockery.png")
const CELL_SIZE := Vector2(1440, 1760)
const PALETTES: Array[Color] = [
	Color("e0d999"), Color("b6d9e3"), Color("8af4db"), Color("aec7da"), Color("e6be7b"),
	Color("d99188"), Color("91bac6"), Color("b5a9eb"), Color("c4e8f3"), Color("ef9968")
]
# Pairs provide a foreground accent and a quieter supporting motion for each trial.
const PROFILES: Dictionary = {
	1: [Vector2i(0,4), Vector2i(1,0), Vector2i(2,4), Vector2i(3,1), Vector2i(4,3), Vector2i(2,6)],
	2: [Vector2i(5,0), Vector2i(1,5), Vector2i(2,5), Vector2i(3,5), Vector2i(4,5)],
	3: [Vector2i(7,3), Vector2i(6,7), Vector2i(2,7), Vector2i(3,7), Vector2i(7,4)],
	4: [Vector2i(8,3), Vector2i(6,8), Vector2i(8,0), Vector2i(2,8), Vector2i(4,8)],
	5: [Vector2i(9,3), Vector2i(9,2), Vector2i(9,5), Vector2i(7,9), Vector2i(4,9)]
}
const SOUND_PROFILES: Array[String] = [
	"meadow", "bamboo", "shrine", "ridge", "shrine", "bloodwood", "astral", "astral", "frost", "ember"
]
const PATCH_SLOTS: Array[Vector2] = [
	Vector2(-160, -243), Vector2(185, -144), Vector2(162, 57),
	Vector2(-169, 142), Vector2(-146, 306), Vector2(188, 354)
]
const DECOR_CROWD_LIMIT: int = 64

var profile := Vector2i.ZERO
var _shrine_landmarks: Array[Sprite2D] = []
var _wind := Vector2.RIGHT
var _tint: Color
var _origin: Vector2
var _cell := Vector2i(9999, 9999)
var _hero: Node2D
var _waves: Node
var _patches: Array[Polygon2D] = []
var _uv_texture: ImageTexture
var _far_mist: CanvasItem
var _bed: AudioStreamPlayer
var _near: AudioStreamPlayer2D
var _pulse: float = 0.0
var _quiet: bool = false
var _crowded: bool = false
var _boss_near: bool = false
var _voice_target: float = -30.0

func configure(realm: int, stage: int, accent: Color) -> void:
	var choices: Array = PROFILES.get(realm, PROFILES[1])
	profile = choices[clampi(stage - 1, 0, choices.size() - 1)]
	_wind = Vector2.from_angle(float(realm * 3 + stage) * 0.17)
	_tint = accent

func _ready() -> void:
	z_index = -68
	_hero = get_parent().get_node_or_null("player_1") as Node2D
	_waves = get_parent().get_node_or_null("WaveManager")
	if _hero == null or _waves == null:
		return
	_origin = to_local(_hero.global_position)
	_far_mist = get_parent().get_node_or_null("VerdantQiValleyMistFar") as CanvasItem
	var old_near: CanvasItem = get_parent().get_node_or_null("VerdantQiValleyQiNear") as CanvasItem
	if old_near != null:
		old_near.hide()
	var unit := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	unit.fill(Color.WHITE)
	_uv_texture = ImageTexture.create_from_image(unit)
	if profile == Vector2i(2,4):
		_add_shrine_landmarks()
	for index: int in PATCH_SLOTS.size():
		_add_patch(index)
	_refresh_patches()
	_start_audio()

func _add_shrine_landmarks() -> void:
	for index: int in [0,2]:
		var ruin := Sprite2D.new()
		ruin.name = "JadeFissureLandmark"
		ruin.texture = SHRINE_ROCKERY
		ruin.scale = Vector2(134,174) / SHRINE_ROCKERY.get_size()
		ruin.modulate = Color(0.68,0.79,0.76,0.88)
		ruin.flip_h = index == 2
		ruin.set_meta(&"patch_index",index)
		ruin.z_index = -1
		_shrine_landmarks.append(ruin)
		add_child(ruin)

func _add_patch(index: int) -> void:
	var panel := Polygon2D.new()
	var wide: bool = index % 2 == 0
	var extent := Vector2(160, 106) if wide else Vector2(128, 93)
	panel.polygon = PackedVector2Array([-extent, Vector2(extent.x,-extent.y), extent, Vector2(-extent.x,extent.y)])
	panel.uv = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	# The source only supplies UVs. The shader paints the complete decal.
	panel.texture = _uv_texture
	var patch_material := ShaderMaterial.new()
	patch_material.shader = PATCH
	var motif: int = profile.x if wide else profile.y
	patch_material.set_shader_parameter("motif", motif)
	patch_material.set_shader_parameter("tint", PALETTES[motif].lerp(_tint, 0.24))
	patch_material.set_shader_parameter("seed", float(index) * 2.31 + float(profile.x) * 0.42)
	patch_material.set_shader_parameter("wind", _wind)
	panel.material = patch_material
	_patches.append(panel)
	add_child(panel)

func _start_audio() -> void:
	var bed_name: String = SOUND_PROFILES[profile.x]
	var near_name: String = SOUND_PROFILES[profile.y]
	var path: String = "res://assets/audio/stage_atmosphere/"
	_bed = AudioStreamPlayer.new()
	_bed.name = "BiomeBed"
	_bed.stream = _loop(path + bed_name + ".ogg")
	_bed.bus = &"SFX"
	_bed.volume_db = -40.0
	add_child(_bed)
	_bed.play()
	_near = AudioStreamPlayer2D.new()
	_near.name = "LandmarkSound"
	_near.stream = _loop(path + near_name + ".ogg")
	_near.bus = &"SFX"
	_near.volume_db = -36.0
	_near.max_distance = 420.0
	_near.attenuation = 2.0
	_near.position = _patches[1].position
	add_child(_near)
	_near.play(1.4)

func _loop(path: String) -> AudioStreamOggVorbis:
	var source: AudioStreamOggVorbis = load(path) as AudioStreamOggVorbis
	source.loop = true
	return source

func _process(delta: float) -> void:
	if not is_instance_valid(_hero):
		return
	if _bed != null:
		_bed.volume_db = move_toward(_bed.volume_db, _voice_target, delta * 18.0)
		_near.volume_db = move_toward(_near.volume_db, _voice_target - 5.0, delta * 18.0)
	_pulse -= delta
	if _pulse > 0.0:
		return
	_pulse = 0.25
	_refresh_patches()

func _refresh_patches() -> void:
	var hero_position: Vector2 = to_local(_hero.global_position)
	var next_cell := Vector2i(((hero_position - _origin + CELL_SIZE * 0.5) / CELL_SIZE).floor())
	# Move all anchors only when the player enters another arena cell.
	if next_cell != _cell:
		_cell = next_cell
		for index: int in _patches.size():
			_patches[index].position = _origin + Vector2(_cell) * CELL_SIZE + PATCH_SLOTS[index]
		for ruin: Sprite2D in _shrine_landmarks:
			ruin.position = _patches[int(ruin.get_meta(&"patch_index"))].position - Vector2(0,36)
		if _near != null:
			_near.position = _patches[1].position
	var reduced: bool = SettingsManager.reduced_effects
	var crowded: bool = get_tree().get_node_count_in_group(&"enemy") >= DECOR_CROWD_LIMIT
	var boss_near: bool = int(_waves.current_wave) >= int(_waves.final_wave) or (
		int(_waves.current_wave) == int(_waves.final_wave) - 1 and float(_waves.wave_timer) <= 6.0
	)
	_voice_target = -40.0 if boss_near else (-34.0 if crowded else -26.0)
	var quiet: bool = reduced or crowded
	if _quiet == quiet and _crowded == crowded and _boss_near == boss_near and _pulse > 0.0:
		return
	_quiet = quiet
	_crowded = crowded
	_boss_near = boss_near
	if _far_mist != null:
		_far_mist.visible = not _quiet
	var scenery: Node = get_parent().get_node_or_null("ChapterOneBattlefieldVisual")
	if scenery != null:
		scenery.set_quiet_wind(_quiet or boss_near)
	for index: int in _patches.size():
		var panel: Polygon2D = _patches[index]
		if crowded:
			panel.visible = index == 0 or index == 2
		else:
			panel.visible = index % 2 == 0 or not boss_near
		var patch_material: ShaderMaterial = panel.material as ShaderMaterial
		patch_material.set_shader_parameter("strength", 0.44 if boss_near else (0.58 if _quiet else 1.0))
		patch_material.set_shader_parameter("reduced", _quiet or boss_near)
