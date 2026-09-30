extends "res://scripts/enemy/boss_1.gd"

## Realm IV/V boss. Never replaces base HP/phase/death/reward contracts.
## Distinct per-stage silhouette and a phase-2 exclusive signature pattern.
const RealmTelegraph = preload("res://scripts/enemy/realm_boss_telegraph.gd")
const BossArt = preload("res://scripts/data/realm_boss_visual_catalog.gd")
const FROST_CHARGE_ART: Texture2D = preload("res://assets/vfx/realm/frost_charge.png")
const SOLAR_CHARGE_ART: Texture2D = preload("res://assets/vfx/realm/solar_charge.png")

var realm_id: int = 4
var boss_stage_id: int = 1
var authored_patterns: Array[String] = []
var boss_signature: String = ""
var _previous_pattern: String = ""
var _strafe_side: float = 1.0

# Chapter IV-only presentation. No scene, damage, save or boss-spawn changes.
var _frost_visual_clock: float = 0.0
var _frost_redraw_left: float = 0.0
var _frost_intro_left: float = 0.0
var _first_phase_two_signature_pending: bool = false
var _body_ward: Sprite2D = null
var _body_ward_size: float = 0.0

# Realm 5 boss presence only. Stage/boss state is still owned by production systems.
var _solar_visual_clock: float = 0.0
var _solar_redraw_left: float = 0.0
var _solar_intro_left: float = 0.0

const SOLAR_BOSS_PALETTE = [
	Color(0.99, 0.78, 0.44), # 5-1: First Sun guard
	Color(1.00, 0.68, 0.30), # 5-2: Crucible king
	Color(1.00, 0.58, 0.42), # 5-3: Ashwing matriarch
	Color(0.85, 0.66, 0.81), # 5-4: Eclipse hierophant
	Color(1.00, 0.88, 0.55), # 5-5: Primordial sovereign
]

const FROST_BOSS_PALETTE = [
	Color(0.39, 0.89, 0.97), # 4-1: glacial pathkeeper
	Color(0.69, 0.70, 1.00), # 4-2: mirror abbot
	Color(0.61, 0.97, 0.91), # 4-3: lotus spirit
	Color(0.73, 0.82, 0.97), # 4-4: bell guardian
	Color(0.80, 0.94, 1.00), # 4-5: the sovereign
]


func configure_encounter(profile: Dictionary) -> void:
	super.configure_encounter(profile)
	realm_id = int(profile.get("realm_id", 4))
	boss_stage_id = int(profile.get("realm_stage_id", 1))
	boss_signature = str(profile.get("boss_signature", ""))
	authored_patterns.clear()
	var incoming: Array = profile.get("boss_patterns", [])
	for entry: Variant in incoming:
		var name_value: String = str(entry)
		if not name_value.is_empty() and name_value not in authored_patterns:
			authored_patterns.append(name_value)


func _apply_encounter_presentation() -> void:
	# Called by base _ready after the inherited AnimatedSprite2D node exists.
	var frames: SpriteFrames = BossArt.get_frames(realm_id, boss_stage_id)
	if frames == null:
		push_error("RealmBoss: missing art %d-%d" % [realm_id, boss_stage_id])
		return
	animated_sprite.sprite_frames = frames
	animated_sprite.position = Vector2(0.0, -27.0)
	# Chapter 4 art is fitted to its original 128x128 frames. The collider
	# remains the old production footprint, NOT the silhouette/weapon extent.
	if realm_id == 4:
		var scales: Array[float] = [1.48, 1.53, 1.56, 1.61, 1.78]
		var offsets: Array[float] = [-27.0, -29.0, -30.0, -30.0, -35.0]
		var art_idx: int = clampi(boss_stage_id - 1, 0, 4)
		animated_sprite.position = Vector2(0.0, offsets[art_idx])
		animated_sprite.scale = Vector2.ONE * scales[art_idx]
	elif realm_id == 5:
		# Keep the original collider. Scale only the painted figure/ornament.
		var solar_scales: Array[float] = [1.51, 1.64, 1.59, 1.65, 1.83]
		var solar_offsets: Array[float] = [-28.0, -31.0, -29.0, -31.0, -35.0]
		var solar_index: int = clampi(boss_stage_id - 1, 0, 4)
		animated_sprite.position = Vector2(0.0, solar_offsets[solar_index])
		animated_sprite.scale = Vector2.ONE * solar_scales[solar_index]
	else:
		animated_sprite.scale = Vector2(1.35, 1.35)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var footprint := CapsuleShape2D.new()
	footprint.radius = 21.0 if boss_stage_id < 5 else 23.0
	footprint.height = 49.0 if boss_stage_id < 5 else 54.0
	collision_shape.position = Vector2(0.0, 14.0)
	collision_shape.shape = footprint


func _get_attack_presentation_theme() -> String:
	# Applies only to fallback base boss spells; signature spells own their palette.
	return "nine_heavens" if realm_id == 4 else "crimson_moon"


func _ready() -> void:
	super._ready()
	if realm_id == 4:
		_frost_intro_left = 0.95
		queue_redraw()
	elif realm_id == 5:
		_solar_intro_left = 0.95
		queue_redraw()
	_create_body_ward()


func _process(delta: float) -> void:
	if is_dead:
		return
	if realm_id == 4:
		_frost_visual_clock += delta
		_frost_intro_left = maxf(0.0, _frost_intro_left - delta)
		_frost_redraw_left -= delta
		if _frost_redraw_left <= 0.0:
			# Keep the already-approved Chapter 4 behavior byte-equivalent.
			_frost_redraw_left = 0.25 if SettingsManager.reduced_effects else 0.085
			queue_redraw()
	elif realm_id == 5:
		_solar_visual_clock += delta
		_solar_intro_left = maxf(0.0, _solar_intro_left - delta)
		_solar_redraw_left -= delta
		if _solar_redraw_left <= 0.0:
			# Only the single active boss redraws at a bounded rate.
			_solar_redraw_left = 0.25 if SettingsManager.reduced_effects else 0.10
			queue_redraw()
	_update_body_ward()


## A restrained authored sigil behind the painted character. It is never an
## attack warning, never a collider, and never marks an AoE damage boundary.
func _create_body_ward() -> void:
	if realm_id not in [4, 5]:
		return
	_body_ward = Sprite2D.new()
	_body_ward.name = "RealmBossSanctuary"
	_body_ward.texture = FROST_CHARGE_ART if realm_id == 4 else SOLAR_CHARGE_ART
	_body_ward.show_behind_parent = true
	_body_ward.z_index = -1
	_body_ward.position = Vector2(0.0, -24.0)
	_body_ward.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_body_ward_size = 0.37 if boss_stage_id < 5 else 0.48
	_body_ward.scale = Vector2.ONE * _body_ward_size
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_body_ward.material = additive
	add_child(_body_ward)
	_update_body_ward()


func _update_body_ward() -> void:
	if not is_instance_valid(_body_ward):
		return
	var t: float = _frost_visual_clock if realm_id == 4 else _solar_visual_clock
	var second_phase: bool = current_phase == PHASE_TWO
	var entrance: float = maxf(_frost_intro_left, _solar_intro_left)
	var power: float = 0.15 if not second_phase else 0.31
	power += 0.32 * clampf(entrance / 0.95, 0.0, 1.0)
	if phase_transition_timer > 0.0:
		power = maxf(power, 0.52)
	if SettingsManager.reduced_effects:
		power *= 0.33
	_body_ward.modulate = Color(1.0, 1.0, 1.0, power)
	if not SettingsManager.reduced_effects:
		_body_ward.scale = Vector2.ONE * _body_ward_size * (1.0 + sin(t * 1.8) * 0.022)
		_body_ward.rotation = sin(t * 0.65) * 0.018


func _frost_palette() -> Color:
	return FROST_BOSS_PALETTE[clampi(boss_stage_id - 1, 0, 4)]


func _draw_frost_body_presence() -> void:
	# Everything here remains inside the boss' silhouette/ward, never a
	# hostile AoE radius. Actual danger is drawn ONLY by RealmTelegraph.
	var c: Color = _frost_palette()
	var phase_power: float = 1.40 if current_phase == PHASE_TWO else 1.0
	var reduce_power: float = 0.45 if SettingsManager.reduced_effects else 1.0
	var motion: float = sin(_frost_visual_clock * 1.75)
	var center := Vector2(0.0, -26.0)
	var aura_strength: float = (0.07 + motion * 0.015) * phase_power * reduce_power
	draw_circle(center, 27.0, Color(c.r, c.g, c.b, aura_strength))
	draw_arc(center, 31.0, 0.24 + _frost_visual_clock * 0.19,
		4.90 + _frost_visual_clock * 0.19, 28,
		Color(c.r, c.g, c.b, 0.17 * phase_power * reduce_power), 1.3, true)
	if boss_stage_id == 2:
		for i: int in range(4):
			var a: float = float(i) * TAU / 4.0 + _frost_visual_clock * 0.16
			var shard_center: Vector2 = center + Vector2.RIGHT.rotated(a) * 36.0
			draw_line(shard_center + Vector2(0, -3), shard_center + Vector2(2, 3),
				Color(c.r, c.g, c.b, 0.32 * reduce_power), 1.4, true)
	elif boss_stage_id == 3:
		for i: int in range(6):
			var a: float = float(i) * TAU / 6.0 + PI * 0.5
			var petal: Vector2 = center + Vector2.RIGHT.rotated(a) * 35.0
			draw_circle(petal, 2.0, Color(c.r, c.g, c.b, 0.22 * reduce_power))
	elif boss_stage_id == 4:
		# Small resonant bell stroke; no gameplay hit area implied.
		draw_arc(center, 40.0, -PI * 0.32, PI * 0.20, 20,
			Color(0.97, 0.80, 0.51, 0.24 * phase_power * reduce_power), 1.5, true)
	elif boss_stage_id == 5:
		for sign_v: float in [-1.0, 1.0]:
			draw_line(center + Vector2(sign_v * 18.0, -13.0),
				center + Vector2(sign_v * 37.0, -29.0),
				Color(0.95, 0.84, 0.57, 0.27 * phase_power * reduce_power), 1.3, true)
	if _frost_intro_left > 0.0:
		var approach: float = _frost_intro_left / 0.95
		draw_arc(center, 40.0, 0.0, TAU, 32,
			Color(c.r, c.g, c.b, approach * 0.43 * reduce_power), 1.6, true)


func _solar_palette() -> Color:
	return SOLAR_BOSS_PALETTE[clampi(boss_stage_id - 1, 0, 4)]


func _draw_solar_body_presence() -> void:
	# Presentation is strictly body-bound. It is NOT a damage radius:
	# RealmTelegraph alone marks danger and controls actual hits.
	var tint: Color = _solar_palette()
	var phase_power: float = 1.34 if current_phase == PHASE_TWO else 1.0
	var reduced: float = 0.38 if SettingsManager.reduced_effects else 1.0
	var pulse: float = sin(_solar_visual_clock * 1.58)
	var center: Vector2 = Vector2(0.0, -24.0)
	draw_circle(center, 25.0,
		Color(tint.r, tint.g, tint.b, (0.070 + 0.012 * pulse) * phase_power * reduced))
	draw_arc(center, 30.0, _solar_visual_clock * 0.12,
		4.65 + _solar_visual_clock * 0.12, 30,
		Color(tint.r, tint.g, tint.b, 0.23 * phase_power * reduced), 1.4, true)
	match boss_stage_id:
		1:
			for side: float in [-1.0, 1.0]:
				draw_line(center + Vector2(side * 24, -21),
					center + Vector2(side * 33, -29),
					Color(tint.r, tint.g, tint.b, 0.28 * reduced), 1.3, true)
		2:
			for side: float in [-1.0, 1.0]:
				draw_arc(center + Vector2(side * 19, 9), 12.0, 0.12, PI * 0.81,
					12, Color(1.0, 0.69, 0.32, 0.25 * reduced), 1.6, true)
		3:
			for side: float in [-1.0, 1.0]:
				draw_line(center + Vector2(side * 15, -8),
					center + Vector2(side * 34, -31 + 2.0 * pulse),
					Color(1.0, 0.62, 0.42, 0.30 * reduced), 1.4, true)
		4:
			# Eclipse center stays small; never looks like a gameplay ring.
			draw_arc(center, 35.0, -PI * 0.70, PI * 0.20, 28,
				Color(0.96, 0.79, 0.55, 0.26 * reduced), 1.3, true)
		5:
			for index: int in range(5):
				var angle: float = float(index) * TAU / 5.0 - PI * 0.50
				var point: Vector2 = center + Vector2.RIGHT.rotated(angle) * 34.0
				draw_circle(point, 1.65,
					Color(1.0, 0.88, 0.61, 0.32 * phase_power * reduced))
	if _solar_intro_left > 0.0:
		var remaining: float = _solar_intro_left / 0.95
		draw_arc(center, 40.0, 0.0, TAU, 32,
			Color(tint.r, tint.g, tint.b, remaining * 0.43 * reduced), 1.5, true)


func _draw() -> void:
	if realm_id == 4:
		_draw_frost_body_presence()
	elif realm_id == 5:
		_draw_solar_body_presence()
	# Small, body-bound defensive ward = not a hostile AoE telegraph.
	if phase_transition_timer <= 0.0:
		return
	var progress: float = 1.0 - clampf(phase_transition_timer / maxf(phase_transition_invulnerability, 0.01), 0.0, 1.0)
	var primary: Color = Color(0.54, 0.91, 1.0, 0.92) if realm_id == 4 else Color(1.0, 0.76, 0.34, 0.94)
	var secondary: Color = Color(0.70, 0.74, 1.0, 0.72) if realm_id == 4 else Color(1.0, 0.37, 0.18, 0.72)
	draw_circle(Vector2(0, -16), 45.0, Color(primary.r, primary.g, primary.b, 0.07))
	draw_arc(Vector2(0, -16), 51.0, progress * 1.8, progress * 1.8 + PI * 1.5, 36, primary, 2.8, true)
	draw_arc(Vector2(0, -16), 58.0, -progress * 1.3, -progress * 1.3 + PI * 1.1, 36, secondary, 2.0, true)


func update_behavior() -> void:
	# Aggressive but bounded orbit pressure for the mobile/duelist encounters.
	# Boss still closes distance when outside ranged reach, and respects melee.
	if not is_instance_valid(player):
		return
	var distance_value: float = global_position.distance_to(player.global_position)
	var orbit_boss: bool = boss_stage_id in [2, 3, 5]
	if orbit_boss and distance_value > melee_distance and distance_value < ranged_distance and current_phase == PHASE_TWO:
		var direction: Vector2 = global_position.direction_to(player.global_position)
		var tangent: Vector2 = direction.orthogonal() * _strafe_side
		velocity = (tangent + direction * 0.13).normalized() * speed * 0.62
		move_and_slide()
		_update_facing_to_player()
		try_ranged_attack()
		_play_walk_animation()
		return
	super.update_behavior()


func try_ranged_attack() -> void:
	if ranged_attack_timer > 0.0 or not is_instance_valid(player):
		return
	if authored_patterns.is_empty():
		super.try_ranged_attack()
		return
	var choices: Array[String] = authored_patterns.duplicate()
	if current_phase == PHASE_TWO and not boss_signature.is_empty() and boss_signature not in choices:
		choices.append(boss_signature)
	if choices.size() > 1:
		choices.erase(_previous_pattern)
	var selected: String = choices.pick_random()
	# Showcase the phase-two-only bespoke move once, rather than relying on RNG.
	# Do not consume it while six hazards are already active.
	if realm_id in [4, 5] and _first_phase_two_signature_pending and not boss_signature.is_empty():
		if get_tree().get_nodes_in_group("realm_boss_telegraph").size() >= 6:
			ranged_attack_timer = 0.30
			return
		selected = boss_signature
		_first_phase_two_signature_pending = false
	_previous_pattern = selected
	_cast_realm_pattern(selected, player.global_position)
	_strafe_side = -_strafe_side
	ranged_attack_timer = get_current_ranged_attack_cooldown()


func enter_phase_two() -> void:
	super.enter_phase_two()
	if realm_id == 4:
		_first_phase_two_signature_pending = not boss_signature.is_empty()
		_frost_intro_left = 0.90
		queue_redraw()
	elif realm_id == 5:
		_first_phase_two_signature_pending = not boss_signature.is_empty()
		_solar_intro_left = 0.90
		queue_redraw()


func try_attack() -> void:
	if attack_timer > 0.0:
		return
	if current_phase == PHASE_TWO and shockwave_timer <= 0.0:
		var close_pattern: String = "frost_ring" if realm_id == 4 else "solar_ring"
		_cast_realm_pattern(close_pattern, global_position)
		shockwave_timer = shockwave_cooldown
	else:
		attack_player()
	attack_timer = attack_cooldown


func _cast_realm_pattern(pattern_name: String, target: Vector2) -> void:
	# Max six total boss telegraphs, independent of normal/projectile cap.
	if get_tree().get_nodes_in_group("realm_boss_telegraph").size() >= 6:
		return
	var spell: Node2D = RealmTelegraph.new()
	spell.set("pattern", pattern_name)
	var is_signature: bool = pattern_name == boss_signature
	var base_damage: float = projectile_damage * (1.65 if is_signature else 1.34)
	if current_phase == PHASE_TWO:
		base_damage *= 1.12
	spell.set("damage", base_damage)
	spell.set("warning_duration", 1.35 if is_signature else (1.20 if current_phase == PHASE_ONE else 1.13))
	var anchored: bool = pattern_name in ["frost_mark", "ember_mark", "lotus_bloom", "nine_suns"]
	var launch: Vector2 = target if anchored else global_position
	spell.set("aim", global_position.direction_to(target))
	spell.add_to_group("realm_boss_telegraph")
	get_tree().current_scene.add_child(spell)
	spell.global_position = launch
	_update_facing_to_position(target)
	if realm_id == 4 and pattern_name in ["frost_ring", "bell_toll", "lotus_bloom"]:
		_play_action_animation("shockwave", 0.56)
	elif realm_id == 4 and pattern_name in ["frost_fork", "frost_crown"]:
		_play_action_animation("melee", 0.56)
	else:
		_play_action_animation("lightning", 0.56)
