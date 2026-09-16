extends Area2D

## Fire Orb selalu menampilkan hit effect pada actual collision.
## Lv.3+ dapat membawa Cinder Bloom dari FireOrbWeapon; pada kondisi itu
## impact visual ikut membesar karena memang ada splash gameplay yang nyata.
const FIRE_ORB_IMPACT_SCENE: PackedScene = preload(
	"res://scenes/weapons/fire_orb_impact.tscn"
)

@export var speed: float = 350.0
@export var damage: float = 20.0
@export var cinder_bloom_radius: float = 0.0
@export_range(0.0, 1.0, 0.05) var cinder_bloom_damage_multiplier: float = 0.0
@export var impact_visual_scale: float = 1.0

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
	_align_to_player_combat_origin()
	direction = global_position.direction_to(target_position)
	rotation = direction.angle()


func _align_to_player_combat_origin() -> void:
	var player := (
		get_tree().get_first_node_in_group("player")
		as Node2D
	)
	if player == null:
		return

	var combat_origin := (
		player.get_node_or_null("CombatOrigin")
		as Node2D
	)
	if combat_origin == null:
		return

	global_position = combat_origin.global_position


func _on_body_entered(body: Node2D) -> void:
	if consumed or not body.is_in_group("enemy"):
		return

	consumed = true
	body.take_damage(damage)
	_apply_cinder_bloom(body)
	spawn_hit_visual()
	queue_free()


## Memberikan splash damage actual kepada enemy lain di sekitar impact.
## Primary target sengaja dikecualikan agar direct-hit DPS lama tetap sama.
func _apply_cinder_bloom(primary_target: Node2D) -> void:
	if cinder_bloom_radius <= 0.0:
		return
	if cinder_bloom_damage_multiplier <= 0.0:
		return

	var splash_damage: float = (
		damage * cinder_bloom_damage_multiplier
	)
	var radius_squared: float = (
		cinder_bloom_radius * cinder_bloom_radius
	)
	var splash_hits: int = 0

	var enemy_candidates: Array[Node] = (
		get_tree().get_nodes_in_group("enemy")
	)

	for enemy_node in enemy_candidates:
		if not enemy_node is Node2D:
			continue

		var enemy := enemy_node as Node2D
		if enemy == primary_target:
			continue
		if not is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion():
			continue
		if not enemy.has_method("take_damage"):
			continue

		var distance_squared: float = (
			global_position.distance_squared_to(
				enemy.global_position
			)
		)
		if distance_squared > radius_squared:
			continue

		enemy.take_damage(splash_damage)
		splash_hits += 1

	if splash_hits > 0:
		DebugLogger.combat(str(
			"CINDER BLOOM | Radius: ",
			cinder_bloom_radius,
			" | Splash Damage: ",
			splash_damage,
			" | Extra Targets: ",
			splash_hits
		))


func spawn_hit_visual() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var effect := (
		FIRE_ORB_IMPACT_SCENE.instantiate()
		as FireOrbImpact
	)
	if effect == null:
		return

	current_scene.add_child(effect)
	effect.global_position = global_position
	effect.scale = Vector2.ONE * maxf(
		impact_visual_scale,
		0.1
	)
