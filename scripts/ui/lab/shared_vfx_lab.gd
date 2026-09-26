extends Control

## SHARED VFX LAB v5.2 — Lock Candidate Pass
## Presentation-only review scene for Pavilion shared summon VFX.
## No PavilionManager, economy, save, inventory, summon, or production UI calls.
## Premium artwork keeps its native gold/jade palette. Rarity color is applied
## only to secondary procedural accents, never as a full-art tint.

const ASSET_ROOT: String = "res://assets/ui/pavilion/vfx/shared/"

const RARE_TINT: Color = Color(0.28, 0.94, 0.84, 1.0)
const EPIC_TINT: Color = Color(0.78, 0.48, 0.98, 1.0)
const LEGENDARY_TINT: Color = Color(1.0, 0.76, 0.28, 1.0)
const TEXT_MAIN: Color = Color(0.94, 0.97, 0.94, 1.0)
const TEXT_MUTED: Color = Color(0.64, 0.74, 0.76, 1.0)
const GOLD: Color = Color(0.96, 0.75, 0.30, 1.0)

const ASSETS: Array[Dictionary] = [
	{
		"name": "Ritual Circle Base",
		"file": "ritual_circle_base_premium.png",
		"usage": "Foundation altar • stable hero art • perimeter glints • inner pulse",
		"blend": "mix",
		"kind": "ritual_base",
	},
	{
		"name": "Inner Runic Portal",
		"file": "inner_runic_portal_premium.png",
		"usage": "Runic focus • center ignition • rune halo • energy accumulation",
		"blend": "add",
		"kind": "inner_runic",
	},
	{
		"name": "Outer Sacred Seal",
		"file": "outer_sacred_seal_premium.png",
		"usage": "Ceremonial escalation • perimeter ignition • staged sacred glow",
		"blend": "add",
		"kind": "outer_seal",
	},
	{
		"name": "Qi Mist",
		"file": "qi_mist_premium.png",
		"usage": "Atmospheric depth • cropped mist planes • parallax flow • volumetric feel",
		"blend": "mix",
		"kind": "qi_mist",
	},
	{
		"name": "Procedural Spark Field",
		"file": "",
		"usage": "Cinematic micro-particles • star sparks • streaks • orbiting motes",
		"blend": "add",
		"kind": "spark",
	},
	{
		"name": "Celestial Light Streak",
		"file": "light_streak_premium.png",
		"usage": "Controlled celestial slash • fast attack • thin premium afterimages",
		"blend": "add",
		"kind": "light_streak",
	},
	{
		"name": "Procedural Shockwave",
		"file": "",
		"usage": "Layered radial impact • halo ripple • bright core • soft secondary wave",
		"blend": "add",
		"kind": "shockwave",
	},
	{
		"name": "Soft Halo",
		"file": "soft_halo_premium.png",
		"usage": "Supporting halo • layered breathing • result-depth support",
		"blend": "add",
		"kind": "soft_glow",
	},
	{
		"name": "Reveal Burst",
		"file": "reveal_burst_premium.png",
		"usage": "Sharp reveal burst • impact flash • lingering halo shimmer",
		"blend": "add",
		"kind": "reveal_flare",
	},
	{
		"name": "Floating Talisman",
		"file": "floating_talisman_premium.png",
		"usage": "Three small talismans • elliptical depth orbit • bob • front-pass glow",
		"blend": "mix",
		"kind": "talisman",
	},
	{
		"name": "Impact Core",
		"file": "impact_core_premium.png",
		"usage": "Central impact core • compression • snap release • shock accent",
		"blend": "add",
		"kind": "impact_core",
	},
	{
		"name": "Summon Gateway",
		"file": "summon_gateway_premium.png",
		"usage": "Ceremonial gateway • aperture pulse • inward energy suction • depth glow",
		"blend": "mix",
		"kind": "gateway",
	},
]

var current_index: int = 0
var current_tint: Color = RARE_TINT
var current_tint_name: String = "RARE / JADE"
var active_tween: Tween = null
var playback_generation: int = 0
var auto_loop: bool = true

var stage_root: Control
var effect_sprite: TextureRect
var spawned_layer: Control
var accent_layer: Control
var stage_flash: ColorRect
var flare_horizontal: ColorRect
var flare_vertical: ColorRect
var index_label: Label
var asset_name_label: Label
var asset_usage_label: Label
var tint_label: Label
var loop_button: Button


func _ready() -> void:
	_build_lab()
	await get_tree().process_frame
	_refresh_asset()
	_replay_current()


func _build_lab() -> void:
	var safe_area: Control = $SafeArea

	var background: ColorRect = ColorRect.new()
	background.color = Color(0.001, 0.008, 0.014, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(background, 0)

	var ambient: ColorRect = ColorRect.new()
	ambient.color = Color(0.010, 0.040, 0.048, 0.045)
	ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ambient)
	ambient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(ambient, 1)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	safe_area.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)

	var title: Label = _make_label(root_box, "SHARED VFX LAB • LOCK CANDIDATE", 21, Color(1.0, 0.88, 0.58, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle: Label = _make_label(
		root_box,
		"Final shared-VFX correction • clean depth • lock candidate",
		10,
		TEXT_MUTED
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tint_panel: PanelContainer = PanelContainer.new()
	tint_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.18, 0.42, 0.38, 0.42)))
	root_box.add_child(tint_panel)
	var tint_box: VBoxContainer = VBoxContainer.new()
	tint_box.add_theme_constant_override("separation", 5)
	tint_panel.add_child(tint_box)
	tint_label = _make_label(tint_box, "SECONDARY ACCENT • RARE / JADE", 11, Color(0.82, 1.0, 0.94, 1.0))
	tint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tint_row: HBoxContainer = HBoxContainer.new()
	tint_row.add_theme_constant_override("separation", 6)
	tint_box.add_child(tint_row)
	_add_tint_button(tint_row, "RARE", RARE_TINT, "RARE / JADE")
	_add_tint_button(tint_row, "EPIC", EPIC_TINT, "EPIC / VIOLET")
	_add_tint_button(tint_row, "LEGENDARY", LEGENDARY_TINT, "LEGENDARY / GOLD")

	var stage_panel: PanelContainer = PanelContainer.new()
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.custom_minimum_size.y = 510.0
	stage_panel.add_theme_stylebox_override("panel", _stage_style())
	root_box.add_child(stage_panel)

	stage_root = Control.new()
	stage_root.clip_contents = true
	stage_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.add_child(stage_root)

	_build_stage_guides()

	spawned_layer = Control.new()
	spawned_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_root.add_child(spawned_layer)
	spawned_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	effect_sprite = TextureRect.new()
	effect_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect_sprite.anchor_left = 0.10
	effect_sprite.anchor_top = 0.07
	effect_sprite.anchor_right = 0.90
	effect_sprite.anchor_bottom = 0.78
	stage_root.add_child(effect_sprite)

	accent_layer = Control.new()
	accent_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_root.add_child(accent_layer)
	accent_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	stage_flash = ColorRect.new()
	stage_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	stage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_root.add_child(stage_flash)
	stage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	flare_horizontal = ColorRect.new()
	flare_horizontal.color = Color(1.0, 1.0, 1.0, 0.0)
	flare_horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flare_horizontal.anchor_left = 0.16
	flare_horizontal.anchor_right = 0.84
	flare_horizontal.anchor_top = 0.40
	flare_horizontal.anchor_bottom = 0.40
	flare_horizontal.offset_bottom = 2.0
	stage_root.add_child(flare_horizontal)

	flare_vertical = ColorRect.new()
	flare_vertical.color = Color(1.0, 1.0, 1.0, 0.0)
	flare_vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flare_vertical.anchor_left = 0.50
	flare_vertical.anchor_right = 0.50
	flare_vertical.anchor_top = 0.18
	flare_vertical.anchor_bottom = 0.63
	flare_vertical.offset_right = 2.0
	stage_root.add_child(flare_vertical)

	var info_panel: PanelContainer = PanelContainer.new()
	info_panel.anchor_left = 0.035
	info_panel.anchor_top = 0.81
	info_panel.anchor_right = 0.965
	info_panel.anchor_bottom = 0.975
	info_panel.add_theme_stylebox_override("panel", _info_style())
	stage_root.add_child(info_panel)
	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	info_box.add_theme_constant_override("separation", 2)
	info_panel.add_child(info_box)
	index_label = _make_label(info_box, "01 / 12", 10, GOLD)
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asset_name_label = _make_label(info_box, "", 18, TEXT_MAIN)
	asset_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asset_usage_label = _make_label(info_box, "", 10, TEXT_MUTED)
	asset_usage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asset_usage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var controls: HBoxContainer = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	root_box.add_child(controls)
	var previous_button: Button = _make_button(controls, "‹ PREV")
	previous_button.pressed.connect(_previous_asset)
	var replay_button: Button = _make_button(controls, "REPLAY")
	replay_button.size_flags_stretch_ratio = 1.25
	replay_button.pressed.connect(_replay_current)
	var next_button: Button = _make_button(controls, "NEXT ›")
	next_button.pressed.connect(_next_asset)
	loop_button = _make_button(root_box, "AUTO LOOP • ON")
	loop_button.custom_minimum_size.y = 42.0
	loop_button.pressed.connect(_toggle_loop)


func _build_stage_guides() -> void:
	var center_glow: ColorRect = ColorRect.new()
	center_glow.color = Color(0.02, 0.10, 0.10, 0.025)
	center_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_glow.anchor_left = 0.18
	center_glow.anchor_top = 0.10
	center_glow.anchor_right = 0.82
	center_glow.anchor_bottom = 0.73
	stage_root.add_child(center_glow)

	var horizontal_line: ColorRect = ColorRect.new()
	horizontal_line.color = Color(0.86, 0.68, 0.28, 0.075)
	horizontal_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_line.anchor_left = 0.08
	horizontal_line.anchor_top = 0.40
	horizontal_line.anchor_right = 0.92
	horizontal_line.anchor_bottom = 0.40
	horizontal_line.offset_bottom = 1.0
	stage_root.add_child(horizontal_line)


func _add_tint_button(parent: Node, title: String, tint: Color, tint_name: String) -> void:
	var button: Button = _make_button(parent, title)
	button.add_theme_color_override("font_color", tint)
	button.pressed.connect(_select_tint.bind(tint, tint_name))


func _select_tint(tint: Color, tint_name: String) -> void:
	current_tint = tint
	current_tint_name = tint_name
	tint_label.text = "SECONDARY ACCENT • " + current_tint_name
	_replay_current()


func _previous_asset() -> void:
	current_index = wrapi(current_index - 1, 0, ASSETS.size())
	_refresh_asset()
	_replay_current()


func _next_asset() -> void:
	current_index = wrapi(current_index + 1, 0, ASSETS.size())
	_refresh_asset()
	_replay_current()


func _toggle_loop() -> void:
	auto_loop = not auto_loop
	loop_button.text = "AUTO LOOP • " + ("ON" if auto_loop else "OFF")
	if auto_loop:
		_replay_current()


func _refresh_asset() -> void:
	var data: Dictionary = ASSETS[current_index]
	index_label.text = "%02d / %02d" % [current_index + 1, ASSETS.size()]
	asset_name_label.text = str(data.get("name", "VFX"))
	asset_usage_label.text = str(data.get("usage", ""))
	var file_name: String = str(data.get("file", ""))
	if file_name.is_empty():
		effect_sprite.texture = null
	else:
		effect_sprite.texture = load(ASSET_ROOT + file_name) as Texture2D
	effect_sprite.material = _material_for_blend(str(data.get("blend", "mix")))


func _replay_current() -> void:
	if not is_inside_tree():
		return
	playback_generation += 1
	var generation: int = playback_generation
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = null
	_clear_layer(spawned_layer)
	_clear_layer(accent_layer)
	_reset_stage()
	await get_tree().process_frame
	if generation != playback_generation:
		return
	_play_current_animation(generation)


func _reset_stage() -> void:
	effect_sprite.visible = effect_sprite.texture != null
	effect_sprite.rotation = 0.0
	effect_sprite.scale = Vector2.ONE
	effect_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	effect_sprite.position = Vector2.ZERO
	effect_sprite.pivot_offset = effect_sprite.size * 0.5
	stage_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flare_horizontal.color = Color(1.0, 1.0, 1.0, 0.0)
	flare_vertical.color = Color(1.0, 1.0, 1.0, 0.0)


func _play_current_animation(generation: int) -> void:
	var kind: String = str(ASSETS[current_index].get("kind", ""))
	match kind:
		"ritual_base":
			_play_ritual_base()
		"inner_runic":
			_play_inner_runic()
		"outer_seal":
			_play_outer_seal()
		"qi_mist":
			_play_qi_mist()
		"spark":
			_play_procedural_sparks()
		"light_streak":
			_play_light_streak()
		"shockwave":
			_play_procedural_shockwave()
		"soft_glow":
			_play_soft_glow()
		"reveal_flare":
			_play_reveal_flare()
		"talisman":
			_play_talisman()
		"impact_core":
			_play_impact_core()
		"gateway":
			_play_gateway()

	if active_tween != null:
		active_tween.finished.connect(_on_preview_finished.bind(generation))


func _play_ritual_base() -> void:
	# Keep the premium altar stable. Movement is delegated to perimeter glints,
	# an inner pulse and a restrained native-color depth echo.
	effect_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	effect_sprite.scale = Vector2(0.95, 0.95)
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(effect_sprite, "modulate:a", 0.94, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(effect_sprite, "scale", Vector2(1.0, 1.0), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_spawn_native_depth_copy(Vector2(348.0, 348.0), 0.10, 1.025)
	_spawn_perimeter_glints(10, 150.0, 108.0, 0.12)
	_spawn_layered_halo_pulse(72.0, 0.12)
	_energy_sweep(0.20)

func _play_inner_runic() -> void:
	effect_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	effect_sprite.scale = Vector2(0.76, 0.76)
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(effect_sprite, "modulate:a", 0.94, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(effect_sprite, "scale", Vector2(0.88, 0.88), 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_layered_halo_pulse(58.0, 0.06)
	_spawn_perimeter_glints(12, 128.0, 92.0, 0.16)
	_spawn_inward_motes(9, 142.0, 0.02)
	_flash_stage(0.055, 0.04, 0.18)

func _play_outer_seal() -> void:
	effect_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	effect_sprite.scale = Vector2(0.84, 0.84)
	active_tween = create_tween()
	active_tween.tween_interval(0.08)
	active_tween.set_parallel(true)
	active_tween.tween_property(effect_sprite, "modulate:a", 0.94, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(effect_sprite, "scale", Vector2(0.95, 0.95), 0.70).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_native_depth_copy(Vector2(340.0, 340.0), 0.08, 1.025)
	_spawn_perimeter_glints(8, 152.0, 115.0, 0.22)
	_spawn_layered_halo_pulse(82.0, 0.20)
	_energy_sweep(0.32)

func _play_qi_mist() -> void:
	effect_sprite.visible = false
	var texture: Texture2D = load(ASSET_ROOT + "qi_mist_premium.png") as Texture2D
	var center_point: Vector2 = _effect_center()
	# LOCK candidate: mist must frame the relic, never become a full-screen sheet.
	# Two small perimeter planes create depth while the center stays intentionally clean.
	var plane_sizes: Array[Vector2] = [
		Vector2(156.0, 92.0),
		Vector2(170.0, 98.0),
	]
	var plane_offsets: Array[Vector2] = [
		Vector2(-142.0, 52.0),
		Vector2(142.0, 38.0),
	]
	for layer_index: int in range(2):
		var mist: TextureRect = _spawn_texture_sprite(texture, plane_sizes[layer_index], "mix")
		mist.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_place_center(mist, center_point + plane_offsets[layer_index])
		mist.modulate = Color(1.0, 1.0, 1.0, 0.0)
		mist.rotation = -0.035 if layer_index == 0 else 0.035
		var direction: float = 1.0 if layer_index == 0 else -1.0
		var target_alpha: float = 0.120 if layer_index == 0 else 0.095
		var duration: float = 3.8 + float(layer_index) * 0.45
		var mist_tween: Tween = create_tween().set_parallel(true)
		mist_tween.tween_property(mist, "modulate:a", target_alpha, 0.82).set_trans(Tween.TRANS_SINE)
		mist_tween.tween_property(mist, "position:x", mist.position.x + direction * 18.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		mist_tween.tween_property(mist, "position:y", mist.position.y - 7.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		mist_tween.tween_property(mist, "scale", Vector2(1.025, 1.025), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_spawn_inward_motes(4, 150.0, 0.62)
	active_tween = create_tween()
	active_tween.tween_interval(3.55)

func _play_procedural_sparks() -> void:
	effect_sprite.visible = false
	# Three restrained depth tiers. Readable at 405x860 without becoming particle noise.
	_spawn_cinematic_spark_field(18, 142.0, 0.00)
	_spawn_cinematic_spark_field(10, 108.0, 0.08)
	_spawn_cinematic_spark_field(4, 68.0, 0.16)
	_spawn_perimeter_glints(4, 78.0, 58.0, 0.14)
	active_tween = create_tween()
	active_tween.tween_interval(1.95)

func _play_light_streak() -> void:
	effect_sprite.visible = false
	var texture: Texture2D = load(ASSET_ROOT + "light_streak_premium.png") as Texture2D
	var center_point: Vector2 = _effect_center()
	# Accent slash only: ~25% smaller than v5.1 and kept safely inside the focal stage.
	for trail_index: int in range(2):
		var streak: TextureRect = _spawn_texture_sprite(texture, Vector2(132.0, 64.0), "add")
		_place_center(streak, center_point + Vector2(-82.0 - float(trail_index) * 8.0, 24.0 + float(trail_index) * 5.0))
		streak.modulate = Color(1.0, 1.0, 1.0, 0.0)
		streak.scale = Vector2(0.50, 0.50)
		streak.rotation = -0.09 + float(trail_index) * 0.014
		var delay: float = float(trail_index) * 0.068
		var tween: Tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(streak, "modulate:a", 0.72 - float(trail_index) * 0.26, 0.035)
		tween.parallel().tween_property(streak, "position", streak.position + Vector2(158.0, -38.0), 0.39 + float(trail_index) * 0.05).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(streak, "scale", Vector2(0.64, 0.64), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(streak, "modulate:a", 0.0, 0.19)
	_spawn_cinematic_spark_field(5, 60.0, 0.14)
	_flash_stage(0.026, 0.025, 0.10)
	active_tween = create_tween()
	active_tween.tween_interval(0.92)

func _play_procedural_shockwave() -> void:
	effect_sprite.visible = false
	# Rebuilt from premium ring artwork so the wave never reads like a debug/UI circle.
	# Center stays transparent; one crisp ring leads, one ornate ripple follows.
	_spawn_premium_shockwave_layer(138.0, 0.34, 0.00, 1.58, 0.56)
	_spawn_premium_shockwave_layer(154.0, 0.16, 0.075, 1.72, 0.72)
	_spawn_clean_ring_wave(58.0, 0.75, 0.20, 0.025, 2.10, 0.48)
	_spawn_perimeter_glints(6, 78.0, 58.0, 0.035)
	_spawn_cinematic_spark_field(5, 58.0, 0.045)
	_flash_stage(0.032, 0.018, 0.09)
	active_tween = create_tween()
	active_tween.tween_interval(1.05)

func _play_soft_glow() -> void:
	effect_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	effect_sprite.scale = Vector2(0.78, 0.78)
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(effect_sprite, "modulate:a", 0.50, 0.62).set_trans(Tween.TRANS_SINE)
	active_tween.tween_property(effect_sprite, "scale", Vector2(0.98, 0.98), 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_spawn_layered_halo_pulse(70.0, 0.22)
	_spawn_perimeter_glints(5, 92.0, 72.0, 0.36)

func _play_reveal_flare() -> void:
	effect_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	effect_sprite.scale = Vector2(0.24, 0.24)
	active_tween = create_tween()
	# Sharp peak, then a short clean shimmer instead of fog.
	active_tween.tween_property(effect_sprite, "modulate:a", 0.98, 0.035)
	active_tween.parallel().tween_property(effect_sprite, "scale", Vector2(0.78, 0.78), 0.16).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(effect_sprite, "modulate:a", 0.18, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_tween.tween_property(effect_sprite, "modulate:a", 0.0, 0.20)
	_flash_stage(0.16, 0.018, 0.10)
	_flare_bars()
	_spawn_clean_afterglow(0.11)
	_spawn_layered_halo_pulse(62.0, 0.13)
	_spawn_cinematic_spark_field(8, 76.0, 0.06)

func _play_talisman() -> void:
	effect_sprite.visible = false
	var texture: Texture2D = load(ASSET_ROOT + "floating_talisman_premium.png") as Texture2D
	var center_point: Vector2 = _effect_center()
	# Final scale hierarchy: individual talismans stay clearly separated.
	var sizes: Array[float] = [28.0, 32.0, 36.0]
	for talisman_index: int in range(3):
		var size_value: float = sizes[talisman_index]
		var talisman: TextureRect = _spawn_texture_sprite(texture, Vector2(size_value, size_value * 1.34), "mix")
		var angle: float = -0.95 + float(talisman_index) * 2.18
		var radius_x: float = 148.0 + float(talisman_index) * 10.0
		var radius_y: float = 84.0 + float(talisman_index) * 6.0
		var start_point: Vector2 = center_point + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		_place_center(talisman, start_point)
		talisman.modulate = Color(1.0, 1.0, 1.0, 0.0)
		talisman.rotation = -0.06 + float(talisman_index) * 0.04
		var direction: float = 1.0 if talisman_index % 2 == 0 else -1.0
		var end_angle: float = angle + direction * 0.42
		var end_point: Vector2 = center_point + Vector2(cos(end_angle) * radius_x, sin(end_angle) * radius_y)
		var tween: Tween = create_tween()
		tween.tween_interval(float(talisman_index) * 0.11)
		tween.tween_property(talisman, "modulate:a", 0.58 - float(talisman_index) * 0.06, 0.17)
		tween.parallel().tween_property(talisman, "position", end_point - talisman.size * 0.5 + Vector2(0.0, -4.0), 1.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(talisman, "rotation", talisman.rotation + direction * 0.06, 1.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(talisman, "modulate:a", 0.10, 0.26)
	_spawn_clean_ring_wave(60.0, 0.8, 0.13, 0.18, 1.48, 0.34)
	active_tween = create_tween()
	active_tween.tween_interval(1.95)

func _play_impact_core() -> void:
	# Final punctuation: visible compression, 0.10s held tension, then a decisive release.
	effect_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	effect_sprite.scale = Vector2(0.62, 0.62)
	active_tween = create_tween()
	active_tween.tween_property(effect_sprite, "modulate:a", 0.76, 0.06)
	active_tween.parallel().tween_property(effect_sprite, "scale", Vector2(0.39, 0.39), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_tween.tween_interval(0.10)
	active_tween.tween_callback(_impact_release_accent)
	active_tween.tween_property(effect_sprite, "scale", Vector2(1.18, 1.18), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(effect_sprite, "modulate:a", 1.0, 0.055)
	active_tween.tween_property(effect_sprite, "scale", Vector2(0.90, 0.90), 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_tween.parallel().tween_property(effect_sprite, "modulate:a", 0.32, 0.30)
	active_tween.tween_property(effect_sprite, "modulate:a", 0.0, 0.18)

func _play_gateway() -> void:
	effect_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	effect_sprite.scale = Vector2(0.80, 0.80)
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(effect_sprite, "modulate:a", 0.90, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(effect_sprite, "scale", Vector2(0.91, 0.91), 0.92).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_spawn_native_depth_copy(Vector2(360.0, 360.0), 0.045, 1.015)
	_spawn_clean_ring_wave(58.0, 1.4, 0.30, 0.26, 1.58, 0.22)
	_spawn_inward_motes(12, 156.0, 0.18)
	_spawn_perimeter_glints(7, 136.0, 102.0, 0.26)

func _spawn_premium_shockwave_layer(
	diameter: float,
	peak_alpha: float,
	delay: float,
	target_scale: float,
	release_time: float
) -> void:
	var texture: Texture2D = load(ASSET_ROOT + "inner_runic_portal_premium.png") as Texture2D
	var ripple: TextureRect = _spawn_texture_sprite(texture, Vector2(diameter, diameter), "add")
	_place_center(ripple, _effect_center())
	ripple.modulate = Color(1.0, 1.0, 1.0, 0.0)
	ripple.scale = Vector2(0.28, 0.28)
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_property(ripple, "modulate:a", peak_alpha, 0.035)
	tween.parallel().tween_property(ripple, "scale", Vector2(target_scale, target_scale), release_time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(ripple, "modulate:a", 0.0, 0.18)


func _impact_release_accent() -> void:
	_flash_stage(0.10, 0.018, 0.10)
	_spawn_premium_shockwave_layer(116.0, 0.28, 0.0, 1.50, 0.46)
	_spawn_clean_ring_wave(54.0, 0.75, 0.18, 0.025, 1.96, 0.52)
	_spawn_cinematic_spark_field(7, 62.0, 0.015)


func _spawn_native_depth_copy(target_size: Vector2, alpha_value: float, scale_value: float) -> void:
	if effect_sprite.texture == null:
		return
	var copy: TextureRect = _spawn_texture_sprite(effect_sprite.texture, target_size, "add")
	_place_center(copy, _effect_center())
	copy.modulate = Color(1.0, 1.0, 1.0, alpha_value)
	copy.scale = Vector2(scale_value, scale_value)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(copy, "modulate:a", alpha_value * 0.65, 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(copy, "scale", Vector2(scale_value + 0.025, scale_value + 0.025), 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _spawn_cinematic_spark_field(count: int, spread: float, start_delay: float) -> void:
	var center_point: Vector2 = _effect_center()
	for spark_index: int in range(count):
		var tier: int = spark_index % 3
		var spark: ColorRect = ColorRect.new()
		var width_value: float = 1.2
		var height_value: float = 4.0
		if tier == 1:
			width_value = 2.2
			height_value = 8.0
		elif tier == 2:
			width_value = 1.6
			height_value = 13.0
		spark.size = Vector2(width_value, height_value)
		spark.pivot_offset = spark.size * 0.5
		spark.rotation = float((spark_index * 41) % 180) * PI / 180.0
		var warm_mix: float = 0.42 if spark_index % 4 == 0 else 0.12
		var spark_color: Color = current_tint.lerp(Color(1.0, 0.90, 0.62, 1.0), warm_mix)
		spark.color = Color(spark_color.r, spark_color.g, spark_color.b, 0.0)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		accent_layer.add_child(spark)
		var angle: float = TAU * float(spark_index) / float(maxi(count, 1)) + float((spark_index * 17) % 13) * 0.028
		var radius: float = 24.0 + float((spark_index * 29) % int(maxf(spread, 34.0)))
		spark.position = center_point + Vector2(cos(angle), sin(angle) * 0.72) * radius - spark.size * 0.5
		var delay: float = start_delay + float(spark_index % 7) * 0.036
		var rise: float = 16.0 + float((spark_index * 19) % 42)
		var lateral: float = -10.0 + float((spark_index * 11) % 21)
		var peak_alpha: float = 0.46 + float(tier) * 0.16
		var target_scale: float = 0.82 + float(tier) * 0.18
		var tween: Tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(spark, "color:a", peak_alpha, 0.055)
		tween.parallel().tween_property(spark, "scale", Vector2(target_scale, target_scale), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(spark, "position", spark.position + Vector2(lateral, -rise), 0.66 + float(tier) * 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "color:a", 0.0, 0.30)

func _spawn_clean_ring_wave(
	base_radius: float,
	line_width: float,
	peak_alpha: float,
	delay: float,
	target_scale: float,
	gold_mix: float
) -> void:
	var ring: Line2D = Line2D.new()
	ring.width = line_width
	ring.closed = true
	ring.antialiased = true
	var ring_color: Color = current_tint.lerp(Color(1.0, 0.88, 0.56, 1.0), clampf(gold_mix, 0.0, 1.0))
	ring.default_color = Color(ring_color.r, ring_color.g, ring_color.b, 1.0)
	for point_index: int in range(65):
		var angle: float = TAU * float(point_index) / 64.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * base_radius)
	ring.position = _effect_center()
	ring.scale = Vector2(0.36, 0.36)
	ring.modulate.a = 0.0
	accent_layer.add_child(ring)
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_property(ring, "modulate:a", peak_alpha, 0.045)
	tween.parallel().tween_property(ring, "scale", Vector2(target_scale, target_scale), 0.58).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.24)


func _spawn_clean_afterglow(delay: float) -> void:
	_spawn_clean_ring_wave(54.0, 1.4, 0.30, delay, 1.58, 0.40)
	_spawn_clean_ring_wave(70.0, 0.9, 0.16, delay + 0.06, 1.48, 0.70)
	_spawn_perimeter_glints(6, 82.0, 62.0, delay + 0.04)


func _spawn_perimeter_glints(count: int, radius_x: float, radius_y: float, start_delay: float) -> void:
	var center_point: Vector2 = _effect_center()
	for glint_index: int in range(count):
		var glint: ColorRect = ColorRect.new()
		var long_axis: float = 9.0 + float(glint_index % 3) * 3.0
		glint.size = Vector2(1.5, long_axis)
		glint.pivot_offset = glint.size * 0.5
		var glint_color: Color = current_tint.lerp(Color(1.0, 0.90, 0.62, 1.0), 0.45)
		glint.color = Color(glint_color.r, glint_color.g, glint_color.b, 0.0)
		glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		accent_layer.add_child(glint)
		var angle: float = TAU * float(glint_index) / float(maxi(count, 1)) - PI * 0.5
		var point: Vector2 = center_point + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		glint.position = point - glint.size * 0.5
		glint.rotation = angle + PI * 0.5
		var tween: Tween = create_tween()
		tween.tween_interval(start_delay + float(glint_index) * 0.065)
		tween.tween_property(glint, "color:a", 0.78, 0.08)
		tween.parallel().tween_property(glint, "scale", Vector2(1.0, 1.7), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(glint, "color:a", 0.0, 0.24)

func _spawn_layered_halo_pulse(diameter: float, delay: float) -> void:
	var halo_texture: Texture2D = load(ASSET_ROOT + "soft_halo_premium.png") as Texture2D
	for halo_index: int in range(2):
		var halo: TextureRect = _spawn_texture_sprite(halo_texture, Vector2(diameter, diameter), "add")
		_place_center(halo, _effect_center())
		halo.modulate = Color(1.0, 1.0, 1.0, 0.0)
		halo.scale = Vector2(0.48 + float(halo_index) * 0.10, 0.48 + float(halo_index) * 0.10)
		var tween: Tween = create_tween()
		tween.tween_interval(delay + float(halo_index) * 0.09)
		tween.tween_property(halo, "modulate:a", 0.30 - float(halo_index) * 0.09, 0.10)
		tween.parallel().tween_property(halo, "scale", Vector2(1.05 + float(halo_index) * 0.22, 1.05 + float(halo_index) * 0.22), 0.72 + float(halo_index) * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(halo, "modulate:a", 0.0, 0.34)

func _spawn_afterglow_shimmer(delay: float) -> void:
	var halo_texture: Texture2D = load(ASSET_ROOT + "soft_halo_premium.png") as Texture2D
	var shimmer: TextureRect = _spawn_texture_sprite(halo_texture, Vector2(152.0, 152.0), "add")
	_place_center(shimmer, _effect_center())
	shimmer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	shimmer.scale = Vector2(0.72, 0.72)
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_property(shimmer, "modulate:a", 0.26, 0.12)
	tween.parallel().tween_property(shimmer, "scale", Vector2(1.10, 1.10), 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(shimmer, "modulate:a", 0.0, 0.34)

func _spawn_inward_motes(count: int, start_radius: float, start_delay: float) -> void:
	var center_point: Vector2 = _effect_center()
	for mote_index: int in range(count):
		var mote: ColorRect = ColorRect.new()
		var size_value: float = 2.0 + float(mote_index % 3)
		mote.size = Vector2(size_value, size_value)
		mote.pivot_offset = mote.size * 0.5
		mote.rotation = PI * 0.25
		var mote_color: Color = current_tint.lerp(Color(1.0, 0.90, 0.65, 1.0), 0.34)
		mote.color = Color(mote_color.r, mote_color.g, mote_color.b, 0.0)
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		accent_layer.add_child(mote)
		var angle: float = TAU * float(mote_index) / float(maxi(count, 1)) + float((mote_index * 11) % 7) * 0.08
		var start_point: Vector2 = center_point + Vector2(cos(angle), sin(angle) * 0.72) * (start_radius + float(mote_index % 3) * 14.0)
		mote.position = start_point - mote.size * 0.5
		var tween: Tween = create_tween()
		tween.tween_interval(start_delay + float(mote_index % 6) * 0.06)
		tween.tween_property(mote, "color:a", 0.64, 0.10)
		tween.parallel().tween_property(mote, "position", center_point - mote.size * 0.5, 0.82 + float(mote_index % 4) * 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(mote, "scale", Vector2(0.30, 0.30), 0.82).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(mote, "color:a", 0.0, 0.12)

func _spawn_ring(diameter: float, border_width: int) -> PanelContainer:
	var ring: PanelContainer = PanelContainer.new()
	ring.size = Vector2(diameter, diameter)
	ring.custom_minimum_size = ring.size
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = Color(current_tint.r, current_tint.g, current_tint.b, 0.92)
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	ring.add_theme_stylebox_override("panel", style)
	accent_layer.add_child(ring)
	ring.pivot_offset = ring.size * 0.5
	return ring


func _spawn_accent_ring(diameter: float, alpha_value: float, target_scale: float) -> void:
	var ring: PanelContainer = _spawn_ring(diameter, 1)
	_place_center(ring, _effect_center())
	ring.modulate.a = 0.0
	ring.scale = Vector2(0.78, 0.78)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(ring, "modulate:a", alpha_value, 0.30)
	tween.tween_property(ring, "scale", Vector2(target_scale, target_scale), 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _spawn_accent_core(diameter: float, alpha_value: float, target_scale: float) -> void:
	var core: PanelContainer = PanelContainer.new()
	core.size = Vector2(diameter, diameter)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(current_tint.r, current_tint.g, current_tint.b, alpha_value)
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	core.add_theme_stylebox_override("panel", style)
	accent_layer.add_child(core)
	core.pivot_offset = core.size * 0.5
	_place_center(core, _effect_center())
	core.scale = Vector2(0.55, 0.55)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(core, "scale", Vector2(target_scale, target_scale), 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(core, "modulate:a", 0.0, 0.86)


func _spawn_procedural_shockwave_accent(delay: float) -> void:
	var ring: PanelContainer = _spawn_ring(116.0, 2)
	_place_center(ring, _effect_center())
	ring.modulate.a = 0.0
	ring.scale = Vector2(0.48, 0.48)
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_property(ring, "modulate:a", 0.72, 0.05)
	tween.parallel().tween_property(ring, "scale", Vector2(1.90, 1.90), 0.56).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.22)


func _energy_sweep(delay: float) -> void:
	var sweep: ColorRect = ColorRect.new()
	sweep.size = Vector2(82.0, 2.0)
	sweep.color = Color(current_tint.r, current_tint.g, current_tint.b, 0.0)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent_layer.add_child(sweep)
	sweep.position = Vector2(stage_root.size.x * 0.22, stage_root.size.y * 0.40)
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_property(sweep, "color:a", 0.55, 0.08)
	tween.parallel().tween_property(sweep, "position:x", stage_root.size.x * 0.70, 0.64).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(sweep, "color:a", 0.0, 0.18)


func _flash_stage(peak_alpha: float, attack_time: float, release_time: float) -> void:
	stage_flash.color = Color(current_tint.r, current_tint.g, current_tint.b, 0.0)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(stage_flash, "color:a", peak_alpha, attack_time)
	flash_tween.tween_property(stage_flash, "color:a", 0.0, release_time)


func _flare_bars() -> void:
	flare_horizontal.color = Color(current_tint.r, current_tint.g, current_tint.b, 0.0)
	flare_vertical.color = Color(1.0, 0.92, 0.70, 0.0)
	var horizontal_tween: Tween = create_tween()
	horizontal_tween.tween_property(flare_horizontal, "color:a", 0.62, 0.04)
	horizontal_tween.tween_property(flare_horizontal, "color:a", 0.0, 0.26)
	var vertical_tween: Tween = create_tween()
	vertical_tween.tween_interval(0.025)
	vertical_tween.tween_property(flare_vertical, "color:a", 0.42, 0.04)
	vertical_tween.tween_property(flare_vertical, "color:a", 0.0, 0.22)


func _effect_center() -> Vector2:
	return Vector2(stage_root.size.x * 0.50, stage_root.size.y * 0.40)


func _spawn_texture_sprite(texture: Texture2D, target_size: Vector2, blend_name: String) -> TextureRect:
	var sprite: TextureRect = TextureRect.new()
	sprite.texture = texture
	sprite.size = target_size
	sprite.custom_minimum_size = target_size
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.material = _material_for_blend(blend_name)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spawned_layer.add_child(sprite)
	sprite.pivot_offset = target_size * 0.5
	return sprite


func _place_center(control: Control, center_point: Vector2) -> void:
	control.position = center_point - control.size * 0.5


func _on_preview_finished(generation: int) -> void:
	if generation != playback_generation or not auto_loop:
		return
	await get_tree().create_timer(0.40).timeout
	if generation == playback_generation and auto_loop:
		_replay_current()


func _clear_layer(layer: Control) -> void:
	for child: Node in layer.get_children():
		layer.remove_child(child)
		child.queue_free()


func _material_for_blend(blend_name: String) -> CanvasItemMaterial:
	var canvas_material: CanvasItemMaterial = CanvasItemMaterial.new()
	canvas_material.blend_mode = (
		CanvasItemMaterial.BLEND_MODE_ADD
		if blend_name == "add"
		else CanvasItemMaterial.BLEND_MODE_MIX
	)
	return canvas_material


func _make_label(parent: Node, text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _make_button(parent: Node, text_value: String) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 46.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 12)
	parent.add_child(button)
	return button


func _panel_style(border_tint: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.020, 0.030, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_tint
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


func _stage_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0005, 0.006, 0.012, 0.97)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.94, 0.74, 0.28, 0.72)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 8
	return style


func _info_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.018, 0.028, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.24, 0.76, 0.70, 0.44)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
