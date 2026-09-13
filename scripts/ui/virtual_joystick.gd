extends Control

## Floating Virtual Joystick
## Mobile movement layer untuk gameplay portrait.
## Sentuhan pertama di area bawah gameplay menjadi pusat joystick sementara.
## Analog strength tetap dirutekan ke ui_left/ui_right/ui_up/ui_down sehingga
## player_1.gd, keyboard, dan controller path tidak perlu diubah.

const ACTION_LEFT: StringName = &"ui_left"
const ACTION_RIGHT: StringName = &"ui_right"
const ACTION_UP: StringName = &"ui_up"
const ACTION_DOWN: StringName = &"ui_down"
const INVALID_TOUCH_INDEX: int = -1

@export_range(0.0, 0.8, 0.01) var deadzone: float = 0.18
@export_range(32.0, 128.0, 1.0) var base_radius: float = 72.0
@export_range(12.0, 64.0, 1.0) var knob_radius: float = 27.0
@export_range(0.35, 1.0, 0.01) var activation_width_ratio: float = 1.0
@export_range(0.25, 0.75, 0.01) var activation_top_ratio: float = 0.42
@export_range(0.0, 40.0, 1.0) var edge_padding: float = 14.0

var active_touch_index: int = INVALID_TOUCH_INDEX
var mouse_dragging: bool = false
var raw_offset: Vector2 = Vector2.ZERO
var movement_vector: Vector2 = Vector2.ZERO
var floating_center: Vector2 = Vector2.ZERO
var input_ready: bool = false
var platform_visible: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	platform_visible = _should_show_for_platform()
	input_ready = _validate_actions()
	visible = platform_visible and input_ready and not get_tree().paused
	floating_center = _get_idle_center()
	queue_redraw()

	if input_ready:
		DebugLogger.system(str("Floating Virtual Joystick aktif! Full-width lower zone -> ui_* actions."))

func _exit_tree() -> void:
	_release_pointer()
	_release_actions()

func _process(_delta: float) -> void:
	var should_be_visible: bool = (
		platform_visible
		and input_ready
		and not get_tree().paused
	)

	if visible != should_be_visible:
		visible = should_be_visible
		if not visible:
			_release_pointer()
			_release_actions()
			queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_pointer()
		_release_actions()
		queue_redraw()
	if what == NOTIFICATION_RESIZED and not _is_engaged():
		floating_center = _get_idle_center()
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not input_ready:
		return

	# Release harus tetap diterima walau modal/pause muncul di tengah drag supaya
	# simulated ui_* actions tidak pernah tertinggal.
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if not touch_event.pressed and touch_event.index == active_touch_index:
			_release_pointer()
			_release_actions()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if (
			mouse_button.button_index == MOUSE_BUTTON_LEFT
			and not mouse_button.pressed
			and mouse_dragging
		):
			_release_pointer()
			_release_actions()
			get_viewport().set_input_as_handled()
			return

	if not visible or get_tree().paused:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
		return

	if event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
		return

	# Mouse support untuk editor/desktop verification. Android memakai touch asli.
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if not event.pressed:
		return

	if active_touch_index != INVALID_TOUCH_INDEX:
		return

	if not _is_inside_activation_zone(event.position):
		return

	active_touch_index = event.index
	_begin_at_viewport_position(event.position)
	get_viewport().set_input_as_handled()

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != active_touch_index:
		return

	_update_from_viewport_position(event.position)
	get_viewport().set_input_as_handled()

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	if mouse_dragging:
		return

	if not _is_inside_activation_zone(event.position):
		return

	mouse_dragging = true
	_begin_at_viewport_position(event.position)
	get_viewport().set_input_as_handled()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not mouse_dragging:
		return

	_update_from_viewport_position(event.position)
	get_viewport().set_input_as_handled()

func _begin_at_viewport_position(viewport_position: Vector2) -> void:
	var local_position: Vector2 = _viewport_to_local(viewport_position)
	floating_center = _clamp_center_to_safe_bounds(local_position)
	raw_offset = Vector2.ZERO
	movement_vector = Vector2.ZERO
	_release_actions()
	queue_redraw()

func _update_from_viewport_position(viewport_position: Vector2) -> void:
	var local_position: Vector2 = _viewport_to_local(viewport_position)
	var offset_from_center: Vector2 = local_position - floating_center
	var limited_offset: Vector2 = offset_from_center.limit_length(base_radius)
	raw_offset = limited_offset

	var normalized: Vector2 = limited_offset / maxf(base_radius, 1.0)
	var magnitude: float = normalized.length()

	if magnitude <= deadzone:
		movement_vector = Vector2.ZERO
	else:
		var remapped_strength: float = inverse_lerp(deadzone, 1.0, magnitude)
		movement_vector = normalized.normalized() * clampf(
			remapped_strength,
			0.0,
			1.0
		)

	_apply_actions(movement_vector)
	queue_redraw()

func _apply_actions(direction: Vector2) -> void:
	_apply_axis_action(ACTION_LEFT, maxf(-direction.x, 0.0))
	_apply_axis_action(ACTION_RIGHT, maxf(direction.x, 0.0))
	_apply_axis_action(ACTION_UP, maxf(-direction.y, 0.0))
	_apply_axis_action(ACTION_DOWN, maxf(direction.y, 0.0))

func _apply_axis_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _release_actions() -> void:
	Input.action_release(ACTION_LEFT)
	Input.action_release(ACTION_RIGHT)
	Input.action_release(ACTION_UP)
	Input.action_release(ACTION_DOWN)
	movement_vector = Vector2.ZERO

func _release_pointer() -> void:
	active_touch_index = INVALID_TOUCH_INDEX
	mouse_dragging = false
	raw_offset = Vector2.ZERO
	movement_vector = Vector2.ZERO
	floating_center = _get_idle_center()
	queue_redraw()

func _viewport_to_local(viewport_position: Vector2) -> Vector2:
	return (
		get_global_transform_with_canvas().affine_inverse()
		* viewport_position
	)

func _is_inside_activation_zone(viewport_position: Vector2) -> bool:
	var local_position: Vector2 = _viewport_to_local(viewport_position)
	var zone_width: float = size.x * activation_width_ratio
	var zone_top: float = size.y * activation_top_ratio
	return (
		local_position.x >= 0.0
		and local_position.x <= zone_width
		and local_position.y >= zone_top
		and local_position.y <= size.y
	)

func _clamp_center_to_safe_bounds(local_position: Vector2) -> Vector2:
	var minimum_margin: float = base_radius + edge_padding
	var min_x: float = minimum_margin
	var max_x: float = maxf(size.x - minimum_margin, min_x)
	var min_y: float = minimum_margin
	var max_y: float = maxf(size.y - minimum_margin, min_y)
	return Vector2(
		clampf(local_position.x, min_x, max_x),
		clampf(local_position.y, min_y, max_y)
	)

func _get_idle_center() -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO

	var minimum_margin: float = base_radius + edge_padding
	return Vector2(
		minimum_margin,
		maxf(size.y - minimum_margin, minimum_margin)
	)

func _is_engaged() -> bool:
	return active_touch_index != INVALID_TOUCH_INDEX or mouse_dragging

func _should_show_for_platform() -> bool:
	# Editor ikut aktif supaya floating placement bisa dites dengan mouse.
	return (
		OS.has_feature("mobile")
		or OS.has_feature("editor")
		or DisplayServer.is_touchscreen_available()
	)

func _validate_actions() -> bool:
	var required_actions: Array[StringName] = [
		ACTION_LEFT,
		ACTION_RIGHT,
		ACTION_UP,
		ACTION_DOWN
	]

	for action_value in required_actions:
		var action: StringName = action_value
		if not InputMap.has_action(action):
			push_warning(
				"Floating Virtual Joystick: Input action %s tidak tersedia."
				% String(action)
			)
			return false

	return true

func _draw() -> void:
	# Floating joystick tidak menampilkan base statis. Ia baru muncul di lokasi
	# sentuhan pertama sehingga ibu jari tidak perlu mencari titik fixed.
	if not _is_engaged():
		return

	var center: Vector2 = floating_center
	var outer_gold: Color = Color(0.96, 0.73, 0.18, 0.72)
	var jade_line: Color = Color(0.12, 0.88, 0.72, 0.72)
	var base_fill: Color = Color(0.004, 0.035, 0.045, 0.58)
	var inner_fill: Color = Color(0.008, 0.09, 0.10, 0.68)
	var knob_fill: Color = Color(0.03, 0.42, 0.36, 0.90)
	var knob_core: Color = Color(0.15, 0.92, 0.72, 0.88)

	draw_circle(center, base_radius + 10.0, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(center, base_radius, base_fill)
	draw_arc(center, base_radius, 0.0, TAU, 72, outer_gold, 2.2, true)
	draw_arc(center, base_radius - 8.0, 0.0, TAU, 72, jade_line, 1.2, true)
	draw_circle(center, base_radius * 0.43, inner_fill)

	for index_value in range(4):
		var index: int = int(index_value)
		var angle: float = PI * 0.5 * float(index)
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var start_point: Vector2 = center + direction * (base_radius - 17.0)
		var end_point: Vector2 = center + direction * (base_radius - 9.0)
		draw_line(start_point, end_point, outer_gold, 2.0, true)

	var knob_position: Vector2 = center + raw_offset
	draw_circle(
		knob_position + Vector2(0.0, 3.0),
		knob_radius + 4.0,
		Color(0.0, 0.0, 0.0, 0.28)
	)
	draw_circle(knob_position, knob_radius + 3.0, outer_gold)
	draw_circle(knob_position, knob_radius, knob_fill)
	draw_circle(knob_position, knob_radius * 0.28, knob_core)
