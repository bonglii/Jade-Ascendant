extends Area2D

signal critical_hit_confirmed(
	source_projectile: Area2D,
	hit_enemy: Node2D,
	hit_position: Vector2
)

## Spirit Sword Projectile
## Original player projectiles are aligned to Player/CombatOrigin.
## Resonance projectiles intentionally retain their actual hit position.

const SPIRIT_SWORD_IMPACT_SCENE: PackedScene = preload(
	"res://scenes/weapons/spirit_sword_impact.tscn"
)

@export var speed: float = 500.0
@export var damage: float = 10.0
@export var attack_cooldown: float = 1.0

var attack_timer: float = 0.0
var direction: Vector2 = Vector2.ZERO

var is_critical: bool = false
var is_resonance_projectile: bool = false
var resonance_triggered: bool = false

var pierce: int = 0
var lifetime: float = 4.0
var hit_ids: Array[int] = []
var consumed: bool = false


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	position += direction * speed * delta


func setup(target_position: Vector2) -> void:
	if not is_resonance_projectile:
		_align_original_spawn_to_combat_origin()

	direction = global_position.direction_to(
		target_position
	)

	rotation = direction.angle()


func _align_original_spawn_to_combat_origin() -> void:
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

	# Preserve the existing secondary-projectile perpendicular spawn offset.
	var existing_spawn_offset: Vector2 = (
		global_position - player.global_position
	)
	global_position = (
		combat_origin.global_position
		+ existing_spawn_offset
	)


func mark_resonance_triggered() -> void:
	resonance_triggered = true


func run_resonance_guard_test() -> bool:
	if is_resonance_projectile:
		return false

	var original_is_critical: bool = is_critical
	var original_resonance_triggered: bool = resonance_triggered

	is_critical = true
	resonance_triggered = true

	var guard_active: bool = resonance_triggered

	if guard_active:
		DebugLogger.combat(
			"SPIRIT SWORD | Resonance already triggered."
		)

	is_critical = original_is_critical
	resonance_triggered = original_resonance_triggered

	return guard_active


func _on_body_entered(body: Node2D) -> void:
	if (
		consumed
		or not body.is_in_group("enemy")
		or body.get_instance_id() in hit_ids
	):
		return

	hit_ids.append(body.get_instance_id())

	body.take_damage(damage)
	spawn_hit_visual()

	if is_critical:
		DebugLogger.combat(
			"SPIRIT SWORD ACTUAL CRITICAL HIT CONFIRMED"
		)

	try_emit_critical_hit(body)

	if pierce > 0:
		pierce -= 1
		return

	consumed = true
	queue_free()


func spawn_hit_visual() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var effect := (
		SPIRIT_SWORD_IMPACT_SCENE.instantiate()
		as SpiritSwordImpact
	)
	if effect == null:
		return

	current_scene.add_child(effect)
	effect.global_position = global_position
	effect.setup(
		is_critical,
		is_resonance_projectile
	)


func try_emit_critical_hit(hit_enemy: Node2D) -> void:
	if not is_critical:
		return

	if is_resonance_projectile:
		DebugLogger.combat(
			"RESONANCE PROJECTILE | Chain blocked."
		)
		return

	if resonance_triggered:
		DebugLogger.combat(
			"SPIRIT SWORD | Resonance already triggered."
		)
		return

	DebugLogger.combat(
		"SPIRIT SWORD | Emitting critical_hit_confirmed."
	)

	critical_hit_confirmed.emit(
		self,
		hit_enemy,
		global_position
	)
