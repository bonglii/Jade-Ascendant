extends RefCounted
class_name M7RewardedOfferGateway

## M7A opt-in wrapper for FUTURE UI routes. No existing call sites are changed.
## Never forward a planned-but-disabled or unknown placement to the SDK.
const Catalog = preload("res://scripts/monetization/m7_rewarded_offer_catalog.gd")


static func can_request(placement: String) -> bool:
	if not Catalog.is_shipping_placement(placement):
		return false
	return MonetizationManager.rewarded_available(placement)


static func request(placement: String) -> bool:
	if not Catalog.is_shipping_placement(placement):
		return false
	return MonetizationManager.show_rewarded(placement)


static func get_policy_status(placement: String) -> Dictionary:
	if not Catalog.is_shipping_placement(placement):
		return {
			"available": false,
			"placement_claims": 0,
			"daily_limit": 0,
			"cooldown_remaining_seconds": 0,
			"provider_ready": false
		}
	return MonetizationManager.get_rewarded_policy_status(placement)
