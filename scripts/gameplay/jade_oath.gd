extends Node2D
const State = preload("res://scripts/data/jade_oath_state.gd")
const Sheet = preload("res://scripts/companion/player_journal.gd")
const ARRIVAL_DURATION := .65
var state = State.new()
var _actor: Node2D
var _waves: Node
var _panel: PanelContainer
var _heading: Label
var _instruction: Label
var _progress: ProgressBar
var _arrival_left: float = 0.0
var _probe_left: float = 0.0
var _draw_left: float = 0.0

func _ready() -> void:
	name = "JadeOath"
	z_index = 6
	_actor = get_parent().get_node("player_1")
	_waves = get_parent().get_node("WaveManager")
	state.begin(GameSession.jade_oath_requested and JourneyManager.is_stage_cleared(1,3))
	GameSession.jade_oath_requested = false
	var safe: Control = get_parent().get_node_or_null("HUD/ScreenRoot/HUDSafeArea")
	if safe == null:
		return
	_panel = PanelContainer.new()
	_panel.name = "JadeOathHUD"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel",Sheet.skin(8))
	safe.add_child(_panel)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation",3)
	_panel.add_child(body)
	_heading = Sheet.label("",14,Sheet.GOLD)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_heading)
	_instruction = Sheet.label("",13)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_instruction)
	_progress = ProgressBar.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 5
	_progress.max_value = State.CHARGE
	_progress.step = 0.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color("1a3b37")
	track.set_corner_radius_all(3)
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = Sheet.JADE
	_progress.add_theme_stylebox_override("background",track)
	_progress.add_theme_stylebox_override("fill",fill)
	body.add_child(_progress)
	safe.resized.connect(_fit_chip)
	safe.get_node("TopHUD").resized.connect(_fit_chip)
	safe.get_node("BossPanel").visibility_changed.connect(_fit_chip)
	_fit_chip()
	_refresh()

func _fit_chip() -> void:
	if not is_instance_valid(_panel):
		return
	var safe: Control = _panel.get_parent()
	var width: float = minf(340,safe.size.x - 24)
	var top: float = maxf(safe.get_node("TopHUD").get_rect().end.y,safe.get_node("StageIdentity").get_rect().end.y)
	var boss: Control = safe.get_node("BossPanel")
	if boss.visible:
		top = maxf(top,boss.get_rect().end.y)
	_panel.size = Vector2(width,0)
	_panel.position = Vector2((safe.size.x - width)*.5,top + 6.0)

func restore(raw: Variant) -> void:
	state.restore(raw)
	_arrival_left = 0.0
	_refresh()

func _exit_tree() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()

func _process(delta: float) -> void:
	if not is_instance_valid(_actor) or bool(_actor.get_node("PlayerHealth").is_dead):
		return
	if state.phase == "waiting" and _waves.current_wave == 5:
		_probe_left -= delta
		if _probe_left <= 0:
			_probe_left = .5
			var available: float = float(_waves.wave_timer) + float(_waves.duration_for_wave(6))
			var spawner: Node = get_parent().get_node("EnemySpawner")
			if available >= State.WINDOW and not spawner.has_active_scheduled_elite():
				var candidate: Variant = _safe_point()
				if candidate is Vector2 and state.offer(candidate,5,available):
					_arrival_left = 0.0 if SettingsManager.reduced_effects else ARRIVAL_DURATION
					AudioManager.play_sfx("achievement_unlock")
					if SettingsManager.haptics and OS.has_feature("android"):
						Input.vibrate_handheld(32)
	_arrival_left = maxf(0.0,_arrival_left-delta)
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
	if not is_instance_valid(_panel):
		return
	_panel.visible = state.phase in ["charging","pending","failed"]
	if not _panel.visible:
		return
	_heading.text = Sheet.copy("◆ JADE OATH","◆ SUMPAH GIOK")
	_progress.visible = state.phase == "charging"
	match state.phase:
		"charging":
			_heading.text += Sheet.copy("  ·  %ds left","  ·  sisa %d dtk") % ceili(state.remaining)
			var inside: bool = _actor.global_position.distance_squared_to(state.location) <= State.RADIUS*State.RADIUS
			_instruction.text = Sheet.copy("Stay inside to charge","Tetap di dalam untuk mengisi") if inside else Sheet.copy("Step inside the jade seal","Masuk ke lingkaran segel")
			_progress.value = state.charge
		"pending":
			_instruction.text = Sheet.copy("Seal restored · Win to unlock the story","Segel pulih · Menang untuk membuka cerita")
		"failed":
			_instruction.text = Sheet.copy("Seal faded · Continue the trial","Segel padam · Lanjutkan trial")

func _draw() -> void:
	if state.phase != "charging":
		return
	var point: Vector2 = to_local(state.location)
	draw_circle(point,State.RADIUS,Color(.22,.69,.48,.18))
	draw_arc(point,State.RADIUS+2,0,TAU,64,Color(.02,.12,.10,.85),6,true)
	draw_arc(point,State.RADIUS,0,TAU,64,Sheet.JADE,3,true)
	draw_arc(point,State.RADIUS-5,-PI/2,-PI/2+TAU*state.charge/State.CHARGE,64,Color("edce82"),4,true)
	var seal := PackedVector2Array([point+Vector2(0,-16),point+Vector2(11,0),point+Vector2(0,16),point+Vector2(-11,0)])
	draw_colored_polygon(seal,Color("edce82"))
	for index: int in range(4):
		var axis := Vector2.from_angle(float(index)*PI/2)
		draw_line(point+axis*(State.RADIUS-11),point+axis*(State.RADIUS+7),Sheet.GOLD,3,true)
	if _arrival_left > 0.0:
		var arrival: float = _arrival_left/ARRIVAL_DURATION
		draw_arc(point,State.RADIUS+32*(1.0-arrival),0,TAU,64,Color(Sheet.GOLD,arrival*.65),3,true)
