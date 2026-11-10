extends SceneTree
## Run in a disposable XDG_DATA_HOME. All fixture ownership is test-local.

const HOME = "res://scenes/ui/main_menu.tscn"
const STAGE = "res://scenes/levels/level_1.tscn"
const ENEMY = "res://scenes/enemy/enemy_1.tscn"
const BOSS = "res://scenes/enemy/boss_1.tscn"

var passed: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		printerr("FAIL: ", label)

func _scene(path: String) -> void:
	assert(change_scene_to_file(path) == OK)
	await scene_changed
	await create_timer(0.35).timeout

func _stage() -> Node2D:
	root.get_node("GameSession").start_new_game()
	await _scene(STAGE)
	var tutorial: Node = current_scene.get_node_or_null("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")
	if tutorial != null and tutorial.tutorial_active:
		tutorial._on_skip_pressed()
	paused = false
	for name in ["EnemySpawner", "WaveManager", "DifficultyManager"]:
		current_scene.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	for existing in get_nodes_in_group("enemy"):
		existing.queue_free()
	await process_frame
	var player: Node2D = get_first_node_in_group("player")
	player.set_physics_process(false)
	var weapons: Node = player.get_node("WeaponManager")
	weapons.set_process(false)
	weapons.get_node("RunPathChoices").process_mode = Node.PROCESS_MODE_DISABLED
	return player

func _enemy(path: String, at: Vector2) -> CharacterBody2D:
	var actor: CharacterBody2D = load(path).instantiate()
	actor.max_hp = 10000
	current_scene.add_child(actor)
	actor.current_hp = 10000
	actor.global_position = at
	actor.set_physics_process(false)
	actor.set_process(false)
	return actor

func _run() -> void:
	await process_frame
	await _offer()
	await _rain()
	await _parasol()
	current_scene.queue_free()
	await process_frame
	await process_frame
	print("GALE_RECOVERY_SMOKE ", passed, " passed, ", failures, " failed")
	quit(0 if failures == 0 else 1)

func _offer() -> void:
	var journey: Node = root.get_node("JourneyManager")
	var pack: Script = load("res://scripts/data/starter_pack_catalog.gd")
	var sets: Script = load("res://scripts/data/equipment_set_catalog.gd")
	root.content_scale_size = Vector2i(360, 640)
	await _scene(HOME)
	var shortcut := current_scene.find_child("GaleStarterPackShortcut", true, false) as Button
	_check(shortcut != null and not shortcut.is_visible_in_tree(), "Home offer hidden before Stage 1-5")
	journey.cleared_stage_keys.append(journey.get_stage_key(1, 5))
	journey.stage_completed.emit(1, 5, true)
	await process_frame
	await process_frame
	_check(shortcut != null and shortcut.is_visible_in_tree(), "Home offer visible after Stage 1-5")
	if shortcut != null:
		shortcut.pressed.emit()
	await process_frame
	var offer := current_scene.find_child("GaleStarterPack", true, false) as Control
	_check(offer != null, "Home opens the production offer")
	if offer != null:
		var checkout := offer.find_child("StarterPackCheckout", true, false) as Button
		var scroll := offer.find_child("StarterPackScroll", true, false) as ScrollContainer
		_check(checkout != null and checkout.disabled, "draft cannot initiate payment")
		_check(scroll != null and scroll.scroll_deadzone == 6, "shared mobile scroller")
		_check(scroll.size.x <= offer.size.x and scroll.get_v_scroll_bar().max_value > scroll.size.y,
			"compact preview scrolls within its width")
		var close := offer.find_child("CloseStarterPack", true, false) as Button
		close.pressed.emit()
		await process_frame
		_check(not is_instance_valid(offer), "offer close returns to Home")
	var settings: Node = root.get_node("SettingsManager")
	settings.set_presentation("language", "id")
	for layout in [Vector2i(405, 860), Vector2i(800, 450)]:
		root.content_scale_size = layout
		root.size = layout
		await process_frame
		await process_frame
		var panels := current_scene.find_child("SanctuaryPanelsScroll", true, false) as Control
		_check(shortcut.is_visible_in_tree() and not shortcut.get_global_rect().intersects(panels.get_global_rect()),
			"offer icon clears Home panels at %s" % str(layout))
		shortcut.pressed.emit()
		await process_frame
		offer = current_scene.find_child("GaleStarterPack", true, false) as Control
		if offer == null:
			_check(false, "Indonesian offer opens")
			continue
		var id_checkout := offer.find_child("StarterPackCheckout", true, false) as Button
		_check(id_checkout != null and id_checkout.text == "Pembelian Google Play belum tersedia",
			"Indonesian purchase state at %s" % str(layout))
		var close := offer.find_child("CloseStarterPack", true, false) as Button
		close.pressed.emit()
		await process_frame
	settings.set_presentation("language", "en")
	root.content_scale_size = Vector2i(360, 640)
	root.size = Vector2i(360, 640)
	_check(pack.target_price() == "Rp39.000" and pack.ITEMS.size() == 5, "five items and Indonesia price")
	var pavilion: Node = root.get_node("PavilionManager")
	var pools: Dictionary = pavilion.get_summon_pool_by_rarity()
	for id: String in pack.ITEMS:
		var in_pool: bool = false
		for pool: Array in pools.values():
			in_pool = in_pool or id in pool
		_check(not in_pool and not pavilion.is_item_unlocked(id)
			and not pavilion.can_buy_equipment_with_stones(id), id + " excluded from currency routes")
	var armor: Array[String] = ["galeweave_robe", "galeweave_bracer", "galeweave_boots", "galeweave_pendant"]
	_check(sets.is_tier_active("galeweave", 2, armor), "2/4 HP applies to other weapon types")
	_check(not sets.is_tier_active("galeweave", 3, armor)
		and not sets.is_tier_active("galeweave", 4, armor), "3/4 and 4/4 require parasol")
	armor.append("gale_parasol")
	_check(sets.is_tier_active("galeweave", 3, armor)
		and sets.is_tier_active("galeweave", 4, armor), "matching weapon activates both upper tiers")

func _rain() -> void:
	var player := await _stage()
	var manager: Node = player.get_node("WeaponManager")
	var button := current_scene.find_child("SwordRainMode", true, false) as Button
	_check(button != null and not button.is_visible_in_tree(), "Rain switch hidden before acquisition")
	manager.add_heavenly_sword_rain()
	await process_frame
	await process_frame
	var rain: Node = manager.get_weapon_by_name("Heavenly Sword Rain")
	var orbit: Node2D = player.get_node("SwordRainOrbit")
	for pair in [[1, 2], [3, 3], [5, 4], [7, 5]]:
		rain.level = pair[0]
		rain.apply_level_stats()
		_check(orbit.count == pair[1], "orbit count at level %d" % pair[0])
	for index in range(1, 5):
		var current: Vector2 = rain.get_strike_position(Vector2.ZERO, index)
		var next: Vector2 = rain.get_strike_position(Vector2.ZERO, index % 4 + 1)
		_check(absf(current.normalized().dot(next.normalized())) < 0.0001, "Lv.7 orthogonal coverage")
	_check(button != null and button.is_visible_in_tree(), "Rain switch visible after acquisition")

	var boss := _enemy(BOSS, player.global_position + Vector2(145, 0))
	rain.attack(player, boss)
	await create_timer(1.0).timeout
	var area: float = 10000.0 - boss.current_hp
	_check(area > 0.0, "Area damages a real boss")
	boss.current_hp = 10000
	if button != null:
		var position: Vector2 = button.get_global_transform_with_canvas() * (button.size / 2.0)
		for pressed in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 1
			touch.position = position
			touch.pressed = pressed
			root.push_input(touch, true)
	_check(rain.sequential, "secondary touch switches to Sequence")
	rain.attack(player, boss)
	await create_timer(1.65).timeout
	var sequence: float = 10000.0 - boss.current_hp
	_check(sequence > 0.0 and sequence < area, "Sequence repeat damage applied to real boss")
	print("RAIN_DAMAGE area=%.2f sequence=%.2f" % [area, sequence])
	var checkpoint: Node = current_scene.get_node("CheckPointManager")
	_check(checkpoint.save_checkpoint(), "actual checkpoint written")
	var stored: Dictionary = checkpoint.read_checkpoint_result().get("data", {})
	_check(bool(stored.get("heavenly_sword_rain_sequential", false)), "Sequence stored")
	stored.erase("heavenly_sword_rain_sequential")
	var legacy: Dictionary = checkpoint.normalize_checkpoint_save_data(stored)
	_check(not legacy.is_empty() and not legacy.get("heavenly_sword_rain_sequential", false),
		"older saves default to Area")
	rain.sequential = false
	_check(checkpoint.load_checkpoint() and rain.sequential, "Continue restores Sequence")
	checkpoint.delete_checkpoint()

func _parasol() -> void:
	var pack: Script = load("res://scripts/data/starter_pack_catalog.gd")
	var equipment: Node = root.get_node("EquipmentManager")
	var inventory: Node = root.get_node("InventoryManager")
	equipment.active_run_loadout_snapshot = {}
	for id: String in pack.ITEMS:
		inventory.item_counts[id] = 1
		equipment.equipped_item_ids[str(equipment.get_item_data(id).slot)] = id

	var player := await _stage()
	var manager: Node = player.get_node("WeaponManager")
	var parasol: Node = manager.get_weapon_by_name("Spirit Sword")
	if parasol == null or parasol.get_combat_display_name() != "Gale Parasol":
		_check(false, "production WeaponManager selects the Gale Parasol")
		return
	_check(true, "production WeaponManager selects the Gale Parasol")
	var socket := player.get_node_or_null("CombatOrigin") as Node2D
	var origin: Vector2 = socket.global_position if socket != null else player.global_position
	var line: Array[CharacterBody2D] = []
	for distance in [122, 176, 230]:
		line.append(_enemy(ENEMY, origin + Vector2(distance, 0)))
	await physics_frame
	_check(not parasol.tick_opening(player, 0.13), "scattered enemies leave parasol closed")
	parasol.attack(player, line[0])
	await create_timer(0.45).timeout
	for actor in line:
		_check(actor.current_hp < 10000.0, "3/4 piercing thorn damages the next real enemy")
		actor.queue_free()
	await process_frame

	var crowd: Array[CharacterBody2D] = []
	for offset in [Vector2(73, 0), Vector2(0, 74), Vector2(-74, 0)]:
		crowd.append(_enemy(ENEMY, player.global_position + offset))
	var boss := _enemy(BOSS, player.global_position + Vector2(0, -80))
	var ordinary_start: Vector2 = crowd[0].global_position
	var boss_start: Vector2 = boss.global_position
	var speed: float = player.get_effective_movement_speed()
	await physics_frame
	_check(parasol.tick_opening(player, 0.13) and parasol.blocks_needle(), "crowd opens canopy")
	_check(is_equal_approx(player.get_effective_movement_speed(), speed * 1.20), "4/4 Windstep speed")
	_check(not parasol.tick_opening(player, 0.01), "canopy has separate cooldown")
	await create_timer(0.4).timeout
	_check(crowd[0].current_hp < 10000 and crowd[0].global_position.distance_to(ordinary_start) > 20.0,
		"canopy damages and pushes regular enemies")
	_check(boss.current_hp < 10000 and boss.global_position.is_equal_approx(boss_start),
		"canopy damages boss without displacement")
	_check(boss.current_hp > crowd[0].current_hp, "canopy boss damage reduced")
	var ledger: Node = manager.get_node("RunCombatLedger")
	var rows: Array = ledger.damage_rows()
	_check(rows.any(func(row: Dictionary) -> bool:
		return row.id == "gale_parasol" and row.damage > 0.0), "real Gale damage recorded on run report")
	print("GALE_WAVE normal=%.2f boss=%.2f push=%.2f" % [
		10000.0 - crowd[0].current_hp, 10000.0 - boss.current_hp, ordinary_start.distance_to(crowd[0].global_position)])
