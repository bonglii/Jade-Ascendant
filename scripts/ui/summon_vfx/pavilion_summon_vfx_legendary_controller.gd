extends "res://scripts/ui/summon_vfx/pavilion_summon_vfx_controller.gd"

## Legendary vertical-slice controller.
## Rare + Epic motion remain locked. This layer escalates the same safe composition
## contract into Celestial Mandate Descends using the approved Legendary pack.
## Presentation-only: no PavilionManager, economy, pity, inventory, or save calls.

const LEGENDARY_ROOT: String = "res://assets/ui/pavilion/vfx/legendary/"
const MANDALA_PATH: String = LEGENDARY_ROOT + "heavenly_mandala.png"
const BEAM_CORE_PATH: String = LEGENDARY_ROOT + "heavenly_beam_core.png"
const BEAM_SOFT_PATH: String = LEGENDARY_ROOT + "heavenly_beam_soft.png"
const SEAL_FRAGMENT_PATH: String = LEGENDARY_ROOT + "legendary_seal_fragments.png"
const DIVINE_SPARK_PATH: String = LEGENDARY_ROOT + "divine_spark.png"
const CELESTIAL_CREST_PATH: String = LEGENDARY_ROOT + "celestial_crest.png"
const DRAGON_PATH: String = LEGENDARY_ROOT + "dragon_spirit_silhouette.png"
const RESULT_HALO_PATH: String = LEGENDARY_ROOT + "legendary_result_halo.png"

# Alpha-weighted optical-center corrections measured from the separated assets.
const MANDALA_OPTICAL_OFFSET: Vector2 = Vector2(0.0200, 0.0299)
const BEAM_CORE_OPTICAL_OFFSET: Vector2 = Vector2(0.0500, 0.0892)
const BEAM_SOFT_OPTICAL_OFFSET: Vector2 = Vector2(-0.0370, 0.0738)
const SEAL_FRAGMENT_OPTICAL_OFFSET: Vector2 = Vector2(-0.0544, 0.0504)
const DIVINE_SPARK_OPTICAL_OFFSET: Vector2 = Vector2(0.0061, 0.0409)
const CREST_OPTICAL_OFFSET: Vector2 = Vector2(-0.0076, 0.0662)
const DRAGON_OPTICAL_OFFSET: Vector2 = Vector2(-0.0329, 0.0194)
const RESULT_HALO_OPTICAL_OFFSET: Vector2 = Vector2(0.0163, 0.0704)


func play_sequence(
	profile: Dictionary,
	item_icon_path: String,
	item_name: String
) -> void:
	if _busy:
		return
	_busy = true
	_reset_sequence_visuals()

	var rarity_id: String = "legendary"
	sequence_started.emit(rarity_id)

	var center_point: Vector2 = _effect_center()
	var base_size: float = _base_effect_size()
	var accent: Color = profile.get("accent", Color(1.0, 0.76, 0.24, 1.0))
	var secondary: Color = profile.get("secondary", Color(0.84, 0.96, 1.0, 1.0))
	var mist_primary_tint: Color = profile.get("mist_primary_tint", accent)
	var mist_secondary_tint: Color = profile.get("mist_secondary_tint", secondary)
	var mist_tint_strength: float = float(profile.get("mist_tint_strength", 0.18))

	# PHASE 1 — SHARED FOUNDATION
	# Shared layers stay lower than Rare/Epic so Legendary-specific celestial art
	# owns the event without turning the whole screen into a bright texture stack.
	var gateway: TextureRect = _spawn_texture(
		_back_layer,
		GATEWAY_PATH,
		Vector2(base_size * 1.02, base_size * 1.02),
		center_point,
		"mix"
	)
	var ritual: TextureRect = _spawn_texture(
		_ritual_layer,
		RITUAL_PATH,
		Vector2(base_size * 0.78, base_size * 0.78),
		center_point,
		"add"
	)
	var runic: TextureRect = _spawn_texture(
		_ritual_layer,
		RUNIC_PATH,
		Vector2(base_size * 0.56, base_size * 0.56),
		center_point,
		"add"
	)
	var seal: TextureRect = _spawn_texture(
		_ritual_layer,
		SEAL_PATH,
		Vector2(base_size * 0.64, base_size * 0.64),
		center_point,
		"add"
	)

	_set_sprite_start(gateway, 0.0, 0.84)
	_set_sprite_start(ritual, 0.0, 0.78)
	_set_sprite_start(runic, 0.0, 0.70)
	_set_sprite_start(seal, 0.0, 0.80)

	_tween_in(gateway, float(profile.get("gateway_peak_alpha", 0.22)), 1.0, 0.50)
	_tween_in(ritual, float(profile.get("ritual_peak_alpha", 0.42)), 1.0, 0.42)
	_tween_in(runic, 0.28, 1.0, 0.44, 0.06)
	_tween_in(seal, 0.14, 1.0, 0.46, 0.10)
	_spawn_peripheral_mist(
		center_point,
		base_size,
		float(profile.get("mist_peak_alpha", 0.032)),
		mist_primary_tint,
		mist_secondary_tint,
		mist_tint_strength
	)
	_spawn_layered_inward_sparks(
		int(profile.get("mote_count", 20)),
		center_point,
		base_size * 0.58,
		accent
	)

	# PHASE 1B — CELESTIAL MANDATE FORMS
	var mandala_size := Vector2(base_size * 1.00, base_size * 0.83)
	var mandala: TextureRect = _spawn_texture(
		_ritual_layer,
		MANDALA_PATH,
		mandala_size,
		_optical_center(center_point, mandala_size, MANDALA_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(mandala, 0.0, 0.66)
	_tween_in(
		mandala,
		float(profile.get("mandala_peak_alpha", 0.62)),
		1.0,
		0.62,
		0.08
	)

	var beam_soft_size := Vector2(base_size * 0.74, base_size * 1.08)
	var beam_soft_center := center_point + Vector2(0.0, -base_size * 0.05)
	var beam_soft: TextureRect = _spawn_texture(
		_back_layer,
		BEAM_SOFT_PATH,
		beam_soft_size,
		_optical_center(beam_soft_center, beam_soft_size, BEAM_SOFT_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(beam_soft, 0.0, 0.90)
	_tween_in(
		beam_soft,
		float(profile.get("beam_soft_peak_alpha", 0.20)),
		1.0,
		0.72,
		0.18
	)

	var fragment_size := Vector2(base_size * 0.82, base_size * 0.51)
	var fragments: TextureRect = _spawn_texture(
		_front_layer,
		SEAL_FRAGMENT_PATH,
		fragment_size,
		_optical_center(center_point, fragment_size, SEAL_FRAGMENT_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(fragments, 0.0, 1.12)
	var fragment_tween: Tween = create_tween().set_parallel(true)
	_track_tween(fragment_tween)
	fragment_tween.tween_property(
		fragments,
		"modulate:a",
		float(profile.get("seal_fragment_peak_alpha", 0.28)),
		0.46
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fragment_tween.tween_property(
		fragments,
		"scale",
		Vector2(0.92, 0.92),
		0.86
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	var spark_size := Vector2(base_size * 0.86, base_size * 0.60)
	var divine_spark: TextureRect = _spawn_texture(
		_front_layer,
		DIVINE_SPARK_PATH,
		spark_size,
		_optical_center(center_point, spark_size, DIVINE_SPARK_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(divine_spark, 0.0, 0.92)
	_tween_in(
		divine_spark,
		float(profile.get("divine_spark_peak_alpha", 0.24)),
		1.0,
		0.52,
		0.34
	)

	await get_tree().create_timer(float(profile.get("anticipation_duration", 1.55))).timeout

	# PHASE 2 — MANDATE DESCENDS / COMPRESSION
	var impact_size := Vector2(base_size * 0.30, base_size * 0.30)
	var impact: TextureRect = _spawn_texture(
		_front_layer,
		IMPACT_PATH,
		impact_size,
		_optical_center(center_point, impact_size, IMPACT_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(impact, 0.0, 0.84)

	var impact_tween: Tween = create_tween()
	_track_tween(impact_tween)
	impact_tween.tween_property(
		impact,
		"modulate:a",
		float(profile.get("impact_peak_alpha", 0.94)),
		0.050
	)
	impact_tween.parallel().tween_property(
		impact,
		"scale",
		Vector2(0.42, 0.42),
		0.20
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	impact_tween.tween_interval(float(profile.get("impact_hold", 0.12)))
	impact_tween.tween_callback(
		Callable(self, "_release_legendary_impact").bind(
			center_point,
			base_size,
			accent,
			secondary,
			profile
		)
	)
	impact_tween.tween_property(
		impact,
		"scale",
		Vector2(1.08, 1.08),
		0.15
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact_tween.parallel().tween_property(impact, "modulate:a", 0.16, 0.18)
	impact_tween.tween_property(impact, "modulate:a", 0.0, 0.12)

	await get_tree().create_timer(float(profile.get("reveal_delay", 0.58))).timeout

	# PHASE 3 — LEGENDARY RELIC REVEAL
	reveal_cue.emit(rarity_id)
	if not _external_relic_mode:
		_prepare_relic_card(item_icon_path, item_name, rarity_id, accent)
		_apply_legendary_relic_style(accent, secondary)

	var result_halo_size := Vector2(base_size * 0.98, base_size * 0.69)
	var result_halo: TextureRect = _spawn_texture(
		_back_layer,
		RESULT_HALO_PATH,
		result_halo_size,
		_optical_center(center_point, result_halo_size, RESULT_HALO_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(result_halo, 0.0, 0.76)
	_tween_in(
		result_halo,
		float(profile.get("result_halo_peak_alpha", 0.42)),
		1.0,
		0.36
	)

	var crest_size := Vector2(base_size * 0.68, base_size * 0.47)
	var crest: TextureRect = _spawn_texture(
		_ritual_layer,
		CELESTIAL_CREST_PATH,
		crest_size,
		_optical_center(center_point, crest_size, CREST_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(crest, 0.0, 0.82)
	_tween_in(
		crest,
		float(profile.get("crest_reveal_alpha", 0.30)),
		1.0,
		0.34
	)

	# The relic becomes the only hero visual. The heavenly field remains present,
	# but every pre-reveal layer steps down decisively.
	_fade_support_layer(gateway, 0.08, 0.26)
	_fade_support_layer(ritual, 0.08, 0.24)
	_fade_support_layer(runic, 0.05, 0.22)
	_fade_support_layer(seal, 0.04, 0.20)
	_fade_support_layer(mandala, 0.16, 0.28)
	_fade_support_layer(beam_soft, 0.05, 0.28)
	_fade_support_layer(fragments, 0.04, 0.20)
	_fade_support_layer(divine_spark, 0.08, 0.22)

	if not _external_relic_mode:
		_relic_panel.visible = true
		_relic_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_relic_panel.scale = Vector2(0.74, 0.74)
		var reveal_tween: Tween = create_tween().set_parallel(true)
		_track_tween(reveal_tween)
		var reveal_duration: float = float(profile.get("reveal_duration", 0.46))
		reveal_tween.tween_property(
			_relic_panel,
			"modulate:a",
			1.0,
			reveal_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		reveal_tween.tween_property(
			_relic_panel,
			"scale",
			Vector2.ONE,
			reveal_duration
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(float(profile.get("settle_duration", 1.28))).timeout
	_busy = false
	sequence_finished.emit(rarity_id)


func _release_legendary_impact(
	center_point: Vector2,
	base_size: float,
	accent: Color,
	secondary: Color,
	profile: Dictionary
) -> void:
	# Vertical beam is the Legendary punctuation. It is tall but fully contained
	# inside the safe stage; no full-screen whiteout is used.
	var beam_size := Vector2(base_size * 0.62, base_size * 1.08)
	var beam_center := center_point + Vector2(0.0, -base_size * 0.05)
	var beam: TextureRect = _spawn_texture(
		_front_layer,
		BEAM_CORE_PATH,
		beam_size,
		_optical_center(beam_center, beam_size, BEAM_CORE_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(beam, 0.0, 0.82)
	var beam_tween: Tween = create_tween()
	_track_tween(beam_tween)
	beam_tween.tween_property(
		beam,
		"modulate:a",
		float(profile.get("beam_core_peak_alpha", 0.78)),
		0.040
	)
	beam_tween.parallel().tween_property(
		beam,
		"scale",
		Vector2(1.0, 1.0),
		0.20
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	beam_tween.tween_property(beam, "modulate:a", 0.18, 0.18)
	beam_tween.tween_property(beam, "modulate:a", 0.0, 0.20)

	_spawn_legendary_crest_pulse(center_point, base_size, profile)
	_spawn_legendary_dragon_apparition(center_point, base_size, profile)
	_spawn_legendary_result_pulse(center_point, base_size)
	_spawn_reveal_burst(
		center_point,
		base_size,
		float(profile.get("burst_peak_alpha", 0.68))
	)
	_spawn_release_sparks(center_point, base_size, accent)
	_flash_screen(accent, 0.105, 0.020, 0.14)
	_flash_screen(secondary, 0.040, 0.018, 0.10)


func _spawn_legendary_crest_pulse(
	center_point: Vector2,
	base_size: float,
	profile: Dictionary
) -> void:
	var crest_size := Vector2(base_size * 0.72, base_size * 0.50)
	var crest: TextureRect = _spawn_texture(
		_front_layer,
		CELESTIAL_CREST_PATH,
		crest_size,
		_optical_center(center_point, crest_size, CREST_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(crest, 0.0, 0.54)
	var tween: Tween = create_tween()
	_track_tween(tween)
	tween.tween_property(
		crest,
		"modulate:a",
		float(profile.get("crest_peak_alpha", 0.72)),
		0.035
	)
	tween.parallel().tween_property(
		crest,
		"scale",
		Vector2(1.10, 1.10),
		0.28
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(crest, "modulate:a", 0.10, 0.14)
	tween.tween_property(crest, "modulate:a", 0.0, 0.15)


func _spawn_legendary_dragon_apparition(
	center_point: Vector2,
	base_size: float,
	profile: Dictionary
) -> void:
	# Dragon is a brief celestial apparition, not a persistent background image.
	var dragon_size := Vector2(base_size * 1.06, base_size * 0.74)
	var dragon_center := center_point + Vector2(base_size * 0.04, -base_size * 0.05)
	var dragon: TextureRect = _spawn_texture(
		_back_layer,
		DRAGON_PATH,
		dragon_size,
		_optical_center(dragon_center, dragon_size, DRAGON_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(dragon, 0.0, 0.90)
	var tween: Tween = create_tween()
	_track_tween(tween)
	tween.tween_property(
		dragon,
		"modulate:a",
		float(profile.get("dragon_peak_alpha", 0.24)),
		0.10
	)
	tween.parallel().tween_property(
		dragon,
		"position",
		dragon.position + Vector2(-base_size * 0.025, -base_size * 0.018),
		0.42
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(dragon, "modulate:a", 0.0, 0.22)


func _spawn_legendary_result_pulse(center_point: Vector2, base_size: float) -> void:
	var halo_size := Vector2(base_size * 0.86, base_size * 0.60)
	var halo: TextureRect = _spawn_texture(
		_front_layer,
		RESULT_HALO_PATH,
		halo_size,
		_optical_center(center_point, halo_size, RESULT_HALO_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(halo, 0.0, 0.48)
	var tween: Tween = create_tween()
	_track_tween(tween)
	tween.tween_property(halo, "modulate:a", 0.36, 0.035)
	tween.parallel().tween_property(
		halo,
		"scale",
		Vector2(1.18, 1.18),
		0.34
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(halo, "modulate:a", 0.0, 0.16)


func _apply_legendary_relic_style(accent: Color, secondary: Color) -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.012, 0.004, 0.97)
	panel_style.border_color = Color(accent.r, accent.g, accent.b, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.shadow_color = Color(secondary.r, secondary.g, secondary.b, 0.16)
	panel_style.shadow_size = 16
	_relic_panel.add_theme_stylebox_override("panel", panel_style)
	_rarity_label.add_theme_color_override("font_color", accent)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0))
