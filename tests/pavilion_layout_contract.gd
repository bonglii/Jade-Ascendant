extends RefCounted
## Read actual engine layout, not requested minimum sizes or mock rectangles.
static func inspect(screen: Control) -> Array[String]:
	var errors: Array[String] = []
	var unit: float = screen._unit()
	var scroll: ScrollContainer = screen.scroll_container
	var bounds: Rect2 = scroll.get_global_rect()
	var more: Button = screen.content.find_child("PavilionMore",true,false) as Button
	for action: Button in [screen._focus_daily, more, screen._focus_target]:
		if action == null or not action.is_visible_in_tree(): continue
		var font: Font = action.get_theme_font("font")
		var font_size: int = action.get_theme_font_size("font_size")
		var skin: StyleBox = action.get_theme_stylebox("normal")
		var natural: float = font.get_string_size(action.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + skin.get_minimum_size().x
		if action.autowrap_mode != TextServer.AUTOWRAP_OFF: errors.append(action.name + ": compact action still wraps")
		if action.size.x + 2 < natural: errors.append(action.name + ": caption width %.1f < %.1f" % [action.size.x,natural])
		if action.size.y > 76 * unit: errors.append(action.name + ": vertical strip height %.1f" % action.size.y)
	if screen._focus_daily.get_parent().size.y > 80 * unit: errors.append("Header expands into a tall empty block")
	if screen.focus_tab == "summon" and not screen.paid_mode and screen._focus_target.get_parent().size.y > 80 * unit: errors.append("Target selector expands into a tall empty block")
	if screen.content.get_global_rect().end.x > bounds.end.x + 2: errors.append("Content overflows the horizontal viewport")
	_collect(screen.content, bounds, errors)
	return errors

static func _collect(node: Node, bounds: Rect2, errors: Array[String]) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Button and not node.text.is_empty():
		var rect: Rect2 = node.get_global_rect()
		if rect.position.x < bounds.position.x - 2 or rect.end.x > bounds.end.x + 2: errors.append(str(node.name) + ": button exceeds content width")
		if rect.size.x < 28 or rect.size.y < 28: errors.append(str(node.name) + ": collapsed text action")
		var font: Font = node.get_theme_font("font")
		var skin: StyleBox = node.get_theme_stylebox("normal")
		var paragraph := TextParagraph.new()
		paragraph.width = maxf(1,rect.size.x-skin.get_minimum_size().x)
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE if node.autowrap_mode != TextServer.AUTOWRAP_OFF else TextServer.BREAK_MANDATORY
		paragraph.add_string(node.text,font,node.get_theme_font_size("font_size"))
		if paragraph.get_size().y > rect.size.y-skin.get_minimum_size().y+2: errors.append(str(node.name) + ": text exceeds button height")
	for child: Node in node.get_children(): _collect(child,bounds,errors)

static func inspect_sheet(screen: Control) -> Array[String]:
	var errors: Array[String] = []
	var overlays: Array = [screen._focus_sheet, screen._target_overlay, screen.locked_rates_overlay, screen.locked_history_overlay]
	for overlay in overlays:
		if not is_instance_valid(overlay) or not overlay.visible: continue
		var panel: Control = overlay.get_meta("panel") if overlay.has_meta("panel") else _first_panel(overlay)
		if panel == null: errors.append("Sheet lacks bounded panel"); continue
		var rect: Rect2 = panel.get_global_rect()
		if not screen.get_global_rect().grow(1).encloses(rect): errors.append("Sheet exceeds viewport: " + str(rect))
	return errors

static func _first_panel(node: Node) -> PanelContainer:
	if node is PanelContainer: return node
	for child: Node in node.get_children():
		var found: PanelContainer = _first_panel(child)
		if found != null: return found
	return null
