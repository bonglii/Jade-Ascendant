extends Control


func _ready() -> void:
	SceneTransitionManager.set_back_handler(_back)
	_configure_backdrop()
	var scroll: ScrollContainer = $SafeArea/Scroll
	var content: VBoxContainer = $SafeArea/Scroll/Content
	_configure_scroll_surface(scroll, content)
	var hero: PanelContainer = PanelContainer.new()
	hero.add_theme_stylebox_override(
		"panel",
		_make_card_style(Color(0.34, 0.90, 0.80), true)
	)
	hero.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(hero)
	var hero_box: VBoxContainer = VBoxContainer.new()
	hero_box.mouse_filter = Control.MOUSE_FILTER_PASS
	hero_box.add_theme_constant_override("separation", 6)
	hero.add_child(hero_box)
	_add_label(hero_box, tr("ARCHIVE"), 12, Color(0.34, 0.90, 0.80))
	_add_label(
		hero_box,
		tr("Credits & Licenses"),
		27,
		Color(0.98, 0.83, 0.43)
	)
	_add_label(
		hero_box,
		tr("Jade Ascendant • Open-source notices and acknowledgements"),
		13,
		Color(0.68, 0.79, 0.76)
	)

	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override(
		"panel",
		_make_card_style(Color(0.30, 0.75, 0.72), false)
	)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(card)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	inner.add_theme_constant_override("separation", 10)
	card.add_child(inner)
	var credits: RichTextLabel = RichTextLabel.new()
	credits.fit_content = true
	credits.selection_enabled = false
	credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.add_theme_font_size_override("normal_font_size", 14)
	credits.add_theme_color_override(
		"default_color",
		Color(0.79, 0.87, 0.84)
	)
	credits.text = (
		"Jade Ascendant\n\n"
		+ Engine.get_license_text()
		+ "\n\n"
		+ tr("THIRD-PARTY NOTICES")
		+ "\n\n"
	)
	for component: Dictionary in Engine.get_copyright_info():
		credits.text += str(component.get("name", "")) + "\n"
		for part: Dictionary in component.get("parts", []):
			for line in part.get("copyright", []):
				credits.text += str(line) + "\n"
			credits.text += str(part.get("license", "")) + "\n"
		credits.text += "\n"
	var licenses: Dictionary = Engine.get_license_info()
	for license_name in licenses:
		credits.text += (
			str(license_name)
			+ "\n"
			+ str(licenses[license_name])
			+ "\n\n"
		)
	inner.add_child(credits)

	var back: Button = Button.new()
	back.text = tr("BACK TO PRIVACY")
	back.mouse_filter = Control.MOUSE_FILTER_PASS
	back.custom_minimum_size.y = 48.0
	back.theme_type_variation = &"JadeSecondaryButton"
	back.add_theme_font_size_override("font_size", 14)
	back.pressed.connect(_back)
	content.add_child(back)


func _configure_scroll_surface(
	scroll: ScrollContainer,
	content: VBoxContainer
) -> void:
	# Credits are read-only content. The outer ScrollContainer owns all swipe
	# gestures; text selection is deliberately disabled for mobile ergonomics.
	scroll.scroll_deadzone = 6
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	content.mouse_filter = Control.MOUSE_FILTER_PASS

func _configure_backdrop() -> void:
	var backdrop: Control = $Backdrop
	if backdrop != null and backdrop.has_method("apply_profile"):
		backdrop.call("apply_profile", {
			"sky_top": Color(0.002, 0.012, 0.023, 1.0),
			"sky_bottom": Color(0.008, 0.044, 0.058, 1.0),
			"mountain_far": Color(0.018, 0.080, 0.096, 0.78),
			"mountain_near": Color(0.006, 0.036, 0.046, 0.95),
			"mist": Color(0.28, 0.80, 0.78, 0.07),
			"moon": Color(0.96, 0.82, 0.44, 0.05),
			"accent": Color(0.34, 0.90, 0.80, 1.0),
			"gold": Color(0.96, 0.78, 0.34, 1.0)
		})


func _make_card_style(accent: Color, hero: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(
		0.002,
		0.022,
		0.034,
		0.94 if hero else 0.90
	)
	style.border_width_left = 2 if hero else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.58 if hero else 0.30
	)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color(0, 0, 0, 0.30)
	style.shadow_size = 4
	return style


func _add_label(
	parent_node: Node,
	text_value: String,
	font_size: int,
	tint: Color
) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent_node.add_child(label)
	return label


func _back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		"res://scenes/ui/privacy_screen.tscn",
		-1
	)
	if change_error != OK:
		push_error(
			"CreditsScreen: gagal kembali ke Privacy. Error code: "
			+ str(change_error)
		)
