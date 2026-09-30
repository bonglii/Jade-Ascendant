extends "res://scripts/enemy/enemy_6.gd"

## Chapter IV/V Qi Guardian pulse art. Production aura protection, wind-up,
## collision, radius and damage stay entirely in enemy_6.gd.
const FROST_SEAL: Texture2D = preload("res://assets/vfx/realm/frost_sigil.png")
const SOLAR_SEAL: Texture2D = preload("res://assets/vfx/realm/solar_sigil.png")
const FROST_IMPACT: Texture2D = preload("res://assets/vfx/realm/frost_impact.png")
const SOLAR_IMPACT: Texture2D = preload("res://assets/vfx/realm/solar_impact.png")

var _pulse_seal: Sprite2D = null


func _realm_solar() -> bool:
	return presentation_theme == &"solar_nirvana"


func _pulse_stamp(image_value: Texture2D, world_diameter: float, opacity: float) -> Sprite2D:
	var stamp := Sprite2D.new()
	stamp.texture = image_value
	stamp.scale = Vector2.ONE * world_diameter / image_value.get_size()
	stamp.modulate = Color(1.0, 1.0, 1.0, opacity)
	stamp.z_index = 5
	stamp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	stamp.material = additive
	add_child(stamp)
	return stamp


func create_qi_pulse_telegraph_visual() -> void:
	# Base ring still marks the full gameplay radius throughout wind-up.
	super.create_qi_pulse_telegraph_visual()
	if SettingsManager.reduced_effects:
		return
	_pulse_seal = _pulse_stamp(
		SOLAR_SEAL if _realm_solar() else FROST_SEAL,
		qi_pulse_radius * 1.70, 0.34
	)
	var breath := create_tween()
	breath.tween_property(_pulse_seal, "modulate:a", 0.58, qi_pulse_wind_up)


func remove_qi_pulse_telegraph_visual() -> void:
	super.remove_qi_pulse_telegraph_visual()
	if is_instance_valid(_pulse_seal):
		_pulse_seal.queue_free()
	_pulse_seal = null


func create_qi_pulse_impact_visual() -> void:
	super.create_qi_pulse_impact_visual()
	if SettingsManager.reduced_effects:
		return
	var splash: Sprite2D = _pulse_stamp(
		SOLAR_IMPACT if _realm_solar() else FROST_IMPACT,
		qi_pulse_radius * 1.94, 0.75
	)
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(splash, "modulate:a", 0.0, PULSE_VISUAL_DURATION)
	fade.tween_property(splash, "scale", splash.scale * 1.09, PULSE_VISUAL_DURATION)
	fade.finished.connect(func() -> void:
		if is_instance_valid(splash):
			splash.queue_free()
	)
