extends SpiritSwordWeapon
const Cast = preload("res://scripts/weapon/heavenweaver_compass_cast.gd")
const COMPASS = preload("res://assets/ui/liveops/odyssey/compass.png")
var _halo: Sprite2D
var _clock: float = 0.0
var pursuit: Node2D
func _ready() -> void:
	super._ready()
	cooldown = 0.45
	_halo = Sprite2D.new()
	_halo.texture = COMPASS
	_halo.scale = Vector2.ONE * 38.0 / COMPASS.get_width()
	_halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_halo.z_index = -1
	add_child(_halo)
func _process(delta: float) -> void:
	_clock += delta
	if _halo != null:
		_halo.position = Vector2(22, -28 + sin(_clock * 2.0) * 2.0)
		_halo.rotation = sin(_clock * 0.7) * 0.12
func attack(player: Node2D, _target: Node2D) -> void:
	var event_client: Node = get_node_or_null("/root/OdysseyClient")
	if event_client == null or not bool(event_client.get("run_authorized")): return
	if not is_instance_valid(pursuit):
		pursuit = Cast.new()
		player.get_parent().add_child(pursuit)
		pursuit.configure(player, self)
	var manager: Node = player.get_node_or_null("WeaponManager")
	var tempo: float = float(manager.call("get_cast_tempo_damage_multiplier", self)) if manager != null else 1.0
	pursuit.strike_tick(base_damage * EquipmentManager.get_weapon_level_multiplier(armament_id) * tempo, level)
func _exit_tree() -> void:
	if is_instance_valid(pursuit): pursuit.queue_free()
