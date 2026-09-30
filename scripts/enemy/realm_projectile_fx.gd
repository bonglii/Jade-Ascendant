extends "res://scripts/enemy/enemy_projectile.gd"

## Chapter IV/V hostile talisman projectile. No changes to hit detection,
## trajectory, damage, lifetime, collision group or attack timing.
const FROST_TRAIL: Texture2D = preload("res://assets/vfx/realm/frost_projectile.png")
const SOLAR_TRAIL: Texture2D = preload("res://assets/vfx/realm/solar_projectile.png")
const FROST_HIT: Texture2D = preload("res://assets/vfx/realm/frost_hit.png")
const SOLAR_HIT: Texture2D = preload("res://assets/vfx/realm/solar_hit.png")

var realm_visual_theme: StringName = &"frostveil"
var _hit_visual_fired: bool = false


func _is_solar() -> bool:
	return realm_visual_theme == &"solar_nirvana"


func _ready() -> void:
	super._ready()
	if SettingsManager.reduced_effects:
		return
	# A tiny additive accent follows the ACTUAL projectile sprite/collider.
	# It adds no standalone hazard indicator or oversized false hitbox.
	var art := Sprite2D.new()
	art.texture = SOLAR_TRAIL if _is_solar() else FROST_TRAIL
	art.scale = Vector2.ONE * 0.125
	art.modulate.a = 0.42
	art.z_index = -1
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	art.material = additive
	add_child(art)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _hit_visual_fired:
		_hit_visual_fired = true
		if not SettingsManager.reduced_effects:
			_spawn_contact_spark()
	# The original projectile script owns damage and queue_free().
	super._on_body_entered(body)


func _spawn_contact_spark() -> void:
	var world: Node = get_tree().current_scene
	if world == null:
		return
	var glint := Sprite2D.new()
	glint.texture = SOLAR_HIT if _is_solar() else FROST_HIT
	glint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glint.scale = Vector2.ONE * 0.12
	glint.z_index = 7
	glint.modulate.a = 0.88
	world.add_child(glint)
	glint.global_position = global_position
	var fade := glint.create_tween()
	fade.set_parallel(true)
	fade.tween_property(glint, "modulate:a", 0.0, 0.16)
	fade.tween_property(glint, "scale", glint.scale * 1.25, 0.16)
	fade.finished.connect(func() -> void:
		if is_instance_valid(glint):
			glint.queue_free()
	)
