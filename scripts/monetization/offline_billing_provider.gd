extends Node

signal store_products_updated(products: Dictionary)
@warning_ignore("unused_signal")
signal purchase_ready(product_id: String, purchase_token: String, order_id: String)
signal purchase_state_changed(product_id: String, status: String, message: String)
signal entitlements_received(product_ids: Array[String])

func _ready() -> void:
	call_deferred("_publish_empty")

func _publish_empty() -> void:
	store_products_updated.emit({})

func supports_product(_product_id: String) -> bool:
	return false

func refresh_products() -> void:
	store_products_updated.emit({})

func get_store_products() -> Dictionary:
	return {}

func purchase(product_id: String) -> bool:
	purchase_state_changed.emit(
		product_id,
		"unavailable",
		"Google Play Billing is unavailable."
	)
	return false

func restore_purchases() -> void:
	var empty: Array[String] = []
	entitlements_received.emit(empty)

func finalize_purchase(
	_product_id: String,
	_purchase_token: String,
	_grant_accepted: bool
) -> void:
	pass

func get_runtime_status() -> Dictionary:
	return {
		"provider": "offline_billing",
		"state": "unavailable",
		"ready": false,
		"products_loaded": false,
		"product_count": 0,
	}
