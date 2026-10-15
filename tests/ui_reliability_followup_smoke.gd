extends SceneTree
var checks: int=0
var failures: int=0
var captured: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("UI_RELIABILITY_FAIL "+message)
func frames(count: int=12) -> void:
 for i: int in range(count):await process_frame
func fits_text(control: Control) -> bool:
 var text: String=str(control.get("text"))
 var font: Font=control.get_theme_font("font")
 var available: float=control.size.x
 if control is Button:available-=control.get_theme_stylebox("normal").get_minimum_size().x
 return font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x<=available+1
func within(rect: Rect2,outer: Rect2) -> bool:
 return rect.position.x>=outer.position.x-1 and rect.position.y>=outer.position.y-1 and rect.end.x<=outer.end.x+1 and rect.end.y<=outer.end.y+1
func capture(name_value: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/jade-qa/"+name_value+".png")
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_ui_reliability_qa"):quit(2);return
 create_timer(110).timeout.connect(func():push_error("UI_RELIABILITY_WATCHDOG");quit(3))
 await create_timer(.5).timeout
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 var config:=ConfigFile.new();config.set_value("meta","version",2)
 for id: String in ["home","equipment","pavilion"]:config.set_value("tutorials",id,true)
 config.save("user://jade_onboarding.cfg")
 var guide: Node=root.get_node_or_null("RefineOnboarding")
 if guide!=null:guide.completed=true;guide.set_process(false)
 var cache: Node=root.get_node("MenuResourcePrewarm")
 cache._generation+=1;cache._prewarm_completed=true
 var eq: Node=root.get_node("EquipmentManager");var inv: Node=root.get_node("InventoryManager")
 for id: String in eq.get_item_ids():inv.item_counts[id]=2
 for id: String in ["nine_heavens_star_sword","sovereign_mantle","tribulation_bracer","cloudtreader_boots","ascendant_heart"]:eq.equip_item(id)
 var economy: Array=[inv.item_counts.duplicate(true),root.get_node("PavilionManager").state.duplicate(true),root.get_node("ProgressionManager").spirit_stone]
 var prefs: Node=root.get_node("SettingsManager")
 for language: String in ["en","id"]:
  prefs.set_presentation("language",language)
  change_scene_to_file("res://scenes/ui/settings_screen.tscn");await frames(18)
  var settings: Node=current_scene
  for viewport: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(720,1600)]:
   root.size=viewport;await frames()
   for key: String in settings.presentation_toggles:
    var toggle: CheckButton=settings.presentation_toggles[key]
    var state: Label=settings.presentation_toggle_labels[key]
    for enabled: bool in [false,true]:
     toggle.set_pressed(enabled);await frames(2)
     var expected: String=("AKTIF" if enabled else "MATI") if language=="id" else ("ON" if enabled else "OFF")
     check(state.text==expected,"complete toggle state "+key+" "+language)
     check(toggle.text.is_empty() and fits_text(state) and state.get_line_count()==1,"native switch never clips state to O")
     check(bool(prefs.get(key))==enabled,"actual preference follows toggle")
   var content: Control=settings.get_node("SafeArea/Scroll/Content")
   check(content.size.x<=viewport.x,"settings remains within phone width")
   if viewport.x==720 and language=="en":
    var toggle_top: float=settings.presentation_toggles.screen_shake.get_parent().get_parent().get_global_position().y
    settings._settings_scroll.scroll_vertical+=roundi(toggle_top-settings._settings_scroll.get_global_position().y)-75
    await frames();await capture("ui-followup-settings-720")
 prefs.set_presentation("language","en")
 change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(18)
 var home: Node=current_scene
 var presenter: Node=home.get_node("HomeUI/HomeProductionOverlay")
 for viewport: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(720,1600),Vector2i(896,504)]:
  root.size=viewport;await frames(16)
  for continuation: bool in [false,true]:
   presenter.continue_button.visible=continuation;presenter._layout_sanctuary();await frames(3)
   check(presenter.journey_button.text.contains("ENTER JOURNEY"),"full Journey label retained")
   for button: Button in [presenter.journey_button,presenter.continue_button,presenter.all_events_button]:
    if not button.visible:continue
    check(fits_text(button),"complete CTA "+str(button.name)+" "+str(viewport))
    check(button.size.y>=44,"comfortable CTA hit target "+str(button.name))
    check(button.get_theme_font_size("font_size")>=14,"readable CTA font")
   for button: Button in [presenter.settings_shortcut,presenter.mailbox_button]:check(button.size.x>=48 and button.size.y>=48,"header icon tap target")
   for button: Button in [presenter.seven_day_button,presenter.meditation_button,presenter.library_button]:
    for label: Label in [button.get_node("Title"),button.get_node("State")]:
     check(fits_text(label),"shortcut copy fits "+str(button.name)+" "+str(label.text)+" "+str(viewport))
   if viewport.x in [390,720] and not continuation:await capture("ui-followup-home-"+str(viewport.x))
 # All hub scenes share exactly one wallet composition and source routes.
 var wallet: Node=root.get_node("HubResourceBarManager")
 wallet.set_process(false)
 for scene: String in wallet.HUB_SCENES:
  root.size=Vector2i(390,844)
  change_scene_to_file(scene);await frames(20)
  wallet._refresh_scene_binding();wallet._sync_values();await frames()
  var screen_id: int=current_scene.get_instance_id()
  for viewport: Vector2i in [Vector2i(320,568),Vector2i(720,1600)]:
   root.size=viewport;await frames(16)
   wallet._sync_values();await frames()
   var bar: Control=wallet._resource_bar
   var host: Control=wallet._resource_host(current_scene,scene)
   check(is_equal_approx(bar.size.y,70),"same wallet height "+scene)
   check(is_equal_approx(bar.get_global_position().y,host.get_global_position().y),"wallet respects scene safe-area origin")
   var row: HBoxContainer=bar.get_node("ResourceRow")
   for i: int in range(3):
    var cell: Control=row.get_child(i);var value: Label=wallet._cell_value_label(cell);var icon: Control=cell.get_child(0)
    var button: Button=bar.get_node("WalletSource%d"%i);var plus: Label=button.get_node("Plus")
    check(value.get_theme_font_size("font_size")>=14 and icon.size.x>=26,"larger resource value/icon")
    check(absf(value.get_global_rect().get_center().y-bar.get_global_rect().get_center().y)<1,"value centered away from border")
    check(value.get_global_rect().end.x<=plus.get_global_rect().position.x,"number and plus do not overlap")
    check(fits_text(value),"resource digits fit")
    var original: String=value.text
    for amount: int in [96,9999,123456,1234567890]:
     value.text=wallet._format_count(amount);wallet._layout_sanctuary_wallet();await frames(2)
     check(fits_text(value) and value.get_global_rect().end.x<=plus.get_global_rect().position.x,"large/short balances stay clear of plus "+str(amount)+" "+str(viewport)+" "+str(value.size.x)+" "+str(value.get_theme_font_size("font_size")))
    value.text=original;wallet._layout_sanctuary_wallet()
    check(within(button.get_global_rect(),bar.get_global_rect()),"resource hit target fits bar")
   if viewport.x==720 and scene==wallet.HERO_SCENE:await capture("ui-followup-hero-720")
  wallet._on_sanctuary_currency_source(screen_id,1);await frames(18)
  var ops: Node=root.get_node("LiveOpsManager")
  check(ops._active_live_popup!=null and ops._active_live_popup.scene_file_path==wallet.TREASURY_SCENE,"Jade + opens real Treasury "+scene)
  check(current_scene.get_instance_id()==screen_id,"Treasury preserves hub page")
  ops.close_live_popup();await frames()
 # Re-entering Hero: one initial composition, shared texture identity, no filter full-page rebuild.
 var builds: Array[int]=[]
 for attempt: int in range(2):
  root.size=Vector2i(390,844);change_scene_to_file(wallet.HERO_SCENE);await frames(18)
  var hero: Node=current_scene
  print("HERO_VERIFIED_BUILD_US=",hero._last_build_usec," COUNT=",hero._build_count)
  check(hero._build_count==1,"Hero first open composes exactly once")
  var count: int=hero._build_count;var slot: Node=hero.fixed_deck.find_child("Slot_armament",true,false);var slot_id: int=slot.get_instance_id()
  hero.filter_menu.item_selected.emit(1);await frames()
  check(hero._build_count==count and slot.get_instance_id()==slot_id,"filter updates collection without refreshing equipped deck")
  var path: String="res://assets/ui/hero/lin_yue_menu_showcase_v2.png"
  var first: Texture2D=cache.get_hub_texture(path)
  check(first==cache.get_hub_texture(path),"hub texture cache reuses same resource")
  change_scene_to_file(wallet.HOME_SCENE);await frames()
 check(economy==[inv.item_counts,root.get_node("PavilionManager").state,root.get_node("ProgressionManager").spirit_stone],"UI/source routing never buys or grants currency")
 change_scene_to_file("res://scenes/levels/level_1.tscn");await frames(18)
 # Native path uses the actual scene_changed subscription; headless explicitly executes same handler.
 if DisplayServer.get_name()=="headless":cache._on_scene_changed()
 check(cache._warm_cache.is_empty(),"hub texture retention is released on gameplay entry")
 current_scene.get_node("EnemySpawner").process_mode=Node.PROCESS_MODE_DISABLED
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);current_scene.queue_free();await frames()
 print("UI_RELIABILITY checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
