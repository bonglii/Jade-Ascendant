extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_gacha_qa"): quit(2);return
	await create_timer(.5).timeout
	var manager: Node=root.get_node("PavilionManager")
	var client: Node=manager.banner_client
	var journey: Node=root.get_node("JourneyManager")
	for chapter: int in journey.get_chapter_ids():
		for stage: int in journey.get_stage_ids(chapter): journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
	manager.set_wish_target("nine_heavens_star_sword")
	manager.state.wish_fate_guaranteed=true
	manager.state.pity_legendary=17
	var before: Dictionary=manager.state.duplicate(true)
	var b: Dictionary={"id":"9".repeat(32),"title":"CELESTIAL REBIRTH","subtitle":"Ancient relics return","artwork":"sanctum","featured":["ascendant_heart","cloudtreader_boots"],"rates":{"common":5500,"rare":3000,"epic":1000,"legendary":500},"starts_at":100,"ends_at":1000,"enabled":true}
	var payload: Dictionary={"version":1,"revision":1,"server_time":200,"valid_until":300,"banner":b}
	check(client.accept_snapshot(payload),"known complete banner accepted")
	check(manager.state==before,"configuration does not alter pity, Fate, currency or target")
	check(manager.get_effective_drop_rates_basis_points()==b.rates,"roll uses configured base rates with complete unlocked pool")
	check(manager.get_base_drop_rate_disclosure()[3].basis_points==500,"disclosure matches configured Legendary rate")
	for change: Dictionary in [{"featured":["unknown"]},{"featured":["bamboo_weave_robe"]},{"featured":["ascendant_heart","ascendant_heart"]},{"rates":{"common":5500,"rare":3000,"epic":1000,"legendary":499}},{"rates":{"common":5500,"rare":3000,"epic":999.5,"legendary":500.5}},{"artwork":"https://evil.test"},{"ends_at":199},{"title":""},{"enabled":false}]:
		var bad: Dictionary=payload.duplicate(true)
		bad.banner.merge(change,true)
		check(not client.accept_snapshot(bad),"invalid banner rejected: "+str(change))
		check(client.current()==b,"invalid response retains last valid banner until lease expiry")
	check(not client.accept_snapshot({"version":1,"revision":0,"server_time":200,"valid_until":300,"banner":null}),"older revision cannot replace live configuration")
	check(not client.accept_snapshot({"version":1,"revision":2,"server_time":200,"valid_until":501,"banner":b}),"excessive server lease rejected")
	var scene: PackedScene=load("res://scenes/ui/pavilion_screen.tscn")
	for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
		var viewport:=SubViewport.new();viewport.size=dims;root.add_child(viewport)
		var screen: Control=scene.instantiate();viewport.add_child(screen)
		for n in range(6): await process_frame
		check(screen.featured_items==["ascendant_heart","cloudtreader_boots"],"server equipment order in UI "+str(dims))
		check(screen._banner_title.text==b.title,"server banner title in UI")
		check(screen._banner_notice.visible,"retained target disclosed outside rotating list")
		check(screen.selected_rate_up_item_id=="nine_heavens_star_sword","old target stays selected")
		check(screen.featured_row.get_child_count()==2,"selector supports variable banner size")
		check(screen.content.get_global_rect().end.x<=dims.x+1,"new UI fits mobile width")
		check(screen.summon_one_button.get_theme_stylebox("normal").get_script()!=null,"button consumes generated material")
		check(screen.summon_one_button.get_theme_stylebox("normal").get_minimum_size().x<50,"frame resolution cannot inflate layout")
		screen._start_summon_reveal({"results":[{"item_id":"ascendant_heart","rarity":"legendary"}]})
		var updated: Dictionary=payload.duplicate(true);updated.revision=2;updated.banner.title="NEW ROTATION";updated.banner.featured=["nine_heavens_star_sword"]
		check(client.accept_snapshot(updated),"rotation can arrive during cinematic")
		check(screen._banner_title.text==b.title,"in-flight UI does not switch behind cinematic")
		screen._skip_ritual();screen._finish_summon_reveal()
		check(screen._banner_title.text=="NEW ROTATION","queued banner appears after reveal closes")
		check(screen.featured_row.get_child_count()==1,"selector rebuilt when IDs rotate")
		check(manager.state==before,"UI configuration and cinematic preserve committed economy")
		viewport.queue_free();await process_frame
		payload.revision=2;client.accept_snapshot(payload)
	client._expires_ticks=Time.get_ticks_msec()-1
	client._process(0)
	check(client.current().is_empty(),"expired server lease falls back without relying on phone clock")
	check(manager.get_effective_drop_rates_basis_points()=={"common":6000,"rare":2900,"epic":900,"legendary":200},"expiry uses embedded odds")
	check(manager.state==before,"expiry retains target, Fate and pity")
	check(client.accept_snapshot({"version":1,"revision":3,"server_time":1000,"valid_until":1300,"banner":null}),"disabled or ended banner accepts explicit fallback")
	print("PAVILION_BANNER_QA checks=",checks," failures=",failures)
	await create_timer(.75).timeout
	quit(1 if failures else 0)
