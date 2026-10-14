extends Node2D

## Visual transforms only. Collision, movement, atlas regions and action timings
## continue to belong to the original actor scripts.
##
## IMPORTANT:
## Jade Pavilion cosmetics are NOT rendered here anymore.
## LinYuePavilionAuraPresentation is the single runtime authority for player aura
## cosmetics. Keeping one authority prevents mismatched pivots / doubled rings.

const HURT_DURATION: float = 0.16
const IDLE_PRESENTATION_INTERVAL: float = 1.0 / 30.0
const REDUCED_IDLE_PRESENTATION_INTERVAL: float = 1.0 / 18.0

var sprite: AnimatedSprite2D
var rest_scale: Vector2
var rest_position: Vector2
var rest_rotation: float
var age: float = 0.0
var hurt_left: float = 0.0
var action_left: float = 0.0
var action_length: float = 0.28
var action_direction: float = 1.0
var is_player_actor: bool = false
var presentation_accumulator: float = 0.0
var player_tint_active: bool = false
var premium_boss: bool = false
var stride_phase: float = 0.0
var travel_strength: float = 0.0
var last_actor_position: Vector2


func _ready() -> void:
	sprite = get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		set_process(false)
		return
	rest_scale = sprite.scale
	rest_position = sprite.position
	rest_rotation = sprite.rotation
	age = float(get_parent().get_instance_id() % 101) * 0.1
	is_player_actor = get_parent().is_in_group("player")
	premium_boss = get_parent().is_in_group("boss") or bool(get_parent().get_meta("premium_boss_presentation",false))
	last_actor_position = get_parent().global_position
	sprite.animation_changed.connect(_on_actor_animation_changed)
	_on_actor_animation_changed()


func hurt() -> void:
	hurt_left = HURT_DURATION
	if is_player_actor:
		var health: Node = get_parent().get_node_or_null("PlayerHealth")
		if health != null and health.has_method("is_hit_guarded") and health.is_hit_guarded():
			hurt_left = maxf(hurt_left, float(health.hit_guard_remaining))
	presentation_accumulator = 0.0


func action(duration: float = 0.28) -> void:
	if action_left > 0.0:
		return
	action_length = maxf(duration, 0.12)
	action_left = action_length
	presentation_accumulator = 0.0

	var actor: CharacterBody2D = get_parent() as CharacterBody2D
	if actor != null and absf(actor.velocity.x) > 0.01:
		action_direction = signf(actor.velocity.x)


func _process(delta: float) -> void:
	if not is_instance_valid(sprite):
		return

	age += delta
	var distance: float = get_parent().global_position.distance_to(last_actor_position)
	last_actor_position = get_parent().global_position
	stride_phase = fmod(stride_phase + minf(distance, 24.0) * TAU / (72.0 if premium_boss else 42.0), TAU)
	travel_strength = move_toward(travel_strength, 1.0 if distance > 0.02 else 0.0, delta * 10.0)
	var reaction_was_active: bool = hurt_left > 0.0 or action_left > 0.0
	hurt_left = maxf(hurt_left - delta, 0.0)
	action_left = maxf(action_left - delta, 0.0)

	# Lin Yue owns deterministic locomotion plus dedicated combat/cultivation/aura
	# presentation layers. The generic presentation only owns its hurt tint, so
	# an unharmed player no longer receives redundant transform/color writes on
	# every rendered frame.
	if is_player_actor:
		_update_player_hurt_tint()
		return

	var active_reaction: bool = hurt_left > 0.0 or action_left > 0.0
	if not active_reaction:
		# If a reaction ended this frame, immediately restore the passive pose and
		# clear the hurt tint before switching back to the budgeted idle cadence.
		if reaction_was_active:
			presentation_accumulator = 0.0
			_update_non_player_presentation()
			return
		presentation_accumulator += delta
		var idle_interval: float = (
			REDUCED_IDLE_PRESENTATION_INTERVAL
			if SettingsManager.reduced_effects
			else IDLE_PRESENTATION_INTERVAL
		)
		if presentation_accumulator < idle_interval:
			return
		presentation_accumulator = fmod(presentation_accumulator, idle_interval)
	else:
		# Hurt/action reactions retain full-frame responsiveness. Only passive
		# breathing is budgeted to a lower visual tick rate.
		presentation_accumulator = 0.0

	_update_non_player_presentation()


func _update_player_hurt_tint() -> void:
	if hurt_left > 0.0:
		var hurt_weight: float = hurt_left / HURT_DURATION
		var player_flash: float = (
			hurt_weight
			* (0.12 if SettingsManager.reduced_effects else 0.5)
		)
		sprite.self_modulate = Color(
			1.0,
			1.0 - player_flash * 0.30,
			1.0 - player_flash * 0.55,
			1.0
		)
		player_tint_active = true
		return

	if player_tint_active:
		sprite.self_modulate = Color.WHITE
		player_tint_active = false


func _update_non_player_presentation() -> void:
	if bool(get_parent().get_meta("frame_driven_boss",false)):
		# Painted 2D frames own pose; generic gait/breath squash must never compete.
		var flash: float = hurt_left / HURT_DURATION * (0.12 if SettingsManager.reduced_effects else 0.5)
		sprite.self_modulate=Color(1.0,1.0-flash*.30,1.0-flash*.55,1.0)
		return
	var breath: float = sin(age * 3.2) * 0.012
	var gait: float = sin(stride_phase) * travel_strength
	var step_lift: float = absf(gait) * (2.8 if premium_boss else 2.0)
	var actor: CharacterBody2D = get_parent() as CharacterBody2D
	var lean: float = clampf(actor.velocity.x / 180.0, -1.0, 1.0) if actor != null else 0.0
	var action_weight: float = (
		sin((1.0 - action_left / action_length) * PI)
		if action_left > 0.0
		else 0.0
	)
	var hurt_weight: float = hurt_left / HURT_DURATION
	var motion: float = 0.35 if SettingsManager.reduced_effects else 1.0
	var action_amplitude: float = 1.9 if premium_boss else 1.0

	sprite.scale = (
		rest_scale
		* Vector2(
			1.0 + breath + absf(gait) * 0.018 * motion + action_weight * 0.035 * motion * action_amplitude,
			1.0 - breath - absf(gait) * 0.025 * motion - hurt_weight * 0.035 * motion
		)
	)
	sprite.position = (
		rest_position
		+ Vector2(gait * 1.3 * motion, -(step_lift + action_weight * 3.0 * action_amplitude) * motion)
	)
	sprite.rotation = (
		rest_rotation
		+ (gait * 0.035 - lean * 0.025 + action_weight * 0.09 * action_direction * action_amplitude) * motion
	)

	queue_redraw()
	# self_modulate leaves child telegraphs and guardian status rings untouched.
	var flash: float = (
		hurt_weight
		* (0.12 if SettingsManager.reduced_effects else 0.5)
	)
	sprite.self_modulate = Color(
		1.0,
		1.0 - flash * 0.30,
		1.0 - flash * 0.55,
		1.0
	)

func _on_actor_animation_changed() -> void:
	if is_player_actor or premium_boss or sprite == null: return
	var animation_name: String = str(sprite.animation)
	if not ("cast" in animation_name or "charge" in animation_name or "attack" in animation_name): return
	var frames: SpriteFrames = sprite.sprite_frames
	var duration: float = float(frames.get_frame_count(sprite.animation))/maxf(1,frames.get_animation_speed(sprite.animation))
	action(clampf(duration,.18,.7))
func _draw() -> void:
	if is_player_actor or premium_boss or action_left <= 0: return
	var strength: float = sin((1.0-action_left/action_length)*PI)
	var ink := Color(.6,.9,.8,strength*.65)
	var hand: Vector2 = rest_position + Vector2(-18 if sprite.flip_h else 18,-8)
	for index: int in range(2):
		var at: Vector2 = hand+Vector2(index*9,-index*4)
		draw_line(at+Vector2(0,-8),at+Vector2(0,6),ink,2,true)
		draw_line(at+Vector2(-3,-4),at+Vector2(3,-4),ink,1.5,true)
