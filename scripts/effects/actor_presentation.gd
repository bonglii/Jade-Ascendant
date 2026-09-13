extends Node2D

## Visual transforms only. Collision, movement, atlas regions and action timings
## continue to belong to the original actor scripts.
var sprite: AnimatedSprite2D
var rest_scale: Vector2
var rest_position: Vector2
var rest_rotation: float
var age: float = 0.0
var hurt_left: float = 0.0
var action_left: float = 0.0
var action_length: float = 0.28
var action_direction: float = 1.0

func _ready() -> void:
	sprite = get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		set_process(false)
		return
	rest_scale = sprite.scale
	rest_position = sprite.position
	rest_rotation = sprite.rotation
	age = float(get_parent().get_instance_id() % 101) * 0.1

func hurt() -> void:
	hurt_left = 0.16

func action(duration: float = 0.28) -> void:
	if action_left > 0.0:
		return
	action_length = maxf(duration, 0.12)
	action_left = action_length
	var actor: CharacterBody2D = get_parent() as CharacterBody2D
	if actor != null and absf(actor.velocity.x) > 0.01:
		action_direction = signf(actor.velocity.x)

func _process(delta: float) -> void:
	if not is_instance_valid(sprite):
		return
	age += delta
	hurt_left = maxf(hurt_left - delta, 0.0)
	action_left = maxf(action_left - delta, 0.0)
	var breath: float = sin(age * 3.2) * 0.012
	var action_weight: float = sin((1.0 - action_left / action_length) * PI) if action_left > 0.0 else 0.0
	var hurt_weight: float = hurt_left / 0.16
	var motion: float = 0.35 if SettingsManager.reduced_effects else 1.0
	var parent_actor: Node = get_parent()

	# Lin Yue already owns deterministic locomotion, hurt/death animation and
	# mechanic-backed combat source cues. Do not add a generic squash/sword action
	# on top of those locked presentations.
	if parent_actor.is_in_group("player"):
		sprite.scale = rest_scale
		sprite.position = rest_position
		sprite.rotation = rest_rotation
		var player_flash: float = hurt_weight * (0.12 if SettingsManager.reduced_effects else 0.5)
		sprite.self_modulate = Color(1.0, 1.0 - player_flash * 0.30, 1.0 - player_flash * 0.55, 1.0)
		queue_redraw()
		return

	sprite.scale = rest_scale * Vector2(1.0 + breath + action_weight * 0.035 * motion, 1.0 - breath - hurt_weight * 0.035 * motion)
	sprite.position = rest_position + Vector2(0.0, -action_weight * 2.0 * motion)
	sprite.rotation = rest_rotation + action_weight * 0.07 * action_direction * motion
	# self_modulate leaves child telegraphs and guardian status rings untouched.
	var flash: float = hurt_weight * (0.12 if SettingsManager.reduced_effects else 0.5)
	sprite.self_modulate = Color(1.0, 1.0 - flash * 0.30, 1.0 - flash * 0.55, 1.0)

func _draw() -> void:
	var actor: Node = get_parent()
	if not actor.is_in_group("player"):
		return
	var cosmetic_id: String = PavilionManager.get_cosmetic_id()
	match cosmetic_id:
		"jade_aura":
			draw_arc(Vector2(0.0, 16.0), 18.0, age * 0.2, age * 0.2 + TAU * 0.78, 24, Color(0.47, 0.85, 0.73, 0.5), 1.0, true)
		"golden_aura":
			draw_arc(Vector2(0.0, 16.0), 18.0, age * 0.2, age * 0.2 + TAU * 0.78, 24, Color(0.89, 0.76, 0.40, 0.5), 1.0, true)
		"astral_aura":
			draw_arc(Vector2(0.0, 16.0), 19.0, age * 0.24, age * 0.24 + TAU * 0.80, 28, Color(0.57, 0.48, 0.98, 0.52), 1.2, true)
			if not SettingsManager.reduced_effects:
				draw_arc(Vector2(0.0, 16.0), 22.0, -age * 0.16, -age * 0.16 + TAU * 0.60, 28, Color(0.95, 0.81, 0.42, 0.34), 1.0, true)
		"ascendant_aura":
			draw_arc(Vector2(0.0, 16.0), 19.0, age * 0.28, age * 0.28 + TAU * 0.86, 32, Color(0.38, 0.96, 0.80, 0.58), 1.35, true)
			if not SettingsManager.reduced_effects:
				draw_arc(Vector2(0.0, 16.0), 23.0, -age * 0.18, -age * 0.18 + TAU * 0.66, 32, Color(0.98, 0.82, 0.42, 0.42), 1.1, true)
	# No generic player attack arc: Lin Yue CombatPresentation listens to the
	# actual WeaponManager signal and remains the sole player source-cue authority.
	return
