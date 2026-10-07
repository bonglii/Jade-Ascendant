extends Node

const EconomyCatalog = preload("res://scripts/data/economy_catalog.gd")
const BillingClientScript: Script = preload(
	"res://addons/GodotGooglePlayBilling/BillingClient.gd"
)

signal store_products_updated(products: Dictionary)
signal purchase_ready(product_id: String, purchase_token: String, order_id: String)
signal purchase_state_changed(product_id: String, status: String, message: String)
signal entitlements_received(product_ids: Array[String])

const PLUGIN_SINGLETON := "GodotGooglePlayBilling"
const RESPONSE_OK := 0
const RESPONSE_USER_CANCELED := 1
const PRODUCT_TYPE_INAPP := 0
const PURCHASED := 1
const PENDING := 2

const SECURE_CONSUMABLE_PRODUCT_IDS: Array = [
	"jade_pouch_100",
	"jade_satchel_550",
	"jade_casket_1200",
	"jade_vault_2500",
	"jade_treasury_6500",
	"jade_ascendant_14000",
]

# Canonical game IDs stay stable for economy, reward, UI, and save contracts.
# Five Google Play Console products use jade_pouch_* IDs, so translation happens
# only at this provider boundary.
const PLAY_PRODUCT_ID_BY_INTERNAL: Dictionary = {
	"jade_pouch_100": "jade_pouch_100",
	"jade_satchel_550": "jade_pouch_550",
	"jade_casket_1200": "jade_pouch_1200",
	"jade_vault_2500": "jade_pouch_2500",
	"jade_treasury_6500": "jade_pouch_6500",
	"jade_ascendant_14000": "jade_pouch_14000",
}
const INTERNAL_PRODUCT_ID_BY_PLAY: Dictionary = {
	"jade_pouch_100": "jade_pouch_100",
	"jade_pouch_550": "jade_satchel_550",
	"jade_pouch_1200": "jade_casket_1200",
	"jade_pouch_2500": "jade_vault_2500",
	"jade_pouch_6500": "jade_treasury_6500",
	"jade_pouch_14000": "jade_ascendant_14000",
}

var billing_client: Node
var state := "boot"
var store_products: Dictionary = {}
var active_product_id := ""
var restore_in_progress := false
var secure_account_binding: String = ""
var secure_authority_ready: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() != "Android":
		state = "not_android"
		call_deferred("_publish_catalog")
		return
	if not Engine.has_singleton(PLUGIN_SINGLETON):
		state = "native_plugin_missing"
		call_deferred("_publish_catalog")
		return
	billing_client = BillingClientScript.new() as Node
	if billing_client == null:
		state = "client_failed"
		return
	add_child(billing_client)
	_connect_signal("connected", _on_connected)
	_connect_signal("disconnected", _on_disconnected)
	_connect_signal("connect_error", _on_connect_error)
	_connect_signal("query_product_details_response", _on_product_details)
	_connect_signal("query_purchases_response", _on_query_purchases)
	_connect_signal("on_purchase_updated", _on_purchase_updated)
	state = "connecting"
	billing_client.call("start_connection")

func _exit_tree() -> void:
	if billing_client != null and is_instance_valid(billing_client):
		if billing_client.has_method("end_connection"):
			billing_client.call("end_connection")

func _connect_signal(
	signal_name: StringName,
	callback: Callable
) -> void:
	if (
		billing_client != null
		and billing_client.has_signal(signal_name)
	):
		if not billing_client.is_connected(signal_name, callback):
			billing_client.connect(signal_name, callback)

func supports_product(product_id: String) -> bool:
	if product_id not in SECURE_CONSUMABLE_PRODUCT_IDS:
		return false
	var product: Dictionary = EconomyCatalog.get_iap_product(product_id)
	if product.is_empty():
		return false
	return (
		str(product.get("type", ""))
		== EconomyCatalog.PRODUCT_TYPE_CONSUMABLE
	)


func configure_secure_purchase_context(
	account_binding: String,
	authority_ready: bool
) -> bool:
	var normalized: String = account_binding.strip_edges().to_lower()
	secure_account_binding = normalized if _is_sha256_hex(normalized) else ""
	secure_authority_ready = (
		authority_ready and not secure_account_binding.is_empty()
	)
	if (
		not secure_account_binding.is_empty()
		and billing_client != null
		and is_instance_valid(billing_client)
		and billing_client.has_method("set_obfuscated_account_id")
	):
		billing_client.call(
			"set_obfuscated_account_id",
			secure_account_binding
		)
	if secure_authority_ready and _client_ready():
		call_deferred("restore_purchases")
	return secure_authority_ready


func _is_sha256_hex(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _to_play_product_id(product_id: String) -> String:
	return str(
		PLAY_PRODUCT_ID_BY_INTERNAL.get(product_id, product_id)
	)


func _to_internal_product_id(product_id: String) -> String:
	return str(
		INTERNAL_PRODUCT_ID_BY_PLAY.get(product_id, product_id)
	)


func _supported_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for product_id: String in EconomyCatalog.get_iap_products().keys():
		if not supports_product(product_id):
			continue
		var play_product_id := _to_play_product_id(product_id)
		if play_product_id.is_empty() or ids.has(play_product_id):
			continue
		ids.append(play_product_id)
	ids.sort()
	return ids

func _on_connected() -> void:
	state = "connected"
	refresh_products()
	if secure_authority_ready:
		restore_purchases()

func _on_disconnected() -> void:
	state = "disconnected"
	_publish_catalog()

func _on_connect_error(_code: int, _message: String) -> void:
	state = "connect_error"
	_publish_catalog()

func _client_ready() -> bool:
	return (
		billing_client != null
		and is_instance_valid(billing_client)
		and bool(billing_client.call("is_ready"))
	)

func refresh_products() -> void:
	if not _client_ready():
		_publish_catalog()
		return
	var ids := _supported_ids()
	if ids.is_empty():
		_publish_catalog()
		return
	state = "querying_products"
	billing_client.call("query_product_details", ids, PRODUCT_TYPE_INAPP)

func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -999)) != RESPONSE_OK:
		state = "product_query_failed"
		_publish_catalog()
		return
	var next_products: Dictionary = {}
	var details: Variant = response.get("product_details", [])
	if details is Array:
		for raw: Variant in details:
			if raw is Dictionary:
				var item := _normalize_product(raw as Dictionary)
				if not item.is_empty():
					next_products[str(item["product_id"])] = item
	store_products = next_products
	state = "ready"
	_publish_catalog()

func _optional_string(value: Variant) -> String:
	if value == null:
		return ""
	return str(value)


func _normalize_product(detail: Dictionary) -> Dictionary:
	var play_product_id := str(detail.get("product_id", ""))
	var product_id := _to_internal_product_id(play_product_id)
	if not supports_product(product_id):
		return {}
	var offers: Variant = detail.get(
		"one_time_purchase_offer_details_list",
		[]
	)
	if not offers is Array or (offers as Array).is_empty():
		return {}
	var first: Variant = (offers as Array)[0]
	if not first is Dictionary:
		return {}
	var offer := first as Dictionary
	return {
		"product_id": product_id,
		"play_product_id": play_product_id,
		"title": str(detail.get("title", product_id)),
		"description": str(detail.get("description", "")),
		"formatted_price": str(offer.get("formatted_price", "")),
		"price_currency_code": str(offer.get("price_currency_code", "")),
		"price_amount_micros": int(offer.get("price_amount_micros", 0)),
		"purchase_option_id": _optional_string(
			offer.get("purchase_option_id", null)
		),
		"offer_id": _optional_string(
			offer.get("offer_id", null)
		),
		"offer_token": _optional_string(
			offer.get("offer_token", null)
		),
	}

func _publish_catalog() -> void:
	store_products_updated.emit(store_products.duplicate(true))

func get_store_products() -> Dictionary:
	return store_products.duplicate(true)

func purchase(product_id: String) -> bool:
	if not supports_product(product_id):
		purchase_state_changed.emit(
			product_id,
			"unsupported",
			"Product is not enabled yet."
		)
		return false
	if not secure_authority_ready:
		purchase_state_changed.emit(
			product_id,
			"secure_verification_unavailable",
			"Secure purchase verification is not available yet."
		)
		return false
	if not _is_sha256_hex(secure_account_binding):
		purchase_state_changed.emit(
			product_id,
			"identity_unavailable",
			"Secure purchase identity is not ready."
		)
		return false
	if not _client_ready():
		purchase_state_changed.emit(
			product_id,
			"unavailable",
			"Google Play Billing is not ready."
		)
		return false
	if not store_products.has(product_id):
		purchase_state_changed.emit(
			product_id,
			"price_unavailable",
			"Play Store price is not available yet."
		)
		refresh_products()
		return false
	var detail: Dictionary = store_products[product_id]
	var play_product_id := str(
		detail.get(
			"play_product_id",
			_to_play_product_id(product_id)
		)
	)
	active_product_id = product_id
	purchase_state_changed.emit(
		product_id,
		"opening",
		"Opening Google Play purchase..."
	)
	billing_client.call(
		"set_obfuscated_account_id",
		secure_account_binding
	)
	var raw: Variant = billing_client.call(
		"purchase",
		play_product_id,
		str(detail.get("purchase_option_id", "")),
		str(detail.get("offer_id", "")),
		false
	)
	if not raw is Dictionary:
		active_product_id = ""
		purchase_state_changed.emit(
			product_id,
			"launch_failed",
			"Could not open Google Play purchase."
		)
		return false
	var result := raw as Dictionary
	if int(result.get("response_code", -999)) != RESPONSE_OK:
		active_product_id = ""
		purchase_state_changed.emit(
			product_id,
			"launch_failed",
			str(result.get(
				"debug_message",
				"Google Play purchase failed."
			))
		)
		return false
	return true

func _on_purchase_updated(response: Dictionary) -> void:
	var code := int(response.get("response_code", -999))
	if code == RESPONSE_USER_CANCELED:
		purchase_state_changed.emit(
			active_product_id,
			"cancelled",
			"Purchase cancelled."
		)
		active_product_id = ""
		return
	if code != RESPONSE_OK:
		purchase_state_changed.emit(
			active_product_id,
			"failed",
			str(response.get(
				"debug_message",
				"Google Play purchase failed."
			))
		)
		active_product_id = ""
		return
	var purchases: Variant = response.get("purchases", [])
	if purchases is Array:
		for raw: Variant in purchases:
			if raw is Dictionary:
				_process_purchase(raw as Dictionary)
	active_product_id = ""

func restore_purchases() -> void:
	if not _client_ready():
		var empty: Array[String] = []
		entitlements_received.emit(empty)
		return
	restore_in_progress = true
	state = "restoring_purchases"
	billing_client.call("query_purchases", PRODUCT_TYPE_INAPP)

func _on_query_purchases(response: Dictionary) -> void:
	var owned: Array[String] = []
	if int(response.get("response_code", -999)) == RESPONSE_OK:
		var purchases: Variant = response.get("purchases", [])
		if purchases is Array:
			for raw: Variant in purchases:
				if not raw is Dictionary:
					continue
				var purchase_data := raw as Dictionary
				for product_id: String in _product_ids(purchase_data):
					if product_id not in owned:
						owned.append(product_id)
				_process_purchase(purchase_data)
	state = (
		"ready"
		if not store_products.is_empty()
		else "connected"
	)
	restore_in_progress = false
	entitlements_received.emit(owned)

func _product_ids(purchase_data: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var raw_ids: Variant = purchase_data.get("product_ids", [])
	if raw_ids is Array or raw_ids is PackedStringArray:
		for raw: Variant in raw_ids:
			var play_product_id := str(raw)
			var product_id := _to_internal_product_id(
				play_product_id
			)
			if (
				not product_id.is_empty()
				and product_id not in ids
			):
				ids.append(product_id)
	return ids

func _process_purchase(purchase_data: Dictionary) -> void:
	var purchase_state := int(
		purchase_data.get("purchase_state", 0)
	)
	for product_id: String in _product_ids(purchase_data):
		if not supports_product(product_id):
			continue
		if purchase_state == PENDING:
			purchase_state_changed.emit(
				product_id,
				"pending",
				"Purchase is pending in Google Play."
			)
			continue
		if purchase_state != PURCHASED:
			continue
		var token := str(
			purchase_data.get("purchase_token", "")
		).strip_edges()
		if token.is_empty():
			purchase_state_changed.emit(
				product_id,
				"invalid",
				"Google Play returned an empty purchase token."
			)
			continue
		purchase_state_changed.emit(
			product_id,
			"verification_required",
			"Purchase received. Waiting for secure server verification..."
		)
		purchase_ready.emit(
			product_id,
			token,
			str(purchase_data.get("order_id", ""))
		)

func get_runtime_status() -> Dictionary:
	var runtime_ready: bool = (
		_client_ready()
		and secure_authority_ready
		and _is_sha256_hex(secure_account_binding)
	)
	var runtime_state: String = state
	if _client_ready() and not secure_authority_ready:
		runtime_state = "secure_verification_unavailable"
	elif _client_ready() and secure_account_binding.is_empty():
		runtime_state = "identity_unavailable"
	return {
		"provider": "google_play_billing",
		"state": runtime_state,
		"ready": runtime_ready,
		"billing_client_ready": _client_ready(),
		"secure_authority_ready": secure_authority_ready,
		"account_binding_ready": _is_sha256_hex(secure_account_binding),
		"client_finalization_enabled": false,
		"products_loaded": not store_products.is_empty(),
		"product_count": store_products.size(),
		"restore_in_progress": restore_in_progress,
		"plugin_singleton": Engine.has_singleton(
			PLUGIN_SINGLETON
		),
	}
