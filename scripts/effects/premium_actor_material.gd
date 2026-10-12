extends RefCounted
const SHADER: Shader = preload("res://assets/shaders/premium_actor.gdshader")
static func create(sprite: AnimatedSprite2D, color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("accent", color)
	sprite.material = material
	return material
static func sync_frame(sprite: AnimatedSprite2D, material: ShaderMaterial) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation): return
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var uv := Vector4(0,0,1,1)
	if texture is AtlasTexture:
		var atlas: AtlasTexture = texture as AtlasTexture
		var atlas_size: Vector2 = atlas.atlas.get_size()
		uv = Vector4(atlas.region.position.x/atlas_size.x, atlas.region.position.y/atlas_size.y, atlas.region.end.x/atlas_size.x, atlas.region.end.y/atlas_size.y)
	material.set_shader_parameter("frame_uv", uv)
