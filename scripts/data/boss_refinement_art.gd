extends RefCounted
## Per-boss 2D cels. Load only the encountered boss, with legacy fallback available.
const Profiles=preload("res://scripts/data/boss_premium_catalog.gd")
const FrameDriver=preload("res://scripts/enemy/boss_frame_driver.gd")
const FAMILIES: Array[String]=["walk","melee","projectile","radial","lightning","shockwave"]
static func _path(profile: Dictionary) -> String:
 return "res://assets/enemy/boss_2d/atlas_%d_%d.png" % [int(profile.get("chapter",0)),mini(5,int(profile.get("stage",0)))]
static func has_art(display_name: String) -> bool:
 var profile: Dictionary=Profiles.get_profile(display_name)
 return not profile.is_empty() and ResourceLoader.exists(_path(profile))
static func install(boss: Node) -> bool:
 var profile: Dictionary=Profiles.get_profile(str(boss.encounter_display_name))
 if profile.is_empty():return false
 boss.set_meta("boss_pressure_role",(int(profile.stage)-1)%5)
 var path: String=_path(profile)
 if not ResourceLoader.exists(path):return false
 var atlas: Texture2D=load(path)
 if atlas==null:return false
 var frames:=SpriteFrames.new();frames.remove_animation(&"default")
 var width: float=atlas.get_width()/6.0
 var height: float=atlas.get_height()/6.0
 for family: String in FAMILIES+["idle","phase"]:
  var row: int=FAMILIES.find(family)
  if family=="idle":row=1
  if family=="phase":row=3
  for direction: String in ["left","right"]:
   var name_value:=StringName(family+"_"+direction);frames.add_animation(name_value)
   frames.set_animation_loop(name_value,false);frames.set_animation_speed(name_value,8)
   for column: int in range(1 if family=="idle" else 6):
    var tile:=AtlasTexture.new();tile.atlas=atlas;tile.region=Rect2(column*width,row*height,width,height);tile.filter_clip=true
    frames.add_frame(name_value,tile)
 var sprite: AnimatedSprite2D=boss.get_node("AnimatedSprite2D")
 sprite.sprite_frames=frames;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 var size: float=160.0 if int(profile.stage)>=5 else 140.0
 boss.set_meta("boss_visible_height",size)
 # Transparent safety gutters must not shrink the boss's visible body.
 var idle_rect:=atlas.get_image().get_region(Rect2i(0,int(height),int(width),int(height))).get_used_rect()
 var visible_height: float=maxf(float(idle_rect.size.y),1.0)
 sprite.scale=Vector2.ONE*(size/visible_height)
 sprite.position=Vector2(0,14.0-(148.0-height*.5)*sprite.scale.y)
 sprite.flip_h=bool(boss.facing_left)
 boss.set_meta("refined_boss_art",true);boss.set_meta("frame_driven_boss",true)
 var driver:=FrameDriver.new();driver.name="BossFrameDriver";boss.add_child(driver)
 return true
