extends "res://scripts/enemy/qi_explosion.gd"

## Realm IV/V-only Qi Caster presentation. The base _ready, impact, player
## damage, exact CircleShape2D radius and timer continue unchanged.
const FROST_SEAL: Texture2D = preload("res://assets/vfx/realm/frost_sigil.png")
const SOLAR_SEAL: Texture2D = preload("res://assets/vfx/realm/solar_sigil.png")
const FROST_IMPACT: Texture2D = preload("res://assets/vfx/realm/frost_impact.png")
const SOLAR_IMPACT: Texture2D = preload("res://assets/vfx/realm/solar_impact.png")

var _realm_caster_seal: Sprite2D = null


func _solar() -> bool:
	return presentation_theme == &"solar_nirvana"


func _create_stamp(texture_value: Texture2D, diameter: float, strength: float) -> Sprite2D:
	var stamp := Sprite2D.new()
	stamp.texture = texture_value
	stamp.scale = Vector2.ONE * diameter / texture_value.get_size()
	stamp.modulate = Color(1.0, 1.0, 1.0, strength)
	stamp.z_index = 5
	stamp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	stamp.material = additive
	add_child(stamp)
	return stamp


func create_telegraph_visual() -> void:
	# Base Line2D is the ONLY marked damage-radius boundary.
	super.create_telegraph_visual()
	var accent: Color = Color(1.0, 0.76, 0.36, 0.87) if _solar() else Color(0.53, 0.87, 1.0, 0.87)
	if is_instance_valid(telegraph_outline):
		telegraph_outline.default_color = accent
	if telegraph_visual != null:
		telegraph_visual.color = Color(accent.r, accent.g, accent.b, 0.10)
	if SettingsManager.reduced_effects:
		return
	_realm_caster_seal = _create_stamp(
		SOLAR_SEAL if _solar() else FROST_SEAL,
		explosion_radius * 1.65, 0.43
	)
	var pulse: Tween = create_tween()
	pulse.set_loops()
	pulse.tween_property(_realm_caster_seal, "modulate:a", 0.27, telegraph_duration * 0.5)
	pulse.tween_property(_realm_caster_seal, "modulate:a", 0.51, telegraph_duration * 0.5)


func create_impact_visual() -> void:
	if is_instance_valid(_realm_caster_seal):
		_realm_caster_seal.hide()
	# Existing flash/ring/timing remains visible and owns the real combat hit.
	super.create_impact_visual()
	var stamp: Sprite2D = _create_stamp(
		SOLAR_IMPACT if _solar() else FROST_IMPACT,
		explosion_radius * 1.90,
		0.48 if SettingsManager.reduced_effects else 0.92
	)
	var fade: Tween = create_tween()
	fade.set_parallel(true)
	fade.tween_property(stamp, "modulate:a", 0.0, IMPACT_VISUAL_DURATION)
	fade.tween_property(stamp, "scale", stamp.scale * 1.10, IMPACT_VISUAL_DURATION)
