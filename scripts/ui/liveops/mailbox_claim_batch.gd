extends Node
## Bounded network bursts; each letter retains its own durable receipt and lease.
signal changed
const NETWORK_BATCH: int = 8
var authority: Node
var active: bool = false
var paused: bool = false
var total: int = 0
var claimed: int = 0
var skipped: int = 0
var message: String = ""
var _owner: String = ""
var _ids: Array[String] = []
var _owned_ids: Array[String] = []
var _inflight: Array[String] = []
var _sent_at: int = 0
var _tick: float = 0.0
var _reward: Dictionary = {}
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RewardManager.reward_granted.connect(_capture_reward)
func _live_owner() -> String: return PlayerIdentityServerClient._current_owner()
func _eligible(entry: Dictionary) -> bool:
	return not entry.is_empty() and not (entry.get("reward",{}) as Dictionary).is_empty() and not bool(entry.get("claimed",false)) and bool(entry.get("can_claim",true)) and not bool(entry.get("expired",false)) and not bool(entry.get("cancelled",false)) and not bool(entry.get("blocked_on_other_device",false))
func available() -> int:
	if authority == null: return 0
	var count: int = 0
	for entry: Dictionary in authority.get_mail_entries():
		if _eligible(entry): count += 1
	return count
func start() -> void:
	if active and not paused: return
	if SaveManager.is_progress_read_only(): message = "Save hanya-baca · klaim ditunda"; changed.emit(); return
	if active and paused and _owner == _live_owner():
		paused = false
		_ids.assign(_inflight + _ids)
		_inflight.clear()
		message = "Melanjutkan klaim…"; changed.emit(); return
	_owner = _live_owner(); _ids.clear(); _inflight.clear(); _reward = {}; claimed = 0; skipped = 0
	for entry: Dictionary in authority.get_mail_entries():
		if _eligible(entry): _ids.append(str(entry.id))
	_owned_ids.assign(_ids)
	total = _ids.size(); active = total > 0; paused = false
	message = "Mengambil %d surat…" % total if active else "Tidak ada attachment yang bisa diklaim"
	changed.emit()
func owns_reward(id: String) -> bool:
	if not active or _owner != _live_owner(): return false
	for mail_id: String in _owned_ids:
		if id == ("live_ops_mail_server_" + mail_id.trim_prefix("server:") if mail_id.begins_with("server:") else "live_ops_mail_" + mail_id): return true
	return false
func _capture_reward(source: String,id: String,data: Dictionary) -> void:
	if not owns_reward(id): return
	var applied: Dictionary = RewardManager.get_last_grant_result()
	if bool(applied.get("success",false)) and str(applied.get("source_type","")) == source and str(applied.get("source_id","")) == id and applied.get("applied_reward_data") is Dictionary: data = applied.applied_reward_data
	for key: String in ["spirit_stone","celestial_jade","pavilion_seal","hero_exp"]:
		if int(data.get(key,0)) > 0: _reward[key] = int(_reward.get(key,0)) + int(data[key])
	if data.get("items") is Dictionary:
		if not _reward.has("items"): _reward.items = {}
		for key: String in data.items: _reward.items[key] = int(_reward.items.get(key,0)) + int(data.items[key])
func _process(delta: float) -> void:
	if not active: return
	if _owner != _live_owner():
		active = false; paused = false; _ids.clear(); _inflight.clear(); _reward = {}; message = "Akun berubah · klaim dihentikan"; changed.emit(); return
	if paused: return
	_tick -= delta
	if _tick > 0: return
	_tick = 0.05
	if SaveManager.is_progress_read_only(): paused = true; message = "Save hanya-baca · tekan Claim All untuk lanjut"; changed.emit(); return
	if get_tree().get_first_node_in_group("player") != null: return
	for index: int in range(_inflight.size()-1,-1,-1):
		var id: String = _inflight[index]
		var entry: Dictionary = authority.get_mail(id)
		if bool(entry.get("claimed",false)): claimed += 1; _inflight.remove_at(index)
		elif not _eligible(entry): skipped += 1; _inflight.remove_at(index)
		elif id.begins_with("server:") and ServerMailManager.is_busy_for(id): continue
		elif Time.get_ticks_msec() - _sent_at >= 1000:
			paused = true; message = "Diklaim %d/%d · LANJUTKAN untuk mencoba sisanya" % [claimed,total]; changed.emit(); return
	if not _inflight.is_empty(): return
	message = "Diklaim %d/%d" % [claimed,total]
	if _ids.is_empty(): _complete(); return
	_sent_at = Time.get_ticks_msec()
	# Enqueue a bounded group in one frame so the transport can use one verified
	# token and one claim/ack pair for up to eight distinct letters.
	for index: int in NETWORK_BATCH:
		if _ids.is_empty(): break
		var id: String = _ids.pop_front()
		if not _eligible(authority.get_mail(id)): skipped += 1; continue
		_inflight.append(id)
		if not bool(authority.claim_mail(id)):
			paused = true; message = "Klaim tertunda · LANJUTKAN"; break
	changed.emit()
func _complete() -> void:
	active = false; paused = false
	message = "%d surat diklaim%s" % [claimed," · %d dilewati" % skipped if skipped > 0 else ""]
	changed.emit()
	if _reward.is_empty(): return
	for node: Node in get_tree().root.get_children():
		var script: Script = node.get_script()
		if script != null and script.resource_path == "res://scripts/ui/reward_claim_result_presenter.gd" and node.has_method("show_claimed_reward"):
			node.call("show_claimed_reward","MAILBOX · CLAIM ALL",_reward.duplicate(true)); break
	_reward = {}
