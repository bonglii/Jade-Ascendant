extends SceneTree
const Dot=preload("res://scripts/ui/action_ready_dot.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("EVENT_OFF_FAIL "+label)
func frames(n: int=6) -> void:
	for i: int in n:await process_frame
func _initialize() -> void:run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
	await frames(10);await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	var guide: Node=root.get_node_or_null("RefineOnboarding")
	if guide!=null:guide.completed=true;guide.set_process(false)
	var odyssey: Node=root.get_node("OdysseyClient");var trials: Node=root.get_node("HeavenlyTrialsClient")
	odyssey.set_process(false);trials.set_process(false)
	var now: int=int(Time.get_unix_time_from_system())
	odyssey.snapshot={"event":{"id":"off-qa","enabled":false,"ads_enabled":true,"purchases_enabled":true,"starts_at":now-60,"ends_at":now+86400},"state":{"rolls":30,"daily_rolls":5,"daily_ads":0,"day":Time.get_datetime_string_from_unix_time(now).substr(0,10),"milestones":[],"position":3,"tickets":6},"server_time":now,"revision":2};odyssey.status="connected";odyssey._received_msec=Time.get_ticks_msec()
	trials.snapshot={"campaign":{"enabled":false,"ads_enabled":true,"shop_enabled":true},"week":{"id":"ht_off_0","index":0,"starts_at":now-60,"ends_at":now+86400,"theme":"jade_wind","stage":5,"reward":{"celestial_jade":40,"pavilion_seal":1,"spirit_stone":600}},"progress":[{"clears":1,"claimed":0,"tier":1}],"previous_progress":[],"server_time":now,"unlock_tier":3,"shop_ready":false};trials.status="connected";trials._received=Time.get_ticks_msec()
	var before_odyssey: Dictionary=odyssey.snapshot.duplicate(true);var before_trials: Dictionary=trials.snapshot.duplicate(true)
	check(not odyssey.event_enabled() and not odyssey.event_active(),"off Odyssey is unavailable despite enabled sub-switches")
	check(not odyssey.watch_ad() and not odyssey.submit({"kind":"roll"}) and not odyssey.submit({"kind":"buy_dice","pack":1}),"off Odyssey cannot start ad, roll or dice exchange")
	check(not odyssey.purchase_bonus_active(),"off event cannot advertise purchase bonus")
	check(not trials.is_available() and trials.ready_count()==0,"off Trials hides entry and earned badge without deleting progress")
	check(not trials.watch_bonus(1) and not trials.action("start",{"tier":1}) and not trials.action("ad_intent",{"tier":1}),"off Trials cannot start attempts or new ads")
	check(Dot.count(root,"odyssey")==0 and Dot.count(root,"heavenly_trials")==0,"shared dots obey disabled event")
	check(not preload("res://scripts/data/odyssey_progress.gd").visible(odyssey.snapshot.event,odyssey.snapshot.state,now),"disabled Odyssey is absent from visibility adapter")
	check(odyssey.snapshot==before_odyssey and trials.snapshot==before_trials,"disabled gates never clear earned rewards or saved event state")
	change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(20)
	var presenter: Node=current_scene.get_node("HomeUI/HomeProductionOverlay");presenter.set_process(false);presenter._refresh_liveops_badges();await frames(14)
	check(presenter._featured_key not in ["odyssey","heavenly_trials"],"Home slideshow skips both disabled events")
	var ops: Node=root.get_node("LiveOpsManager")
	ops.open_live_popup("res://scenes/ui/event_center_screen.tscn");await frames(14)
	var hub: Node=ops._active_live_popup
	check(not hub._hero_stage.visible and not hub._activity_handles.heavenly_trials.card.visible,"All Events removes both disabled destinations")
	ops.close_live_popup();await frames()
	# Open each real page while active, then deliver a disabled snapshot.
	odyssey.snapshot.event.enabled=true;trials.snapshot.campaign.enabled=true
	check(trials.is_available(),"enabled current Trial week remains available")
	for scene: String in ["odyssey_screen","heavenly_trials_screen"]:
		ops.open_live_popup("res://scenes/ui/"+scene+".tscn");await frames(15)
		var page: Control=ops._active_live_popup
		check(is_instance_valid(page),"actual event page opens "+scene)
		if scene=="odyssey_screen":
			odyssey.busy=true;odyssey.status="refreshing";odyssey.changed.emit()
			check(not page.roll.disabled and not page.missions_button.disabled,"read-only sync does not flicker normal event actions")
			odyssey.busy=false;odyssey.status="connected"
		else:
			trials.busy=true;trials.status="connected";trials.changed.emit()
			check(not page._entry.disabled,"read-only Trial sync does not flicker entry")
			trials.busy=false
		if scene=="odyssey_screen":odyssey.snapshot.event.enabled=false;odyssey.changed.emit()
		else:trials.snapshot.campaign.enabled=false;trials.changed.emit()
		await frames(12)
		check(not is_instance_valid(ops._active_live_popup),"disabled snapshot closes current event and its actions "+scene)
	check(odyssey.snapshot.state==before_odyssey.state and trials.snapshot.progress==before_trials.progress,"closing hidden event preserves board and earned Trial progress")
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("EVENT_OFF checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
