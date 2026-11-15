extends SceneTree
## Isolated production UI/input fixtures, not phone FPS or a reward transaction.
var checks: int=0
var failures: int=0
var checks_finished: bool=false

func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("STAGE_FLOW_FAIL "+message)
func frames(count: int=8) -> void:
	for index: int in range(count):await process_frame
func touch(at: Vector2, down: bool) -> void:
	var event:=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=down
	Input.parse_input_event(event);await frames(2)
func tap(button: Button) -> void:
	await touch(button.get_global_rect().get_center(),true)
	await touch(button.get_global_rect().get_center(),false)
	await frames()
func swipe(at: Vector2) -> void:
	await touch(at,true)
	for index: int in range(1,9):
		var event:=InputEventScreenDrag.new();event.index=0
		event.position=at+Vector2(0,-8*index);event.relative=Vector2(0,-8)
		Input.parse_input_event(event);await frames(1)
	await touch(at+Vector2(0,-64),false);await frames()
func scene(path: String) -> void:
	paused=false;check(change_scene_to_file(path)==OK,"production scene "+path)
	await scene_changed;await frames(12)
func dispose() -> void:
	paused=false
	if is_instance_valid(current_scene):current_scene.queue_free();current_scene=null
	await frames()

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_stage_flow_qa"):quit(2);return
	create_timer(100).timeout.connect(func():if not checks_finished:quit(1))
	await frames();Input.set_emulate_touch_from_mouse(true)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	var settings: Node=root.get_node("SettingsManager")
	var journey: Node=root.get_node("JourneyManager")
	var saver: Node=root.get_node("SaveManager")
	var progression: Node=root.get_node("ProgressionManager")
	journey.unlocked_stage_keys.append(journey.get_stage_key(2,1))
	for language: String in ["en","id"]:
		settings.set_presentation("language",language)
		journey.selected_chapter_id=2;journey.selected_stage_id=1
		root.size=Vector2i(320,568);await scene("res://scenes/ui/stage_select.tscn")
		var page: Control=current_scene
		for dimensions: Vector2i in [Vector2i(320,568),Vector2i(405,860),Vector2i(648,1152),Vector2i(860,405)]:
			root.size=dimensions;await frames()
			journey.campaign_energy={"units":0,"anchor":int(Time.get_unix_time_from_system())}
			var energy_before: Dictionary=journey.campaign_energy.duplicate(true)
			page.preview_stage_id=1;page._refresh_selected_stage_panel();await frames()
			var context: String=language+str(dimensions)
			check(page.start_button.disabled and page.start_button.text==("PERLU 2 ENERGI" if language=="id" else "NEED 2 ENERGY"),"blocked CTA identifies energy "+context)
			check(page._energy_label.text.contains("Siap dalam" if language=="id" else "Ready in"),"available stage explains wait "+context)
			check(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(1).encloses(page.start_button.get_global_rect()),"Start remains in viewport "+context)
			page.preview_stage_id=2;page._refresh_selected_stage_panel();await frames()
			check(page.start_button.disabled and page.start_button.text==("UJIAN TERKUNCI" if language=="id" else "TRIAL LOCKED"),"locked CTA keeps progression gate "+context)
			check(not page._energy_label.text.contains("Siap dalam") and not page._energy_label.text.contains("Ready in"),"locked stage never promises timer unlock "+context)
			page.preview_stage_id=1
			journey.campaign_energy={"units":2,"anchor":int(Time.get_unix_time_from_system())}
			page._refresh_selected_stage_panel();await frames()
			check(not page.start_button.disabled and page.start_button.text==("MULAI UJIAN" if language=="id" else "BEGIN TRIAL"),"recovered energy restores ready caption "+context)
			check(bool(saver.begin_save_write_barrier("stage-flow-qa","isolated UI recovery state").success),"acquire owned recovery barrier")
			page._refresh_stage_energy();await frames()
			check(page.start_button.disabled and page.start_button.text==("PULIHKAN SAVE" if language=="id" else "RECOVER SAVE"),"save recovery reason takes priority "+context)
			check(bool(saver.end_save_write_barrier("stage-flow-qa").success),"release owned recovery barrier")
			page._refresh_stage_energy()
			check(not page.start_button.disabled,"leaving recovery restores ready action "+context)
			journey.cleared_stage_keys.append(journey.get_stage_key(2,1))
			page._refresh_selected_stage_panel();await frames()
			check(page.start_button.text==("ULANGI UJIAN" if language=="id" else "REPLAY TRIAL") and page._energy_label.text.contains("Gratis" if language=="id" else "Free"),"replay is explicitly free "+context)
			journey.cleared_stage_keys.erase(journey.get_stage_key(2,1))
			check(journey.campaign_energy.units==2 and energy_before.units==0,"presentation never debits energy "+context)
		root.size=Vector2i(320,568);await frames()
		var safe: Control=page.get_node("SafeArea")
		safe.offset_left=12;safe.offset_right=-12;safe.offset_top=20;safe.offset_bottom=-24
		page._refresh_selected_stage_panel();await frames()
		check(safe.get_global_rect().grow(1).encloses(page.start_button.get_global_rect()),"stage CTA respects compact safe insets "+language)
		await dispose()
	journey.selected_chapter_id=1;journey.selected_stage_id=1
	root.get_node("GameSession").start_new_game();journey.begin_selected_stage()
	await scene("res://scenes/levels/level_1.tscn");await create_timer(.3).timeout
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
	current_scene.get_node("EnemySpawner").set_process(false);current_scene.get_node("EnemySpawner").clear_normal_enemies()
	current_scene.get_node("WaveManager").set_process(false)
	var player: Node=current_scene.get_node("player_1");player.set_physics_process(false)
	var weapons: Node=player.get_node("WeaponManager");weapons.set_process(false)
	weapons.add_fire_orb();weapons.add_yin_yang_blades();weapons.add_thunder_talisman()
	player.get_node("PlayerStats").power_level=4
	var ledger: Node=weapons.get_node("RunCombatLedger")
	ledger.totals={"fire_orb":10000.0,"spirit_sword":4000.0}
	player.get_node("PlayerHealth").take_damage(10000);await frames(15)
	# Fix the display-only totals after all final combat callbacks have settled.
	ledger.totals={"fire_orb":10000.0,"spirit_sword":4000.0}
	var stones_before: int=progression.spirit_stone
	var clears_before: Array=journey.cleared_stage_keys.duplicate()
	var ledger_before: Dictionary=ledger.snapshot().duplicate(true)
	var defeat: Node=current_scene.get_node("GameOverUI")
	var victory: Node=current_scene.get_node("VictoryUI")
	for mode: String in ["defeat","victory"]:
		var ui: Node=defeat if mode=="defeat" else victory
		var ceremony: Node=ui.get_node("ResultCeremony")
		if mode=="victory":
			defeat.hide();victory.show_victory({},false);victory.show();await frames()
		else:ceremony.capture_defeat_report();ceremony._defeat_details.show()
		for language: String in ["en","id"]:
			settings.set_presentation("language",language)
			if mode=="victory":
				ui.show_victory({},false);await frames()
				check(ui.reward_header_label.text==("HADIAH MENUNGGU" if language=="id" else "REWARDS PENDING"),"pending save never claims rewards secured "+language)
				ui.show_victory({},true);await frames()
				check(ui.reward_header_label.text==ui.tr("REWARDS SECURED"),"saved presentation restores normal reward heading "+language)
				ui.show_victory({},false);await frames()
			for dimensions: Vector2i in [Vector2i(320,568),Vector2i(405,860),Vector2i(648,1152),Vector2i(860,405)]:
				root.size=dimensions;await frames(12)
				ceremony._show_skills=false;ceremony._refresh_report_rows();await frames()
				var context: String=mode+language+str(dimensions)
				var scroll: ScrollContainer=ceremony._scroll
				var tab_offset: int=roundi(ceremony._skills_tab.global_position.y-ceremony._body.global_position.y)-24
				scroll.scroll_vertical=maxi(0,tab_offset);await frames()
				check(scroll.get_global_rect().grow(1).encloses(ceremony._skills_tab.get_global_rect()),"tab is a real visible input target "+context)
				await swipe(ceremony._skills_tab.get_global_rect().get_center())
				check(not ceremony._show_skills,"first swipe on Skills does not switch tabs "+context)
				scroll.scroll_vertical=maxi(0,tab_offset);await frames()
				await tap(ceremony._skills_tab)
				check(ceremony._show_skills,"actual tap chooses Skills "+context)
				check(scroll.get_global_rect().grow(1).encloses(ceremony._skills_tab.get_global_rect()),"selected tab stays inside reader "+context)
				check(scroll.scroll_vertical>0 or scroll.get_v_scroll_bar().max_value<=scroll.get_v_scroll_bar().page,"tab switch keeps context or all content already fits "+context)
				await tap(ceremony._damage_tab)
				check(not ceremony._show_skills and scroll.get_global_rect().grow(1).encloses(ceremony._damage_tab.get_global_rect()),"Damage tab also keeps reader context "+context)
				var labels: Array=ceremony._report_rows.find_children("ReportDamageAmount","Label",true,false)
				if labels.size()<2 or not labels[0].text.contains("71.4%"):
					print("STAGE_FLOW_AMOUNTS ",context," ",labels.map(func(label: Label):return label.text))
				check(labels.size()>=2 and labels[0].text.contains("71.4%") and labels[1].text.contains("28.6%"),"damage contribution matches recorded total "+context)
				for amount: Label in labels:
					check(amount.get_line_count()==1 and amount.get_theme_font("font").get_string_size(amount.text,HORIZONTAL_ALIGNMENT_LEFT,-1,amount.get_theme_font_size("font_size")).x<=amount.size.x+1,"amount and percentage remain readable "+context)
				check(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(1).encloses(ceremony._panel.get_global_rect()),"result panel fits "+context)
			var fixture_rows: Array[Dictionary]=[{"name":"Fire Orb","damage":1.0e12},{"name":"Spirit Sword","damage":1.0}]
			ceremony._report_damage=fixture_rows
			ceremony._report_partial=true;ceremony._refresh_report_rows();await frames()
			var text: String=""
			for label: Label in ceremony._report_rows.find_children("*","Label",true,false):text+=label.text
			check(text.contains("<1%") and text.contains("Continue"),"tiny share and partial-history caveat remain explicit "+mode+language)
			ceremony._report_damage.clear();ceremony._report_skills.clear();ceremony._refresh_report_rows();await frames()
			check(ceremony._report_rows.get_child_count()>=2,"empty damage report explains its state "+mode+language)
			ceremony._show_skills=true;ceremony._refresh_report_rows();await frames()
			check(ceremony._report_rows.get_child_count()==1,"empty skills report explains its state "+mode+language)
			ceremony._report_damage=ledger.damage_rows();ceremony._report_skills=ledger.skills();ceremony._report_partial=false
		root.size=Vector2i(320,568);await frames()
		ceremony._safe.offset_left=12;ceremony._safe.offset_right=-12;ceremony._safe.offset_top=20;ceremony._safe.offset_bottom=-24
		ceremony.fit();await frames()
		check(ceremony._safe.get_global_rect().grow(1).encloses(ceremony._panel.get_global_rect()),"result panel respects compact safe insets "+mode)
	check(progression.spirit_stone==stones_before and journey.cleared_stage_keys==clears_before,"report browsing grants no reward or stage clear")
	check(ledger.snapshot().totals==ledger_before.totals and ledger.snapshot().metrics==ledger_before.metrics,"report browsing preserves combat evidence")
	check(not current_scene.get_node("GameOverManager").defeat_finalized,"report browsing does not finalize a recoverable defeat")
	print("STAGE_FLOW_CHECKS=",checks,";FAILURES=",failures,";DISPLAY=",DisplayServer.get_name())
	checks_finished=true
	if "--review" in OS.get_cmdline_user_args():
		settings.set_presentation("language","id" if "--id" in OS.get_cmdline_user_args() else "en")
		root.size=Vector2i(860,405) if "--landscape" in OS.get_cmdline_user_args() else Vector2i(320,568) if "--compact" in OS.get_cmdline_user_args() else Vector2i(405,860)
		if "--stage" in OS.get_cmdline_user_args():
			journey.selected_chapter_id=2;journey.selected_stage_id=1;journey.campaign_energy={"units":0,"anchor":int(Time.get_unix_time_from_system())}
			await scene("res://scenes/ui/stage_select.tscn")
		else:
			victory.hide();defeat.show();ledger.frozen=false
			var ceremony: Node=defeat.get_node("ResultCeremony");ceremony.capture_defeat_report();ceremony._defeat_details.show();ceremony.fit()
		return
	await dispose();await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	quit(1 if failures else 0)
