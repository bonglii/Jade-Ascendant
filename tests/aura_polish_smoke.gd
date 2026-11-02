extends SceneTree
## Presentation-only fixture. Mock autoloads have no save or economy authority.
const Visual = preload("res://scripts/ui/pavilion_aura_visual.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("AURA_POLISH " + label)
func frames(count: int = 5) -> void:
	for index: int in count: await process_frame

func geometry_valid(frame: Dictionary) -> bool:
	for command: Dictionary in frame.commands:
		for value: float in command.color:
			if not is_finite(value) or value < 0 or value > 1: return false
		var points: Array = command.get("points", [command.get("point", [0,0])])
		for point: Array in points:
			if not is_finite(float(point[0])) or not is_finite(float(point[1])): return false
			if absf(float(point[0])) > 48 or float(point[1]) < -58 or float(point[1]) > 49: return false
		if int(command.kind) == 2:
			var at := Vector2(float(command.point[0]),float(command.point[1]))
			var axes := Vector2(float(command.axes[0]),float(command.axes[1]))
			if at.x - axes.x < -48 or at.x + axes.x > 48 or at.y - axes.y < -58 or at.y + axes.y > 49: return false
		if int(command.kind) == 3:
			var polygon := PackedVector2Array()
			for point: Array in points: polygon.append(Vector2(float(point[0]),float(point[1])))
			if command.triangles.size() != (polygon.size() / 2 - 1) * 6: return false
			for index: int in command.triangles:
				if index < 0 or index >= polygon.size(): return false
			if command.alphas.size() != polygon.size(): return false
			for alpha: float in command.alphas:
				if not is_finite(alpha) or alpha < 0 or alpha > 1: return false
	return true

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_aura_polish_qa"): quit(2); return
	var signatures: Dictionary = {}
	var timing: Dictionary = {}
	for id: String in Visual.IDS:
		var model = Visual.new()
		model.build(id, 0)
		var first: Dictionary = model.snapshot()
		check(geometry_valid(first), id + " geometry finite and within the authored actor envelope")
		check(first.curves <= Visual.MAX_CURVES and first.commands.size() <= Visual.MAX_COMMANDS and first.vertices <= 2080, id + " bounded organic ribbon geometry")
		var no_outlines: bool = true
		for command: Dictionary in first.commands: no_outlines = no_outlines and int(command.kind) in [2,3]
		check(no_outlines, id + " only feathered light and gradient ribbons, no hard outlines")
		var pool: Array[int] = []
		for curve in model._curves: pool.append(curve.get_instance_id())
		var resize_count: int = model.buffer_resizes
		var samples: Array[int] = []
		var all_frames_valid: bool = true
		for index: int in 240:
			var started: int = Time.get_ticks_usec()
			model.build(id, float(index) / 30.0)
			samples.append(Time.get_ticks_usec() - started)
			all_frames_valid = all_frames_valid and geometry_valid(model.snapshot())
		check(all_frames_valid, id + " all animated ribbons have valid indices within the envelope")
		check(model.buffer_resizes == resize_count, id + " steady frames do not resize point buffers")
		var same_pool: bool = true
		for index: int in pool.size(): same_pool = same_pool and model._curves[index].get_instance_id() == pool[index]
		check(same_pool and model._commands.size() == Visual.MAX_COMMANDS, id + " reuses bounded geometry and command objects")
		model.build(id, 2.0)
		check(model.snapshot() != first, id + " motion changes the geometry")
		model.build(id, Visual.PERIOD)
		check(model.snapshot() == first, id + " seamless authored cycle")
		model.build(id, 0, true)
		var low: Dictionary = model.snapshot()
		model.build(id, 3.2, true)
		check(model.snapshot() == low and geometry_valid(low), id + " reduced effects is static and valid")
		check(low.commands.size() < first.commands.size() and low.vertices < first.vertices, id + " reduced effects lowers draw and geometry budgets")
		signatures[id] = JSON.stringify(low.commands)
		samples.sort()
		timing[id] = {"geometry_build_p95_usec":samples[int(samples.size() * 0.95)], "full_commands":first.commands.size(), "full_vertices":first.vertices, "reduced_commands":low.commands.size(), "reduced_vertices":low.vertices}
	var distinct: bool = true
	for id: String in Visual.IDS:
		for other: String in Visual.IDS:
			if id != other and signatures[id] == signatures[other]: distinct = false
	check(distinct, "all four silhouettes remain distinct even without animation")
	var empty = Visual.new()
	for id: String in ["plain", "unknown"]:
		empty.build(id, 1)
		check(empty.command_count == 0 and empty.curve_count == 0, id + " does not draw a cosmetic")
	var settings: Node = root.get_node("SettingsManager")
	var pavilion: Node = root.get_node("PavilionManager")
	var initial: Dictionary = pavilion.fixture_state.duplicate(true)
	var host := Node2D.new(); root.add_child(host)
	var live: Node2D = load("res://scripts/player/lin_yue_pavilion_aura_presentation.gd").new()
	host.add_child(live); await frames()
	check(not live.visible and not live.is_processing() and not live.is_physics_processing(), "plain live aura has no processing or physics")
	pavilion.fixture_state.id = "ascendant_aura"; pavilion.pavilion_changed.emit(); await frames()
	check(not live.visible, "unowned cosmetic cannot become visible")
	pavilion.fixture_state.owned.append("ascendant_aura"); pavilion.pavilion_changed.emit(); await frames()
	check(live.visible and live.is_processing() and live.get_child_count() == 0, "owned live aura uses one draw node without emitter children")
	settings.reduced_effects = true; settings.settings_changed.emit(); await frames()
	check(live.visible and not live.is_processing(), "battery aura stays visible without continuous updates")
	settings.reduced_effects = false; settings.settings_changed.emit(); host.hide(); await frames()
	check(not live.is_processing(), "hidden actor does not update its aura")
	host.show(); await frames()
	check(live.is_processing(), "visible actor resumes cosmetic motion")
	var preview: Control = load("res://scripts/ui/pavilion_aura_preview.gd").new()
	root.add_child(preview); preview.size = Vector2(280,210); await frames()
	check(preview.mouse_filter == Control.MOUSE_FILTER_IGNORE and preview.get_child_count() == 1, "preview keeps artwork out of the GUI input chain")
	check(preview._actor.sprite_frames == preview.FRAMES and preview._actor.is_playing(), "preview uses the real duration-aware idle animation")
	check(is_equal_approx(preview._actor.scale.x, preview._scale_value * 1.12) and preview._actor.position.is_equal_approx(preview._actor_origin + Vector2(0,-3) * preview._scale_value), "preview matches the production body transform")
	preview.show_aura("golden_aura"); await frames()
	var stable_clock: float = preview.clock
	preview.show_aura("golden_aura")
	check(preview.clock == stable_clock, "refreshing the selected aura cannot restart its animation")
	for dims: Vector2 in [Vector2(160,120), Vector2(280,210), Vector2(420,300)]:
		preview.size = dims; await frames()
		var valid: bool = true
		for id: String in Visual.IDS:
			preview._visual.build(id, 2)
			for command: Dictionary in preview._visual.snapshot().commands:
				for point: Array in command.get("points", [command.get("point", [0,0])]):
					var projected: Vector2 = preview._actor_origin + Vector2(float(point[0]),float(point[1])) * preview._scale_value
					valid = valid and Rect2(Vector2.ZERO, dims).has_point(projected)
		check(valid, "aura envelope fits preview " + str(dims))
	preview.hide(); await frames()
	check(not preview.is_processing() and not preview._actor.is_playing(), "hidden preview pauses both aura and idle sprite")
	check(pavilion.fixture_state.get("coins", 0) == initial.get("coins", 0) and pavilion.mutation_calls == 0, "presentation never calls a fixture economy mutation")
	preview.queue_free(); host.queue_free(); await frames()
	DirAccess.make_dir_recursive_absolute("res://.local/aura_output")
	var metadata := FileAccess.open("res://.local/aura_output/model_metrics.json", FileAccess.WRITE)
	metadata.store_string(JSON.stringify({"checks":checks, "failures":failures, "scope":"headless presentation fixture; not GPU/Android performance", "timing":timing}, "\t")); metadata.close()
	if "--export-geometry" in OS.get_cmdline_user_args(): export_geometry()
	print("AURA_POLISH checks=%d failures=%d; NATIVE_GUI=%s; PHONE=NOT_TESTED" % [checks, failures, str(DisplayServer.get_name() != "headless")])
	quit(1 if failures else 0)

func export_geometry() -> void:
	var file := FileAccess.open("res://.local/aura_output/geometry.jsonl", FileAccess.WRITE)
	var models: Array = []
	for id: String in Visual.IDS: models.append(Visual.new())
	for index: int in 240:
		var snapshots: Array = []
		for aura_index: int in Visual.IDS.size():
			models[aura_index].build(Visual.IDS[aura_index], float(index) / 30.0)
			snapshots.append(models[aura_index].snapshot())
		file.store_line(JSON.stringify({"time":float(index) / 30.0,"auras":snapshots}))
	file.close()
	var frames_data: SpriteFrames = preload("res://assets/character/player/player_lin_yue_idle_walk_spriteframes.tres")
	var animation: Array = []
	for index: int in frames_data.get_frame_count("idle_down"):
		var texture: AtlasTexture = frames_data.get_frame_texture("idle_down", index) as AtlasTexture
		animation.append({"duration":frames_data.get_frame_duration("idle_down",index) / frames_data.get_animation_speed("idle_down"),"source":texture.atlas.resource_path,"region":[texture.region.position.x,texture.region.position.y,texture.region.size.x,texture.region.size.y]})
	var actor_file := FileAccess.open("res://.local/aura_output/actor_frames.json", FileAccess.WRITE)
	actor_file.store_string(JSON.stringify(animation)); actor_file.close()
