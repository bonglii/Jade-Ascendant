extends Area2D

## Enemy Projectile
## Projectile ranged enemy yang bergerak menuju posisi Player.
## Terdaftar sebagai enemy_attack agar dapat dibersihkan
## ketika terjadi transisi combat seperti Boss Wave.

@export var speed: float = 200.0
@export var damage: float = 2.0
@export var lifetime: float = 5.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.ZERO
var configured_sprite_frames: SpriteFrames = null

func configure_sprite_frames(frames: SpriteFrames) -> void:
	configured_sprite_frames = frames

func _ready() -> void:
	## Active hostile projectile must remain readable above actor bodies.
	z_index = 4

	add_to_group("enemy_attack")
	body_entered.connect(_on_body_entered)

	if animated_sprite != null:
		if configured_sprite_frames != null:
			animated_sprite.sprite_frames = configured_sprite_frames
		animated_sprite.play(&"fly")

## Menentukan arah projectile menuju posisi target.
func setup(target_position: Vector2) -> void:
	direction = global_position.direction_to(
		target_position
	)

	rotation = direction.angle()

## Menggerakkan projectile dan menghapusnya setelah lifetime habis.
func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()

## Memberikan damage ketika projectile mengenai Player.
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var player_health: PlayerHealth = (
		body.get_node_or_null("PlayerHealth")
		as PlayerHealth
	)

	if player_health == null:
		return

	DebugLogger.combat(
		"Enemy Projectile Hit | Damage: %.1f"
		% damage
	)

	player_health.take_damage(damage)
	queue_free()
