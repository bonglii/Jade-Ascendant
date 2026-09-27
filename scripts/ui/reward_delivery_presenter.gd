extends Node

## Shared reward delivery presentation for Jade Ascendant.
##
## DESIGN CONTRACT
## source -> travel -> semantic destination -> destination pulse -> visible value impact
##
## This node is presentation-only. Economy/save ownership remains in the existing
## managers. It observes successful changes and never grants, spends, saves, or
## mutates authoritative reward data.

const SPIRIT_STONE_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/spirit_stone_premium.png"
)
const REFINEMENT_SHARD_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/refinement_shard_premium.png"
)
const CELESTIAL_JADE_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/celestial_jade_premium.png"
)
const PAVILION_SEAL_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/pavilion_seal_premium.png"
)
const RUN_EXP_ICON: Texture2D = preload(
	"res://assets/pickups/xp_gold_amber_qi_shard_32x32.png"
)
const HERO_ICON: Texture2D = preload(
	"res://assets/ui/icons/navigation/hero.png"
)

const KEY_SPIRIT_STONE: String = "spirit_stone"
const KEY_REFINEMENT_SHARD: String = "refinement_shard"
const KEY_CELESTIAL_JADE: String = "celestial_jade"
const KEY_PAVILION_SEAL: String = "pavilion_seal"
const KEY_HERO_EXP: String = "hero_exp"
const KEY_RUN_EXP: String = "run_exp"
const KEY_INVENTORY_ITEM: String = "inventory_item"

const WALLET_INDEX: Dictionary = {
	KEY_SPIRIT_STONE: 0,
	KEY_REFINEMENT_SHARD: 1,
	KEY_CELESTIAL_JADE: 2,
	KEY_PAVILION_SEAL: 3,
}

const GOLD: Color = Color(1.0, 0.79, 0.30, 1.0)
const JADE: Color = Color(0.30, 0.94, 0.76, 1.0)
const EXP_GOLD: Color = Color(1.0, 0.73, 0.24, 1.0)

const POLL_INTERVAL: float = 0.08
const CLAIM_ALL_BUFFER: float = 0.09

var _overlay_layer: CanvasLayer = null
var _overlay: Control = null
var _poll_elapsed: float = 0.0

var _last_scene_id: int = 0
var _last_spirit_stone: int = 0
var _last_refinement_shard: int = 0
var _last_celestial_jade: int = 0
var _last_pavilion_seal: int = 0
var _last_hero_exp_total: int = 0

var _run_player: Node = null
var _last_run_exp: int = 0
var _last_run_level: int = 1
var _last_run_exp_to_next: int = 10

var _pending_claim_all: Array[Dictionary] = []
var _claim_all_elapsed: float = 0.0
var _wallet_visual_holds: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	_cache_authoritative_values()
	_connect_manager_signals()
	set_process(true)


func _process(delta: float) -> void:
	_refresh_scene_context()
	_enforce_wallet_holds()

	if not _pending_claim_all.is_empty():
		_claim_all_elapsed += delta
		if _claim_all_elapsed >= CLAIM_ALL_BUFFER:
			_flush_claim_all()

	_poll_elapsed += delta
	if _poll_elapsed < POLL_INTERVAL:
		return
	_poll_elapsed = 0.0

	_poll_fallback_resource_gains()
	_poll_run_experience()


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "RewardDeliveryOverlayLayer"
	_overlay_layer.layer = 190
	add_child(_overlay_layer)

	_overlay = Control.new()
	_overlay.name = "RewardDeliveryOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_overlay)


func _connect_manager_signals() -> void:
	if (
		is_instance_valid(RewardManager)
		and not RewardManager.reward_granted.is_connected(_on_reward_granted)
	):
		RewardManager.reward_granted.connect(_on_reward_granted)

	if (
		is_instance_valid(InventoryManager)
		and not InventoryManager.item_added.is_connected(_on_item_added)
	):
		InventoryManager.item_added.connect(_on_item_added)

	if (
		is_instance_valid(PavilionManager)
		and not PavilionManager.pavilion_changed.is_connected(_on_pavilion_changed)
	):
		PavilionManager.pavilion_changed.connect(_on_pavilion_changed)


func _cache_authoritative_values() -> void:
	_last_spirit_stone = maxi(int(ProgressionManager.spirit_stone), 0)
	_last_refinement_shard = maxi(
		int(InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD)),
		0
	)
	_last_celestial_jade = maxi(int(PavilionManager.get_celestial_jade()), 0)
	_last_pavilion_seal = maxi(int(PavilionManager.get_pavilion_seals()), 0)
	_last_hero_exp_total = maxi(
		int(ProgressionManager.hero_experience_total),
		0
	)


func _refresh_scene_context() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		_run_player = null
		_last_scene_id = 0
		return

	var scene_id: int = scene.get_instance_id()
	if scene_id == _last_scene_id:
		return

	_last_scene_id = scene_id
	_run_player = scene.find_child("player_1", true, false)
	if _run_player != null:
		_last_run_exp = int(_run_player.get("experience"))
		_last_run_level = int(_run_player.get("level"))
		_last_run_exp_to_next = maxi(
			int(_run_player.get("experience_to_next_level")),
			1
		)
	else:
		_last_run_exp = 0
		_last_run_level = 1
		_last_run_exp_to_next = 10


func _on_reward_granted(
	_source_type: String,
	_source_id: String,
	reward_data: Dictionary
) -> void:
	var source := _capture_source()
	var claim_all: bool = _source_is_claim_all(source)

	var spirit_amount: int = maxi(
		int(reward_data.get(RewardManager.REWARD_KEY_SPIRIT_STONE, 0)),
		0
	)
	if spirit_amount > 0:
		_queue_delivery(
			KEY_SPIRIT_STONE,
			spirit_amount,
			SPIRIT_STONE_ICON,
			source,
			claim_all
		)

	var hero_exp_amount: int = maxi(
		int(reward_data.get(RewardManager.REWARD_KEY_HERO_EXP, 0)),
		0
	)
	if hero_exp_amount > 0:
		_queue_delivery(
			KEY_HERO_EXP,
			hero_exp_amount,
			RUN_EXP_ICON,
			source,
			claim_all
		)

	# RewardManager has already committed the authoritative progression payload.
	# Advance caches now so the fallback poll does not replay the same gain.
	_last_spirit_stone = maxi(int(ProgressionManager.spirit_stone), 0)
	_last_hero_exp_total = maxi(
		int(ProgressionManager.hero_experience_total),
		0
	)


func _on_item_added(
	item_id: String,
	amount: int,
	new_count: int
) -> void:
	if amount <= 0:
		return

	var source := _capture_source()
	var claim_all: bool = _source_is_claim_all(source)

	if item_id == InventoryManager.REFINEMENT_SHARD:
		_queue_delivery(
			KEY_REFINEMENT_SHARD,
			amount,
			REFINEMENT_SHARD_ICON,
			source,
			claim_all
		)
		_last_refinement_shard = maxi(new_count, 0)
		return

	# Equipment and other inventory acquisitions travel toward Hero / Inventory.
	# We deliberately use the authored Hero navigation icon as the generic
	# inventory-delivery glyph instead of guessing an item-art field contract.
	_queue_delivery(
		KEY_INVENTORY_ITEM,
		amount,
		HERO_ICON,
		source,
		claim_all
	)


func _on_pavilion_changed() -> void:
	var current_jade: int = maxi(int(PavilionManager.get_celestial_jade()), 0)
	var current_seals: int = maxi(int(PavilionManager.get_pavilion_seals()), 0)
	var source := _capture_source()
	var claim_all: bool = _source_is_claim_all(source)

	if current_jade > _last_celestial_jade:
		_queue_delivery(
			KEY_CELESTIAL_JADE,
			current_jade - _last_celestial_jade,
			CELESTIAL_JADE_ICON,
			source,
			claim_all
		)

	if current_seals > _last_pavilion_seal:
		_queue_delivery(
			KEY_PAVILION_SEAL,
			current_seals - _last_pavilion_seal,
			PAVILION_SEAL_ICON,
			source,
			claim_all
		)

	_last_celestial_jade = current_jade
	_last_pavilion_seal = current_seals


func _poll_fallback_resource_gains() -> void:
	var current_stone: int = maxi(int(ProgressionManager.spirit_stone), 0)
	var current_shard: int = maxi(
		int(InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD)),
		0
	)
	var current_jade: int = maxi(int(PavilionManager.get_celestial_jade()), 0)
	var current_seal: int = maxi(int(PavilionManager.get_pavilion_seals()), 0)
	var current_hero_exp: int = maxi(
		int(ProgressionManager.hero_experience_total),
		0
	)

	var source := _capture_source()
	var claim_all: bool = _source_is_claim_all(source)

	if current_stone > _last_spirit_stone:
		_queue_delivery(
			KEY_SPIRIT_STONE,
			current_stone - _last_spirit_stone,
			SPIRIT_STONE_ICON,
			source,
			claim_all
		)
	if current_shard > _last_refinement_shard:
		_queue_delivery(
			KEY_REFINEMENT_SHARD,
			current_shard - _last_refinement_shard,
			REFINEMENT_SHARD_ICON,
			source,
			claim_all
		)
	if current_jade > _last_celestial_jade:
		_queue_delivery(
			KEY_CELESTIAL_JADE,
			current_jade - _last_celestial_jade,
			CELESTIAL_JADE_ICON,
			source,
			claim_all
		)
	if current_seal > _last_pavilion_seal:
		_queue_delivery(
			KEY_PAVILION_SEAL,
			current_seal - _last_pavilion_seal,
			PAVILION_SEAL_ICON,
			source,
			claim_all
		)
	if current_hero_exp > _last_hero_exp_total:
		_queue_delivery(
			KEY_HERO_EXP,
			current_hero_exp - _last_hero_exp_total,
			RUN_EXP_ICON,
			source,
			claim_all
		)

	_last_spirit_stone = current_stone
	_last_refinement_shard = current_shard
	_last_celestial_jade = current_jade
	_last_pavilion_seal = current_seal
	_last_hero_exp_total = current_hero_exp


func _poll_run_experience() -> void:
	if _run_player == null or not is_instance_valid(_run_player):
		return

	var current_exp: int = int(_run_player.get("experience"))
	var current_level: int = int(_run_player.get("level"))
	var current_to_next: int = maxi(
		int(_run_player.get("experience_to_next_level")),
		1
	)

	var gained: int = 0
	if current_level == _last_run_level:
		if current_exp > _last_run_exp:
			gained = current_exp - _last_run_exp
	elif current_level == _last_run_level + 1:
		gained = maxi(_last_run_exp_to_next - _last_run_exp, 0) + current_exp

	if gained > 0:
		_play_delivery_now(
			KEY_RUN_EXP,
			gained,
			RUN_EXP_ICON,
			_player_screen_position(_run_player),
			false,
			1
		)

	_last_run_exp = current_exp
	_last_run_level = current_level
	_last_run_exp_to_next = current_to_next


func _queue_delivery(
	resource_key: String,
	amount: int,
	texture: Texture2D,
	source: Vector2,
	claim_all: bool
) -> void:
	if amount <= 0:
		return

	if claim_all:
		_pending_claim_all.append({
			"key": resource_key,
			"amount": amount,
			"texture": texture,
			"source": source,
		})
		_claim_all_elapsed = 0.0
		return

	_play_delivery_now(resource_key, amount, texture, source, false, 1)


func _flush_claim_all() -> void:
	var grouped: Dictionary = {}
	for entry: Dictionary in _pending_claim_all:
		var key: String = str(entry.get("key", ""))
		if key.is_empty():
			continue
		if not grouped.has(key):
			grouped[key] = {
				"amount": 0,
				"count": 0,
				"texture": entry.get("texture"),
				"source": entry.get("source", _viewport_center()),
			}
		var group: Dictionary = grouped[key]
		group["amount"] = int(group.get("amount", 0)) + int(entry.get("amount", 0))
		group["count"] = int(group.get("count", 0)) + 1
		grouped[key] = group

	_pending_claim_all.clear()
	_claim_all_elapsed = 0.0

	var delay: float = 0.0
	var sorted_keys: Array[String] = []
	for raw_key: Variant in grouped.keys():
		sorted_keys.append(str(raw_key))
	sorted_keys.sort()

	for key: String in sorted_keys:
		var group: Dictionary = grouped[key]
		var timer := get_tree().create_timer(delay, true, false, true)
		timer.timeout.connect(
			_play_delivery_now.bind(
				key,
				int(group.get("amount", 0)),
				group.get("texture") as Texture2D,
				group.get("source", _viewport_center()) as Vector2,
				true,
				maxi(int(group.get("count", 1)), 1)
			)
		)
		delay += 0.10


func _play_delivery_now(
	resource_key: String,
	amount: int,
	texture: Texture2D,
	source: Vector2,
	claim_all: bool,
	source_count: int
) -> void:
	var target: Control = _resolve_destination(resource_key)
	if target == null:
		return

	if _reduced_effects_enabled():
		_pulse_target(target, _accent_for(resource_key))
		return

	if WALLET_INDEX.has(resource_key):
		_prepare_wallet_visual_hold(resource_key, amount)

	if claim_all and source_count > 1:
		_play_claim_all_delivery(
			resource_key,
			amount,
			texture,
			source,
			target,
			source_count
		)
	else:
		_play_single_delivery(
			resource_key,
			amount,
			texture,
			source,
			target
		)


func _play_single_delivery(
	resource_key: String,
	amount: int,
	texture: Texture2D,
	source: Vector2,
	target: Control
) -> void:
	var icon := _create_fly_icon(texture, 50.0)
	icon.global_position = source - icon.size * 0.5
	_overlay.add_child(icon)

	var trail := _create_trail(_accent_for(resource_key))
	var target_position: Vector2 = target.get_global_rect().get_center()
	var control_point := Vector2(
		lerpf(source.x, target_position.x, 0.52),
		minf(source.y, target_position.y) - 140.0
	)

	_play_audio("claim")
	var tween := create_tween()
	tween.tween_method(
		_update_bezier.bind(
			icon,
			trail,
			source,
			control_point,
			target_position
		),
		0.0,
		1.0,
		0.60
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(
		_on_delivery_impact.bind(
			resource_key,
			amount,
			target,
			icon,
			trail
		)
	)


func _play_claim_all_delivery(
	resource_key: String,
	amount: int,
	texture: Texture2D,
	source: Vector2,
	target: Control,
	source_count: int
) -> void:
	var count: int = clampi(source_count, 2, 6)
	var merge_point := Vector2(
		lerpf(source.x, _viewport_center().x, 0.58),
		lerpf(source.y, _viewport_center().y, 0.58)
	)

	var core := _create_fly_icon(texture, 56.0)
	core.global_position = merge_point - core.size * 0.5
	core.scale = Vector2(0.76, 0.76)
	core.modulate.a = 0.80
	_overlay.add_child(core)

	var total_label := Label.new()
	total_label.text = "+%d" % amount
	total_label.size = Vector2(120.0, 32.0)
	total_label.global_position = merge_point + Vector2(-60.0, 36.0)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 20)
	total_label.add_theme_color_override(
		"font_color",
		_accent_for(resource_key)
	)
	total_label.add_theme_constant_override("outline_size", 2)
	total_label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.82)
	)
	total_label.modulate.a = 0.0
	_overlay.add_child(total_label)

	_play_audio("claim")

	for index: int in range(count):
		var mini := _create_fly_icon(texture, 31.0)
		var spread_x: float = (float(index) - float(count - 1) * 0.5) * 16.0
		var spread_y: float = -10.0 if index % 2 == 0 else 10.0
		var mini_source := source + Vector2(spread_x, spread_y)
		mini.global_position = mini_source - mini.size * 0.5
		mini.scale = Vector2(0.72, 0.72)
		_overlay.add_child(mini)

		var delay: float = float(index) * 0.055
		var mini_tween := create_tween()
		mini_tween.tween_interval(delay)
		mini_tween.set_parallel(true)
		mini_tween.tween_property(
			mini,
			"global_position",
			merge_point - mini.size * 0.5,
			0.22
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		mini_tween.tween_property(
			mini,
			"scale",
			Vector2(0.28, 0.28),
			0.22
		)
		mini_tween.tween_property(mini, "modulate:a", 0.12, 0.22)
		mini_tween.chain().tween_callback(mini.queue_free)

	var gather_duration: float = 0.22 + float(count - 1) * 0.055
	var gather_timer := get_tree().create_timer(
		gather_duration + 0.08,
		true,
		false,
		true
	)
	await gather_timer.timeout

	if not is_instance_valid(core):
		return

	core.modulate.a = 1.0
	var core_tween := create_tween()
	core_tween.set_parallel(true)
	core_tween.tween_property(
		core,
		"scale",
		Vector2(1.14, 1.14),
		0.11
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	core_tween.tween_property(total_label, "modulate:a", 1.0, 0.10)

	await get_tree().create_timer(0.13, true, false, true).timeout

	var launch_source: Vector2 = core.get_global_rect().get_center()
	core.queue_free()

	var label_tween := create_tween()
	label_tween.set_parallel(true)
	label_tween.tween_property(
		total_label,
		"global_position:y",
		total_label.global_position.y - 8.0,
		0.16
	)
	label_tween.tween_property(total_label, "modulate:a", 0.0, 0.16)
	label_tween.chain().tween_callback(total_label.queue_free)

	var main_icon := _create_fly_icon(texture, 58.0)
	main_icon.global_position = launch_source - main_icon.size * 0.5
	_overlay.add_child(main_icon)

	var trail := _create_trail(_accent_for(resource_key))
	var target_position: Vector2 = target.get_global_rect().get_center()
	var control_point := Vector2(
		lerpf(launch_source.x, target_position.x, 0.50),
		minf(launch_source.y, target_position.y) - 155.0
	)

	var tween := create_tween()
	tween.tween_method(
		_update_bezier.bind(
			main_icon,
			trail,
			launch_source,
			control_point,
			target_position
		),
		0.0,
		1.0,
		0.62
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(
		_on_delivery_impact.bind(
			resource_key,
			amount,
			target,
			main_icon,
			trail
		)
	)


func _on_delivery_impact(
	resource_key: String,
	amount: int,
	target: Control,
	icon: TextureRect,
	trail: Line2D
) -> void:
	if is_instance_valid(icon):
		icon.queue_free()
	_fade_trail(trail)

	var accent: Color = _accent_for(resource_key)
	_pulse_target(target, accent)
	_play_impact_flash(target, accent)
	_play_audio("pickup_jade")

	if WALLET_INDEX.has(resource_key):
		_release_wallet_visual_hold(resource_key, amount)


func _resolve_destination(resource_key: String) -> Control:
	if WALLET_INDEX.has(resource_key):
		return _wallet_cell(resource_key)

	if resource_key == KEY_RUN_EXP:
		return _find_control_by_names([
			"EXPBar",
			"ExperienceBar",
		])

	if resource_key == KEY_HERO_EXP:
		var hero_progress := _find_control_by_names([
			"HeroEXPBar",
			"HeroExpBar",
			"HeroProgressBar",
			"HeroStage",
		])
		if hero_progress != null:
			return hero_progress
		return _find_control_by_names(["HeroTab"])

	if resource_key == KEY_INVENTORY_ITEM:
		var inventory_destination := _find_control_by_names([
			"InventoryButton",
			"BackpackButton",
			"HeroTab",
			"HeroStage",
		])
		return inventory_destination

	return null


func _wallet_cell(resource_key: String) -> Control:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null

	var bar := scene.find_child(
		"SharedHubResourceBar",
		true,
		false
	) as Control
	if bar == null:
		return null

	var row := bar.get_node_or_null("ResourceRow") as HBoxContainer
	if row == null:
		return null

	var index: int = int(WALLET_INDEX.get(resource_key, -1))
	if index < 0 or index >= row.get_child_count():
		return null
	return row.get_child(index) as Control


func _wallet_value_label(resource_key: String) -> Label:
	var cell := _wallet_cell(resource_key)
	if cell == null:
		return null
	for child: Node in cell.get_children():
		if child is Label:
			return child as Label
	return null


func _prepare_wallet_visual_hold(resource_key: String, amount: int) -> void:
	var actual_value: int = _authoritative_wallet_value(resource_key)
	var pre_value: int = maxi(actual_value - amount, 0)
	_wallet_visual_holds[resource_key] = {
		"display": pre_value,
		"actual": actual_value,
	}
	var label := _wallet_value_label(resource_key)
	if label != null:
		label.text = _format_count(pre_value)


func _enforce_wallet_holds() -> void:
	for raw_key: Variant in _wallet_visual_holds.keys():
		var key: String = str(raw_key)
		var hold: Dictionary = _wallet_visual_holds.get(key, {})
		var label := _wallet_value_label(key)
		if label != null:
			label.text = _format_count(int(hold.get("display", 0)))


func _release_wallet_visual_hold(resource_key: String, _amount: int) -> void:
	if not _wallet_visual_holds.has(resource_key):
		return

	var hold: Dictionary = _wallet_visual_holds[resource_key]
	var from_value: int = int(hold.get("display", 0))
	var to_value: int = _authoritative_wallet_value(resource_key)
	var label := _wallet_value_label(resource_key)

	_wallet_visual_holds.erase(resource_key)

	if label == null:
		return

	var tween := create_tween()
	tween.tween_method(
		_set_wallet_label.bind(label),
		float(from_value),
		float(to_value),
		0.24
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_wallet_label(value: float, label: Label) -> void:
	if is_instance_valid(label):
		label.text = _format_count(int(round(value)))


func _authoritative_wallet_value(resource_key: String) -> int:
	match resource_key:
		KEY_SPIRIT_STONE:
			return maxi(int(ProgressionManager.spirit_stone), 0)
		KEY_REFINEMENT_SHARD:
			return maxi(
				int(
					InventoryManager.get_item_count(
						InventoryManager.REFINEMENT_SHARD
					)
				),
				0
			)
		KEY_CELESTIAL_JADE:
			return maxi(int(PavilionManager.get_celestial_jade()), 0)
		KEY_PAVILION_SEAL:
			return maxi(int(PavilionManager.get_pavilion_seals()), 0)
		_:
			return 0


func _find_control_by_names(names: Array[String]) -> Control:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	for node_name: String in names:
		var found := scene.find_child(node_name, true, false) as Control
		if found != null and found.visible:
			return found
	return null


func _capture_source() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		var focus := viewport.gui_get_focus_owner()
		if focus != null and is_instance_valid(focus) and focus is Control:
			var control := focus as Control
			if control.visible:
				return control.get_global_rect().get_center()
	return _viewport_center()


func _source_is_claim_all(source: Vector2) -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var focus := viewport.gui_get_focus_owner()
	if focus == null or not is_instance_valid(focus) or not focus is Button:
		return false
	var button := focus as Button
	if button.get_global_rect().grow(8.0).has_point(source):
		return button.text.to_upper().contains("CLAIM ALL")
	return false


func _player_screen_position(player: Node) -> Vector2:
	if player is Node2D:
		var actor := player as Node2D
		return actor.get_global_transform_with_canvas().origin
	return _viewport_center()


func _viewport_center() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5


func _create_fly_icon(
	texture: Texture2D,
	size_px: float
) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.custom_minimum_size = Vector2(size_px, size_px)
	icon.size = Vector2(size_px, size_px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.pivot_offset = icon.size * 0.5
	icon.z_index = 4
	return icon


func _create_trail(accent: Color) -> Line2D:
	var trail := Line2D.new()
	trail.width = 3.5
	trail.default_color = accent
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.z_index = 2
	_overlay.add_child(trail)
	return trail


func _update_bezier(
	progress: float,
	icon: TextureRect,
	trail: Line2D,
	start: Vector2,
	control: Vector2,
	end: Vector2
) -> void:
	if not is_instance_valid(icon):
		return

	var inverse: float = 1.0 - progress
	var center: Vector2 = (
		inverse * inverse * start
		+ 2.0 * inverse * progress * control
		+ progress * progress * end
	)
	icon.global_position = center - icon.size * 0.5

	if is_instance_valid(trail):
		var points: PackedVector2Array = trail.points
		points.append(center)
		while points.size() > 10:
			points.remove_at(0)
		trail.points = points
		trail.modulate.a = 0.80 - progress * 0.34


func _fade_trail(trail: Line2D) -> void:
	if not is_instance_valid(trail):
		return
	var tween := create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.12)
	tween.tween_callback(trail.queue_free)


func _pulse_target(target: Control, accent: Color) -> void:
	if target == null or not is_instance_valid(target):
		return

	target.pivot_offset = target.size * 0.5
	target.scale = Vector2.ONE
	target.modulate = Color.WHITE

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		target,
		"scale",
		Vector2(1.10, 1.10),
		0.10
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		target,
		"modulate",
		accent,
		0.08
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().set_parallel(true)
	tween.tween_property(
		target,
		"scale",
		Vector2.ONE,
		0.13
	)
	tween.tween_property(
		target,
		"modulate",
		Color.WHITE,
		0.13
	)


func _play_impact_flash(target: Control, accent: Color) -> void:
	var flash := Panel.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.size = Vector2(62.0, 62.0)
	flash.global_position = (
		target.get_global_rect().get_center()
		- flash.size * 0.5
	)
	flash.pivot_offset = flash.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.08)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(
		GOLD.r,
		GOLD.g,
		GOLD.b,
		0.78
	)
	style.corner_radius_top_left = 31
	style.corner_radius_top_right = 31
	style.corner_radius_bottom_left = 31
	style.corner_radius_bottom_right = 31
	style.shadow_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.22
	)
	style.shadow_size = 7
	flash.add_theme_stylebox_override("panel", style)
	_overlay.add_child(flash)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		flash,
		"scale",
		Vector2(1.48, 1.48),
		0.19
	)
	tween.tween_property(flash, "modulate:a", 0.0, 0.19)
	tween.chain().tween_callback(flash.queue_free)


func _accent_for(resource_key: String) -> Color:
	match resource_key:
		KEY_RUN_EXP, KEY_HERO_EXP:
			return EXP_GOLD
		KEY_CELESTIAL_JADE:
			return Color(0.53, 0.67, 1.0, 1.0)
		KEY_PAVILION_SEAL:
			return GOLD
		_:
			return JADE


func _play_audio(cue: String) -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx(cue)


func _reduced_effects_enabled() -> bool:
	return bool(SettingsManager.reduced_effects)


func _format_count(value: int) -> String:
	var safe_value: int = maxi(value, 0)
	if safe_value >= 1000000:
		return "%.1fM" % (float(safe_value) / 1000000.0)
	if safe_value >= 10000:
		return "%.1fK" % (float(safe_value) / 1000.0)
	return str(safe_value)
