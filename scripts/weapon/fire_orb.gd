extends Area2D


## Fire Orb uses a dedicated ACTUAL-hit effect; no fake AoE is added.
const FIRE_ORB_IMPACT_SCENE: PackedScene = preload(
	"res://scenes/weapons/fire_orb_impact.tscn"
)

@export var speed: float = 350.0
@export var damage: float = 20.0

var direction: Vector2 = Vector2.ZERO
var lifetime: float = 4.0
var consumed: bool = false

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	position += direction * speed * delta

func setup(target_position: Vector2) -> void:
	direction = global_position.direction_to(target_position)
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	if not consumed and body.is_in_group("enemy"):
		consumed = true
		body.take_damage(damage)
		spawn_hit_visual()
		queue_free()

func spawn_hit_visual() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var effect := FIRE_ORB_IMPACT_SCENE.instantiate() as FireOrbImpact
	if effect == null:
		return

	current_scene.add_child(effect)
	effect.global_position = global_position
