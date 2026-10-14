extends RefCounted
## One shared 1024x1280 atlas for the active realm; no per-frame texture generation.
const Profiles=preload("res://scripts/data/boss_premium_catalog.gd")
static func has_art(display_name: String) -> bool:
 var profile: Dictionary=Profiles.get_profile(display_name)
 return not profile.is_empty() and ResourceLoader.exists("res://assets/enemy/refined/realm_%d_atlas.png" % int(profile.get("chapter",0)))
static func install(boss: Node) -> bool:
 var profile: Dictionary=Profiles.get_profile(str(boss.encounter_display_name))
 if profile.is_empty():return false
 boss.set_meta("boss_pressure_role",(int(profile.stage)-1)%5)
 var path: String="res://assets/enemy/refined/realm_%d_atlas.png" % int(profile.chapter)
 if not ResourceLoader.exists(path):return false
 var atlas: Texture2D=load(path)
 if atlas==null:return false
 var row: int=clampi(int(profile.stage)-1,0,4)
 var frames:=SpriteFrames.new()
 frames.remove_animation(&"default")
 var tiles: Array[AtlasTexture]=[]
 var width: float=atlas.get_width()/4.0
 var height: float=atlas.get_height()/5.0
 for column: int in range(4):
  var tile:=AtlasTexture.new();tile.atlas=atlas
  tile.region=Rect2(column*width,row*height,width,height)
  tile.filter_clip=true;tiles.append(tile)
 for prefix: String in ["idle","walk","melee","projectile","radial","lightning","shockwave","phase"]:
  for facing: String in ["left","right"]:
   var animation:=StringName(prefix+"_"+facing)
   frames.add_animation(animation)
   frames.set_animation_loop(animation,prefix in ["idle","walk"])
   frames.set_animation_speed(animation,7.5 if prefix=="walk" else 6.0)
   var sequence: Array=[0] if prefix=="idle" else ([1,0,2,0] if prefix=="walk" else [0,3,3,0])
   for index: int in sequence:frames.add_frame(animation,tiles[index])
 var sprite: AnimatedSprite2D=boss.get_node("AnimatedSprite2D")
 sprite.sprite_frames=frames
 sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 # Cell height256; figure occupies~70%, body reads~145px, sovereign~164px.
 var desired: float=210.0 if int(profile.stage)>=5 else 185.0
 sprite.scale=Vector2.ONE*(desired/height)
 sprite.position=Vector2(0,14.0-desired*.46875)
 sprite.flip_h=bool(boss.facing_left)
 boss.set_meta("refined_boss_art",true)
 return true
