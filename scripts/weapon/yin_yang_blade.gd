extends Area2D
class_name YinYangBlade

signal body_contacted(body: Node)

var orbit_angle: float = 0.0
var orbit_radius: float = 80.0
var orbit_speed: float = PI

var polarity: StringName = &"yin"
var reversal_visual_active: bool = false

@onready var blade_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var aura_ring: Line2D = $AuraRing


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true

	apply_polarity_visual()
	apply_reversal_visual()
	queue_redraw()


func _physics_process(delta: float) -> void:
	orbit_angle = fmod(
		orbit_angle + orbit_speed * delta,
		TAU
	)

	var orbit_center: Vector2 = _get_player_combat_origin_local()

	position = orbit_center + Vector2(
		cos(orbit_angle),
		sin(orbit_angle)
	) * orbit_radius

	# Sprite points right, +PI/2 makes it fly tangentially.
	rotation = orbit_angle + PI * 0.5

	for body in get_overlapping_bodies():
		body_contacted.emit(body)

	if not SettingsManager.reduced_effects:
		queue_redraw()


func _get_player_combat_origin_local() -> Vector2:
	var player := get_parent() as Node2D
	if player == null:
		return Vector2.ZERO

	var combat_origin := (
		player.get_node_or_null("CombatOrigin")
		as Node2D
	)
	if combat_origin == null:
		return Vector2.ZERO

	return combat_origin.position


func set_polarity(new_polarity: StringName) -> void:
	polarity = (
		&"yang"
		if new_polarity == &"yang"
		else &"yin"
	)

	if is_node_ready():
		apply_polarity_visual()
		queue_redraw()


func set_reversal_visual(active: bool) -> void:
	reversal_visual_active = active

	if is_node_ready():
		apply_reversal_visual()
		queue_redraw()


func apply_polarity_visual() -> void:
	if blade_sprite == null:
		return

	blade_sprite.play(polarity)

	if aura_ring == null:
		return

	if polarity == &"yin":
		aura_ring.default_color = Color(
			0.28,
			0.82,
			0.78,
			0.36
		)
	else:
		aura_ring.default_color = Color(
			1.0,
			0.78,
			0.28,
			0.36
		)


func apply_reversal_visual() -> void:
	var target_scale: Vector2 = Vector2.ONE

	if reversal_visual_active:
		target_scale = Vector2.ONE * 1.18

		if aura_ring != null:
			aura_ring.width = 4.2
			aura_ring.modulate.a = 1.0
	else:
		if aura_ring != null:
			aura_ring.width = 2.4
			aura_ring.modulate.a = 0.68

	if blade_sprite != null:
		blade_sprite.scale = target_scale
		blade_sprite.modulate.a = 1.0


func _draw() -> void:
	var main_color := (
		Color(0.30, 0.92, 0.86, 0.82)
		if polarity == &"yin"
		else Color(1.0, 0.78, 0.28, 0.84)
	)
	var pale_color := (
		Color(0.78, 1.0, 0.96, 0.88)
		if polarity == &"yin"
		else Color(1.0, 0.95, 0.72, 0.90)
	)

	draw_arc(
		Vector2.ZERO,
		18.0 if reversal_visual_active else 16.0,
		0.0,
		TAU,
		28,
		Color(
			main_color.r,
			main_color.g,
			main_color.b,
			0.35
		),
		1.5,
		true
	)

	if SettingsManager.reduced_effects:
		return

	# Root rotates tangentially, so local -X is the movement trail direction.
	var trail_length: float = (
		34.0 if reversal_visual_active else 26.0
	)
	draw_line(
		Vector2(-7.0, 0.0),
		Vector2(-trail_length, 0.0),
		Color(
			main_color.r,
			main_color.g,
			main_color.b,
			0.42
		),
		5.5 if reversal_visual_active else 3.8,
		true
	)
	draw_line(
		Vector2(-5.0, 0.0),
		Vector2(-trail_length * 0.78, 0.0),
		Color(
			pale_color.r,
			pale_color.g,
			pale_color.b,
			0.72
		),
		1.7,
		true
	)

	if reversal_visual_active:
		draw_arc(
			Vector2.ZERO,
			23.0,
			-PI * 0.8,
			PI * 0.2,
			22,
			Color(
				pale_color.r,
				pale_color.g,
				pale_color.b,
				0.62
			),
			1.7,
			true
		)
