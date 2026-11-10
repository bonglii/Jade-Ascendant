extends Node2D
class_name FireOrbImpact

## Gate B: actual-hit-only Fire Orb bloom, still NOT a gameplay AoE.
## One CanvasItem draw; preserves the projectile's external visual scale.
## No temporary Polygon2D/Line2D children, timers, or Tween objects per impact.

const Vfx = preload("res://scripts/effects/weapon_vfx_art.gd")
const EFFECT_DURATION: float = 0.25

var _elapsed: float = 0.0
var bloom_radius: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	create_burst()


func create_burst() -> void:
	_elapsed = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= EFFECT_DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_elapsed / EFFECT_DURATION,0,1)
	var extent: float = lerpf(35,67,1.0-pow(1.0-t,2))
	var low: bool = Vfx.low_detail(self)
	if low:
		extent *= 0.65
	var fade: float = pow(1.0 - t, 1.4)
	preload("res://scripts/effects/combat_cel_art.gd").paint(self, "impacts", 1,
		Vector2.ZERO, Vector2.ONE * extent, t * 0.20, fade)
	if bloom_radius > 0.0:
		# This is the actual Cinder Bloom radius in world space.
		var local_radius: float = bloom_radius / maxf(absf(scale.x), 0.01)
		draw_arc(Vector2.ZERO, local_radius, 0.0, TAU, 32,
			Color(1.0, 0.55, 0.22, fade * 0.64), 1.6, true)
		if not low:
			Vfx.curls(self, Vector2.ZERO, local_radius, -t * 0.62, Color(1.0, 0.45, 0.14, fade * 0.70))
