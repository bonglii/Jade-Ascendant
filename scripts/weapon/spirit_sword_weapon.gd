class_name SpiritSwordWeapon
extends Weapon

## Spirit Sword Weapon
## Menembakkan pedang spiritual ke target.
## Final damage dan metadata Critical Hit dihitung
## melalui PlayerStats.
##
## Sword Dao Resonance ditangani setelah original
## Spirit Sword menghasilkan actual Critical Hit.

@export var projectile_scene: PackedScene = preload(
	"res://scenes/weapons/spirit_sword.tscn"
)

const MAX_LEVEL: int = 7
var level: int = 1
var base_damage: float = 10.0

func _ready() -> void:
	weapon_name = "Spirit Sword"
	cooldown = 1.0

func attack(player: Node2D, target: Node2D) -> void:
	if player == null or target == null:
		return

	# Projectile utama tidak pernah diberi spread: selalu diarahkan tepat ke
	# pusat primary target agar multi-shot tidak menciptakan dead zone di tengah.
	create_projectile(
		player,
		target,
		Vector2.ZERO
	)

	if level < 5:
		return

	var secondary_target: Node2D = (
		resolve_secondary_attack_target(
			player.global_position,
			target,
			get_tree().get_nodes_in_group("enemy")
		)
	)

	var secondary_origin_offset: Vector2 = Vector2.ZERO
	if secondary_target == target:
		secondary_origin_offset = get_secondary_origin_offset(
			player.global_position,
			target.global_position
		)

	create_projectile(
		player,
		secondary_target,
		secondary_origin_offset
	)

## Membuat satu original Spirit Sword projectile.
func create_projectile(
	player: Node2D,
	target: Node2D,
	spawn_offset: Vector2 = Vector2.ZERO
) -> void:
	var sword = projectile_scene.instantiate()

	var damage_result: Dictionary = (
		player.player_stats.calculate_damage_result(
			base_damage
		)
	)

	player.get_parent().add_child(sword)

	sword.global_position = player.global_position + spawn_offset
	sword.damage = float(
		damage_result["damage"]
	)
	sword.is_critical = bool(
		damage_result["is_critical"]
	)
	sword.is_resonance_projectile = false
	sword.resonance_triggered = false

	connect_projectile_signals(
		sword,
		player
	)

	if level >= 7:
		sword.pierce = 1

	# Both projectiles aim at an actual enemy center. Only the fallback second
	# sword may use a small perpendicular spawn offset to avoid perfect overlap.
	sword.setup(
		target.global_position
	)

## Menghubungkan signal projectile ke weapon controller.
func connect_projectile_signals(
	sword: Area2D,
	player: Node2D
) -> void:
	sword.critical_hit_confirmed.connect(
		_on_projectile_critical_hit.bind(
			player
		)
	)

## Menangani actual Critical Hit dari original Spirit Sword.
func _on_projectile_critical_hit(
	source_projectile: Area2D,
	hit_enemy: Node2D,
	hit_position: Vector2,
	player: Node2D
) -> void:
	DebugLogger.combat(
		"SWORD DAO RESONANCE | Critical signal received."
	)

	if source_projectile == null:
		DebugLogger.combat(
			"SWORD DAO RESONANCE | Invalid source projectile."
		)
		return

	if not is_instance_valid(source_projectile):
		DebugLogger.combat(
			"SWORD DAO RESONANCE | Source projectile freed."
		)
		return

	if player == null:
		DebugLogger.combat(
			"SWORD DAO RESONANCE | Player null."
		)
		return

	if not is_instance_valid(player):
		DebugLogger.combat(
			"SWORD DAO RESONANCE | Player invalid."
		)
		return

	if not player.player_stats.has_sword_dao_resonance():
		DebugLogger.combat(
			"SWORD DAO RESONANCE | Upgrade not owned."
		)
		return

	DebugLogger.combat(
		"SWORD DAO RESONANCE | Upgrade ownership confirmed."
	)

	var resonance_target: Node2D = (
		find_resonance_target(
			hit_position,
			hit_enemy
		)
	)

	if resonance_target == null:
		DebugLogger.combat(
			"SWORD DAO RESONANCE | No secondary target."
		)
		return

	DebugLogger.combat(
		"SWORD DAO RESONANCE | Secondary target found."
	)

	source_projectile.mark_resonance_triggered()

	call_deferred(
		"create_resonance_projectile",
		player,
		hit_position,
		resonance_target
	)

## Mencari enemy terdekat selain enemy yang baru terkena hit.
func find_resonance_target(
	origin_position: Vector2,
	excluded_enemy: Node2D
) -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance: float = INF

	var enemies: Array[Node] = (
		get_tree().get_nodes_in_group(
			"enemy"
		)
	)

	DebugLogger.combat(
		"SWORD DAO RESONANCE | Enemy candidates: %d"
		% enemies.size()
	)

	for enemy_node in enemies:
		if not enemy_node is Node2D:
			continue

		var enemy := enemy_node as Node2D

		if enemy == excluded_enemy:
			continue

		if not is_instance_valid(enemy):
			continue

		if enemy.is_queued_for_deletion():
			continue

		var distance: float = (
			origin_position.distance_to(
				enemy.global_position
			)
		)

		if distance >= nearest_distance:
			continue

		nearest_distance = distance
		nearest_enemy = enemy

	return nearest_enemy

## Membuat Spirit Sword tambahan menuju secondary enemy.
## Fungsi ini dipanggil secara deferred agar Area2D baru
## tidak dibuat ketika PhysicsServer sedang flushing queries.
func create_resonance_projectile(
	player: Node2D,
	spawn_position: Vector2,
	target: Node2D
) -> void:
	if player == null:
		return

	if not is_instance_valid(player):
		return

	if target == null:
		return

	if not is_instance_valid(target):
		return

	if target.is_queued_for_deletion():
		return

	var sword = projectile_scene.instantiate()

	var resonance_damage_result: Dictionary = (
		player.player_stats.calculate_damage_result(
			base_damage
		)
	)

	player.get_parent().add_child(sword)

	sword.global_position = spawn_position
	sword.damage = float(
		resonance_damage_result["damage"]
	)
	sword.is_critical = bool(
		resonance_damage_result["is_critical"]
	)
	sword.is_resonance_projectile = true
	sword.resonance_triggered = true
	sword.pierce = 0

	sword.setup(
		target.global_position
	)

	DebugLogger.combat(
		"SWORD DAO RESONANCE | Additional Spirit Sword spawned."
	)

## Memilih target Spirit Sword kedua. Enemy terdekat selain primary diprioritaskan.
## Bila tidak ada target kedua yang valid, projectile kedua kembali ke primary
## sehingga jumlah projectile tidak berkurang dan centerline tetap aman.
func resolve_secondary_attack_target(
	origin_position: Vector2,
	primary_target: Node2D,
	candidates: Array[Node]
) -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance: float = INF

	for enemy_node in candidates:
		if not enemy_node is Node2D:
			continue

		var enemy := enemy_node as Node2D

		if enemy == primary_target:
			continue

		if not is_instance_valid(enemy):
			continue

		if enemy.is_queued_for_deletion():
			continue

		var distance: float = origin_position.distance_to(
			enemy.global_position
		)

		if distance >= nearest_distance:
			continue

		nearest_distance = distance
		nearest_enemy = enemy

	if nearest_enemy != null:
		return nearest_enemy

	return primary_target

## Memberi origin kedua sedikit offset saat kedua pedang mengejar target yang sama.
## Target position tetap pusat enemy; offset hanya mencegah dua Area2D bertumpuk
## sempurna pada frame spawn.
func get_secondary_origin_offset(
	origin_position: Vector2,
	target_position: Vector2
) -> Vector2:
	var direction: Vector2 = origin_position.direction_to(
		target_position
	)

	if direction.is_zero_approx():
		return Vector2(0.0, -12.0)

	return direction.orthogonal().normalized() * 12.0

func upgrade() -> void:
	if level >= MAX_LEVEL:
		return
	level += 1
	base_damage += 5.0

	DebugLogger.system(str("Spirit Sword Level: ", level))
	DebugLogger.system(str("Spirit Sword Damage: ", base_damage))
