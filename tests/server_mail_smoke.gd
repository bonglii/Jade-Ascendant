extends SceneTree
var checks: int = 0
var failures: int = 0
var mailer: Node
var ops: Node
var saver: Node
var native_auth: Node
var owner: String
const MAIL_ID: String = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const CRASH_ID: String = "cccccccccccccccccccccccccccccccc"
class AuthStub extends Node:
	signal id_token_result(token: String)
	signal id_token_error(message: String)
	var uid: String = "server-mail-qa-user"
	func is_signed_in() -> bool: return true
	func get_current_user_data() -> Dictionary: return {"uid":uid}
	func get_id_token(_force: bool = false) -> void: pass

func check(ok: bool,tag: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(tag)

func _initialize() -> void:
	run.call_deferred()

func entry(id: String) -> Dictionary:
	return {"id":"server:"+id,"mail_id":id,"title":"Server gift","body":"A gift from the sanctuary.","sender":"JADE SANCTUARY","reward":{"spirit_stone":200,"items":{"refinement_shard":2}},"created_at":100,"expires_at":int(Time.get_unix_time_from_system())+86400,"read":false,"claimed":false,"pending":false,"can_claim":true,"blocked_on_other_device":false,"cancelled":false,"expired":false,"receipt_id":""}

func response(data: Dictionary,id: String = MAIL_ID) -> void:
	mailer._queue.clear()
	mailer._pending = {"kind":"claim","id":"server:"+id,"owner":owner,"refreshed_token":false}
	mailer._busy = true
	mailer._waiting_token = false
	mailer._on_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(data).to_utf8_buffer())

func delivery(id: String = MAIL_ID,reward: Dictionary = {"spirit_stone":200,"items":{"refinement_shard":2}}) -> Dictionary:
	return {"owner_binding":owner,"mail_id":id,"installation_id":mailer._state.installation_id,"receipt_id":"dddddddddddddddddddddddddddddddd","delivery_state":"pending","reward":reward}

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_server_mail_qa"):
		push_error("Server mail QA requires isolated user://")
		quit(2)
		return
	await create_timer(0.5).timeout
	mailer = root.get_node("ServerMailManager")
	ops = root.get_node("LiveOpsManager")
	saver = root.get_node("SaveManager")
	native_auth = AuthStub.new()
	root.add_child(native_auth)
	root.get_node("PlayerIdentityServerClient")._auth = native_auth
	mailer._auth_node = native_auth
	owner = str(native_auth.uid).sha256_text()
	mailer._owner = owner
	mailer._queue.clear()
	check(not mailer._state.is_empty(),"mail install ID persisted on first startup")
	if mailer._state.is_empty(): quit(1); return
	check(mailer._valid_id(str(mailer._state.installation_id)),"install ID is bounded lowercase hex")
	var permanent: Array[String] = saver.get_save_domain_ids_for_scope("permanent")
	permanent.sort()
	check(permanent == ["achievements", "cultivation_mastery", "daily_quests", "equipment", "idle_cultivation", "inventory", "journey", "pavilion", "progression"],"all original permanent domains plus approved Mastery preserved")
	check(saver.get_save_scope("server_mail") == "local_profile","presentation cache stays outside locked cloud schema")
	var progression: Node = root.get_node("ProgressionManager")
	var inventory: Node = root.get_node("InventoryManager")
	var pavilion: Node = root.get_node("PavilionManager")
	var expect_path: String = "user://server_mail_qa_expect.json"
	if "--verify-restart" in OS.get_cmdline_user_args() or "--verify-crash" in OS.get_cmdline_user_args():
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expect_path))
		check(str(mailer._state.installation_id) == str(expected.installation),"restart retains delivery installation binding")
		check(progression.spirit_stone == int(expected.stones),"wallet recovered to exact snapshot")
		check(inventory.get_item_count("refinement_shard") == int(expected.shards),"inventory recovered to exact snapshot")
		var id: String = CRASH_ID if "--verify-crash" in OS.get_cmdline_user_args() else MAIL_ID
		check(mailer._has_local_receipt(id),"receipt survives restart alongside rewards")
		var before: int = progression.spirit_stone
		response(delivery(id,{"spirit_stone":17,"items":{"refinement_shard":1}}))
		check(progression.spirit_stone == before,"recovered pending receipt never adds currency twice")
		check(not saver.has_pending_transaction(),"journal recovery completed")
		print("SERVER_MAIL_RESTART checks=",checks," failures=",failures)
		quit(1 if failures else 0)
		return
	if "--crash-prepare" in OS.get_cmdline_user_args():
		var next_progression: Dictionary = progression.build_progression_save_data()
		next_progression.spirit_stone += 17
		var counts: Dictionary = inventory.preview_add_items({"refinement_shard":1})
		var next_pavilion: Dictionary = pavilion.state.duplicate(true)
		next_pavilion.claimed_milestone_ids.append("liveops:server_mail:claim:"+owner+":"+CRASH_ID)
		var targets: Dictionary = {"progression":next_progression,"inventory":{"version":1,"item_counts":counts},"pavilion":next_pavilion}
		check(bool(saver._write_dictionary_to_path_atomic(saver.TRANSACTION_PATH,{"version":1,"targets":targets},false).get("success",false)),"crash fixture durably writes intent")
		check(bool(saver._write_dictionary_to_path_atomic(saver.get_save_path("progression"),next_progression).get("success",false)),"crash fixture stops after one domain commit")
		var expected: Dictionary = {"stones":next_progression.spirit_stone,"shards":counts.get("refinement_shard",0),"installation":mailer._state.installation_id}
		var file := FileAccess.open(expect_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(expected))
		file.close()
		print("SERVER_MAIL_CRASH_PREPARE checks=",checks," failures=",failures)
		quit(1 if failures else 0)
		return
	mailer._state.cache[owner] = [entry(MAIL_ID)]
	check("server:"+MAIL_ID in ops.get_mail_ids(),"server mail joins real mailbox catalog")
	check(not ops.is_mail_claimed("server:"+MAIL_ID),"new server mail is unclaimed")
	var stones_before: int = progression.spirit_stone
	var shards_before: int = inventory.get_item_count("refinement_shard")
	response(delivery())
	check(progression.spirit_stone == stones_before+200,"server-approved receipt grants stones")
	check(inventory.get_item_count("refinement_shard") == shards_before+2,"server-approved receipt grants ordinary item")
	check(mailer._has_local_receipt(MAIL_ID),"reward and receipt commit together")
	check(ops.is_mail_claimed("server:"+MAIL_ID),"pending ack displays already applied reward")
	check(not mailer.can_delete_mail("server:"+MAIL_ID),"pending ack cannot delete recovery state")
	check(mailer._queue.size() == 1 and str(mailer._queue[0].kind) == "ack","ack queued after successful durable grant")
	response(delivery())
	check(progression.spirit_stone == stones_before+200,"lost response retry is locally idempotent")
	check(inventory.get_item_count("refinement_shard") == shards_before+2,"lost response cannot duplicate item")
	var malformed: Dictionary = delivery()
	malformed.owner_binding = "wrong"
	response(malformed)
	check(progression.spirit_stone == stones_before+200,"wrong owner response cannot grant")
	check(not mailer._valid_reward({"spirit_stone":true,"items":{}}),"boolean reward rejected")
	check(not mailer._valid_reward({"spirit_stone":"200","items":{}}),"string reward rejected")
	check(not mailer._valid_reward({"spirit_stone":-1,"items":{}}),"negative reward rejected")
	check(not mailer._valid_reward({"spirit_stone":1,"items":{"premium_jade":1}}),"unsupported paid currency rejected")
	var other: String = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	mailer._pending = {"kind":"claim","id":"server:"+other,"owner":owner}
	mailer._queue.clear()
	var barrier: Dictionary = saver.begin_save_write_barrier("mail_qa","fixture")
	check(bool(barrier.get("success",false)),"write barrier acquired")
	check(not mailer._apply_delivery(delivery(other)),"failed save blocks delivery acknowledgement")
	check(not mailer._has_local_receipt(other),"failed save cannot mark claim")
	check(progression.spirit_stone == stones_before+200,"failed save leaves wallet unchanged")
	saver.end_save_write_barrier("mail_qa")
	var expected: Dictionary = {"stones":progression.spirit_stone,"shards":inventory.get_item_count("refinement_shard"),"installation":mailer._state.installation_id}
	var file := FileAccess.open(expect_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(expected))
	file.close()
	mailer._pending = {"kind":"claim","id":"server:"+MAIL_ID,"owner":owner}
	mailer._busy = true
	native_auth.uid = "other-account"
	mailer._on_profile({})
	check(mailer.get_mail_ids().is_empty(),"account switch hides prior account mailbox")
	check(mailer._queue.is_empty() and not mailer._busy,"account switch cancels in-flight operations")
	check(progression.spirit_stone == stones_before+200,"account switch never grants prior pending response")
	print("SERVER_MAIL_SMOKE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
