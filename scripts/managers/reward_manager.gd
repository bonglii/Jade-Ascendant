extends Node

## Reward Manager
## Memvalidasi dan menyalurkan reward ke manager pemilik data.
## Spirit Stone tetap dimiliki ProgressionManager.
## Ownership/count item tetap dimiliki InventoryManager.
## RewardManager tidak memiliki save file sendiri.

signal reward_granted(
	source_type: String,
	source_id: String,
	reward_data: Dictionary
)
signal reward_rejected(
	source_type: String,
	source_id: String,
	reason: String
)

const REWARD_KEY_SPIRIT_STONE: String = "spirit_stone"
const REWARD_KEY_ITEMS: String = "items"

const SOURCE_STAGE_CLEAR: String = "stage_clear"
const SOURCE_BOSS_DEFEAT: String = "boss_defeat"
const SOURCE_GAME_OVER: String = "game_over"
const SOURCE_ACHIEVEMENT: String = "achievement"
const SOURCE_DAILY_QUEST: String = "daily_quest"
const SOURCE_PAVILION: String = "pavilion"

const CLEAR_TYPE_FIRST: String = "first_clear"
const CLEAR_TYPE_REPEAT: String = "repeat_clear"
const ChapterOneCatalog = preload("res://scripts/data/chapter_one_catalog.gd")
const ChapterTwoCatalog = preload("res://scripts/data/chapter_two_catalog.gd")
const ChapterThreeCatalog = preload("res://scripts/data/chapter_three_catalog.gd")

## Nilai first/repeat clear sengaja tetap mengikuti baseline lama.
## Nominal dapat dibedakan nanti tanpa mengubah flow VictoryManager.
const DEFAULT_STAGE_CLEAR_REWARDS: Dictionary = {
	"first_clear": {
		"spirit_stone": 100,
		"items": {}
	},
	"repeat_clear": {
		"spirit_stone": 100,
		"items": {}
	}
}

## Equipment is available outside Stage Clear progression. Chapter stages award
## economy currency only; they must never inject equipment copies into Inventory.
const STAGE_CLEAR_REWARD_CATALOG: Dictionary = {
	"1-1": {
		"first_clear": {
			"spirit_stone": 100,
			"items": {}
		},
		"repeat_clear": {
			"spirit_stone": 100,
			"items": {}
		}
	}
}

## Boss source is registered for exact-once routing, but has no separate item
## payload. Stage completion owns each Chapter clear reward.
const BOSS_REWARD_CATALOG: Dictionary = {
	"boss_1": {
		"spirit_stone": 0,
		"items": {}
	}
}

const GAME_OVER_TIER_NONE: String = "no_reward"
const GAME_OVER_REWARD_TIERS: Array = [
	{
		"id": "early_failure",
		"min_wave": 2,
		"max_wave": 3,
		"spirit_stone": 10
	},
	{
		"id": "mid_failure",
		"min_wave": 4,
		"max_wave": 6,
		"spirit_stone": 20
	},
	{
		"id": "late_failure",
		"min_wave": 7,
		"max_wave": 10,
		"spirit_stone": 30
	}
]

var last_grant_result: Dictionary = {}

func _ready() -> void:
	DebugLogger.system(str("RewardManager aktif!"))

func get_source_type_ids() -> Array[String]:
	return [
		SOURCE_STAGE_CLEAR,
		SOURCE_BOSS_DEFEAT,
		SOURCE_GAME_OVER,
		SOURCE_ACHIEVEMENT,
		SOURCE_DAILY_QUEST,
		SOURCE_PAVILION
	]

func is_valid_source_type(source_type: String) -> bool:
	return source_type in get_source_type_ids()

func get_stage_reward_key(chapter_id: int, stage_id: int) -> String:
	return "%d-%d" % [chapter_id, stage_id]

func get_stage_clear_type(was_first_clear: bool) -> String:
	if was_first_clear:
		return CLEAR_TYPE_FIRST
	return CLEAR_TYPE_REPEAT

func has_stage_clear_reward_definition(
	chapter_id: int,
	stage_id: int
) -> bool:
	return (
		STAGE_CLEAR_REWARD_CATALOG.has(
			get_stage_reward_key(
				chapter_id,
				stage_id
			)
		)
		or (
			chapter_id == 1
			and ChapterOneCatalog.STAGES.has(stage_id)
		)
		or (
			chapter_id == 2
			and ChapterTwoCatalog.STAGES.has(stage_id)
		)
		or (
			chapter_id == 3
			and ChapterThreeCatalog.STAGES.has(stage_id)
		)
	)

func get_default_stage_clear_reward(
	was_first_clear: bool
) -> Dictionary:
	var clear_type := get_stage_clear_type(was_first_clear)
	var reward_data: Dictionary = DEFAULT_STAGE_CLEAR_REWARDS.get(
		clear_type,
		{}
	)
	return reward_data.duplicate(true)

func get_stage_clear_reward(
	chapter_id: int,
	stage_id: int,
	was_first_clear: bool
) -> Dictionary:
	var stage_key := get_stage_reward_key(chapter_id, stage_id)
	# Chapter catalogs are the source of truth for implemented stages. Keep the
	# legacy stage reward table only as a fallback for non-catalog content.
	if (
		chapter_id == 1
		and ChapterOneCatalog.STAGES.has(stage_id)
	):
		return _get_catalog_stage_clear_reward(
			ChapterOneCatalog.get_stage(stage_id),
			was_first_clear
		)
	elif (
		chapter_id == 2
		and ChapterTwoCatalog.STAGES.has(stage_id)
	):
		return _get_catalog_stage_clear_reward(
			ChapterTwoCatalog.get_stage(stage_id),
			was_first_clear
		)
	elif (
		chapter_id == 3
		and ChapterThreeCatalog.STAGES.has(stage_id)
	):
		return _get_catalog_stage_clear_reward(
			ChapterThreeCatalog.get_stage(stage_id),
			was_first_clear
		)
	var stage_rewards: Dictionary = DEFAULT_STAGE_CLEAR_REWARDS
	if STAGE_CLEAR_REWARD_CATALOG.has(stage_key):
		stage_rewards = STAGE_CLEAR_REWARD_CATALOG.get(
			stage_key,
			DEFAULT_STAGE_CLEAR_REWARDS
		)
	var clear_type := get_stage_clear_type(was_first_clear)
	var reward_data: Dictionary = stage_rewards.get(clear_type, {})
	return reward_data.duplicate(true)

func _get_catalog_stage_clear_reward(
	stage_data: Dictionary,
	was_first_clear: bool
) -> Dictionary:
	var reward_key: String = (
		"first_clear_stones"
		if was_first_clear
		else "repeat_clear_stones"
	)
	var item_rewards: Dictionary = {}
	if not was_first_clear:
		var shard_amount := maxi(
			int(stage_data.get("repeat_clear_shards", 0)),
			0
		)
		if shard_amount > 0:
			item_rewards[InventoryManager.REFINEMENT_SHARD] = shard_amount
	return create_reward_data(
		int(stage_data.get(reward_key, 100)),
		item_rewards
	)

func has_boss_reward_definition(boss_source_id: String) -> bool:
	return BOSS_REWARD_CATALOG.has(boss_source_id.strip_edges())

func get_boss_reward(boss_source_id: String) -> Dictionary:
	var normalized_source_id := boss_source_id.strip_edges()
	var reward_data: Dictionary = BOSS_REWARD_CATALOG.get(
		normalized_source_id,
		{}
	)
	return reward_data.duplicate(true)

func has_reward_payload(reward_data: Dictionary) -> bool:
	var spirit_stone_amount := int(
		reward_data.get(REWARD_KEY_SPIRIT_STONE, 0)
	)
	if spirit_stone_amount > 0:
		return true
	var raw_items = reward_data.get(REWARD_KEY_ITEMS, {})
	if not raw_items is Dictionary:
		return false
	for raw_item_id in raw_items.keys():
		if int(raw_items.get(raw_item_id, 0)) > 0:
			return true
	return false

## Membentuk teks presentasi dari payload transaksi tanpa mengubah data.
## UI tetap menerima reward_data yang sama dengan reward_granted signal.
func get_reward_summary(
	reward_data: Dictionary,
	empty_text: String = "No Reward"
) -> String:
	var summary_lines: Array[String] = []
	var spirit_stone_amount := int(
		reward_data.get(REWARD_KEY_SPIRIT_STONE, 0)
	)
	if spirit_stone_amount > 0:
		summary_lines.append(
			tr("%d Spirit Stone") % spirit_stone_amount
		)

	var raw_items = reward_data.get(REWARD_KEY_ITEMS, {})
	if raw_items is Dictionary:
		var item_ids: Array[String] = []
		for raw_item_id in raw_items.keys():
			item_ids.append(str(raw_item_id))
		item_ids.sort()
		for item_id in item_ids:
			var item_amount := int(raw_items.get(item_id, 0))
			if item_amount <= 0:
				continue
			var item_display_name := item_id
			if InventoryManager.is_known_item(item_id):
				var item_data := InventoryManager.get_item_data(item_id)
				item_display_name = str(
					item_data.get("display_name", item_id)
				)
			summary_lines.append(
				"%s x%d" % [tr(item_display_name), item_amount]
			)

	if summary_lines.is_empty():
		return tr(empty_text)
	return "\n".join(PackedStringArray(summary_lines))

func get_game_over_reward_tier_id(wave: int) -> String:
	for raw_tier_data in GAME_OVER_REWARD_TIERS:
		var tier_data: Dictionary = raw_tier_data
		var minimum_wave := int(tier_data.get("min_wave", 0))
		var maximum_wave := int(tier_data.get("max_wave", -1))
		if wave >= minimum_wave and wave <= maximum_wave:
			return str(tier_data.get("id", GAME_OVER_TIER_NONE))
	return GAME_OVER_TIER_NONE

func get_game_over_reward(wave: int) -> Dictionary:
	for raw_tier_data in GAME_OVER_REWARD_TIERS:
		var tier_data: Dictionary = raw_tier_data
		var minimum_wave := int(tier_data.get("min_wave", 0))
		var maximum_wave := int(tier_data.get("max_wave", -1))
		if wave < minimum_wave or wave > maximum_wave:
			continue
		return create_reward_data(
			int(tier_data.get(REWARD_KEY_SPIRIT_STONE, 0))
		)
	return create_reward_data()

func create_reward_data(
	spirit_stone_amount: int = 0,
	item_amounts: Dictionary = {}
) -> Dictionary:
	return {
		REWARD_KEY_SPIRIT_STONE: maxi(
			spirit_stone_amount,
			0
		),
		REWARD_KEY_ITEMS: item_amounts.duplicate(true)
	}

func get_reward_validation_error(
	source_type: String,
	source_id: String,
	reward_data: Dictionary
) -> String:
	if not is_valid_source_type(source_type):
		return "source type tidak valid: " + source_type
	if source_id.strip_edges().is_empty():
		return "source id tidak boleh kosong"
	var spirit_stone_amount := int(
		reward_data.get(REWARD_KEY_SPIRIT_STONE, 0)
	)
	if spirit_stone_amount < 0:
		return "Spirit Stone reward tidak boleh negatif"
	var raw_items = reward_data.get(REWARD_KEY_ITEMS, {})
	if not raw_items is Dictionary:
		return "item reward harus berupa Dictionary"
	var has_item_reward := false
	for raw_item_id in raw_items.keys():
		var item_id := str(raw_item_id)
		var amount := int(raw_items.get(raw_item_id, 0))
		if item_id.is_empty():
			return "item id tidak boleh kosong"
		if amount <= 0:
			return "jumlah item harus lebih dari 0: " + item_id
		if not InventoryManager.is_known_item(item_id):
			return "item tidak dikenal: " + item_id
		has_item_reward = true
	if spirit_stone_amount <= 0 and not has_item_reward:
		return "reward tidak memiliki grant yang valid"
	return ""

func is_valid_reward(
	source_type: String,
	source_id: String,
	reward_data: Dictionary
) -> bool:
	return get_reward_validation_error(
		source_type,
		source_id,
		reward_data
	).is_empty()

func grant_reward(
	source_type: String,
	source_id: String,
	reward_data: Dictionary,
	additional_domains: Dictionary = {}
) -> Dictionary:
	var validation_error: String = get_reward_validation_error(source_type, source_id, reward_data)
	if not validation_error.is_empty():
		return _reject_reward(source_type, source_id, validation_error)
	var normalized_reward: Dictionary = _normalize_reward_data(reward_data)
	var item_rewards: Dictionary = normalized_reward.get(REWARD_KEY_ITEMS, {})
	var spirit_stone_amount: int = int(normalized_reward.get(REWARD_KEY_SPIRIT_STONE, 0))
	var progression_data: Dictionary = ProgressionManager.build_progression_save_data()
	progression_data["spirit_stone"] = int(progression_data["spirit_stone"]) + spirit_stone_amount
	var counts: Dictionary = InventoryManager.preview_add_items(item_rewards)
	var targets: Dictionary = additional_domains.duplicate(true)
	targets["progression"] = progression_data
	targets["inventory"] = {"version": 1, "item_counts": counts}
	if not SaveManager.write_save_batch(targets):
		return _reject_reward(source_type, source_id, "Reward could not be committed. Restart to recover any pending transaction.")
	ProgressionManager.apply_progression_save_data(progression_data)
	var previous_counts: Dictionary = InventoryManager.item_counts.duplicate(true)
	InventoryManager.item_counts = counts
	for raw_id in counts:
		var item_id: String = str(raw_id)
		if int(previous_counts.get(item_id, 0)) != int(counts[item_id]):
			InventoryManager.inventory_changed.emit(item_id, int(counts[item_id]))
	for raw_id in item_rewards:
		var item_id: String = str(raw_id)
		InventoryManager.item_added.emit(item_id, int(item_rewards[item_id]), int(counts.get(item_id, 0)))
	last_grant_result = _build_grant_result(true, source_type, source_id, normalized_reward, "")
	var applied_items: Dictionary = {}
	for raw_id in counts:
		var delta: int = int(counts[raw_id]) - int(previous_counts.get(raw_id, 0))
		if delta > 0:
			applied_items[str(raw_id)] = delta
	last_grant_result["applied_reward_data"] = create_reward_data(spirit_stone_amount, applied_items)
	reward_granted.emit(source_type, source_id, normalized_reward.duplicate(true))
	AudioManager.play_sfx("claim")
	return last_grant_result.duplicate(true)

func get_last_grant_result() -> Dictionary:
	return last_grant_result.duplicate(true)

func get_run_end_domains() -> Dictionary:
	var journey_data: Dictionary = JourneyManager.build_save_data()
	journey_data["active_run_chapter_id"] = JourneyManager.NO_ACTIVE_ID
	journey_data["active_run_stage_id"] = JourneyManager.NO_ACTIVE_ID
	var domains: Dictionary = {"journey": journey_data}
	var checkpoint_result: Dictionary = SaveManager.read_save_data("checkpoint")
	if bool(checkpoint_result.get("success", false)):
		var checkpoint_data: Dictionary = checkpoint_result["data"].duplicate(true)
		checkpoint_data["version"] = 1
		checkpoint_data["ended"] = true
		domains["checkpoint"] = checkpoint_data
	return domains

func _normalize_reward_data(reward_data: Dictionary) -> Dictionary:
	var normalized_items: Dictionary = {}
	var raw_items: Dictionary = reward_data.get(
		REWARD_KEY_ITEMS,
		{}
	)
	for raw_item_id in raw_items.keys():
		var item_id := str(raw_item_id)
		normalized_items[item_id] = int(
			raw_items.get(raw_item_id, 0)
		)
	return {
		REWARD_KEY_SPIRIT_STONE: int(
			reward_data.get(REWARD_KEY_SPIRIT_STONE, 0)
		),
		REWARD_KEY_ITEMS: normalized_items
	}

func _reject_reward(
	source_type: String,
	source_id: String,
	reason: String
) -> Dictionary:
	last_grant_result = _build_grant_result(
		false,
		source_type,
		source_id,
		{},
		reason
	)
	reward_rejected.emit(source_type, source_id, reason)
	push_warning(
		"RewardManager: reward ditolak | Source: "
		+ source_type
		+ "/"
		+ source_id
		+ " | Reason: "
		+ reason
	)
	return last_grant_result.duplicate(true)

func _build_grant_result(
	success: bool,
	source_type: String,
	source_id: String,
	reward_data: Dictionary,
	error_message: String
) -> Dictionary:
	return {
		"success": success,
		"source_type": source_type,
		"source_id": source_id,
		"reward_data": reward_data.duplicate(true),
		"error": error_message
	}

## What the player will actually receive after duplicate conversion; pure preview.
func preview_received_reward(reward_data: Dictionary) -> Dictionary:
	var next_counts: Dictionary = InventoryManager.preview_add_items(reward_data.get(REWARD_KEY_ITEMS, {}))
	var received: Dictionary = {}
	for raw_id in next_counts:
		var amount: int = int(next_counts[raw_id]) - InventoryManager.get_item_count(str(raw_id))
		if amount > 0:
			received[str(raw_id)] = amount
	return create_reward_data(int(reward_data.get(REWARD_KEY_SPIRIT_STONE, 0)), received)
