extends VBoxContainer
## Paid summon CTA (independent of local summon buttons and local saves).
## Only instantiate after PavilionManager.HYBRID_PAID_SUMMON_WRITE_APPROVED.
## Result presentation is server-only; never emit local summon_completed.

var _status: Label
var _single: Button
var _ten: Button
var _recover: Button
var _recover_purchase: Button

func _ready() -> void:
	name = "PaidSummonSecureActions"
	add_theme_constant_override("separation", 8)
	var heading := Label.new()
	heading.text = "SERVER-VERIFIED JADE SUMMON"
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color(0.96, 0.80, 0.36))
	add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_single = _action(row, "PAID ×1 • 100 JADE", 1)
	_ten = _action(row, "PAID ×10 • 900 JADE", 10)
	_recover = Button.new()
	_recover.text = "RECOVER PENDING SUMMON"
	_recover.custom_minimum_size.y = 44.0
	_recover.pressed.connect(_recover_pending)
	add_child(_recover)
	_recover_purchase = Button.new()
	_recover_purchase.text = "REPAIR VERIFIED PLAY PURCHASES"
	_recover_purchase.custom_minimum_size.y = 44.0
	_recover_purchase.visible = PavilionManager.PAID_LEDGER_REPAIR_UI_APPROVED
	_recover_purchase.pressed.connect(_repair_purchases)
	add_child(_recover_purchase)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Only purchased Jade is spent here. Local Jade and saves stay unchanged."
	_status.add_theme_font_size_override("font_size", 12)
	add_child(_status)
	var cb := Callable(self, "_on_paid_summon_changed")
	if not PavilionManager.paid_summon_commit_rc4_changed.is_connected(cb):
		PavilionManager.paid_summon_commit_rc4_changed.connect(cb)
	_on_paid_summon_changed(PavilionManager.get_paid_summon_commit_rc4_view())
	var repair_cb := Callable(self, "_on_purchase_repair_changed")
	if not PavilionManager.paid_verified_purchase_repair_changed.is_connected(repair_cb):
		PavilionManager.paid_verified_purchase_repair_changed.connect(repair_cb)

func _action(row: HBoxContainer, text_value: String, pulls: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 48.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_request_summon.bind(pulls))
	row.add_child(button)
	return button

func _request_summon(pulls: int) -> void:
	# Only server can debit/roll. A failed attempt never creates a local grant.
	if not PavilionManager.request_paid_summon_rc4(pulls):
		_status.text = "Paid summon unavailable. Check account, network, or pending recovery."

func _recover_pending() -> void:
	if not PavilionManager.resume_pending_paid_summon_rc4():
		_status.text = "No recoverable request for the current verified account."

func _repair_purchases() -> void:
	if not PavilionManager.request_paid_verified_purchase_repair():
		_status.text = "Purchase repair unavailable: verify your account or try later."

func _on_purchase_repair_changed(view: Dictionary) -> void:
	if _status == null or _recover_purchase == null:
		return
	var state: String = str(view.get("status", "unavailable"))
	_recover_purchase.disabled = state == "loading"
	if state == "reconciled":
		_status.text = "Verified purchases checked on server. %d wallet credits recovered. No local save was changed." % int(view.get("new_wallet_credits", 0))
	elif state == "loading":
		_status.text = "Checking verified Google Play purchases on server..."
	elif state in ["account_changed", "invalid_response", "unavailable"]:
		_status.text = "Purchase repair unavailable; server and local saves remain unchanged."

func _on_paid_summon_changed(view: Dictionary) -> void:
	if _status == null:
		return
	var status: String = str(view.get("status", "not_connected"))
	var busy: bool = status == "loading"
	_single.disabled = busy
	_ten.disabled = busy
	_recover.disabled = busy
	if busy:
		_status.text = "Confirming paid summon on server. Do not restart another purchase."
	elif status == "committed":
		var outcome: Dictionary = view.get("outcome", {})
		var names: Array[String] = []
		for entry: Variant in outcome.get("results", []):
			if entry is Dictionary:
				var item_id: String = str(entry.get("item_id", ""))
				var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
				var label: String = str(item_data.get("display_name", item_id))
				if bool(entry.get("duplicate", false)):
					label += " (duplicate)"
				names.append(label)
		var wallet: Dictionary = view.get("wallet", {})
		_status.text = "Server committed: %s | Paid Jade remaining: %d. Equipment appears after server entitlement sync." % [", ".join(names), int(wallet.get("balance", 0))]
	elif status in ["unavailable", "account_changed", "invalid_response"]:
		_status.text = "Network/account changed; use RECOVER PENDING. Do not open a new paid summon."
