extends "res://scripts/ui/library_skill_reader.gd"
## Read-only encyclopedia; gameplay and upgrade authority stay in their managers.
const Visual=preload("res://scripts/ui/equipment_visual_catalog.gd")
const Sets=preload("res://scripts/data/equipment_set_catalog.gd")
const ArchiveFont=preload("res://assets/ui/library/fonts/archive_serif.ttf")
var _mode: String="EQUIPMENT"
var _rarity: String="ALL"
var _filters: HBoxContainer
var _tabs: Dictionary={}
var _summary: PanelContainer
var _summary_icon: TextureRect
var _summary_text: Label
var _selected: String=""
var _popup: Control
var _rarity_picker: OptionButton
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	Localization.install()
	var art:=TextureRect.new()
	art.texture=load("res://assets/ui/library/jade_archive_bg.png")
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe:=Control.new();safe.name="DeviceSafeArea";safe.set_script(SafeArea)
	add_child(safe);safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin:=MarginContainer.new();safe.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,12 if size.x<400 else 24)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",8);margin.add_child(body)
	var top:=HBoxContainer.new();body.add_child(top)
	var back:=_button("‹ HOME");back.custom_minimum_size.x=100;back.name="SkillBookBack";back.pressed.connect(_back);top.add_child(back)
	var seal:=_label("JADE ARCHIVES",13,Color(.97,.80,.43));seal.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;top.add_child(seal)
	body.add_child(_label("LIBRARY",30,Color(1,.88,.55)))
	var tabs:=HBoxContainer.new();body.add_child(tabs)
	for value: String in ["EQUIPMENT","SKILLS"]:
		var tab:=_button(value);tab.name="LibraryTab"+value;tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab.pressed.connect(_set_mode.bind(value));tabs.add_child(tab);_tabs[value]=tab
	_search=LineEdit.new();_search.name="SkillBookSearch";_search.placeholder_text="Search the archives…";_search.custom_minimum_size.y=44
	_search.add_theme_font_size_override("font_size",16)
	_search.add_theme_stylebox_override("normal",Ui.make_panel_style(Color(.004,.03,.036,.97),Color(.40,.68,.60),8))
	_search.text_changed.connect(_on_search);body.add_child(_search)
	_filters=HBoxContainer.new();_filters.add_theme_constant_override("separation",5);body.add_child(_filters);_build_filters()
	var count_row:=HBoxContainer.new();body.add_child(count_row)
	_count=_label("",13,Color(.79,.87,.82));count_row.add_child(_count)
	_rarity_picker=OptionButton.new();_rarity_picker.name="LibraryRarity";_rarity_picker.custom_minimum_size=Vector2(104,34);_rarity_picker.add_theme_font_size_override("font_size",12)
	for value: String in ["ALL","common","rare","epic","legendary"]:_rarity_picker.add_item("All rarities" if value=="ALL" else value.capitalize())
	for state: String in ["normal","hover","pressed"]:_rarity_picker.add_theme_stylebox_override(state,_skin(state))
	_rarity_picker.get_popup().add_theme_stylebox_override("panel",Ui.make_panel_style(Color(.003,.03,.039,.99),Color(.83,.66,.32),10))
	_rarity_picker.item_selected.connect(func(index: int):_rarity=["ALL","common","rare","epic","legendary"][index];_refresh())
	count_row.add_child(_rarity_picker)
	var scroll:=ScrollContainer.new();scroll.name="SkillBookScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.scroll_deadzone=8;body.add_child(scroll)
	scroll.get_v_scroll_bar().modulate=Color(.46,.64,.57,.5)
	_list=VBoxContainer.new();_list.name="SkillBookEntries";_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_list.add_theme_constant_override("separation",10);scroll.add_child(_list)
	_summary=PanelContainer.new();_summary.name="LibrarySelection";_summary.add_theme_stylebox_override("panel",Ui.make_panel_style(Color(.004,.027,.034,.99),Color(.84,.66,.32),12));body.add_child(_summary)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);_summary.add_child(row)
	_summary_icon=TextureRect.new();_summary_icon.custom_minimum_size=Vector2(64,64);_summary_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_summary_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(_summary_icon)
	var copy:=VBoxContainer.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(copy)
	_summary_text=_label("Tap a relic to explore.",15,Color(.98,.86,.56));_summary_text.max_lines_visible=3;copy.add_child(_summary_text)
	var detail:=_button("VIEW DETAILS ›");detail.custom_minimum_size.y=36;detail.pressed.connect(func():if not _selected.is_empty():_open_equipment_detail(_selected));copy.add_child(detail)
	var guard: Node=preload("res://scripts/ui/mobile_touch_presentation_guard.gd").new();add_child(guard)
	SceneTransitionManager.set_back_handler(_back);_refresh()
func _skin(state: String) -> StyleBoxTexture:
	var skin:=StyleBoxTexture.new();skin.texture=load("res://assets/ui/account_gate/imperial_v1/jade_button.png")
	for edge: String in ["left","right","top","bottom"]:
		skin.set("texture_margin_"+edge,0)
		skin.set("content_margin_"+edge,8)
	if state=="pressed":skin.modulate_color=Color(.67,.80,.76)
	elif state=="hover":skin.modulate_color=Color(1.08,1.08,1.02)
	return skin
func _button(value: String) -> Button:
	var button:=Button.new();button.text=tr(value);button.custom_minimum_size.y=44;button.add_theme_font_size_override("font_size",14);button.add_theme_font_override("font",ArchiveFont)
	button.mouse_filter=Control.MOUSE_FILTER_PASS;button.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE
	for state: String in ["normal","hover","pressed"]:button.add_theme_stylebox_override(state,_skin(state))
	return button
func _set_mode(value: String) -> void:
	_close_popup();_mode=value;_filter="ALL";_search.text="";_build_filters();_refresh()
func _build_filters() -> void:
	for child: Node in _filters.get_children():_filters.remove_child(child);child.queue_free()
	_filter_buttons.clear()
	var categories: Array=["ALL","WEAPONS","ARMOR","SETS"] if _mode=="EQUIPMENT" else ["ALL","WEAPONS","PASSIVES","SYNERGIES"]
	for category: String in categories:
		var b:=_button(category);b.custom_minimum_size.y=38;b.add_theme_font_size_override("font_size",11 if size.x<400 else 14);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.pressed.connect(_set_filter.bind(category));_filters.add_child(b);_filter_buttons[category]=b
func _refresh() -> void:
	_summary.visible=_mode=="EQUIPMENT" and _filter!="SETS"
	_rarity_picker.visible=_summary.visible
	for tab: String in _tabs:_tabs[tab].add_theme_color_override("font_color",Color(1,.87,.44) if tab==_mode else Color(.72,.83,.79))
	if _mode=="SKILLS":super._refresh();return
	for child: Node in _list.get_children():_list.remove_child(child);child.queue_free()
	var query: String=_search.text.strip_edges().to_lower();var shown: int=0
	if _filter=="SETS":
		for id: String in Sets.SET_ORDER:
			if not query.is_empty() and not (id+" "+Sets.get_display_name(id)+" "+Sets.get_identity(id)).to_lower().contains(query):continue
			_list.add_child(_set_card(id));shown+=1
	else:
		var grid:=GridContainer.new();grid.name="LibraryEquipmentGrid";grid.columns=5;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",8);_list.add_child(grid)
		var ids: Array[String]=EquipmentManager.get_item_ids()
		ids.sort_custom(func(a: String,b: String):
			var sa: int=Sets.SET_ORDER.find(Sets.get_set_id_for_item(a));var sb: int=Sets.SET_ORDER.find(Sets.get_set_id_for_item(b))
			if sa!=sb:return (sa if sa>=0 else 99)<(sb if sb>=0 else 99)
			if sa>=0:return Sets.get_piece_ids(Sets.SET_ORDER[sa]).find(a)<Sets.get_piece_ids(Sets.SET_ORDER[sb]).find(b)
			return a<b)
		for id: String in ids:
			var d: Dictionary=EquipmentManager.get_item_data(id);var slot: String=str(d.slot)
			if _filter=="WEAPONS" and slot!="armament":continue
			if _filter=="ARMOR" and slot=="armament":continue
			if _rarity!="ALL" and str(d.rarity)!=_rarity:continue
			if not query.is_empty() and not (id+" "+str(d.display_name)+" "+str(d.rarity)+" "+Sets.get_display_name(Sets.get_set_id_for_item(id))).to_lower().contains(query):continue
			grid.add_child(_equipment_tile(id));shown+=1
	_count.text="%d %s"%[shown,"SETS" if _filter=="SETS" else "RELICS"]
	if shown==0:_list.add_child(_label("NO MATCHING ENTRIES",18,Color(.77,.85,.80)))
	for category: String in _filter_buttons:_filter_buttons[category].add_theme_color_override("font_color",Color(1,.87,.44) if category==_filter else Color(.75,.85,.80))
	if _selected.is_empty():_select_equipment("void_piercer_spear")
func _equipment_tile(id: String) -> Button:
	var d: Dictionary=EquipmentManager.get_item_data(id);var color: Color=Visual.get_rarity_color(str(d.rarity))
	var b:=Button.new();b.name="Relic_"+id;b.tooltip_text=str(d.display_name);b.custom_minimum_size.y=62 if size.x<400 else 104;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.mouse_filter=Control.MOUSE_FILTER_PASS;b.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE
	for state: String in ["normal","hover","pressed"]:
		var skin:=Ui.make_panel_style(Color(.005,.028,.037,.98),color,8);skin.set_border_width_all(2);skin.shadow_color=Color(color.r,color.g,color.b,.18);skin.shadow_size=4;skin.content_margin_left=4;skin.content_margin_right=4;b.add_theme_stylebox_override(state,skin)
	var art:=TextureRect.new();art.texture=load(Visual.get_icon_path(id));art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);art.offset_left=6;art.offset_right=-6;art.offset_top=6;art.offset_bottom=-6
	var mark:=Label.new();mark.text="◆" if InventoryManager.owns_item(id) else "○";mark.tooltip_text="OWNED" if InventoryManager.owns_item(id) else "NOT OWNED";mark.add_theme_font_size_override("font_size",12);mark.add_theme_color_override("font_color",color);mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(mark);mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);mark.offset_left=-18;mark.offset_top=4
	b.pressed.connect(_select_equipment.bind(id));return b
func _select_equipment(id: String) -> void:
	_selected=id;var d: Dictionary=EquipmentManager.get_item_data(id);_summary_icon.texture=load(Visual.get_icon_path(id));_summary_text.text=str(d.display_name)+"\n"+str(d.rarity).to_upper()+" • "+("OWNED" if InventoryManager.owns_item(id) else "NOT OWNED")+"\n"+Visual.get_stat_summary(d)
func _set_card(id: String) -> Control:
	var p:=PanelContainer.new();p.add_theme_stylebox_override("panel",Ui.make_panel_style(Color(.003,.028,.035,.97),Visual.get_rarity_color(Sets.get_set_rarity(id)),10));var c:=VBoxContainer.new();p.add_child(c);c.add_child(_label(Sets.get_display_name(id),20,Color(.99,.85,.48)));var row:=HBoxContainer.new();c.add_child(row)
	for item: String in Sets.get_piece_ids(id):var tile:=_equipment_tile(item);tile.custom_minimum_size.y=74;row.add_child(tile)
	c.add_child(_label("FOUR PIECES • "+Sets.get_identity(id),14,Color(.62,.91,.82)));c.add_child(_label(Sets.get_tier_description(id,4),14,Color(.85,.93,.87)));return p
func _card(id: String) -> Control:
	var b:=Button.new();b.name="Skill_"+id;b.custom_minimum_size.y=114;b.mouse_filter=Control.MOUSE_FILTER_PASS;b.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.add_theme_stylebox_override("normal",Ui.make_panel_style(Color(.003,.028,.035,.96),Color(.58,.66,.40),10))
	var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_theme_constant_override("separation",12);b.add_child(row);row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);row.offset_left=12;row.offset_right=-12;row.offset_top=10;row.offset_bottom=-10
	var icon:=TextureRect.new();var arm: String=EquipmentManager.get_equipped_item_id("armament");icon.texture=load(Catalog.get_icon_path(id,arm));icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(72,72);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(icon)
	var c:=VBoxContainer.new();c.mouse_filter=Control.MOUSE_FILTER_IGNORE;c.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(c);c.add_child(_label(_display_name(id),20,Color(.99,.85,.48)));c.add_child(_label(Catalog.get_category(id),11,Color(.50,.90,.78)));var desc:=_label(_description(id),14,Color(.82,.90,.86));desc.max_lines_visible=2;c.add_child(desc);b.pressed.connect(_open_skill_detail.bind(id));return b
func _open_skill_detail(id: String) -> void:_open_popup(_display_name(id),super._card(id))
func _open_equipment_detail(id: String) -> void:
	var d: Dictionary=EquipmentManager.get_item_data(id);var c:=VBoxContainer.new();c.add_theme_constant_override("separation",12)
	var art:=TextureRect.new();art.custom_minimum_size.y=100;art.texture=load(Visual.get_icon_path(id));art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;c.add_child(art)
	c.add_child(_label(str(d.rarity).to_upper()+" • "+Visual.get_slot_title(str(d.slot)),14,Visual.get_rarity_color(str(d.rarity))))
	c.add_child(_label("BASE STATS • "+Visual.get_stat_summary(d),16,Color(.9,.94,.9)))
	c.add_child(_label(Visual.get_signature_effect_description(d),15,Color(.82,.90,.86)))
	var set_id: String=Sets.get_set_id_for_item(id)
	if not set_id.is_empty():
		c.add_child(_label(Sets.get_display_name(set_id)+" • FOUR ARMOR/ACCESSORY PIECES",16,Color(.99,.83,.45)))
		for tier: int in [2,3,4]:c.add_child(_label("%d PIECES: %s"%[tier,Sets.get_tier_description(set_id,tier)],15,Color(.68,.90,.80)))
	else:c.add_child(_label("Independent weapon • does not count toward a set. Permanent level cap: 10 / 20 / 30 / 40 / 50 at 1–5 stars. Run refinement is separate.",15,Color(.68,.90,.80)))
	c.add_child(_label("Star ascension requires identical duplicates. Manage your loadout and upgrades in HERO.",14,Color(.73,.83,.79)))
	var chapter: int=int(d.get("requires_chapter",0));var stage: int=int(d.get("requires_stage",0))
	c.add_child(_label("SHOP / FORGE UNLOCK: Clear %d-%d"%[chapter,stage] if chapter>0 else "ACQUISITION: Available from the beginning",14,Color(.99,.83,.45)))
	c.add_child(_label("GACHA COLLECTION: Opens after clear 1-5. Shop/forge requirements are separate.",14,Color(.68,.90,.80)))
	_open_popup(str(d.display_name),c)
func _open_popup(title: String,content: Control) -> void:
	_close_popup();_popup=Control.new();_popup.name="LibraryDetail";add_child(_popup);_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim:=ColorRect.new();dim.color=Color(0,.008,.014,.72);_popup.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.gui_input.connect(func(event: InputEvent):if event is InputEventMouseButton and event.pressed:_close_popup())
	var panel:=PanelContainer.new();panel.name="LibraryDetailPanel";panel.add_theme_stylebox_override("panel",Ui.make_panel_style(Color(.003,.026,.034,.99),Color(.84,.66,.32),12));_popup.add_child(panel)
	var width: float=minf(520,size.x-32);var height: float=minf(500,size.y*.68);panel.position=(size-Vector2(width,height))*.5;panel.size=Vector2(width,height)
	var body:=VBoxContainer.new();panel.add_child(body);var top:=HBoxContainer.new();body.add_child(top);top.add_child(_label(title,20,Color(.99,.85,.48)));var close:=_button("×");close.custom_minimum_size.x=44;close.pressed.connect(_close_popup);top.add_child(close)
	var scroll:=ScrollContainer.new();scroll.name="LibraryDescriptionScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.scroll_deadzone=8;body.add_child(scroll);content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.custom_minimum_size.x=width-panel.get_theme_stylebox("panel").get_minimum_size().x-12;scroll.add_child(content)
func _close_popup() -> void:
	if is_instance_valid(_popup):remove_child(_popup);_popup.queue_free()
	_popup=null
func _back() -> void:
	if is_instance_valid(_popup):_close_popup();return
	super._back()

func _label(value: String,font_size: int,color: Color) -> Label:
	var label: Label=super._label(value,font_size,color)
	if font_size>=20:label.add_theme_font_override("font",ArchiveFont)
	return label
