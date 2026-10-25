extends SceneTree
## Controlled actual Area2D overlap/production damage probe, not full-run DPS.
var rows: Array[Dictionary]=[]
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("YIN_COVERAGE_FAIL "+label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_yin_coverage_qa"):quit(2);return
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	await process_frame
	root.get_node("GameSession").start_new_game();change_scene_to_file("res://scenes/levels/level_1.tscn");await create_timer(.3,true).timeout
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
	current_scene.get_node("EnemySpawner").process_mode=Node.PROCESS_MODE_DISABLED
	current_scene.get_node("WaveManager").process_mode=Node.PROCESS_MODE_DISABLED
	var player: Node2D=current_scene.get_node("player_1");player.set_physics_process(false)
	player.get_node("WeaponManager").set_process(false)
	var stats: Node=player.get_node("PlayerStats");stats.sword_intent_level=0
	var w: Node=load("res://scripts/weapon/yin_yang_blades_weapon.gd").new();player.get_node("WeaponManager").add_child(w);w.activate(player);w.set_process(false)
	for variant: String in ["legacy_control","wide_lv1","wide_lv7"]:
		for layout: String in ["inner_gap","outer_group","moving_group"]:
			w.level=1 if variant=="wide_lv1" else 7;w.apply_level_stats()
			if variant=="legacy_control":w.blade_count=5
			w.rebuild_blades();w.hit_cooldowns.clear()
			for blade: Node2D in w.blades:
				blade.orbit_radius=80.0 if variant=="legacy_control" else w.BASE_ORBIT_RADIUS
				if variant=="legacy_control":blade.orbit_speed=PI
			var enemies: Array[Node2D]=[]
			for index: int in range(6):
				var enemy: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate();enemy.max_hp=100000;current_scene.add_child(enemy);enemy.set_physics_process(false)
				enemies.append(enemy)
			var start: Array[float]=[]
			for enemy: Node2D in enemies:start.append(enemy.current_hp)
			for tick: int in range(120):
				var angle: float=tick*.007 if layout=="moving_group" else 0.0
				var radius: float=55.0 if layout=="inner_gap" else w.BASE_ORBIT_RADIUS
				for index: int in range(enemies.size()):
					enemies[index].global_position=player.get_node("CombatOrigin").global_position+Vector2.RIGHT.rotated(angle+index*TAU/enemies.size())*radius
				w.update_hit_cooldowns(1.0/60.0)
				await physics_frame
			var total: float=0
			for index: int in range(enemies.size()):total+=start[index]-enemies[index].current_hp
			rows.append({"variant":variant,"layout":layout,"targets":6,"seconds":2.0,"actual_hp_loss":total,"aggregate_dps":total/2.0})
			check(total>=0 and total<=6*w.damage/0.5*2.0*1.10,"bounded shared damage "+variant+layout)
			for enemy: Node2D in enemies:enemy.queue_free()
			await process_frame
	var outer: Array[Dictionary]=rows.filter(func(r: Dictionary):return r.variant=="wide_lv7" and r.layout=="outer_group")
	var gap: Array[Dictionary]=rows.filter(func(r: Dictionary):return r.variant=="wide_lv7" and r.layout=="inner_gap")
	check(outer[0].actual_hp_loss>0,"wide orbit damages real outer contacts")
	check(gap[0].actual_hp_loss==0,"inner gap is real; no invisible full-disc damage")
	# Large boss collider at the real outer orbit, with production hit handling.
	w.level=7;w.apply_level_stats();w.rebuild_blades();w.hit_cooldowns.clear()
	var boss: Node2D=load("res://scenes/enemy/boss_1.tscn").instantiate();boss.max_hp=100000;current_scene.add_child(boss);boss.set_physics_process(false);boss.set_process(false)
	boss.global_position=player.get_node("CombatOrigin").global_position+Vector2(w.BASE_ORBIT_RADIUS,0)
	var boss_before: float=boss.current_hp
	for tick: int in range(120):
		w.update_hit_cooldowns(1.0/60.0);await physics_frame
	var boss_loss: float=boss_before-boss.current_hp
	rows.append({"variant":"wide_lv7","layout":"production_boss_1","targets":1,"seconds":2.0,"actual_hp_loss":boss_loss,"aggregate_dps":boss_loss/2.0})
	check(boss_loss>0 and boss_loss<=w.damage/.5*2.0*1.10,"actual boss hit loss bounded by shared interval")
	boss.queue_free();await process_frame
	var result: Dictionary={"scope":"2-second production physics overlap and applied HP-loss fixture; 6 ordinary stationary/moving targets, no critical/passive/progression bonuses. Legacy control manually sets 5 blades/80px; not full-run/phone DPS.","rows":rows,"checks":checks,"failures":failures}
	var file=FileAccess.open(OS.get_environment("JADE_YIN_REPORT") if not OS.get_environment("JADE_YIN_REPORT").is_empty() else "user://yin-yang-coverage.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("YIN_COVERAGE_QA checks=",checks," failures=",failures," rows=",JSON.stringify(rows))
	w.clear_blades();current_scene.queue_free();current_scene=null;await process_frame;await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0)
