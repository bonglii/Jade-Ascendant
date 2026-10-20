extends RefCounted
## Shared native touch-scroll policy. No gesture emulation or reward callbacks.
const DEADZONE: int = 6

static func configure(scroll: ScrollContainer) -> void:
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = DEADZONE
	scroll.follow_focus = false
	scroll.clip_contents = true
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	# A project-wide theme must not add a rectangular matte behind a list.
	if not scroll.has_meta("jade_shared_scroll"):
		scroll.set_meta("jade_shared_scroll", true)
		scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

static func ancestor(control: Node) -> ScrollContainer:
	var node: Node = control.get_parent()
	while node != null:
		if node is Viewport: return null
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null

static func prepare(control: Control) -> void:
	if control is ScrollContainer:
		configure(control)
		return
	if ancestor(control) == null or control is ScrollBar or control.has_meta("jade_preserve_touch_input"):
		return
	if control is BaseButton:
		# IGNORE marks decorative arrows/overlays; do not create a second target.
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
		control.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		control.keep_pressed_outside = false
	elif control is LineEdit or control is TextEdit or control is Slider or control is ItemList or control is Tree:
		return
	elif control is RichTextLabel and control.selection_enabled:
		return
	elif not control.gui_input.get_connections().is_empty():
		return
	else:
		var script: Script = control.get_script()
		if script != null:
			for method: Dictionary in script.get_script_method_list():
				if method.name == "_gui_input": return
		# Layout, artwork and labels must never become dead drag zones.
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func prepare_tree(node: Node) -> void:
	if node is Control:
		prepare(node)
	for child: Node in node.get_children():
		prepare_tree(child)
