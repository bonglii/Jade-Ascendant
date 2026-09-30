extends "res://scripts/enemy/lightning_strike.gd"

## Realm IV/V-only visual replacement for the elite caster's original
## six-point polyline lightning. Damage radius, timer and one-hit rules are
## inherited byte-for-byte from LightningStrike.
const FROST_SEAL: Texture2D = preload("res://assets/vfx/realm/frost_sigil.png")
const SOLAR_SEAL: Texture2D = preload("res://assets/vfx/realm/solar_sigil.png")
const FROST_BOLT: Texture2D = preload("res://assets/vfx/realm/frost_bolt.png")
const SOLAR_BOLT: Texture2D = preload("res://assets/vfx/realm/solar_bolt.png")
const FROST_BRANCH: Texture2D = preload("res://assets/vfx/realm/frost_branch.png")
const SOLAR_BRANCH: Texture2D = preload("res://assets/vfx/realm/solar_branch.png")
const FROST_IMPACT: Texture2D = preload("res://assets/vfx/realm/frost_impact.png")
const SOLAR_IMPACT: Texture2D = preload("res://assets/vfx/realm/solar_impact.png")

var _realm_seal: Sprite2D = null


func _realm_is_solar() -> bool:
	return presentation_theme == &"solar_nirvana"


func _realm_accent() -> Color:
	return Color(1.0, 0.79, 0.39, 0.96) if _realm_is_solar() else Color(0.60, 0.90, 1.0, 0.96)


func _realm_texture(frost_texture: Texture2D, solar_texture: Texture2D) -> Texture2D:
	return solar_texture if _realm_is_solar() else frost_texture


func _add_fx_sprite(art: Texture2D, center: Vector2, size_value: Vector2,
	alpha_value: float) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = art
	sprite.position = center
	sprite.scale = size_value / art.get_size()
	sprite.modulate = Color(1.0, 1.0, 1.0, alpha_value)
	sprite.z_index = 7
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.set_meta(&"realm_visual_only", true)
	var material_instance: CanvasItemMaterial = CanvasItemMaterial.new()
	material_instance.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = material_instance
	add_child(sprite)
	return sprite


func create_telegraph_visual() -> void:
	# Preserve the exact Polygon2D/Line2D used by the original hit radius.
	super.create_telegraph_visual()
	var warning_color: Color = _realm_accent()
	if telegraph_visual != null:
		telegraph_visual.color = Color(warning_color.r, warning_color.g, warning_color.b, 0.105)
	if is_instance_valid(telegraph_outline):
		telegraph_outline.default_color = warning_color
		telegraph_outline.width = 2.7
	# Charge seal remains INSIDE the actual radius; it is decorative, not a
	# second hitbox. Reduced Effects leaves only the semantic warning border.
	if SettingsManager.reduced_effects:
		return
	var diameter: float = strike_radius * 1.66
	_realm_seal = _add_fx_sprite(
		_realm_texture(FROST_SEAL, SOLAR_SEAL),
		Vector2.ZERO, Vector2.ONE * diameter, 0.46
	)
	_realm_seal.z_index = 3
	var breath: Tween = create_tween()
	breath.set_loops()
	breath.tween_property(_realm_seal, "modulate:a", 0.27, telegraph_duration * 0.5)
	breath.tween_property(_realm_seal, "modulate:a", 0.54, telegraph_duration * 0.5)


func create_impact_visual() -> void:
	# Base impact() still calls apply_damage_to_player() exactly once. Only
	# the flat six-point Line2D and circle flash are replaced here.
	if is_instance_valid(_realm_seal):
		_realm_seal.hide()
	var impact_scale: float = strike_radius / 55.0
	var bolt: Sprite2D = _add_fx_sprite(
		_realm_texture(FROST_BOLT, SOLAR_BOLT),
		Vector2(0.0, -82.0 * impact_scale),
		Vector2.ONE * (512.0 * 0.50 * impact_scale), 0.96
	)
	var impact_sprite: Sprite2D = _add_fx_sprite(
		_realm_texture(FROST_IMPACT, SOLAR_IMPACT),
		Vector2.ZERO, Vector2.ONE * (strike_radius * 2.04),
		0.75 if SettingsManager.reduced_effects else 0.97
	)
	# Approved forked lightning sits above the exact ground-impact circle;
	# it creates NO new strike radius or collision geometry.
	if not SettingsManager.reduced_effects:
		var branch: Sprite2D = _add_fx_sprite(
			_realm_texture(FROST_BRANCH, SOLAR_BRANCH),
			Vector2(0.0, -73.0 * impact_scale),
			Vector2(174.0, 88.0) * impact_scale, 0.82
		)
		var branch_fade: Tween = create_tween()
		branch_fade.tween_property(branch, "modulate:a", 0.0, 0.14)
	# A second short bolt core is omitted when Reduced Effects is enabled.
	if not SettingsManager.reduced_effects:
		var core: Sprite2D = _add_fx_sprite(
			_realm_texture(FROST_BOLT, SOLAR_BOLT),
			Vector2(0.0, -82.0 * impact_scale),
			Vector2.ONE * (512.0 * 0.35 * impact_scale), 0.85
		)
		var fade_core: Tween = create_tween()
		fade_core.tween_property(core, "modulate:a", 0.0, 0.13)
	var fade: Tween = create_tween()
	fade.set_parallel(true)
	fade.tween_property(bolt, "modulate:a", 0.0, 0.14)
	fade.tween_property(impact_sprite, "modulate:a", 0.0, 0.14)
	fade.tween_property(impact_sprite, "scale", impact_sprite.scale * 1.14, 0.14)
