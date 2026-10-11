extends RefCounted
## Volatile, account-bound paid loadout projection, never a game save.
## Paid runtime remains gated in EquipmentManager, not authorized by this parser.
const Slots: Array[String] = ["armament", "robe", "bracer", "boots", "pendant"]
const Loadout = preload("res://scripts/monetization/hybrid_paid_loadout_rc2.gd")
const FRESH_MSEC: int = 120000

static func empty(reason: String = "not_connected") -> Dictionary:
	return {"status": reason, "owner_binding": "", "paid_slots": {}, "expires_at_msec": -1,
		"display_only": true, "can_grant": false, "can_spend": false, "can_save": false}

static func verified_session(owner_binding: String, entitlements: Dictionary, loadout: Dictionary, now_msec: int) -> Dictionary:
	if owner_binding.length() != 64 or now_msec < 0:
		return empty("invalid_account")
	var hex_re := RegEx.new()
	if hex_re.compile("^[a-f0-9]{64}$") != OK or hex_re.search(owner_binding) == null:
		return empty("invalid_account")
	if entitlements.get("status") != "ready" or entitlements.get("authority") != "server_read_only":
		return empty("entitlement_unavailable")
	if loadout.get("status") != "ready" or loadout.get("authority") != "server_only":
		return empty("loadout_unavailable")
	if int(entitlements.get("revision", -1)) != int(loadout.get("entitlement_revision", -2)):
		return empty("revision_mismatch")
	var owned: Variant = entitlements.get("item_ids", null)
	var slots: Variant = loadout.get("paid_slots", null)
	if not (owned is Array) or not (slots is Dictionary) or (slots as Dictionary).size() != Slots.size():
		return empty("invalid_slots")
	var result: Dictionary = {}
	for slot: String in Slots:
		if not slots.has(slot) or not (slots[slot] is String):
			return empty("invalid_slots")
		var item_id: String = slots[slot]
		if not item_id.is_empty():
			if item_id not in owned or item_id not in Loadout.PER_SLOT[slot]:
				return empty("invalid_ownership")
		result[slot] = item_id
	return {"status": "ready", "owner_binding": owner_binding,
		"paid_slots": result, "expires_at_msec": now_msec + FRESH_MSEC,
		"display_only": true, "can_grant": false, "can_spend": false, "can_save": false}

static func slot_if_fresh(snapshot: Dictionary, live_account_binding: String, slot_id: String, now_msec: int) -> String:
	if snapshot.get("status") != "ready" or live_account_binding.is_empty():
		return ""
	if str(snapshot.get("owner_binding", "")) != live_account_binding:
		return ""
	if now_msec < 0 or now_msec > int(snapshot.get("expires_at_msec", -1)):
		return ""
	var slots: Variant = snapshot.get("paid_slots", {})
	if not (slots is Dictionary) or slot_id not in Slots:
		return ""
	return str(slots.get(slot_id, ""))
