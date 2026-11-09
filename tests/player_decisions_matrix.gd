extends SceneTree
var checks: int = 0
var failures: int = 0
var case_name: String
const POPUPS := ["new_player_event_screen", "celestial_boss_hunt_screen"]
const SCENES := [
	"achievement_screen","backpack_screen","celestial_boss_hunt_screen",
	"celestial_treasure_hunt_screen","celestial_treasury_screen","chapter_select",
	"credits_screen","cultivation_menu","daily_quest_screen","equipment_screen",
	"event_center_screen","google_account_entry","heavenly_ladder_screen",
	"heavenly_trials_screen","jade_valley_pilgrimage_screen","mailbox_screen",
	"main_menu","new_player_event_screen","odyssey_screen","path_of_five_elements_screen",
	"pavilion_screen","privacy_screen","settings_screen","skill_book_screen",
	"stage_select","training_ground"
]

func _initialize() -> void:
	run.call_deferred()

func frames(count: int = 12) -> void:
	for index: int in count:
		await process_frame

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("DECISIONS_FAIL " + case_name + " " + what)

func rect_of(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,control.size)

func fits(control: Control, what: String) -> void:
	if not is_instance_valid(control):
		check(false,what + " missing")
		return
	check(control.is_visible_in_tree() and root.get_visible_rect().grow(1).encloses(rect_of(control)),what + " " + str(rect_of(control)))

func readable(label: Label, what: String) -> void:
	fits(label,what + " in viewport")
	if not is_instance_valid(label):
		return
	check(label.get_line_count() == label.get_visible_line_count(),what + " lines")
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var width: float = label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
		check(width <= label.size.x + 2, what + " natural width")

func tap(button: BaseButton) -> void:
	if not is_instance_valid(button):
		check(false,"button missing")
		return
	var point: Vector2 = rect_of(button).get_center()
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
		await frames(1)
	await frames()

func open_view(view: String) -> Node:
	var path: String = "res://scenes/ui/"+view+".tscn"
	if view in POPUPS:
		change_scene_to_file("res://scenes/ui/main_menu.tscn")
		await frames()
		var live: Node = root.get_node("LiveOpsManager")
		live.open_live_popup(path)
		await frames()
		return live._active_live_popup
	check(change_scene_to_file(path)==OK,"scene load")
	await frames(16)
	return current_scene

func apply_insets(view: Node) -> void:
	if root.size.x != 320:
		return
	for safe: Control in view.find_children("*","Control",true,false):
		if safe.has_method("refresh_safe_area") and safe.size.y >= root.size.y*.96 and safe.size.x >= root.size.x*.96:
			safe.offset_top = 24.0
			safe.offset_bottom = -32.0

func audit(view_name: String, view: Node, locale: String) -> void:
	match view_name:
		"main_menu":
			var presenter: Control = view.get_node("HomeUI/HomeProductionOverlay")
			readable(presenter.profile_rank,"home rank")
			presenter._open_profile()
			await frames(16)
			fits(view.profile_sheet_panel,"profile inner panel")
			check(view.profile_sheet_body.size.x <= view.profile_scroll.size.x + 1,"profile scroll width")
			var close: Button = view.profile_sheet_panel.find_child("CloseButton",true,false)
			fits(close,"profile close")
			await tap(close)
			check(not view.profile_overlay.visible,"profile tap closes")
		"stage_select":
			view._on_stage_node_pressed(3)
			await frames()
			readable(view.find_child("StageTacticalHint",true,false),"stage hint")
			view._show_start_confirm_dialog()
			await frames()
			fits(view.find_child("ReplaceRunPanel",true,false),"replace-run dialog")
			var keep: Button = view.find_child("KeepSavedRun",true,false)
			fits(keep,"keep saved run")
			fits(view.find_child("StartNewTrial",true,false),"start new trial")
			await tap(keep)
			check(not view.confirm_overlay.visible,"cancel keeps current scene")
		"equipment_screen":
			view._slot_pressed("armament")
			await frames()
			fits(view.weapon_picker,"candidate picker")
			check(view.weapon_picker.text == ("GANTI KANDIDAT" if locale=="id" else "CHANGE CANDIDATE"),"short caption")
			check(view.weapon_comparison != null,"both weapon cards")
			view._close_detail()
		"skill_book_screen":
			view._search.text = "Jade Binding Chain"
			view._refresh()
			await frames()
			check(view._selected == "jade_binding_chain","selection follows search")
			readable(view._summary_text,"selected gear name")
			readable(view._summary_meta,"ownership")
			readable(view._summary_stats,"gear stats")
			view._open_equipment_detail("jade_binding_chain")
			await frames(16)
			fits(view._detail_panel,"gear details")
			view._close_popup()
			view._search.text = "unmatched-author-fixture"
			view._refresh()
			await frames()
			check(not view._summary.visible,"empty search hides stale selection")
		"daily_quest_screen","achievement_screen":
			var trials: Node = view.get_node("TrialsProductionPresenter")
			fits(trials.header_panel,"header")
			fits(trials.claim_all_button,"claim action")
			if view_name == "daily_quest_screen":
				var daily: Node = root.get_node("DailyQuestManager")
				var record: String = daily.get_daily_quest_ids()[0]
				daily.completed_quest_ids.append(record)
				daily.quest_progress[record] = daily.get_target(record)
				trials._refresh()
				await frames(20)
				check(not trials.claim_all_button.disabled,"claimable action enabled")
				readable(trials.completion_reward,"claim totals and bonus")
				daily.completed_quest_ids.erase(record)
				daily.quest_progress[record] = 0
		"pavilion_screen":
			view._select_summon_mode(true)
			await frames()
			check(view.paid_mode and view._paid_status.visible,"paid status displayed")
			check(view._paid_status.text.contains("verifi"),"guest sees unverified balance")
			check(view._paid_buttons[0].text.contains("100") and view._paid_buttons[1].text.contains("900"),"paid cost and count")
			view._select_summon_mode(false)
			await frames()
			check(not view._paid_status.visible and view._focus_normal_row.visible,"earned mode actions")
		"heavenly_trials_screen":
			for index: int in 3:
				view._risk_picker.select(index)
				view._risk_picker.item_selected.emit(index)
				await frames(3)
				readable(view._risk_summary,"risk effect %d" % index)
				check(view._risk_summary.text.contains(["9","7","+15%"][index]),"actual selected risk effect")
			fits(view._entry,"trial entry")
		"new_player_event_screen":
			check(rect_of(view._header).grow(1).encloses(rect_of(view._header_copy)),"header copy stays in its artwork reader")
			for day: int in [1,view._total_days()]:
				view._selected_day = day
				view._refresh_footer()
				await frames()
				readable(view._day_title,"Ascension day %d" % day)
				fits(view._root,"Ascension panel")
				readable(view._day_status,"Ascension day status")
				fits(view._action,"Ascension claim or lock")
				check(view._action.disabled == (view._state(day) != "ready"),"real claim eligibility")
				if day == view._total_days():
					readable(view._seal_reward_note,"final Seal")
					var output_dir: String = OS.get_environment("JADE_DECISION_RENDER_DIR")
					if DisplayServer.get_name() != "headless" and not output_dir.is_empty():
						await RenderingServer.frame_post_draw
						check(root.get_texture().get_image().save_png(output_dir.path_join("ascension-final-%d-%s.png" % [root.size.x, locale])) == OK,"native capture")
		"celestial_boss_hunt_screen":
			var shown: bool = false
			for label: Label in view.find_children("*","Label",true,false):
				if label.text in ["Klaim biasa tersedia","Standard claim available"] and label.is_visible_in_tree():
					shown = true
					check(label.get_line_count() == label.get_visible_line_count(),"standard claim note wraps")
			check(shown,"standard claim note exists")

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_decision_qa"):
		quit(2)
		return
	await frames()
	var prewarm: Node = root.get_node_or_null("MenuResourcePrewarm")
	if prewarm != null:
		prewarm.free()
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var cfg := ConfigFile.new()
	cfg.set_value("meta","version",2)
	for key: String in ["home","equipment","pavilion"]:
		cfg.set_value("tutorials",key,true)
	cfg.save("user://jade_onboarding.cfg")
	root.get_node("RefineOnboarding").completed = true
	var inventory: Node = root.get_node("InventoryManager")
	inventory.item_counts = {"jade_binding_chain":2,"celestial_returning_glaive":1,"nine_heavens_star_sword":1}
	root.get_node("EquipmentManager").equip_item("jade_binding_chain")
	var journey: Node = root.get_node("JourneyManager")
	journey.unlocked_stage_keys.assign(["1-1","1-2","1-3","1-4","1-5"])
	journey.cleared_stage_keys.assign(["1-1","1-2","1-3","1-4","1-5"])
	journey.select_stage(1,3)
	var settings: Node = root.get_node("SettingsManager")
	settings.reduced_effects = true
	var dimensions: Array[Vector2i] = [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]
	var scenes: Array = SCENES
	if DisplayServer.get_name() != "headless":
		dimensions = [Vector2i(320,568)]
		scenes = ["main_menu","equipment_screen","stage_select","daily_quest_screen","achievement_screen","skill_book_screen","pavilion_screen","heavenly_trials_screen","new_player_event_screen","celestial_boss_hunt_screen"]
	if OS.get_cmdline_user_args().has("--ascension-only"):
		dimensions = [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]
		scenes = ["new_player_event_screen"]
	for locale: String in ["en","id"]:
		settings.set_presentation("language",locale)
		for dims: Vector2i in dimensions:
			root.size = dims
			for scene_name: String in scenes:
				case_name = "%s %s %s" % [locale,dims,scene_name]
				var old_fails: int = failures
				var view: Node = await open_view(scene_name)
				check(is_instance_valid(view),"production view opened")
				if is_instance_valid(view):
					apply_insets(view)
					await frames()
					await audit(scene_name,view,locale)
				if scene_name in POPUPS:
					root.get_node("LiveOpsManager").close_live_popup()
					await frames(3)
				paused = false
				print("DECISION_CASE %s failures=%d" % [case_name,failures-old_fails])
	if is_instance_valid(current_scene):
		current_scene.free()
		current_scene = null
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("DECISION_MATRIX checks=%d failures=%d display=%s" % [checks,failures,DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)
