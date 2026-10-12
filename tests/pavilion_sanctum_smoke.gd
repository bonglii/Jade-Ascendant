extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for n in range(5): await process_frame
func snapshot() -> Dictionary:
	return {"pavilion":root.get_node("PavilionManager").state.duplicate(true),"inventory":root.get_node("InventoryManager").item_counts.duplicate(true)}
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_gacha_qa"):
		push_error("Isolated gacha QA user directory required");quit(2);return
	await create_timer(0.5).timeout
	var pavilion: Node = root.get_node("PavilionManager")
	if "--restart" in OS.get_cmdline_user_args():
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://gacha_expect.json"))
		check(pavilion.get_pavilion_seals()==int(expected.seals),"restart retains seals after exactly one summon")
		check(pavilion.get_lifetime_pulls()==int(expected.pulls),"restart retains committed pull count")
		print("GACHA_RESTART checks=",checks," failures=",failures);quit(1 if failures else 0);return
	var journey: Node = root.get_node("JourneyManager")
	for chapter: int in journey.get_chapter_ids():
		for stage: int in journey.get_stage_ids(chapter):
			journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
	pavilion.state.pavilion_seals = 30
	pavilion.state.starter_seals_claimed = true
	var conf := ConfigFile.new();conf.set_value("tutorials","pavilion",true);conf.save("user://jade_onboarding.cfg")
	var scene: PackedScene = load("res://scenes/ui/pavilion_screen.tscn")
	for locale in ["en","id"]:
		TranslationServer.set_locale(locale)
		for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(540,960),Vector2i(648,1152),Vector2i(896,504)]:
			var viewport := SubViewport.new();viewport.size=dims;root.add_child(viewport)
			var screen: Control = scene.instantiate();viewport.add_child(screen);await settle()
			if not screen.has_method("_fit_sanctum"):push_error("Pavilion script failed to load");quit(1);return
			screen._fit_sanctum();await settle()
			if screen.has_node("JadeOnboardingOverlay"):screen.get_node("JadeOnboardingOverlay").visible=false
			var label: String = str(dims)+" "+locale
			check(screen.sanctum_stage.size.x>100,label+" native stage visible")
			check(screen.featured_row.get_child_count()==5,label+" five selectable targets")
			check(screen.summon_one_button.size.x<dims.x and screen.summon_ten_button.size.x<dims.x,label+" CTAs fit width")
			check(screen.content.get_global_rect().end.x<=dims.x+1,label+" content stays inside viewport")
			check(screen.summon_ten_button.get_global_rect().end.x<=dims.x+1,label+" ten CTA inside viewport")
			check(screen.locked_watch_ad_button.text==tr("WATCH AD • FREE 1× SUMMON"),label+" ad CTA explicit")
			for rarity in ["common","rare","epic","legendary"]:
				var committed: Dictionary = {"results":[{"item_id":"nine_heavens_star_sword","rarity":rarity,"duplicate":true,"duplicate_shards":75}]}
				var before: Dictionary = snapshot()
				screen._start_summon_reveal(committed)
				check(screen.summon_reveal_overlay.visible,label+" overlay opens "+rarity)
				screen._reveal_stage.set_process(false)
				screen._reveal_stage.elapsed=screen._reveal_stage.duration*0.99
				screen._reveal_stage._process(0)
				check(screen._reveal_stage.relic==null and screen._result_name.text.is_empty(),label+" identity hidden even at ninety-nine percent "+rarity)
				check(screen._phase_copy.text.begins_with(tr(rarity.capitalize()).to_upper()),label+" actual rarity hint "+rarity)
				screen._show_history_overlay()
				check(screen.locked_history_overlay==null,label+" history blocked while cinematic open")
				screen._reveal_stage.set_process(true)
				screen._skip_ritual();await settle()
				check(not screen.summon_reveal_busy,label+" skip releases lock "+rarity)
				check(screen._stars_copy.text=="★☆☆☆☆",label+" actual ascension stars, not rarity "+rarity)
				check(screen._result_state.text.contains("75"),label+" actual duplicate amount "+rarity)
				check(screen.summon_reveal_action.get_global_rect().end.y<=screen.summon_reveal_overlay.get_global_rect().end.y+1,label+" continue fits "+rarity)
				check(screen.summon_reveal_action.get_global_rect().end.y<=dims.y+1,label+" continue inside physical viewport "+rarity)
				screen._advance_summon_reveal()
				check(not screen.summon_reveal_overlay.visible,label+" continue returns "+rarity)
				check(snapshot()==before,label+" presentation cannot change rewards "+rarity)
			var batch: Array = []
			for index in range(10):batch.append({"item_id":"nine_heavens_star_sword","rarity":"legendary","duplicate":true,"duplicate_shards":75})
			var before: Dictionary = snapshot()
			screen._start_summon_reveal({"results":batch});screen._reveal_stage.skip();await settle()
			check(screen._formation.get_child_count()==10,label+" ten formation seals")
			screen._open_formation_seal(0);screen._open_formation_seal(0)
			check(screen._formation_opened.size()==0,label+" result stays sealed during cinematic")
			check(screen._reveal_stage.relic==null,label+" no rendered equipment while charging")
			check((screen._formation.get_child(0).get_node("RelicContent/Icon") as TextureRect).texture==screen.CELESTIAL_SEAL,label+" formation icon remains a seal")
			check(screen._formation.get_child(0).tooltip_text.is_empty(),label+" tooltip cannot leak result")
			check(screen._formation.columns==2,label+" balanced two-column formation")
			check(screen._formation_detail,label+" legendary has focused cinematic")
			screen._skip_ritual()
			check(screen._formation_opened.size()==1,label+" only completed reveal opens seal")
			screen._advance_summon_reveal();await settle()
			check(not screen._formation_detail and screen._formation_scroll.visible,label+" return preserves formation")
			screen._skip_ritual();await settle()
			check(screen._formation_opened.size()==10,label+" reveal all opens ten")
			check(screen._formation.size.x<=screen._formation_scroll.size.x+1,label+" formation fits width")
			check(screen.summon_reveal_action.get_global_rect().end.y<=screen.summon_reveal_overlay.get_global_rect().end.y+1,label+" batch continue pinned")
			for rarity in ["common","rare","epic","legendary"]:
				screen.summon_reveal_entries[0].rarity=rarity
				screen._open_formation_seal(0)
				check(screen._reveal_stage.relic==null and screen._result_name.text.is_empty(),label+" all rarity identities hidden "+rarity)
				screen._skip_ritual();screen._advance_summon_reveal()
			screen._advance_summon_reveal()
			check(snapshot()==before,label+" reveal all cannot regrant")
			screen._start_summon_reveal({"results":batch});screen._back();await settle()
			check(not screen._reveal_stage.playing and not screen.summon_reveal_overlay.visible,label+" back cancels cinematic")
			root.get_node("SettingsManager").reduced_effects=true
			screen._start_summon_reveal({"results":batch});await settle()
			check(not screen.summon_reveal_busy and screen._formation_scroll.visible,label+" reduced effects lands immediately")
			screen._finish_summon_reveal();root.get_node("SettingsManager").reduced_effects=false
			screen.queue_free();viewport.queue_free();await settle()
	var viewport := SubViewport.new();viewport.size=Vector2i(648,1152);root.add_child(viewport)
	var screen: Control = scene.instantiate();viewport.add_child(screen);await settle()
	var seals: int = pavilion.get_pavilion_seals()
	var pulls: int = pavilion.get_lifetime_pulls()
	screen._summon(10);await settle()
	check(screen.summon_reveal_overlay.visible,"real ten pull opens presentation after commit")
	check(pavilion.get_pavilion_seals()==seals-10,"real ten pull consumes exactly ten seals")
	check(pavilion.get_lifetime_pulls()==pulls+10,"real ten pull commits exactly ten results")
	var saved: Dictionary = snapshot()
	screen._summon(10)
	check(snapshot()==saved,"double tap during ritual cannot spend again")
	screen._skip_ritual();screen._advance_summon_reveal();await settle()
	check(snapshot()==saved,"real skip does not mutate committed reward")
	root.get_node("SettingsManager").reduced_effects=false
	for rarity in ["common","rare","epic","legendary"]:
		screen._start_summon_reveal({"results":[{"item_id":"nine_heavens_star_sword","rarity":rarity}]})
		await create_timer(screen._reveal_stage.duration+0.3).timeout
		check(not screen.summon_reveal_busy,"natural ritual finishes "+rarity)
		screen._finish_summon_reveal()
	var equipment: Node = root.get_node("EquipmentManager")
	equipment.ascension_stars["nine_heavens_star_sword"]=5
	screen._start_summon_reveal({"results":[{"item_id":"nine_heavens_star_sword","rarity":"rare"}]})
	check(screen._reveal_stage.rarity=="rare" and screen._reveal_stage.presentation_star==5,"five-star Rare keeps blue rarity signal")
	screen._skip_ritual()
	check(screen._stars_copy.text=="★★★★★" and screen._phase_copy.text==tr("Rare").to_upper(),"five stars do not rewrite actual rarity")
	screen._finish_summon_reveal()
	equipment.ascension_stars.erase("nine_heavens_star_sword")
	var file := FileAccess.open("user://gacha_expect.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"seals":pavilion.get_pavilion_seals(),"pulls":pavilion.get_lifetime_pulls()}));file.close()
	screen.queue_free();viewport.queue_free();await settle()
	await create_timer(0.75).timeout
	print("GACHA_NATIVE_QA checks=",checks," failures=",failures)
	quit(1 if failures else 0)
