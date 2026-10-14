extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(count: int=4) -> void:
 for index: int in range(count): await process_frame
func shot(path: String) -> void:
 root.get_texture().get_image().save_png(path)
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_reward_refine_render_qa"):quit(2);return
 await frames(10)
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 var eq: Node=root.get_node("EquipmentManager");eq.active_run_loadout_snapshot.clear()
 var inv: Node=root.get_node("InventoryManager");inv.item_counts={"nine_heavens_star_sword":2,"sovereign_mantle":2,"tribulation_bracer":1,"cloudtreader_boots":1,"ascendant_heart":1,"jade_binding_chain":1}
 root.get_node("ProgressionManager").spirit_stone=3600
 for slot: String in ["nine_heavens_star_sword","sovereign_mantle","tribulation_bracer","cloudtreader_boots","ascendant_heart"]:eq.equip_item(slot)
 var prewarm: Node=root.get_node_or_null("MenuResourcePrewarm")
 if prewarm!=null:prewarm.queue_free()
 await frames(2)
 var guide: Node=root.get_node("RefineOnboarding");guide.completed=true;guide.set_process(false)
 var journey: Node=root.get_node("JourneyManager");journey.cleared_stage_keys=[journey.get_stage_key(1,1)]
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn");await frames(8)
 var dir: String="/tmp/jade-qa/reward-refine-render";DirAccess.make_dir_recursive_absolute(dir)
 await RenderingServer.frame_post_draw
 shot(dir+"/hero.png")
 var flight: Node=root.get_node("RewardDeliveryPresenter")
 var claim: Node=root.get_node("RewardClaimResultPresenter")
 flight._play_delivery_now("spirit_stone",240,flight.SPIRIT_STONE_ICON,Vector2(330,720),false,1)
 flight._play_delivery_now("inventory_item",1,load("res://assets/ui/equipment/imperial_v3/icons/sovereign_mantle.png"),Vector2(310,630),false,1)
 for index: int in range(36):
  if index==17: claim._build_result_popup(current_scene,"MAIL · JADE SANCTUARY",{"spirit_stone":240,"celestial_jade":60,"items":{"sovereign_mantle":1}},1)
  await RenderingServer.frame_post_draw
  shot(dir+"/%03d.png"%index)
 if is_instance_valid(claim._panel):
  await RenderingServer.frame_post_draw
  shot(dir+"/reward.png")
 claim._close_popup();await frames(4)
 guide.completed=false;guide.step=1;guide._show_guide(current_scene);await frames(8)
 await RenderingServer.frame_post_draw
 shot(dir+"/guide.png")
 guide.completed=true;guide._dismiss(true);await frames(4)
 root.get_node("AudioManager").release_runtime_audio()
 current_scene.queue_free();await frames(8)
 print("REWARD_REFINE_NATIVE_RENDER=PASS; 36 frames + Hero/reward/tutorial");quit(0)
