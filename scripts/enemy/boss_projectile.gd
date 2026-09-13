extends Area2D

const NINE_HEAVENS_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/chapter3/boss_3_astral_star_projectile_spriteframes.tres"
)

## Boss Projectile
## Projectile Boss yang dapat ditembakkan menuju target
## atau langsung menggunakan arah tertentu.

@export var speed: float = 250.0
@export var damage: float = 2.0
@export var lifetime: float = 5.0
@export var presentation_theme: String = ""

var direction: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	## Active hostile projectile stays above actor bodies.
	z_index = 4

	body_entered.connect(_on_body_entered)

	if animated_sprite != null:
		if presentation_theme == "nine_heavens":
			animated_sprite.sprite_frames = NINE_HEAVENS_SPRITE_FRAMES
		animated_sprite.play(&"fly")

## Mengarahkan projectile menuju posisi target.
func setup(target_position: Vector2) -> void:
	direction = global_position.direction_to(target_position)

## Mengatur arah projectile secara langsung.
func setup_direction(new_direction: Vector2) -> void:
	direction = new_direction.normalized()

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

	var player_health: PlayerHealth = body.get_node_or_null("PlayerHealth") as PlayerHealth

	if player_health == null:
		return

	DebugLogger.system(str("BOSS PROJECTILE HIT!"))
	DebugLogger.system(str("Projectile Damage: ", damage))

	player_health.take_damage(damage)
	queue_free()
