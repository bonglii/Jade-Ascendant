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
	var backdrop: ColorRect = _host.get_node("ColorRect")
	backdrop.color = Color(0.018,0.055,0.065,0.98)
	for child: Node in backdrop.get_children():
		if child is TextureRect: child.hide()
	var landscape := TextureRect.new()
	landscape.name = "AscendantResultBackdrop"
	landscape.texture = load("res://assets/ui/results/ascendant_v3/%s_backdrop.png" % _mode)
	landscape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	landscape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	landscape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(landscape)
	backdrop.move_child(landscape,0)
	landscape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.name = "ResultReadabilityVeil"
	veil.color = Color(0.015,0.04,0.045,0.16)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(veil)
	backdrop.move_child(veil,1)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_margin = _panel.get_node("Margin")
	_content = _margin.get_node("Content")
	var empty := StyleBoxEmpty.new()
	_panel.add_theme_stylebox_override("panel", empty)
	var frame := TextureRect.new()
	frame.name = "CeremonialResultFrame"
	frame.self_modulate.a = 0.95
	frame.texture = load("res://assets/ui/results/neo/%s.svg" % ("crimson" if _mode == "defeat" else "jade"))
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
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
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
		_seal.custom_minimum_size = Vector2(0, 56)
	var title: Label = _host.get("victory_label" if _mode == "victory" else "game_over_label") as Label
	title.add_theme_font_size_override("font_size", 30)
	if _mode == "victory":
		_seal.hide()
		_host.get("eyebrow_label").hide()
		_host.get("hint_label").hide()
		_host.get("balance_label").hide()
		_install_run_report()
	if _host.get("result_atmosphere") != null:
		_host.get("result_atmosphere").hide()
		_host.get("result_atmosphere").set_process(false)
	for button: Button in _content.find_children("*", "Button", true, false):
		var primary: bool = button == _host.get("main_menu_button") if _mode == "victory" else button == _host.get("retry_button")
		style_button(button, ("red" if _mode == "defeat" else "jade") if primary else "navy")
	_safe.resized.connect(fit)
	fit()
	fit.call_deferred()

static func style_button(button: Button, palette: String) -> void:
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 16)
	for pair: Array in [["normal", "normal"], ["hover", "hover"], ["pressed", "pressed"], ["disabled", "pressed"]]:
		var style := StyleBoxTexture.new()
		style.texture = load("res://assets/ui/results/quiet/button_%s_%s.svg" % [palette, pair[1]])
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.texture_margin_left=12
		style.texture_margin_right=12
		style.texture_margin_top=12
		style.texture_margin_bottom=12
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
	var available: Vector2 = _safe.size - Vector2(24,24)
	var fixed_height: float = 76.0
	for child: Control in _content.get_children():
		if child != _scroll and child.visible: fixed_height += child.get_combined_minimum_size().y + 8
	var natural: float = _body.get_combined_minimum_size().y + fixed_height
	var desired := Vector2(minf(520, available.x), minf(clampf(natural, 480, 740), available.y))
	_panel.custom_minimum_size = desired
	_panel.size = desired
	_margin.add_theme_constant_override("margin_left", 24)
	_margin.add_theme_constant_override("margin_right", 24)
	_margin.add_theme_constant_override("margin_top", 32)
	_margin.add_theme_constant_override("margin_bottom", 28)
	if _seal != null:
		_seal.custom_minimum_size = Vector2(0, 56)
	var grid: GridContainer = _host.get("reward_chip_row") as GridContainer if _mode == "victory" else null
	if grid != null: grid.columns = 2 if desired.x - 48 >= 300 else 1

var _record_summary: Label
var _report: VBoxContainer
var _report_rows: VBoxContainer
var _damage_tab: Button
var _skills_tab: Button
var _show_skills: bool=false
var _report_damage: Array[Dictionary]=[]
var _report_skills: Array[Dictionary]=[]
var _report_partial: bool=false

func _install_run_report() -> void:
	_report=VBoxContainer.new()
	_report.name="RunReport"
	_report.add_theme_constant_override("separation",10)
	_body.add_child(_report)
	_record_summary=_report_label("",Color(.48,.87,.73),15);_record_summary.name="PersonalRecordSummary";_record_summary.hide();_report.add_child(_record_summary)
	var tabs:=HBoxContainer.new()
	_report.add_child(tabs)
	_damage_tab=Button.new();_skills_tab=Button.new()
	for button: Button in [_damage_tab,_skills_tab]:
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.toggle_mode=true
		button.custom_minimum_size=Vector2(0,44)
		tabs.add_child(button)
		style_button(button,"navy")
	_damage_tab.pressed.connect(func():_show_skills=false;_refresh_report_rows())
	_skills_tab.pressed.connect(func():_show_skills=true;_refresh_report_rows())
	_report_rows=VBoxContainer.new()
	_report_rows.add_theme_constant_override("separation",8)
	_report.add_child(_report_rows)

func capture_run_report() -> void:
	if _mode!="victory":return
	var player: Node=get_tree().get_first_node_in_group("player")
	if player==null:return
	var ledger: Node=player.get_node_or_null("WeaponManager/RunCombatLedger")
	if ledger==null:return
	ledger.frozen=true
	_report_damage=ledger.damage_rows();_report_skills=ledger.skills();_report_partial=ledger.partial
	var victory: Node=_host.get_parent().get_node_or_null("VictoryManager")
	if victory!=null and not str(victory.record_result).is_empty():
		var id_language: bool=SettingsManager.language=="id"
		var labels: Dictionary={"first":"REKOR PERTAMA" if id_language else "FIRST RECORD","best":"REKOR WAKTU BARU" if id_language else "NEW PERSONAL BEST","saved":"REKOR TERSIMPAN" if id_language else "RECORD SAVED","unavailable":"REKOR BELUM TERSIMPAN" if id_language else "RECORD NOT SAVED"}
		_record_summary.text=str(labels.get(victory.record_result,""))
		if victory.record_result!="unavailable":_record_summary.text+=" · "+preload("res://scripts/data/stage_record_book.gd").clock(int(victory.record_report.get("time_ms",0)))
		_record_summary.show()
	_refresh_report_rows()

func _report_label(text: String,color: Color,font_size: int=15) -> Label:
	var label:=Label.new();label.text=text
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color",color)
	label.add_theme_font_size_override("font_size",font_size)
	return label

func _refresh_report_rows() -> void:
	if _report_rows==null:return
	for child: Node in _report_rows.get_children():_report_rows.remove_child(child);child.queue_free()
	var indonesian: bool=SettingsManager.language=="id"
	_damage_tab.text="DAMAGE"
	_skills_tab.text="SKILL" if indonesian else "SKILLS"
	_damage_tab.set_pressed_no_signal(not _show_skills);_skills_tab.set_pressed_no_signal(_show_skills)
	if _show_skills:
		for skill: Dictionary in _report_skills:
			var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);_report_rows.add_child(row)
			var icon:=TextureRect.new();icon.name="ReportSkillIcon_"+str(skill.id);icon.texture=load(preload("res://scripts/data/skill_catalog.gd").get_icon_path(str(skill.id),str(skill.get("armament_id",""))))
			icon.custom_minimum_size=Vector2(28,28);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(icon)
			row.add_child(_report_label(str(skill.name),Color(.84,.91,.86)))
			var level:=_report_label("Lv."+str(skill.level),Color(.83,.75,.51));level.name="ReportSkillLevel";level.autowrap_mode=TextServer.AUTOWRAP_OFF;level.custom_minimum_size.x=44;level.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;level.size_flags_horizontal=Control.SIZE_SHRINK_END;row.add_child(level)
	else:
		var total: float=0
		for item: Dictionary in _report_damage:total+=float(item.damage)
		_report_rows.add_child(_report_label(("TOTAL TERCATAT" if indonesian else "TOTAL RECORDED")+"  "+str(roundi(total)),Color(.94,.84,.60),17))
		for item: Dictionary in _report_damage:
			var row:=VBoxContainer.new();row.add_theme_constant_override("separation",4);_report_rows.add_child(row)
			var heading:=HBoxContainer.new();row.add_child(heading)
			heading.add_child(_report_label(str(item.name),Color(.84,.91,.86)))
			var number:=_report_label(str(roundi(float(item.damage))),Color(.96,.86,.65));number.name="ReportDamageAmount";number.autowrap_mode=TextServer.AUTOWRAP_OFF;number.custom_minimum_size.x=56;number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;number.size_flags_horizontal=Control.SIZE_SHRINK_END;heading.add_child(number)
			var bar:=ProgressBar.new();bar.custom_minimum_size.y=4;bar.show_percentage=false;bar.max_value=maxf(total,1);bar.value=float(item.damage);row.add_child(bar)
			var fill:=StyleBoxFlat.new();fill.bg_color=Color(.30,.72,.59);fill.set_corner_radius_all(2);bar.add_theme_stylebox_override("fill",fill)
			var bg:=StyleBoxFlat.new();bg.bg_color=Color(.1,.23,.24);bg.set_corner_radius_all(2);bar.add_theme_stylebox_override("background",bg)
		if _report_partial:
			_report_rows.add_child(_report_label("Catatan damage dimulai setelah Continue." if indonesian else "Damage tracking started after Continue.",Color(.65,.74,.72),12))
	_scroll.set_deferred("scroll_vertical",0)
	fit.call_deferred()
