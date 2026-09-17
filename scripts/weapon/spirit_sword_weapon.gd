class_name SpiritSwordWeapon
extends Weapon

## Spirit Sword Weapon
## Internal weapon identity remains Spirit Sword for checkpoint v1 compatibility.
## Permanent armament equipment can override presentation via a combat profile.

@export var projectile_scene: PackedScene = preload(
    "res://scenes/weapons/spirit_sword.tscn"
)

const ArmamentCombatCatalog = preload(
    "res://scripts/data/armament_combat_catalog.gd"
)
const MAX_LEVEL: int = 7

var level: int = 1
var base_damage: float = 10.0
var armament_id: String = ""
var armament_profile: Dictionary = {}

func configure_armament(new_armament_id: String) -> void:
    armament_id = new_armament_id
    armament_profile = ArmamentCombatCatalog.get_profile(armament_id)

func get_combat_display_name() -> String:
    if armament_profile.is_empty():
        armament_profile = ArmamentCombatCatalog.get_profile(armament_id)
    return str(armament_profile.get("combat_display_name", "Spirit Sword"))

func _ready() -> void:
    if armament_profile.is_empty():
        armament_profile = ArmamentCombatCatalog.get_profile(armament_id)
    # Do not rename this: checkpoint v1 resolves starter progression by this key.
    weapon_name = "Spirit Sword"
    cooldown = 1.0

func attack(player: Node2D, target: Node2D) -> void:
    if player == null or target == null:
        return

    create_projectile(player, target, Vector2.ZERO)

    if level < 5:
        return

    var secondary_target: Node2D = resolve_secondary_attack_target(
        player.global_position,
        target,
        get_tree().get_nodes_in_group("enemy")
    )

    var secondary_origin_offset: Vector2 = Vector2.ZERO
    if secondary_target == target:
        secondary_origin_offset = get_secondary_origin_offset(
            player.global_position,
            target.global_position
        )

    create_projectile(player, secondary_target, secondary_origin_offset)

func create_projectile(
    player: Node2D,
    target: Node2D,
    spawn_offset: Vector2 = Vector2.ZERO
) -> void:
    var sword = projectile_scene.instantiate()
    var damage_result: Dictionary = player.player_stats.calculate_damage_result(
        base_damage
    )

    if sword.has_method("configure_combat_profile"):
        sword.configure_combat_profile(armament_profile)

    player.get_parent().add_child(sword)
    sword.global_position = player.global_position + spawn_offset
    sword.damage = float(damage_result["damage"])
    sword.is_critical = bool(damage_result["is_critical"])
    sword.is_resonance_projectile = false
    sword.resonance_triggered = false

    connect_projectile_signals(sword, player)

    if level >= 7:
        sword.pierce = 1

    sword.setup(target.global_position)

func connect_projectile_signals(sword: Area2D, player: Node2D) -> void:
    sword.critical_hit_confirmed.connect(
        _on_projectile_critical_hit.bind(player)
    )

func _on_projectile_critical_hit(
    source_projectile: Area2D,
    hit_enemy: Node2D,
    hit_position: Vector2,
    player: Node2D
) -> void:
    DebugLogger.combat("SWORD DAO RESONANCE | Critical signal received.")

    if source_projectile == null or not is_instance_valid(source_projectile):
        return
    if player == null or not is_instance_valid(player):
        return
    if not player.player_stats.has_sword_dao_resonance():
        return

    var resonance_target: Node2D = find_resonance_target(hit_position, hit_enemy)
    if resonance_target == null:
        return

    source_projectile.mark_resonance_triggered()
    call_deferred(
        "create_resonance_projectile",
        player,
        hit_position,
        resonance_target
    )

func find_resonance_target(
    origin_position: Vector2,
    excluded_enemy: Node2D
) -> Node2D:
    var nearest_enemy: Node2D = null
    var nearest_distance: float = INF

    for enemy_node in get_tree().get_nodes_in_group("enemy"):
        if not enemy_node is Node2D:
            continue
        var enemy := enemy_node as Node2D
        if enemy == excluded_enemy:
            continue
        if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
            continue
        var distance: float = origin_position.distance_to(enemy.global_position)
        if distance >= nearest_distance:
            continue
        nearest_distance = distance
        nearest_enemy = enemy

    return nearest_enemy

func create_resonance_projectile(
    player: Node2D,
    spawn_position: Vector2,
    target: Node2D
) -> void:
    if player == null or not is_instance_valid(player):
        return
    if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
        return

    var sword = projectile_scene.instantiate()
    var damage_result: Dictionary = player.player_stats.calculate_damage_result(
        base_damage
    )

    if sword.has_method("configure_combat_profile"):
        sword.configure_combat_profile(armament_profile)

    player.get_parent().add_child(sword)
    sword.global_position = spawn_position
    sword.damage = float(damage_result["damage"])
    sword.is_critical = bool(damage_result["is_critical"])
    sword.is_resonance_projectile = true
    sword.resonance_triggered = true
    sword.pierce = 0
    sword.setup(target.global_position)

    DebugLogger.combat("SWORD DAO RESONANCE | Additional Spirit Sword spawned.")

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
        if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
            continue
        var distance: float = origin_position.distance_to(enemy.global_position)
        if distance >= nearest_distance:
            continue
        nearest_distance = distance
        nearest_enemy = enemy

    if nearest_enemy != null:
        return nearest_enemy
    return primary_target

func get_secondary_origin_offset(
    origin_position: Vector2,
    target_position: Vector2
) -> Vector2:
    var direction: Vector2 = origin_position.direction_to(target_position)
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
