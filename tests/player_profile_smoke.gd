extends SceneTree

var checks: int = 0
var failures: int = 0
var identity: Node
var saves: Node
const MARKER: String = "user://profile_qa_marker.cfg"

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PROFILE_QA_FAIL " + label)

func disk_hashes() -> Dictionary:
	var result: Dictionary = {}
	for id: String in saves.get_save_domain_ids_for_scope("permanent"):
		var path: String = saves.get_save_path(id)
		result[id] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result

func put_profile(data: Dictionary) -> void:
	var file := FileAccess.open(saves.get_save_path("player_profile"),FileAccess.WRITE)
	file.store_var(data)
	file.close()

func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("jade_profile_qa"):
		push_error("Use an isolated jade_profile_qa XDG_DATA_HOME before startup")
		quit(2)
		return
	await create_timer(0.5).timeout
	identity = root.get_node("PlayerIdentityManager")
	saves = root.get_node("SaveManager")
	var snapshot: Dictionary = identity.get_profile_snapshot()
	check(bool(snapshot.ready),"profile persisted before UID exposed")
	var uid: String = str(snapshot.player_uid)
	check(uid.length() == 18,"alphanumeric local device ID")
	check(not bool(snapshot.server_registered),"local UID never claims server registration")
	check(bool(saves.audit_save_architecture().valid),"save registry valid")
	check(saves.get_save_domain_ids_for_scope("permanent").size() == 8,"locked eight-domain cloud contract preserved")
	check(saves.get_save_scope("player_profile") == "local_profile","isolated local profile scope")
	if "--seed-legacy" in OS.get_cmdline_user_args():
		var file := FileAccess.open(saves.get_save_path("progression"),FileAccess.WRITE)
		file.store_var({"spirit_stone":123456,"vitality_level":4,"sword_power_level":3,"swift_qi_level":2})
		file.close()
		check(bool(saves.write_save_data("inventory",{"version":1,"item_counts":{"refinement_shard":17}}).success),"seed existing inventory")
		for suffix: String in ["",".backup",".tmp",".rollback"]:
			var path: String = saves.get_save_path("player_profile")+suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		finish()
		return
	if "--legacy" in OS.get_cmdline_user_args():
		var progression: Node = root.get_node("ProgressionManager")
		check(progression.spirit_stone == 123456,"legacy currency preserved on first UID creation")
		check(progression.vitality_level == 4 and progression.sword_power_level == 3 and progression.swift_qi_level == 2,"legacy upgrades preserved")
		check(root.get_node("InventoryManager").get_item_count("refinement_shard") == 17,"existing inventory preserved")
		check(FileAccess.file_exists(saves.get_save_path("player_profile")),"new profile added alongside legacy saves")
		finish()
		return
	if "--restart" in OS.get_cmdline_user_args():
		var marker := ConfigFile.new()
		check(marker.load(MARKER) == OK,"restart marker")
		check(uid == str(marker.get_value("qa","uid","")),"UID survives actual process restart")
		check(str(snapshot.display_name) == str(marker.get_value("qa","name","")),"name survives actual process restart")
		finish()
		return
	var initial_hashes: Dictionary = disk_hashes()
	check(identity._compact_uid("JA-00010203-04050607-08090A0B-0C0D0E0F") == "JA-000G-40R4-0M30-E209","independent base32 encoding vector")
	check(identity._compact_uid("bad").is_empty(),"invalid legacy UID cannot become short UID")
	var current_payload: Dictionary = saves.read_save_data("player_profile").data.duplicate(true)
	var legacy: Dictionary = {"version":1,"player_uid":current_payload.legacy_player_uid,"display_name":current_payload.display_name}
	put_profile(legacy)
	check(bool(saves.begin_save_write_barrier("profile_migration_qa","maintenance").success),"block migration write")
	identity.refresh_profile()
	check(str(identity.get_profile_snapshot().player_uid) == str(legacy.player_uid).replace("-",""),"failed migration exposes only persisted old UID")
	check(saves.read_save_data("player_profile").data == legacy,"failed migration preserves old save")
	saves.end_save_write_barrier("profile_migration_qa")
	identity.refresh_profile()
	check(str(identity.get_profile_snapshot().player_uid) == uid,"migration deterministically shortens existing identity")
	var migrated: Dictionary = saves.read_save_data("player_profile").data
	check(str(migrated.legacy_player_uid) == str(legacy.player_uid),"migration retains original UID reference")
	check(str(migrated.display_name) == str(legacy.display_name),"migration preserves name")
	var migration_hash: String = FileAccess.get_sha256(saves.get_save_path("player_profile"))
	identity.refresh_profile()
	check(FileAccess.get_sha256(saves.get_save_path("player_profile")) == migration_hash,"migration is idempotent")
	var mismatched: Dictionary = migrated.duplicate(true)
	mismatched.player_uid = "JA-0000-0000-0000-0000"
	check(not identity._valid_payload(mismatched),"alias/reference mismatch rejected")
	var names: Array[String] = ["Kim", "  Kim   Jade  ", "李明天", "Éléonore", "D'Artagnan", "Jade_Ascendant", "名".repeat(20), "A".repeat(20), "Player 123", "Kim-Jade"]
	for name: String in names:
		check(bool(identity.validate_name(name).valid),"valid international name " + name)
		check(bool(identity.rename_player(name).success),"save valid name")
		check(str(identity.get_profile_snapshot().player_uid) == uid,"rename keeps UID")
	var invalid: Array[String] = ["", "  ", "ab", "A".repeat(21), "-Kim", "[color=red]Kim", "<Kim>", "Kim\nJade", "Kim\tJade", "Kim/../", "😀😀😀", "Kim\u200b", "Kim\u202e", "Kim\u2066", "Kim\u007f", "Kim\\Jade"]
	for name: String in invalid:
		var before: Dictionary = identity.get_profile_snapshot()
		check(not bool(identity.validate_name(name).valid),"reject invalid name")
		check(not bool(identity.rename_player(name).success),"invalid rename rejected")
		check(identity.get_profile_snapshot() == before,"invalid rename leaves state intact")
	check(str(identity.validate_name("  Kim   Jade  ").name) == "Kim Jade","normalize ordinary spaces")
	var generated: Dictionary = {}
	for i: int in range(200):
		var candidate: Dictionary = identity._new_identity()
		check(identity._valid_payload(candidate),"generated identity validates")
		check(not generated.has(candidate.player_uid),"random UID independent")
		generated[candidate.player_uid] = true
	var before_barrier: Dictionary = identity.get_profile_snapshot()
	check(bool(saves.begin_save_write_barrier("profile_qa","maintenance").success),"maintenance barrier acquired")
	check(not bool(identity.rename_player("Blocked Jade").success),"blocked save rejects rename")
	check(identity.get_profile_snapshot() == before_barrier,"failed write never changes live name")
	check(bool(saves.end_save_write_barrier("profile_qa").success),"maintenance barrier released")
	var recursive: Array[Dictionary] = []
	var handler: Callable = func(_snapshot: Dictionary):
		recursive.append(identity.rename_player("Recursive Jade"))
		identity.refresh_profile()
	identity.profile_changed.connect(handler)
	check(bool(identity.rename_player("Kim Jade").success),"outer rename succeeds")
	identity.profile_changed.disconnect(handler)
	check(recursive.size() == 1 and not bool(recursive[0].success),"reentrant callbacks cannot mutate or reload")
	check(str(identity.get_profile_snapshot().display_name) == "Kim Jade","reentrancy preserves committed name")
	root.get_node("GoogleAccountManager").account_state_changed.emit({"signed_in": false})
	check(str(identity.get_profile_snapshot().player_uid) == uid,"account UI event never changes public UID")
	check(bool(saves.reset_active_run_saves().success),"new-run reset allowed")
	check(str(identity.get_profile_snapshot().player_uid) == uid,"new run keeps public UID")
	identity.refresh_profile()
	check(str(identity.get_profile_snapshot().player_uid) == uid,"disk reload keeps UID")
	# Semantic corruption, missing primary, and future versions never mint a UID.
	check(bool(identity.rename_player("Backup Jade").success),"seed known backup")
	var malformed := {"version":1,"player_uid":"bad","display_name":"Valid Name"}
	put_profile(malformed)
	identity.refresh_profile()
	check(bool(identity.get_profile_snapshot().ready),"semantic corruption recovers validated backup")
	check(str(identity.get_profile_snapshot().player_uid) == uid,"semantic recovery keeps original UID")
	DirAccess.remove_absolute(saves.get_save_path("player_profile"))
	identity.refresh_profile()
	check(str(identity.get_profile_snapshot().player_uid) == uid,"missing primary restores backup before generating")
	var valid_payload: Dictionary = saves.read_save_data("player_profile").data.duplicate(true)
	var future: Dictionary = valid_payload.duplicate(true)
	future.version = 2
	put_profile(future)
	var future_hash: String = FileAccess.get_sha256(saves.get_save_path("player_profile"))
	identity.refresh_profile()
	check(not bool(identity.get_profile_snapshot().ready),"future profile fails closed")
	check(FileAccess.get_sha256(saves.get_save_path("player_profile")) == future_hash,"future save preserved without downgrade")
	check(not saves.is_progress_read_only(),"profile fault does not lock gameplay")
	check(not bool(identity.rename_player("Forbidden Jade").success),"unavailable profile cannot be renamed")
	put_profile(valid_payload)
	identity.refresh_profile()
	DirAccess.remove_absolute(saves.get_save_backup_path("player_profile"))
	put_profile(malformed)
	var corrupt_hash: String = FileAccess.get_sha256(saves.get_save_path("player_profile"))
	identity.refresh_profile()
	check(not bool(identity.get_profile_snapshot().ready),"corrupt profile without backup fails closed")
	check(FileAccess.get_sha256(saves.get_save_path("player_profile")) == corrupt_hash,"corrupt profile never overwritten by new UID")
	put_profile(valid_payload)
	identity.refresh_profile()
	for suffix: String in [".rollback",".tmp"]:
		var primary: String = saves.get_save_path("player_profile")
		check(DirAccess.rename_absolute(primary,primary+suffix) == OK,"simulate interrupted identity write")
		identity.refresh_profile()
		check(not bool(identity.get_profile_snapshot().ready),"interrupted write never mints replacement UID")
		check(FileAccess.file_exists(primary+suffix) and not FileAccess.file_exists(primary),"interrupted evidence preserved")
		DirAccess.rename_absolute(primary+suffix,primary)
		identity.refresh_profile()
		check(str(identity.get_profile_snapshot().player_uid) == uid,"restored interrupted fixture retains UID")
	check(bool(identity.rename_player("Kim Ascendant").success),"recover original fixture")
	check(disk_hashes() == initial_hashes,"profile operations leave all eight gameplay saves byte-identical")
	check(change_scene_to_file("res://scenes/ui/main_menu.tscn") == OK,"open real Home")
	await create_timer(0.5).timeout
	var menu: Node = current_scene
	menu._open_profile_sheet()
	await create_timer(0.3).timeout
	var card: Node = menu.profile_sheet_body.get_node("PlayerIdentityCard")
	check(card._uid.text == uid,"real profile shows exact UID")
	check(menu.profile_player_name_label.text == "Kim Ascendant","header shows player name")
	var stats: Dictionary = menu._build_permanent_profile_snapshot()
	card._begin_edit()
	card._name_input.text = "ab"
	card._validate_name_input("ab")
	check(card._save.disabled,"invalid UI input disables Save")
	card._name_input.text = "Unsaved Name"
	card._cancel_edit()
	check(str(identity.get_profile_snapshot().display_name) == "Kim Ascendant","Cancel leaves saved name intact")
	card._begin_edit()
	card._name_input.text = "Jade Kim"
	card._validate_name_input("Jade Kim")
	card._save_name()
	check(menu.profile_player_name_label.text == "Jade Kim","successful rename updates visible header")
	check(card._name.text == "Jade Kim" and not card._editor.visible,"successful rename closes editor and refreshes card")
	check(menu._build_permanent_profile_snapshot() == stats,"name edit leaves displayed stats identical")
	menu._close_profile_sheet()
	menu._open_profile_sheet()
	await create_timer(0.15).timeout
	check(menu.profile_sheet_body.get_node("PlayerIdentityCard")._name.text == "Jade Kim","reopen keeps name")
	check(menu.profile_sheet_body.get_node_or_null("ProfileGoogleAccountCard") != null,"Google account UI retained")
	var marker := ConfigFile.new()
	marker.set_value("qa","uid",uid)
	marker.set_value("qa","name","Jade Kim")
	check(marker.save(MARKER) == OK,"restart evidence saved")
	menu.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	finish()

func finish() -> void:
	print("PLAYER_PROFILE_QA checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
