extends Control
## Shared read-only sheet: bounded content, native scrolling and reversible Back.
var content: VBoxContainer
var actions: VBoxContainer
var _safe: Control
var _panel: PanelContainer
var _previous_back: Callable
static func create(host: Node, title: String, node_name: String) -> Control:
	var sheet = load("res://scripts/ui/player_sheet.gd").new()
	sheet.name = node_name
	host.add_child(sheet)
	sheet.content.add_child(sheet.label(title,24,Color("ead19a")))
	return sheet
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 500
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.002,0.014,0.02,.94)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe = Control.new()
	_safe.name = "DeviceSafeArea"
	_safe.set_script(preload("res://scripts/ui/mobile_safe_area.gd"))
	add_child(_safe)
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe.resized.connect(_fit)
	_panel = PanelContainer.new()
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("061c22")
	skin.border_color = Color("8baf96")
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(18)
	for edge: String in ["left","right","top","bottom"]:
		skin.set("content_margin_"+edge,16)
	_panel.add_theme_stylebox_override("panel",skin)
	_safe.add_child(_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	_panel.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.name = "PlayerSheetScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation",6)
	body.add_child(actions)
	var close := button("TUTUP" if SettingsManager.language == "id" else "CLOSE")
	close.name = "PlayerSheetClose"
	close.pressed.connect(queue_free)
	body.add_child(close)
	_previous_back = SceneTransitionManager.back_handler
	SceneTransitionManager.set_back_handler(queue_free)
	resized.connect(_fit)
	_fit()
	preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(self)
func _fit() -> void:
	if _panel == null:return
	var available: Vector2 = _safe.size if _safe != null else size
	var dimensions := Vector2(minf(560,maxf(200,available.x-24)),maxf(220,available.y-40))
	_panel.size = dimensions
	_panel.position = (available-dimensions)*.5
func label(value: String, font_size: int = 16, ink: Color = Color("d0ddcf")) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",ink)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
func button(value: String) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size.y = 48
	node.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.theme_type_variation = &"JadeSecondaryButton"
	return node
func _exit_tree() -> void:
	if SceneTransitionManager.back_handler == Callable(self,"queue_free"):
		SceneTransitionManager.set_back_handler(_previous_back if _previous_back.is_valid() else Callable())
