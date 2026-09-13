extends Control
## Attach to a full-rect UI layer whose direct parent is a Control.
## Keep full-screen artwork outside this layer.

const REFRESH_INTERVAL: float = 0.25

var _refresh_elapsed: float = 0.0
var _mobile_display: bool = false

func _ready() -> void:
	_mobile_display = OS.has_feature("android") or OS.has_feature("ios")
	get_viewport().size_changed.connect(_queue_refresh)
	var parent_control: Control = get_parent_control()
	if parent_control != null:
		parent_control.resized.connect(_queue_refresh)
	set_process(_mobile_display)
	refresh_safe_area()
	_queue_refresh()

func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= REFRESH_INTERVAL:
		_refresh_elapsed = 0.0
		refresh_safe_area()

func _queue_refresh() -> void:
	refresh_safe_area.call_deferred()

func refresh_safe_area() -> void:
	if not is_inside_tree():
		return
	var parent_control: Control = get_parent_control()
	if parent_control == null or not parent_control.size.x > 0.0 or not parent_control.size.y > 0.0:
		return
	var available_rect: Rect2 = Rect2(Vector2.ZERO, parent_control.size)
	var content_rect: Rect2 = available_rect
	if _mobile_display:
		var display_safe_rect: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		var parent_to_screen: Transform2D = parent_control.get_screen_transform()
		if display_safe_rect.has_area() and not is_zero_approx(parent_to_screen.determinant()):
			var local_safe_rect: Rect2 = parent_to_screen.affine_inverse() * display_safe_rect
			var intersection_rect: Rect2 = available_rect.intersection(local_safe_rect)
			if intersection_rect.has_area():
				content_rect = intersection_rect
	# Assign absolute insets, never accumulate padding on subsequent refreshes.
	offset_left = content_rect.position.x
	offset_top = content_rect.position.y
	offset_right = content_rect.end.x - available_rect.end.x
	offset_bottom = content_rect.end.y - available_rect.end.y
