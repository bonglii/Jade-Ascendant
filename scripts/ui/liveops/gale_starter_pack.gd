extends Control

const Pack = preload("res://scripts/data/starter_pack_catalog.gd")
const Sets = preload("res://scripts/data/equipment_set_catalog.gd")
const Visual = preload("res://scripts/ui/equipment_visual_catalog.gd")
const SafeArea = preload("res://scripts/ui/mobile_safe_area.gd")
const Scroll = preload("res://scripts/ui/mobile_scroll_policy.gd")
const Preview = preload("res://scripts/ui/liveops/gale_starter_preview.gd")
const GOLD = Color("#f2d38e")
const JADE = Color("#86e9bd")
const TEXT = Color("#d1e5dc")

func _ready() -> void:
	if not Pack.preview_available():
		hide()
		_close.call_deferred()
		return
	var shade := ColorRect.new()
	shade.color = Color("#071619")
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)
	var safe := Control.new()
	safe.set_script(SafeArea)
	safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(safe)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]:
		margins.add_theme_constant_override("margin_" + side, 14)
	safe.add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margins.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label(_copy("GALE STARTER PACK", "STARTER PACK GALE"), 23, GOLD)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.name = "CloseStarterPack"
	close.text = "×"
	close.custom_minimum_size = Vector2(48, 44)
	close.pressed.connect(_close)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.name = "StarterPackScroll"
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	Scroll.configure(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	content.add_child(_label(_copy("GALE PARASOL • TWO COMBAT MODES", "GALE PARASOL • DUA MODE SERANGAN"), 17, JADE))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	content.add_child(modes)
	_add_mode(modes, false, _copy("PIERCING THORNS", "DURI TEMBUS"),
		_copy("At range, fire thorns that pierce enemies.", "Dari jauh, tembakkan duri yang menembus musuh."))
	_add_mode(modes, true, _copy("GALE WARD", "GALE WARD"),
		_copy("When surrounded, open the canopy and push regular enemies back.",
			"Saat dikerumuni, buka payung dan dorong musuh biasa menjauh."))
	content.add_child(_label("GALEWEAVE REGALIA", 19, GOLD))
	var gear := GridContainer.new()
	gear.columns = 2
	gear.add_theme_constant_override("h_separation", 8)
	gear.add_theme_constant_override("v_separation", 8)
	content.add_child(gear)
	for id: String in Pack.ITEMS:
		if id == "gale_parasol":
			continue
		_add_gear(gear, id)
	for tier: int in [2, 3, 4]:
		content.add_child(_label("%d/4  %s" % [tier, Sets.get_tier_description("galeweave", tier)], 15, TEXT))
	content.add_child(_label(_copy("One pack per account • Google Play purchase",
		"Satu pack per akun • Pembelian Google Play"), 14, TEXT))

	column.add_child(_label(_copy("Indonesia target price", "Target harga Indonesia") + "  " + Pack.target_price(), 16, GOLD))
	var checkout := Button.new()
	checkout.name = "StarterPackCheckout"
	checkout.text = _copy("Google Play purchase unavailable", "Pembelian Google Play belum tersedia")
	checkout.custom_minimum_size.y = 46
	checkout.clip_text = true
	checkout.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	checkout.disabled = true
	column.add_child(checkout)
	Scroll.prepare_tree(scroll)

func _add_mode(parent: Control, canopy: bool, title: String, description: String) -> void:
	var card := _card(parent)
	var preview: Control = Preview.new()
	preview.canopy = canopy
	preview.custom_minimum_size.y = 104
	card.add_child(preview)
	card.add_child(_label(title, 15, JADE))
	card.add_child(_label(description, 14, TEXT))

func _add_gear(parent: Control, id: String) -> void:
	var item: Dictionary = EquipmentManager.get_item_data(id)
	var card := _card(parent)
	var art := TextureRect.new()
	art.texture = load(Visual.get_icon_path(id))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size.y = 83
	card.add_child(art)
	card.add_child(_label(str(item.display_name), 15, GOLD))
	card.add_child(_label(Visual.get_stat_summary(item), 14, TEXT))

func _card(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0d282a")
	style.border_color = Color("#6b7650")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 8.0)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label

func _copy(en: String, id: String) -> String:
	return id if SettingsManager.language == "id" else en

func _close() -> void:
	var live_ops: Node = get_node_or_null("/root/LiveOpsManager")
	if has_meta("liveops_popup") and live_ops != null:
		live_ops.close_live_popup()
	else:
		SceneTransitionManager.transition_menu_to("res://scenes/ui/main_menu.tscn", 1)
