extends Control

const Catalog = preload("res://scripts/data/skill_catalog.gd")
const SafeArea = preload("res://scripts/ui/mobile_safe_area.gd")
const Ui = preload("res://scripts/ui/liveops/live_ops_ui.gd")
const Localization = preload("res://scripts/liveops/live_ops_localization.gd")
var _search: LineEdit
var _list: VBoxContainer
var _count: Label
var _filter: String = "ALL"
var _filter_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Localization.install()
	var art := TextureRect.new()
	art.texture = Ui.BACKGROUND_TEXTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(0.16, 0.23, 0.23)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := Control.new()
	safe.name = "DeviceSafeArea"
	safe.set_script(SafeArea)
	add_child(safe)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	safe.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	var top := HBoxContainer.new()
	body.add_child(top)
	var back := _button("‹  HOME")
	back.name = "SkillBookBack"
	back.pressed.connect(_back)
	top.add_child(back)
	var seal := _label("JADE ARCHIVES", 13, Color(0.94, 0.77, 0.40))
	seal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(seal)
	body.add_child(_label("SKILL BOOK", 30, Color(1.0, 0.88, 0.55)))
	body.add_child(_label("Learn your skills. Discover their resonance.", 16, Color(0.65, 0.92, 0.86)))
	body.add_child(_label("Run skills are chosen during level-up. They reset after the run; permanent equipment is managed in HERO.", 14, Color(0.76, 0.84, 0.82)))
	_search = LineEdit.new()
	_search.name = "SkillBookSearch"
	_search.placeholder_text = tr("SEARCH SKILLS")
	_search.custom_minimum_size.y = 48
	_search.add_theme_font_size_override("font_size", 16)
	_search.text_changed.connect(_on_search)
	body.add_child(_search)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	body.add_child(filters)
	for category: String in ["ALL", "WEAPONS", "PASSIVES", "SYNERGIES"]:
		var button := _button(category)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_filter.bind(category))
		filters.add_child(button)
		_filter_buttons[category] = button
	_count = _label("", 13, Color(0.76, 0.84, 0.82))
	body.add_child(_count)
	var scroll := ScrollContainer.new()
	scroll.name = "SkillBookScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 6
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "SkillBookEntries"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	SceneTransitionManager.set_back_handler(_back)
	_refresh()

func _on_search(_query: String) -> void:
	_refresh()

func _set_filter(category: String) -> void:
	_filter = category
	_refresh()

func _refresh() -> void:
	for node: Node in _list.get_children():
		_list.remove_child(node)
		node.queue_free()
	var shown: int = 0
	var query: String = _search.text.strip_edges().to_lower()
	for id: String in Catalog.UPGRADE_IDS:
		if _filter != "ALL" and Catalog.get_category(id) != _filter:
			continue
		var haystack: String = (id + " " + tr(_display_name(id)) + " " + tr(_description(id))).to_lower()
		if not query.is_empty() and not haystack.contains(query):
			continue
		_list.add_child(_card(id))
		shown += 1
	_count.text = tr("%d SKILLS") % shown
	if shown == 0:
		_list.add_child(_label("NO MATCHING SKILLS", 18, Color(0.76, 0.84, 0.82)))
	for category: String in _filter_buttons:
		var button: Button = _filter_buttons[category]
		button.add_theme_color_override("font_color", Color(1.0, 0.87, 0.44) if category == _filter else Color(0.76, 0.84, 0.82))

func _card(id: String) -> Control:
	var card := PanelContainer.new()
	card.name = "Skill_" + id
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := Ui.make_panel_style(Color(0.004, 0.037, 0.043, 0.97), Color(0.38, 0.74, 0.63, 0.65), 12)
	for edge: String in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + edge, 14.0)
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64,64)
	var armament: String = EquipmentManager.get_equipped_item_id(EquipmentManager.SLOT_ARMAMENT)
	icon.texture = load(Catalog.get_icon_path(id, armament)) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	text.add_theme_constant_override("separation", 5)
	row.add_child(text)
	text.add_child(_label(Catalog.get_category(id), 12, Color(0.42, 0.91, 0.78)))
	text.add_child(_label(_display_name(id), 21, Color(1.0, 0.88, 0.55)))
	text.add_child(_label(_description(id), 16, Color(0.89, 0.94, 0.91)))
	var requirements: Dictionary = Catalog.get_requirements(id)
	if not requirements.is_empty():
		var names: PackedStringArray = []
		for required: String in requirements:
			names.append(tr(_display_name(required)) + " Lv.%d" % int(requirements[required]))
		text.add_child(_label(tr("REQUIRES: %s") % " + ".join(names), 15, Color(0.96, 0.77, 0.39)))
		text.add_child(_label("Once requirements are met, this synergy can appear in level-up choices. It must still be selected.", 14, Color(0.76, 0.84, 0.82)))
	else:
		var synergies: PackedStringArray = []
		for synergy: String in Catalog.get_related_synergies(id):
			synergies.append(tr(_display_name(synergy)))
		if not synergies.is_empty():
			text.add_child(_label(tr("COMBINES INTO: %s") % ", ".join(synergies), 15, Color(0.55, 0.92, 0.83)))
	return card

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = tr(value)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(value: String) -> Button:
	var button := Button.new()
	button.text = tr(value)
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", Ui.make_button_style(Color(0.006,0.055,0.062), Color(0.38,0.74,0.63)))
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	return button

func _back() -> void:
	SceneTransitionManager.transition_menu_to("res://scenes/ui/main_menu.tscn", 1)

func _is_chain() -> bool:
	return EquipmentManager.get_equipped_item_id(EquipmentManager.SLOT_ARMAMENT) == "jade_binding_chain"

func _is_glaive() -> bool:
	return EquipmentManager.get_equipped_item_id(EquipmentManager.SLOT_ARMAMENT) == "celestial_returning_glaive"

func _display_name(id: String) -> String:
	var armament: String = EquipmentManager.get_equipped_item_id(EquipmentManager.SLOT_ARMAMENT)
	if preload("res://scripts/data/ascendant_arsenal_catalog.gd").IDS.has(armament):
		if id == "spirit_sword": return preload("res://scripts/data/ascendant_arsenal_catalog.gd").NAMES[armament]
		if id == "sword_dao_resonance": return "Ascendant Dao Resonance"
	if _is_glaive():
		if id == "spirit_sword": return "Celestial Returning Glaive"
		if id == "sword_dao_resonance": return "Returning Dao Resonance"
	if _is_chain():
		if id == "spirit_sword": return "Jade Binding Chain"
		if id == "sword_dao_resonance": return "Binding Dao Resonance"
	return Catalog.get_upgrade_display_name(id)

func _description(id: String) -> String:
	var armament: String = EquipmentManager.get_equipped_item_id(EquipmentManager.SLOT_ARMAMENT)
	if preload("res://scripts/data/ascendant_arsenal_catalog.gd").IDS.has(armament):
		if id == "spirit_sword": return preload("res://scripts/data/ascendant_arsenal_catalog.gd").description(armament)
		if id == "sword_dao_resonance": return preload("res://scripts/data/ascendant_arsenal_catalog.gd").resonance(armament)
	if _is_glaive():
		if id == "spirit_sword": return "Your Legendary armament throws a piercing disc, spins near the aimed position, then returns to your current position. Move to steer its path. Lv.3: crescent flight; Lv.5: staggered twin discs; Lv.7: 58-radius closure on a real catch. One hit per enemy per phase. Cooldown 2.1s, minimum 1.75s; extra tempo strengthens hits at that limit. Run level resets; equipment stars persist."
		if id == "sword_dao_resonance": return "An outbound critical empowers only the first return hit by 40% base damage, once per disc. No additional projectile is created."
	if _is_chain():
		if id == "spirit_sword": return "Your equipped Legendary armament replaces the starter attack. Seal, bind, then detonate jade knots. Lv.1/3/5/7 binds 2/3/4/5 enemies in 80/92/104/116 radius. Slow 40% for 0.72s; bosses 12%. Cooldown 1.8s, minimum 1.25s; extra tempo strengthens hits at that limit. Refinement resets after the run; equipment stars persist."
		if id == "sword_dao_resonance": return "Critical bindings release one extra 40% damage knot onto a nearby unbound enemy. Once per cast, without recursively creating more bindings."
	return Catalog.get_upgrade_description(id)
