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
	material = preload("res://scripts/effects/combat_cel_art.gd").palette(_main)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


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
	var t: float = clampf(_elapsed / EFFECT_DURATION,0,1)
	var extent: float = lerpf(38,65,1.0-pow(1.0-t,2)) * _impact_scale
	if _reduced: extent *= .65
	var art = preload("res://scripts/effects/combat_cel_art.gd")
	art.paint(self,"impacts",0,Vector2.ZERO,Vector2.ONE*extent,0,pow(1.0-t,1.4))
	if critical and not _reduced:
		art.paint(self,"impacts",0,Vector2.ZERO,Vector2.ONE*extent*.70,PI*.50,pow(1.0-t,1.8)*.80)
