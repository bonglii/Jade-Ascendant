extends Node

## Domain bridge between verified rewarded-ad completions and Pavilion economy.
## Providers never write currency directly. Only PavilionManager owns the wallet.
const EconomyCatalog = preload("res://scripts/data/economy_catalog.gd")

const PLACEMENT_ID: String = "pavilion_seal"


func _ready() -> void:
	var manager: Variant = get_parent()
	if not manager.verified_rewarded_completed.is_connected(
		_on_verified_rewarded_completed
	):
		manager.verified_rewarded_completed.connect(
			_on_verified_rewarded_completed
		)


func _on_verified_rewarded_completed(
	placement: String,
	grant_id: String
) -> void:
	if placement != PLACEMENT_ID:
		return

	var manager: Variant = get_parent()
	var granted: bool = PavilionManager.apply_verified_rewarded_ad_completion(
		grant_id
	)
	var amount: int = EconomyCatalog.REWARDED_AD_SEALS if granted else 0
	var message: String = "" if granted else PavilionManager.last_error

	manager.call(
		"publish_reward_delivery_result",
		placement,
		granted,
		amount,
		message
	)

	if not granted:
		push_error(
			"Pavilion rewarded-ad grant gagal: " + PavilionManager.last_error
		)
