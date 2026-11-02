extends SceneTree
const Contract = preload("res://tests/pavilion_layout_contract.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://.local/pavilion_review"
func _initialize() -> void: run.call_deferred()
func frames(count: int = 16) -> void:
	for index: int in count: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("PAVILION_LAYOUT " + label)
func wallet() -> Dictionary:
	return {"pavilion":root.get_node("PavilionManager").state.duplicate(true),"inventory":root.get_node("InventoryManager").item_counts.duplicate(true),"stones":root.get_node("ProgressionManager").spirit_stone}
func color(c: Color) -> Array: return [c.r,c.g,c.b,c.a]
func box(r: Rect2) -> Array: return [r.position.x,r.position.y,r.size.x,r.size.y]
func style(s: StyleBox) -> Dictionary:
	var record: Dictionary = {"margins":[s.get_content_margin(SIDE_LEFT),s.get_content_margin(SIDE_TOP),s.get_content_margin(SIDE_RIGHT),s.get_content_margin(SIDE_BOTTOM)]}
	if s.get_script() != null and s.get_script().resource_path.ends_with("pavilion_imperial_style.gd"):
		record.merge({"kind":"imperial","texture":s.MATERIAL.resource_path,"corner":[s.corner.x,s.corner.y],"selected":s.selected,"tint":color(s.tint)})
	elif s is StyleBoxFlat:
		record.merge({"kind":"flat","color":color(s.bg_color),"border":color(s.border_color),"widths":[s.border_width_left,s.border_width_top,s.border_width_right,s.border_width_bottom],"radius":s.corner_radius_top_left})
	elif s is StyleBoxTexture:
		record.merge({"kind":"texture","texture":s.texture.resource_path,"region":box(s.region_rect),"slice":[s.texture_margin_left,s.texture_margin_top,s.texture_margin_right,s.texture_margin_bottom]})
	else: record["kind"] = "empty"
	return record
func text_data(c: Control, text: String, width: float, wrap: bool) -> Dictionary:
	var font: Font = c.get_theme_font("font")
	var font_size: int = c.get_theme_font_size("font_size")
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE if wrap else TextServer.BREAK_MANDATORY
	paragraph.add_string(text,font,font_size)
	var lines: Array = []; var widths: Array = []
	for i: int in paragraph.get_line_count():
		var span: Vector2i = paragraph.get_line_range(i)
		lines.append(text.substr(span.x,span.y-span.x).strip_edges())
		widths.append(font.get_string_size(lines[-1],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
	return {"text":text,"lines":lines,"widths":widths,"font":font.resource_path,"font_size":font_size,"line_height":font.get_height(font_size),"ascent":font.get_ascent(font_size),"color":color(c.get_theme_color("font_disabled_color" if c is Button and c.disabled else "font_color"))}
func walk(node: Node, records: Array) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is AnimatedSprite2D and node.name == "AuraHeroIdle":
		var frame: AtlasTexture = node.sprite_frames.get_frame_texture(node.animation,node.frame) as AtlasTexture
		var rect: Rect2 = node.get_global_transform() * Rect2(-frame.region.size * 0.5,frame.region.size)
		records.append({"class":"ActorSprite","name":node.name,"rect":box(rect),"texture":frame.atlas.resource_path,"region":box(frame.region),"layer":0,"z":0})
	if node is Control and node.size.x > 0 and node.size.y > 0:
		var r: Dictionary = {"class":node.get_class(),"name":node.name,"path":str(node.get_path()),"rect":box(node.get_global_rect()),"script":node.get_script().resource_path if node.get_script() != null else "","z":node.z_index,"layer":node.get_canvas_layer_node().layer if node.get_canvas_layer_node() != null else 0}
		if node is ColorRect: r["color"] = color(node.color)
		if node is TextureRect and node.texture != null: r.merge({"texture":node.texture.resource_path,"stretch":node.stretch_mode})
		if node is NinePatchRect and node.texture != null:
			r["style"] = {"kind":"texture","texture":node.texture.resource_path,"slice":[node.patch_margin_left,node.patch_margin_top,node.patch_margin_right,node.patch_margin_bottom],"draw_center":node.draw_center}
		if node is PanelContainer or node is Panel: r["style"] = style(node.get_theme_stylebox("panel"))
		if node is Button:
			r["style"] = style(node.get_theme_stylebox("disabled" if node.disabled else "normal"))
			r["copy"] = text_data(node,node.text,maxf(1,node.size.x-node.get_theme_stylebox("normal").get_minimum_size().x),node.autowrap_mode != TextServer.AUTOWRAP_OFF)
			r["alignment"] = node.alignment
		if node is Label:
			r["copy"] = text_data(node,node.text,node.size.x,node.autowrap_mode != TextServer.AUTOWRAP_OFF)
			r["alignment"] = node.horizontal_alignment; r["valign"] = node.vertical_alignment
		if node is ProgressBar: r.merge({"progress":node.ratio,"back":style(node.get_theme_stylebox("background")),"fill":style(node.get_theme_stylebox("fill"))})
		if node is ScrollContainer or node.clip_contents: r["clip"] = true
		if r.script.ends_with("pavilion_sanctum_stage.gd"):
			r["relic"] = node.relic.resource_path if node.relic != null else ""
		if r.script.ends_with("wuxia_hub_nav.gd"):
			r["nav_frame"] = style(node.sanctuary_frame); r["active_tab"] = node.active_tab
		if r.script.ends_with("pavilion_aura_preview.gd"):
			node._visual.build(node.aura_id,0,root.get_node("SettingsManager").reduced_effects)
			r["aura"] = node._visual.snapshot(); r["aura_scale"] = node._scale_value; r["aura_origin"] = [node._actor_origin.x,node._actor_origin.y]
		records.append(r)
	for child: Node in node.get_children(): walk(child,records)
func record(label: String) -> void:
	if "--safe-area" in OS.get_cmdline_user_args(): label = "safe-" + label
	var records: Array = []; walk(root,records)
	var file := FileAccess.open(output + "/" + label + ".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"viewport":[root.size.x,root.size.y],"native_gui":DisplayServer.get_name()!="headless","nodes":records}));file.close()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_aura_live_qa"): quit(2); return
	create_timer(110).timeout.connect(func(): push_error("Pavilion review watchdog");quit(3))
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	var guide: Node = root.get_node_or_null("RefineOnboarding")
	if guide != null: guide.completed = true; guide.set_process(false)
	var conf := ConfigFile.new();conf.set_value("meta","version",2)
	for id: String in ["pavilion","equipment"]: conf.set_value("tutorials",id,true)
	conf.save("user://jade_onboarding.cfg")
	var journey: Node = root.get_node("JourneyManager")
	for chapter: int in journey.get_chapter_ids():
		for stage: int in journey.get_stage_ids(chapter): journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
	root.get_node("PavilionManager").state.celestial_jade = 139
	root.get_node("PavilionManager").state.pavilion_seals = 1
	root.get_node("PavilionManager").state.pity_legendary = 23
	root.get_node("PavilionManager").state.starter_seals_claimed = true
	root.get_node("ProgressionManager").spirit_stone = 16000
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size = Vector2i.ZERO
	DirAccess.make_dir_recursive_absolute(output)
	var quick: bool = "--quick" in OS.get_cmdline_user_args()
	var sizes: Array = [Vector2i(390,844),Vector2i(648,1440)] if quick else [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(648,1440),Vector2i(720,1600)]
	if "--safe-area" in OS.get_cmdline_user_args(): sizes = [Vector2i(648,1440)]
	for locale: String in (["en"] if quick else ["id","en"]):
		root.get_node("SettingsManager").set_presentation("language",locale)
		for dims: Vector2i in sizes:
			root.size = dims;change_scene_to_file("res://scenes/ui/pavilion_screen.tscn");await frames(24)
			var screen: Control = current_scene
			if "--safe-area" in OS.get_cmdline_user_args():
				var safe: Control = screen.get_node("SafeArea")
				safe.offset_top = 90; safe.offset_bottom = -12; await frames()
			if screen.has_node("JadeOnboardingOverlay"):screen.get_node("JadeOnboardingOverlay").hide()
			var before: Dictionary = wallet()
			for tab: String in ["summon","aura"]:
				screen._select_focus_tab(tab);await frames()
				var errors: Array[String] = Contract.inspect(screen)
				check(errors.is_empty(),"%s %s %s: %s" % [locale,str(dims),tab,str(errors)])
				record("%s-%d-%d-%s" % [locale,dims.x,dims.y,tab])
				if tab == "summon":
					screen._select_summon_mode(true);await frames()
					check(Contract.inspect(screen).is_empty(),"paid layout fits " + str(dims))
					record("%s-%d-%d-paid" % [locale,dims.x,dims.y])
					screen._select_summon_mode(false);await frames()
			check(wallet() == before,"all page/mode browsing is read-only " + str(dims))
			if dims == Vector2i(390,844) and not quick:
				for sheet: String in ["daily","info","target","odds","history"]:
					screen._select_focus_tab("summon");await frames()
					match sheet:
						"daily":screen._open_daily()
						"info":screen._open_mode_info()
						"target":screen._open_target_picker("weapon")
						"odds":screen._show_drop_rates_overlay()
						"history":screen._show_history_overlay()
						"equipment":screen._open_equipment_detail("mistveil_jian")
					await frames(24)
					check(Contract.inspect_sheet(screen).is_empty(),locale + " modal fits: " + sheet)
					record(locale+"-390-844-sheet-"+sheet)
					screen._back();await frames()
				check(wallet() == before,"opening sheets cannot spend, claim or equip")
			current_scene.queue_free(); current_scene = null;await frames()
	print("PAVILION_LAYOUT checks=%d failures=%d; NATIVE_GUI=%s; PHONE=NOT_TESTED" % [checks,failures,str(DisplayServer.get_name()!="headless")])
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	quit(1 if failures else 0)
