extends SceneTree
const Catalog = preload("res://scripts/data/skill_catalog.gd")
var LevelUp: Variant
var checks: int = 0
var failures: int = 0
var ops: Node
var saver: Variant
var pavilion: Variant
var progression: Variant
func check(ok: bool, tag: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(tag)
func _initialize() -> void:
	run.call_deferred()
func on_reward(_source: String, _id: String, _reward: Dictionary) -> void:
	check(not ops.claim_mail("welcome_initiate"),"mail reentrant claim")
	check(not ops.delete_mail("celestial_path_notice"),"mail reentrant delete")
	check(not ops.mark_all_mail_read(),"mail reentrant read write")
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("jade_batch1_qa"):
		push_error("Batch 1 QA requires isolated user:// before startup")
		quit(2)
		return
	await create_timer(0.5).timeout
	LevelUp = load("res://scripts/ui/level_up.gd")
	ops = root.get_node("LiveOpsManager")
	ops.set_process(false)
	saver = root.get_node("SaveManager")
	pavilion = root.get_node("PavilionManager")
	progression = root.get_node("ProgressionManager")
	if "--verify-mail-restart" in OS.get_cmdline_user_args():
		check(ops.get_mail_ids().is_empty(),"restart does not synthesize retired mail")
		check(ops.MAIL_CLAIM_PREFIX+"welcome_initiate" in ops._get_ledger(),"historical grant marker retained")
		check(not ops.claim_mail("welcome_initiate"),"retired mail cannot replay")
		print("MAIL_RESTART_QA checks=",checks," failures=",failures);quit(1 if failures else 0);return
	var before: int=progression.spirit_stone
	var ledger: Array[String]=ops._get_ledger().duplicate()
	ledger.append(ops.MAIL_CLAIM_PREFIX+"welcome_initiate")
	check(ops._commit_ledger(ledger),"historical mail grant fixture saved")
	check(ops.get_mail_ids().is_empty() and ops.get_mail_unread_count()==0,"no automatic local messages")
	check(ops.get_mail_claimable_count()==0,"no automatic update reward")
	check(not ops.claim_mail("welcome_initiate") and progression.spirit_stone==before,"retired grant rejected without changing balance")
	check(change_scene_to_file("res://scenes/ui/mailbox_screen.tscn")==OK,"mail load")
	await process_frame;await process_frame
	check(ops.get_mail_ids().is_empty(),"opening mailbox does not create welcome letters")
	check(ops.MAIL_CLAIM_PREFIX+"welcome_initiate" in ops._get_ledger(),"mail retirement preserves historical marker")
	check(not saver.has_pending_transaction(),"mail journal clear")
	var level: Variant = LevelUp.new()
	check(Catalog.UPGRADE_IDS.size() == 18,"all skills")
	for id: String in Catalog.UPGRADE_IDS:
		check(level.get_upgrade_display_name(id) == Catalog.get_upgrade_display_name(id),"name parity")
		check(level.get_upgrade_description(id) == Catalog.get_upgrade_description(id),"description parity")
		check(ResourceLoader.exists(Catalog.ICON_PATHS[id]),"icon exists")
	check(Catalog.get_requirements("sword_dao_resonance") == {"spirit_sword":LevelUp.SWORD_DAO_RESONANCE_REQUIRED_SPIRIT_SWORD_LEVEL,"sword_intent":LevelUp.SWORD_DAO_RESONANCE_REQUIRED_SWORD_INTENT_LEVEL},"sword requirements")
	check(Catalog.get_requirements("yin_yang_reversal") == {"yin_yang_blades":LevelUp.YIN_YANG_REVERSAL_REQUIRED_BLADES_LEVEL,"qi_shield":LevelUp.YIN_YANG_REVERSAL_REQUIRED_QI_SHIELD_LEVEL},"yin yang requirements")
	check(Catalog.get_requirements("heavenly_tribulation") == {"heavenly_sword_rain":LevelUp.HEAVENLY_TRIBULATION_REQUIRED_SWORD_RAIN_LEVEL,"thunder_talisman":LevelUp.HEAVENLY_TRIBULATION_REQUIRED_THUNDER_LEVEL},"tribulation requirements")
	level.free()
	check(change_scene_to_file("res://scenes/ui/skill_book_screen.tscn") == OK,"skill book load")
	await process_frame
	await process_frame
	var book: Control = current_scene
	book._set_mode("SKILLS")
	check(book._list.get_child_count() == 18,"book all skills")
	for category: String in ["WEAPONS","PASSIVES","SYNERGIES"]:
		book._set_filter(category)
		check(book._list.get_child_count() == (6 if category == "WEAPONS" else 3 if category == "SYNERGIES" else 9),"filter coverage")
		for width: int in [648,720,1080]:
			root.size = Vector2i(width,width*2)
			await process_frame
			await process_frame
			for card: Control in book._list.get_children():
				check(card.size.x <= book.size.x,"card width fits")
	book._set_filter("ALL")
	book._search.text = "tribulation"
	book._refresh()
	check(book._list.get_child_count() == 1,"search match")
	book._search.text = "no_such_skill"
	book._refresh()
	check(book._list.get_child_count() == 1 and book._list.get_child(0) is Label,"empty search state")
	book._search.text = ""
	book._refresh()
	check(book._list.get_child_count() == 18,"clear search")
	check(change_scene_to_file("res://scenes/ui/main_menu.tscn") == OK, "home navigation load")
	await create_timer(0.5).timeout
	var home_safe: Control = current_scene.get_node("HomeUI")
	home_safe._finish_onboarding()
	var book_button: Button = current_scene.find_child("HomeSkillBookButton",true,false)
	check(book_button != null, "home skill book entry")
	book_button.pressed.emit()
	await create_timer(2.0).timeout
	check(current_scene.scene_file_path == "res://scenes/ui/skill_book_screen.tscn", "home button opens skill book")
	current_scene._back()
	await create_timer(2.0).timeout
	check(current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn", "skill book returns home")
	await create_timer(3).timeout
	current_scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	print("BATCH1_QA checks=",checks," failures=",failures)
	quit(1 if failures else 0)
