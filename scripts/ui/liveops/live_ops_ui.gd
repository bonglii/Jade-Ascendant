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
	hero_icon: Texture2D = null,
	accent: Color = Color(0.34, 0.90, 0.80, 1.0),
	event_background: Texture2D = null
) -> Dictionary:
	if bool(root.get_meta("liveops_popup", false)):
		return _build_popup_shell(
			root,
			eyebrow_text,
			title_text,
			subtitle_text,
			hero_icon,
			accent,
			event_background
		)

	var background := TextureRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture = BACKGROUND_TEXTURE
	if event_background != null:
		background.texture = event_background
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.18, 0.27, 0.29, 1.0)
	if event_background != null:
		background.modulate = Color(0.72, 0.78, 0.72, 1.0)
	root.add_child(background)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.001, 0.009, 0.014, 0.80)
	if event_background != null:
		shade.color = Color(0.001, 0.009, 0.014, 0.50)
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


	var hero_panel := PanelContainer.new()
	var hero_style := make_panel_style(
		Color(0.004, 0.032, 0.042, 0.98),
		Color(accent.r, accent.g, accent.b, 0.78),
		16
	)
	hero_style.border_width_left = 2
	hero_style.border_width_top = 2
	hero_style.border_width_right = 2
	hero_style.border_width_bottom = 2
	hero_style.shadow_size = 10
	hero_panel.add_theme_stylebox_override("panel", hero_style)
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
	eyebrow.add_theme_color_override("font_color", accent)
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
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Keep drag acquisition responsive on mobile while descendant controls
	# propagate touch input back to the owning ScrollContainer.
	scroll.scroll_deadzone = 4
	scroll.follow_focus = false
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	outer.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	_install_scroll_guard(scroll, content)

	return {
		"back_button": back_button,
		"content": content,
		"scroll": scroll,
	}


static func _build_popup_shell(
	root: Control,
	eyebrow_text: String,
	title_text: String,
	subtitle_text: String,
	hero_icon: Texture2D,
	accent: Color,
	event_background: Texture2D
) -> Dictionary:
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.name = "ModalScrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.color = Color(0.0, 0.0, 0.0, 0.66)
	root.add_child(scrim)

	var panel := PanelContainer.new()
	panel.name = "LiveOpsPopup"
	panel.anchor_left = 0.065
	panel.anchor_top = 0.10
	panel.anchor_right = 0.935
	panel.anchor_bottom = 0.90
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := make_panel_style(Color(0.002, 0.018, 0.027, 0.99), Color(0.90, 0.70, 0.30, 0.72), 20)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style)
	panel.clip_contents = true
	root.add_child(panel)

	if event_background != null:
		_add_event_realm_backdrop(
			panel,
			event_background
		)

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 44.0
	outer.add_child(top)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close := Button.new()
	close.custom_minimum_size = Vector2(44.0, 44.0)
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 23)
	close.add_theme_stylebox_override("normal", make_button_style(Color(0.002, 0.030, 0.040, 0.94), Color(0.34, 0.78, 0.70, 0.50)))
	top.add_child(close)

	var hero := PanelContainer.new()
	var hero_style := make_panel_style(
		Color(0.005, 0.034, 0.043, 0.985),
		Color(accent.r, accent.g, accent.b, 0.82),
		16
	)
	hero_style.border_width_left = 2
	hero_style.border_width_top = 2
	hero_style.border_width_right = 2
	hero_style.border_width_bottom = 2
	hero_style.shadow_size = 10
	hero.add_theme_stylebox_override("panel", hero_style)
	outer.add_child(hero)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 14)
	hm.add_theme_constant_override("margin_top", 10)
	hm.add_theme_constant_override("margin_right", 14)
	hm.add_theme_constant_override("margin_bottom", 10)
	hero.add_child(hm)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 10)
	hm.add_child(hr)
	if hero_icon != null:
		var icon_frame := PanelContainer.new()
		icon_frame.custom_minimum_size = Vector2(74.0, 74.0)
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_style := make_panel_style(
			Color(0.002, 0.020, 0.028, 0.98),
			Color(accent.r, accent.g, accent.b, 0.72),
			12
		)
		icon_style.shadow_size = 5
		icon_frame.add_theme_stylebox_override("panel", icon_style)
		hr.add_child(icon_frame)
		var icon_margin := MarginContainer.new()
		for side: String in ["left", "top", "right", "bottom"]:
			icon_margin.add_theme_constant_override("margin_" + side, 5)
		icon_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(icon_margin)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(62.0, 62.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = hero_icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_margin.add_child(icon)
	var ht := VBoxContainer.new()
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(ht)
	var eyebrow := Label.new()
	eyebrow.text = eyebrow_text
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", accent)
	ht.add_child(eyebrow)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.40, 1.0))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ht.add_child(title)
	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.88, 0.86, 1.0))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ht.add_child(subtitle)
	var hero_rule := ColorRect.new()
	hero_rule.custom_minimum_size.y = 3.0
	hero_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_rule.color = Color(accent.r, accent.g, accent.b, 0.78)
	hero_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ht.add_child(hero_rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 4
	scroll.follow_focus = false
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	outer.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	_install_scroll_guard(scroll, content)

	close.pressed.connect(func() -> void: return_home(root))
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
			scrim.accept_event()
			return_home(root)
	)
	scrim.modulate.a = 0.0
	panel.modulate.a = 0.0
	var tween := root.create_tween().set_parallel(true)
	tween.tween_property(scrim, "modulate:a", 1.0, 0.12)
	tween.tween_property(panel, "modulate:a", 1.0, 0.14)
	return {"back_button": close, "content": content, "scroll": scroll, "popup": panel}


static func _add_event_realm_backdrop(
	parent: Control,
	texture: Texture2D
) -> void:
	var art := TextureRect.new()
	art.name = "EventRealmBackdrop"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.modulate = Color(0.82, 0.88, 0.82, 1.0)
	parent.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.name = "EventRealmShade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.001, 0.010, 0.014, 0.34)
	parent.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var lower_shade := ColorRect.new()
	lower_shade.name = "EventRealmLowerShade"
	lower_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower_shade.color = Color(0.001, 0.010, 0.014, 0.22)
	lower_shade.anchor_left = 0.0
	lower_shade.anchor_top = 0.40
	lower_shade.anchor_right = 1.0
	lower_shade.anchor_bottom = 1.0
	parent.add_child(lower_shade)

static func _install_scroll_guard(
	scroll: ScrollContainer,
	content: Control
) -> void:
	# ScrollContainer emits these signals specifically for touch drag scrolling.
	# While a drag is active, descendant buttons are temporarily disabled so a
	# release cannot also activate a card/action that the finger started on.
	var tracked_buttons: Array[Button] = []
	var disabled_before: Dictionary = {}
	make_scroll_tree_touch_safe(content)

	scroll.scroll_started.connect(
		func() -> void:
			make_scroll_tree_touch_safe(content)
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


static func make_scroll_tree_touch_safe(root: Node) -> void:
	# Layout-only Controls must never become dead drag zones. Buttons stay
	# interactive, but PASS lets ScrollContainer still win once a swipe starts.
	if root is Control:
		var control := root as Control
		if control is Button:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
		elif not (control is ScrollContainer):
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in root.get_children():
		make_scroll_tree_touch_safe(child)


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
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := make_panel_style(
		Color(0.003, 0.031, 0.040, 0.985),
		Color(accent.r, accent.g, accent.b, 0.64),
		12
	)
	card_style.border_width_left = 3
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	card_style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", card_style)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 13)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var accent_line := ColorRect.new()
	accent_line.custom_minimum_size.y = 2.0
	accent_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accent_line.color = Color(accent.r, accent.g, accent.b, 0.78)
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(accent_line)
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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


static func add_progress_meter(
	parent: Container,
	current_value: int,
	total_value: int,
	accent: Color = Color(0.30, 0.82, 0.72, 1.0)
) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.custom_minimum_size.y = 9.0
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.min_value = 0.0
	meter.max_value = float(maxi(total_value, 1))
	meter.value = float(clampi(current_value, 0, maxi(total_value, 1)))
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var track := make_panel_style(
		Color(0.001, 0.014, 0.020, 0.98),
		Color(accent.r, accent.g, accent.b, 0.20),
		4
	)
	track.shadow_size = 0
	meter.add_theme_stylebox_override("background", track)

	var fill := make_panel_style(
		Color(accent.r, accent.g, accent.b, 0.82),
		Color(accent.r, accent.g, accent.b, 0.94),
		4
	)
	fill.shadow_size = 0
	meter.add_theme_stylebox_override("fill", fill)
	parent.add_child(meter)
	return meter


static func make_event_overview(
	parent: Container,
	title_text: String,
	current_value: int,
	total_value: int,
	state_text: String,
	accent: Color,
	ready_count: int = 0
) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := make_panel_style(
		Color(0.004, 0.034, 0.044, 0.99),
		Color(accent.r, accent.g, accent.b, 0.86),
		16
	)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	var title := add_label(
		top,
		title_text,
		18,
		Color(0.98, 0.82, 0.40, 1.0)
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var status_accent: Color = (
		Color(0.98, 0.80, 0.36, 1.0)
		if ready_count > 0
		else accent
	)
	add_state_badge(top, state_text, status_accent, ready_count > 0)

	var metric := add_label(
		box,
		"%d / %d" % [current_value, total_value],
		29,
		accent
	)
	metric.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.72)
	)
	metric.add_theme_constant_override("shadow_offset_y", 1)

	add_progress_meter(
		box,
		current_value,
		total_value,
		accent
	)

	if ready_count > 0:
		add_info_strip(
			box,
			parent.tr("%d REWARDS READY") % ready_count,
			Color(0.98, 0.80, 0.36, 1.0),
			true
		)
	return box


static func make_event_milestone(
	parent: Container,
	marker_text: String,
	title_text: String,
	detail_text: String,
	reward_text: String,
	accent: Color,
	state_id: String,
	state_text: String,
	progress_current: int = -1,
	progress_total: int = -1
) -> VBoxContainer:
	var border: Color = accent
	var background := Color(0.003, 0.027, 0.036, 0.99)
	var shadow_size: int = 5
	match state_id:
		"ready":
			border = Color(0.98, 0.80, 0.36, 1.0)
			background = Color(0.075, 0.048, 0.012, 0.985)
			shadow_size = 10
		"claimed":
			border = Color(0.34, 0.89, 0.72, 0.66)
			background = Color(0.003, 0.032, 0.036, 0.95)
		"locked":
			border = Color(0.34, 0.52, 0.52, 0.52)
			background = Color(0.002, 0.018, 0.025, 0.94)
		_:
			pass

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := make_panel_style(background, border, 14)
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_size = shadow_size
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 13)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var marker := add_label(header, marker_text, 12, border)
	marker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_state_badge(
		header,
		state_text,
		border,
		state_id == "ready"
	)

	var title_color: Color = (
		Color(0.98, 0.82, 0.40, 1.0)
		if state_id == "ready"
		else border
	)
	add_label(box, title_text, 18, title_color)
	if not detail_text.is_empty():
		add_label(
			box,
			detail_text,
			13,
			Color(0.74, 0.84, 0.82, 1.0)
		)

	if progress_current >= 0 and progress_total > 0:
		add_label(
			box,
			parent.tr("PROGRESS %d / %d") % [
				progress_current,
				progress_total,
			],
			12,
			Color(0.62, 0.84, 0.79, 1.0)
		)
		add_progress_meter(
			box,
			progress_current,
			progress_total,
			accent
		)

	var reward_panel := PanelContainer.new()
	reward_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reward_style := make_panel_style(
		Color(0.002, 0.020, 0.027, 0.98),
		Color(border.r, border.g, border.b, 0.34),
		9
	)
	reward_style.shadow_size = 0
	reward_panel.add_theme_stylebox_override("panel", reward_style)
	box.add_child(reward_panel)
	var reward_margin := MarginContainer.new()
	reward_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_margin.add_theme_constant_override("margin_left", 11)
	reward_margin.add_theme_constant_override("margin_top", 7)
	reward_margin.add_theme_constant_override("margin_right", 11)
	reward_margin.add_theme_constant_override("margin_bottom", 7)
	reward_panel.add_child(reward_margin)
	var reward_label := Label.new()
	reward_label.text = "✦  " + reward_text
	reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_label.add_theme_font_size_override("font_size", 13)
	reward_label.add_theme_color_override(
		"font_color",
		Color(0.98, 0.78, 0.32, 1.0)
	)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_margin.add_child(reward_label)
	return box


static func add_state_badge(
	parent: Container,
	text_value: String,
	accent: Color,
	strong: bool = false
) -> Label:
	var badge := Label.new()
	badge.text = text_value
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(96.0, 27.0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", accent)
	var fill := Color(0.004, 0.045, 0.052, 0.98)
	if strong:
		fill = Color(0.16, 0.095, 0.020, 0.99)
	var style := make_panel_style(
		fill,
		Color(accent.r, accent.g, accent.b, 0.72),
		7
	)
	style.shadow_size = 0
	badge.add_theme_stylebox_override("normal", style)
	parent.add_child(badge)
	return badge


static func add_info_strip(
	parent: Container,
	text_value: String,
	accent: Color,
	strong: bool = false
) -> Label:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := Color(
		accent.r * 0.055,
		accent.g * 0.055,
		accent.b * 0.055,
		0.99
	)
	if strong:
		fill = Color(
			accent.r * 0.11,
			accent.g * 0.08,
			accent.b * 0.04,
			0.99
		)
	var style := make_panel_style(
		fill,
		Color(accent.r, accent.g, accent.b, 0.42),
		8
	)
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size.y = 28.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", accent)
	panel.add_child(label)
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
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	button.add_theme_stylebox_override(
		"disabled",
		make_button_style(
			Color(0.001, 0.018, 0.024, 0.94),
			Color(accent.r, accent.g, accent.b, 0.24)
		)
	)
	button.add_theme_color_override(
		"font_disabled_color",
		Color(0.54, 0.65, 0.63, 0.78)
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
	if bool(root.get_meta("liveops_popup", false)):
		var manager: Node = root.get_node_or_null("/root/LiveOpsManager")
		if manager != null and manager.has_method("close_live_popup"):
			manager.call("close_live_popup")
		else:
			root.queue_free()
		return
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(MAIN_MENU_SCENE, -1)
	if change_error != OK:
		push_error("LiveOps UI: gagal kembali ke Home. Error code: " + str(change_error))
