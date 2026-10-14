extends SceneTree
const Ledger=preload("res://scripts/weapon/run_combat_ledger.gd")
const Art=preload("res://scripts/effects/combat_cel_art.gd")
var checks: int=0
var failures: int=0
class DeniedTarget extends Node2D:
	var current_hp: float=100
	var max_hp: float=100
	var is_dead: bool=false
	func take_damage(_amount: float) -> void: pass
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("COMBAT_CEL_FAIL "+label)
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i: int in range(3):await process_frame
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_combat_cel_qa"):quit(2);return
	await process_frame
	root.get_node("GameSession").start_new_game()
	change_scene_to_file("res://scenes/levels/level_1.tscn");await create_timer(.3,true).timeout
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
	current_scene.get_node("EnemySpawner").process_mode=Node.PROCESS_MODE_DISABLED
	current_scene.get_node("WaveManager").process_mode=Node.PROCESS_MODE_DISABLED
	var player: Node2D=current_scene.get_node("player_1");player.set_physics_process(false)
	var manager: Node=player.get_node("WeaponManager");manager.set_process(false)
	var stats: Node=player.get_node("PlayerStats")
	stats.sword_intent_level=0
	var w: Node=load("res://scripts/weapon/yin_yang_blades_weapon.gd").new();manager.add_child(w);w.activate(player);w.set_process(false);await settle()
	for lv: int in [1,3,5,7]:
		w.level=lv;w.apply_level_stats();w.rebuild_blades();
		for blade: Node2D in w.blades:blade.set_physics_process(false)
		await settle()
		check(w.blades.size()=={1:2,3:3,5:4,7:6}[lv],"blade milestone Lv."+str(lv))
		check(is_equal_approx(w.damage,8+3*(lv-1)),"per-hit damage unchanged Lv."+str(lv))
		for blade: Node2D in w.blades:
			blade.set_physics_process(false)
			var center: Vector2=player.get_node("CombatOrigin").position
			check(is_equal_approx(blade.position.distance_to(center),116),"first visible frame already on wide orbit")
			check(not blade.aura_ring.visible and blade.get_node("CollisionShape2D").shape.radius==10,"no polygon halo; real hitbox unchanged")
	check(w.blades.filter(func(b: Node2D):return b.polarity==&"yin").size()==3,"3 Yin + 3 Yang")
	w.blades[0].orbit_angle=1.3;w.rebuild_blades()
	for blade: Node2D in w.blades:blade.set_physics_process(false)
	check(is_equal_approx(w.blades[0].orbit_angle,1.3),"refinement rebuild keeps orbit phase")
	await settle()
	for blade: Node2D in w.blades:blade.set_physics_process(false)
	var enemy: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate();enemy.max_hp=100000;current_scene.add_child(enemy);enemy.set_physics_process(false)
	enemy.global_position=player.global_position+Vector2(116,0)
	var before: float=enemy.current_hp
	w.damage_target(enemy);var after: float=enemy.current_hp
	for blade: Node2D in w.blades:w._on_blade_body_contacted(enemy)
	check(before>after and enemy.current_hp==after,"six blade contacts share one target gate")
	w.update_hit_cooldowns(.5);w.damage_target(enemy)
	check(is_equal_approx(before-enemy.current_hp,2*(before-after)),"0.5s shared hit interval unchanged")
	var rejected:=DeniedTarget.new();current_scene.add_child(rejected)
	var rain: Node2D=load("res://scenes/weapons/heavenly_sword_rain.tscn").instantiate();rain.telegraph_duration=10;rain.setup(18,32,stats);current_scene.add_child(rain)
	check(not rain.damage_target(rejected),"rejected impact cannot trigger Heavenly Tribulation")
	check(rain.damage_target(enemy),"actual Sword Rain hit succeeds")
	check(rain.telegraph_ring.scale==Vector2.ONE and rain.get_node("CollisionShape2D").shape.radius==32,"Sword Rain boundary real from first paint")
	rain.free();rejected.free()
	var feedback: Node=root.get_node("CombatFeedback")
	var cursor: int=feedback.weapon_impact_cursor
	var denied:=DeniedTarget.new();current_scene.add_child(denied)
	check(Ledger.apply_hit(denied,20,"yin_yang_blades")==0 and feedback.weapon_impact_cursor==cursor,"no luxury hit on rejected damage")
	denied.free()
	for i: int in range(200):Ledger.apply_hit(enemy,1,"yin_yang_blades")
	check(feedback.weapon_impacts.size()==32,"confirmed impact ring buffer bounded under burst")
	var left: float=feedback.weapon_impacts[feedback.weapon_impact_cursor].left
	paused=true;await settle()
	check(feedback.weapon_impacts[feedback.weapon_impact_cursor].left==left,"new impacts freeze while paused")
	paused=false
	feedback._reset_feedback()
	check(feedback.weapon_impacts.all(func(e: Dictionary):return e.is_empty()),"transition clears pooled impacts")
	w.clear_blades();w.free();await settle()
	# Ranged pattern locks aim at charge, retains single/spread/predictive count.
	for pattern: StringName in [&"single",&"spread_three",&"predictive_pair"]:
		var caster: Node2D=load("res://scenes/enemy/enemy_2.tscn").instantiate();current_scene.add_child(caster);caster.set_physics_process(false)
		caster.attack_pattern=pattern;caster.position=player.position+Vector2(100,0);caster.attack_timer=0
		caster.try_attack();var locked: Vector2=caster.locked_aim
		check(get_nodes_in_group("enemy_attack").is_empty(),"no release before cast wind-up "+str(pattern))
		caster._physics_process(.17)
		check(get_nodes_in_group("enemy_attack").is_empty(),"wind-up respected "+str(pattern))
		player.position.y+=30;caster._physics_process(.02);await settle()
		var shots: Array[Node]=get_nodes_in_group("enemy_attack")
		check(shots.size()=={&"single":1,&"spread_three":3,&"predictive_pair":2}[pattern],"pattern projectile count "+str(pattern))
		check(caster.locked_aim==locked,"aim remains locked through wind-up")
		for shot: Node in shots:shot.free()
		caster.free()
	var dead_caster: Node2D=load("res://scenes/enemy/enemy_2.tscn").instantiate();current_scene.add_child(dead_caster);dead_caster.set_physics_process(false);dead_caster.try_attack();dead_caster.is_dead=true;dead_caster._physics_process(.3)
	check(get_nodes_in_group("enemy_attack").is_empty(),"dead caster cancels queued shot");dead_caster.free()
	for theme: StringName in [&"verdant_qi",&"crimson_moon",&"nine_heavens",&"frostveil",&"solar_nirvana"]:
		for file: String in ["qi_explosion","lightning_strike"]:
			var attack: Node2D=load("res://scenes/enemy/"+file+".tscn").instantiate();attack.presentation_theme=theme;attack.telegraph_duration=10;current_scene.add_child(attack)
			check(attack.has_node("HostileAttackPolish") and attack.telegraph_outline.points.size()==49,"polished spell with exact circular warning "+file+str(theme))
			attack.free()
	for kit: String in ["blades","hostile","impacts"]:
		for index: int in range(8 if kit=="impacts" else 4):
			var texture: AtlasTexture=Art.frame(kit,index)
			check(texture.filter_clip and texture.region.size==Vector2(256,256),"isolated source component "+kit+str(index))
	print("COMBAT_CEL_QA checks=",checks," failures=",failures)
	current_scene.queue_free();current_scene=null;await settle();quit(1 if failures else 0)
