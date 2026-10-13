extends SceneTree
var checks: int=0
var failures: int=0
var live: Node
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(label)
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for _frame in range(9): await process_frame
func economy() -> Dictionary:
	return {"pavilion":root.get_node("PavilionManager").state.duplicate(true),"inventory":root.get_node("InventoryManager").item_counts.duplicate(true),"stones":root.get_node("ProgressionManager").spirit_stone,"ledger":live._get_ledger().duplicate()}
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_event_qa"): quit(2);return
	await create_timer(.5).timeout
	live=root.get_node("LiveOpsManager")
	var settings: Node=root.get_node("SettingsManager")
	var before: Dictionary=economy()
	var seen: Array[String]=[]
	var screen: Control
	for locale: String in ["en","id"]:
		TranslationServer.set_locale(locale)
		var viewport:=SubViewport.new();viewport.size=Vector2i(648,1152);root.add_child(viewport)
		screen=load("res://scenes/ui/event_center_screen.tscn").instantiate();viewport.add_child(screen);await settle()
		check(screen._grid.get_child_count()==7,"seven existing activities retained")
		for dims: Vector2i in [Vector2i(648,1152),Vector2i(390,844),Vector2i(320,568),Vector2i(896,504),Vector2i(648,1152)]:
			viewport.size=dims;screen._fit_layout();await settle()
			check(screen._popup.get_rect().end.x<=dims.x+1 and screen._popup.position.x>=0,"popup fits after resize "+str(dims)+locale)
			check(screen._popup.get_rect().end.y<=dims.y+1 and screen._popup.position.y>=0,"popup fits height "+str(dims)+locale)
			check(screen._chrome_frame.get_rect()==screen._popup.get_rect(),"frame follows popup")
			check(screen._scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"no horizontal scrolling")
			for id: String in screen._activity_handles:
				var h: Dictionary=screen._activity_handles[id]
				check(h.art.artwork!=null,"native artwork loaded "+id)
				check(h.art.mouse_filter==Control.MOUSE_FILTER_IGNORE,"art passes swipes "+id)
				check(h.cta.mouse_filter==Control.MOUSE_FILTER_PASS,"CTA allows touch scroll "+id)
				check(h.cta.get_theme_stylebox("normal").get_script()!=null,"CTA uses native material "+id)
				var destinations: Array=h.cta.pressed.get_connections().filter(func(connection: Dictionary) -> bool: return connection.callable.get_method()=="_open_destination")
				check(destinations.size()==1 and destinations[0].callable.get_bound_arguments()==[id],"CTA preserves correct navigation destination "+id)
				check(h.panel.get_global_rect().end.x<=screen._scroll.get_global_rect().end.x+1,"activity fits scroll width "+id)
				if locale=="en" and seen.size()<5 and dims==Vector2i(648,1152) and id not in ["daily","pavilion"]:
					var path: String=h.art.artwork.resource_path
					check(path not in seen,"five distinct event illustrations "+id);seen.append(path)
				if id not in ["daily","pavilion"]: check(h.art.artwork.get_width()<=1024,"texture memory cap "+id)
			check(economy()==before,"opening/resizing UI changes no reward or progression state")
		check(screen._hero_art.texture.resource_path.ends_with("seven_day_ascension_hero_portrait_bg.png"),"approved seven-day art retained")
		var journey: Node=root.get_node("JourneyManager")
		var saved_keys: Array=journey.cleared_stage_keys.duplicate()
		for chapter: int in journey.get_chapter_ids():
			for stage: int in journey.get_stage_ids(chapter): journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
		live.live_ops_changed.emit();await settle()
		check(screen._activity_handles.pilgrimage.art.claim_ready,"real manager readiness updates ambient claim indicator")
		check(screen._activity_handles.pilgrimage.status.text.contains("3"),"real manager readiness updates status label")
		check(economy()==before,"readiness presentation never grants rewards")
		journey.cleared_stage_keys.assign(saved_keys);live.live_ops_changed.emit();await settle()
		check(not screen._activity_handles.pilgrimage.art.claim_ready,"readiness indicator clears when manager says unavailable")
		screen._scroll.scroll_vertical=int(screen._grid.position.y);await settle()
		var art: Control=screen._activity_handles.pilgrimage.art
		art.set_process(false);var tick: int=art.render_ticks
		settings.reduced_effects=false;art._process(.06)
		check(art.render_ticks>tick,"visible art has capped ambient redraw")
		tick=art.render_ticks;settings.reduced_effects=true;art._process(.5)
		check(art.render_ticks==tick,"reduced effects suspends ambient animation")
		settings.reduced_effects=false;screen._scroll.scroll_vertical=int(screen._scroll.get_v_scroll_bar().max_value);await settle()
		tick=art.render_ticks;art._process(.5)
		check(art.render_ticks==tick,"offscreen art stops ambient redraw")
		screen._press_scroll_y["pilgrimage"]=screen._scroll.scroll_vertical
		screen._on_scroll_started();screen._open_destination("pilgrimage")
		check(not root.get_node("SceneTransitionManager").is_transitioning,"swipe release does not open an activity")
		screen._on_scroll_ended()
		viewport.queue_free();await settle()
	check(seen.size()==5,"five generated identities are all distinct")
	for key: String in ["pilgrimage","boss_hunt","heavenly_ladder","treasure_hunt","five_elements"]:
		var paths: Dictionary={"pilgrimage":"jade_valley_pilgrimage","boss_hunt":"celestial_boss_hunt","heavenly_ladder":"heavenly_ladder","treasure_hunt":"celestial_treasure_hunt","five_elements":"path_of_five_elements"}
		var viewport:=SubViewport.new();viewport.size=Vector2i(390,844);root.add_child(viewport)
		var page: Control=load("res://scenes/ui/"+paths[key]+"_screen.tscn").instantiate();viewport.add_child(page);await settle()
		var art: Control=page.find_child("EventIdentityArtwork",true,false)
		check(art!=null and art.identity==key,"detail uses matching identity "+key)
		check(economy()==before,"detail artwork changes no reward state "+key)
		check(page._content.get_global_rect().end.x<=391,"detail content fits portrait width "+key)
		viewport.queue_free();await settle()
	var popup_view:=SubViewport.new();popup_view.size=Vector2i(390,844);root.add_child(popup_view)
	screen=load("res://scenes/ui/event_center_screen.tscn").instantiate();screen.set_meta("liveops_popup",true);popup_view.add_child(screen);await settle()
	check(not screen.has_node("StandaloneHomeBackdrop"),"Home popup retains Home-owned background")
	check(screen._popup.get_rect().end.x<=391,"Home popup keeps illustrated cards within safe width")
	check(screen._close_button.get_rect().end.x<=391,"Home popup close remains reachable")
	check(economy()==before,"Home popup presentation changes no rewards")
	popup_view.queue_free();await settle()
	# Opening and closing immediately must invalidate deferred layout callbacks.
	for _pass_index in range(12):
		var viewport:=SubViewport.new();viewport.size=Vector2i(390,844);root.add_child(viewport)
		screen=load("res://scenes/ui/event_center_screen.tscn").instantiate();viewport.add_child(screen)
		viewport.remove_child(screen);screen.queue_free();viewport.queue_free();await process_frame
	await settle()
	check(economy()==before,"rapid close never modifies progress or claims")
	print("EVENT_IDENTITY_QA checks=",checks," failures=",failures)
	await create_timer(.75).timeout
	quit(1 if failures else 0)
