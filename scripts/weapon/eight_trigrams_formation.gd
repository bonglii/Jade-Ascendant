class_name EightTrigramsFormation
extends Area2D

## Persistent ground-control instance for Eight Trigrams Formation.
## Applies independent damage events to valid enemies on every pulse
## and removes itself automatically when its lifetime expires.
##
## Semantic VFX:
## - Area persists for the full gameplay duration, therefore a persistent
##   formation visual is VALID and meaningful.
## - Visual uses thin jade rings / trigram markers, not a filled danger circle.
## - Every actual damage pulse receives a short active pulse ring.

const FORMATION_SEGMENTS: int = 48
const TRIGRAM_MARKER_COUNT: int = 8
const PULSE_VISUAL_DURATION: float = 0.20

var base_damage: float = 8.0
var radius: float = 80.0
var duration: float = 4.0
var pulse_interval: float = 0.75

var lifetime_remaining: float = 0.0
var pulse_remaining: float = 0.0

var player_stats: Node = null

var visual_age: float = 0.0
var pulse_visual_left: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	z_index = -1
	lifetime_remaining = duration
	pulse_remaining = pulse_interval

	_set_radius(radius)
	create_formation_visual()

func _physics_process(delta: float) -> void:
	visual_age += delta
	pulse_visual_left = maxf(pulse_visual_left - delta, 0.0)
	lifetime_remaining -= delta
	pulse_remaining -= delta

	if lifetime_remaining <= 0.0:
		queue_free()
		return

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
	pulse_interval = maxf(new_pulse_interval, 0.01)
	player_stats = new_player_stats

	lifetime_remaining = duration
	pulse_remaining = pulse_interval

	if is_node_ready():
		_set_radius(radius)
		rebuild_formation_visual()

func _set_radius(new_radius: float) -> void:
	if collision_shape == null:
		return

	var circle_shape := collision_shape.shape as CircleShape2D

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

func create_formation_visual() -> void:
	queue_redraw()

func rebuild_formation_visual() -> void:
	queue_redraw()

func update_formation_visual() -> void:
	queue_redraw()

func create_damage_pulse_visual() -> void:
	pulse_visual_left = PULSE_VISUAL_DURATION
	## Actual damage tick receives a short higher-priority confirmation.
	CombatFeedback.pulse(global_position, "formation")
	queue_redraw()

func _draw() -> void:
	var fade: float = clampf(minf(visual_age / 0.3, lifetime_remaining / 0.4), 0.0, 1.0)
	var opacity: float = fade * (0.32 if SettingsManager.reduced_effects else 0.50)
	var jade: Color = Color(0.48, 0.88, 0.73, opacity)
	var gold: Color = Color(0.90, 0.76, 0.42, opacity * 0.76)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, jade, 1.6, true)
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 40, gold, 1.0, true)
	# Every trigram has three lines; its bit pattern controls solid/broken strokes.
	for index in range(8):
		var angle: float = float(index) * TAU / 8.0 + visual_age * 0.055
		var radial: Vector2 = Vector2.from_angle(angle)
		var tangent: Vector2 = radial.orthogonal()
		for stroke in range(3):
			var center: Vector2 = radial * (radius * 0.8 + float(stroke - 1) * 4.0)
			if (index & (1 << stroke)) != 0:
				draw_line(center - tangent * 7.0, center + tangent * 7.0, gold, 1.5, true)
			else:
				draw_line(center - tangent * 7.0, center - tangent * 2.0, gold, 1.5, true)
				draw_line(center + tangent * 2.0, center + tangent * 7.0, gold, 1.5, true)
	var seal_radius: float = minf(radius * 0.18, 22.0)
	draw_arc(Vector2.ZERO, seal_radius, 0.0, TAU, 28, jade, 1.5, true)
	draw_arc(Vector2(0.0, -seal_radius * 0.5), seal_radius * 0.5, -PI / 2.0, PI / 2.0, 12, gold, 1.2, true)
	draw_arc(Vector2(0.0, seal_radius * 0.5), seal_radius * 0.5, PI / 2.0, PI * 1.5, 12, jade, 1.2, true)
	draw_circle(Vector2(0.0, -seal_radius * 0.5), 2.0, jade)
	draw_circle(Vector2(0.0, seal_radius * 0.5), 2.0, gold)
	if pulse_visual_left > 0.0:
		var progress: float = 1.0 - pulse_visual_left / PULSE_VISUAL_DURATION
		draw_arc(Vector2.ZERO, radius * lerpf(0.35, 1.0, progress), 0.0, TAU, 48, Color(jade, opacity * 0.78 * (1.0 - progress)), 1.6, true)

func _apply_damage_pulse() -> void:
	if player_stats == null:
		return

	if not is_instance_valid(player_stats):
		return

	if not player_stats.has_method("calculate_damage"):
		return

	for body in get_overlapping_bodies():
		if body == null:
			continue

		if not is_instance_valid(body):
			continue

		if not body.has_method("take_damage"):
			continue

		var final_damage: float = (
			player_stats.calculate_damage(base_damage)
		)

		body.take_damage(final_damage)
