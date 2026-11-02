extends SceneTree
var checks: int = 0
var failures: int = 0
var evidence: Array = []
var accidental_actions: int = 0
func check(ok: bool, caption: String) -> void:
	checks += 1
	evidence.append({"check":caption,"pass":ok})
	if not ok: failures += 1;push_error("PLAYER_8_10 "+caption)
func frames(count: int = 5) -> void:
	for index: int in range(count):await process_frame
func mouse(at: Vector2, down: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down;event.position=at;root.push_input(event,true)
func swipe(at: Vector2, delta: Vector2) -> void:
	mouse(at,true);await frames(1)
	for index: int in range(1,9):
		var event:=InputEventMouseMotion.new();event.position=at+delta*float(index)/8;event.relative=delta/8;event.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(event,true);await frames(1)
	mouse(at+delta,false);await frames(2)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_player_810_qa"):quit(2);return
	create_timer(150).timeout.connect(func():push_error("PLAYER_8_10_TIMEOUT");quit(1))
	await frames()
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(320,568)
	var journey: Node=root.get_node("JourneyManager")
	root.get_node("ProgressionManager").spirit_stone=0
	var settings: Node=root.get_node("SettingsManager")
	var saver: Node=root.get_node("SaveManager")
	var State=load("res://scripts/data/jade_oath_state.gd")
	var Catalog=load("res://scripts/data/chronicle_catalog.gd")
	var Snapshot=load("res://scripts/data/run_share_snapshot.gd")
	var Pattern=load("res://scripts/game/heavenly_trial_rule_v2.gd")
	var Rules=load("res://scripts/data/trial_ruleset_policy.gd")
	var old_week: Dictionary={"id":"ht_old_0","stage":1,"theme":"jade_wind"}
	var new_week: Dictionary={"id":"ht_new_0","stage":2,"theme":"scarlet_rite","ruleset_version":2}
	check(Rules.version(old_week)==1 and Rules.version(new_week)==2,"legacy week defaults to v1 while explicit v2 is supported")
	check(Rules.session_config({"week":"ht_old_0","week_config":old_week},{"week":new_week})==old_week,"old session never borrows new rotation rules")
	check(Rules.session_config({"week":"ht_old_0"},{"week":new_week,"previous":old_week})==old_week,"legacy session fallback requires its own matching week")
	check(Rules.session_config({"week":"ht_old_0"},{"week":new_week}).is_empty(),"missing old-week metadata fails safely instead of changing rules")
	check(Rules.version({"ruleset_version":3})==0 and Rules.version({"ruleset_version":"2"})==0,"unknown or malformed rulesets cannot silently play v1")

	for path: String in ["ui/stage_select.gd","ui/skill_book_screen.gd","ui/run_share_panel.gd","ui/run_share_controller.gd","ui/run_card_renderer.gd","ui/chronicle_reader.gd","ui/result_ceremony.gd","game/VictoryManager.gd","game/heavenly_trial_arena.gd","game/heavenly_trial_checkpoint.gd"]:
		check(load("res://scripts/"+path)!=null,"load changed production script "+path)
	var oath=State.new()
	oath.begin(true)
	check(not oath.offer(Vector2.ZERO,6,40),"wave six cannot begin a late ritual")
	check(not oath.offer(Vector2.ZERO,5,21.99),"full 22 seconds must be available")
	check(oath.offer(Vector2(148,0),5,22),"safe wave five opens the altar")
	oath.advance(3,true,5);oath.advance(4,false,5)
	check(is_equal_approx(oath.charge,3) and is_equal_approx(oath.remaining,15),"outside pauses charge while timer keeps going")
	var saved: Dictionary=oath.snapshot();var resumed=State.new();resumed.restore(saved)
	check(resumed.snapshot()==saved,"Continue preserves timer, charge and exact altar location")
	resumed.advance(5,true,6)
	check(resumed.phase=="pending","eight cumulative seconds becomes pending, never grants rewards")
	var pending=State.new();pending.restore(resumed.snapshot());check(pending.phase=="pending","completed altar cannot respawn on Continue")
	for bad: Variant in [{},{"version":2},null,{"version":1,"phase":"charging","remaining":NAN,"charge":0,"x":0,"y":0},{"version":1,"phase":"pending","remaining":9,"charge":1,"x":0,"y":0}]:
		var clean=State.new();clean.begin(true);clean.restore(bad);check(clean.phase=="off","malformed optional metadata safely disables only the ritual")
	var timed=State.new();timed.begin(true);timed.offer(Vector2.ZERO,5,40);timed.advance(22,false,6);check(timed.phase=="failed","altar expiry does not create a success")
	var omitted=State.new();omitted.begin(true);omitted.advance(1,false,6);check(omitted.phase=="omitted","missed safe offer never delays ordinary waves")
	check(Catalog.ENTRIES.size()==11,"all eleven approved bilingual stories ship")
	for entry: Dictionary in Catalog.ENTRIES:
		for language: String in ["en","id"]:
			for field: String in ["title","body","line"]:check(not Catalog.copy(entry,field,language).is_empty(),"story copy "+str(entry.id)+" "+language+" "+field)
		check(Catalog.unlocked(entry,[],[])==(entry.id=="verdant_arrival"),"fresh account story gate "+str(entry.id))
		if entry.id!="verdant_oath_fragment" and entry.get("requires")!=null:check(Catalog.unlocked(entry,[entry.requires],[]),"existing clears unlock story without replay or rewards")
	check(Catalog.unlocked(Catalog.get_entry("verdant_oath_fragment"),[],["keeper_of_the_oath"]),"optional fragment derives from the committed cosmetic badge")
	var report: Dictionary={"time_ms":132300,"hits":2,"deaths":0,"complete":true,"damage_complete":true,"skills":[{"id":"spirit_sword","level":7,"armament_id":""},{"id":"attack_speed","level":1}],"damage":{"spirit_sword":4395}}
	var card: Dictionary=Snapshot.journey(1,3,"Ruined Jade Shrine",report)
	report.time_ms=999999;report.skills[0].level=1
	check(card.time_ms==132300 and card.skills[0].level==7,"share snapshot is independent of later run/current build mutation")
	check(not card.has("best_ms") and not card.has("uid") and not card.has("session_id"),"DTO contains no personal/best-run authority")
	check(Snapshot.alias_text("  Lin<Yue>@mail  ")=="LinYuemail","alias is optional, bounded and explicit")
	check(Snapshot.alias_text("a".repeat(80)).length()==24,"alias length is bounded")
	check(Snapshot.trials({"won":true,"tier":1,"time_ms":30000,"hits":0,"deaths":0}).is_empty(),"Trials cannot share an uncommitted result")
	var basic: Dictionary=Snapshot.trials({"won":true,"committed":true,"tier":1,"time_ms":30000,"hits":0,"deaths":0})
	check(not basic.complete and basic.skills.is_empty() and basic.mode=="trials","legacy Trials fallback never borrows Journey build or invents no-hit data")
	var actor:=Node2D.new();actor.name="PatternPlayer";actor.add_to_group("player");root.add_child(actor)
	var health: Node=load("res://tests/player_8_10_health.gd").new();health.name="PlayerHealth";actor.add_child(health)
	for theme: String in Pattern.WARNINGS:
		var pattern=Pattern.new();pattern.theme_id=theme;pattern.tier=2;root.add_child(pattern);pattern.set_process(false)
		check(pattern.marks().size()==({"starfall":3,"froststep":2}.get(theme,1)),"bounded marker count "+theme)
		if theme=="sunforge":check(not pattern.inside(Vector2(90,0)) and pattern.inside(Vector2(-90,0)) and not pattern.inside(Vector2.ZERO),"Sunforge safe gap and center match damage geometry")
		if theme=="sunforge":
			var initial: Vector2=pattern.ring_band(1.65)
			var moving: Vector2=pattern.ring_band(1.9)
			check(initial.x==56 and initial.y==56 and moving.x>=56 and moving.y<=100,"Sunforge visual/damage band preserves its safe center throughout the sweep")
		if theme=="froststep":check(not pattern.inside(Vector2.ZERO,0) and not pattern.inside(Vector2.ZERO,1),"Froststep preserves the safe corridor")
		if theme=="starfall":
			actor.position=Vector2.ZERO;pattern._process(1.26);actor.position=pattern.marks()[1];pattern._process(.5);actor.position=pattern.marks()[2];pattern._process(.5)
			check(health.applications==1 and health.damage==7,"Starfall applies at most one unchanged tier hit per pattern")
		check(Pattern.valid_snapshot(pattern.snapshot()),"v2 pattern checkpoint is bounded "+theme)
		pattern.queue_free();await frames(1)
	actor.queue_free();await frames()
	var renderer=load("res://scripts/ui/run_card_renderer.gd").new()
	for story: bool in [false,true]:
		var image: Image=renderer.render(card,story,"","id")
		check(image!=null and image.get_size()==Vector2i(1080,1920 if story else 1350),"real CPU PNG format "+str(story))
		check(image.save_png("user://card-"+("story" if story else "feed")+".png")==OK,"real PNG writes successfully")
	journey.cleared_stage_keys=["1-1","1-2","1-3","1-4","1-5"]
	journey.cosmetic_badges=["keeper_of_the_oath"]
	check(journey.build_save_data().cosmetic_badges==["keeper_of_the_oath"],"cosmetic badge is serialized in Journey domain")
	var host:=Control.new();host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(host)
	for language: String in ["id","en"]:
		settings.language=language
		for dimensions: Vector2i in [Vector2i(320,568),Vector2i(360,800)]:
			root.size=dimensions;await frames()
			var reader: Control=load("res://scripts/ui/chronicle_reader.gd").open(host,"verdant_oath_fragment");await frames()
			check(reader!=null and reader._panel.size.x<=dimensions.x-20 and reader._panel.size.y<=dimensions.y-30,"Chronicle sheet fits "+language+" "+str(dimensions))
			var scroll: ScrollContainer=reader.find_child("PlayerSheetScroll",true,false)
			check(scroll!=null and scroll.vertical_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED,"reader preserves native vertical scrolling")
			reader.queue_free();await frames()
			var share: Control=load("res://scripts/ui/run_share_panel.gd").open(host,card);await frames()
			check(share!=null and not share.find_child("RunCardShowAlias",true,false).button_pressed,"share starts private by default "+language)
			check(share._panel.size.x<=dimensions.x-20,"share fits narrow phone "+str(dimensions))
			share.queue_free();await frames()
	host.queue_free();await frames()
	# Integration follows the same Home-before-run order used by the tested parent.
	change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(20)
	current_scene.queue_free();current_scene=null;await frames()
	journey.unlocked_stage_keys=["1-1","1-2","1-3","1-4","1-5"]
	journey.select_stage(1,3)
	saver.delete_active_run_save("checkpoint")
	var launch: String=journey.begin_selected_stage()
	root.get_node("GameSession").start_new_game()
	root.get_node("GameSession").jade_oath_requested=true
	change_scene_to_file(launch);await frames(15)
	var arena: Node=current_scene
	check(arena.get_node_or_null("JadeOath")!=null,"actual replay 1-3 installs one optional objective")
	var runtime: Node=arena.get_node("JadeOath")
	check(runtime.state.phase=="waiting","new replay consumes its frozen opt-in")
	var waves: Node=arena.get_node("WaveManager")
	waves.current_wave=5;waves.wave_timer=19
	var spawner: Node=arena.get_node("EnemySpawner")
	spawner.set_process(false)
	for enemy: Node in get_nodes_in_group("enemy"):enemy.queue_free()
	await frames()
	runtime._probe_left=0;runtime._process(.01)
	check(runtime.state.phase=="charging","production wave-five timing and actual safe placement can open the altar")
	if runtime.state.phase!="charging":runtime.state.offer(arena.get_node("player_1").global_position+Vector2(148,0),5,39)
	runtime.set_process(false)
	runtime.state.advance(3,true,5)
	var checkpoint: Node=arena.get_node("CheckPointManager")
	check(checkpoint.save_checkpoint(),"optional ritual coexists with the real paid/save checkpoint path")
	var before: Dictionary=runtime.state.snapshot()
	runtime.state.advance(2,false,5)
	check(checkpoint.load_checkpoint(),"real Continue accepts checkpoint with optional metadata")
	check(runtime.state.snapshot()==before,"real Continue restores exact ritual state without a second altar")
	check(arena.find_children("JadeOath","",false,false).size()==1,"Continue never duplicates objective nodes")
	var snapshot_result: Dictionary=saver.read_save_data("checkpoint")
	var malformed: Dictionary=snapshot_result.data.duplicate(true)
	malformed["jade_oath"]={"version":1,"phase":"charging","remaining":"broken"}
	check(saver.write_save_data("checkpoint",malformed).success,"optional metadata corruption fixture is isolated")
	check(checkpoint.load_checkpoint() and runtime.state.phase=="off","malformed ritual data keeps the main Continue usable without a new offer")
	runtime.restore(before)

	paused=true
	var paused_remaining: float=runtime.state.remaining
	await frames(5)
	check(is_equal_approx(runtime.state.remaining,paused_remaining),"game pause stops ritual timer")
	paused=false
	# The cosmetic is written by the same transaction as a real stage clear reward.
	runtime.state.charge=8;runtime.state.phase="pending"
	journey.cosmetic_badges=[]
	var victory: Node=arena.get_node("VictoryManager")
	var result: Dictionary={"completed":true,"chapter_id":1,"stage_id":3,"was_first_clear":false}
	check(saver.write_save_data("journey",journey.build_save_data()).success,"pre-failure cosmetic state is saved in isolated fixture")
	check(saver.begin_save_write_barrier("player810failure","QA transaction rejection").success,"failure fixture uses the real progress barrier")
	print("EXPECTED_ATOMIC_FAILURE_BEGIN")
	var refused: bool=bool(victory.grant_victory_reward(result))
	print("EXPECTED_ATOMIC_FAILURE_END")
	check(not refused and not "keeper_of_the_oath" in journey.cosmetic_badges,"failed Victory transaction leaves cosmetic locked in memory")
	check(not "keeper_of_the_oath" in saver.read_save_data("journey").get("data",{}).get("cosmetic_badges",[]),"failed Victory transaction leaves cosmetic locked on disk")
	check(saver.end_save_write_barrier("player810failure").success,"failure fixture releases its owned save barrier")
	var granted: bool=bool(victory.grant_victory_reward(result))
	check(granted,"real repeat-clear transaction commits with the optional cosmetic")
	check("keeper_of_the_oath" in journey.cosmetic_badges,"badge enters live state only after successful Victory transaction")
	var disk: Dictionary=saver.read_save_data("journey")
	check("keeper_of_the_oath" in disk.get("data",{}).get("cosmetic_badges",[]),"committed Journey domain contains the badge")
	var stones: int=int(root.get_node("ProgressionManager").spirit_stone)
	var expected: int=int(root.get_node("RewardManager").get_stage_clear_reward(1,3,false).get("spirit_stone",0))
	check(stones==expected,"ritual adds no currency to normal repeat-clear reward")
	current_scene.queue_free();current_scene=null;await frames(10)


	# Test only the newly affected archive/map surfaces in both shipped languages.
	for language: String in ["id","en"]:
		settings.language=language
		root.size=Vector2i(320,568)
		change_scene_to_file("res://scenes/ui/skill_book_screen.tscn");await frames(12)
		var book: Control=current_scene
		book._set_mode("CHRONICLES");await frames()
		check(book._tabs.size()==4,"Library keeps equipment, skills and builds alongside Chronicles")
		check(book._tabs.CHRONICLES.get_parent() is GridContainer and book._tabs.CHRONICLES.get_parent().columns==2,"four archive tabs fit a narrow phone")
		check(book._list.get_child_count()==11,"Chronicle tab renders all entries including locked story gates")
		check(book._list.get_parent().size.y>60,"Chronicles retain usable native scroll space")
		var archive_scroll: ScrollContainer=book._list.get_parent()
		archive_scroll.scroll_vertical=0;await frames()
		var first: Button=book.find_child("Chronicle_verdant_arrival",true,false)
		first.pressed.connect(func():accidental_actions+=1)
		await swipe(first.get_global_rect().get_center(),Vector2(0,-70))
		check(archive_scroll.scroll_vertical>20,"Chronicles first swipe begins on a real story button")
		check(accidental_actions==0 and book.get_node_or_null("ChronicleReader")==null,"story drag does not open an accidental reader")

		current_scene.queue_free();current_scene=null;await frames()
		journey.select_stage(1,3)
		change_scene_to_file("res://scenes/ui/stage_select.tscn");await frames(12)
		var map: Control=current_scene
		check(map._oath_toggle.visible and map._oath_hint.visible,"cleared replay 1-3 shows the explicit optional toggle")
		check(map.start_button.get_global_rect().end.y<=root.size.y+1,"new ritual/story rows leave Start reachable on a narrow phone")
		var detail: ScrollContainer=map.find_child("StageDetailScroll",true,false)
		var maximum: int=int(detail.get_v_scroll_bar().max_value-detail.get_v_scroll_bar().page)
		detail.scroll_vertical=clampi(roundi(map._oath_toggle.position.y-30),0,maximum);await frames()
		var old_scroll: int=detail.scroll_vertical
		await swipe(map._oath_toggle.get_global_rect().get_center(),Vector2(0,-50))
		check(not map._oath_toggle.button_pressed,"dragging the objective toggle does not opt into a run")
		check(detail.scroll_vertical!=old_scroll or old_scroll==maximum,"objective detail preserves native drag scrolling")

		map._oath_toggle.button_pressed=true
		journey.select_stage(1,2);map._refresh_selected_stage_panel();await frames()
		check(not map._oath_toggle.visible and not map._oath_toggle.button_pressed,"other stages cannot inherit the ritual opt-in")
		current_scene.queue_free();current_scene=null;await frames()
	FileAccess.open("user://player-8-10-evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"\t"))
	print("PLAYER_8_10_ARTIFACTS="+OS.get_user_data_dir())
	print("PLAYER_8_10 checks=%d failures=%d"%[checks,failures])
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	quit(1 if failures else 0)
