extends Button

const DRAG_CANCEL_DISTANCE: float = 12.0
var _second_finger: int = -1
var _touch_origin: Vector2
var _touch_cancelled: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(86.0, 49.0)
	visibility_changed.connect(_reset_touch)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.105, 0.12, 0.95)
	style.border_color = Color(0.80, 0.67, 0.37, 0.84)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	add_theme_stylebox_override("normal", style)
	add_theme_color_override("font_color", Color(0.81, 0.97, 0.94))

func _reset_touch() -> void:
	_second_finger = -1
	_touch_cancelled = false
	self_modulate = Color.WHITE

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_reset_touch()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled or get_tree().paused:
		_reset_touch()
		return
	# Primary touch uses Button mouse emulation. The independent second finger
	# must cancel its tap after a drag, just as the shared menu controls do.
	if event is InputEventScreenDrag and event.index == _second_finger:
		if event.position.distance_to(_touch_origin) > DRAG_CANCEL_DISTANCE:
			_touch_cancelled = true
			self_modulate = Color.WHITE
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventScreenTouch or event.index == 0:
		return
	var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	var inside := Rect2(Vector2.ZERO, size).has_point(point)
	if event.pressed and inside and _second_finger < 0:
		_second_finger = event.index
		_touch_origin = event.position
		_touch_cancelled = false
		self_modulate = Color(0.78, 1.0, 0.91)
		get_viewport().set_input_as_handled()
	elif not event.pressed and _second_finger == event.index:
		var tapped: bool = inside and not event.canceled and not _touch_cancelled
		_reset_touch()
		get_viewport().set_input_as_handled()
		if tapped:
			pressed.emit()
