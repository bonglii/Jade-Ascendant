extends Node2D
const State = preload("res://scripts/data/jade_oath_state.gd")
var state = State.new()
var _actor: Node2D
var _waves: Node
var _chip: Label
var _probe_left: float = 0.0
var _draw_left: float = 0.0

func _ready() -> void:
	name = "JadeOath"
	z_index = 6
	_actor = get_parent().get_node("player_1")
	_waves = get_parent().get_node("WaveManager")
	state.begin(GameSession.jade_oath_requested and JourneyManager.is_stage_cleared(1,3))
	GameSession.jade_oath_requested = false
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var safe := Control.new()
	safe.name = "DeviceSafeArea"
	safe.set_script(preload("res://scripts/ui/mobile_safe_area.gd"))
	root.add_child(safe)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-154,112)
	panel.custom_minimum_size = Vector2(308,46)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(.015,.055,.05,.94)
	skin.border_color = Color("83cca7")
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(10)
	skin.content_margin_left = 10
	skin.content_margin_right = 10
	panel.add_theme_stylebox_override("panel",skin)
	safe.add_child(panel)
	_chip = Label.new()
	_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip.add_theme_font_size_override("font_size",14)
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_chip)
	_refresh()

func restore(raw: Variant) -> void:
	state.restore(raw)
	_refresh()

func _process(delta: float) -> void:
	if not is_instance_valid(_actor) or bool(_actor.get_node("PlayerHealth").is_dead):
		return
	if state.phase == "waiting" and _waves.current_wave == 5:
		_probe_left -= delta
		if _probe_left <= 0:
			_probe_left = .5
			var available: float = float(_waves.wave_timer) + float(_waves.wave_duration)
			var spawner: Node = get_parent().get_node("EnemySpawner")
			if available >= State.WINDOW and not spawner.has_active_scheduled_elite():
				var candidate: Variant = _safe_point()
				if candidate is Vector2:
					state.offer(candidate,5,available)
	state.advance(delta,_actor.global_position.distance_squared_to(state.location) <= State.RADIUS*State.RADIUS,int(_waves.current_wave))
	_draw_left -= delta
	if _draw_left <= 0:
		_draw_left = 1.0/20.0
		_refresh()

func _safe_point() -> Variant:
	var space := get_world_2d().direct_space_state
	var circle := CircleShape2D.new()
	circle.radius = State.RADIUS + 16.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = _actor.collision_mask
	query.exclude = [_actor.get_rid()]
	for index: int in range(12):
		var point := _actor.global_position + Vector2.from_angle(float(index)*TAU/12.0)*148.0
		query.transform = Transform2D(0.0,point)
		if not space.intersect_shape(query,1).is_empty():
			continue
		var safe := true
		for enemy: Node in get_tree().get_nodes_in_group("enemy"):
			if enemy is Node2D and enemy.global_position.distance_squared_to(point) < 160.0*160.0:
				safe = false
				break
		for hazard: Node in get_tree().get_nodes_in_group("stage_hazard"):
			if hazard is Node2D and hazard.global_position.distance_squared_to(point) < 180.0*180.0:
				safe = false
		var ray := PhysicsRayQueryParameters2D.create(_actor.global_position,point,_actor.collision_mask,[_actor.get_rid()])
		if safe and space.intersect_ray(ray).is_empty():
			return point
	return null

func _refresh() -> void:
	queue_redraw()
	if _chip == null:
		return
	_chip.get_parent().visible = state.phase in ["charging","pending","failed"]
	var id: bool = SettingsManager.language == "id"
	match state.phase:
		"charging": _chip.text = ("SUMPAH GIOK  %.1f / 8 dtk  ·  %.0f dtk" if id else "JADE OATH  %.1f / 8s  ·  %.0fs") % [state.charge,ceilf(state.remaining)]
		"pending": _chip.text = "Segel pulih · Menang untuk membuka cerita" if id else "Seal restored · Win to unlock the story"
		"failed": _chip.text = "Segel padam · Lanjutkan trial" if id else "Seal faded · Continue the trial"

func _draw() -> void:
	if state.phase != "charging":
		return
	var point: Vector2 = to_local(state.location)
	draw_circle(point,State.RADIUS,Color(.22,.69,.48,.12))
	draw_arc(point,State.RADIUS,0,TAU,64,Color("a8dbc0"),2,true)
	draw_arc(point,State.RADIUS-5,-PI/2,-PI/2+TAU*state.charge/State.CHARGE,64,Color("edce82"),4,true)
	for index: int in range(4):
		var axis := Vector2.from_angle(float(index)*PI/2)
		draw_line(point+axis*12,point+axis*26,Color("83cca7"),2,true)
