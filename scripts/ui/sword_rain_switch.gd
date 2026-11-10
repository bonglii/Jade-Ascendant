extends Button

var _second_finger: int = -1

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(86.0, 49.0)
	visibility_changed.connect(func(): _second_finger = -1)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.105, 0.12, 0.95)
	style.border_color = Color(0.80, 0.67, 0.37, 0.84)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	add_theme_stylebox_override("normal", style)
	add_theme_color_override("font_color", Color(0.81, 0.97, 0.94))

func _input(event: InputEvent) -> void:
	# Primary touch uses Button mouse emulation. Handle the independent second
	# finger even when another Control owns the primary drag.
	if not event is InputEventScreenTouch or event.index == 0 or not is_visible_in_tree() or disabled or get_tree().paused:
		return
	var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	var inside := Rect2(Vector2.ZERO, size).has_point(point)
	if event.pressed and inside and _second_finger < 0:
		_second_finger = event.index
		get_viewport().set_input_as_handled()
	elif not event.pressed and _second_finger == event.index:
		_second_finger = -1
		get_viewport().set_input_as_handled()
		if inside and not event.canceled:
			pressed.emit()
