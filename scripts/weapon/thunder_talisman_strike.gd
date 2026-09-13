extends Node2D
class_name ThunderTalismanStrike

## Pure presentation scene for Thunder Talisman.
## No collision and no damage logic live here.
## It only visualizes an actual hit performed by ThunderTalismanWeapon.

const EFFECT_DURATION: float = 0.16
const LIGHTNING_SEGMENTS: int = 7
const IMPACT_SEGMENTS: int = 32

@onready var talisman_sprite: AnimatedSprite2D = $TalismanSprite

func setup(
	target_world_position: Vector2,
	show_talisman: bool = true
) -> void:
	var local_target: Vector2 = (
		to_local(target_world_position)
	)

	talisman_sprite.visible = show_talisman

	if show_talisman:
		talisman_sprite.play("activate")

	create_lightning(local_target)
	create_impact(local_target)

	await get_tree().create_timer(
		EFFECT_DURATION,
		false
	).timeout

	if is_inside_tree():
		queue_free()

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

		var base_point: Vector2 = (
			delta * ratio
		)

		var alternating_sign: float = (
			-1.0
			if index % 2 == 0
			else 1.0
		)

		var amplitude: float = minf(
			10.0,
			4.0 + length * 0.025
		)

		points.append(
			base_point
			+ perpendicular
			* amplitude
			* alternating_sign
			* sin(PI * ratio)
		)

	points.append(delta)

	var glow := Line2D.new()
	glow.width = 7.0
	glow.default_color = Color(
		0.30,
		0.68,
		1.0,
		0.24
	)
	glow.antialiased = true
	glow.points = points
	add_child(glow)

	var core := Line2D.new()
	core.width = 2.5
	core.default_color = Color(
		0.72,
		0.94,
		1.0,
		0.96
	)
	core.antialiased = true
	core.points = points
	add_child(core)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		glow,
		"modulate:a",
		0.0,
		EFFECT_DURATION
	)

	tween.tween_property(
		core,
		"modulate:a",
		0.0,
		EFFECT_DURATION
	)

func create_impact(local_target: Vector2) -> void:
	var ring := Line2D.new()
	ring.width = 3.5
	ring.default_color = Color(
		0.62,
		0.88,
		1.0,
		0.88
	)
	ring.antialiased = true

	var points := PackedVector2Array()
	var start_radius: float = 7.0

	for index in range(IMPACT_SEGMENTS + 1):
		var angle: float = (
			TAU
			* float(index)
			/ float(IMPACT_SEGMENTS)
		)

		points.append(
			Vector2.RIGHT.rotated(angle)
			* start_radius
		)

	ring.points = points
	ring.position = local_target
	add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector2.ONE * 2.0,
		EFFECT_DURATION
	)

	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		EFFECT_DURATION
	)
