extends SceneTree
const Art = preload("res://scripts/player/legendary_set_art.gd")
const Catalog = preload("res://scripts/data/equipment_set_catalog.gd")
const Ledger = preload("res://scripts/weapon/run_combat_ledger.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LEGENDARY_VFX_FAIL " + label)
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i: int in range(3): await process_frame
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_legendary_qa"): quit(2); return
	await process_frame
	var eq: Node = root.get_node("EquipmentManager")
	var save: Node = root.get_node("SaveManager")
	var inventory_before: Dictionary = root.get_node("InventoryManager").item_counts.duplicate(true)
	var stars_before: Dictionary = eq.ascension_stars.duplicate(true)
	for id: String in Catalog.SET_ORDER:
		check(Art.qualifies(id,4) == (Catalog.get_set_rarity(id)=="legendary"), "Legendary only " + id)
		check(not Art.qualifies(id,3), "no full ornament on incomplete set " + id)
	for id: String in Art.SETS:
		eq.active_run_loadout_snapshot = {}
		save.delete_active_run_save("checkpoint")
		eq.equipped_item_ids = {"armament":"mistveil_jian","robe":"","bracer":"","boots":"","pendant":""}
		for piece: String in Catalog.get_piece_ids(id): eq.equipped_item_ids[eq.get_item_data(piece).slot] = piece
		root.get_node("GameSession").start_new_game()
		check(change_scene_to_file("res://scenes/levels/level_1.tscn")==OK, "production scene " + id)
		await create_timer(0.25,true).timeout
		current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed()
		paused = false
		current_scene.get_node("EnemySpawner").process_mode = Node.PROCESS_MODE_DISABLED
		current_scene.get_node("WaveManager").process_mode = Node.PROCESS_MODE_DISABLED
		var player: Node2D = current_scene.get_node("player_1")
		player.set_physics_process(false)
		player.get_node("WeaponManager").set_process(false)
		var health: Node = player.get_node("PlayerHealth")
		var presentation: Node = player.get_node("EquipmentSetPresentation")
		var fx: Node2D = presentation.get_node("LegendarySetVFX")
		fx.set_process(false)
		var guard: Node = health.get_node("CelestialAegisGuard")
		guard.set_physics_process(false)
		check(fx.set_id==id and fx.frames.size()==4, "production presentation " + id)
		check(fx.foreground.z_index+presentation.z_index>player.get_node("AnimatedSprite2D").z_index, "guardian depth " + id)
		for texture: Texture2D in fx.frames:
			check(texture is AtlasTexture and texture.filter_clip and texture.region.size==Vector2(256,256), "isolated sampling " + id)
		fx._process(1.0)
		check(fx.visibility_mix==1.0 and fx.formation_left==0.0, "formation settles " + id)
		var enemy: Node2D = load("res://scenes/enemy/enemy_1.tscn").instantiate()
		enemy.max_hp = 1000
		current_scene.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.global_position = player.global_position + Vector2(45,0)
		if id=="vermilion_verdict":
			enemy.current_hp = 400
			Ledger.apply_hit(enemy,100,"spirit_sword")
			check(fx.proc_left==0.0, "crossing threshold is not already eligible")
			var before: float = enemy.current_hp
			Ledger.apply_hit(enemy,100,"spirit_sword")
			check(is_equal_approx(before-enemy.current_hp,112.0) and fx.proc_left>0.0, "eligible hit matches verdict VFX")
			fx._process(1.0)
			enemy.current_hp = 1
			Ledger.apply_hit(enemy,100,"spirit_sword")
			check(fx.proc_left>0.0,"final eligible killing hit still displays")
		elif id in ["nine_heavens","solar_meridian"]:
			var before: float = enemy.current_hp
			Ledger.apply_hit(enemy,100,"spirit_sword")
			check(is_equal_approx(before-enemy.current_hp,100.0), "direct damage unchanged " + id)
			check(enemy.has_node("EquipmentSetStatus") and fx.proc_left>0.0, "actual status drives effect " + id)
			var status: Node = enemy.get_node("EquipmentSetStatus")
			status.set_physics_process(false)
			var timer: float = fx.proc_left
			Ledger.apply_hit(enemy,100,"spirit_sword")
			check(is_equal_approx(fx.proc_left,timer), "rapid hit does not restart burst " + id)
			fx._process(1.0)
			Ledger.apply_hit(enemy,6,"set_"+str(Art.SETS[id].kind))
			check(fx.proc_left==0.0, "DOT does not fake direct proc " + id)
		else:
			health.qi_shield_charges = 0
			fx.shield_charges = 0
			guard.quiet = 7.99
			guard._physics_process(0.02)
			check(health.qi_shield_charges==1 and fx.formation_left==fx.FORM_SECONDS, "real refill opens seal")
			fx._process(0.3)
			check(fx.shield_mix>0.9, "shield ornaments follow real charge")
			var before: float = health.current_health
			health.hit_guard_remaining = 0
			health.take_damage(1)
			check(health.current_health==before and health.qi_shield_charges==0 and fx.block_left>0.0, "actual block shatters ornaments")
			guard._physics_process(0.1)
			check(guard.quiet<0.2, "block restarts eight-second wait")
		# Pause freezes inherited process in production, with no always-processing
		# timers. Resume does not reset elapsed time or create free procs.
		fx.set_process(true)
		paused = true
		var frozen_clock: float = fx.clock
		await settle()
		check(fx.clock==frozen_clock, "pause-aware effect " + id)
		paused = false
		fx.set_process(false)
		fx.configure(id,4,true)
		check(fx._burst(0.3,0.7)==0.0 and fx._clock(1.0)==0.0, "reduced steady appearance " + id)
		fx.set_process(false)
		fx.configure("frost_lotus",4,false)
		fx._process(0.12)
		check(fx.set_id==id and fx.visibility_mix>0 and fx.visibility_mix<1, "smooth departing set " + id)
		fx._process(0.2)
		check(fx.set_id.is_empty() and fx.visibility_mix==0.0, "epic never inherits premium art " + id)
		fx.configure(id,4,false)
		fx._process(1.0)
		health.is_dead = true
		fx._process(0.01)
		check(fx.visibility_mix==0.0, "hide on defeat " + id)
		current_scene.queue_free()
		await settle()
		current_scene = null
	check(root.get_node("InventoryManager").item_counts==inventory_before and eq.ascension_stars==stars_before, "visuals do not consume or ascend inventory")
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("LEGENDARY_VFX_QA checks=",checks," failures=",failures)
	quit(1 if failures else 0)
