extends RefCounted

const BACKGROUND_TEXTURE = preload(
	"res://assets/ui/main_menu/main_menu_key_art_lin_yue.png"
)

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"


static func build_shell(
	root: Control,
	eyebrow_text: String,
	title_text: String,
	subtitle_text: String,
	hero_icon: Texture2D = null
) -> Dictionary:
	var background := TextureRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.18, 0.27, 0.29, 1.0)
	root.add_child(background)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.001, 0.009, 0.014, 0.80)
	root.add_child(shade)

	var safe := MarginContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 28)
	safe.add_theme_constant_override("margin_top", 28)
	safe.add_theme_constant_override("margin_right", 28)
	safe.add_theme_constant_override("margin_bottom", 28)
	root.add_child(safe)

	var outer := VBoxContainer.new()
	outer.name = "Outer"
	outer.add_theme_constant_override("separation", 12)
	safe.add_child(outer)

	var top_row := HBoxContainer.new()
	top_row.custom_minimum_size = Vector2(0.0, 48.0)
	top_row.add_theme_constant_override("separation", 8)
	outer.add_child(top_row)

	var back_button := Button.new()
	back_button.custom_minimum_size = Vector2(104.0, 44.0)
	back_button.text = root.tr("‹  HOME")
	back_button.add_theme_font_size_override("font_size", 14)
	back_button.add_theme_stylebox_override(
		"normal",
		make_button_style(
			Color(0.002, 0.030, 0.040, 0.95),
			Color(0.30, 0.82, 0.72, 0.58)
		)
	)
	back_button.add_theme_stylebox_override(
		"hover",
		make_button_style(
			Color(0.006, 0.075, 0.078, 0.99),
			Color(0.96, 0.78, 0.34, 0.86)
		)
	)
	top_row.add_child(back_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var live_tag := Label.new()
	live_tag.text = root.tr("LIVE SERVICES")
	live_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	live_tag.add_theme_font_size_override("font_size", 11)
	live_tag.add_theme_color_override(
		"font_color",
		Color(0.50, 0.82, 0.76, 1.0)
	)
	top_row.add_child(live_tag)

	var hero_panel := PanelContainer.new()
	hero_panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.002, 0.024, 0.034, 0.95),
			Color(0.96, 0.76, 0.30, 0.55),
			14
		)
	)
	outer.add_child(hero_panel)

	var hero_margin := MarginContainer.new()
	hero_margin.add_theme_constant_override("margin_left", 18)
	hero_margin.add_theme_constant_override("margin_top", 15)
	hero_margin.add_theme_constant_override("margin_right", 18)
	hero_margin.add_theme_constant_override("margin_bottom", 15)
	hero_panel.add_child(hero_margin)

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 12)
	hero_margin.add_child(hero_row)

	if hero_icon != null:
		var hero_icon_rect := TextureRect.new()
		hero_icon_rect.custom_minimum_size = Vector2(82.0, 82.0)
		hero_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hero_icon_rect.texture = hero_icon
		hero_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero_row.add_child(hero_icon_rect)

	var hero_text := VBoxContainer.new()
	hero_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_text.add_theme_constant_override("separation", 3)
	hero_row.add_child(hero_text)

	var eyebrow := Label.new()
	eyebrow.text = eyebrow_text
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override(
		"font_color",
		Color(0.34, 0.90, 0.80, 1.0)
	)
	hero_text.add_child(eyebrow)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override(
		"font_color",
		Color(0.98, 0.82, 0.40, 1.0)
	)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_text.add_child(title)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override(
		"font_color",
		Color(0.72, 0.84, 0.81, 1.0)
	)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_text.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Per-screen override: sensitive enough to win against an accidental tap,
	# but not so sensitive that normal stationary taps become scroll gestures.
	scroll.scroll_deadzone = 4
	outer.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	_install_scroll_guard(scroll, content)

	return {
		"back_button": back_button,
		"content": content,
		"scroll": scroll,
	}


static func _install_scroll_guard(
	scroll: ScrollContainer,
	content: Control
) -> void:
	# ScrollContainer emits these signals specifically for touch drag scrolling.
	# While a drag is active, descendant buttons are temporarily disabled so a
	# release cannot also activate a card/action that the finger started on.
	var tracked_buttons: Array[Button] = []
	var disabled_before: Dictionary = {}

	scroll.scroll_started.connect(
		func() -> void:
			tracked_buttons.clear()
			disabled_before.clear()
			_collect_buttons(content, tracked_buttons)
			for button: Button in tracked_buttons:
				if not is_instance_valid(button):
					continue
				disabled_before[button] = button.disabled
				if not button.disabled:
					button.disabled = true
	)

	scroll.scroll_ended.connect(
		func() -> void:
			if not is_instance_valid(scroll):
				return
			var tree: SceneTree = scroll.get_tree()
			if tree == null:
				return
			var timer: SceneTreeTimer = tree.create_timer(
				0.06,
				true,
				false,
				true
			)
			timer.timeout.connect(
				func() -> void:
					for button: Button in tracked_buttons:
						if not is_instance_valid(button):
							continue
						button.disabled = bool(
							disabled_before.get(button, false)
						)
					tracked_buttons.clear()
					disabled_before.clear()
			)
	)


static func _collect_buttons(
	root: Node,
	target: Array[Button]
) -> void:
	for child: Node in root.get_children():
		if child is Button:
			target.append(child as Button)
		_collect_buttons(child, target)


static func clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func make_card(
	parent: Container,
	accent: Color = Color(0.30, 0.82, 0.72, 1.0)
) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(
			Color(0.002, 0.022, 0.032, 0.95),
			Color(accent.r, accent.g, accent.b, 0.42),
			12
		)
	)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 13)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	return box


static func add_label(
	parent: Container,
	text_value: String,
	font_size: int = 14,
	color: Color = Color(0.88, 0.94, 0.91, 1.0)
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


static func add_action_button(
	parent: Container,
	text_value: String,
	callback: Callable,
	primary: bool = false
) -> Button:
	var button := Button.new()
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.keep_pressed_outside = false
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = text_value
	button.add_theme_font_size_override(
		"font_size",
		15 if primary else 14
	)
	var accent: Color = (
		Color(0.96, 0.76, 0.30, 1.0)
		if primary
		else Color(0.30, 0.82, 0.72, 1.0)
	)
	button.add_theme_stylebox_override(
		"normal",
		make_button_style(
			Color(0.003, 0.040, 0.050, 0.96),
			Color(accent.r, accent.g, accent.b, 0.58)
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_button_style(
			Color(0.008, 0.085, 0.082, 0.99),
			Color(accent.r, accent.g, accent.b, 0.90)
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		make_button_style(
			Color(0.002, 0.028, 0.038, 1.0),
			Color(accent.r, accent.g, accent.b, 0.82)
		)
	)
	if callback.is_valid():
		button.pressed.connect(callback)
	parent.add_child(button)
	return button


static func make_panel_style(
	background: Color,
	border: Color,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 6
	return style


static func make_button_style(
	background: Color,
	border: Color
) -> StyleBoxFlat:
	var style := make_panel_style(background, border, 10)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


static func return_home(root: Node) -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		MAIN_MENU_SCENE,
		-1
	)
	if change_error != OK:
		push_error(
			"LiveOps UI: gagal kembali ke Home. Error code: "
			+ str(change_error)
		)
