extends SceneTree
var checks: int=0
var failures: int=0
var native: bool=false
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("LIN_LIBRARY_FAIL "+label)
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for i: int in range(4):await process_frame
func shot(name: String) -> void:
	if not native:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/jade-qa/"+name+".png")
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_lin_library_qa"):quit(2);return
	await process_frame
	native=DisplayServer.get_name()!="headless";root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
	var eq: Node=root.get_node("EquipmentManager");var inv: Node=root.get_node("InventoryManager")
	var active_ids: Array[String]=eq.get_item_ids()
	check(active_ids.size()>=56 and "astral_resonance_bell" not in active_ids,"current active catalog preserves released entries and excludes Bell")
	inv.item_counts["astral_resonance_bell"]=3;eq.ascension_stars["astral_resonance_bell"]=4;eq.weapon_levels["astral_resonance_bell"]=22;eq.equipped_item_ids.armament="astral_resonance_bell"
	var legacy: Dictionary=eq.build_active_run_loadout_snapshot()
	eq._validate_loaded_state();inv._validate_loaded_state()
	check(eq._normalize_active_run_loadout_snapshot(legacy).get("equipped_item_ids",{}).get("armament","")=="astral_resonance_bell","legacy active snapshot remains resumable")
	check(eq.get_loadout_equipped_item_id("armament")=="","retired next-run slot cleared")
	check(inv.get_item_count("astral_resonance_bell")==3 and eq.ascension_stars["astral_resonance_bell"]==4 and eq.weapon_levels["astral_resonance_bell"]==22,"legacy count/star/level retained")
	check("astral_resonance_bell" not in inv.get_owned_item_ids(),"retired hidden from backpack")
	check(not eq.equip_item("astral_resonance_bell") and not eq.can_ascend_item("astral_resonance_bell") and not eq.can_level_weapon("astral_resonance_bell"),"retired cannot equip or consume upgrades")
	check(not root.get_node("PavilionManager").is_item_unlocked("astral_resonance_bell"),"retired cannot acquire")
	inv.item_counts["void_piercer_spear"]=1
	var before: Dictionary=inv.item_counts.duplicate(true)
	check(change_scene_to_file("res://scenes/ui/skill_book_screen.tscn")==OK,"Library entry loads");await settle()
	var book: Control=current_scene
	for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(896,504)]:
		root.size=dims;await settle();book._set_mode("EQUIPMENT");await settle()
		var grid: GridContainer=book._list.get_node("LibraryEquipmentGrid")
		check(grid.columns==5 and grid.get_child_count()==active_ids.size(),"five columns complete "+str(dims))
		var rendered_ids: Array[String]=[]
		for tile: Node in grid.get_children():rendered_ids.append(str(tile.name).trim_prefix("Relic_"))
		rendered_ids.sort();var expected_ids: Array[String]=active_ids.duplicate();expected_ids.sort()
		check(rendered_ids==expected_ids,"each active catalog item rendered exactly once "+str(dims))
		check(grid.get_global_rect().end.x<=book.size.x+1,"grid fits "+str(dims))
		book._open_equipment_detail("frost_lotus_robe");await settle()
		var panel: Control=book._popup.get_node("LibraryDetailPanel")
		check(panel.size.x<=book.size.x-20 and panel.size.y<=book.size.y*.72,"compact popup "+str(dims))
		check(book._popup.find_child("LibraryDescriptionScroll",true,false)!=null,"scroll detail "+str(dims))
		book._close_popup()
	root.size=Vector2i(648,1152);await settle();book._select_equipment("void_piercer_spear");await shot("library-equipment")
	book._set_filter("SETS");await settle();check(book._list.get_child_count()==11,"eleven four-piece sets");await shot("library-sets")
	book._set_mode("SKILLS");await settle();check(book._list.get_child_count()==18,"18 skills retained");await shot("library-skills")
	book._search.text="heavenly_tribulation";book._refresh();await settle();check(book._list.get_child_count()==1,"search")
	book._search.text="";book._set_filter("SYNERGIES");await settle();check(book._list.get_child_count()==3,"resonance coverage")
	book._open_skill_detail("sword_dao_resonance");await settle();check(book._popup.get_node("LibraryDetailPanel").size.y<=book.size.y*.72,"resonance popup bounded");book._close_popup()
	check(inv.item_counts==before,"encyclopedia is read-only")
	check(change_scene_to_file("res://scenes/levels/level_1.tscn")==OK,"production combat loads");await create_timer(.4).timeout
	current_scene.get_node("EnemySpawner").process_mode=Node.PROCESS_MODE_DISABLED;current_scene.get_node("WaveManager").process_mode=Node.PROCESS_MODE_DISABLED
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
	var player: Node2D=current_scene.get_node("player_1");player.set_physics_process(false);player.get_node("WeaponManager").set_process(false)
	var sprite: AnimatedSprite2D=player.get_node("AnimatedSprite2D");var body: Node=player.get_node("PremiumBodyPresentation");body.set_process(false)
	var collider: Transform2D=player.get_node("CollisionShape2D").transform
	for animation: StringName in sprite.sprite_frames.get_animation_names():
		check(sprite.sprite_frames.get_frame_count(animation)>0,"poses "+animation)
		for i: int in range(sprite.sprite_frames.get_frame_count(animation)):
			var im: Image=sprite.sprite_frames.get_frame_texture(animation,i).get_image();var used: Rect2i=im.get_used_rect()
			check(used.position.x>=8 and used.position.y>=8 and used.end.x<=88 and used.end.y<=88,"safe gutter "+animation+"/"+str(i))
	var drive: RefCounted=player.locomotion;drive.phase=0;drive.advance(.1,"right",14)
	check(sprite.animation=="walk_right" and sprite.frame==1,"distance chooses pose")
	drive.advance(.1,"up",.01);check(sprite.animation=="idle_up","blocked input idle")
	drive.advance(.1,"left",14);check(sprite.frame==2,"turn keeps phase")
	drive.react_to_hit();drive.advance(.05,"left",0);check(sprite.animation=="hurt_left","authored hit")
	drive.advance(.3,"left",0);check(sprite.animation=="idle_left","recover idle")
	# Real move_and_slide collision, with held input; boots must stop at a wall.
	var wall:=StaticBody2D.new();var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(20,500);shape.shape=rect;wall.add_child(shape);wall.collision_layer=2;current_scene.add_child(wall);wall.global_position=player.global_position+Vector2(70,0)
	var start: Vector2=player.global_position;player.set_physics_process(true);Input.action_press("right");await create_timer(.65).timeout
	var stop: Vector2=player.global_position;await create_timer(.2).timeout
	check(stop.distance_to(start)>1,"actual movement before wall")
	check(player.global_position.distance_to(stop)<.1 and sprite.animation.begins_with("idle_"),"held input at wall cannot walk in place")
	Input.action_release("right");player.set_physics_process(false);wall.free()
	for facing: String in ["down","right","up","left"]:
		player.facing_direction=facing;drive.phase=0
		for frame: int in range(8):
			drive.advance(.1,facing,14);player.velocity=Vector2(180,0);body._process(.1)
			check(sprite.scale==body.base_scale and sprite.position==body.base_position and is_zero_approx(sprite.rotation),"stable body "+facing+str(frame))
			check(float(sprite.material.get_shader_parameter("stride_strength"))==0,"no competing warp")
			await shot("lin-walk-"+facing+"-"+str(frame))
	check(player.get_node("CollisionShape2D").transform==collider,"collider unchanged")
	check(body.get_child_count()==0,"no walk ghost nodes")
	await shot("lin-yue-combat")
	player.get_node("PlayerHealth").die();await settle();check(current_scene.has_node("LinYueDefeatPose"),"authored defeat")
	await create_timer(1.2,true).timeout;check(not current_scene.has_node("LinYueDefeatPose"),"bounded defeat lifetime")
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	current_scene.queue_free();current_scene=null;await settle()
	print("LIN_LIBRARY_QA checks=%d failures=%d native=%s"%[checks,failures,native]);quit(0 if failures==0 else 1)
