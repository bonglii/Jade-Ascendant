extends SpiritSwordWeapon

const Cast = preload("res://scripts/weapon/jade_binding_cast.gd")

func _ready() -> void:
	super._ready()
	cooldown = 1.8

func get_binding_target_count() -> int:
	return 2 + int(level >= 3) + int(level >= 5) + int(level >= 7)

func get_binding_radius() -> float:
	return 80.0 + 12.0 * (get_binding_target_count() - 2)

func attack(player: Node2D, target: Node2D) -> void:
	if not Cast.living(target) or not is_instance_valid(player): return
	var selected: Array[Node2D] = [target]
	var candidates: Array[Node2D] = []
	var radius: float = get_binding_radius()
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		if not Cast.living(node) or node == target: continue
		if node.global_position.distance_to(target.global_position) > radius: continue
		if node.global_position.distance_to(player.global_position) > (230.0 if node.is_in_group("boss") else 320.0): continue
		candidates.append(node)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position))
	for candidate: Node2D in candidates:
		if selected.size() >= get_binding_target_count(): break
		selected.append(candidate)
	var cast := Cast.new()
	player.get_parent().add_child(cast)
	cast.configure(player, selected, radius, base_damage * EquipmentManager.get_weapon_level_multiplier(armament_id))
	AudioManager.play_sfx("chain")
