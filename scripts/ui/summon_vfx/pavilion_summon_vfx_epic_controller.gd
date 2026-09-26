extends "res://scripts/ui/summon_vfx/pavilion_summon_vfx_controller.gd"

## Epic vertical-slice controller.
## Reuses the Rare-locked shared composition contract, then escalates with the
## approved Violet Constellation / Spiral Qi / Epic Seal / Crack Light assets.
## Presentation-only: no PavilionManager, economy, pity, inventory, or save calls.

const EPIC_ROOT: String = "res://assets/ui/pavilion/vfx/epic/"
const CONSTELLATION_PATH: String = EPIC_ROOT + "violet_constellation_ring.png"
const SPIRAL_PATH: String = EPIC_ROOT + "violet_spiral_qi.png"
const EPIC_SEAL_PATH: String = EPIC_ROOT + "epic_seal_complex.png"
const CRACK_PATH: String = EPIC_ROOT + "epic_crack_light.png"

# Alpha-weighted optical-center corrections measured from the separated
# production candidates. They keep every phase locked to one perceived origin.
const CONSTELLATION_OPTICAL_OFFSET: Vector2 = Vector2(0.0306, 0.0695)
const SPIRAL_OPTICAL_OFFSET: Vector2 = Vector2(-0.0283, 0.1026)
const EPIC_SEAL_OPTICAL_OFFSET: Vector2 = Vector2(0.0159, 0.1083)
const CRACK_OPTICAL_OFFSET: Vector2 = Vector2(0.0309, 0.1296)


func play_sequence(
	profile: Dictionary,
	item_icon_path: String,
	item_name: String
) -> void:
	if _busy:
		return
	_busy = true
	_reset_sequence_visuals()

	var rarity_id: String = "epic"
	sequence_started.emit(rarity_id)

	var center_point: Vector2 = _effect_center()
	var base_size: float = _base_effect_size()
	var accent: Color = profile.get("accent", Color(0.72, 0.48, 0.96, 1.0))
	var secondary: Color = profile.get("secondary", Color(0.98, 0.78, 0.30, 1.0))
	var mist_primary_tint: Color = profile.get("mist_primary_tint", accent)
	var mist_secondary_tint: Color = profile.get("mist_secondary_tint", secondary)
	var mist_tint_strength: float = float(profile.get("mist_tint_strength", 0.24))

	# PHASE 1 — SHARED FOUNDATION
	# The Rare-locked framing rules stay intact: all artwork is fully contained,
	# the focal center remains clear, and shared native gold/jade colors are not
	# globally violet-tinted.
	var gateway: TextureRect = _spawn_texture(
		_back_layer,
		GATEWAY_PATH,
		Vector2(base_size * 1.06, base_size * 1.06),
		center_point,
		"mix"
	)
	var ritual: TextureRect = _spawn_texture(
		_ritual_layer,
		RITUAL_PATH,
		Vector2(base_size * 0.82, base_size * 0.82),
		center_point,
		"add"
	)
	var runic: TextureRect = _spawn_texture(
		_ritual_layer,
		RUNIC_PATH,
		Vector2(base_size * 0.60, base_size * 0.60),
		center_point,
		"add"
	)
	var seal: TextureRect = _spawn_texture(
		_ritual_layer,
		SEAL_PATH,
		Vector2(base_size * 0.70, base_size * 0.70),
		center_point,
		"add"
	)

	_set_sprite_start(gateway, 0.0, 0.86)
	_set_sprite_start(ritual, 0.0, 0.80)
	_set_sprite_start(runic, 0.0, 0.74)
	_set_sprite_start(seal, 0.0, 0.84)

	_tween_in(gateway, float(profile.get("gateway_peak_alpha", 0.28)), 1.0, 0.48)
	_tween_in(ritual, float(profile.get("ritual_peak_alpha", 0.54)), 1.0, 0.38)
	_tween_in(runic, 0.34, 1.0, 0.42, 0.04)
	_tween_in(seal, 0.18, 1.0, 0.44, 0.08)
	_spawn_peripheral_mist(
		center_point,
		base_size,
		float(profile.get("mist_peak_alpha", 0.045)),
		mist_primary_tint,
		mist_secondary_tint,
		mist_tint_strength
	)
	_spawn_layered_inward_sparks(
		int(profile.get("mote_count", 18)),
		center_point,
		base_size * 0.56,
		accent
	)

	# PHASE 1B — EPIC MANIFESTATION
	# Epic must be visibly different from Rare, not merely recolored. The spiral
	# establishes flowing violet qi, the constellation ring maps the omen, and
	# the complex seal arrives last as the ritual locks.
	var spiral_size := Vector2(base_size * 0.92, base_size * 0.49)
	var spiral: TextureRect = _spawn_texture(
		_back_layer,
		SPIRAL_PATH,
		spiral_size,
		_optical_center(center_point + Vector2(0.0, base_size * 0.015), spiral_size, SPIRAL_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(spiral, 0.0, 0.88)
	var spiral_tween: Tween = create_tween().set_parallel(true)
	_track_tween(spiral_tween)
	spiral_tween.tween_property(
		spiral,
		"modulate:a",
		float(profile.get("spiral_peak_alpha", 0.22)),
		0.48
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	spiral_tween.tween_property(spiral, "scale", Vector2.ONE, 0.58).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	spiral_tween.tween_property(
		spiral,
		"position",
		spiral.position + Vector2(base_size * 0.018, -base_size * 0.010),
		0.82
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var ring_size := Vector2(base_size * 0.98, base_size * 0.50)
	var constellation: TextureRect = _spawn_texture(
		_ritual_layer,
		CONSTELLATION_PATH,
		ring_size,
		_optical_center(center_point, ring_size, CONSTELLATION_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(constellation, 0.0, 0.70)
	_tween_in(
		constellation,
		float(profile.get("constellation_peak_alpha", 0.54)),
		1.0,
		0.46,
		0.10
	)

	var epic_seal_size := Vector2(base_size * 0.82, base_size * 0.42)
	var epic_seal: TextureRect = _spawn_texture(
		_ritual_layer,
		EPIC_SEAL_PATH,
		epic_seal_size,
		_optical_center(center_point, epic_seal_size, EPIC_SEAL_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(epic_seal, 0.0, 0.66)
	_tween_in(
		epic_seal,
		float(profile.get("epic_seal_peak_alpha", 0.58)),
		1.0,
		0.40,
		0.30
	)

	await get_tree().create_timer(float(profile.get("anticipation_duration", 1.18))).timeout

	# PHASE 2 — COMPRESSION / EPIC FRACTURE
	var impact_size := Vector2(base_size * 0.34, base_size * 0.34)
	var impact: TextureRect = _spawn_texture(
		_front_layer,
		IMPACT_PATH,
		impact_size,
		_optical_center(center_point, impact_size, IMPACT_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(impact, 0.0, 0.80)

	var impact_tween: Tween = create_tween()
	_track_tween(impact_tween)
	impact_tween.tween_property(
		impact,
		"modulate:a",
		float(profile.get("impact_peak_alpha", 0.88)),
		0.055
	)
	impact_tween.parallel().tween_property(
		impact,
		"scale",
		Vector2(0.48, 0.48),
		0.17
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	impact_tween.tween_interval(float(profile.get("impact_hold", 0.09)))
	impact_tween.tween_callback(
		Callable(self, "_release_epic_impact").bind(
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
		Vector2(1.03, 1.03),
		0.13
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact_tween.parallel().tween_property(impact, "modulate:a", 0.18, 0.17)
	impact_tween.tween_property(impact, "modulate:a", 0.0, 0.12)

	await get_tree().create_timer(float(profile.get("reveal_delay", 0.42))).timeout

	# PHASE 3 — EPIC RELIC REVEAL
	reveal_cue.emit(rarity_id)
	if not _external_relic_mode:
		_prepare_relic_card(item_icon_path, item_name, rarity_id, accent)
		_apply_epic_relic_style(accent, secondary)

	var halo: TextureRect = _spawn_texture(
		_back_layer,
		HALO_PATH,
		Vector2(base_size * 0.76, base_size * 0.76),
		center_point,
		"add"
	)
	_set_sprite_start(halo, 0.0, 0.76)
	_tween_in(halo, float(profile.get("afterglow_peak_alpha", 0.22)), 1.0, 0.30)

	# Once the relic appears, every ritual layer steps down. The constellation
	# remains as a low-intensity Epic signature but never competes with the item.
	_fade_support_layer(gateway, 0.12, 0.24)
	_fade_support_layer(ritual, 0.12, 0.22)
	_fade_support_layer(runic, 0.08, 0.22)
	_fade_support_layer(seal, 0.06, 0.20)
	_fade_support_layer(spiral, 0.05, 0.24)
	_fade_support_layer(epic_seal, 0.08, 0.22)
	_fade_support_layer(constellation, 0.18, 0.26)

	if not _external_relic_mode:
		_relic_panel.visible = true
		_relic_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_relic_panel.scale = Vector2(0.80, 0.80)
		var reveal_tween: Tween = create_tween().set_parallel(true)
		_track_tween(reveal_tween)
		var reveal_duration: float = float(profile.get("reveal_duration", 0.38))
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

	await get_tree().create_timer(float(profile.get("settle_duration", 0.96))).timeout
	_busy = false
	sequence_finished.emit(rarity_id)


func _release_epic_impact(
	center_point: Vector2,
	base_size: float,
	accent: Color,
	secondary: Color,
	profile: Dictionary
) -> void:
	# The approved Crack Light is the Epic punctuation. It occupies the same safe
	# focal region as the impact and is corrected by its measured optical center.
	var crack_size := Vector2(base_size * 0.78, base_size * 0.41)
	var crack: TextureRect = _spawn_texture(
		_front_layer,
		CRACK_PATH,
		crack_size,
		_optical_center(center_point, crack_size, CRACK_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(crack, 0.0, 0.54)
	var crack_tween: Tween = create_tween()
	_track_tween(crack_tween)
	crack_tween.tween_property(
		crack,
		"modulate:a",
		float(profile.get("crack_peak_alpha", 0.78)),
		0.035
	)
	crack_tween.parallel().tween_property(
		crack,
		"scale",
		Vector2(0.96, 0.96),
		0.18
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	crack_tween.tween_property(crack, "modulate:a", 0.16, 0.12)
	crack_tween.tween_property(crack, "modulate:a", 0.0, 0.16)

	_spawn_epic_constellation_pulse(center_point, base_size)
	_spawn_soft_shockwave(center_point, base_size)
	_spawn_reveal_burst(
		center_point,
		base_size,
		float(profile.get("burst_peak_alpha", 0.56))
	)
	_spawn_release_sparks(center_point, base_size, accent)
	_flash_screen(accent, 0.070, 0.024, 0.12)
	_flash_screen(secondary, 0.028, 0.020, 0.09)


func _spawn_epic_constellation_pulse(center_point: Vector2, base_size: float) -> void:
	var pulse_size := Vector2(base_size * 0.72, base_size * 0.37)
	var pulse: TextureRect = _spawn_texture(
		_front_layer,
		CONSTELLATION_PATH,
		pulse_size,
		_optical_center(center_point, pulse_size, CONSTELLATION_OPTICAL_OFFSET),
		"add"
	)
	_set_sprite_start(pulse, 0.0, 0.42)
	var tween: Tween = create_tween()
	_track_tween(tween)
	tween.tween_property(pulse, "modulate:a", 0.28, 0.030)
	tween.parallel().tween_property(
		pulse,
		"scale",
		Vector2(1.20, 1.20),
		0.34
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.14)


func _apply_epic_relic_style(accent: Color, secondary: Color) -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.010, 0.010, 0.032, 0.96)
	panel_style.border_color = Color(accent.r, accent.g, accent.b, 0.88)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.shadow_color = Color(secondary.r, secondary.g, secondary.b, 0.18)
	panel_style.shadow_size = 14
	_relic_panel.add_theme_stylebox_override("panel", panel_style)
