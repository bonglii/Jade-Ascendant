extends Node2D
class_name ThunderTalismanStrike

## Pure presentation scene for an actual Thunder Talisman hit.
## Source is aligned to Player/CombatOrigin when the talisman is player-cast.

const EFFECT_DURATION: float = 0.24
const LIGHTNING_SEGMENTS: int = 9
const IMPACT_SEGMENTS: int = 36

@onready var talisman_sprite: AnimatedSprite2D = $TalismanSprite


func setup(
	target_world_position: Vector2,
	show_talisman: bool = true
) -> void:
	if show_talisman:
		_align_to_player_combat_origin()

	var local_target: Vector2 = to_local(
		target_world_position
	)

	talisman_sprite.visible = show_talisman

	if show_talisman:
		talisman_sprite.play("activate")

	create_source_seal()
	create_lightning(local_target)
	create_impact(local_target)

	await get_tree().create_timer(
		EFFECT_DURATION,
		false
	).timeout

	if is_inside_tree():
		queue_free()


func _align_to_player_combat_origin() -> void:
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
	if combat_origin != null:
		global_position = combat_origin.global_position


func _make_line(
	points: PackedVector2Array,
	width: float,
	color: Color
) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.antialiased = true
	line.points = points
	add_child(line)
	return line


func create_source_seal() -> void:
	if SettingsManager.reduced_effects:
		return

	for radius in [12.0, 18.0]:
		var points := PackedVector2Array()
		for index in range(25):
			var angle: float = (
				TAU * float(index) / 24.0
			)
			points.append(
				Vector2.RIGHT.rotated(angle)
				* radius
			)

		var ring := _make_line(
			points,
			1.7 if radius < 15.0 else 1.2,
			Color(
				0.56,
				0.90,
				1.0,
				0.62 if radius < 15.0 else 0.38
			)
		)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(
			ring,
			"scale",
			Vector2.ONE * 1.45,
			EFFECT_DURATION
		)
		tween.tween_property(
			ring,
			"modulate:a",
			0.0,
			EFFECT_DURATION
		)


func create_lightning(local_target: Vector2) -> void:
	var delta: Vector2 = local_target
	var length: float = delta.length()

	if length <= 0.001:
		return

	var direction: Vector2 = delta / length
	var perpendicular := Vector2(
		-direction.y,
		direction.x
	)

	var points := PackedVector2Array()
	points.append(Vector2.ZERO)

	for index in range(1, LIGHTNING_SEGMENTS):
		var ratio: float = (
			float(index)
			/ float(LIGHTNING_SEGMENTS)
		)
		var base_point: Vector2 = delta * ratio
		var alternating_sign: float = (
			-1.0 if index % 2 == 0 else 1.0
		)
		var amplitude: float = minf(
			13.0,
			5.0 + length * 0.028
		)

		points.append(
			base_point
			+ perpendicular
			* amplitude
			* alternating_sign
			* sin(PI * ratio)
		)

	points.append(delta)

	var outer := _make_line(
		points,
		13.0,
		Color(0.18, 0.52, 1.0, 0.13)
	)
	var glow := _make_line(
		points,
		7.0,
		Color(0.30, 0.68, 1.0, 0.30)
	)
	var core := _make_line(
		points,
		2.8,
		Color(0.78, 0.96, 1.0, 1.0)
	)

	var tween := create_tween()
	tween.set_parallel(true)

	for line in [outer, glow, core]:
		tween.tween_property(
			line,
			"modulate:a",
			0.0,
			EFFECT_DURATION
		)


func create_impact(local_target: Vector2) -> void:
	var ring_points := PackedVector2Array()
	var start_radius: float = 8.0

	for index in range(IMPACT_SEGMENTS + 1):
		var angle: float = (
			TAU
			* float(index)
			/ float(IMPACT_SEGMENTS)
		)
		ring_points.append(
			Vector2.RIGHT.rotated(angle)
			* start_radius
		)

	var ring := _make_line(
		ring_points,
		4.5,
		Color(0.62, 0.88, 1.0, 0.94)
	)
	ring.position = local_target

	var outer: Line2D = null
	if not SettingsManager.reduced_effects:
		outer = _make_line(
			ring_points,
			8.0,
			Color(0.24, 0.60, 1.0, 0.18)
		)
		outer.position = local_target

		for index in range(8):
			var direction := Vector2.RIGHT.rotated(
				float(index) * TAU / 8.0
			)
			var ray := _make_line(
				PackedVector2Array([
					local_target + direction * 7.0,
					local_target + direction * (
						24.0
						if index % 2 == 0
						else 18.0
					)
				]),
				1.7,
				Color(0.72, 0.94, 1.0, 0.76)
			)

			var ray_tween := create_tween()
			ray_tween.tween_property(
				ray,
				"modulate:a",
				0.0,
				EFFECT_DURATION
			)

	var tween := create_tween()
	tween.set_parallel(true)

	for impact_ring in [ring, outer]:
		if impact_ring == null:
			continue

		tween.tween_property(
			impact_ring,
			"scale",
			Vector2.ONE * 2.6,
			EFFECT_DURATION
		)
		tween.tween_property(
			impact_ring,
			"modulate:a",
			0.0,
			EFFECT_DURATION
		)
