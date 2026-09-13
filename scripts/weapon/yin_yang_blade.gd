extends Area2D
class_name YinYangBlade

## Yin-Yang Blade
## Blade individual yang mengorbit Player.
## Blade mendeteksi body yang bersentuhan lalu mengirim
## permintaan hit kepada Yin-Yang Blades Weapon.
##
## Visual identity:
## - Blade bergantian Yin / Yang.
## - Blade menghadap tangensial mengikuti orbit.
## - Reversal hanya mengubah presentation; hitbox tetap CircleShape2D.

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

func _physics_process(delta: float) -> void:
	orbit_angle = fmod(
		orbit_angle + orbit_speed * delta,
		TAU
	)

	position = Vector2(
		cos(orbit_angle),
		sin(orbit_angle)
	) * orbit_radius

	## Sprite points right, therefore +PI/2 makes it fly tangentially.
	rotation = orbit_angle + PI * 0.5

	for body in get_overlapping_bodies():
		body_contacted.emit(body)

func set_polarity(new_polarity: StringName) -> void:
	if new_polarity == &"yang":
		polarity = &"yang"
	else:
		polarity = &"yin"

	if is_node_ready():
		apply_polarity_visual()

func set_reversal_visual(active: bool) -> void:
	reversal_visual_active = active

	if is_node_ready():
		apply_reversal_visual()

func apply_polarity_visual() -> void:
	if blade_sprite == null:
		return

	blade_sprite.play(polarity)

	if aura_ring == null:
		return

	if polarity == &"yin":
		aura_ring.default_color = Color(
			0.28,
			0.78,
			0.72,
			0.28
		)
	else:
		aura_ring.default_color = Color(
			0.94,
			0.78,
			0.34,
			0.28
		)

func apply_reversal_visual() -> void:
	var target_scale: Vector2 = Vector2.ONE
	var target_alpha: float = 1.0

	if reversal_visual_active:
		target_scale = Vector2.ONE * 1.14
		target_alpha = 1.0

		if aura_ring != null:
			aura_ring.width = 3.5
			aura_ring.modulate.a = 0.90
	else:
		if aura_ring != null:
			aura_ring.width = 2.0
			aura_ring.modulate.a = 0.55

	if blade_sprite != null:
		blade_sprite.scale = target_scale
		blade_sprite.modulate.a = target_alpha
