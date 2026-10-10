extends Node2D
class_name FireOrbImpact

## Gate B: actual-hit-only Fire Orb bloom, still NOT a gameplay AoE.
## One CanvasItem draw; preserves the projectile's external visual scale.
## No temporary Polygon2D/Line2D children, timers, or Tween objects per impact.

const EFFECT_DURATION: float = 0.25
const RING_SEGMENTS: int = 30
const REDUCED_RING_SEGMENTS: int = 16

var _elapsed: float = 0.0
var _reduced: bool = false
var _petal_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_reduced = SettingsManager.reduced_effects
	_build_flame_shape()
	create_burst()


func create_burst() -> void:
	_elapsed = 0.0
	queue_redraw()


func _build_flame_shape() -> void:
	_petal_points.clear()
	for index in range(24):
		var angle: float = TAU * float(index) / 24.0
		var radius: float = 13.0 + 3.8 * sin(float(index) * 2.15)
		_petal_points.append(Vector2.RIGHT.rotated(angle) * radius)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= EFFECT_DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_elapsed / EFFECT_DURATION, 0.0, 1.0)
	var expansion: float = 1.0 - pow(1.0 - progress, 2.0)
	var fade: float = pow(1.0 - progress, 1.35)
	var segments: int = REDUCED_RING_SEGMENTS if _reduced else RING_SEGMENTS

	# Warm core + jagged fire silhouette, scaled independently of damage radius.
	draw_set_transform(
		Vector2.ZERO, 0.0, Vector2.ONE * (1.0 + expansion * 0.52)
	)
	draw_colored_polygon(
		_petal_points,
		Color(1.0, 0.35, 0.06, fade * 0.72)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(
		Vector2.ZERO, 7.0 + expansion * 6.0,
		Color(1.0, 0.88, 0.34, fade * 0.84)
	)
	if progress < 0.30:
		draw_circle(
			Vector2.ZERO, 3.8,
			Color(1.0, 0.99, 0.78, 1.0 - progress / 0.30)
		)

	# Confirmed single-hit burst, not a hostile/warning ground marker.
	draw_arc(
		Vector2.ZERO, lerpf(11.0, 31.0, expansion), 0.0, TAU, segments,
		Color(1.0, 0.74, 0.22, fade * 0.88), 3.0, true
	)
	if not _reduced:
		draw_arc(
			Vector2.ZERO, lerpf(17.0, 36.0, expansion), 0.0, TAU, segments,
			Color(1.0, 0.27, 0.04, fade * 0.45), 1.5, true
		)

	var streak_count: int = 4 if _reduced else 8
	for index in range(streak_count):
		var direction: Vector2 = Vector2.RIGHT.rotated(
			float(index) * TAU / float(streak_count) + 0.12
		)
		var start_distance: float = 8.0 + expansion * 9.0
		var end_distance: float = (
			(26.0 if index % 2 == 0 else 20.0) * (1.0 + expansion * 0.45)
		)
		draw_line(
			direction * start_distance, direction * end_distance,
			Color(1.0, 0.43, 0.08, fade * 0.80),
			2.5 if index % 2 == 0 else 1.6, true
		)
