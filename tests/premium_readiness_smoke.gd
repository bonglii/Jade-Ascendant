extends SceneTree
const Catalog=preload("res://scripts/data/skill_catalog.gd")
const DNS=preload("res://scripts/managers/trusted_profile_dns.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("PREMIUM_BATCH_FAIL "+message)
func frames(n: int=8) -> void:
 for i: int in range(n):await process_frame
func capture(name_value: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/jade-qa/"+name_value+".png")
func bounds(rect: Rect2, outer: Rect2) -> bool:
 return rect.position.x>=outer.position.x-1 and rect.position.y>=outer.position.y-1 and rect.end.x<=outer.end.x+1 and rect.end.y<=outer.end.y+1
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_premium_batch_qa"):quit(2);return
 create_timer(100).timeout.connect(func():push_error("PREMIUM_BATCH_WATCHDOG");quit(3))
 await create_timer(.5).timeout
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 var config:=ConfigFile.new();config.set_value("meta","version",2)
 for key: String in ["home","equipment","pavilion"]:config.set_value("tutorials",key,true)
 config.save("user://jade_onboarding.cfg")
 var prewarm: Node=root.get_node_or_null("MenuResourcePrewarm")
 if prewarm!=null:prewarm.queue_free()
 var guide: Node=root.get_node_or_null("RefineOnboarding")
 if guide!=null:guide.completed=true;guide.set_process(false)
 var eq: Node=root.get_node("EquipmentManager")
 var inv: Node=root.get_node("InventoryManager")
 for id: String in eq.get_item_ids():inv.item_counts[id]=2
 for id: String in ["nine_heavens_star_sword","sovereign_mantle","tribulation_bracer","cloudtreader_boots","ascendant_heart"]:eq.equip_item(id)
 var economy: Dictionary=inv.item_counts.duplicate(true)
 check(change_scene_to_file("res://scenes/ui/equipment_screen.tscn")==OK,"real Hero loads")
 await frames(18)
 var hero: Control=current_scene
 for viewport: Vector2i in [Vector2i(648,1152),Vector2i(390,844),Vector2i(320,568),Vector2i(896,504)]:
  root.size=viewport;await frames(16)
  print("HERO_LAYOUT ",viewport," content=",hero.content.size," deck=",hero.fixed_deck.size," scroll=",hero.scroll.get_rect())
  var deck: Control=hero.fixed_deck
  var slot: Control=deck.find_child("Slot_armament",true,false)
  var at: Rect2=slot.get_global_rect();var instance: int=slot.get_instance_id()
  check(hero.grid.columns==5,"five columns "+str(viewport))
  check(hero.scroll.position.y>=deck.position.y+deck.size.y,"backpack begins below pinned deck")
  check(hero.scroll.get_global_rect().end.y<=hero.nav.get_global_rect().position.y,"backpack fits above navigation")
  check(hero.scroll.size.y>=110,"usable backpack viewport "+str(viewport))
  check(bounds(deck.get_global_rect(),Rect2(Vector2.ZERO,Vector2(viewport))),"pinned deck fits "+str(viewport))
  check(hero.filter_menu.size.x>40 and hero.filter_menu.get_global_rect().end.x<viewport.x,"phone dropdown fits")
  hero.scroll.scroll_vertical=10000;await frames()
  check(hero.scroll.scroll_vertical>0,"backpack still scrolls")
  check(slot.get_instance_id()==instance and slot.get_global_rect().is_equal_approx(at),"equipped row stays pinned without rebuild")
  var card: Button=hero.card_buttons.values()[0]
  check(card.get_node("ItemRank").get_theme_font_size("font_size")>=11,"readable stars")
  var guard: Node=root.get_node("MobileTouchPresentationGuard")
  guard.touch_mode=true;guard._capture(card)
  var drag:=InputEventScreenDrag.new();drag.relative=Vector2(15,0);guard._input(drag);drag.relative=Vector2(-15,0);guard._input(drag)
  hero._card_pressed(str(card.name).trim_prefix("Relic_"))
  check(not hero.detail_open,"swipe returning to origin cannot open item")
  guard._apply(card)
  check(card.get_theme_stylebox("hover")==card.get_theme_stylebox("normal") and card.get_theme_stylebox("hover_pressed")==card.get_theme_stylebox("normal"),"touch does not glow while scrolling")
  hero.scroll.scroll_vertical=0;await frames()
  if viewport.x in [390,896]:await capture("premium-hero-"+str(viewport.x))
 check(inv.item_counts==economy,"Hero presentation does not mutate inventory")
 check(change_scene_to_file("res://scenes/ui/settings_screen.tscn")==OK,"real Settings loads")
 await frames(20)
 var settings: Node=current_scene
 var prefs: Node=root.get_node("SettingsManager")
 var before: Array=[prefs.master_volume,prefs.music_volume,prefs.sfx_volume,prefs.language,prefs.haptics,prefs.damage_numbers]
 for id: String in ["battery","balanced","premium"]:
  prefs.set_quality_preset(id)
  check(prefs.get_quality_preset()==id,"preset actual settings "+id)
  prefs._load_settings();check(prefs.get_quality_preset()==id,"preset persisted "+id)
 check(before==[prefs.master_volume,prefs.music_volume,prefs.sfx_volume,prefs.language,prefs.haptics,prefs.damage_numbers],"preset preserves audio language and controls")
 for viewport: Vector2i in [Vector2i(390,844),Vector2i(320,568),Vector2i(648,1152)]:
  root.size=viewport;await frames(16)
  var content: Control=settings.get_node("SafeArea/Scroll/Content")
  check(content.size.x<=viewport.x,"Settings content width "+str(viewport))
  for name_value: String in ["Header","AudioCard","GoogleAccountCard","ConnectionSupportCard"]:
   var card: Control=content.get_node_or_null(name_value)
   check(card!=null and card.size.x>100,"settings card exists "+name_value)
   if card!=null:
    for label: Label in card.find_children("*","Label",true,false):
     if label.is_visible_in_tree() and not label.text.is_empty():check(label.size.y>0,"visible label "+str(label.name))
  var summary: String=settings.get_support_summary()
  check(not summary.contains("Bearer") and not summary.contains("firebase_uid") and not summary.contains("owner_binding"),"support allowlist")
  settings._settings_scroll.scroll_vertical=0;await frames()
  if viewport.x==390:await capture("premium-settings-390")
  settings._settings_scroll.scroll_vertical=100000;await frames()
  check(settings._settings_scroll.scroll_vertical>0,"Settings long content remains scrollable")
  if viewport.x==390:await capture("premium-settings-support")
 var guard: Node=root.get_node("MobileTouchPresentationGuard")
 for ref: WeakRef in guard._scrollers.values():
  var scroll: ScrollContainer=ref.get_ref()
  if scroll!=null:check(scroll.vertical_scroll_mode in [ScrollContainer.SCROLL_MODE_DISABLED,ScrollContainer.SCROLL_MODE_SHOW_NEVER] and scroll.horizontal_scroll_mode in [ScrollContainer.SCROLL_MODE_DISABLED,ScrollContainer.SCROLL_MODE_SHOW_NEVER],"no visible scrollbar in tracked UI")
 check(change_scene_to_file("res://scenes/levels/level_1.tscn")==OK,"real result host")
 await frames(20)
 current_scene.get_node("EnemySpawner").process_mode=Node.PROCESS_MODE_DISABLED
 var tutorial: Node=current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")
 tutorial._on_skip_pressed()
 var player: Node=current_scene.get_node("player_1")
 player.set_physics_process(false);player.get_node("WeaponManager").set_process(false)
 var ledger: Node=player.get_node("WeaponManager/RunCombatLedger")
 var starter: Node=player.get_node("WeaponManager").get_weapon_by_name("Spirit Sword")
 starter.armament_id="jade_binding_chain";starter.armament_profile.clear()
 ledger.record("jade_binding_chain",240);ledger.record("fire_orb",80)
 var rows: Array=ledger.skills()
 check(rows[0].armament_id=="jade_binding_chain","report records run armament")
 eq.equipped_item_ids["armament"]="celestial_returning_glaive"
 paused=true
 var victory: Node=current_scene.get_node("VictoryUI")
 victory.show_victory();await frames(18)
 var ceremony: Node=victory.get_node("ResultCeremony")
 check(not victory.clear_state_label.text.contains("REWARD SECURED"),"no receipt means no secured-reward claim")
 ceremony._show_skills=true;ceremony._refresh_report_rows();await frames()
 var icon: TextureRect=ceremony._report_rows.find_child("ReportSkillIcon_spirit_sword",true,false)
 check(icon!=null and icon.texture.resource_path==Catalog.get_icon_path("spirit_sword","jade_binding_chain"),"Victory icon follows run rather than hub weapon")
 for viewport: Vector2i in [Vector2i(390,844),Vector2i(320,568)]:
  root.size=viewport;await frames(16)
  check(bounds(ceremony._panel.get_global_rect(),Rect2(Vector2.ZERO,Vector2(viewport))),"result fits phone")
  check(victory.main_menu_button.get_global_rect().end.y<=viewport.y,"fixed result actions fit")
  if viewport.x==390:await capture("premium-victory-skills")
 victory.hide()
 var defeat: Node=current_scene.get_node("GameOverUI")
 defeat.show_game_over();await frames(18);root.size=Vector2i(390,844);await frames();await capture("premium-defeat")
 paused=false
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);current_scene.queue_free();await frames()
 print("PREMIUM_READINESS checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
