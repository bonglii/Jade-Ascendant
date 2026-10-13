extends Node
## Shared presentation, responsive scrolling and fixed actions. No reward authority.
var _host: CanvasLayer
var _mode: String
var _panel: PanelContainer
var _safe: Control
var _margin: MarginContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _seal: TextureRect

func configure(host: CanvasLayer, mode: String) -> void:
	_host = host
	_mode = mode

func _ready() -> void:
	_host.set_meta("ja_clean_popup_v3", true)
	_panel = _host.get_node("ColorRect/SafeArea/CenterContainer/Panel")
	_safe = _host.get_node("ColorRect/SafeArea")
	_margin = _panel.get_node("Margin")
	_content = _margin.get_node("Content")
	var empty := StyleBoxEmpty.new()
	_panel.add_theme_stylebox_override("panel", empty)
	var frame := TextureRect.new()
	frame.name = "CeremonialResultFrame"
	frame.texture = load("res://assets/ui/results/premium_v2/frame_%s.png" % ("crimson" if _mode == "defeat" else "jade"))
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(frame)
	_panel.move_child(frame, 0)
	_scroll = ScrollContainer.new()
	_scroll.name = "ResultScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 80)
	_scroll.scroll_deadzone = 10
	_body = VBoxContainer.new()
	_body.name = "ResultBody"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)
	var children: Array[Node] = _content.get_children()
	_content.add_child(_scroll)
	_content.move_child(_scroll, 0)
	for child: Node in children:
		if child is Button or child.name == "VictoryEncoreOffer": continue
		child.reparent(_body)
	_content.add_theme_constant_override("separation", 8)
	for label: Label in _content.find_children("*", "Label", true, false):
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal = _host.get("victory_seal" if _mode == "victory" else "defeat_seal") as TextureRect
	if _seal != null:
		_seal.texture = load("res://assets/ui/results/premium_v2/hero_%s.png" % _mode)
		_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_seal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_seal.custom_minimum_size = Vector2(0, 96)
	var title: Label = _host.get("victory_label" if _mode == "victory" else "game_over_label") as Label
	title.add_theme_font_size_override("font_size", 36 if _mode == "victory" else 30)
	for button: Button in _content.find_children("*", "Button", true, false):
		var primary: bool = button == _host.get("main_menu_button") if _mode == "victory" else button == _host.get("retry_button")
		style_button(button, ("red" if _mode == "defeat" else "jade") if primary else "navy")
	_safe.resized.connect(fit)
	fit()
	fit.call_deferred()

static func style_button(button: Button, palette: String) -> void:
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 17)
	for pair: Array in [["normal", "normal"], ["hover", "hover"], ["pressed", "pressed"], ["disabled", "pressed"]]:
		var style := StyleBoxTexture.new()
		style.texture = load("res://assets/ui/results/premium_v2/%s_%s.png" % [palette, pair[1]])
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		button.add_theme_stylebox_override(str(pair[0]), style)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color(1.0, 0.94, 0.72))
	button.add_theme_color_override("font_disabled_color", Color(0.50, 0.63, 0.60))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color(1.0, 0.88, 0.58)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(10)
	button.add_theme_stylebox_override("focus", focus)

func fit() -> void:
	if not is_instance_valid(_safe) or _safe.size.x <= 1: return
	var desired := Vector2(minf(544, _safe.size.x - 24), minf(840, _safe.size.y - 24))
	_panel.custom_minimum_size = desired
	_margin.add_theme_constant_override("margin_left", int(desired.x * 0.145))
	_margin.add_theme_constant_override("margin_right", int(desired.x * 0.145))
	_margin.add_theme_constant_override("margin_top", int(desired.y * 0.18))
	_margin.add_theme_constant_override("margin_bottom", int(desired.y * 0.115))
	if _seal != null:
		_seal.custom_minimum_size = Vector2(0, 96)
	var grid: GridContainer = _host.get("reward_chip_row") as GridContainer if _mode == "victory" else null
	if grid != null: grid.columns = 2 if desired.x * 0.71 >= 350 else 1
