extends Node2D

## One bounded flight. Collision is swept between simulated positions, not
## based on rendered frames. One hit per enemy per phase, including spin.
const Art = preload("res://scripts/weapon/returning_glaive_art.gd")
const OUT_TIME: float = 0.46
const SPIN_TIME: float = 0.24
const RETURN_SPEED: float = 580.0
const HIT_RADIUS: float = 24.0
const CLOSURE_RADIUS: float = 58.0
var player_ref: WeakRef
var origin: Vector2
var endpoint: Vector2
var curve: float = 0.0
var side: float = 1.0
var base_damage: float = 10.0
var twin: bool = false
var final_refinement: bool = false
var launch_delay: float = 0.0
var phase: int = 0 # outbound, spin, returning, caught
var phase_age: float = 0.0
var age: float = 0.0
var lifetime_age: float = 0.0
var outbound_critical: bool = false
var return_bonus_used: bool = false
var hits: Dictionary = {}
var trail: PackedVector2Array = PackedVector2Array()
var hit_flashes: Array[Dictionary] = []
var normal_range: float = 320.0
var boss_range: float = 230.0

static func living(value: Variant) -> bool:
	return is_instance_valid(value) and value is Node2D and not value.is_queued_for_deletion() and value.is_in_group("enemy") and not bool(value.get("is_dead")) and value.has_method("take_damage")

func configure(player: Node2D, target_position: Vector2, amount: float, level: int, direction_side: float, delay: float) -> void:
	player_ref = weakref(player)
	origin = player.global_position
	global_position = origin
	var direction: Vector2 = origin.direction_to(target_position)
	if direction.is_zero_approx(): direction = Vector2.UP
	var manager: Node = player.get_node_or_null("WeaponManager")
	if manager != null:
		normal_range = manager.maximum_attack_range
		boss_range = manager.boss_attack_range
	var distance: float = clampf(origin.distance_to(target_position) + 32.0, 120.0, normal_range - HIT_RADIUS)
	endpoint = origin + direction * distance
	curve = 52.0 if level >= 3 else 0.0
	side = direction_side
	base_damage = amount
	twin = level >= 5
	final_refinement = level >= 7
	launch_delay = delay
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	z_index = 8
	add_to_group("returning_glaive_flight")

func _physics_process(delta: float) -> void:
	lifetime_age += delta
	if lifetime_age > 3.4: queue_free(); return
	var player: Variant = player_ref.get_ref()
	if not is_instance_valid(player) or player.is_queued_for_deletion(): queue_free(); return
	if launch_delay > 0.0:
		launch_delay -= delta
		if launch_delay > 0.0: return
		delta = -launch_delay
		launch_delay = 0.0
		AudioManager.play_sfx("sword")
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	# Bounded substeps handle slow frames and phase boundaries without tunneling.
	var remaining: float = minf(delta, 0.5)
	while remaining > 0.00001 and not is_queued_for_deletion():
		var step: float = minf(remaining, 0.025)
		_advance(step, player, enemies)
		remaining -= step
	queue_redraw()

func _advance(delta: float, player: Node2D, enemies: Array[Node]) -> void:
	age += delta
	phase_age += delta
	var previous: Vector2 = global_position
	match phase:
		0:
			var t: float = minf(phase_age / OUT_TIME, 1.0)
			global_position = origin.lerp(endpoint, t) + origin.direction_to(endpoint).orthogonal() * sin(t * PI) * curve * side
			_sweep(previous, global_position, player, enemies, 0, 0.55 if twin else 0.80)
			if phase_age >= OUT_TIME: phase = 1; phase_age = 0.0
		1:
			_sweep(global_position, global_position, player, enemies, 1, 0.20 if twin else 0.30)
			if phase_age >= SPIN_TIME: phase = 2; phase_age = 0.0; AudioManager.play_sfx("sword")
		2:
			global_position = global_position.move_toward(player.global_position, RETURN_SPEED * delta)
			_sweep(previous, global_position, player, enemies, 2, 0.75 if twin else 1.0)
			if global_position.distance_to(player.global_position) <= 18.0:
				global_position = player.global_position
				phase = 3; phase_age = 0.0
				if final_refinement:
					for enemy: Node in enemies:
						if living(enemy) and enemy.global_position.distance_to(player.global_position) <= CLOSURE_RADIUS:
							_hit(player, enemy, 3, 0.35)
				AudioManager.play_sfx("chain")
			elif phase_age >= 2.2: queue_free() # Lost/displaced player: no fake catch bonus.
		3:
			if phase_age >= 0.32: queue_free()
	if phase != 3:
		trail.append(global_position)
		if trail.size() > 12: trail.remove_at(0)
	for i: int in range(hit_flashes.size()-1, -1, -1):
		hit_flashes[i].age += delta
		if float(hit_flashes[i].age) > 0.16: hit_flashes.remove_at(i)

func _sweep(start: Vector2, finish: Vector2, player: Node2D, enemies: Array[Node], phase_id: int, multiplier: float) -> void:
	for enemy: Node in enemies:
		if not living(enemy): continue
		var reach: float = boss_range if enemy.is_in_group("boss") else normal_range
		if enemy.global_position.distance_to(player.global_position) > reach: continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, finish)
		if closest.distance_to(enemy.global_position) <= HIT_RADIUS:
			_hit(player, enemy, phase_id, multiplier)

func _hit(player: Node2D, enemy: Node2D, phase_id: int, multiplier: float) -> void:
	var key: String = "%d:%d" % [phase_id, enemy.get_instance_id()]
	if hits.has(key): return
	hits[key] = true
	var stats: Node = player.get("player_stats")
	if stats == null: return
	if phase_id == 2 and outbound_critical and not return_bonus_used and stats.has_sword_dao_resonance():
		multiplier += 0.40
		return_bonus_used = true
	var result: Dictionary = stats.calculate_damage_result(base_damage * multiplier)
	if phase_id == 0 and bool(result.is_critical): outbound_critical = true
	CombatFeedback.mark_next_hit_critical(enemy, bool(result.is_critical))
	var hit_position: Vector2 = enemy.global_position
	enemy.take_damage(float(result.damage))
	if hit_flashes.size() >= 6: hit_flashes.pop_front()
	hit_flashes.append({"position":hit_position, "age":0.0})

func _draw() -> void:
	if launch_delay > 0.0: return
	var reduced: bool = SettingsManager.reduced_effects
	var local_trail := PackedVector2Array()
	for p: Vector2 in trail: local_trail.append(p - global_position)
	Art.trail(self, local_trail, phase >= 2, reduced)
	if phase < 3:
		var player: Variant = player_ref.get_ref()
		var powered: bool = phase == 2 and outbound_critical and not return_bonus_used and is_instance_valid(player) and player.player_stats.has_sword_dao_resonance()
		Art.disc(self, Vector2.ZERO, age * 15.0 * side, phase >= 2, reduced, 58.0, powered)
	elif final_refinement:
		Art.closure(self, Vector2.ZERO, phase_age, reduced)
	for entry: Dictionary in hit_flashes:
		var alpha: float = 1.0 - float(entry.age) / 0.16
		draw_arc(entry.position - global_position, 8 + float(entry.age)*90, 0, TAU, 16, Color(Art.GOLD if phase >= 2 else Art.CYAN, alpha * 0.7), 1.3, true)
