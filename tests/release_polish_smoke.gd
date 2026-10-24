extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("RELEASE_POLISH "+why)
func settle(n: int=8) -> void:
 for i: int in n:await process_frame
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var folder: String=OS.get_environment("JADE_POLISH_RENDER_DIR")
 if not folder.is_empty():root.get_texture().get_image().save_png(folder+"/"+name+".png")
func mouse(at: Vector2,down: bool) -> void:
 var e:=InputEventMouseButton.new();e.position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;root.push_input(e,true)
func swipe(at: Vector2) -> void:
 mouse(at,true);await settle(1)
 for i: int in range(1,9):
  var e:=InputEventMouseMotion.new();e.position=at+Vector2(0,-110)*float(i)/8;e.relative=Vector2(0,-110.0/8);e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true);await settle(1)
 mouse(at+Vector2(0,-110),false);await settle()
func run() -> void:
 if not (OS.get_user_data_dir().contains("jade_release_polish_qa") or OS.get_user_data_dir().contains("jade_event_touch_qa")):quit(2);return
 create_timer(60).timeout.connect(func():push_error("RELEASE_POLISH_WATCHDOG");quit(1))
 await settle()
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(390,844)
 var guide:=ConfigFile.new();guide.set_value("meta","version",2)
 for key: String in ["home","equipment","pavilion"]:guide.set_value("tutorials",key,true)
 guide.save("user://jade_onboarding.cfg")
 var journey: Node=root.get_node("JourneyManager")
 journey.cleared_stage_keys.clear()
 change_scene_to_file("res://scenes/ui/pavilion_screen.tscn");await settle(20)
 var page: Control=current_scene
 check(page._lock_notice.visible and "1–5" in page._lock_notice.text,"locked Pavilion has a prominent actionable notice")
 page._show_drop_rates_overlay();await settle()
 var body: VBoxContainer=page.locked_rates_overlay.get_meta("content")
 var rates: Array[String]=[]
 for node: Node in body.get_children():
  if node is Label and "%" in node.text:rates.append(node.text)
 check(rates.size()==4 and rates.any(func(v: String)->bool:return "60.00%" in v),"pre-unlock odds describe the base pool instead of four zeroes")
 check(page.locked_rates_overlay.color.a<=0.16,"Pavilion scrim preserves visible background")
 await capture("pavilion-locked-rates")
 page._back();await settle(12)
 for stage: int in range(1,6):journey.cleared_stage_keys.append(journey.get_stage_key(1,stage))
 page._refresh_summon_panel();await settle()
 check(not page._lock_notice.visible,"unlock notice follows actual unlock")
 page._open_target_picker("weapon");await settle(20)
 var sheet: ColorRect=page._target_overlay
 var panel: PanelContainer=sheet.get_meta("panel")
 var identity: int=sheet.get_instance_id()
 var rect: Rect2=panel.get_rect()
 check(panel.modulate.a==1 and panel.clip_contents,"first paint occurs only after the complete sheet fits")
 var scroll: ScrollContainer=sheet.get_meta("scroll")
 var target: String=root.get_node("PavilionManager").get_wish_target_item_id()
 var choices: GridContainer=(sheet.get_meta("content") as VBoxContainer).get_node("TargetChoices")
 var at: Vector2=(choices.get_child(0) as Control).get_global_rect().get_center()
 if scroll.get_global_rect().has_point(at):
  await swipe(at)
  check(scroll.scroll_vertical>20,"first native swipe beginning on a target button scrolls")
  check(root.get_node("PavilionManager").get_wish_target_item_id()==target,"native swipe does not select a target")
 await create_timer(.16).timeout
 page._open_target_picker("set");await settle(20)
 check(page._target_overlay.get_instance_id()==identity,"category change reuses the same popup instead of reopening it")
 check(panel.get_rect()==rect,"weapon and set categories keep the same popup footprint")
 check(sheet.find_child("Target_sovereign_mantle",true,false)!=null,"set category uses actual item artwork/options")
 await capture("pavilion-set-target")
 page._back();await settle(12)
 var result: Dictionary={"results":[{"item_id":"nine_heavens_star_sword","rarity":"legendary"}]}
 page._start_summon_reveal(result);page._reveal_stage.set_process(false);page._skip_ritual();await settle(2)
 page._finish_summon_reveal();page._start_summon_reveal({"results":[{"item_id":"jade_binding_chain","rarity":"legendary"}]});page._reveal_stage.set_process(false)
 await create_timer(.12).timeout
 check(page._result_name.text.is_empty() and not page._result_name.visible,"previous landing tween cannot leak identity into the next summon")
 check(page._reveal_stage.relic==null,"next item's artwork stays sealed")
 await capture("pavilion-sealed")
 page._reveal_stage.set_process(true);page._skip_ritual();await settle(20);await capture("pavilion-legendary")
 check(page.summon_reveal_action.get_global_rect().end.y<=root.size.y,"portrait result retains its Continue action")
 page._finish_summon_reveal()
 var odyssey: Node=root.get_node("OdysseyClient");odyssey.set_process(false)
 var now: int=int(Time.get_unix_time_from_system())
 var offers: Array=[]
 for id: String in root.get_node("PavilionManager").get_iap_product_catalog():
  if id=="heavenly_trials_support_550":continue
  var product: Dictionary=root.get_node("PavilionManager").get_iap_product_catalog()[id]
  if str(product.get("type",""))=="consumable":offers.append({"product_id":id,"jade":int(product.get("celestial_jade",0)),"dice":[1,3,5,8,12,16][offers.size()],"claimed":false})
 odyssey.snapshot={"event":{"id":"qa-polish","enabled":true,"ads_enabled":true,"purchases_enabled":true,"starts_at":now-100,"ends_at":now+86400},"state":{"tickets":3,"rolls":6,"daily_rolls":1,"position":2,"day":Time.get_date_string_from_system(),"missions":[],"task_claims":[],"milestones":[],"last_die":0,"daily_ads":0},"revision":1,"server_time":now,"purchase_bonus":{"active":true,"offers":offers}}
 odyssey._received_msec=Time.get_ticks_msec();odyssey.status="connected";odyssey.busy=false
 change_scene_to_file("res://scenes/ui/odyssey_screen.tscn");await settle(16)
 var board_page: Control=current_scene;board_page._shop();await settle(20)
 var veil: ColorRect=board_page.modal.get_node("JadeModalScrim")
 check(veil.color.a<=.12,"Odyssey popup uses the same light backdrop instead of a black veil")
 check(board_page._modal_panel.get_global_rect().end.x<=root.size.x and board_page._modal_panel.get_global_rect().end.y<=root.size.y,"actual Travel Shop popup stays within the phone viewport")
 await capture("odyssey-shop")
 change_scene_to_file("res://scenes/ui/achievement_screen.tscn");await settle(20)
 var presenter: Node=current_scene.get_node("TrialsProductionPresenter")
 check(presenter.active_section=="achievement" and presenter.footer.visible and presenter.claim_all_button.is_visible_in_tree(),"achievement Claim All is visible in the actual production presenter")
 var achievements: Node=root.get_node("AchievementManager")
 for id: String in ["first_blood","enemy_slayer_50"]:
  if id not in achievements.unlocked_achievement_ids:achievements.unlocked_achievement_ids.append(id)
  achievements.claimed_achievement_ids.erase(id)
 presenter._refresh();await settle()
 check(not presenter.claim_all_button.disabled,"claim-all availability follows real claimable achievements")
 var before: int=root.get_node("ProgressionManager").spirit_stone
 presenter._on_claim_all_pressed();await settle(20)
 check(achievements.is_claimed("first_blood") and achievements.is_claimed("enemy_slayer_50"),"one action claims both achievements through the authority")
 var after: int=root.get_node("ProgressionManager").spirit_stone
 presenter._on_claim_all_pressed();await settle()
 check(after>before and root.get_node("ProgressionManager").spirit_stone==after,"repeat Claim All cannot duplicate grants")
 await capture("achievement-claim-all")
 var audio: Node=root.get_node("AudioManager")
 var music_ok: bool=audio.MUSIC.size()==4 and audio.MUSIC.home==audio.MUSIC.pavilion and audio.MUSIC.journey==audio.MUSIC.boss
 music_ok=music_ok and audio.MUSIC.home.resource_path.ends_with("chinese_music/lotus_pond_loop.ogg") and audio.MUSIC.journey.resource_path.ends_with("chinese_music/dragon_dance_loop.ogg")
 for cue: String in ["ui","sword","chain","fire","thunder","claim","upgrade","victory","defeat","summon_rare","summon_epic","summon_legendary_reveal"]:
  music_ok=music_ok and audio.SFX.has(cue) and not audio.SFX[cue].is_empty()
 check(music_ok,"approved Chinese music aliases and complete gameplay cue families remain available")
 var cursor_before: Dictionary=audio.variation_cursor.duplicate(true)
 for source: String in ["jade_binding_chain","void_piercer_spear","phoenix_war_fan","heavenweaver_compass"]:
  audio.play_weapon_impact(source)
 check(audio.variation_cursor==cursor_before and not audio.SFX.has("impact_compass") and audio.SFX.sword[0].resource_path.contains("presentation_v2"),"restored weapon palette stays active without extra per-hit layers")
 check("BiteMe Games" in audio.CREDITS and "CC0" in audio.CREDITS and "https://bitemegames.itch.io/chinese-game-music" in audio.CREDITS,"shipped credits identify the active music creator and license")
 current_scene.queue_free();current_scene=null;await settle()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("RELEASE_POLISH checks=",checks," failures=",failures," renderer=",DisplayServer.get_name())
 quit(1 if failures else 0)
