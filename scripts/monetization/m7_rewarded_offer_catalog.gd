extends RefCounted
class_name M7RewardedOfferCatalog

## M7A additive, read-only catalog. No reward grants, provider changes, or saves.
## Existing placements are live. Future offers are NEVER dispatchable in M7A.
## The following policy is a design target, not an active daily cap.
const GLOBAL_OPTIONAL_AD_DAILY_CAP_TARGET: int = 5

const SHIPPING_PLACEMENTS: Dictionary = {
	"game_over_revive": {
		"owner": "GameOverManager",
		"kind": "revive",
		"limit_owner": "one_per_run"
	},
	"offline_cultivation_double": {
		"owner": "IdleCultivationManager",
		"kind": "claim_multiplier",
		"limit_owner": "MonetizationManager"
	},
	"pavilion_seal": {
		"owner": "PavilionManager",
		"kind": "seal",
		"limit_owner": "MonetizationManager+PavilionManager"
	},
	"liveops_boss_hunt_double": {
		"owner": "LiveOpsManager",
		"kind": "event_claim_multiplier",
		"limit_owner": "MonetizationManager+LiveOpsManager"
	},
	"liveops_treasure_hunt_double": {
		"owner": "LiveOpsManager",
		"kind": "event_claim_multiplier",
		"limit_owner": "MonetizationManager+LiveOpsManager"
	}
}

const PLANNED_DISABLED_PLACEMENTS: Dictionary = {
	"daily_completion_cache": {
		"kind": "spirit_stone",
		"amount": 50,
		"daily_limit": 1,
		"requires": "all_active_daily_quests_claimed"
	},
	"refinement_supply": {
		"kind": "refinement_shard",
		"amount": 2,
		"daily_limit": 1,
		"requires": "verified_grant_and_inventory_save"
	},
	"victory_encore": {
		"kind": "repeat_stage_spirit_stone_bonus",
		"bonus_percent": 50,
		"maximum_bonus": 100,
		"daily_limit": 1,
		"requires": "snapshotted_repeat_clear"
	},
	"qi_focus": {
		"kind": "next_run_exp_bonus",
		"bonus_percent": 10,
		"daily_limit": 1,
		"requires": "single_use_run_bound_token"
	},
	"dao_choice_reroll": {
		"kind": "in_run_upgrade_reroll",
		"uses_per_run": 1,
		"daily_limit": 1,
		"requires": "pending_unselected_upgrade_choices"
	}
}


static func is_shipping_placement(placement: String) -> bool:
	return SHIPPING_PLACEMENTS.has(placement)


static func is_registered_placement(placement: String) -> bool:
	return SHIPPING_PLACEMENTS.has(placement) or PLANNED_DISABLED_PLACEMENTS.has(placement)


static func is_future_offer_enabled(_placement: String) -> bool:
	# Fail closed until owner-specific grant, replay protection, limits, and QA exist.
	return false


static func get_shipping_offer(placement: String) -> Dictionary:
	var data: Dictionary = SHIPPING_PLACEMENTS.get(placement, {})
	return data.duplicate(true)


static func get_planned_offer(placement: String) -> Dictionary:
	var data: Dictionary = PLANNED_DISABLED_PLACEMENTS.get(placement, {})
	return data.duplicate(true)


static func get_registered_placements() -> Array[String]:
	var ids: Array[String] = []
	for raw_id: String in SHIPPING_PLACEMENTS.keys():
		ids.append(raw_id)
	for raw_id: String in PLANNED_DISABLED_PLACEMENTS.keys():
		ids.append(raw_id)
	ids.sort()
	return ids
