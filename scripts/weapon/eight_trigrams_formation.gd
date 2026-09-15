class_name EightTrigramsFormation
extends Area2D

## Persistent ground-control instance for Eight Trigrams Formation.
## Visual radius is explicitly synchronized to gameplay radius.

const FORMATION_SEGMENTS: int = 56
const TRIGRAM_MARKER_COUNT: int = 8
const PULSE_VISUAL_DURATION: float = 0.24

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
	queue_redraw()


func rebuild_formation_visual() -> void:
	_sync_sigil_to_gameplay_radius()
	queue_redraw()


func update_formation_visual() -> void:
	if formation_sigil != null:
		formation_sigil.rotation = (
			visual_age
			* (0.025 if SettingsManager.reduced_effects else 0.055)
		)
	queue_redraw()


func create_damage_pulse_visual() -> void:
	pulse_visual_left = PULSE_VISUAL_DURATION

	# Pooled tick confirmation stays intentionally small because the persistent
	# formation itself already communicates the true damage area.
	CombatFeedback.pulse(
		global_position,
		"formation"
	)
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf(
		minf(
			visual_age / 0.30,
			lifetime_remaining / 0.40
		),
		0.0,
		1.0
	)
	var opacity: float = (
		fade
		* (
			0.38
			if SettingsManager.reduced_effects
			else 0.62
		)
	)

	var jade := Color(0.38, 0.96, 0.72, opacity)
	var pale := Color(0.78, 1.0, 0.90, opacity * 0.78)
	var gold := Color(0.96, 0.76, 0.30, opacity * 0.88)

	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		FORMATION_SEGMENTS,
		jade,
		2.5,
		true
	)
	draw_arc(
		Vector2.ZERO,
		radius * 0.78,
		0.0,
		TAU,
		48,
		gold,
		1.5,
		true
	)
	draw_arc(
		Vector2.ZERO,
		radius * 0.50,
		0.0,
		TAU,
		40,
		pale,
		1.2,
		true
	)

	for index in range(TRIGRAM_MARKER_COUNT):
		var angle: float = (
			float(index) * TAU / 8.0
			+ visual_age * 0.055
		)
		var radial: Vector2 = Vector2.from_angle(angle)
		var tangent: Vector2 = radial.orthogonal()

		# Connector stays entirely inside the real gameplay radius.
		draw_line(
			radial * radius * 0.53,
			radial * radius * 0.70,
			Color(
				jade.r,
				jade.g,
				jade.b,
				opacity * 0.44
			),
			1.0,
			true
		)

		for stroke in range(3):
			var center: Vector2 = (
				radial
				* (
					radius * 0.84
					+ float(stroke - 1) * 4.0
				)
			)

			if (index & (1 << stroke)) != 0:
				draw_line(
					center - tangent * 8.0,
					center + tangent * 8.0,
					gold,
					1.8,
					true
				)
			else:
				draw_line(
					center - tangent * 8.0,
					center - tangent * 2.3,
					gold,
					1.8,
					true
				)
				draw_line(
					center + tangent * 2.3,
					center + tangent * 8.0,
					gold,
					1.8,
					true
				)

	var seal_radius: float = minf(
		radius * 0.21,
		24.0
	)
	draw_arc(
		Vector2.ZERO,
		seal_radius,
		0.0,
		TAU,
		32,
		jade,
		2.0,
		true
	)
	draw_arc(
		Vector2(0.0, -seal_radius * 0.5),
		seal_radius * 0.5,
		-PI / 2.0,
		PI / 2.0,
		14,
		gold,
		1.5,
		true
	)
	draw_arc(
		Vector2(0.0, seal_radius * 0.5),
		seal_radius * 0.5,
		PI / 2.0,
		PI * 1.5,
		14,
		jade,
		1.5,
		true
	)
	draw_circle(
		Vector2(0.0, -seal_radius * 0.5),
		2.4,
		jade
	)
	draw_circle(
		Vector2(0.0, seal_radius * 0.5),
		2.4,
		gold
	)

	if pulse_visual_left > 0.0:
		var progress: float = (
			1.0
			- pulse_visual_left
			/ PULSE_VISUAL_DURATION
		)
		var pulse_alpha: float = (
			opacity
			* (1.0 - progress)
		)

		draw_arc(
			Vector2.ZERO,
			radius * lerpf(
				0.28,
				1.0,
				progress
			),
			0.0,
			TAU,
			FORMATION_SEGMENTS,
			Color(
				pale.r,
				pale.g,
				pale.b,
				pulse_alpha
			),
			2.8,
			true
		)

		if not SettingsManager.reduced_effects:
			for index in range(8):
				var direction := Vector2.RIGHT.rotated(
					float(index) * TAU / 8.0
				)
				draw_line(
					direction * radius * 0.25,
					direction * radius * lerpf(
						0.42,
						0.78,
						progress
					),
					Color(
						gold.r,
						gold.g,
						gold.b,
						pulse_alpha * 0.72
					),
					1.5,
					true
				)


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
			player_stats.calculate_damage(
				base_damage
			)
		)
		body.take_damage(final_damage)
