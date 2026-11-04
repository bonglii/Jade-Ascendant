extends "res://scripts/ui/virtual_joystick.gd"
## Reuses the combat artwork, without registering or releasing gameplay input.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, 208)
	_authored_base_radius = base_radius
	_authored_knob_radius = knob_radius
	_refresh_preview()

func _refresh_preview() -> void:
	_apply_control_preferences()
	floating_center = Vector2(size.x * 0.5, size.y * 0.5)
	raw_offset = Vector2(0.4, -0.2) * base_radius
	queue_redraw()

func _process(_delta: float) -> void:
	if _prefs_revision != ControlPrefs.revision:
		_refresh_preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_refresh_preview()

func _is_engaged() -> bool:
	return true

func _input(_event: InputEvent) -> void:
	pass

func _exit_tree() -> void:
	pass
