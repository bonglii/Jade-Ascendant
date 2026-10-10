extends Node

## Jade Pavilion permanent economy owner.
## Economy Foundation v2 keeps the existing v1 save domain and adds optional
## currency / summon fields additively so legacy pavilion.save files remain valid.
##
## IMPORTANT: Celestial Jade can only enter runtime through a trusted verified
## grant API. The current shipping OfflineProvider does not grant paid currency.

signal pavilion_changed
signal summon_completed(result: Dictionary)
signal store_products_updated(products: Dictionary)
signal billing_purchase_state_changed(
	product_id: String,
	status: String,
	message: String
)
signal purchase_delivery_finished(
	product_id: String,
	success: bool,
	message: String
)
signal billing_entitlements_changed(product_ids: Array[String])
## Display-only paid wallet update; never a credit/debit/summon authorization.
signal paid_wallet_snapshot_m9_changed(view: Dictionary)
## M14 server-credit acknowledgment is volatile display only.
signal paid_purchase_receipt_m14_changed(view: Dictionary)
## M12 committed summon recovery is a volatile DISPLAY snapshot only.
signal paid_summon_recovery_m12_changed(view: Dictionary)
## FastTrack read-only paid entitlement view; never written to user:// inventory.
signal paid_entitlements_rc_changed(view: Dictionary)

const EconomyCatalog = preload("res://scripts/data/economy_catalog.gd")
const OfflineBillingProvider = preload(
	"res://scripts/monetization/offline_billing_provider.gd"
)
const GooglePlayBillingProvider = preload(
	"res://scripts/monetization/google_play_billing_provider.gd"
)
const PURCHASE_AUTHORITY_SINGLETON: String = "JadeMonetizationNativeBridge"
const SECURE_PURCHASE_ACTIVATION_APPROVED: bool = false
const HybridWalletGameBridgeM7 = preload(
	"res://scripts/monetization/hybrid_wallet_game_bridge_m7.gd"
)
const HybridPaidWalletSnapshotM9 = preload(
	"res://scripts/monetization/hybrid_paid_wallet_snapshot_m9.gd"
)
## Explicit follow-up approval needed AFTER Worker read route QA.
const HYBRID_PAID_WALLET_DISPLAY_SYNC_APPROVED: bool = false
const HybridPaidPurchaseReceiptM14 = preload("res://scripts/monetization/hybrid_paid_purchase_receipt_m14.gd")
const HybridPaidSummonRecoveryM12 = preload(
	"res://scripts/monetization/hybrid_paid_summon_recovery_m12.gd"
)
## Kept false until server-issued paid outcomes can be reconciled exactly once.
const HYBRID_PAID_SUMMON_RECOVERY_READ_APPROVED: bool = false
const HybridPaidEntitlementsRC = preload("res://scripts/monetization/hybrid_paid_entitlements_rc.gd")
const HYBRID_PAID_ENTITLEMENTS_DISPLAY_APPROVED: bool = false

const MEDITATION_REWARD: int = 20
const PAYMENT_AUTO: String = "auto"
const PAYMENT_SEAL: String = "seal"
const PAYMENT_JADE: String = "jade"

const COSMETICS: Dictionary = {
	"plain": {
		"name": "Wandering Cultivator",
		"chapter": 0,
		"stage": 0,
		"stone_cost": 0,
		"shard_cost": 0
	},
	"jade_aura": {
		"name": "Shrinekeeper Aura",
		"chapter": 1,
		"stage": 3,
		"stone_cost": 0,
		"shard_cost": 0
	},
	"golden_aura": {
		"name": "Sovereign Aura",
		"chapter": 1,
		"stage": 5,
		"stone_cost": 0,
		"shard_cost": 0
	},
	"astral_aura": {
		"name": "Astral Crown Aura",
		"chapter": 3,
		"stage": 5,
		"stone_cost": 2500,
		"shard_cost": 40
	},
	"ascendant_aura": {
		"name": "Jade Ascendant Halo",
		"chapter": 3,
		"stage": 5,
		"stone_cost": 5000,
		"shard_cost": 90,
		"requires_cosmetic": "astral_aura"
	}
}

const MAX_PROCESSED_GRANT_IDS: int = 1024
const SECONDS_PER_DAY: int = 86400

const DEFAULT_STATE: Dictionary = {
	"version": 1,
	"meditation_date": "",
	"cosmetic_id": "plain",
	"owned_cosmetics": ["plain"],
	"celestial_jade": 0,
	"pavilion_seals": 0,
	"starter_seals_claimed": false,
	"wish_item_id": "",
	"wish_fate_guaranteed": false,
	"pity_rare_plus": 0,
	"pity_epic_plus": 0,
	"pity_legendary": 0,
	"lifetime_pulls": 0,
	"cadence_last_daily_bonus_date": "",
	"cadence_active_days": 0,
	"cadence_cycles_completed": 0,
	"rewarded_ads_claimed_in_cycle": 0,
	"claimed_milestone_ids": [],
	"claimed_one_time_product_ids": [],
	"monthly_blessing_expires_unix": 0,
	"monthly_blessing_last_claim_date": "",
	"monthly_blessing_daily_claims_remaining": 0,
	"monthly_blessing_purchase_count": 0,
	"processed_grant_ids": [],
	"processed_iap_grant_ids": []
}

var state: Dictionary = DEFAULT_STATE.duplicate(true)
var last_error: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var billing_provider: Node = null
var billing_store_products: Dictionary = {}
var billing_owned_product_ids: Array[String] = []
var secure_purchase_authority_ready: bool = false
var purchase_authority_bridge: Object = null
var secure_purchase_in_flight_product_id: String = ""
var _secure_purchase_in_flight_binding_m14: String = ""
var _paid_purchase_receipt_m14: Dictionary = HybridPaidPurchaseReceiptM14.empty()
var secure_purchase_recovery_rescan_requested: bool = false
## M9 ephemeral display state: excluded from pavilion.save and summon accounting.
var _paid_wallet_bridge_m9: Object = null
var _paid_summon_recovery_bridge_m12: Object = null
var _paid_summon_recovery_request_m12: String = ""
var _paid_summon_recovery_view_m12: Dictionary = {}
var _paid_entitlements_bridge_rc: Object = null
var _paid_entitlements_pending_rc: bool = false
var _paid_entitlements_binding_rc: String = ""
var _paid_entitlements_view_rc: Dictionary = HybridPaidEntitlementsRC.empty()
var _paid_wallet_pending_m9: bool = false
var _paid_wallet_view_m9: Dictionary = HybridPaidWalletSnapshotM9.empty()


func _ready() -> void:
	rng.randomize()
	if not EconomyCatalog.is_valid():
		push_error("PavilionManager: EconomyCatalog v2 cadence tidak valid.")
	_attach_billing_provider(OfflineBillingProvider.new())
	if OS.get_name() == "Android":
		call_deferred("_activate_android_billing_provider")
	var result: Dictionary = SaveManager.read_save_data("pavilion")
	if bool(result.get("success", false)):
		_apply_loaded_state(result.get("data", {}))
		_sanitize_wish_target()
		# Persist additive fields once so old saves migrate without changing schema.
		if not SaveManager.is_progress_read_only():
			_save_state()
	elif not bool(result.get("exists", false)):
		_save_state()
	_connect_cadence_hooks()
	call_deferred("_connect_secure_purchase_transport")
	call_deferred("_connect_paid_wallet_transport_m9")
	call_deferred("_connect_secure_purchase_identity")
	call_deferred("_sync_economy_cadence")


func _apply_loaded_state(data: Dictionary) -> void:
	state = DEFAULT_STATE.duplicate(true)
	state["meditation_date"] = str(data.get("meditation_date", ""))

	var cosmetic_id: String = str(data.get("cosmetic_id", "plain"))
	state["cosmetic_id"] = cosmetic_id if COSMETICS.has(cosmetic_id) else "plain"

	var normalized_owned: Array = []
	var owned: Variant = data.get("owned_cosmetics", ["plain"])
	if owned is Array:
		for raw_id in owned:
			var owned_id: String = str(raw_id)
			if COSMETICS.has(owned_id) and owned_id not in normalized_owned:
				normalized_owned.append(owned_id)
	if "plain" not in normalized_owned:
		normalized_owned.append("plain")
	state["owned_cosmetics"] = normalized_owned

	state["celestial_jade"] = maxi(int(data.get("celestial_jade", 0)), 0)
	state["pavilion_seals"] = maxi(int(data.get("pavilion_seals", 0)), 0)
	state["starter_seals_claimed"] = bool(data.get("starter_seals_claimed", false))
	state["wish_item_id"] = str(data.get("wish_item_id", ""))
	state["wish_fate_guaranteed"] = bool(data.get("wish_fate_guaranteed", false))
	state["cadence_last_daily_bonus_date"] = str(
		data.get("cadence_last_daily_bonus_date", "")
	)
	state["cadence_active_days"] = clampi(
		int(data.get("cadence_active_days", 0)),
		0,
		EconomyCatalog.ACTIVE_DAY_CYCLE_LENGTH - 1
	)
	state["cadence_cycles_completed"] = maxi(
		int(data.get("cadence_cycles_completed", 0)),
		0
	)
	state["rewarded_ads_claimed_in_cycle"] = clampi(
		int(data.get("rewarded_ads_claimed_in_cycle", 0)),
		0,
		EconomyCatalog.REWARDED_AD_MAX_PER_CYCLE
	)
	state["monthly_blessing_expires_unix"] = maxi(
		int(data.get("monthly_blessing_expires_unix", 0)),
		0
	)
	state["monthly_blessing_last_claim_date"] = str(
		data.get("monthly_blessing_last_claim_date", "")
	)
	state["monthly_blessing_daily_claims_remaining"] = maxi(
		int(data.get("monthly_blessing_daily_claims_remaining", 0)),
		0
	)
	state["monthly_blessing_purchase_count"] = maxi(
		int(data.get("monthly_blessing_purchase_count", 0)),
		0
	)
	state["claimed_milestone_ids"] = _normalize_string_array(
		data.get("claimed_milestone_ids", [])
	)
	state["claimed_one_time_product_ids"] = _normalize_string_array(
		data.get("claimed_one_time_product_ids", [])
	)
	state["pity_rare_plus"] = clampi(
		int(data.get("pity_rare_plus", 0)),
		0,
		int(EconomyCatalog.PITY_LIMITS["rare_plus"]) - 1
	)
	state["pity_epic_plus"] = clampi(
		int(data.get("pity_epic_plus", 0)),
		0,
		int(EconomyCatalog.PITY_LIMITS["epic_plus"]) - 1
	)
	state["pity_legendary"] = clampi(
		int(data.get("pity_legendary", 0)),
		0,
		int(EconomyCatalog.PITY_LIMITS["legendary"]) - 1
	)
	state["lifetime_pulls"] = maxi(int(data.get("lifetime_pulls", 0)), 0)

	var processed: Array = _normalize_string_array(data.get("processed_grant_ids", []))
	var processed_iap: Array = _normalize_string_array(
		data.get("processed_iap_grant_ids", [])
	)
	var migrated_iap: Dictionary = _migrate_legacy_iap_grant_ids(
		processed,
		processed_iap
	)
	processed = migrated_iap["generic"]
	processed_iap = migrated_iap["iap"]
	while processed.size() > MAX_PROCESSED_GRANT_IDS:
		processed.pop_front()
	state["processed_grant_ids"] = processed
	# Paid IAP replay protection is exact and intentionally not truncated.
	state["processed_iap_grant_ids"] = processed_iap

	var loaded_cosmetic_id: String = str(state["cosmetic_id"])
	if not is_cosmetic_owned(loaded_cosmetic_id):
		var loaded_cost: Dictionary = get_cosmetic_cost(loaded_cosmetic_id)
		var loaded_is_free: bool = (
			int(loaded_cost.get("spirit_stone", 0)) <= 0
			and int(loaded_cost.get("refinement_shard", 0)) <= 0
		)
		if loaded_is_free and is_cosmetic_stage_unlocked(loaded_cosmetic_id):
			state["owned_cosmetics"].append(loaded_cosmetic_id)
		else:
			state["cosmetic_id"] = "plain"


func _normalize_string_array(raw_value: Variant) -> Array:
	var normalized: Array = []
	if raw_value is Array:
		for raw_entry in raw_value:
			var value: String = str(raw_entry).strip_edges()
			if not value.is_empty() and value not in normalized:
				normalized.append(value)
	return normalized


func _migrate_legacy_iap_grant_ids(
	processed: Array,
	processed_iap: Array
) -> Dictionary:
	var generic: Array = []
	var iap: Array = processed_iap.duplicate()
	for raw_entry in processed:
		var entry: String = str(raw_entry).strip_edges()
		if entry.begins_with("iap:"):
			var second_colon: int = entry.find(":", 4)
			if second_colon > 4 and second_colon + 1 < entry.length():
				var purchase_token: String = entry.substr(second_colon + 1)
				var migrated_id: String = "iapv1:" + _sha256_hex(purchase_token)
				if _is_iap_grant_id(migrated_id):
					if migrated_id not in iap:
						iap.append(migrated_id)
					# Never keep a legacy raw Play purchase token in local save.
					continue
		if not entry.is_empty() and entry not in generic:
			generic.append(entry)
	return {
		"generic": generic,
		"iap": iap,
	}


func _sha256_hex(value: String) -> String:
	if value.is_empty():
		return ""
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(value.to_utf8_buffer()) != OK:
		return ""
	return hashing.finish().hex_encode()


func _is_iap_grant_id(value: String) -> bool:
	if not value.begins_with("iapv1:") or value.length() != 70:
		return false
	for character in value.substr(6):
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _dictionary_has_exact_keys(data: Dictionary, expected: Array) -> bool:
	if data.size() != expected.size():
		return false
	for raw_key in data:
		if not (raw_key is String) or raw_key not in expected:
			return false
	return true


func _save_state() -> bool:
	state["version"] = 1
	var result: Dictionary = SaveManager.write_save_data("pavilion", state)
	if not bool(result.get("success", false)):
		last_error = "The Pavilion could not be saved. Restart the game to recover."
		return false
	return true


func get_celestial_jade() -> int:
	return maxi(int(state.get("celestial_jade", 0)), 0)


## M7 read-only Hybrid inspection: local balance remains unclassified.
## These methods NEVER authorize, debit, credit, summon or write a save.
func get_hybrid_wallet_m7_status() -> Dictionary:
	var grants: Variant = state.get("processed_iap_grant_ids", [])
	if not (grants is Array):
		return {"error": "invalid_local_grants", "runtime_cutover": false}
	return HybridWalletGameBridgeM7.status_from_local(
		get_celestial_jade(), grants as Array,
		not SECURE_PURCHASE_ACTIVATION_APPROVED
	)


func preview_hybrid_summon_m7(pull_count: int, source: String = "auto") -> Dictionary:
	return HybridWalletGameBridgeM7.preview_summon(
		get_celestial_jade(), pull_count, source
	)


## M9 READ-ONLY native transport. Never writes save, modifies game currency,
## or opens any purchasing/summoning path. Read gate remains false in M9.
func get_paid_wallet_m9_view() -> Dictionary:
	return _paid_wallet_view_m9.duplicate(true)


func _invalidate_paid_wallet_m9(status: String = "not_connected") -> void:
	_paid_wallet_pending_m9 = false
	_paid_wallet_view_m9 = HybridPaidWalletSnapshotM9.empty(status)
	paid_wallet_snapshot_m9_changed.emit(get_paid_wallet_m9_view())


func _connect_paid_wallet_transport_m9() -> bool:
	_paid_wallet_bridge_m9 = null
	if OS.get_name() != "Android":
		return false
	if not Engine.has_singleton(PURCHASE_AUTHORITY_SINGLETON):
		return false
	var bridge: Object = Engine.get_singleton(PURCHASE_AUTHORITY_SINGLETON)
	if bridge == null:
		return false
	if not bridge.has_method("refreshPaidWalletSnapshot"):
		return false
	if not bridge.has_signal("paidWalletSnapshotResult"):
		return false
	var callback := Callable(self, "_on_paid_wallet_snapshot_result_m9")
	if not bridge.is_connected("paidWalletSnapshotResult", callback):
		bridge.connect("paidWalletSnapshotResult", callback)
	_paid_wallet_bridge_m9 = bridge
	return true


func request_paid_wallet_snapshot_m9() -> bool:
	## The Worker read endpoint has NOT been enabled/deployed. This approval
	## must only be flipped after separate read-route and identity QA.
	if not HYBRID_PAID_WALLET_DISPLAY_SYNC_APPROVED:
		return false
	if _paid_wallet_pending_m9 or OS.get_name() != "Android":
		return false
	if GoogleAccountManager.get_monetization_account_binding().is_empty():
		_invalidate_paid_wallet_m9("identity_required")
		return false
	if _paid_wallet_bridge_m9 == null or not is_instance_valid(_paid_wallet_bridge_m9):
		if not _connect_paid_wallet_transport_m9():
			_invalidate_paid_wallet_m9("not_connected")
			return false
	_paid_wallet_pending_m9 = true
	_paid_wallet_view_m9 = HybridPaidWalletSnapshotM9.empty("loading")
	paid_wallet_snapshot_m9_changed.emit(get_paid_wallet_m9_view())
	_paid_wallet_bridge_m9.call("refreshPaidWalletSnapshot")
	return true


func _on_paid_wallet_snapshot_result_m9(success: bool, status: String, payload: String) -> void:
	## Ignore unsolicited/late native results after logout or reset.
	if not _paid_wallet_pending_m9:
		return
	_paid_wallet_pending_m9 = false
	if GoogleAccountManager.get_monetization_account_binding().is_empty():
		_invalidate_paid_wallet_m9("identity_required")
		return
	_paid_wallet_view_m9 = HybridPaidWalletSnapshotM9.from_native_result(
		success, status, payload
	)
	paid_wallet_snapshot_m9_changed.emit(get_paid_wallet_m9_view())


## FastTrack read-only server entitlement mirror. NEVER touches inventory.save.
func get_paid_entitlements_rc_view() -> Dictionary:
	return _paid_entitlements_view_rc.duplicate(true)

func _invalidate_paid_entitlements_rc(status: String = "not_connected") -> void:
	_paid_entitlements_pending_rc = false
	_paid_entitlements_binding_rc = ""
	_paid_entitlements_view_rc = HybridPaidEntitlementsRC.empty(status)
	paid_entitlements_rc_changed.emit(get_paid_entitlements_rc_view())

func _connect_paid_entitlements_rc() -> bool:
	_paid_entitlements_bridge_rc = null
	if OS.get_name() != "Android" or not Engine.has_singleton(PURCHASE_AUTHORITY_SINGLETON):
		return false
	var bridge: Object = Engine.get_singleton(PURCHASE_AUTHORITY_SINGLETON)
	if bridge == null or not bridge.has_method("refreshPaidEntitlements") or not bridge.has_signal("paidEntitlementsReadResult"):
		return false
	var callback := Callable(self, "_on_paid_entitlements_result_rc")
	if not bridge.is_connected("paidEntitlementsReadResult", callback):
		bridge.connect("paidEntitlementsReadResult", callback)
	_paid_entitlements_bridge_rc = bridge
	return true

func request_paid_entitlements_rc() -> bool:
	if not HYBRID_PAID_ENTITLEMENTS_DISPLAY_APPROVED or _paid_entitlements_pending_rc:
		return false
	var binding: String = GoogleAccountManager.get_monetization_account_binding()
	if binding.is_empty():
		_invalidate_paid_entitlements_rc("identity_required")
		return false
	if _paid_entitlements_bridge_rc == null or not is_instance_valid(_paid_entitlements_bridge_rc):
		if not _connect_paid_entitlements_rc():
			_invalidate_paid_entitlements_rc("not_connected")
			return false
	_paid_entitlements_pending_rc = true
	_paid_entitlements_binding_rc = binding
	_paid_entitlements_view_rc = HybridPaidEntitlementsRC.empty("loading")
	paid_entitlements_rc_changed.emit(get_paid_entitlements_rc_view())
	_paid_entitlements_bridge_rc.call("refreshPaidEntitlements")
	return true

func _on_paid_entitlements_result_rc(success: bool, status: String, payload: String) -> void:
	if not _paid_entitlements_pending_rc:
		return
	var bound_uid: String = _paid_entitlements_binding_rc
	_paid_entitlements_pending_rc = false
	_paid_entitlements_binding_rc = ""
	if bound_uid.is_empty() or GoogleAccountManager.get_monetization_account_binding() != bound_uid:
		_invalidate_paid_entitlements_rc("identity_changed")
		return
	_paid_entitlements_view_rc = HybridPaidEntitlementsRC.from_native_result(success, status, payload)
	paid_entitlements_rc_changed.emit(get_paid_entitlements_rc_view())


## M12 read-only recovery handoff. Never writes game state or applies rewards.
func get_paid_summon_recovery_m12_view() -> Dictionary:
	if _paid_summon_recovery_view_m12.is_empty():
		return HybridPaidSummonRecoveryM12.empty()
	return _paid_summon_recovery_view_m12.duplicate(true)

func _invalidate_paid_summon_recovery_m12(reason: String = "not_connected") -> void:
	_paid_summon_recovery_request_m12 = ""
	_paid_summon_recovery_view_m12 = HybridPaidSummonRecoveryM12.empty(reason)
	paid_summon_recovery_m12_changed.emit(get_paid_summon_recovery_m12_view())

func _connect_paid_summon_recovery_m12() -> bool:
	_paid_summon_recovery_bridge_m12 = null
	if OS.get_name() != "Android" or not Engine.has_singleton(PURCHASE_AUTHORITY_SINGLETON):
		return false
	var bridge: Object = Engine.get_singleton(PURCHASE_AUTHORITY_SINGLETON)
	if bridge == null or not bridge.has_method("recoverPaidSummon") or not bridge.has_signal("paidSummonRecoveryResult"):
		return false
	var callback := Callable(self, "_on_paid_summon_recovery_result_m12")
	if not bridge.is_connected("paidSummonRecoveryResult", callback):
		bridge.connect("paidSummonRecoveryResult", callback)
	_paid_summon_recovery_bridge_m12 = bridge
	return true

func request_paid_summon_recovery_m12(request_id: String) -> bool:
	if not HYBRID_PAID_SUMMON_RECOVERY_READ_APPROVED:
		return false
	if not _paid_summon_recovery_request_m12.is_empty():
		return false
	if not HybridPaidSummonRecoveryM12.valid_request_id(request_id):
		return false
	if GoogleAccountManager.get_monetization_account_binding().is_empty():
		_invalidate_paid_summon_recovery_m12("identity_required")
		return false
	if _paid_summon_recovery_bridge_m12 == null or not is_instance_valid(_paid_summon_recovery_bridge_m12):
		if not _connect_paid_summon_recovery_m12():
			_invalidate_paid_summon_recovery_m12("not_connected")
			return false
	_paid_summon_recovery_request_m12 = request_id.to_lower()
	_paid_summon_recovery_view_m12 = HybridPaidSummonRecoveryM12.empty("loading")
	paid_summon_recovery_m12_changed.emit(get_paid_summon_recovery_m12_view())
	_paid_summon_recovery_bridge_m12.call("recoverPaidSummon", request_id)
	return true

func _on_paid_summon_recovery_result_m12(success: bool, status: String, payload: String) -> void:
	if _paid_summon_recovery_request_m12.is_empty():
		return
	var expected_id: String = _paid_summon_recovery_request_m12
	_paid_summon_recovery_request_m12 = ""
	if GoogleAccountManager.get_monetization_account_binding().is_empty():
		_invalidate_paid_summon_recovery_m12("identity_required")
		return
	_paid_summon_recovery_view_m12 = HybridPaidSummonRecoveryM12.from_native_result(
		success, status, payload, expected_id
	)
	paid_summon_recovery_m12_changed.emit(get_paid_summon_recovery_m12_view())


func get_pavilion_seals() -> int:
	return maxi(int(state.get("pavilion_seals", 0)), 0)


func get_lifetime_pulls() -> int:
	return maxi(int(state.get("lifetime_pulls", 0)), 0)


func get_economy_summary() -> Dictionary:
	return {
		"celestial_jade": get_celestial_jade(),
		"pavilion_seals": get_pavilion_seals(),
		"refinement_shards": InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD),
		"spirit_stones": ProgressionManager.spirit_stone,
		"lifetime_pulls": get_lifetime_pulls(),
		"cadence": get_cadence_status(),
		"wish_fate_guaranteed": is_wish_fate_guaranteed(),
		"monthly_blessing_active": is_monthly_blessing_active()
	}


## Trusted boundary for future billing/reward adapters. `grant_id` must be a
## unique verified transaction id so replay never double-grants.
func apply_verified_economy_grant(
	grant_id: String,
	celestial_jade_amount: int,
	pavilion_seal_amount: int = 0
) -> bool:
	last_error = ""
	var next_state: Dictionary = state.duplicate(true)
	if not _commit_currency_grant(
		next_state,
		grant_id,
		celestial_jade_amount,
		pavilion_seal_amount
	):
		return false
	pavilion_changed.emit()
	return true


func _commit_currency_grant(
	next_state: Dictionary,
	grant_id: String,
	celestial_jade_amount: int,
	pavilion_seal_amount: int
) -> bool:
	if SaveManager.is_progress_read_only():
		last_error = "Restart the game to recover a pending save."
		return false
	var normalized_id: String = grant_id.strip_edges()
	if normalized_id.is_empty():
		last_error = "Verified grant id is required."
		return false
	if celestial_jade_amount < 0 or pavilion_seal_amount < 0:
		last_error = "Verified currency grant cannot be negative."
		return false
	if celestial_jade_amount == 0 and pavilion_seal_amount == 0:
		last_error = "Verified currency grant is empty."
		return false
	var processed: Array = _normalize_string_array(
		next_state.get("processed_grant_ids", [])
	)
	if normalized_id in processed:
		last_error = "Verified grant already consumed."
		return false
	next_state["celestial_jade"] = maxi(
		int(next_state.get("celestial_jade", 0)) + celestial_jade_amount,
		0
	)
	next_state["pavilion_seals"] = maxi(
		int(next_state.get("pavilion_seals", 0)) + pavilion_seal_amount,
		0
	)
	processed.append(normalized_id)
	while processed.size() > MAX_PROCESSED_GRANT_IDS:
		processed.pop_front()
	next_state["processed_grant_ids"] = processed
	return _commit_pavilion_state(next_state)


func get_iap_product_catalog() -> Dictionary:
	return EconomyCatalog.get_iap_products()


func get_iap_product_data(product_id: String) -> Dictionary:
	return EconomyCatalog.get_iap_product(product_id)


func has_claimed_one_time_product(product_id: String) -> bool:
	return product_id in _normalize_string_array(
		state.get("claimed_one_time_product_ids", [])
	)


func get_iap_store_products() -> Dictionary:
	return billing_store_products.duplicate(true)


func get_billing_runtime_status() -> Dictionary:
	if not is_instance_valid(billing_provider):
		return {
			"provider": "none",
			"state": "missing",
			"ready": false,
			"secure_purchase_authority_ready": false,
		}
	var raw: Variant = billing_provider.call("get_runtime_status")
	if not (raw is Dictionary):
		return {}
	var status: Dictionary = (raw as Dictionary).duplicate(true)
	status["secure_purchase_authority_ready"] = secure_purchase_authority_ready
	if not secure_purchase_authority_ready:
		status["ready"] = false
		var account_binding: String = (
			GoogleAccountManager.get_monetization_account_binding()
		)
		status["state"] = (
			"identity_preparing"
			if account_binding.is_empty()
			else "secure_verification_unavailable"
		)
	return status


func is_iap_purchase_supported(product_id: String) -> bool:
	return (
		secure_purchase_authority_ready
		and is_instance_valid(billing_provider)
		and bool(
			billing_provider.call(
				"supports_product",
				product_id
			)
		)
	)


func is_iap_product_owned(product_id: String) -> bool:
	return product_id in billing_owned_product_ids


func refresh_iap_store_products() -> void:
	if is_instance_valid(billing_provider):
		billing_provider.call("refresh_products")


func purchase_iap(product_id: String) -> bool:
	if not is_instance_valid(billing_provider):
		return false
	if not secure_purchase_in_flight_product_id.is_empty():
		billing_purchase_state_changed.emit(
			product_id,
			"verification_in_progress",
			"Another purchase is still being verified."
		)
		return false
	var account_binding: String = (
		GoogleAccountManager.get_monetization_account_binding()
	)
	if account_binding.is_empty():
		GoogleAccountManager.ensure_monetization_identity()
		billing_purchase_state_changed.emit(
			product_id,
			"identity_preparing",
			"Preparing secure purchase identity. Please try again shortly."
		)
		return false
	_refresh_secure_purchase_context()
	if not secure_purchase_authority_ready:
		billing_purchase_state_changed.emit(
			product_id,
			"secure_verification_unavailable",
			"Secure purchase verification is not available yet."
		)
		return false
	return bool(billing_provider.call("purchase", product_id))


func restore_iap_purchases() -> void:
	if not is_instance_valid(billing_provider):
		return
	if not secure_purchase_in_flight_product_id.is_empty():
		secure_purchase_recovery_rescan_requested = true
		billing_purchase_state_changed.emit(
			"",
			"recovery_deferred",
			"Purchase recovery will continue after current verification."
		)
		return
	_refresh_secure_purchase_context()
	if not secure_purchase_authority_ready:
		billing_purchase_state_changed.emit(
			"",
			"secure_verification_unavailable",
			"Secure purchase recovery is not available yet."
		)
		return
	billing_provider.call("restore_purchases")



func _connect_secure_purchase_transport() -> bool:
	purchase_authority_bridge = null
	if OS.get_name() != "Android" or not Engine.has_singleton(PURCHASE_AUTHORITY_SINGLETON):
		return false
	var bridge: Object = Engine.get_singleton(PURCHASE_AUTHORITY_SINGLETON)
	if bridge == null:
		return false
	if (
		not bridge.has_method("authorizePaidWalletPurchaseV2")
		or not bridge.has_method("isPaidWalletPurchaseV2TransportConfigured")
		or not bridge.has_signal("paidPurchaseWalletCreditResult")
	):
		return false
	var callback := Callable(self, "_on_paid_purchase_wallet_credit_m14")
	if not bridge.is_connected("paidPurchaseWalletCreditResult", callback):
		bridge.connect("paidPurchaseWalletCreditResult", callback)
	purchase_authority_bridge = bridge
	return true

func _has_secure_purchase_transport() -> bool:
	return (
		purchase_authority_bridge != null
		and is_instance_valid(purchase_authority_bridge)
		and purchase_authority_bridge.has_method("authorizePaidWalletPurchaseV2")
		and purchase_authority_bridge.has_method("isPaidWalletPurchaseV2TransportConfigured")
		and purchase_authority_bridge.has_signal("paidPurchaseWalletCreditResult")
	)


func _is_secure_purchase_transport_configured() -> bool:
	if not _has_secure_purchase_transport():
		return false
	return bool(purchase_authority_bridge.call(
		"isPaidWalletPurchaseV2TransportConfigured"
	))


func _compute_secure_purchase_authority_ready(
	account_binding: String
) -> bool:
	return (
		SECURE_PURCHASE_ACTIVATION_APPROVED
		and not account_binding.is_empty()
		and _is_secure_purchase_transport_configured()
	)


func _connect_secure_purchase_identity() -> void:
	if GoogleAccountManager.has_signal("monetization_identity_changed"):
		var callback := Callable(self, "_on_monetization_identity_changed")
		if not GoogleAccountManager.is_connected(
			"monetization_identity_changed",
			callback
		):
			GoogleAccountManager.connect(
				"monetization_identity_changed",
				callback
			)
	GoogleAccountManager.ensure_monetization_identity()
	_refresh_secure_purchase_context()


func _on_monetization_identity_changed(_ready: bool) -> void:
	_invalidate_paid_entitlements_rc("identity_changed")
	_invalidate_paid_purchase_receipt_m14("identity_changed")
	_invalidate_paid_wallet_m9("identity_changed")
	_invalidate_paid_summon_recovery_m12("identity_changed")
	_refresh_secure_purchase_context()


func _refresh_secure_purchase_context() -> bool:
	secure_purchase_authority_ready = false
	if not is_instance_valid(billing_provider):
		return false
	if not billing_provider.has_method("configure_secure_purchase_context"):
		return false
	if not _has_secure_purchase_transport():
		_connect_secure_purchase_transport()
	var account_binding: String = (
		GoogleAccountManager.get_monetization_account_binding()
	)
	secure_purchase_authority_ready = (
		_compute_secure_purchase_authority_ready(account_binding)
	)
	var provider_ready: bool = bool(billing_provider.call(
		"configure_secure_purchase_context",
		account_binding,
		secure_purchase_authority_ready
	))
	if not provider_ready:
		secure_purchase_authority_ready = false
	return secure_purchase_authority_ready


func _activate_android_billing_provider() -> void:
	if OS.get_name() != "Android":
		return
	_attach_billing_provider(GooglePlayBillingProvider.new())


func _attach_billing_provider(next_provider: Node) -> void:
	if is_instance_valid(billing_provider):
		billing_provider.queue_free()
	billing_provider = next_provider
	billing_provider.connect(
		"store_products_updated",
		_on_billing_store_products_updated
	)
	billing_provider.connect(
		"purchase_ready",
		_on_billing_purchase_ready
	)
	billing_provider.connect(
		"purchase_state_changed",
		_on_billing_purchase_state_changed
	)
	billing_provider.connect(
		"entitlements_received",
		_on_billing_entitlements_received
	)
	add_child(billing_provider)
	call_deferred("_refresh_secure_purchase_context")


func _on_billing_store_products_updated(
	products: Dictionary
) -> void:
	billing_store_products = products.duplicate(true)
	store_products_updated.emit(
		billing_store_products.duplicate(true)
	)


func _on_billing_purchase_state_changed(
	product_id: String,
	status: String,
	message: String
) -> void:
	billing_purchase_state_changed.emit(
		product_id,
		status,
		message
	)


func _on_billing_entitlements_received(
	product_ids: Array[String]
) -> void:
	billing_owned_product_ids = product_ids.duplicate()
	billing_entitlements_changed.emit(
		billing_owned_product_ids.duplicate()
	)


func _on_billing_purchase_ready(
	product_id: String,
	_purchase_token: String,
	_order_id: String
) -> void:
	if not _has_secure_purchase_transport():
		_connect_secure_purchase_transport()
	if not secure_purchase_authority_ready or not _has_secure_purchase_transport():
		_fail_secure_purchase_delivery(
			product_id,
			"Secure purchase verification is not available yet."
		)
		return
	if not secure_purchase_in_flight_product_id.is_empty():
		secure_purchase_recovery_rescan_requested = true
		billing_purchase_state_changed.emit(
			product_id,
			"verification_deferred",
			"Purchase will be recovered after current verification."
		)
		return
	secure_purchase_in_flight_product_id = product_id
	_secure_purchase_in_flight_binding_m14 = GoogleAccountManager.get_monetization_account_binding()
	purchase_authority_bridge.call(
		"authorizePaidWalletPurchaseV2",
		_purchase_token
	)


## M14: legacy local-grant listener is NOT connected. If invoked directly,
## fail closed. No grant payload is ever allowed to mutate pavilion.save.
func _on_purchase_authority_result(_success: bool, _status: String, _grant_json: String) -> void:
	var product_id: String = secure_purchase_in_flight_product_id
	secure_purchase_in_flight_product_id = ""
	_secure_purchase_in_flight_binding_m14 = ""
	if not product_id.is_empty():
		_fail_secure_purchase_delivery(product_id, "Legacy local purchase grant is retired.")

func get_paid_purchase_receipt_m14() -> Dictionary:
	return _paid_purchase_receipt_m14.duplicate(true)

func _invalidate_paid_purchase_receipt_m14(reason: String = "identity_changed") -> void:
	_paid_purchase_receipt_m14 = HybridPaidPurchaseReceiptM14.empty(reason)
	paid_purchase_receipt_m14_changed.emit(get_paid_purchase_receipt_m14())

func _on_paid_purchase_wallet_credit_m14(success: bool, result_status: String, receipt_json: String) -> void:
	var product_id: String = secure_purchase_in_flight_product_id
	var expected_binding: String = _secure_purchase_in_flight_binding_m14
	secure_purchase_in_flight_product_id = ""
	_secure_purchase_in_flight_binding_m14 = ""
	if product_id.is_empty():
		return
	if expected_binding.is_empty() or GoogleAccountManager.get_monetization_account_binding() != expected_binding:
		_cancel_secure_purchase_recovery_rescan()
		_invalidate_paid_purchase_receipt_m14("identity_changed")
		_fail_secure_purchase_delivery(product_id, "Account changed during purchase verification.")
		return
	_paid_purchase_receipt_m14 = HybridPaidPurchaseReceiptM14.from_native_result(
		success, result_status, receipt_json
	)
	paid_purchase_receipt_m14_changed.emit(get_paid_purchase_receipt_m14())
	if _paid_purchase_receipt_m14.get("status", "") != "credited":
		_cancel_secure_purchase_recovery_rescan()
		_fail_secure_purchase_delivery(product_id, "Server wallet credit unavailable. Retry purchase recovery.")
		return
	last_error = ""
	billing_purchase_state_changed.emit(product_id, "wallet_credited", "Purchase credited to server wallet.")
	purchase_delivery_finished.emit(product_id, true, "Purchase credited to server wallet.")
	_continue_secure_purchase_recovery()


func _continue_secure_purchase_recovery() -> void:
	if not secure_purchase_recovery_rescan_requested:
		return
	secure_purchase_recovery_rescan_requested = false
	call_deferred("restore_iap_purchases")


func _cancel_secure_purchase_recovery_rescan() -> void:
	secure_purchase_recovery_rescan_requested = false


func _fail_secure_purchase_delivery(
	product_id: String,
	message: String
) -> void:
	last_error = message
	billing_purchase_state_changed.emit(
		product_id,
		"secure_verification_failed",
		message
	)
	purchase_delivery_finished.emit(
		product_id,
		false,
		message
	)


## Internal handoff target for M1B-2. Only a validated server grant may reach
## this function. Purchase token, order id, UID and client-claimed amount are
## intentionally absent from the API.
func _apply_server_authorized_iap_grant(_grant: Dictionary) -> bool:
	## Permanently retired. Local save grants are unsafe across two devices.
	last_error = "Legacy local purchase grant is retired."
	return false


func _connect_cadence_hooks() -> void:
	var daily_claimed := Callable(self, "_on_daily_quest_claimed")
	if DailyQuestManager.has_signal("daily_quest_claimed"):
		if not DailyQuestManager.is_connected("daily_quest_claimed", daily_claimed):
			DailyQuestManager.connect("daily_quest_claimed", daily_claimed)
	var stage_completed := Callable(self, "_on_stage_completed_for_cadence")
	if JourneyManager.has_signal("stage_completed"):
		if not JourneyManager.is_connected("stage_completed", stage_completed):
			JourneyManager.connect("stage_completed", stage_completed)


func _sync_economy_cadence() -> void:
	if SaveManager.is_progress_read_only():
		return
	_sync_daily_completion_bonus()
	_sync_progression_milestones()
	_sync_monthly_blessing_daily()


func _on_daily_quest_claimed(_quest_id: String, _spirit_stone_reward: int) -> void:
	call_deferred("_sync_daily_completion_bonus")


func _on_stage_completed_for_cadence(
	_chapter_id: int,
	_stage_id: int,
	_was_first_clear: bool
) -> void:
	# Victory owns the stage-clear transaction. Defer the Pavilion-only milestone
	# write so it never races the run-end batch.
	call_deferred("_sync_progression_milestones")


func _are_all_active_daily_quests_claimed() -> bool:
	var quest_ids: Array[String] = DailyQuestManager.get_daily_quest_ids()
	if quest_ids.is_empty():
		return false
	for quest_id: String in quest_ids:
		if not DailyQuestManager.is_claimed(quest_id):
			return false
	return true


func _sync_daily_completion_bonus() -> bool:
	if SaveManager.is_progress_read_only():
		return false
	DailyQuestManager.refresh_daily_date()
	if not _are_all_active_daily_quests_claimed():
		return false
	var date_key: String = str(DailyQuestManager.active_date_key)
	if date_key.is_empty():
		date_key = DailyQuestManager.get_current_date_key()
	var last_bonus_date: String = str(
		state.get("cadence_last_daily_bonus_date", "")
	)
	# DailyQuestManager already refuses backward date resets. Mirror that rule so
	# device-clock rollback cannot mint a second premium daily bonus.
	if not last_bonus_date.is_empty() and last_bonus_date >= date_key:
		return false
	var next_state: Dictionary = state.duplicate(true)
	var active_days: int = clampi(
		int(next_state.get("cadence_active_days", 0)) + 1,
		1,
		EconomyCatalog.ACTIVE_DAY_CYCLE_LENGTH
	)
	var jade_amount: int = EconomyCatalog.DAILY_COMPLETION_JADE
	var seal_amount: int = 0
	var cycle_completed: bool = active_days >= EconomyCatalog.ACTIVE_DAY_CYCLE_LENGTH
	if cycle_completed:
		jade_amount += EconomyCatalog.ACTIVE_DAY_CYCLE_BONUS_JADE
		seal_amount += EconomyCatalog.ACTIVE_DAY_CYCLE_BONUS_SEALS
		active_days = 0
		next_state["cadence_cycles_completed"] = (
			int(next_state.get("cadence_cycles_completed", 0)) + 1
		)
		next_state["rewarded_ads_claimed_in_cycle"] = 0
	next_state["cadence_active_days"] = active_days
	next_state["cadence_last_daily_bonus_date"] = date_key
	if not _commit_currency_grant(
		next_state,
		"cadence_daily:" + date_key,
		jade_amount,
		seal_amount
	):
		return false
	pavilion_changed.emit()
	DebugLogger.system(str(
		"Economy cadence daily granted: +", jade_amount,
		" Jade | +", seal_amount, " Seal | Active day progress ",
		active_days, "/", EconomyCatalog.ACTIVE_DAY_CYCLE_LENGTH
	))
	return true


func get_cadence_status() -> Dictionary:
	var active_days: int = clampi(
		int(state.get("cadence_active_days", 0)),
		0,
		EconomyCatalog.ACTIVE_DAY_CYCLE_LENGTH - 1
	)
	var ad_claimed: int = clampi(
		int(state.get("rewarded_ads_claimed_in_cycle", 0)),
		0,
		EconomyCatalog.REWARDED_AD_MAX_PER_CYCLE
	)
	return {
		"active_days": active_days,
		"cycle_length": EconomyCatalog.ACTIVE_DAY_CYCLE_LENGTH,
		"daily_jade": EconomyCatalog.DAILY_COMPLETION_JADE,
		"cycle_bonus_jade": EconomyCatalog.ACTIVE_DAY_CYCLE_BONUS_JADE,
		"cycle_bonus_seals": EconomyCatalog.ACTIVE_DAY_CYCLE_BONUS_SEALS,
		"cycles_completed": maxi(int(state.get("cadence_cycles_completed", 0)), 0),
		"last_daily_bonus_date": str(state.get("cadence_last_daily_bonus_date", "")),
		"rewarded_ads_claimed": ad_claimed,
		"rewarded_ads_remaining": maxi(EconomyCatalog.REWARDED_AD_MAX_PER_CYCLE - ad_claimed, 0),
		"rewarded_ad_seals": EconomyCatalog.REWARDED_AD_SEALS
	}


func get_rewarded_ad_claims_remaining() -> int:
	return int(get_cadence_status().get("rewarded_ads_remaining", 0))


## Trusted rewarded-ad boundary. No ad button calls this directly. A future ad
## provider must pass a unique verified completion id after playback completes.
func apply_verified_rewarded_ad_completion(provider_grant_id: String) -> bool:
	last_error = ""
	if get_rewarded_ad_claims_remaining() <= 0:
		last_error = "Rewarded Seal limit reached for this active-day cycle."
		return false
	var normalized_id: String = provider_grant_id.strip_edges()
	if normalized_id.is_empty():
		last_error = "Verified rewarded-ad grant id is required."
		return false
	var next_state: Dictionary = state.duplicate(true)
	next_state["rewarded_ads_claimed_in_cycle"] = (
		int(next_state.get("rewarded_ads_claimed_in_cycle", 0)) + 1
	)
	if not _commit_currency_grant(
		next_state,
		"rewarded_ad:" + normalized_id,
		0,
		EconomyCatalog.REWARDED_AD_SEALS
	):
		return false
	pavilion_changed.emit()
	return true


func _sync_progression_milestones() -> void:
	if SaveManager.is_progress_read_only():
		return
	var milestones: Dictionary = EconomyCatalog.get_progression_milestone_grants()
	var milestone_ids: Array[String] = []
	for raw_id in milestones.keys():
		milestone_ids.append(str(raw_id))
	milestone_ids.sort()
	for milestone_id: String in milestone_ids:
		var claimed: Array = _normalize_string_array(state.get("claimed_milestone_ids", []))
		if milestone_id in claimed:
			continue
		var milestone: Dictionary = milestones[milestone_id]
		var chapter_id: int = int(milestone.get("chapter_id", 0))
		var stage_id: int = int(milestone.get("stage_id", 0))
		if not JourneyManager.is_stage_cleared(chapter_id, stage_id):
			continue
		var next_state: Dictionary = state.duplicate(true)
		var next_claimed: Array = _normalize_string_array(
			next_state.get("claimed_milestone_ids", [])
		)
		next_claimed.append(milestone_id)
		next_state["claimed_milestone_ids"] = next_claimed
		var jade_amount: int = int(
			milestone.get(EconomyCatalog.CURRENCY_CELESTIAL_JADE, 0)
		)
		var seal_amount: int = int(
			milestone.get(EconomyCatalog.CURRENCY_PAVILION_SEAL, 0)
		)
		if not _commit_currency_grant(
			next_state,
			"milestone:" + milestone_id,
			jade_amount,
			seal_amount
		):
			return
		pavilion_changed.emit()
		DebugLogger.system(str(
			"Economy milestone granted: ", milestone_id,
			" | +", jade_amount, " Jade | +", seal_amount, " Seal"
		))


func is_monthly_blessing_active() -> bool:
	return (
		int(state.get("monthly_blessing_expires_unix", 0))
		> int(Time.get_unix_time_from_system())
	)


func get_monthly_blessing_status() -> Dictionary:
	return {
		"active": is_monthly_blessing_active(),
		"expires_unix": maxi(int(state.get("monthly_blessing_expires_unix", 0)), 0),
		"last_claim_date": str(state.get("monthly_blessing_last_claim_date", "")),
		"daily_claims_remaining": maxi(
			int(state.get("monthly_blessing_daily_claims_remaining", 0)),
			0
		),
		"daily_jade": EconomyCatalog.MONTHLY_BLESSING_DAILY_JADE,
		"purchase_count": maxi(int(state.get("monthly_blessing_purchase_count", 0)), 0)
	}


func _sync_monthly_blessing_daily() -> bool:
	if SaveManager.is_progress_read_only() or not is_monthly_blessing_active():
		return false
	if int(state.get("monthly_blessing_daily_claims_remaining", 0)) <= 0:
		return false
	var date_key: String = DailyQuestManager.get_current_date_key()
	var last_claim_date: String = str(
		state.get("monthly_blessing_last_claim_date", "")
	)
	if not last_claim_date.is_empty() and last_claim_date >= date_key:
		return false
	var next_state: Dictionary = state.duplicate(true)
	next_state["monthly_blessing_last_claim_date"] = date_key
	next_state["monthly_blessing_daily_claims_remaining"] = maxi(
		int(next_state.get("monthly_blessing_daily_claims_remaining", 0)) - 1,
		0
	)
	if not _commit_currency_grant(
		next_state,
		"monthly_blessing_daily:" + date_key,
		EconomyCatalog.MONTHLY_BLESSING_DAILY_JADE,
		0
	):
		return false
	pavilion_changed.emit()
	return true


func can_claim_meditation() -> bool:
	return (
		not SaveManager.is_progress_read_only()
		and str(state["meditation_date"]) < DailyQuestManager.get_current_date_key()
	)


func claim_meditation() -> bool:
	if not can_claim_meditation():
		return false
	var next_state: Dictionary = state.duplicate(true)
	next_state["meditation_date"] = DailyQuestManager.get_current_date_key()
	var result: Dictionary = RewardManager.grant_reward(
		RewardManager.SOURCE_PAVILION,
		"meditation_" + str(next_state["meditation_date"]),
		RewardManager.create_reward_data(MEDITATION_REWARD),
		{"pavilion": next_state}
	)
	if not bool(result.get("success", false)):
		last_error = "The reward could not be saved. Restart the game to recover."
		return false
	state = next_state
	pavilion_changed.emit()
	return true


func is_summon_unlocked() -> bool:
	return JourneyManager.is_stage_cleared(
		EconomyCatalog.SUMMON_UNLOCK_CHAPTER,
		EconomyCatalog.SUMMON_UNLOCK_STAGE
	)


func can_claim_starter_seals() -> bool:
	return (
		is_summon_unlocked()
		and not bool(state.get("starter_seals_claimed", false))
		and not SaveManager.is_progress_read_only()
	)


func has_claimed_starter_seals() -> bool:
	return bool(state.get("starter_seals_claimed", false))


func claim_starter_seals() -> bool:
	last_error = ""
	if not can_claim_starter_seals():
		return false
	var next_state: Dictionary = state.duplicate(true)
	next_state["pavilion_seals"] = (
		get_pavilion_seals() + EconomyCatalog.STARTER_SEAL_GRANT
	)
	next_state["starter_seals_claimed"] = true
	if not _commit_pavilion_state(next_state):
		return false
	pavilion_changed.emit()
	return true


func get_summon_cost(pull_count: int) -> Dictionary:
	return EconomyCatalog.get_summon_cost(pull_count)


func get_base_drop_rate_disclosure() -> Array[Dictionary]:
	return EconomyCatalog.get_drop_rate_disclosure()


func get_effective_drop_rate_disclosure() -> Array[Dictionary]:
	var rates: Dictionary = get_effective_drop_rates_basis_points()
	var entries: Array[Dictionary] = []
	for rarity: String in EconomyCatalog.RARITY_ORDER:
		var basis_points: int = int(rates.get(rarity, 0))
		entries.append({
			"rarity": rarity,
			"basis_points": basis_points,
			"percent": float(basis_points) / 100.0
		})
	return entries


func get_summon_pool_by_rarity() -> Dictionary:
	var pool: Dictionary = {
		"common": [],
		"rare": [],
		"epic": [],
		"legendary": []
	}
	for item_id: String in EquipmentManager.get_item_ids():
		if not is_item_unlocked(item_id):
			continue
		var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
		var rarity: String = str(item_data.get("rarity", "common"))
		if pool.has(rarity):
			pool[rarity].append(item_id)
	return pool


func has_active_legendary_pool() -> bool:
	var pool: Dictionary = get_summon_pool_by_rarity()
	return not (pool.get("legendary", []) as Array).is_empty()


func get_effective_drop_rates_basis_points() -> Dictionary:
	var pool: Dictionary = get_summon_pool_by_rarity()
	var rates: Dictionary = EconomyCatalog.get_base_drop_rates()
	for rarity_index: int in range(EconomyCatalog.RARITY_ORDER.size() - 1, -1, -1):
		var rarity: String = EconomyCatalog.RARITY_ORDER[rarity_index]
		var rarity_pool: Array = pool.get(rarity, [])
		if not rarity_pool.is_empty():
			continue
		var displaced: int = int(rates.get(rarity, 0))
		rates[rarity] = 0
		if displaced <= 0:
			continue
		var fallback: String = _find_nearest_available_rarity(pool, rarity_index)
		if not fallback.is_empty():
			rates[fallback] = int(rates.get(fallback, 0)) + displaced
	return rates


func _find_nearest_available_rarity(pool: Dictionary, from_index: int) -> String:
	for index: int in range(from_index - 1, -1, -1):
		var candidate: String = EconomyCatalog.RARITY_ORDER[index]
		if not (pool.get(candidate, []) as Array).is_empty():
			return candidate
	for index: int in range(from_index + 1, EconomyCatalog.RARITY_ORDER.size()):
		var higher_candidate: String = EconomyCatalog.RARITY_ORDER[index]
		if not (pool.get(higher_candidate, []) as Array).is_empty():
			return higher_candidate
	return ""


func get_summon_pity_status() -> Dictionary:
	var rare_limit: int = int(EconomyCatalog.PITY_LIMITS["rare_plus"])
	var epic_limit: int = int(EconomyCatalog.PITY_LIMITS["epic_plus"])
	var legendary_limit: int = int(EconomyCatalog.PITY_LIMITS["legendary"])
	var legendary_active: bool = has_active_legendary_pool()
	return {
		"rare_plus_counter": int(state.get("pity_rare_plus", 0)),
		"rare_plus_remaining": rare_limit - int(state.get("pity_rare_plus", 0)),
		"epic_plus_counter": int(state.get("pity_epic_plus", 0)),
		"epic_plus_remaining": epic_limit - int(state.get("pity_epic_plus", 0)),
		"legendary_counter": int(state.get("pity_legendary", 0)),
		"legendary_remaining": (
			legendary_limit - int(state.get("pity_legendary", 0))
			if legendary_active
			else -1
		),
		"legendary_active": legendary_active
	}


func get_wish_target_item_id() -> String:
	_sanitize_wish_target()
	return str(state.get("wish_item_id", ""))


func get_wish_target_options() -> Array[String]:
	var options: Array[String] = []
	var pool: Dictionary = get_summon_pool_by_rarity()
	for raw_item_id in pool.get("legendary", []):
		options.append(str(raw_item_id))
	options.sort()
	return options


func set_wish_target(item_id: String) -> bool:
	last_error = ""
	if SaveManager.is_progress_read_only():
		last_error = "Restart the game to recover a pending save."
		return false
	var normalized: String = item_id.strip_edges()
	if not normalized.is_empty() and normalized not in get_wish_target_options():
		last_error = "Wish target must be an unlocked Legendary equipment item."
		return false
	var next_state: Dictionary = state.duplicate(true)
	if normalized != str(next_state.get("wish_item_id", "")):
		# Fate belongs to one declared target. Changing/clearing the target cannot
		# carry a failed 50/50 guarantee onto another Legendary.
		next_state["wish_fate_guaranteed"] = false
	next_state["wish_item_id"] = normalized
	if not _commit_pavilion_state(next_state):
		return false
	pavilion_changed.emit()
	return true


func is_wish_fate_guaranteed() -> bool:
	return (
		not get_wish_target_item_id().is_empty()
		and bool(state.get("wish_fate_guaranteed", false))
	)


func _sanitize_wish_target() -> void:
	var wish_id: String = str(state.get("wish_item_id", ""))
	if wish_id.is_empty():
		state["wish_fate_guaranteed"] = false
		return
	if wish_id not in get_wish_target_options():
		state["wish_item_id"] = ""
		state["wish_fate_guaranteed"] = false


func can_summon(pull_count: int, payment_method: String = PAYMENT_AUTO) -> bool:
	last_error = ""
	if SaveManager.is_progress_read_only():
		last_error = "Restart the game to recover a pending save."
		return false
	if not is_summon_unlocked():
		last_error = "Clear Chapter 1-5 to open the Celestial Pavilion."
		return false
	if pull_count not in [EconomyCatalog.SINGLE_PULL_COUNT, EconomyCatalog.TEN_PULL_COUNT]:
		last_error = "Unsupported summon count."
		return false
	var pool: Dictionary = get_summon_pool_by_rarity()
	var has_any_item: bool = false
	for rarity: String in EconomyCatalog.RARITY_ORDER:
		if not (pool.get(rarity, []) as Array).is_empty():
			has_any_item = true
			break
	if not has_any_item:
		last_error = "No unlocked equipment is available in the Pavilion."
		return false
	var payment: Dictionary = _resolve_summon_payment(pull_count, payment_method)
	if payment.is_empty():
		last_error = "Not enough Pavilion Seals or Celestial Jade."
		return false
	return true


func summon_equipment(
	pull_count: int,
	payment_method: String = PAYMENT_AUTO
) -> Dictionary:
	last_error = ""
	if not can_summon(pull_count, payment_method):
		return _summon_failure(last_error)

	var payment: Dictionary = _resolve_summon_payment(pull_count, payment_method)
	var next_state: Dictionary = state.duplicate(true)
	if str(payment.get("method", "")) == PAYMENT_SEAL:
		next_state["pavilion_seals"] = get_pavilion_seals() - int(payment["amount"])
	else:
		next_state["celestial_jade"] = get_celestial_jade() - int(payment["amount"])

	var pool: Dictionary = get_summon_pool_by_rarity()
	var reward_counts: Dictionary = {}
	var pull_results: Array[Dictionary] = []
	for _pull_index: int in range(pull_count):
		var roll_result: Dictionary = _roll_rarity(next_state, pool)
		var rarity: String = str(roll_result.get("rarity", "common"))
		var hard_legendary_pity: bool = bool(roll_result.get("hard_legendary_pity", false))
		var wish_fate_before: bool = bool(
			next_state.get("wish_fate_guaranteed", false)
		)
		var item_id: String = _choose_item_for_rarity(
			rarity,
			pool,
			hard_legendary_pity,
			next_state
		)
		if item_id.is_empty():
			return _summon_failure("Summon pool resolution failed.")

		var wish_id: String = str(next_state.get("wish_item_id", ""))
		var wish_eligible: bool = (
			rarity == "legendary"
			and not wish_id.is_empty()
			and wish_id in (pool.get("legendary", []) as Array)
		)
		var wish_hit: bool = wish_eligible and item_id == wish_id
		var wish_fate_activated: bool = false
		var wish_fate_consumed: bool = false
		if wish_eligible:
			wish_fate_consumed = wish_fate_before and wish_hit
			wish_fate_activated = not wish_hit and not hard_legendary_pity
			next_state["wish_fate_guaranteed"] = not wish_hit

		var already_owned: bool = (
			InventoryManager.get_item_count(item_id)
			+ int(reward_counts.get(item_id, 0))
		) > 0
		var duplicate_shards: int = 0
		if already_owned:
			duplicate_shards = int(InventoryManager.DUPLICATE_SHARDS.get(rarity, 5))
		reward_counts[item_id] = int(reward_counts.get(item_id, 0)) + 1
		pull_results.append({
			"item_id": item_id,
			"rarity": rarity,
			"duplicate": already_owned,
			"duplicate_shards": duplicate_shards,
			"hard_legendary_pity": hard_legendary_pity,
			"wish_hit": wish_hit,
			"wish_fate_activated": wish_fate_activated,
			"wish_fate_consumed": wish_fate_consumed
		})
		_advance_pity(next_state, rarity, not (pool.get("legendary", []) as Array).is_empty())

	next_state["lifetime_pulls"] = int(next_state.get("lifetime_pulls", 0)) + pull_count
	var previous_counts: Dictionary = InventoryManager.item_counts.duplicate(true)
	var next_counts: Dictionary = InventoryManager.preview_add_items(reward_counts)
	var previous_shards: int = int(previous_counts.get(InventoryManager.REFINEMENT_SHARD, 0))
	var next_shards: int = int(next_counts.get(InventoryManager.REFINEMENT_SHARD, 0))

	var targets: Dictionary = {
		"pavilion": next_state,
		"inventory": {
			"version": InventoryManager.SAVE_VERSION,
			"item_counts": next_counts
		}
	}
	if not SaveManager.write_save_batch(targets):
		last_error = "Summon could not be committed. Restart the game to recover."
		return _summon_failure(last_error)

	state = next_state
	InventoryManager.item_counts = next_counts
	for raw_item_id in reward_counts.keys():
		var reward_item_id: String = str(raw_item_id)
		var previous_count: int = int(previous_counts.get(reward_item_id, 0))
		var next_count: int = int(next_counts.get(reward_item_id, 0))
		if previous_count != next_count:
			InventoryManager.inventory_changed.emit(reward_item_id, next_count)
		InventoryManager.item_added.emit(
			reward_item_id,
			int(reward_counts[reward_item_id]),
			next_count
		)
	if previous_shards != next_shards:
		InventoryManager.inventory_changed.emit(
			InventoryManager.REFINEMENT_SHARD,
			next_shards
		)

	AudioManager.play_sfx("claim")
	pavilion_changed.emit()
	var result: Dictionary = {
		"success": true,
		"pull_count": pull_count,
		"payment_method": str(payment.get("method", "")),
		"payment_amount": int(payment.get("amount", 0)),
		"results": pull_results,
		"refinement_shards_gained": maxi(next_shards - previous_shards, 0),
		"pity": get_summon_pity_status(),
		"economy": get_economy_summary()
	}
	summon_completed.emit(result.duplicate(true))
	return result


func _resolve_summon_payment(pull_count: int, payment_method: String) -> Dictionary:
	var cost: Dictionary = get_summon_cost(pull_count)
	if cost.is_empty():
		return {}
	var seal_cost: int = int(cost.get(EconomyCatalog.CURRENCY_PAVILION_SEAL, 0))
	var jade_cost: int = int(cost.get(EconomyCatalog.CURRENCY_CELESTIAL_JADE, 0))
	if payment_method in [PAYMENT_AUTO, PAYMENT_SEAL]:
		if get_pavilion_seals() >= seal_cost:
			return {"method": PAYMENT_SEAL, "amount": seal_cost}
		if payment_method == PAYMENT_SEAL:
			return {}
	if payment_method in [PAYMENT_AUTO, PAYMENT_JADE]:
		if get_celestial_jade() >= jade_cost:
			return {"method": PAYMENT_JADE, "amount": jade_cost}
	return {}


func _roll_rarity(next_state: Dictionary, pool: Dictionary) -> Dictionary:
	var legendary_active: bool = not (pool.get("legendary", []) as Array).is_empty()
	var legendary_limit: int = int(EconomyCatalog.PITY_LIMITS["legendary"])
	var epic_limit: int = int(EconomyCatalog.PITY_LIMITS["epic_plus"])
	var rare_limit: int = int(EconomyCatalog.PITY_LIMITS["rare_plus"])
	if (
		legendary_active
		and int(next_state.get("pity_legendary", 0)) >= legendary_limit - 1
	):
		return {"rarity": "legendary", "hard_legendary_pity": true}
	if (
		not (pool.get("epic", []) as Array).is_empty()
		and int(next_state.get("pity_epic_plus", 0)) >= epic_limit - 1
	):
		return {"rarity": "epic", "hard_legendary_pity": false}
	if (
		not (pool.get("rare", []) as Array).is_empty()
		and int(next_state.get("pity_rare_plus", 0)) >= rare_limit - 1
	):
		return {"rarity": "rare", "hard_legendary_pity": false}

	var rates: Dictionary = get_effective_drop_rates_basis_points()
	var roll: int = rng.randi_range(1, EconomyCatalog.RATE_BASIS_POINTS)
	var cumulative: int = 0
	for rarity: String in EconomyCatalog.RARITY_ORDER:
		cumulative += int(rates.get(rarity, 0))
		if roll <= cumulative:
			return {"rarity": rarity, "hard_legendary_pity": false}
	return {"rarity": "common", "hard_legendary_pity": false}


func _choose_item_for_rarity(
	rarity: String,
	pool: Dictionary,
	hard_legendary_pity: bool,
	next_state: Dictionary
) -> String:
	var options: Array = pool.get(rarity, [])
	if options.is_empty():
		return ""
	if rarity == "legendary":
		var wish_id: String = str(next_state.get("wish_item_id", ""))
		if not wish_id.is_empty() and wish_id in options:
			if (
				hard_legendary_pity
				or bool(next_state.get("wish_fate_guaranteed", false))
			):
				return wish_id
			if rng.randf() < EconomyCatalog.NATURAL_LEGENDARY_WISH_CHANCE:
				return wish_id
			var non_wish: Array = options.duplicate()
			non_wish.erase(wish_id)
			if not non_wish.is_empty():
				return str(non_wish[rng.randi_range(0, non_wish.size() - 1)])
	return str(options[rng.randi_range(0, options.size() - 1)])


func _advance_pity(
	next_state: Dictionary,
	rarity: String,
	legendary_active: bool
) -> void:
	var rank: int = EconomyCatalog.RARITY_ORDER.find(rarity)
	if rank >= EconomyCatalog.RARITY_ORDER.find("rare"):
		next_state["pity_rare_plus"] = 0
	else:
		next_state["pity_rare_plus"] = int(next_state.get("pity_rare_plus", 0)) + 1

	if rank >= EconomyCatalog.RARITY_ORDER.find("epic"):
		next_state["pity_epic_plus"] = 0
	else:
		next_state["pity_epic_plus"] = int(next_state.get("pity_epic_plus", 0)) + 1

	if legendary_active:
		if rank >= EconomyCatalog.RARITY_ORDER.find("legendary"):
			next_state["pity_legendary"] = 0
		else:
			next_state["pity_legendary"] = int(next_state.get("pity_legendary", 0)) + 1


func _summon_failure(reason: String) -> Dictionary:
	return {
		"success": false,
		"error": reason,
		"pity": get_summon_pity_status(),
		"economy": get_economy_summary()
	}


func _commit_pavilion_state(next_state: Dictionary) -> bool:
	next_state["version"] = 1
	var result: Dictionary = SaveManager.write_save_data("pavilion", next_state)
	if not bool(result.get("success", false)):
		last_error = "The Pavilion could not be saved. Restart the game to recover."
		return false
	state = next_state
	return true


func get_item_unlock_requirement(item_id: String) -> Dictionary:
	var item: Dictionary = EquipmentManager.get_item_data(item_id)
	if item.is_empty():
		return {}
	return {
		"chapter_id": maxi(int(item.get("requires_chapter", 1)), 0),
		"stage_id": maxi(int(item.get("requires_stage", 0)), 0)
	}


func is_item_unlocked(item_id: String) -> bool:
	var requirement := get_item_unlock_requirement(item_id)
	if requirement.is_empty():
		return false
	var required_chapter := int(requirement.get("chapter_id", 0))
	var required_stage := int(requirement.get("stage_id", 0))
	if required_chapter <= 0 or required_stage <= 0:
		return true
	return JourneyManager.is_stage_cleared(required_chapter, required_stage)


func can_buy_equipment_with_stones(item_id: String) -> bool:
	var item: Dictionary = EquipmentManager.get_item_data(item_id)
	if item.is_empty():
		return false
	return EconomyCatalog.can_direct_buy_rarity(str(item.get("rarity", "common")))


func get_equipment_forge_cost(item_id: String) -> int:
	var item: Dictionary = EquipmentManager.get_item_data(item_id)
	if item.is_empty():
		return 0
	return maxi(int(item.get("forge_cost", 0)), 0)


## Legacy deterministic forge remains unchanged in Foundation v2. The next
## Pavilion UI pass will route high-rarity acquisition through summon / shard
## forging together so no existing screen is left with misleading prices.
func acquire_equipment(item_id: String, use_shards: bool = false) -> bool:
	last_error = ""
	if SaveManager.is_progress_read_only():
		last_error = "Restart the game to recover a pending save."
		return false
	if not EquipmentManager.can_modify_equipment():
		last_error = "Finish or abandon the current run before forging equipment."
		return false
	if InventoryManager.owns_item(item_id) or not is_item_unlocked(item_id):
		return false
	var item: Dictionary = EquipmentManager.get_item_data(item_id)
	if not use_shards and not can_buy_equipment_with_stones(item_id):
		last_error = "Epic and Legendary equipment use Summon or Refinement Shard forging."
		return false
	var price: int = (
		get_equipment_forge_cost(item_id)
		if use_shards
		else int(item.get("price", 0))
	)
	var balance: int = (
		InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD)
		if use_shards
		else ProgressionManager.spirit_stone
	)
	if price <= 0 or balance < price:
		last_error = (
			"Insufficient Refinement Shards."
			if use_shards
			else "Insufficient Spirit Stones."
		)
		return false
	var progression_data: Dictionary = ProgressionManager.build_progression_save_data()
	var counts: Dictionary = InventoryManager.preview_add_items({item_id: 1})
	if use_shards:
		counts[InventoryManager.REFINEMENT_SHARD] = balance - price
	else:
		progression_data["spirit_stone"] = balance - price
	if not SaveManager.write_save_batch({
		"progression": progression_data,
		"inventory": {"version": 1, "item_counts": counts}
	}):
		last_error = "The exchange could not be saved. Restart the game to recover."
		return false
	ProgressionManager.apply_progression_save_data(progression_data)
	InventoryManager.item_counts = counts
	InventoryManager.inventory_changed.emit(item_id, 1)
	if use_shards:
		InventoryManager.inventory_changed.emit(
			InventoryManager.REFINEMENT_SHARD,
			balance - price
		)
	InventoryManager.item_added.emit(item_id, 1, 1)
	AudioManager.play_sfx("equip")
	pavilion_changed.emit()
	return true


func get_cosmetic_data(cosmetic_id: String) -> Dictionary:
	if not COSMETICS.has(cosmetic_id):
		return {}
	return COSMETICS[cosmetic_id].duplicate(true)


func is_cosmetic_owned(cosmetic_id: String) -> bool:
	if cosmetic_id == "plain":
		return true
	return cosmetic_id in state.get("owned_cosmetics", [])


func get_cosmetic_cost(cosmetic_id: String) -> Dictionary:
	var definition := get_cosmetic_data(cosmetic_id)
	if definition.is_empty():
		return {"spirit_stone": 0, "refinement_shard": 0}
	return {
		"spirit_stone": maxi(int(definition.get("stone_cost", 0)), 0),
		"refinement_shard": maxi(int(definition.get("shard_cost", 0)), 0)
	}


func is_cosmetic_stage_unlocked(cosmetic_id: String) -> bool:
	if not COSMETICS.has(cosmetic_id):
		return false
	var definition: Dictionary = COSMETICS[cosmetic_id]
	var required_chapter: int = maxi(int(definition.get("chapter", 1)), 0)
	var required_stage: int = maxi(int(definition.get("stage", 0)), 0)
	return (
		required_chapter <= 0
		or required_stage <= 0
		or JourneyManager.is_stage_cleared(required_chapter, required_stage)
	)


func is_cosmetic_unlocked(cosmetic_id: String) -> bool:
	if not is_cosmetic_stage_unlocked(cosmetic_id):
		return false
	var definition: Dictionary = COSMETICS[cosmetic_id]
	var required_cosmetic: String = str(definition.get("requires_cosmetic", ""))
	if not required_cosmetic.is_empty() and not is_cosmetic_owned(required_cosmetic):
		return false
	return true


func acquire_cosmetic(cosmetic_id: String) -> bool:
	last_error = ""
	if not COSMETICS.has(cosmetic_id):
		return false
	if SaveManager.is_progress_read_only():
		last_error = "Restart the game to recover a pending save."
		return false
	if is_cosmetic_owned(cosmetic_id):
		return select_cosmetic(cosmetic_id)
	if not is_cosmetic_unlocked(cosmetic_id):
		last_error = "Complete the required ascension path before attuning this aura."
		return false
	var cost: Dictionary = get_cosmetic_cost(cosmetic_id)
	var stone_cost: int = int(cost.get("spirit_stone", 0))
	var shard_cost: int = int(cost.get("refinement_shard", 0))
	if stone_cost <= 0 and shard_cost <= 0:
		return select_cosmetic(cosmetic_id)
	if ProgressionManager.spirit_stone < stone_cost:
		last_error = "Insufficient Spirit Stones."
		return false
	var shard_balance: int = InventoryManager.get_item_count(
		InventoryManager.REFINEMENT_SHARD
	)
	if shard_balance < shard_cost:
		last_error = "Insufficient Refinement Shards."
		return false
	var progression_data: Dictionary = ProgressionManager.build_progression_save_data()
	progression_data["spirit_stone"] = (
		int(progression_data.get("spirit_stone", 0)) - stone_cost
	)
	var counts: Dictionary = InventoryManager.preview_add_items({})
	if shard_cost > 0:
		var remaining_shards: int = shard_balance - shard_cost
		if remaining_shards > 0:
			counts[InventoryManager.REFINEMENT_SHARD] = remaining_shards
		else:
			counts.erase(InventoryManager.REFINEMENT_SHARD)
	var next_state: Dictionary = state.duplicate(true)
	if cosmetic_id not in next_state["owned_cosmetics"]:
		next_state["owned_cosmetics"].append(cosmetic_id)
	next_state["cosmetic_id"] = cosmetic_id
	if not SaveManager.write_save_batch({
		"progression": progression_data,
		"inventory": {"version": 1, "item_counts": counts},
		"pavilion": next_state
	}):
		last_error = "The exchange could not be saved. Restart the game to recover."
		return false
	ProgressionManager.apply_progression_save_data(progression_data)
	InventoryManager.item_counts = counts
	if shard_cost > 0:
		InventoryManager.inventory_changed.emit(
			InventoryManager.REFINEMENT_SHARD,
			maxi(shard_balance - shard_cost, 0)
		)
	state = next_state
	AudioManager.play_sfx("equip")
	pavilion_changed.emit()
	return true


func select_cosmetic(cosmetic_id: String) -> bool:
	last_error = ""
	if SaveManager.is_progress_read_only():
		last_error = "Restart the game to recover a pending save."
		return false
	if not is_cosmetic_unlocked(cosmetic_id):
		last_error = "Complete the required ascension path before attuning this aura."
		return false
	var cost: Dictionary = get_cosmetic_cost(cosmetic_id)
	var has_paid_cost: bool = (
		int(cost.get("spirit_stone", 0)) > 0
		or int(cost.get("refinement_shard", 0)) > 0
	)
	if not is_cosmetic_owned(cosmetic_id) and has_paid_cost:
		last_error = "Acquire this aura before attuning it."
		return false
	var next_state: Dictionary = state.duplicate(true)
	next_state["cosmetic_id"] = cosmetic_id
	if cosmetic_id not in next_state["owned_cosmetics"]:
		next_state["owned_cosmetics"].append(cosmetic_id)
	var result: Dictionary = SaveManager.write_save_data("pavilion", next_state)
	if not bool(result.get("success", false)):
		last_error = "The exchange could not be saved. Restart the game to recover."
		return false
	state = next_state
	pavilion_changed.emit()
	return true


func get_cosmetic_id() -> String:
	return str(state.get("cosmetic_id", "plain"))
