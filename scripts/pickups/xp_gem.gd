extends Area2D

## Value-preserving pickup cap. Overflow merges into an existing shard instead
## of discarding earned XP; attraction affects visuals/movement, never XP value.
@export var experience_value: int = 5
const MAX_PICKUPS: int = 160
var collected: bool = false
var attracted: bool = false
var age: float = 0.0
var check_left: float = 0.0
var player: Node2D
var sprite: AnimatedSprite2D
var magnet_radius: float = 52.0

func _ready() -> void:
	add_to_group("qi_pickup")
	player = get_tree().get_first_node_in_group("player") as Node2D
	magnet_radius += EquipmentManager.get_secondary_bonus("pickup_radius_bonus", 72.0)
	var pickups: Array[Node] = get_tree().get_nodes_in_group("qi_pickup")
	if pickups.size() > MAX_PICKUPS:
		for pickup in pickups:
			if pickup != self and is_instance_valid(pickup) and not pickup.is_queued_for_deletion() and not bool(pickup.get("collected")):
				pickup.set("experience_value", int(pickup.get("experience_value")) + experience_value)
				collected = true
				queue_free()
				return
	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.play(&"idle")
	age = float(get_instance_id() % 80) * 0.1

func _physics_process(delta: float) -> void:
	if collected or not is_instance_valid(player):
		return
	age += delta
	if sprite != null:
		sprite.position.y = sin(age * 3.0) * 1.2
	check_left -= delta
	if not attracted and check_left <= 0.0:
		check_left = 0.12
		attracted = global_position.distance_squared_to(player.global_position) < magnet_radius * magnet_radius
	if attracted:
		global_position = global_position.move_toward(player.global_position, 310.0 * delta)
		if global_position.distance_squared_to(player.global_position) < 100.0:
			_collect(player)
		queue_redraw()

func _draw() -> void:
	if attracted and is_instance_valid(player):
		var backward: Vector2 = player.global_position.direction_to(global_position)
		draw_line(Vector2.ZERO, backward * 15.0, Color(1.0, 0.78, 0.28, 0.25), 1.2, true)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect(body)

func _collect(body: Node2D) -> void:
	if collected:
		return
	collected = true
	remove_from_group("qi_pickup")
	AudioManager.play_sfx("pickup")
	CombatFeedback.pulse(global_position, "pickup")
	body.add_experience(experience_value)
	queue_free()
