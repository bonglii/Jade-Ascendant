extends Node2D

const Art = preload("res://scripts/weapon/jade_binding_art.gd")
const Slow = preload("res://scripts/weapon/jade_binding_slow.gd")
const SEAL_TIME: float = 0.22
const DETONATE_TIME: float = 0.82
var age: float = 0.0
var radius: float = 80.0
var base_damage: float = 10.0
var player_ref: WeakRef
var targets: Array[Dictionary] = []
var resonance_used: bool = false
var resonance_position: Vector2 = Vector2.ZERO
var resonance_age: float = -1.0

static func living(value: Variant) -> bool:
	return is_instance_valid(value) and value is Node2D and not value.is_queued_for_deletion() and value.is_in_group("enemy") and not bool(value.get("is_dead")) and value.has_method("take_damage")

func configure(player: Node2D, enemies: Array[Node2D], cast_radius: float, amount: float) -> void:
	player_ref = weakref(player)
	radius = cast_radius
	base_damage = amount
	global_position = enemies[0].global_position
	for enemy: Node2D in enemies:
		targets.append({"ref": weakref(enemy), "position": enemy.global_position - global_position, "bound": false, "detonated": false, "burst_age": -1.0})
	z_index = 8
	add_to_group("jade_binding_cast")

func _process(delta: float) -> void:
	age += delta
	var player: Variant = player_ref.get_ref()
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		queue_free(); return
	for i: int in range(targets.size()):
		var entry: Dictionary = targets[i]
		var enemy: Variant = entry.ref.get_ref()
		if living(enemy):
			entry.position = enemy.global_position - global_position
		if age >= SEAL_TIME and not entry.bound:
			entry.bound = true
			if living(enemy) and enemy.global_position.distance_to(player.global_position) <= (230.0 if enemy.is_in_group("boss") else 320.0):
				Slow.apply(enemy)
				_hit(player, enemy, 0.30 if i == 0 else 0.20)
			else:
				entry.detonated = true
		if age >= DETONATE_TIME + i * 0.10 and not entry.detonated:
			entry.detonated = true
			if living(enemy) and enemy.global_position.distance_to(player.global_position) <= (230.0 if enemy.is_in_group("boss") else 320.0):
				entry.burst_age = age
				_hit(player, enemy, 1.50 if i == 0 else 0.80)
				if i == 0: AudioManager.play_sfx("chain")
	if age >= DETONATE_TIME + (targets.size() - 1) * 0.10 + 0.45:
		queue_free(); return
	queue_redraw()

func _hit(player: Node2D, enemy: Node2D, multiplier: float) -> void:
	var stats: Node = player.get("player_stats")
	if stats == null: return
	var result: Dictionary = stats.calculate_damage_result(base_damage * multiplier)
	CombatFeedback.mark_next_hit_critical(enemy, bool(result.is_critical))
	enemy.take_damage(float(result.damage))
	# Keep the existing critical resonance meaningful without spawning a sword,
	# recursively triggering another cast or hitting the same victim twice.
	if resonance_used or not bool(result.is_critical) or not stats.has_sword_dao_resonance(): return
	resonance_used = true
	var candidate: Node2D = null
	var nearest: float = radius
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		if not living(node): continue
		var already_bound: bool = false
		for entry: Dictionary in targets:
			if entry.ref.get_ref() == node: already_bound = true; break
		if already_bound: continue
		var distance: float = node.global_position.distance_to(global_position)
		if distance < nearest and node.global_position.distance_to(player.global_position) <= (230.0 if node.is_in_group("boss") else 320.0):
			candidate = node; nearest = distance
	if candidate != null:
		resonance_position = candidate.global_position - global_position
		resonance_age = age
		var bonus: Dictionary = stats.calculate_damage_result(base_damage * 0.40)
		CombatFeedback.mark_next_hit_critical(candidate, bool(bonus.is_critical))
		candidate.take_damage(float(bonus.damage))

func _draw() -> void:
	var reduced: bool = SettingsManager.reduced_effects
	var fade: float = clampf((1.45 - age) / 0.4, 0.0, 1.0)
	var appear: float = minf(age / SEAL_TIME, 1.0)
	Art.seal(self, Vector2.ZERO, radius * (0.65 + appear * 0.35), age, appear * fade, reduced)
	if age < SEAL_TIME: return
	var player: Variant = player_ref.get_ref()
	if is_instance_valid(player) and age < DETONATE_TIME:
		Art.chain(self, player.global_position - global_position, Vector2.ZERO, age, fade * 0.72, reduced)
	for i: int in range(targets.size()):
		var entry: Dictionary = targets[i]
		if not entry.detonated and living(entry.ref.get_ref()):
			Art.chain(self, Vector2.ZERO, entry.position, age + i, fade, reduced)
			Art.knot(self, entry.position, 10.0 + sin(age * 8) * 1.0, fade)
		if float(entry.burst_age) >= 0.0:
			Art.burst(self, entry.position, minf((age - float(entry.burst_age)) / 0.42, 1.0), reduced)
	if resonance_age >= 0.0:
		Art.burst(self, resonance_position, minf((age - resonance_age) / 0.42, 1.0), reduced)
