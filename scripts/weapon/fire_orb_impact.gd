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
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_reduced = SettingsManager.reduced_effects
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
	var t: float = clampf(_elapsed / EFFECT_DURATION,0,1)
	var extent: float = lerpf(35,67,1.0-pow(1.0-t,2))
	if _reduced: extent *= .65
	preload("res://scripts/effects/combat_cel_art.gd").paint(self,"impacts",1,Vector2.ZERO,Vector2.ONE*extent,t*.20,pow(1.0-t,1.4))
