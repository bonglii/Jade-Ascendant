extends Node

## Stage 1-1 follow-up. No free item, spend, unlock or gameplay pause ownership.
const SAVE_PATH: String = "user://refine_guide.cfg"
const HOME: String = "res://scenes/ui/main_menu.tscn"
const HERO: String = "res://scenes/ui/equipment_screen.tscn"
var completed: bool = false
var step: int = 0
var elapsed: float = 0.0
var popup: Control
var scene_id: int = 0

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 var config := ConfigFile.new()
 if config.load(SAVE_PATH) == OK: completed = bool(config.get_value("refine", "completed", false))

func _process(delta: float) -> void:
 if completed: return
 elapsed += delta
 if elapsed < 0.25: return
 elapsed = 0.0
 var scene: Node = get_tree().current_scene
 if is_instance_valid(popup):
  if scene == null or scene.get_instance_id() != scene_id: _dismiss(false)
  return
 if not should_offer(scene): return
 if scene.scene_file_path == HOME: step = 0
 elif step == 0: step = 1
 _show_guide(scene)

func should_offer(scene: Node) -> bool:
 if completed or scene == null or not JourneyManager.is_stage_cleared(1,1): return false
 if scene.scene_file_path not in [HOME, HERO] or SceneTransitionManager.is_transitioning: return false
 if get_tree().paused or SaveManager.is_progress_read_only(): return false
 if scene.scene_file_path == HERO and bool(scene.get("detail_open")): return false
 for name_value: String in ["UnifiedRewardClaimPopup", "SpiritMeditationPremiumPopup", "SanctuaryAnnouncement", "ProfilePopup", "JadeOnboardingOverlay"]:
  var blocker: CanvasItem = get_tree().root.find_child(name_value,true,false) as CanvasItem
  if blocker != null and blocker.is_visible_in_tree(): return false
 var live_ops: Node = get_tree().root.get_node_or_null("LiveOpsManager")
 if live_ops != null and is_instance_valid(live_ops.get("_active_live_popup")): return false
 return true

func _show_guide(scene: Node) -> void:
 scene_id = scene.get_instance_id()
 popup = Control.new();popup.name = "RefineOnboarding";popup.z_index = 225
 scene.add_child(popup);popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var scrim := ColorRect.new();scrim.color = Color(.002,.015,.022,.58);popup.add_child(scrim)
 scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scrim.mouse_filter = Control.MOUSE_FILTER_STOP
 var panel := PanelContainer.new();panel.name = "RefineGuideCard";popup.add_child(panel)
 panel.anchor_left=.08;panel.anchor_right=.92;panel.anchor_top=.5;panel.anchor_bottom=.5
 var skin := StyleBoxFlat.new();skin.bg_color=Color(.012,.063,.07,.99);skin.border_color=Color(.68,.88,.77,.8)
 skin.set_border_width_all(1);skin.set_corner_radius_all(16);skin.shadow_color=Color(.09,.55,.43,.16);skin.shadow_size=12
 for side: int in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: skin.set_content_margin(side,20)
 panel.add_theme_stylebox_override("panel",skin)
 var scroll := ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.scroll_deadzone=10;panel.add_child(scroll)
 var body := VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",14);scroll.add_child(body)
 _label(body,"JADE ASCENSION  ·  %d / 3" % (step+1),13,Color(.45,.88,.77))
 var emblem := TextureRect.new();emblem.texture=preload("res://assets/ui/main_menu/polish/sanctuary_medallion.svg")
 emblem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;emblem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 emblem.custom_minimum_size=Vector2(60,60);emblem.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(emblem)
 var titles: Array[String]=["Perkuat relikmu", "Duplikat membuka bintang", "Weapon punya level sendiri"]
 var copy: Array[String]=[
  "Stage 1-1 selesai. Buka HERO untuk memperkuat equipment. Titik merah di kanan atas menandai upgrade yang sudah bisa dilakukan.",
  "Ketuk equipment di backpack, lalu NAIK BINTANG. Satu duplikat identik dikonsumsi; item utama tetap tersimpan. Maksimum 5 bintang. Rarity tidak berubah.",
  "NAIK LEVEL memakai Spirit Stone. Batas level weapon: 10 / 20 / 30 / 40 / 50 sesuai bintangnya. Titik merah hilang jika upgrade sudah max, biaya kurang, atau run masih terkunci."
 ]
 _label(body,titles[step],23,Color(1,.86,.56));_label(body,copy[step],16,Color(.86,.95,.92))
 var button := Button.new();button.name="GuideContinue";button.text="BUKA HERO" if step==0 else ("SELESAI" if step==2 else "LANJUT")
 button.custom_minimum_size.y=52;button.focus_mode=Control.FOCUS_NONE;body.add_child(button)
 for state: String in ["normal","hover","pressed"]:
  var texture_style := StyleBoxTexture.new()
  texture_style.texture=load("res://assets/ui/system_v2/custom/buttons/primary_%s.svg" % ("pressed" if state=="pressed" else "normal")) as Texture2D
  texture_style.texture_margin_left=18;texture_style.texture_margin_right=18;texture_style.texture_margin_top=12;texture_style.texture_margin_bottom=12
  button.add_theme_stylebox_override(state,texture_style)
 button.pressed.connect(_continue.bind(step, popup.get_instance_id()))
 SceneTransitionManager.set_back_handler(Callable(self,"_finish"))
 panel.modulate.a=0.0
 var tween := panel.create_tween();tween.tween_property(panel,"modulate:a",1.0,.2)
 _fit_card.call_deferred(panel,body,scene_id)

func _label(body: VBoxContainer, copy: String, font_size: int, tint: Color) -> void:
 var label := Label.new();label.text=copy;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",tint);body.add_child(label)

func _fit_card(panel: Variant, body: Variant, expected_scene: int) -> void:
 await get_tree().process_frame
 await get_tree().process_frame
 if not is_instance_valid(panel) or not is_instance_valid(body) or scene_id != expected_scene: return
 var height: float=minf(body.get_combined_minimum_size().y+40,get_viewport().get_visible_rect().size.y*.66)
 panel.offset_top=-height*.5;panel.offset_bottom=height*.5

func _continue(expected_step: int=-1, expected_popup: int=0) -> void:
 if not is_instance_valid(popup) or popup.is_queued_for_deletion(): return
 if expected_step>=0 and (step!=expected_step or popup.get_instance_id()!=expected_popup): return
 if step==0:
  step=1;_dismiss(false);SceneTransitionManager.transition_menu_to(HERO);return
 if step==2: _finish();return
 step+=1
 var scene: Node=get_tree().current_scene
 _dismiss(false)
 if scene!=null: _show_guide(scene)

func _finish() -> void:
 if completed: return
 var config := ConfigFile.new();config.set_value("refine","completed",true)
 if config.save(SAVE_PATH)!=OK: return # Do not silently lose the completion mark.
 completed=true;_dismiss(true)

func _dismiss(restore_back: bool) -> void:
 if is_instance_valid(popup): popup.queue_free()
 popup=null
 if restore_back:
  var scene: Node=get_tree().current_scene
  if scene!=null and scene.has_method("handle_system_back"):SceneTransitionManager.set_back_handler(Callable(scene,"handle_system_back"))
