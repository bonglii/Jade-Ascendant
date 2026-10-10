extends Node2D
class_name SpiritSwordImpact

## Gate B: actual-hit-only Spirit Sword feedback.
## One CanvasItem draw, no per-hit Line2D children or Tween allocation.
## The projectile remains the authority for hit, critical and resonance state.

const EFFECT_DURATION: float = 0.23
const RING_SEGMENTS: int = 28
const REDUCED_RING_SEGMENTS: int = 16

var critical: bool = false
var resonance_projectile: bool = false
var combat_style_id: StringName = &"spirit_sword"
var combat_profile: Dictionary = {}

var _elapsed: float = 0.0
var _reduced: bool = false
var _impact_scale: float = 1.0
var _main: Color = Color(0.36, 0.96, 0.84, 0.94)
var _core: Color = Color(0.84, 1.0, 0.96, 1.0)
var _accent: Color = Color(0.30, 0.78, 1.0, 0.74)


func setup(
	is_critical: bool,
	is_resonance: bool,
	profile: Dictionary = {}
) -> void:
	critical = is_critical
	resonance_projectile = is_resonance
	# Retain the original profile for compatibility, but never mutate it.
	combat_profile = profile
	combat_style_id = StringName(str(combat_profile.get("style_id", "spirit_sword")))
	_main = combat_profile.get("impact_main", Color(0.36, 0.96, 0.84, 0.94))
	_core = combat_profile.get("impact_core", Color(0.84, 1.0, 0.96, 1.0))
	_accent = combat_profile.get("impact_accent", Color(0.30, 0.78, 1.0, 0.74))
	_impact_scale = maxf(float(combat_profile.get("impact_scale", 1.0)), 0.1)
	_reduced = SettingsManager.reduced_effects

	# A confirmed critical always wins over armament color; resonance comes next.
	if critical:
		_main = Color(1.0, 0.78, 0.22, 1.0)
		_core = Color(1.0, 0.98, 0.76, 1.0)
		_accent = Color(0.46, 1.0, 0.84, 0.82)
		_impact_scale = 1.35
	elif resonance_projectile:
		_main = Color(0.36, 0.84, 1.0, 0.98)
		_core = Color(0.86, 0.98, 1.0, 1.0)
		_accent = Color(0.52, 0.96, 0.90, 0.80)
		_impact_scale = 1.16

	create_impact()


func create_impact() -> void:
	_elapsed = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= EFFECT_DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_elapsed / EFFECT_DURATION, 0.0, 1.0)
	var expansion: float = 1.0 - pow(1.0 - progress, 2.0)
	var fade: float = pow(1.0 - progress, 1.45)
	var ring_radius: float = lerpf(10.0, 26.0, expansion) * _impact_scale
	var segments: int = REDUCED_RING_SEGMENTS if _reduced else RING_SEGMENTS

	# Slash occupies a narrow diagonal footprint so it never mimics a boss AoE.
	_draw_slash(
		Vector2(-18.0, 12.0), Vector2(19.0, -13.0),
		4.8 if critical else 3.6, fade
	)
	_draw_slash(
		Vector2(-12.0, -17.0), Vector2(13.0, 17.0),
		2.8 if critical else 2.2, fade * 0.76
	)

	# The ring confirms the exact projectile hit location, not a gameplay radius.
	draw_arc(
		Vector2.ZERO, ring_radius, 0.0, TAU, segments,
		Color(_main.r, _main.g, _main.b, fade * 0.85),
		2.4 if critical else 1.9, true
	)
	if not _reduced:
		draw_arc(
			Vector2.ZERO, ring_radius * 1.24, 0.0, TAU, segments,
			Color(_accent.r, _accent.g, _accent.b, fade * 0.28),
			1.2, true
		)

	if progress < 0.36:
		var flash: float = 1.0 - progress / 0.36
		draw_circle(
			Vector2.ZERO, (5.0 + expansion * 4.0) * _impact_scale,
			Color(_core.r, _core.g, _core.b, flash * 0.55)
		)

	var ray_count: int = 4 if _reduced else 8
	for index in range(ray_count):
		var direction: Vector2 = Vector2.RIGHT.rotated(
			float(index) * TAU / float(ray_count) + 0.20
		)
		var ray_start: float = (8.0 + expansion * 7.0) * _impact_scale
		var ray_end: float = (19.0 + expansion * 17.0) * _impact_scale
		draw_line(
			direction * ray_start, direction * ray_end,
			Color(_accent.r, _accent.g, _accent.b, fade * 0.72),
			1.5 if index % 2 == 0 else 1.0, true
		)

	# Non-color silhouette: resonance receives twin orbital ticks.
	if resonance_projectile and not critical:
		for side in [-1.0, 1.0]:
			draw_arc(
				Vector2(side * 8.0, 0.0), 15.0 * _impact_scale,
				-0.86 if side < 0.0 else 2.28,
				0.86 if side < 0.0 else 4.0,
				12, Color(_core.r, _core.g, _core.b, fade * 0.72), 1.5, true
			)


func _draw_slash(start: Vector2, finish: Vector2, width: float, fade: float) -> void:
	var outward: float = 1.0 + (1.0 - pow(1.0 - _elapsed / EFFECT_DURATION, 2.0)) * 0.30
	var start_point: Vector2 = start * outward * _impact_scale
	var end_point: Vector2 = finish * outward * _impact_scale
	if not _reduced:
		draw_line(
			start_point, end_point,
			Color(_main.r, _main.g, _main.b, fade * 0.20), width * 2.5, true
		)
	draw_line(
		start_point, end_point,
		Color(_core.r, _core.g, _core.b, fade), width, true
	)
