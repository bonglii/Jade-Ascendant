extends CanvasLayer
## Plain-text broadcasts share existing mail authentication and wait for safe menus.
var _owner: String = ""
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _session_seen: Dictionary = {}
var _epoch: int = 0
var _epoch_ticks: int = 0
var _next_at: int = 0
var _check_left: float = 0.0
var _shade: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: Label
var _kind: Label
var _scroll: ScrollContainer
var _button: Button
var _margin: MarginContainer
var _scroll_positions: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	hide()

func set_account_owner(account_owner: String) -> void:
	if account_owner == _owner: return
	_owner = account_owner
	_queue.clear()
	_current.clear()
	_session_seen.clear()
	_scroll_positions.clear()
	hide()

func _valid_entry(value: Variant) -> bool:
	if not value is Dictionary: return false
	var id: String = str(value.get("id", ""))
	if id.length() != 32: return false
	for character: String in id:
		if not "0123456789abcdef".contains(character): return false
	if value.get("kind") not in ["notice", "event", "maintenance"]: return false
	for key: String in ["title", "body"]:
		if not value.get(key) is String or str(value[key]).strip_edges().is_empty(): return false
	if str(value.title).length() > 100 or str(value.body).length() > 4000: return false
	for key: String in ["starts_at", "expires_at"]:
		if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT]: return false
		var number: float = float(value[key])
		if not is_finite(number) or number <= 0 or floorf(number) != number: return false
	return int(value.expires_at) > int(value.starts_at) and value.get("cancelled", false) == false

func accept_snapshot(account_owner: String, entries: Variant, server_time: int) -> bool:
	if account_owner.is_empty() or account_owner != ServerMailManager.get_announcement_owner() or not entries is Array or entries.size() > 20 or server_time <= 0: return false
	var ids: Dictionary = {}
	for entry: Variant in entries:
		if not _valid_entry(entry) or ids.has(str(entry.id)): return false
		ids[str(entry.id)] = true
	set_account_owner(account_owner)
	_epoch = server_time
	_epoch_ticks = Time.get_ticks_msec()
	_queue.clear()
	if not _current.is_empty() and not ids.has(str(_current.id)):
		_current.clear()
		hide()
	for entry: Dictionary in entries:
		var id: String = str(entry.id)
		if not _session_seen.has(id) and not ServerMailManager.is_announcement_seen(id) and (_current.is_empty() or id != str(_current.id)):
			_queue.append(entry.duplicate(true))
	return true

func _now() -> int:
	return _epoch + maxi(0, int(float(Time.get_ticks_msec() - _epoch_ticks) / 1000.0))

func _blocked() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null or get_tree().paused or SceneTransitionManager.is_transitioning: return true
	if get_tree().get_first_node_in_group("player") != null: return true
	if scene.scene_file_path != "res://scenes/ui/main_menu.tscn": return true
	for node: Node in scene.find_children("*", "Control", true, false):
		if not (node is PanelContainer or node is ColorRect or node is Container): continue
		var name_value: String = str(node.name).to_lower()
		if not ("popup" in name_value or "modal" in name_value or "confirm" in name_value or "overlay" in name_value or "dialog" in name_value): continue
		var control: Control = node as Control
		if control is ColorRect and (control as ColorRect).color.a <= 0.01: continue
		if control.is_visible_in_tree() and control.modulate.a > 0.01 and control.size.length() > 20 and control.mouse_filter != Control.MOUSE_FILTER_IGNORE: return true
	return false

func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0: return
	_check_left = 0.2
	if _owner != ServerMailManager.get_announcement_owner(): set_account_owner(ServerMailManager.get_announcement_owner())
	if _queue.is_empty() and _current.is_empty(): return
	if not _current.is_empty() and int(_current.expires_at) <= _now():
		_current.clear()
		hide()
	if _blocked():
		if not _current.is_empty():
			_scroll_positions[str(_current.id)] = _scroll.scroll_vertical
			_queue.push_front(_current)
			_current = {}
			hide()
		return
	if not _current.is_empty() or Time.get_ticks_msec() < _next_at: return
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		if int(entry.starts_at) <= _now() and int(entry.expires_at) > _now():
			_current = entry
			_present()
			break

func _present() -> void:
	if not is_instance_valid(_panel): _build()
	_title.text = str(_current.title)
	_body.text = str(_current.body)
	var kinds: Dictionary = {"notice": "SANCTUARY NOTICE", "event": "EVENT ANNOUNCEMENT", "maintenance": "MAINTENANCE NOTICE"}
	var kinds_id: Dictionary = {"notice": "PENGUMUMAN SANCTUARY", "event": "PENGUMUMAN EVENT", "maintenance": "INFO PEMELIHARAAN"}
	_kind.text = str((kinds_id if SettingsManager.language == "id" else kinds).get(_current.kind))
	_button.text = "MENGERTI" if SettingsManager.language == "id" else "GOT IT"
	_fit()
	show()
	_scroll.set_deferred("scroll_vertical", int(_scroll_positions.get(str(_current.id), 0)))
	_button.grab_focus()

func _dismiss() -> void:
	if _current.is_empty(): return
	var id: String = str(_current.id)
	_session_seen[id] = true
	ServerMailManager.dismiss_announcement(id, _owner)
	_current.clear()
	_next_at = Time.get_ticks_msec() + 350
	hide()

func _input(event: InputEvent) -> void:
	if visible and not _current.is_empty() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_dismiss()
		get_viewport().set_input_as_handled()

func _build() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0.005, 0.025, 0.025, 0.84)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_panel = PanelContainer.new()
	_panel.name = "SanctuaryAnnouncement"
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_shade.add_child(_panel)
	var frame := TextureRect.new()
	frame.texture = load("res://assets/ui/results/quiet/jade.svg")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(frame)
	_margin = MarginContainer.new()
	_panel.add_child(_margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_margin.add_child(box)
	_kind = _label(11, Color(0.42, 0.92, 0.73))
	box.add_child(_kind)
	_title = _label(23, Color(1.0, 0.89, 0.64))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 10
	box.add_child(_scroll)
	var reading := VBoxContainer.new()
	reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading.add_theme_constant_override("separation", 16)
	_scroll.add_child(reading)
	reading.add_child(_title)
	_body = _label(16, Color(0.85, 0.93, 0.87))
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading.add_child(_body)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(0, 52)
	_button.add_theme_stylebox_override("normal", _style(Color(0.12, 0.32, 0.25), Color(0.93, 0.76, 0.39), 2))
	_button.add_theme_stylebox_override("hover", _style(Color(0.17, 0.40, 0.30), Color(1.0, 0.87, 0.53), 2))
	_button.add_theme_stylebox_override("pressed", _style(Color(0.04, 0.17, 0.13), Color(0.42, 0.84, 0.64), 2))
	_button.pressed.connect(_dismiss)
	box.add_child(_button)
	preload("res://scripts/ui/result_ceremony.gd").style_button(_button, "jade")
	get_viewport().size_changed.connect(_fit)

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 14
	return style

func _fit() -> void:
	if not is_instance_valid(_panel): return
	var area: Rect2 = get_viewport().get_visible_rect()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window: Vector2i = DisplayServer.window_get_size()
	var inset_top: float = 16.0
	var inset_bottom: float = 16.0
	if safe.size.y > 0 and window.y > 0:
		inset_top = maxf(16.0, float(safe.position.y) * area.size.y / float(window.y))
		inset_bottom = maxf(16.0, float(maxi(0, window.y - safe.end.y)) * area.size.y / float(window.y))
	var desired := Vector2(minf(460.0, area.size.x - 32.0), minf(620.0, area.size.y - inset_top - inset_bottom))
	_margin.add_theme_constant_override("margin_left", 24)
	_margin.add_theme_constant_override("margin_right", 24)
	_margin.add_theme_constant_override("margin_top", 28)
	_margin.add_theme_constant_override("margin_bottom", 24)
	_panel.size = desired
	_panel.position = Vector2((area.size.x - desired.x) * 0.5, inset_top + (area.size.y - inset_top - inset_bottom - desired.y) * 0.5)
