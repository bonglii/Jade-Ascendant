extends SceneTree
var Cast: GDScript
var WeaponScript: GDScript
var failed: int = 0
var checks: int = 0
class Stats extends Node:
	func calculate_damage_result(damage: float) -> Dictionary: return {"damage":damage,"is_critical":false}
	func has_sword_dao_resonance() -> bool: return false
class CriticalStats extends Stats:
	func calculate_damage_result(damage: float) -> Dictionary: return {"damage":damage,"is_critical":true}
	func has_sword_dao_resonance() -> bool: return true
class Enemy extends Node2D:
	var current_hp: float = 10000.0
	var is_dead: bool = false
	func take_damage(damage: float) -> void: current_hp = maxf(0,current_hp-damage); is_dead = current_hp <= 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failed += 1; push_error("ODYSSEY_COMBAT " + message)
func _initialize() -> void: run.call_deferred()
func targets(nodes: Array) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for node: Node2D in nodes: out.append(node)
	return out
func enemy(parent: Node, position_value: Vector2, boss: bool = false) -> Node2D:
	var node := Enemy.new(); parent.add_child(node); node.position = position_value; node.add_to_group("enemy")
	if boss: node.add_to_group("boss")
	return node
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_warning_cleanup_qa"): quit(2); return
	Cast = load("res://scripts/weapon/heavenweaver_compass_cast.gd")
	WeaponScript = load("res://scripts/weapon/heavenweaver_compass_weapon.gd")
	var world := Node2D.new(); root.add_child(world)
	var player := Node2D.new(); world.add_child(player)
	var stats := Stats.new(); stats.name = "PlayerStats"; player.add_child(stats)
	for combat_level: int in [1,3,5,7]:
		var target: Node2D = enemy(world,Vector2(120,0),true)
		var cast: Node2D = Cast.new(); world.add_child(cast); cast.configure(player,targets([target]),10.0+(combat_level-1)*5.0,combat_level); cast.set_process(false)
		cast._process(2.0)
		var damage: float = 10000.0 - float(target.current_hp)
		var expected: float = (10.0+(combat_level-1)*5.0) * (2.63 if combat_level >= 5 else 2.0)
		check(is_equal_approx(damage,expected),"boss damage level %d: %.2f != %.2f" % [combat_level,damage,expected])
		print("ODYSSEY_BOSS level=",combat_level," damage=",damage," cast_dps=",damage/2.4)
		cast.free(); target.free()
	var first: Node2D = enemy(world,Vector2(100,0)); var second: Node2D = enemy(world,Vector2(100,100)); var corner: Node2D = enemy(world,Vector2(100,50))
	var sweep: Node2D = Cast.new(); world.add_child(sweep); sweep.configure(player,targets([first,second]),10,5); sweep.set_process(false); sweep._process(2.0)
	check(is_equal_approx(10000.0-float(corner.current_hp),12.15),"coarse frame traverses every path segment and both phases")
	check(sweep.hits[0].size()==3 and sweep.hits[1].size()==3,"one hit per phase")
	sweep.free(); first.free(); second.free(); corner.free()
	var moving: Node2D = enemy(world,Vector2(100,0)); var dodge: Node2D = Cast.new(); world.add_child(dodge); dodge.configure(player,targets([moving]),10,5); dodge.set_process(false); moving.position=Vector2(100,70); dodge._process(2.0)
	check(is_equal_approx(10000.0-float(moving.current_hp),2.0),"moving target escapes locked path and retains mark only")
	dodge.free(); moving.free()
	var crowd: Array[Node2D] = []
	for i: int in range(80): crowd.append(enemy(world,Vector2(100 + i % 3,0)))
	var capped: Node2D = Cast.new(); world.add_child(capped); capped.configure(player,targets([crowd[0]]),10,5); capped.set_process(false); capped._process(2.0)
	check(capped.candidates.size()==64,"candidate scan bounded to 64")
	check(capped.hits[0].size()==12 and capped.hits[1].size()==12,"dragon hit cap 12 per phase")
	capped.free()
	for target: Node2D in crowd: target.free()
	var out_of_range: Node2D = enemy(world,Vector2(240,0),true); check(not Cast.in_range(player,out_of_range),"boss 230px range"); out_of_range.free()
	var weapon: Node = WeaponScript.new(); player.add_child(weapon)
	for combat_level: int in [1,3,5,7]: weapon.level = combat_level; check(weapon.target_count()==2+int(combat_level>=3)+int(combat_level>=5)+int(combat_level>=7),"target milestone")
	weapon.free()
	var paid: Node = root.get_node("PavilionManager/PaidGameplayV2")
	check(paid.local_catalog_hash()==paid.HASH,"event item does not alter pinned paid catalog")
	stats.free()
	var critical := CriticalStats.new(); critical.name = "PlayerStats"; player.add_child(critical)
	var crit_target: Node2D = enemy(world,Vector2(100,0))
	var crit_cast: Node2D = Cast.new(); world.add_child(crit_cast); crit_cast.configure(player,targets([crit_target]),10,5); crit_cast.set_process(false); crit_cast._process(0.241)
	check(not crit_cast.resonance_used,"weak critical mark does not consume resonance")
	crit_cast._process(2.0)
	check(crit_cast.resonance_used and is_equal_approx(10000.0-float(crit_target.current_hp),30.3),"one critical dragon resonance per cast")
	crit_cast.free(); crit_target.free()
	var inventory: Node = root.get_node("InventoryManager"); var equipment: Node = root.get_node("EquipmentManager")
	inventory.item_counts.erase("heavenweaver_compass"); equipment.ascension_stars.erase("heavenweaver_compass")
	check(inventory.add_item("heavenweaver_compass",2),"existing inventory accepts the event attachment")
	check(equipment.get_weapon_level_cap("heavenweaver_compass")==10,"one-star permanent cap 10")
	check(equipment.ascend_item("heavenweaver_compass"),"identical duplicate ascension")
	check(inventory.get_item_count("heavenweaver_compass")==1 and equipment.get_weapon_level_cap("heavenweaver_compass")==20,"duplicate consumed once and cap becomes 20")
	check(not root.get_node("PavilionManager").is_item_unlocked("heavenweaver_compass"),"not forgeable or directly purchasable")
	world.free()
	print("ODYSSEY_COMBAT checks=",checks," failed=",failed)
	await process_frame
	quit(0 if failed==0 else 1)
