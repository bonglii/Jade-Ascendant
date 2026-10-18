extends SpiritSwordWeapon
const Cast = preload("res://scripts/weapon/heavenweaver_compass_cast.gd")
const COMPASS = preload("res://assets/ui/liveops/odyssey/compass.png")
var _halo: Sprite2D
var _clock: float = 0.0
func _ready() -> void:
	super._ready()
	cooldown = 2.4
	_halo = Sprite2D.new(); _halo.texture = COMPASS; _halo.scale = Vector2.ONE * 38.0 / COMPASS.get_width()
	_halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_halo.z_index = -1; add_child(_halo)
func _process(delta: float) -> void:
	_clock += delta
	if _halo != null:
		_halo.position = Vector2(22, -28 + sin(_clock * 2.0) * 2.0)
		_halo.rotation = sin(_clock * 0.7) * 0.12
func target_count() -> int:
	return 2 + int(level >= 3) + int(level >= 5) + int(level >= 7)
func attack(player: Node2D, target: Node2D) -> void:
	var event_client: Node = get_node_or_null("/root/OdysseyClient")
	if event_client == null or not bool(event_client.get("run_authorized")): return
	if not Cast.living(target) or not Cast.in_range(player, target): return
	var candidates: Array[Node2D] = []
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if Cast.living(enemy) and enemy != target and Cast.in_range(player, enemy): candidates.append(enemy)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position))
	var selected: Array[Node2D] = [target]
	for enemy: Node2D in candidates:
		if selected.size() >= target_count(): break
		selected.append(enemy)
	var cast := Cast.new(); player.get_parent().add_child(cast)
	var manager: Node = player.get_node_or_null("WeaponManager")
	var tempo: float = float(manager.call("get_cast_tempo_damage_multiplier", self)) if manager != null else 1.0
	cast.configure(player, selected, base_damage * EquipmentManager.get_weapon_level_multiplier(armament_id) * tempo, level)
