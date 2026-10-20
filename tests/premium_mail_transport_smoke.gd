extends SceneTree
class Auth extends Node:
	var requests: int = 0
	func get_id_token(_refresh: bool) -> void: requests += 1
var checks: int = 0
var failures: int = 0
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("PREMIUM_MAIL " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_premium_qa"): quit(2); return
	await create_timer(0.5).timeout
	var server: Node = root.get_node("ServerMailManager")
	var progression: Node = root.get_node("ProgressionManager")
	var transport: Node = load("res://tests/fixtures/premium_mail_transport.gd").new(); root.add_child(transport)
	transport.set_process(false)
	var auth := Auth.new(); transport.add_child(auth); transport._auth_node = auth
	transport._owner = transport.fixture_owner; server._owner = transport.fixture_owner
	var owner: String = transport.fixture_owner
	var entries: Array = []
	for index: int in 9:
		var id: String = "%032x" % (index+1)
		entries.append({"id":"server:"+id,"mail_id":id,"title":"Earned reward","body":"Test receipt","sender":"QA","reward":{"spirit_stone":10,"items":{}},"created_at":1800000000,"expires_at":1900000000,"read":false,"claimed":false,"pending":false,"can_claim":true,"blocked_on_other_device":false,"cancelled":false,"expired":false})
	transport._state = {"installation_id":"1".repeat(32),"cache":{owner:entries}}
	for index: int in 8: check(transport.claim_mail(entries[index].id),"queued independent mail %d" % index)
	transport._start_next()
	check(transport._pending.kind == "claim_batch" and transport._pending.parts.size() == 8,"eight letters use one bounded claim request")
	check(auth.requests == 1,"one token acquisition for the complete claim burst")
	check(transport.is_busy_for(entries[7].id),"busy fence covers every batch member")
	var before: int = progression.spirit_stone
	var deliveries: Array = []
	for index: int in 8: deliveries.append({"mail_id":entries[index].mail_id,"owner_binding":owner,"installation_id":"1".repeat(32),"receipt_id":"%032x" % (index+20),"delivery_state":"pending","reward":{"spirit_stone":10,"items":{}},"success":true})
	transport._on_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"owner_binding":owner,"entries":deliveries}).to_utf8_buffer())
	check(progression.spirit_stone == before+80,"eight authoritative letters applied exactly once")
	check(transport._queue.size() == 8,"every durable local receipt awaits its own acknowledgement")
	for index: int in 8: check(transport._has_local_receipt(entries[index].mail_id),"per-letter receipt persisted %d" % index)
	transport._cached_token = "transient-fixture-token"; transport._cached_token_until = Time.get_ticks_msec()+45000
	transport._start_next()
	check(transport._pending.kind == "ack_batch" and transport._pending.payload.entries.size() == 8,"eight acknowledgements use one request")
	check(auth.requests == 1 and transport.wire.size() == 1,"valid in-memory token reused for acknowledgement")
	var acknowledgements: Array = []
	for index: int in 8: acknowledgements.append({"mail_id":entries[index].mail_id,"owner_binding":owner,"delivery_state":"claimed","success":true})
	transport._on_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"owner_binding":owner,"entries":acknowledgements}).to_utf8_buffer())
	check(not transport._busy and transport._queue.is_empty(),"batch transport drains without per-letter reconnect")
	for index: int in 8:
		check(not transport.claim_mail(entries[index].id),"replay cannot enqueue a claimed letter %d" % index)
		check(not bool(transport.get_mail(entries[index].id).pending),"ack clears each pending lease %d" % index)
	check(progression.spirit_stone == before+80,"ack and replay never mint reward")
	check(transport.claim_mail(entries[8].id),"last letter queued for owner-switch fixture")
	transport._start_next(); transport.fixture_owner = "new_fixture_owner".sha256_text()
	transport._on_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"owner_binding":owner,"mail_id":entries[8].mail_id,"delivery_state":"claimed"}).to_utf8_buffer())
	check(transport._cached_token.is_empty() and transport._queue.is_empty() and not transport._busy,"account switch clears pending transport and token")
	check(progression.spirit_stone == before+80,"late previous-owner response cannot grant")
	check(not root.get_node("SaveManager").has_pending_transaction(),"mail batch leaves no pending save journal")
	server._owner = ""
	transport.queue_free(); await process_frame
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	if current_scene != null: current_scene.queue_free(); current_scene = null
	for index: int in 8: await process_frame
	print("PREMIUM_MAIL_TRANSPORT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
