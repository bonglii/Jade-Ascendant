extends SceneTree
var checks: int=0
var failures: int=0
var measurements: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("YIN_TEMPO_FAIL "+label)
func frames(n: int=4) -> void:
	for i: int in n: await process_frame
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
	await frames(8);await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	root.get_node("GameSession").start_new_game();change_scene_to_file("res://scenes/levels/level_1.tscn");await frames(22)
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
	current_scene.get_node("EnemySpawner").process_mode=Node.PROCESS_MODE_DISABLED
	current_scene.get_node("EnemySpawner").clear_normal_enemies();current_scene.get_node("WaveManager").set_process(false)
	var player: Node2D=current_scene.get_node("player_1");player.set_physics_process(false)
	var manager: Node=player.get_node("WeaponManager");manager.set_process(false)
	for child: Node in manager.weapons:child.free()
	manager.weapons.clear();manager.attack_timers.clear()
	var stats: Node=player.get_node("PlayerStats");stats.power_multiplier=1;stats.sword_intent_level=0
	var weapon: Node=load("res://scripts/weapon/yin_yang_blades_weapon.gd").new();manager.add_child(weapon);weapon.activate(player);weapon.set_process(false);await frames()
	manager.add_weapon(weapon)
	var overlay: Control=current_scene.get_node("HUD/ScreenRoot/InRunStatsOverlay")
	var last_speed: float=0
	for level: int in range(1,8):
		if level>1:check(weapon.upgrade(),"normal upgrade succeeds "+str(level))
		await frames()
		var speed: float=weapon.get_current_orbit_speed()
		check(speed>last_speed and speed>=PI*1.6,"orbit is faster from level1 and accelerates every level")
		check(weapon.blades.size()==(6 if level==7 else 2+int((level-1)/2)),"blade milestone remains intact")
		for blade: Node2D in weapon.blades:
			blade.set_physics_process(false)
			check(is_equal_approx(blade.orbit_speed,speed),"existing blades update even when upgrade adds no blade")
		var blade: Node2D=weapon.blades[0];var before: float=blade.orbit_angle
		blade._physics_process(.05)
		check(is_equal_approx(fposmod(blade.orbit_angle-before,TAU),speed*.05),"real blade transform advances at disclosed speed")
		last_speed=speed
		overlay._refresh_live_loadout(stats)
		check(overlay._rows.weapon_yin_yang_blades.text.contains("ORBIT %.2fs"%[TAU/speed]),"combat stats disclose actual orbit instead of initial cast cooldown")
	check(is_equal_approx(TAU/last_speed,1.0/1.1),"level7 revolution is about0.91s")
	stats.yin_yang_reversal_unlocked=true
	weapon.activate_reversal()
	check(weapon.reversal_active and is_equal_approx(weapon.get_current_orbit_speed(),last_speed*1.5),"Reversal still multiplies actual faster orbit")
	overlay._refresh_live_loadout(stats)
	check(overlay._rows.weapon_yin_yang_blades.text.contains("ORBIT 0.61s"),"combat stats follow temporary Reversal speed")
	weapon.deactivate_reversal()
	check(is_equal_approx(weapon.get_current_orbit_speed(),last_speed),"Reversal restores exact normal speed")
	var origin: Vector2=player.get_node("CombatOrigin").global_position
	var ledger: Node=manager.get_node("RunCombatLedger")
	for level: int in [1,7]:
		for reversed: bool in [false,true]:
			weapon.level=level;weapon.apply_level_stats();weapon.reversal_active=reversed;weapon.rebuild_blades();weapon.hit_cooldowns.clear();await frames()
			for blade: Node2D in weapon.blades:blade.set_physics_process(false)
			var enemies: Array[Node2D]=[]
			for i: int in 3:
				var enemy: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate();enemy.max_hp=100000;current_scene.add_child(enemy);enemy.set_physics_process(false);enemies.append(enemy)
			var before_hp: Array[float]=[]
			for enemy: Node2D in enemies:before_hp.append(enemy.current_hp)
			var before_ledger: float=float(ledger.totals.get("yin_yang_blades",0))
			var radius: float=weapon.get_current_orbit_radius()
			for tick: int in 90:
				enemies[0].global_position=origin+Vector2(radius,0)
				enemies[1].global_position=origin+Vector2.from_angle(PI+float(tick)/60*.7)*radius
				enemies[2].global_position=origin+Vector2(35,0)
				weapon.update_hit_cooldowns(1.0/60)
				for blade: Node2D in weapon.blades:blade._physics_process(1.0/60)
				await physics_frame
			var actual: float=0
			for i: int in 2:
				var loss: float=before_hp[i]-enemies[i].current_hp
				actual+=loss
				check(loss>0,"faster Area2D hits real stationary/moving target")
				check(loss<=float(stats.calculate_damage(weapon.get_current_damage()))*4+.01,"shared0.5s target interval still bounds actual damage")
			check(is_equal_approx(actual,float(ledger.totals.get("yin_yang_blades",0))-before_ledger),"run report exactly matches applied enemy HP loss")
			check(enemies[2].current_hp==before_hp[2],"orbit does not become invisible full-disc damage")
			measurements.append({"level":level,"reversal":reversed,"stationary_and_moving_hp_loss_1_5s":actual,"seconds_per_turn":TAU/weapon.get_current_orbit_speed()})
			for enemy: Node2D in enemies:enemy.free()
			await frames()
	weapon.clear_blades();weapon.free();await frames()
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("YIN_TEMPO_MEASUREMENTS "+JSON.stringify(measurements))
	print("YIN_TEMPO checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
