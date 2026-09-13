class_name ThunderTalismanWeapon
extends Weapon

## Thunder Talisman Weapon
## Menyerang target utama dengan petir spiritual
## lalu merambat ke enemy terdekat berikutnya.
## Final damage dihitung melalui PlayerStats.

const CHAIN_RANGE: float = 180.0
const TALISMAN_STRIKE_SCENE: PackedScene = preload(
	"res://scenes/weapons/thunder_talisman_strike.tscn"
)

const MAX_LEVEL: int = 7

var level: int = 1
var base_damage: float = 8.0
var chain_count: int = 2

func _ready() -> void:
	weapon_name = "Thunder Talisman"
	cooldown = 1.5

func attack(player: Node2D, target: Node2D) -> void:
	if player == null or target == null:
		return

	if not is_instance_valid(target):
		return

	var enemy_candidates: Array[Node] = (
		get_tree().get_nodes_in_group("enemy")
	)
	var hit_targets: Array[Node2D] = []
	var current_target: Node2D = target
	var arc_origin: Vector2 = player.global_position
	var empowered: bool = player.player_stats.has_heavenly_tribulation()
	AudioManager.play_sfx("thunder")

	for i in range(chain_count):
		if current_target == null:
			break

		if not is_instance_valid(current_target):
			break

		var arc_end: Vector2 = current_target.global_position

		if i == 0:
			spawn_primary_talisman_visual(
				player,
				arc_end
			)
		else:
			CombatFeedback.lightning(
				arc_origin,
				arc_end,
				float(i) * 0.025,
				empowered
			)

		hit_target(player, current_target)
		hit_targets.append(current_target)
		arc_origin = arc_end

		current_target = find_next_chain_target(
			current_target,
			hit_targets,
			enemy_candidates
		)

func spawn_primary_talisman_visual(
	player: Node2D,
	target_position: Vector2
) -> void:
	if player == null:
		return

	var current_scene: Node = player.get_tree().current_scene
	if current_scene == null:
		return

	var effect := TALISMAN_STRIKE_SCENE.instantiate() as ThunderTalismanStrike
	if effect == null:
		return

	current_scene.add_child(effect)
	effect.global_position = player.global_position
	effect.setup(
		target_position,
		true
	)

func hit_target(player: Node2D, target: Node2D) -> void:
	if not target.has_method("take_damage"):
		return

	var final_damage: float = (
		player.player_stats.calculate_damage(
			base_damage
		)
	)

	target.take_damage(final_damage)

	DebugLogger.system(str(
		"Thunder Talisman Hit: ",
		target.name,
		" | Damage: ",
		final_damage
	))

func find_next_chain_target(
	current_target: Node2D,
	hit_targets: Array[Node2D],
	enemy_candidates: Array[Node]
) -> Node2D:
	var nearest_target: Node2D = null
	var nearest_distance_squared: float = (
		CHAIN_RANGE * CHAIN_RANGE
	)

	for enemy in enemy_candidates:
		if not enemy is Node2D:
			continue

		if enemy in hit_targets:
			continue

		if not is_instance_valid(enemy):
			continue

		if enemy.is_queued_for_deletion():
			continue

		var distance_squared: float = (
			current_target.global_position.distance_squared_to(
				enemy.global_position
			)
		)

		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_target = enemy

	return nearest_target

func upgrade() -> void:
	if level >= MAX_LEVEL:
		return
	level += 1
	base_damage += 4.0

	if level == 3:
		chain_count = 3
	elif level == 5:
		chain_count = 4
	elif level == 7:
		chain_count = 5

	DebugLogger.system(str("Thunder Talisman Level: ", level))
	DebugLogger.system(str("Thunder Talisman Damage: ", base_damage))
	DebugLogger.system(str("Thunder Talisman Chain Count: ", chain_count))
