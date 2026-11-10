extends Node2D

const Vfx = preload("res://scripts/effects/weapon_vfx_art.gd")
const Ledger = preload("res://scripts/weapon/run_combat_ledger.gd")
const SetRuntime = preload("res://scripts/data/equipment_set_runtime.gd")
const RADIUS: float = 148.0
const TRAVEL: float = 0.28
const FADE: float = 0.18

var _player: Node2D
var _remaining: Array[Node2D]
var _damage: float
var _push: float
var _resonance: bool
var _age: float = 0.0
var _radius: float = 0.0

static func living(enemy: Variant) -> bool:
	return (is_instance_valid(enemy) and enemy is Node2D and not enemy.is_queued_for_deletion()
		and enemy.is_in_group("enemy") and not bool(enemy.get("is_dead"))
		and enemy.has_method("take_damage"))

func configure(player: Node2D, enemies: Array[Node2D], damage: float, push: float) -> void:
	_player = player
	_remaining = enemies
	_damage = damage
	_push = push
	_resonance = player.player_stats.has_sword_dao_resonance()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		queue_free()
		return
	var previous_age: float = _age
	_age += delta
	_radius = RADIUS * ease(clampf(_age / TRAVEL, 0.0, 1.0), 0.66)
	if previous_age < TRAVEL and not _remaining.is_empty():
		_hit_wavefront()
	queue_redraw()
	if _age >= TRAVEL + FADE:
		queue_free()

func _hit_wavefront() -> void:
	SetRuntime.begin_combat_batch()
	for i in range(_remaining.size() - 1, -1, -1):
		var enemy: Node2D = _remaining[i]
		if not living(enemy):
			_remaining.remove_at(i)
			continue
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length_squared() > _radius * _radius:
			continue
		_remaining.remove_at(i)
		var boss: bool = enemy.is_in_group("boss")
		var result: Dictionary = _player.player_stats.calculate_damage_result(_damage * (0.65 if boss else 1.0))
		var critical: bool = bool(result["is_critical"])
		CombatFeedback.mark_next_hit_critical(enemy, critical)
		var resonant: bool = _resonance and critical
		if Ledger.apply_hit(enemy, float(result["damage"]) * (1.4 if resonant else 1.0), "gale_parasol") <= 0.0:
			continue
		if resonant:
			_resonance = false
		if not boss and living(enemy) and not enemy.is_in_group("elite") and enemy is CharacterBody2D:
			var direction: Vector2 = offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT
			enemy.move_and_collide(direction * _push)
	SetRuntime.end_combat_batch()

func _draw() -> void:
	var alpha: float = 1.0 - clampf((_age - TRAVEL) / FADE, 0.0, 1.0)
	if _radius <= 1.0 or alpha <= 0.0:
		return
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(0.70, 1.0, 0.76, alpha * 0.85), 2.6, true)
	if not Vfx.low_detail(self):
		Vfx.curls(self, Vector2.ZERO, _radius, -_age * 3.0, Color(0.40, 0.92, 0.70, alpha * 0.72), 6)
		Vfx.curls(self, Vector2.ZERO, _radius * 0.69, _age * 3.0 + 0.40,
			Color(0.82, 0.93, 0.57, alpha * 0.38), 3)
