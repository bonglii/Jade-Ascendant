extends RefCounted
## Hand-painted component frames, clipped sampling and continuous transforms.
const ROOT: String = "res://assets/effects/combat_cels/"
const CELL: int = 256
static var cache: Dictionary = {}
static var palettes: Dictionary = {}
static func palette(color: Color) -> ShaderMaterial:
	var key: String = color.to_html()
	if palettes.has(key): return palettes[key]
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/hostile_cel_palette.gdshader")
	material.set_shader_parameter("accent",color)
	palettes[key] = material
	return material
static func frame(kit: String, index: int) -> Texture2D:
	var key: String = kit + str(index)
	if cache.has(key): return cache[key]
	var columns: int = 4 if kit == "impacts" else 2
	var atlas: Texture2D = load(ROOT + kit + ".png")
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2((index % columns) * CELL, floori(float(index) / columns) * CELL, CELL, CELL)
	texture.filter_clip = true
	cache[key] = texture
	return texture
static func paint(c: CanvasItem, kit: String, index: int, at: Vector2, size: Vector2, angle: float = 0.0, alpha: float = 1.0) -> void:
	c.draw_set_transform(at, angle, Vector2.ONE)
	c.draw_texture_rect(frame(kit,index),Rect2(-size*0.5,size),false,Color(1,1,1,clampf(alpha,0,1)))
	c.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
static func hit_index(source: String) -> int:
	match source:
		"fire_orb", "phoenix_war_fan": return 1
		"thunder_talisman", "heavenly_tribulation": return 2
		"yin_yang_blades": return 3
		"heavenly_sword_rain": return 4
		"eight_trigrams_formation": return 5
		"jade_binding_chain": return 6
		"void_piercer_spear": return 7
	return 0
