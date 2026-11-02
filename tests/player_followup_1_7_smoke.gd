extends SceneTree
const Guidance = preload("res://scripts/data/skill_build_guidance.gd")
var checks: int = 0
var failures: int = 0
var evidence: Array[Dictionary] = []
func check(ok: bool, caption: String) -> void:
 checks += 1
 evidence.append({"check":caption,"pass":ok})
 if not ok: failures += 1; push_error("PLAYER_FOLLOWUP " + caption)
func frames(count: int = 6) -> void:
 for i: int in count: await process_frame
func _initialize() -> void: run.call_deferred()
func dismiss_scene() -> void:
 paused = false
 if current_scene != null: current_scene.queue_free(); current_scene = null
 await frames(10)
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_player_followup_qa"): quit(2); return
 create_timer(90).timeout.connect(func(): push_error("PLAYER_FOLLOWUP_TIMEOUT"); quit(1))
 await frames()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.size = Vector2i(320,568)
 # Match the actual launch order: Home initializes before a Journey run.
 # The synthetic direct-to-combat cold threaded Home load leaked engine
 # RefCounted placeholders at exit; do not hide that warning in the runner.
 change_scene_to_file("res://scenes/ui/main_menu.tscn"); await frames(25)
 check(current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn", "fixture follows production Home-before-combat launch order")
 await dismiss_scene()
 var journey: Node = root.get_node("JourneyManager")
 var live: Node = root.get_node("LiveOpsManager")
 var achievements: Node = root.get_node("AchievementManager")
 var inventory: Node = root.get_node("InventoryManager")
 var equipment: Node = root.get_node("EquipmentManager")
 var progress: Node = root.get_node("ProgressionManager")
 var settings: Node = root.get_node("SettingsManager")
 var saver: Node = root.get_node("SaveManager")
 for guide: Node in root.find_children("RefineOnboarding", "", true, false): guide.set_process(false)
 var legacy_count: int = 0
 for chapter: int in journey.get_chapter_ids(): legacy_count += journey.get_stage_ids(chapter).size()
 check(legacy_count == 26 and journey.get_stage_ids(1).has(6), "canonical legacy stage remains readable")
 check(journey.get_active_stage_count() == 25 and journey.get_active_stage_ids(1) == [1,2,3,4,5], "all current surfaces share 25 active stages")
 check(not achievements.get_achievement_ids().has("stage_1_6_clear"), "fresh achievements omit unreachable legacy objective")
 journey.cleared_stage_keys = ["1-1","1-2","1-3","1-4","1-5"]
 check(journey.get_active_chapter_progress(1).cleared_stages == 5 and journey.get_active_chapter_progress(1).total_stages == 5, "first active realm reaches five of five")
 check(live.is_treasure_hunt_cache_unlocked("verdant_realm_cache"), "first realm cache no longer requires hidden sixth stage")
 achievements._sync_journey_achievement_progress()
 check(achievements.is_claimable("verdant_heaven_ascendant") and achievements.get_target("verdant_heaven_ascendant") == 5, "five active clears unlock existing realm achievement")
 journey.cleared_stage_keys.append("1-6")
 achievements._sync_journey_achievement_progress()
 check(achievements.get_achievement_ids().has("stage_1_6_clear") and achievements.is_claimable("stage_1_6_clear"), "earned legacy objective remains visible and claimable")
 var legacy_save: Dictionary = journey.build_save_data()
 check(legacy_save.cleared_stage_keys.has("1-6"), "save serialization retains legacy clear")
 journey.cleared_stage_keys.clear()
 for chapter: int in journey.get_chapter_ids():
  for stage: int in journey.get_active_stage_ids(chapter): journey.cleared_stage_keys.append(journey.get_stage_key(chapter, stage))
 check(live.get_heavenly_ladder_total_stage_count() == 25 and live.get_heavenly_ladder_cleared_stage_count() == 25, "ladder reaches the active campaign cap")
 check(int(live.get_heavenly_ladder_milestone("ascendant_summit").required_clears) == 25, "summit requirement is achievable without legacy trial")
 journey.cleared_stage_keys.append("1-6")
 check(live.get_heavenly_ladder_cleared_stage_count() == 25 and journey.cleared_stage_keys.has("1-6"), "legacy credit is retained without 26 of 25 display")
 journey.cleared_stage_keys = ["1-1"]
 inventory.item_counts.clear()
 equipment.active_run_loadout_snapshot.clear()
 journey.active_run_chapter_id = 0; journey.active_run_stage_id = 0
 var guide: Node = load("res://scripts/ui/refine_onboarding.gd").new(); root.add_child(guide); guide.set_process(false); guide.empty_mode = true
 progress.spirit_stone = 0
 settings.set_presentation("language", "en")
 var empty_copy: Dictionary = guide.guide_copy()
 check(empty_copy.button == "CONTINUE JOURNEY" and not str(empty_copy.body).contains("red dot"), "empty unaffordable backpack gets a real Journey action")
 progress.spirit_stone = 500
 check(guide.guide_copy().button == "OPEN CULTIVATION", "empty backpack advertises only affordable cultivation")
 settings.set_presentation("language", "id")
 check(guide.guide_copy().button == "BUKA CULTIVATION", "empty inventory follow-up respects Indonesian preference")
 settings.set_presentation("language", "en")
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn"); await frames(25)
 check(guide.should_offer(current_scene), "first-win empty inventory may receive the contextual guide")
 guide._show_guide(current_scene); await frames(12)
 var card: Control = guide.popup.get_node("RefineGuideCard")
 check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(card.get_global_rect()), "guide bounds fit narrow 320 by 568 viewport")
 var native_scroll: ScrollContainer = guide.popup.find_child("GuideScroll",true,false)
 check(native_scroll.has_meta("jade_shared_scroll") and native_scroll.scroll_deadzone == 6, "guide uses production touch-scroll policy")
 guide._finish(); await frames()
 check(guide.empty_explained and not guide.completed and not guide.should_offer(current_scene), "empty explanation is one-time without consuming later equipment tutorial")
 var item_id: String = "nine_heavens_star_sword"
 inventory.item_counts[item_id] = 1
 check(guide.should_offer(current_scene), "first actual equipment re-enables the equipment-specific tutorial")
 guide.empty_mode = false; guide.step = 1
 check(str(guide.guide_copy().body).contains("identical duplicate"), "owned-equipment tutorial explains exact duplicate requirement")
 guide._finish(); await frames()
 check(guide.completed, "equipment tutorial retains completion mark")
 var owned_before: Dictionary = inventory.item_counts.duplicate(true)
 var balance_before: int = progress.spirit_stone
 await dismiss_scene()
 for language: String in ["en","id"]:
  settings.set_presentation("language",language)
  change_scene_to_file("res://scenes/ui/equipment_screen.tscn"); await frames(25)
  var hero: Control = current_scene
  check(hero.header_count.text.begins_with("COLLECTION" if language == "en" else "KOLEKSI"), "formatted HERO collection counter language " + language)
  hero._show_detail(item_id); await frames(15)
  var equip: Button = hero.sheet_actions.find_child("EquipAction",true,false)
  check(equip.text == ("EQUIP" if language == "en" else "PASANG"), "HERO action follows locale " + language)
  var level: Button = hero.sheet_actions.find_child("LevelAction",true,false)
  check(level.text.begins_with("LEVEL UP" if language == "en" else "NAIK LEVEL"), "formatted permanent weapon price follows locale " + language)
  check(hero.tr("SAVED TO YOUR PROGRESS") == ("SAVED TO YOUR PROGRESS" if language == "en" else "TERSIMPAN DI PROGRES"), "reward receipt heading follows locale " + language)
  hero._close_detail(); await frames()
  await dismiss_scene()
 check(inventory.item_counts == owned_before and progress.spirit_stone == balance_before, "viewing guides and both locales never grants or spends")
 guide.queue_free(); inventory.item_counts.clear(); settings.set_presentation("language","en")
 var levels: Dictionary = {"spirit_sword":2,"sword_intent":1}
 var snapshot: Dictionary = levels.duplicate(true)
 var hint: String = Guidance.hint("spirit_sword",levels)
 check(hint.contains("Primary 2/3") and hint.contains("Intent 1/2"), "build hint reads exact production resonance requirements")
 check(Guidance.hint("spirit_sword",{},"jade_binding_chain").begins_with("CONTROL"), "main-weapon guidance respects equipped Chain role")
 check(Guidance.hint("spirit_sword",{},"celestial_returning_glaive").begins_with("RETURN PATH"), "main-weapon guidance respects Glaive return role")
 check(Guidance.hint("qi_shield",{"yin_yang_blades":3},"",true).begins_with("SINERGI"), "owned Blades make the Shield hint contextual and bilingual")
 check(levels == snapshot, "build advice leaves its read-only inputs unchanged")
 check(not Guidance.hint("spirit_sword",{"spirit_sword":7,"sword_intent":5,"sword_dao_resonance":1}).begins_with("SYNERGY"), "already acquired resonance does not advertise its prerequisites again")
 check(not Guidance.hint("spirit_sword",{"spirit_sword":7,"sword_intent":2}).contains("7/3"), "completed prerequisites never display above their target")
 root.get_node("GameSession").start_new_game(); journey.begin_selected_stage()
 change_scene_to_file("res://scenes/levels/level_1.tscn"); await frames(25)
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed(); paused = false
 current_scene.get_node("EnemySpawner").set_process(false); current_scene.get_node("EnemySpawner").clear_normal_enemies()
 current_scene.get_node("WaveManager").set_process(false)
 var actor: Node = current_scene.get_node("player_1"); actor.set_physics_process(false); actor.get_node("WeaponManager").set_process(false)
 var health: Node = actor.get_node("PlayerHealth")
 var panel: Control = current_scene.get_node("HUD").level_up_panel
 var checkpoint: Node = current_scene.get_node("CheckPointManager")
 health.take_damage(20); actor.add_experience(10)
 var random_before: int = panel._choice_rng.state
 var options: Array = panel.current_upgrades.duplicate()
 for i: int in 3: panel.get_build_guidance(options[0])
 check(panel._choice_rng.state == random_before and panel.current_upgrades == options, "contextual cards do not roll RNG or replace choices")
 actor.add_experience(26)
 check(actor.get_pending_level_up_count() == 2 and panel.find_child("Subtitle",true,false).text.contains("3 choices"), "queue counter refreshes on surplus EXP without another heal or choice")
 panel.close_level_up()
 check(paused and not panel.visible, "combat stays paused between queued panels")
 await frames(3)
 check(panel.visible and panel.continuing_queue and actor.level == 3 and actor.experience == 14, "queued choice resolves once and skips long intro")
 check(panel.find_child("Subtitle",true,false).text.contains("2 choices"), "queue count decreases after each completed choice")
 panel.close_level_up(); await frames(3)
 check(panel.visible and actor.level == 4 and actor.experience == 0, "second queued choice preserves original EXP thresholds")
 panel.close_level_up(); await frames(3)
 check(not paused and not panel.visible, "combat resumes after final choice")
 actor.add_experience(actor.experience_to_next_level)
 panel.current_upgrades.assign(["power"]); panel.update_buttons()
 var power_before: int = actor.get_node("PlayerStats").power_level
 panel._on_upgrade_button_pressed(0); panel._on_upgrade_button_pressed(0)
 await create_timer(.2,true).timeout
 check(actor.get_node("PlayerStats").power_level == power_before + 1 and not panel.visible, "rapid repeated presses apply exactly one actual upgrade")
 actor.add_experience(actor.experience_to_next_level)
 panel.current_upgrades.assign(["power"]); panel.update_buttons()
 panel._on_upgrade_button_pressed(0)
 panel.close_level_up()
 actor.add_experience(actor.experience_to_next_level)
 panel.current_upgrades.assign(["power"]); panel.update_buttons()
 await create_timer(.2,true).timeout
 check(actor.get_node("PlayerStats").power_level == power_before + 1 and panel.visible, "old selection tween cannot apply into a later identical choice")
 var saved_choices: Array = panel.current_upgrades.duplicate()
 var counts_before: Dictionary = root.get_node("MonetizationManager").placement_counts.duplicate(true)
 panel._m7d_request_grant_id = "stale-fixture-grant"
 panel._m7d_request_run_id = journey.m7d_run_id
 panel._m7d_request_generation = panel._choice_generation - 1
 panel._m7d_original_choices.assign(saved_choices)
 panel._m7d_future_choices.assign(["movement_speed"])
 panel.selection_locked = true
 panel._m7d_on_sdk_reward("dao_choice_reroll", "stale-fixture-grant")
 check(panel.current_upgrades == saved_choices and root.get_node("MonetizationManager").placement_counts == counts_before, "stale rewarded callback cannot replace a later panel or consume its quota")
 panel.close_level_up(); await frames(3)
 check(checkpoint.save_checkpoint(), "unfinished run still saves normally")
 check(checkpoint.load_checkpoint(), "unfinished run Continue payload still restores normally")
 health.current_health = health.max_health - 9
 var level_before_victory: int = actor.level
 current_scene.get_node("EnemySpawner").spawn_boss(); await frames(1)
 var bosses: Array[Node] = get_nodes_in_group("boss")
 check(not bosses.is_empty(), "terminal regression uses the real spawned boss reward identity")
 if not bosses.is_empty(): bosses[0].take_damage(1000000)
 await frames(4)
 check(checkpoint.is_victory_complete() and not journey.has_active_run(), "production victory finalizes active Journey")
 check(not saver.has_save_file("checkpoint"), "victory removes primary checkpoint and backup")
 check(not checkpoint.save_checkpoint() and not checkpoint._write_checkpoint_data({"ended":false}), "both late checkpoint writer entry points reject finished runs")
 actor.add_experience(999)
 check(actor.level == level_before_victory and health.current_health == health.max_health - 9 and not panel.visible, "late EXP after victory cannot heal or reopen choices")
 current_scene.get_node("HUD")._on_resume_pressed()
 check(paused, "stale pause Resume cannot resume a completed fight")
 var stone_after_win: int = progress.spirit_stone
 current_scene.get_node("VictoryManager")._on_boss_defeated()
 check(progress.spirit_stone == stone_after_win, "duplicate victory signal cannot grant again")
 current_scene.get_node("HUD")._on_pause_main_menu_pressed()
 await create_timer(2).timeout
 check(current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn" and not current_scene._has_checkpoint(), "stale pause Home exits through victory without resurfacing Continue")
 var output: String = OS.get_environment("JADE_FOLLOWUP_EVIDENCE")
 if not output.is_empty():
  var file := FileAccess.open(output,FileAccess.WRITE)
  if file != null: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"\t"))
 await dismiss_scene()
 await create_timer(.7,true).timeout
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("PLAYER_FOLLOWUP checks=%d failures=%d" % [checks,failures])
 quit(0 if failures == 0 else 1)
