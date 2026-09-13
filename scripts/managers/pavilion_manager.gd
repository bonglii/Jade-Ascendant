extends Node

## v1 offline Pavilion. Earned currency only; no real-money SDK or entitlement
## is simulated. Prices and unlock requirements belong to the equipment catalog.
signal pavilion_changed
var state: Dictionary = {"version": 1, "meditation_date": "", "cosmetic_id": "plain", "owned_cosmetics": ["plain"]}
var last_error: String = ""
const MEDITATION_REWARD: int = 20
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

func _ready() -> void:
	var result: Dictionary = SaveManager.read_save_data("pavilion")
	if bool(result.get("success", false)):
		var data: Dictionary = result.get("data", {})
		state["meditation_date"] = str(data.get("meditation_date", ""))
		var cosmetic_id: String = str(data.get("cosmetic_id", "plain"))
		state["cosmetic_id"] = cosmetic_id if COSMETICS.has(cosmetic_id) else "plain"
		var owned: Variant = data.get("owned_cosmetics", ["plain"])
		if owned is Array:
			var normalized_owned: Array = []
			for raw_id in owned:
				var owned_id: String = str(raw_id)
				if COSMETICS.has(owned_id) and owned_id not in normalized_owned:
					normalized_owned.append(owned_id)
			if "plain" not in normalized_owned:
				normalized_owned.append("plain")
			state["owned_cosmetics"] = normalized_owned
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
	elif not bool(result.get("exists", false)):
		SaveManager.write_save_data("pavilion", state)

func can_claim_meditation() -> bool:
	return not SaveManager.is_progress_read_only() and str(state["meditation_date"]) < DailyQuestManager.get_current_date_key()

func claim_meditation() -> bool:
	if not can_claim_meditation():
		return false
	var next_state: Dictionary = state.duplicate(true)
	next_state["meditation_date"] = DailyQuestManager.get_current_date_key()
	var result: Dictionary = RewardManager.grant_reward(RewardManager.SOURCE_PAVILION,
		"meditation_" + str(next_state["meditation_date"]), RewardManager.create_reward_data(MEDITATION_REWARD), {"pavilion": next_state})
	if not bool(result.get("success", false)):
		last_error = "The reward could not be saved. Restart the game to recover."
		return false
	state = next_state
	pavilion_changed.emit()
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
	var price: int = int(item.get("forge_cost" if use_shards else "price", 0))
	var balance: int = InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD) if use_shards else ProgressionManager.spirit_stone
	if price <= 0 or balance < price:
		last_error = "Insufficient Refinement Shards." if use_shards else "Insufficient Spirit Stones."
		return false
	var progression_data: Dictionary = ProgressionManager.build_progression_save_data()
	var counts: Dictionary = InventoryManager.preview_add_items({item_id: 1})
	if use_shards:
		counts[InventoryManager.REFINEMENT_SHARD] = balance - price
	else:
		progression_data["spirit_stone"] = balance - price
	if not SaveManager.write_save_batch({"progression": progression_data, "inventory": {"version": 1, "item_counts": counts}}):
		last_error = "The exchange could not be saved. Restart the game to recover."
		return false
	ProgressionManager.apply_progression_save_data(progression_data)
	InventoryManager.item_counts = counts
	InventoryManager.inventory_changed.emit(item_id, 1)
	if use_shards:
		InventoryManager.inventory_changed.emit(InventoryManager.REFINEMENT_SHARD, balance - price)
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
	var shard_balance: int = InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD)
	if shard_balance < shard_cost:
		last_error = "Insufficient Refinement Shards."
		return false
	var progression_data: Dictionary = ProgressionManager.build_progression_save_data()
	progression_data["spirit_stone"] = int(progression_data.get("spirit_stone", 0)) - stone_cost
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
		InventoryManager.inventory_changed.emit(InventoryManager.REFINEMENT_SHARD, maxi(shard_balance - shard_cost, 0))
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
	var has_paid_cost: bool = int(cost.get("spirit_stone", 0)) > 0 or int(cost.get("refinement_shard", 0)) > 0
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
