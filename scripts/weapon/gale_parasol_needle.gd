extends Node2D

const Ledger = preload("res://scripts/weapon/run_combat_ledger.gd")
const Wind = preload("res://scripts/weapon/gale_parasol_wave.gd")
const SPEED: float = 640.0

var _direction: Vector2
var _range: float
var _boss_range: float
var _damage: float
var _critical: bool
var _resonance: bool
var _hits: int
var _distance: float = 0.0
var _excluded: Array[RID] = []

func configure(direction: Vector2, reach: float, boss_reach: float,
		result: Dictionary, hits: int, resonance: bool) -> void:
	_direction = direction
	_range = reach
	_boss_range = boss_reach
	_damage = float(result["damage"])
	_critical = bool(result["is_critical"])
	_hits = hits
	_resonance = resonance and _critical

func _physics_process(delta: float) -> void:
	var start: Vector2 = global_position
	var step: float = minf(SPEED * delta, _range - _distance)
	var end: Vector2 = start + _direction * step
	if step > 0.0:
		var ray := PhysicsRayQueryParameters2D.create(start, end, 2)
		ray.hit_from_inside = true
		for _attempt in range(8):
			ray.exclude = _excluded
			var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
			if hit.is_empty():
				break
			_excluded.append(hit["rid"])
			var enemy: Variant = hit["collider"]
			if not Wind.living(enemy):
				continue
			if enemy.is_in_group("boss") and _distance + start.distance_to(hit["position"]) > _boss_range:
				continue
			CombatFeedback.mark_next_hit_critical(enemy, _critical)
			var applied: float = Ledger.apply_hit(enemy, _damage * (1.4 if _resonance else 1.0), "gale_parasol")
			if applied <= 0.0:
				continue
			_resonance = false
			_hits -= 1
			if _hits == 0:
				queue_free()
				return
	global_position = end
	_distance += step
	if _distance >= _range:
		queue_free()

func _draw() -> void:
	if not SettingsManager.reduced_effects:
		draw_colored_polygon(PackedVector2Array([Vector2(-36, 0), Vector2(-13, -6),
			Vector2(7, 0), Vector2(-13, 6)]), Color(0.22, 0.82, 0.59, 0.32))
	draw_colored_polygon(PackedVector2Array([Vector2(-17, 0), Vector2(-5, -2.5),
		Vector2(9, 0), Vector2(-5, 2.5)]), Color("#d9f9c5"))
