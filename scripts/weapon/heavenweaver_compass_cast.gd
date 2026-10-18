extends Node2D
const DRAGON = preload("res://assets/ui/liveops/odyssey/dragon.png")
const COMPASS = preload("res://assets/ui/liveops/odyssey/compass.png")
const Ledger = preload("res://scripts/weapon/run_combat_ledger.gd")
const WINDUP: float = 0.24
var age: float = 0.0
var duration: float = 0.5
var amount: float = 10.0
var combat_level: int = 1
var player_ref: WeakRef
var selected: Array[WeakRef] = []
var candidates: Array[WeakRef] = []
var path: PackedVector2Array = []
var distances: PackedFloat32Array = []
var total_distance: float = 0.0
var hits: Array[Dictionary] = [{}, {}]
var marked: bool = false
var resonance_used: bool = false
var impacts: Array[Dictionary] = []
var trail: PackedVector2Array = []
var head: Sprite2D
static func living(value: Variant) -> bool:
	return is_instance_valid(value) and value is Node2D and not value.is_queued_for_deletion() and value.is_in_group("enemy") and not bool(value.get("is_dead")) and value.has_method("take_damage")
static func in_range(player: Node2D, enemy: Node2D) -> bool:
	return player.global_position.distance_to(enemy.global_position) <= (230.0 if enemy.is_in_group("boss") else 320.0)
func configure(player: Node2D, enemies: Array[Node2D], damage: float, weapon_level: int) -> void:
	player_ref = weakref(player); amount = damage; combat_level = weapon_level
	global_position = player.global_position; path.append(Vector2.ZERO)
	for enemy: Node2D in enemies:
		selected.append(weakref(enemy)); candidates.append(weakref(enemy)); path.append(enemy.global_position - global_position)
	if enemies.size() == 1:
		path.append(path[-1] + path[-1].normalized() * 28.0)
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if candidates.size() >= 64: break
		if living(enemy) and enemy not in enemies and in_range(player, enemy): candidates.append(weakref(enemy))
	distances.append(0.0)
	for i: int in range(1, path.size()):
		total_distance += path[i - 1].distance_to(path[i]); distances.append(total_distance)
	duration = clampf(total_distance / 560.0, 0.35, 0.95)
	head = Sprite2D.new(); head.texture = DRAGON; head.scale = Vector2.ONE * 66.0 / DRAGON.get_width()
	head.offset.x = -DRAGON.get_width() * 0.28
	head.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	head.hide(); add_child(head); z_index = 8; add_to_group("heavenweaver_cast")
func _point(fraction: float) -> Vector2:
	var distance: float = clampf(fraction, 0.0, 1.0) * total_distance
	for i: int in range(1, path.size()):
		if distance <= distances[i]: return path[i - 1].lerp(path[i], (distance - distances[i - 1]) / maxf(0.001, distances[i] - distances[i - 1]))
	return path[-1]
func _process(delta: float) -> void:
	if player_ref == null: return
	var player: Node2D = player_ref.get_ref() as Node2D
	if not is_instance_valid(player) or player.is_queued_for_deletion(): queue_free(); return
	var before: float = maxf(0.0, age - WINDUP)
	age += delta
	var elapsed: float = maxf(0.0, age - WINDUP)
	if age >= WINDUP:
		if not marked:
			marked = true
			for ref: WeakRef in selected:
				var enemy: Node2D = ref.get_ref() as Node2D
				if living(enemy) and in_range(player, enemy): _hit(player, enemy, 0.2, false)
		_sweep(player, clampf(before / duration, 0, 1), clampf(elapsed / duration, 0, 1), 0)
		if combat_level >= 5:
			_sweep(player, 1.0 - clampf((before - duration) / duration, 0, 1), 1.0 - clampf((elapsed - duration) / duration, 0, 1), 1)
		var returning: bool = combat_level >= 5 and elapsed > duration
		var progress: float = 1.0 - clampf((elapsed - duration) / duration, 0, 1) if returning else clampf(elapsed / duration, 0, 1)
		var current: Vector2 = _point(progress)
		var tangent: Vector2 = _point(clampf(progress + (-0.01 if returning else 0.01), 0, 1)) - current
		if tangent.length_squared() < 0.01: tangent = current - head.position
		head.rotation = tangent.angle(); head.position = current; head.visible = elapsed < duration * (2.0 if combat_level >= 5 else 1.0)
		trail.append(current)
		while trail.size() > (8 if SettingsManager.reduced_effects else 18): trail.remove_at(0)
	if elapsed > duration * (2.0 if combat_level >= 5 else 1.0) + 0.28: queue_free(); return
	queue_redraw()
func _sweep(player: Node2D, from: float, to: float, phase: int) -> void:
	if is_equal_approx(from, to): return
	var points: PackedVector2Array = [_point(from)]
	var indexes: Array[int] = []
	for i: int in range(1, path.size() - 1):
		var fraction: float = distances[i] / maxf(total_distance, 0.001)
		if fraction > minf(from, to) and fraction < maxf(from, to): indexes.append(i)
	if from > to: indexes.reverse()
	for i: int in indexes: points.append(path[i])
	points.append(_point(to))
	for ref: WeakRef in candidates:
		if hits[phase].size() >= 12: break
		var enemy: Node2D = ref.get_ref() as Node2D
		if not living(enemy) or not in_range(player, enemy) or hits[phase].has(enemy.get_instance_id()): continue
		for i: int in range(1, points.size()):
			var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position - global_position, points[i - 1], points[i])
			if nearest.distance_to(enemy.global_position - global_position) <= (22.0 if combat_level >= 7 else 18.0):
				hits[phase][enemy.get_instance_id()] = true
				var multiplier: float = 1.8 if not selected.is_empty() and selected[0].get_ref() == enemy else 0.9
				_hit(player, enemy, multiplier * (0.35 if phase == 1 else 1.0), true); break
func _hit(player: Node2D, enemy: Node2D, multiplier: float, dragon_hit: bool) -> void:
	var stats: Node = player.get_node_or_null("PlayerStats")
	if stats == null: return
	var result: Dictionary = stats.call("calculate_damage_result", amount * multiplier)
	CombatFeedback.mark_next_hit_critical(enemy, bool(result.is_critical))
	Ledger.apply_hit(enemy, float(result.damage), "heavenweaver_compass")
	impacts.append({"position": enemy.global_position - global_position, "time": age})
	if dragon_hit and not resonance_used and bool(result.is_critical) and bool(stats.call("has_sword_dao_resonance")) and living(enemy):
		resonance_used = true
		var bonus: Dictionary = stats.call("calculate_damage_result", amount * 0.4)
		CombatFeedback.mark_next_hit_critical(enemy, bool(bonus.is_critical))
		Ledger.apply_hit(enemy, float(bonus.damage), "heavenweaver_compass")
func _draw() -> void:
	if path.size() < 2: return
	if age < WINDUP:
		draw_polyline(path, Color(0.6, 0.92, 0.75, 0.28), 1.5, true)
		for i: int in range(1, path.size()): draw_texture_rect(COMPASS, Rect2(path[i] - Vector2.ONE * 14.0, Vector2.ONE * 28.0), false, Color(1, 1, 1, 0.75))
	if trail.size() > 1:
		draw_polyline(trail, Color(0.1, 0.9, 0.67, 0.16), 24, true)
		draw_polyline(trail, Color(0.3, 0.94, 0.7, 0.75), 7, true)
		draw_polyline(trail, Color(1, 0.9, 0.56, 0.9), 1.8, true)
	for impact: Dictionary in impacts:
		var progress: float = clampf((age - float(impact.time)) / 0.28, 0, 1)
		if progress >= 1: continue
		var point: Vector2 = impact.position
		draw_arc(point, 5 + progress * 16, 0, TAU, 24, Color(1, 0.84, 0.45, 1 - progress), 1.5, true)
		for i: int in range(4 if SettingsManager.reduced_effects else 6):
			var direction: Vector2 = Vector2.from_angle(float(i) * TAU / 6.0 + 0.2)
			draw_line(point + direction * (5 + progress * 8), point + direction * (12 + progress * 17), Color(0.36, 1, 0.74, 1 - progress), 2, true)
