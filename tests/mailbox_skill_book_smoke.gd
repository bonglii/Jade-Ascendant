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
		check(ops.get_mail_ids().is_empty(), "restart deleted mails stay hidden")
		check(ops.is_mail_claimed("welcome_initiate"), "restart claim retained")
		check(not ops.claim_mail("welcome_initiate"), "restart no replay")
		print("MAIL_RESTART_QA checks=",checks," failures=",failures)
		quit(1 if failures else 0)
		return
	var empty: Array[String] = []
	check(ops._commit_ledger(empty),"mail clean fixture")
	check(ops.get_mail_unread_count() == 2,"initial unread")
	check(not ops.delete_mail("welcome_initiate"),"unclaimed cannot delete")
	check(not ops.delete_mail("invalid"),"invalid delete")
	check(ops.get_mail_claimable_count() == 1,"attachment remains")
	check(change_scene_to_file("res://scenes/ui/mailbox_screen.tscn") == OK,"mail load")
	await process_frame
	await process_frame
	var mail: Control = current_scene
	check(ops.get_mail_unread_count() == 1,"open only selected read")
	check(ops.get_home_mail_badge_count() == 2,"badge counts two distinct actionable letters")
	check(mail._delete_button.disabled,"delete blocked in UI")
	var before: int = int(progression.spirit_stone)
	root.get_node("RewardManager").reward_granted.connect(on_reward)
	check(ops.claim_mail("welcome_initiate"),"claim mail")
	root.get_node("RewardManager").reward_granted.disconnect(on_reward)
	check(progression.spirit_stone == before + 150,"exact mail reward")
	mail._refresh_from_authority()
	check(not mail._delete_button.disabled,"claimed deletable")
	saver.begin_save_write_barrier("batch1_qa","test")
	check(not ops.delete_mail("welcome_initiate"),"readonly delete")
	check(not ops.is_mail_deleted("welcome_initiate"),"readonly tombstone unchanged")
	saver.end_save_write_barrier("batch1_qa")
	mail._on_delete_pressed()
	check(ops.is_mail_deleted("welcome_initiate"),"UI deletion persisted")
	check(ops.get_mail("welcome_initiate").is_empty(),"deleted hidden")
	check(not ops.claim_mail("welcome_initiate"),"deleted cannot reclaim")
	check(ops.get_mail_ids().size() == 1,"deleted removed from list")
	check(ops.get_mail_ids(true).size() == 2,"catalog audit still includes deleted")
	check(mail._selected_id == "celestial_path_notice","selection advances")
	check(ops.delete_mail("celestial_path_notice"),"notice deletable")
	check(ops.get_home_mail_badge_count() == 0,"empty badge")
	check(not ops.delete_mail("celestial_path_notice"),"duplicate delete")
	var read: Dictionary = saver.read_save_data("pavilion")
	pavilion._apply_loaded_state(read.data)
	check(ops.get_mail_ids().is_empty(),"reload tombstones")
	check(ops.MAIL_CLAIM_PREFIX + "welcome_initiate" in ops._get_ledger(),"claim retained")
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
