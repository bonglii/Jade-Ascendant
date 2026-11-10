class_name EightTrigramsFormation
extends Area2D

## Persistent ground-control instance for Eight Trigrams Formation.
## Visual radius is explicitly synchronized to gameplay radius.

const Vfx = preload("res://scripts/effects/weapon_vfx_art.gd")
const FORMATION_SEGMENTS: int = 56
const PULSE_VISUAL_DURATION: float = 0.24
# Visual canvas commands are capped at 30 Hz; physics/damage remain unchanged.
const VISUAL_REFRESH_INTERVAL: float = 1.0 / 30.0
const DENSE_VISUAL_REFRESH_INTERVAL: float = 1.0 / 15.0

var base_damage: float = 8.0
var radius: float = 80.0
var duration: float = 4.0
var pulse_interval: float = 0.75

var lifetime_remaining: float = 0.0
var pulse_remaining: float = 0.0

var player_stats: Node = null

var visual_age: float = 0.0
var pulse_visual_left: float = 0.0
var _visual_refresh_elapsed: float = 0.0
var _boundary: Node2D
var _dense_visuals: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var formation_sigil: Sprite2D = $FormationSigil


func _ready() -> void:
	z_index = -1
	lifetime_remaining = duration
	pulse_remaining = pulse_interval

	_set_radius(radius)
	create_formation_visual()


func _physics_process(delta: float) -> void:
	visual_age += delta
	pulse_visual_left = maxf(
		pulse_visual_left - delta,
		0.0
	)
	lifetime_remaining -= delta
	pulse_remaining -= delta

	if lifetime_remaining <= 0.0:
		queue_free()
		return

	# Only the optional animation slows down in a crowd. Pulse and collision
	# clocks are advanced independently, including on the first and last tick.
	var refresh_interval: float = DENSE_VISUAL_REFRESH_INTERVAL if _dense_visuals else VISUAL_REFRESH_INTERVAL
	_visual_refresh_elapsed += delta
	if _visual_refresh_elapsed >= refresh_interval:
		_visual_refresh_elapsed = fmod(
			_visual_refresh_elapsed,
			refresh_interval
		)
		update_formation_visual()

	if pulse_remaining <= 0.0:
		_apply_damage_pulse()
		create_damage_pulse_visual()
		pulse_remaining += pulse_interval


func setup(
	new_base_damage: float,
	new_radius: float,
	new_duration: float,
	new_pulse_interval: float,
	new_player_stats: Node
) -> void:
	base_damage = maxf(new_base_damage, 0.0)
	radius = maxf(new_radius, 0.0)
	duration = maxf(new_duration, 0.01)
	pulse_interval = maxf(
		new_pulse_interval,
		0.01
	)
	player_stats = new_player_stats

	lifetime_remaining = duration
	pulse_remaining = pulse_interval

	if is_node_ready():
		_set_radius(radius)
		rebuild_formation_visual()


func _set_radius(new_radius: float) -> void:
	if collision_shape == null:
		return

	var circle_shape := (
		collision_shape.shape
		as CircleShape2D
	)

	if circle_shape == null:
		push_error(
			"CircleShape2D tidak ditemukan untuk Eight Trigrams Formation."
		)
		return

	var duplicated_shape := (
		circle_shape.duplicate()
		as CircleShape2D
	)

	if duplicated_shape == null:
		push_error(
			"CircleShape2D Eight Trigrams Formation gagal diduplikasi."
		)
		return

	collision_shape.shape = duplicated_shape
	duplicated_shape.radius = new_radius

	_sync_sigil_to_gameplay_radius()


func _sync_sigil_to_gameplay_radius() -> void:
	if formation_sigil == null:
		return
	if formation_sigil.texture == null:
		return

	var texture_size: Vector2 = (
		formation_sigil.texture.get_size()
	)
	var source_radius: float = (
		maxf(texture_size.x, texture_size.y)
		* 0.5
	)
	if source_radius <= 0.001:
		return

	var scale_factor: float = radius / source_radius
	formation_sigil.scale = Vector2.ONE * scale_factor


func create_formation_visual() -> void:
	# The painted sigil already contains the complete Bagua artwork. Cache
	# one boundary at the actual hit radius and animate only the pulse cue.
	_boundary = Node2D.new()
	_boundary.name = "FormationBoundary"
	_boundary.draw.connect(_draw_boundary)
	add_child(_boundary)
	update_formation_visual()


func rebuild_formation_visual() -> void:
	_sync_sigil_to_gameplay_radius()
	if is_instance_valid(_boundary):
		_boundary.queue_redraw()
	update_formation_visual()


func _draw_boundary() -> void:
	_boundary.draw_arc(Vector2.ZERO, radius, 0.0, TAU, FORMATION_SEGMENTS,
		Color(0.38, 0.96, 0.72, 0.62), 2.5, true)


func update_formation_visual() -> void:
	_dense_visuals = Vfx.low_detail(self)
	var fade: float = _visual_fade()
	if is_instance_valid(_boundary):
		_boundary.modulate.a = minf(1.0, fade * (0.77 + pulse_visual_left / PULSE_VISUAL_DURATION * 0.23))
	if formation_sigil != null:
		formation_sigil.modulate.a = fade * (0.24 if _dense_visuals else 0.38)
		formation_sigil.rotation = visual_age * 0.055
	queue_redraw()


func create_damage_pulse_visual() -> void:
	pulse_visual_left = PULSE_VISUAL_DURATION
	CombatFeedback.pulse(global_position, "formation")
	queue_redraw()


func _visual_fade() -> float:
	return clampf(minf(visual_age / 0.30, lifetime_remaining / 0.40), 0.0, 1.0)


func _draw() -> void:
	var opacity: float = _visual_fade()
	var anticipation_window: float = minf(pulse_interval * 0.33, 0.28)
	if pulse_remaining > 0.0 and pulse_remaining <= anticipation_window:
		var anticipation: float = 1.0 - pulse_remaining / anticipation_window
		draw_arc(Vector2.ZERO, radius * 0.96, -PI * 0.5, -PI * 0.5 + TAU * anticipation,
			32, Color(0.98, 0.82, 0.36, opacity * (0.36 + 0.44 * anticipation)), 2.5, true)
	if pulse_visual_left > 0.0 and not _dense_visuals:
		var remaining: float = pulse_visual_left / PULSE_VISUAL_DURATION
		var wave: float = radius * lerpf(1.0, 0.36, remaining)
		Vfx.curls(self, Vector2.ZERO, wave, visual_age * 0.48,
			Color(0.75, 1.0, 0.87, opacity * remaining * 0.74))


func _apply_damage_pulse() -> void:
	if player_stats == null:
		return
	if not is_instance_valid(player_stats):
		return
	if not player_stats.has_method("calculate_damage"):
		return

	# Project immutable equipment once for this synchronous pulse. Conditions,
	# per-target critical rolls, set effects, kills and ledger still run per hit.
	EquipmentManager.begin_combat_batch()
	preload("res://scripts/data/equipment_set_runtime.gd").begin_combat_batch()
	for body in get_overlapping_bodies():
		if body == null:
			continue
		if not is_instance_valid(body):
			continue
		if not body.has_method("take_damage"):
			continue

		var final_damage: float = (
			player_stats.calculate_damage(
				base_damage
			)
		)
		preload("res://scripts/weapon/run_combat_ledger.gd").apply_hit(body,final_damage,"eight_trigrams_formation")
	preload("res://scripts/data/equipment_set_runtime.gd").end_combat_batch()
	EquipmentManager.end_combat_batch()
