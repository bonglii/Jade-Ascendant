extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool, tag: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error("REWARD_REFINE_FAIL "+tag)
func frames(count: int=4) -> void:
 for i: int in range(count): await process_frame
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_reward_refine_qa"): quit(2);return
 await create_timer(.5).timeout
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 var inv: Node=root.get_node("InventoryManager")
 var eq: Node=root.get_node("EquipmentManager")
 var progress: Node=root.get_node("ProgressionManager")
 var rewards: Node=root.get_node("RewardManager")
 var journey: Node=root.get_node("JourneyManager")
 var guide: Node=root.get_node("RefineOnboarding");guide.completed=true;guide.set_process(false)
 var legacy: Dictionary={"spirit_stone":100,"items":{"refinement_shard":3,"wanderer_jade_jian":1}}
 var normalized: Dictionary=rewards.retire_fragments(legacy)
 check(normalized.spirit_stone==160 and not normalized.items.has("refinement_shard"),"legacy preview converts exactly")
 check(legacy.items.refinement_shard==3 and legacy.spirit_stone==100,"immutable original payload")
 check(rewards.retire_fragments(normalized)==normalized,"payload normalization idempotent")
 inv.item_counts={"refinement_shard":7};progress.spirit_stone=100
 var save: Node=root.get_node("SaveManager")
 save.begin_save_write_barrier("reward_qa","Migration failure fixture")
 check(not inv.migrate_legacy_fragments() and inv.get_item_count("refinement_shard")==7 and progress.spirit_stone==100,"failed migration preserves both balances")
 save.end_save_write_barrier("reward_qa")
 check(inv.migrate_legacy_fragments(),"atomic balance migration succeeds")
 check(progress.spirit_stone==240 and inv.get_item_count("refinement_shard")==0,"correct conversion and archived balance removed")
 check(inv.migrate_legacy_fragments() and progress.spirit_stone==240,"migration retry cannot mint twice")
 var migrated: Dictionary=root.get_node("SaveManager").read_save_data("inventory").get("data",{})
 check(not migrated.get("item_counts",{}).has("refinement_shard"),"committed inventory removes retired material")
 var before: int=progress.spirit_stone
 var granted: Dictionary=rewards.grant_reward(rewards.SOURCE_PAVILION,"legacy_fixture",legacy)
 check(granted.success and progress.spirit_stone==before+160,"historical grant credits replacement")
 check(inv.get_item_count("refinement_shard")==0 and inv.get_item_count("wanderer_jade_jian")==1,"legacy mail does not mint material")
 check(granted.applied_reward_data.spirit_stone==160,"popup reflects committed replacement")
 eq.active_run_loadout_snapshot.clear();eq.ascension_stars.clear();eq.weapon_levels.clear()
 inv.item_counts={"wanderer_jade_jian":2,"bamboo_weave_robe":2,"moonthread_robe":1};progress.spirit_stone=0
 journey.cleared_stage_keys=[journey.get_stage_key(1,1)]
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn");await create_timer(.15).timeout
 var hero: Control=current_scene
 check(hero.find_child("JadeOnboardingOverlay",true,false)==null,"refine guide supersedes old generic Hero overlay")
 await frames()
 var dot: Panel=hero.card_buttons.wanderer_jade_jian.get_node_or_null("RefineReadyDot")
 check(dot!=null and dot.visible,"identical duplicate shows top-right red dot")
 check(dot.mouse_filter==Control.MOUSE_FILTER_IGNORE and dot.anchor_left==1.0,"dot is passive and anchored correctly")
 check(hero.card_buttons.moonthread_robe.get_node_or_null("RefineReadyDot")==null,"unready armor has no dot")
 check(eq.ascend_item("bamboo_weave_robe"),"actual armor ascension")
 await frames()
 check(not hero.card_buttons.bamboo_weave_robe.get_node("RefineReadyDot").visible,"consumed last duplicate hides dot without rebuilding")
 progress.spirit_stone=40;hero._refresh_loadout();await frames()
 check(hero.card_buttons.wanderer_jade_jian.get_node("RefineReadyDot").visible,"affordable weapon level remains eligible")
 inv.item_counts.wanderer_jade_jian=1;eq.ascension_stars.wanderer_jade_jian=5;eq.weapon_levels.wanderer_jade_jian=50
 hero._refresh_loadout();await frames()
 check(not hero.card_buttons.wanderer_jade_jian.get_node("RefineReadyDot").visible,"max stars and levels hides dot")
 var bar: Node=current_scene.find_child("SharedHubResourceBar",true,false)
 check(bar.get_node("ResourceRow").get_child_count()==3,"three active currencies in shared wallet")
 var delivery: Node=root.get_node("RewardDeliveryPresenter")
 check(delivery._wallet_cell("celestial_jade")==bar.get_node("ResourceRow").get_child(1),"flight destination matches removed wallet index")
 var panel: Node=root.get_node("RewardClaimResultPresenter")
 for viewport: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(896,504)]:
  root.size=viewport;await frames()
  panel._build_result_popup(current_scene,"MAIL",legacy,1);await frames(8)
  var rect: Rect2=panel._panel.get_global_rect()
  check(rect.position.x>=0 and rect.end.x<=viewport.x+1,"reward popup width fits "+str(viewport))
  check(rect.position.y>=0 and rect.end.y<=viewport.y+1,"reward popup fits "+str(viewport))
  check(rect.size.y<=viewport.y*.73,"compact reward popup "+str(viewport))
  check(panel._scroll.clip_contents,"reward overflow clips safely "+str(viewport))
  panel._close_popup();await frames()
 # Long reward names never stretch the modal past the screen; scroll real content.
 var many: Dictionary={"items":{}}
 for id: String in eq.get_item_ids():many.items[id]=1
 panel._build_result_popup(current_scene,"BATCH",many,5);await frames(8)
 check(panel._scroll.vertical_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED,"long claim activates vertical scroll")
 panel._scroll.scroll_vertical=10000;await frames()
 check(panel._scroll.scroll_vertical>0,"long reward actually scrolls")
 panel._fit_popup_to_content();panel._close_popup();await frames()
 check(panel._popup==null,"closing during deferred layout is safe")
 root.size=Vector2i(648,1152);await frames()
 guide.completed=false;journey.cleared_stage_keys=[]
 check(not guide.should_offer(hero),"guide locked before stage 1-1")
 journey.cleared_stage_keys=[journey.get_stage_key(1,1)]
 check(guide.should_offer(hero),"guide available after stage 1-1")
 hero._show_detail("wanderer_jade_jian");await frames()
 check(not guide.should_offer(hero),"guide waits for equipment popup")
 hero._close_detail();await frames();guide.step=1;guide._show_guide(hero);await frames(8)
 check(hero.find_child("RefineGuideCard",true,false)!=null,"guide uses actual HERO scene")
 var old_guide_id: int=guide.popup.get_instance_id()
 guide._continue(1,old_guide_id);guide._continue(1,old_guide_id);await frames(8)
 check(guide.step==2,"guide reaches weapon level step")
 guide._finish();await frames()
 check(guide.completed,"guide completion persisted")
 var config:=ConfigFile.new();check(config.load(guide.SAVE_PATH)==OK and config.get_value("refine","completed",false),"guide does not repeat next launch")
 guide.completed=true
 var pavilion: Node=root.get_node("PavilionManager")
 for chapter: int in range(1,6):
  for stage: int in journey.get_stage_ids(chapter):
   journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
 journey.clear_active_run(false);eq.active_run_loadout_snapshot.clear()
 progress.spirit_stone=100000
 var forge_cost: int=pavilion.get_equipment_forge_cost("sovereign_mantle")
 var forged: bool=pavilion.acquire_equipment("sovereign_mantle",true)
 check(forged and progress.spirit_stone==100000-forge_cost,"real forging charges replacement Stones once")
 check(inv.get_item_count("sovereign_mantle")==1 and inv.get_item_count("refinement_shard")==0,"forge does not recreate material")
 check(pavilion.get_cosmetic_cost("astral_aura").spirit_stone==3300,"aura replacement cost includes old 40 fragments")
 pavilion.state.owned_cosmetics=["plain"]
 var aura_before: int=progress.spirit_stone
 check(pavilion.acquire_cosmetic("astral_aura") and progress.spirit_stone==aura_before-3300,"real aura purchase charges Stones atomically")
 await frames(8)
 # Pending cosmetic flights cannot appear in a different scene after their timer.
 var cosmetic_before: int=delivery._overlay.get_child_count()
 delivery._play_delivery_in_scene(-1,"spirit_stone",100,null,Vector2.ZERO,false,1)
 check(delivery._overlay.get_child_count()==cosmetic_before,"old scene claim timer ignored")
 root.get_node("PavilionManager").summon_delivery_active=true
 delivery._on_item_added("nine_heavens_star_sword",1,1)
 check(delivery._overlay.get_child_count()==cosmetic_before,"gacha item cannot leak before reveal")
 root.get_node("PavilionManager").summon_delivery_active=false
 guide.set_process(false)
 root.get_node("AudioManager").release_runtime_audio()
 current_scene.queue_free();await frames(8)
 print("REWARD_REFINE_SMOKE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
