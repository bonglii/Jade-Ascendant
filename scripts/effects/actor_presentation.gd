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


func hurt() -> void:
	hurt_left = HURT_DURATION
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
	var breath: float = sin(age * 3.2) * 0.012
	var action_weight: float = (
		sin((1.0 - action_left / action_length) * PI)
		if action_left > 0.0
		else 0.0
	)
	var hurt_weight: float = hurt_left / HURT_DURATION
	var motion: float = 0.35 if SettingsManager.reduced_effects else 1.0

	sprite.scale = (
		rest_scale
		* Vector2(
			1.0 + breath + action_weight * 0.035 * motion,
			1.0 - breath - hurt_weight * 0.035 * motion
		)
	)
	sprite.position = (
		rest_position
		+ Vector2(0.0, -action_weight * 2.0 * motion)
	)
	sprite.rotation = (
		rest_rotation
		+ action_weight * 0.07 * action_direction * motion
	)

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
