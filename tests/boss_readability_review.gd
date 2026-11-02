extends SceneTree
const Chapters: Array=[preload("res://scripts/data/chapter_one_catalog.gd"),preload("res://scripts/data/chapter_two_catalog.gd"),preload("res://scripts/data/chapter_three_catalog.gd"),preload("res://scripts/data/chapter_four_catalog.gd"),preload("res://scripts/data/chapter_five_catalog.gd")]
const HeroFrames=preload("res://assets/character/player/player_lin_yue_idle_walk_spriteframes.tres")
var checks: int=0
var failures: int=0
var rows: Array[Dictionary]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("BOSS_READABILITY "+label)
func label_node(value: String,size_value: int=16) -> Label:
 var node:=Label.new();node.text=value;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 node.add_theme_font_size_override("font_size",size_value);node.add_theme_color_override("font_color",Color(.92,.86,.68));return node
func run() -> void:
 if not OS.get_user_data_dir().contains("connection_combat"):quit(2);return
 check(DisplayServer.get_name()!="headless","real GUI renderer is required")
 if DisplayServer.get_name()=="headless":quit(2);return
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(720,1600)
 var legacy: bool="--legacy-size" in OS.get_cmdline_user_args()
 var suffix: String="before" if legacy else "after"
 var output: String="res://.local/connection_combat_qa/boss_review";DirAccess.make_dir_recursive_absolute(output)
 for chapter: int in range(1,6):
  var page:=Control.new();root.add_child(page);page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  var bg:=ColorRect.new();bg.color=Color("061714");page.add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  var layout:=VBoxContainer.new();layout.position=Vector2(16,12);layout.size=Vector2(688,1576);layout.add_theme_constant_override("separation",12);page.add_child(layout)
  layout.add_child(label_node("JADE ASCENDANT · CHAPTER %d · %s"%[chapter,suffix.to_upper()],22))
  layout.add_child(label_node("Production boss sprites + actual contact footprint · Lin Yue for scale",14))
  var grid:=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);layout.add_child(grid)
  for stage: int in range(1,6):
   var profile: Dictionary=Chapters[chapter-1].get_stage(stage)
   var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(340,474);grid.add_child(panel)
   var skin:=StyleBoxFlat.new();skin.bg_color=Color("0a2420");skin.border_color=Color(.48,.42,.23);skin.set_border_width_all(1);panel.add_theme_stylebox_override("panel",skin)
   var column:=VBoxContainer.new();column.custom_minimum_size=Vector2(336,0);panel.add_child(column)
   var title:=label_node("%d-%d · %s"%[chapter,stage,str(profile.boss_name)],16);title.custom_minimum_size=Vector2(328,52);column.add_child(title)
   var view_box:=SubViewportContainer.new();view_box.custom_minimum_size=Vector2(336,352);view_box.stretch=true;column.add_child(view_box)
   var view:=SubViewport.new();view.size=Vector2i(336,352);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.world_2d=World2D.new();view_box.add_child(view)
   var world:=Node2D.new();view.add_child(world)
   var path: String="res://scenes/enemy/boss_1.tscn" if chapter<=3 else "res://scenes/enemy/boss_realm_%d.tscn"%chapter
   var boss: Node2D=load(path).instantiate();boss.configure_encounter(profile);boss.position=Vector2(108,237);world.add_child(boss)
   boss.set_physics_process(false);boss.set_process(false)
   var hero:=AnimatedSprite2D.new();hero.sprite_frames=HeroFrames;hero.animation=&"idle_down";hero.frame=0;hero.position=Vector2(247,220);hero.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;world.add_child(hero)
   var sprite: AnimatedSprite2D=boss.get_node("AnimatedSprite2D")
   var frame: Texture2D=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
   var visible_rect: Rect2i=frame.get_image().get_used_rect()
   var actual_height: float=visible_rect.size.y*absf(sprite.global_scale.y)
   var collider: CollisionShape2D=boss.get_node("CollisionShape2D")
   var rect: Rect2=collider.shape.get_rect()
   var marker: Node2D=collider.get_node_or_null("ContactFootprint")
   var max_height: float=(160 if stage==5 else 140) if legacy else (128 if stage==5 else 112)
   check(is_equal_approx(actual_height,max_height),"actual alpha-body height %d-%d"%[chapter,stage])
   if not legacy:
    check(marker!=null,"contact marker exists %d-%d"%[chapter,stage])
    if marker!=null:check(marker.global_transform.is_equal_approx(collider.global_transform),"marker and collider transforms agree %d-%d"%[chapter,stage])
   rows.append({"chapter":chapter,"stage":stage,"name":str(profile.boss_name),"height":actual_height,"contact_size":rect.size,"contact_position":collider.position,"contact_scale":collider.global_scale,"hp":boss.max_hp,"speed":boss.speed,"melee_range":boss.melee_distance})
   column.add_child(label_node("Boss %.0f px · Contact %.0f × %.0f\nLin Yue uses the actual player atlas"%[actual_height,rect.size.x,rect.size.y],13))
  for i: int in 4:await process_frame
  await RenderingServer.frame_post_draw
  var pixels: Image=root.get_texture().get_image()
  check(pixels!=null and not pixels.is_empty() and pixels.get_width()==720,"real renderer readback chapter "+str(chapter))
  if pixels!=null and not pixels.is_empty():check(pixels.save_png(output+"/chapter_%d-%s.png"%[chapter,suffix])==OK,"screenshot saved")
  page.queue_free();await process_frame;await process_frame
 var file:=FileAccess.open(output+"/metrics-"+suffix+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"native_gui":DisplayServer.get_name()!="headless","renderer":RenderingServer.get_video_adapter_name()},"\t"));file.close()
 print("BOSS_READABILITY_REVIEW checks=%d failures=%d; NATIVE_GUI=true; renderer=%s"%[checks,failures,RenderingServer.get_video_adapter_name()])
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 quit(1 if failures else 0)
