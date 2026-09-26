extends Control

## Reusable, presentation-only Pavilion summon sequence controller.
## This controller consumes already-resolved presentation data only.
## It never calls PavilionManager, InventoryManager, SaveManager, or currency APIs.

signal sequence_started(rarity_id: String)
signal reveal_cue(rarity_id: String)
signal sequence_finished(rarity_id: String)

const ASSET_ROOT: String = "res://assets/ui/pavilion/vfx/shared/"
const GATEWAY_PATH: String = ASSET_ROOT + "summon_gateway_premium.png"
const RITUAL_PATH: String = ASSET_ROOT + "ritual_circle_base_premium.png"
const RUNIC_PATH: String = ASSET_ROOT + "inner_runic_portal_premium.png"
const SEAL_PATH: String = ASSET_ROOT + "outer_sacred_seal_premium.png"
const MIST_PATH: String = ASSET_ROOT + "qi_mist_premium.png"
const TALISMAN_PATH: String = ASSET_ROOT + "floating_talisman_premium.png"
const IMPACT_PATH: String = ASSET_ROOT + "impact_core_premium.png"
const BURST_PATH: String = ASSET_ROOT + "reveal_burst_premium.png"
const HALO_PATH: String = ASSET_ROOT + "soft_halo_premium.png"
const STREAK_PATH: String = ASSET_ROOT + "light_streak_premium.png"

# Optical-center corrections measured from the approved source artwork.
# Values are normalized source-space offsets of the brightest visual mass from
# the PNG geometric center. Rendering subtracts them so consecutive effects
# share one perceived focal point instead of only one mathematical center.
const MIST_OPTICAL_OFFSET: Vector2 = Vector2(0.0795, 0.0739)
const TALISMAN_OPTICAL_OFFSET: Vector2 = Vector2(0.0333, 0.0242)
const IMPACT_OPTICAL_OFFSET: Vector2 = Vector2(-0.0050, 0.0658)
const BURST_OPTICAL_OFFSET: Vector2 = Vector2(0.0342, 0.0148)
const STREAK_OPTICAL_OFFSET: Vector2 = Vector2(-0.0289, 0.0265)

var _back_layer: Control
var _ritual_layer: Control
var _relic_layer: Control
var _front_layer: Control
var _screen_layer: Control
var _relic_panel: PanelContainer
var _relic_icon: TextureRect
var _rarity_label: Label
var _name_label: Label
var _busy: bool = false
var _external_relic_mode: bool = false
var _active_tweens: Array[Tween] = []
var _ephemeral_nodes: Array[Node] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_layers()
	_build_relic_card()
	resized.connect(_on_resized)
	call_deferred("_on_resized")


func is_busy() -> bool:
	return _busy


func set_external_relic_mode(enabled: bool) -> void:
	_external_relic_mode = enabled
	if enabled and _relic_panel != null:
		_relic_panel.visible = false


func clear_sequence() -> void:
	# Combined host uses this between rarity switches. Keeping every controller
	# visible gives all three a valid StageFrame size from frame one; clearing
	# inactive controllers prevents leftover relic/VFX layers from overlapping.
	_busy = false
	_reset_sequence_visuals()


func prepare_host_layout() -> void:
	# Called after the host container has completed its layout pass.
	_on_resized()


func play_sequence(
	profile: Dictionary,
	item_icon_path: String,
	item_name: String
) -> void:
	if _busy:
		return
	_busy = true
	_reset_sequence_visuals()

	var rarity_id: String = str(profile.get("id", "rare"))
	sequence_started.emit(rarity_id)

	var center_point: Vector2 = _effect_center()
	var base_size: float = _base_effect_size()
	var accent: Color = profile.get("accent", Color(0.28, 0.95, 0.78, 1.0))
	var secondary: Color = profile.get("secondary", Color(0.98, 0.78, 0.30, 1.0))
	var mist_primary_tint: Color = profile.get("mist_primary_tint", accent)
	var mist_secondary_tint: Color = profile.get("mist_secondary_tint", secondary)
	var mist_tint_strength: float = float(profile.get("mist_tint_strength", 0.24))

	# PHASE 1 — INVOCATION
	# The ritual establishes place and mood, but every support layer stays outside
	# the relic's clean focal aperture. Native gold/jade art is preserved.
	var gateway: TextureRect = _spawn_texture(
		_back_layer,
		GATEWAY_PATH,
		Vector2(base_size * 1.10, base_size * 1.10),
		center_point,
		"mix"
	)
	var ritual: TextureRect = _spawn_texture(
		_ritual_layer,
		RITUAL_PATH,
		Vector2(base_size * 0.88, base_size * 0.88),
		center_point,
		"add"
	)
	var runic: TextureRect = _spawn_texture(
		_ritual_layer,
		RUNIC_PATH,
		Vector2(base_size * 0.66, base_size * 0.66),
		center_point,
		"add"
	)
	var seal: TextureRect = _spawn_texture(
		_ritual_layer,
		SEAL_PATH,
		Vector2(base_size * 0.78, base_size * 0.78),
		center_point,
		"add"
	)

	_set_sprite_start(gateway, 0.0, 0.84)
	_set_sprite_start(ritual, 0.0, 0.76)
	_set_sprite_start(runic, 0.0, 0.68)
	_set_sprite_start(seal, 0.0, 0.82)

	_tween_in(gateway, float(profile.get("gateway_peak_alpha", 0.34)), 1.0, 0.46)
	_tween_in(ritual, float(profile.get("ritual_peak_alpha", 0.76)), 1.0, 0.34)
	_tween_in(runic, 0.58, 1.0, 0.42, 0.05)
	_tween_in(seal, 0.30, 1.0, 0.44, 0.10)
	_spawn_peripheral_mist(
		center_point,
		base_size,
		float(profile.get("mist_peak_alpha", 0.075)),
		mist_primary_tint,
		mist_secondary_tint,
		mist_tint_strength
	)
	_spawn_layered_inward_sparks(
		int(profile.get("mote_count", 12)),
		center_point,
		base_size * 0.52,
		accent
	)
	_spawn_talismans(center_point, base_size, float(profile.get("talisman_peak_alpha", 0.34)))

	await get_tree().create_timer(float(profile.get("anticipation_duration", 0.82))).timeout

	# PHASE 2 — COMPRESSION / IMPACT
	# Energy compresses first, pauses very briefly, then releases. This gives the
	# impact weight without resorting to a full-screen whiteout.
	var impact_size := Vector2(base_size * 0.31, base_size * 0.31)
	var impact: TextureRect = _spawn_texture(
		_front_layer,
		IMPACT_PATH,
		impact_size,
		_optical_center(center_point, impact_size, IMPACT_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(impact, 0.0, 0.78)

	var impact_tween: Tween = create_tween()
	_track_tween(impact_tween)
	impact_tween.tween_property(
		impact,
		"modulate:a",
		float(profile.get("impact_peak_alpha", 0.78)),
		0.055
	)
	impact_tween.parallel().tween_property(
		impact,
		"scale",
		Vector2(0.52, 0.52),
		0.15
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	impact_tween.tween_interval(float(profile.get("impact_hold", 0.075)))
	impact_tween.tween_callback(
		Callable(self, "_release_rare_impact").bind(center_point, base_size, accent, secondary, profile)
	)
	impact_tween.tween_property(
		impact,
		"scale",
		Vector2(1.00, 1.00),
		0.12
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact_tween.parallel().tween_property(impact, "modulate:a", 0.22, 0.16)
	impact_tween.tween_property(impact, "modulate:a", 0.0, 0.11)

	await get_tree().create_timer(float(profile.get("reveal_delay", 0.24))).timeout

	# PHASE 3 — RELIC REVEAL
	# Production can consume the exact reveal cue and render its own resolved-item
	# detail card while this controller continues the locked afterglow motion.
	reveal_cue.emit(rarity_id)
	if not _external_relic_mode:
		_prepare_relic_card(item_icon_path, item_name, rarity_id, accent)
	var halo: TextureRect = _spawn_texture(
		_back_layer,
		HALO_PATH,
		Vector2(base_size * 0.72, base_size * 0.72),
		center_point,
		"add"
	)
	_set_sprite_start(halo, 0.0, 0.78)
	_tween_in(halo, float(profile.get("afterglow_peak_alpha", 0.20)), 1.0, 0.28)

	_fade_support_layer(gateway, 0.16, 0.24)
	_fade_support_layer(ritual, 0.20, 0.22)
	_fade_support_layer(runic, 0.16, 0.22)
	_fade_support_layer(seal, 0.10, 0.20)

	if not _external_relic_mode:
		_relic_panel.visible = true
		_relic_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_relic_panel.scale = Vector2(0.84, 0.84)
		var reveal_tween: Tween = create_tween().set_parallel(true)
		_track_tween(reveal_tween)
		var reveal_duration: float = float(profile.get("reveal_duration", 0.32))
		reveal_tween.tween_property(_relic_panel, "modulate:a", 1.0, reveal_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		reveal_tween.tween_property(_relic_panel, "scale", Vector2.ONE, reveal_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(float(profile.get("settle_duration", 0.78))).timeout
	_busy = false
	sequence_finished.emit(rarity_id)


func _build_layers() -> void:
	_back_layer = _make_layer("VFXBack")
	_ritual_layer = _make_layer("Altar")
	_relic_layer = _make_relic_layer()
	_front_layer = _make_layer("VFXFront")
	_screen_layer = _make_layer("ScreenFX")


func _make_relic_layer() -> CenterContainer:
	var layer := CenterContainer.new()
	layer.name = "RelicStage"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


func _make_layer(layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


func _build_relic_card() -> void:
	_relic_panel = PanelContainer.new()
	_relic_panel.name = "SummonRelicCard"
	# Fixed compact card: prevents the combined host/container from stretching the
	# result card vertically when rarity controllers are switched.
	_relic_panel.custom_minimum_size = Vector2(188.0, 238.0)
	_relic_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_relic_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_relic_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_panel.pivot_offset = Vector2(94.0, 119.0)
	_relic_layer.add_child(_relic_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.006, 0.028, 0.034, 0.94)
	panel_style.border_color = Color(0.30, 0.88, 0.72, 0.78)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.shadow_size = 12
	_relic_panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_relic_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	_relic_icon = TextureRect.new()
	_relic_icon.custom_minimum_size = Vector2(140.0, 140.0)
	_relic_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_relic_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_relic_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_relic_icon)

	_rarity_label = Label.new()
	_rarity_label.text = "RARE"
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity_label.add_theme_font_size_override("font_size", 13)
	stack.add_child(_rarity_label)

	_name_label = Label.new()
	_name_label.text = "MISTVEIL JIAN"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 16)
	stack.add_child(_name_label)

	_relic_panel.visible = false


func _prepare_relic_card(
	item_icon_path: String,
	item_name: String,
	rarity_id: String,
	accent: Color
) -> void:
	_relic_icon.texture = load(item_icon_path) as Texture2D
	_name_label.text = item_name.to_upper()
	_rarity_label.text = rarity_id.to_upper()
	_rarity_label.add_theme_color_override("font_color", accent)
	_name_label.add_theme_color_override("font_color", Color(0.94, 0.98, 0.96, 1.0))


func _reset_sequence_visuals() -> void:
	for tween: Tween in _active_tweens:
		if tween != null:
			tween.kill()
	_active_tweens.clear()

	for node: Node in _ephemeral_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_ephemeral_nodes.clear()

	_relic_panel.visible = false
	_relic_panel.modulate = Color.WHITE
	_relic_panel.scale = Vector2.ONE
	_on_resized()


func _spawn_texture(
	parent_layer: Control,
	path: String,
	target_size: Vector2,
	center_point: Vector2,
	blend_mode: String
) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = load(path) as Texture2D
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.size = target_size
	sprite.position = center_point - target_size * 0.5
	sprite.pivot_offset = target_size * 0.5
	if blend_mode == "add":
		var canvas_material := CanvasItemMaterial.new()
		canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = canvas_material
	parent_layer.add_child(sprite)
	_ephemeral_nodes.append(sprite)
	return sprite


func _set_sprite_start(sprite: Control, alpha_value: float, scale_value: float) -> void:
	sprite.modulate = Color(1.0, 1.0, 1.0, alpha_value)
	sprite.scale = Vector2(scale_value, scale_value)


func _tween_in(
	sprite: Control,
	peak_alpha: float,
	target_scale: float,
	duration: float,
	delay: float = 0.0
) -> void:
	var tween: Tween = create_tween()
	_track_tween(tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", peak_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(target_scale, target_scale), duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _tween_mist(
	mist: Control,
	peak_alpha: float,
	drift: Vector2,
	duration: float
) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	_track_tween(tween)
	tween.tween_property(mist, "modulate:a", peak_alpha, 0.46).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mist, "position", mist.position + drift, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(mist, "scale", Vector2(1.03, 1.03), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _spawn_peripheral_mist(
	center_point: Vector2,
	base_size: float,
	peak_alpha: float,
	primary_tint: Color = Color.WHITE,
	secondary_tint: Color = Color.WHITE,
	tint_strength: float = 0.0
) -> void:
	# Two side wisps + one faint lower wisp. The approved mist art has a strong
	# lower-right visual mass, so every plane receives an optical-center correction.
	# Nothing is allowed to cross the relic aperture.
	var placements: Array[Dictionary] = [
		{
			"size": Vector2(base_size * 0.34, base_size * 0.34),
			"offset": Vector2(-base_size * 0.43, base_size * 0.13),
			"drift": Vector2(base_size * 0.035, -base_size * 0.018),
			"alpha": peak_alpha,
			"rotation": -0.055,
			"tint_mix": 0.00,
		},
		{
			"size": Vector2(base_size * 0.31, base_size * 0.31),
			"offset": Vector2(base_size * 0.44, base_size * 0.10),
			"drift": Vector2(-base_size * 0.032, -base_size * 0.015),
			"alpha": peak_alpha * 0.82,
			"rotation": 0.050,
			"tint_mix": 0.35,
		},
		{
			"size": Vector2(base_size * 0.27, base_size * 0.27),
			"offset": Vector2(-base_size * 0.03, base_size * 0.43),
			"drift": Vector2(base_size * 0.020, -base_size * 0.025),
			"alpha": peak_alpha * 0.46,
			"rotation": 0.015,
			"tint_mix": 0.78,
		},
	]

	for placement: Dictionary in placements:
		var mist_size: Vector2 = placement["size"]
		var mist_offset: Vector2 = placement["offset"]
		var mist_drift: Vector2 = placement["drift"]
		var desired_center: Vector2 = center_point + mist_offset
		var mist: TextureRect = _spawn_texture(
			_back_layer,
			MIST_PATH,
			mist_size,
			_optical_center(desired_center, mist_size, MIST_OPTICAL_OFFSET),
			"mix"
		)
		var mist_tint: Color = _resolve_mist_tint(
			primary_tint,
			secondary_tint,
			float(placement.get("tint_mix", 0.0)),
			tint_strength
		)
		mist.rotation = float(placement["rotation"])
		mist.modulate = Color(mist_tint.r, mist_tint.g, mist_tint.b, 0.0)
		mist.scale = Vector2(0.96, 0.96)
		_tween_mist(
			mist,
			float(placement["alpha"]),
			mist_drift,
			1.52
		)


func _resolve_mist_tint(
	primary_tint: Color,
	secondary_tint: Color,
	mix_amount: float,
	tint_strength: float
) -> Color:
	var equipment_tint: Color = primary_tint.lerp(secondary_tint, clamp(mix_amount, 0.0, 1.0))
	var weighted_strength: float = clamp(tint_strength, 0.0, 0.60)
	return Color.WHITE.lerp(equipment_tint, weighted_strength)


func _spawn_talismans(center_point: Vector2, base_size: float, peak_alpha: float) -> void:
	# Two small peripheral talismans only. Their full artwork stays inside the
	# stage and they clear before impact/reveal so they can never become hero art.
	for index: int in range(2):
		var side: float = -1.0 if index == 0 else 1.0
		var talisman_size := Vector2(base_size * 0.060, base_size * 0.084)
		var start_center := center_point + Vector2(
			side * base_size * 0.40,
			-base_size * 0.11 + float(index) * base_size * 0.025
		)
		var talisman: TextureRect = _spawn_texture(
			_front_layer,
			TALISMAN_PATH,
			talisman_size,
			_optical_center(start_center, talisman_size, TALISMAN_OPTICAL_OFFSET),
			"mix"
		)
		talisman.modulate = Color(1.0, 1.0, 1.0, 0.0)
		talisman.rotation = side * 0.055

		var travel := Vector2(-side * base_size * 0.075, -base_size * 0.035)
		var tween: Tween = create_tween()
		_track_tween(tween)
		tween.tween_interval(float(index) * 0.060)
		tween.tween_property(talisman, "modulate:a", peak_alpha, 0.14)
		tween.parallel().tween_property(
			talisman,
			"position",
			talisman.position + travel,
			0.34
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(
			talisman,
			"rotation",
			-side * 0.020,
			0.34
		)
		tween.tween_property(talisman, "modulate:a", 0.0, 0.20)


func _spawn_layered_inward_sparks(
	count: int,
	center_point: Vector2,
	radius: float,
	accent: Color
) -> void:
	# Deterministic golden-angle distribution avoids the synthetic spoke pattern
	# while remaining stable between replays. Three tiers give depth at 405x860.
	for index: int in range(count):
		var tier: int = index % 3
		var angle: float = float(index) * 2.39996323 + 0.21
		var radial_jitter: float = float((index * 37) % 100) / 100.0
		var start_radius: float = radius * (0.76 + radial_jitter * 0.22)
		var start_point := center_point + Vector2(cos(angle), sin(angle)) * start_radius
		var spark := ColorRect.new()
		var spark_size := Vector2(1.8, 1.8)
		if tier == 1:
			spark_size = Vector2(2.8, 2.8)
		elif tier == 2:
			spark_size = Vector2(5.5, 1.25)
		spark.size = spark_size
		spark.pivot_offset = spark_size * 0.5
		spark.position = start_point - spark_size * 0.5
		spark.rotation = angle + PI * 0.5 if tier == 2 else 0.0
		spark.color = Color(accent.r, accent.g, accent.b, 0.0)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front_layer.add_child(spark)
		_ephemeral_nodes.append(spark)

		var target_radius: float = _base_target_radius(tier)
		var tangent := Vector2(-sin(angle), cos(angle)) * (3.0 + float(index % 4) * 1.5)
		var target_point := center_point + Vector2(cos(angle), sin(angle)) * target_radius + tangent
		var peak_alpha: float = 0.36 if tier == 0 else (0.52 if tier == 1 else 0.30)
		var duration: float = 0.50 + float(index % 5) * 0.032
		var tween: Tween = create_tween()
		_track_tween(tween)
		tween.tween_interval(float((index * 5) % 9) * 0.018)
		tween.tween_property(spark, "color:a", peak_alpha, 0.085)
		tween.parallel().tween_property(
			spark,
			"position",
			target_point - spark_size * 0.5,
			duration
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tween.tween_property(spark, "color:a", 0.0, 0.08)


func _base_target_radius(tier: int) -> float:
	match tier:
		0:
			return 16.0
		1:
			return 12.0
		_:
			return 20.0


func _release_rare_impact(
	center_point: Vector2,
	base_size: float,
	accent: Color,
	secondary: Color,
	profile: Dictionary
) -> void:
	_spawn_soft_shockwave(center_point, base_size)
	_spawn_safe_light_streak(
		center_point,
		base_size,
		float(profile.get("light_streak_peak_alpha", 0.50))
	)
	_spawn_reveal_burst(
		center_point,
		base_size,
		float(profile.get("burst_peak_alpha", 0.78))
	)
	_spawn_release_sparks(center_point, base_size, accent)
	_flash_screen(secondary, 0.055, 0.022, 0.10)


func _spawn_soft_shockwave(center_point: Vector2, base_size: float) -> void:
	# One readable premium ripple plus a faint delayed echo. No procedural circle
	# is drawn, and both layers disappear before the relic becomes dominant.
	var configs: Array[Dictionary] = [
		{"size": 0.38, "alpha": 0.18, "delay": 0.0, "from": 0.48, "to": 1.34, "time": 0.30},
		{"size": 0.42, "alpha": 0.075, "delay": 0.055, "from": 0.56, "to": 1.42, "time": 0.34},
	]
	for config: Dictionary in configs:
		var diameter: float = base_size * float(config["size"])
		var wave: TextureRect = _spawn_texture(
			_front_layer,
			HALO_PATH,
			Vector2(diameter, diameter),
			center_point,
			"add"
		)
		_set_sprite_start(wave, 0.0, float(config["from"]))
		var tween: Tween = create_tween()
		_track_tween(tween)
		tween.tween_interval(float(config["delay"]))
		tween.tween_property(wave, "modulate:a", float(config["alpha"]), 0.028)
		tween.parallel().tween_property(
			wave,
			"scale",
			Vector2(float(config["to"]), float(config["to"])),
			float(config["time"])
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(wave, "modulate:a", 0.0, 0.11)


func _spawn_safe_light_streak(center_point: Vector2, base_size: float, peak_alpha: float) -> void:
	# The approved streak source is 2:1. Keep that aspect ratio and the complete
	# artwork inside the safe composition; only a subtle afterimage follows it.
	var streak_size := Vector2(base_size * 0.32, base_size * 0.16)
	var start_visual_center := center_point + Vector2(-base_size * 0.12, base_size * 0.025)
	var end_visual_center := center_point + Vector2(base_size * 0.12, -base_size * 0.035)

	for index: int in range(2):
		var local_size: Vector2 = streak_size * (1.0 - float(index) * 0.06)
		var start_center: Vector2 = _optical_center(
			start_visual_center + Vector2(-float(index) * 3.0, float(index) * 2.0),
			local_size,
			STREAK_OPTICAL_OFFSET
		)
		var end_center: Vector2 = _optical_center(
			end_visual_center,
			local_size,
			STREAK_OPTICAL_OFFSET
		)
		var streak: TextureRect = _spawn_texture(
			_front_layer,
			STREAK_PATH,
			local_size,
			start_center,
			"add"
		)
		streak.modulate = Color(1.0, 1.0, 1.0, 0.0)
		streak.rotation = -0.075 + float(index) * 0.012
		var tween: Tween = create_tween()
		_track_tween(tween)
		tween.tween_interval(float(index) * 0.040)
		tween.tween_property(streak, "modulate:a", peak_alpha - float(index) * 0.22, 0.025)
		tween.parallel().tween_property(
			streak,
			"position",
			end_center - local_size * 0.5,
			0.25 + float(index) * 0.025
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(streak, "modulate:a", 0.0, 0.09)


func _spawn_reveal_burst(center_point: Vector2, base_size: float, peak_alpha: float) -> void:
	# The source artwork's bright mass is ~3.4% right / 1.5% down from its PNG
	# center. Correct that here so Impact Core -> Burst -> Relic share one perceived
	# origin and the reveal never appears to jump to a different point.
	var burst_size := Vector2(base_size * 0.50, base_size * 0.50)
	var burst: TextureRect = _spawn_texture(
		_front_layer,
		BURST_PATH,
		burst_size,
		_optical_center(center_point, burst_size, BURST_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(burst, 0.0, 0.38)
	var tween: Tween = create_tween()
	_track_tween(tween)
	tween.tween_property(burst, "modulate:a", peak_alpha, 0.028)
	tween.parallel().tween_property(
		burst,
		"scale",
		Vector2(0.84, 0.84),
		0.13
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 0.16, 0.10)
	tween.tween_property(burst, "modulate:a", 0.0, 0.14)

	# Short clean shimmer ties the burst to the same focal point without adding fog.
	var afterglow: TextureRect = _spawn_texture(
		_back_layer,
		HALO_PATH,
		Vector2(base_size * 0.38, base_size * 0.38),
		center_point,
		"add"
	)
	_set_sprite_start(afterglow, 0.0, 0.62)
	var glow_tween: Tween = create_tween()
	_track_tween(glow_tween)
	glow_tween.tween_property(afterglow, "modulate:a", 0.095, 0.045)
	glow_tween.parallel().tween_property(afterglow, "scale", Vector2(1.08, 1.08), 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	glow_tween.tween_property(afterglow, "modulate:a", 0.0, 0.16)


func _spawn_release_sparks(
	center_point: Vector2,
	base_size: float,
	accent: Color
) -> void:
	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0 + 0.18
		var spark := ColorRect.new()
		spark.size = Vector2(6.0, 1.4)
		spark.pivot_offset = spark.size * 0.5
		spark.position = center_point - spark.size * 0.5
		spark.rotation = angle
		spark.color = Color(accent.r, accent.g, accent.b, 0.0)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front_layer.add_child(spark)
		_ephemeral_nodes.append(spark)
		var distance: float = base_size * (0.16 + float(index % 2) * 0.035)
		var endpoint := center_point + Vector2(cos(angle), sin(angle)) * distance
		var tween: Tween = create_tween()
		_track_tween(tween)
		tween.tween_property(spark, "color:a", 0.42, 0.025)
		tween.parallel().tween_property(
			spark,
			"position",
			endpoint - spark.size * 0.5,
			0.24
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "color:a", 0.0, 0.09)


func _fade_support_layer(sprite: Control, target_alpha: float, duration: float) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var tween: Tween = create_tween()
	_track_tween(tween)
	tween.tween_property(sprite, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _flash_screen(
	color_value: Color,
	peak_alpha: float,
	attack: float,
	release: float
) -> void:
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(color_value.r, color_value.g, color_value.b, 0.0)
	_screen_layer.add_child(flash)
	_ephemeral_nodes.append(flash)
	var tween: Tween = create_tween()
	_track_tween(tween)
	tween.tween_property(flash, "color:a", peak_alpha, attack)
	tween.tween_property(flash, "color:a", 0.0, release)


func _optical_center(
	desired_visual_center: Vector2,
	target_size: Vector2,
	normalized_bright_offset: Vector2
) -> Vector2:
	return desired_visual_center - Vector2(
		target_size.x * normalized_bright_offset.x,
		target_size.y * normalized_bright_offset.y
	)


func _track_tween(tween: Tween) -> void:
	_active_tweens.append(tween)


func _effect_center() -> Vector2:
	return Vector2(size.x * 0.50, size.y * 0.45)


func _base_effect_size() -> float:
	# Avoid forcing oversized artwork on the common 405x860 debug window.
	return clampf(minf(size.x * 0.60, size.y * 0.50), 210.0, 360.0)


func _on_resized() -> void:
	if _relic_panel == null:
		return
	# RelicStage is a full-rect CenterContainer. It owns card positioning, while
	# the fixed pivot keeps reveal scaling centered and independent of host resize.
	_relic_panel.pivot_offset = Vector2(94.0, 119.0)
