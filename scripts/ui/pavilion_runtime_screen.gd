extends "res://scripts/ui/pavilion_screen.gd"

## Commercial rewarded-ad presentation for Jade Pavilion.
## Economy authority remains in PavilionManager; this layer only requests a
## verified rewarded placement and presents its saved result.
const RewardedBridge = preload(
	"res://scripts/monetization/pavilion_rewarded_bridge.gd"
)
const RewardedLocalization = preload(
	"res://scripts/monetization/monetization_localization.gd"
)
const RewardedEconomyCatalog = preload(
	"res://scripts/data/economy_catalog.gd"
)

const POLISH_SUMMON_GATE: Texture2D = preload(
	"res://assets/ui/pavilion/icons/summon_gate.png"
)
const POLISH_SUMMON_TALISMAN: Texture2D = preload(
	"res://assets/ui/pavilion/icons/summon_talisman.png"
)
const POLISH_PAVILION_CREST: Texture2D = preload(
	"res://assets/ui/pavilion/icons/pavilion_crest.png"
)
const POLISH_MEDITATION_ICON: Texture2D = preload(
	"res://assets/ui/pavilion/icons/meditation.png"
)
const POLISH_REWARD_CHEST: Texture2D = preload(
	"res://assets/ui/pavilion/icons/reward_chest.png"
)

const POLISH_SLOT_PATHS: Dictionary = {
	"armament": "res://assets/ui/pavilion/icons/slot_armament.png",
	"robe": "res://assets/ui/pavilion/icons/slot_robe.png",
	"bracer": "res://assets/ui/pavilion/icons/slot_bracer.png",
	"boots": "res://assets/ui/pavilion/icons/slot_boots.png",
	"pendant": "res://assets/ui/pavilion/icons/slot_pendant.png",
}

const POLISH_AURA_PATHS: Dictionary = {
	"plain": "res://assets/ui/pavilion/auras/aura_plain.png",
	"jade_aura": "res://assets/ui/pavilion/auras/aura_jade.png",
	"golden_aura": "res://assets/ui/pavilion/auras/aura_golden.png",
	"astral_aura": "res://assets/ui/pavilion/auras/aura_astral.png",
	"ascendant_aura": "res://assets/ui/pavilion/auras/aura_ascendant.png",
}

var rewarded_seal_panel: PanelContainer
var rewarded_seal_button: Button
var rewarded_seal_state_label: Label
var rewarded_seal_remaining_label: Label
var rewarded_seal_message_label: Label
var rewarded_refresh_timer: Timer
var polish_bootstrap_complete: bool = false


func _ready() -> void:
	super()
	if content != null:
		content.modulate = Color(1.0, 1.0, 1.0, 0.0)
	call_deferred("_finish_polish_bootstrap")


func _finish_polish_bootstrap() -> void:
	if polish_bootstrap_complete:
		return

	var wait_frames: int = 0
	while wait_frames < 8:
		# Smoke/off-tree QA can release Pavilion immediately after opening the
		# next hub screen. Never call get_tree() once this node is detached;
		# Godot reports that access as an engine ERROR even though QA checks pass.
		if not is_inside_tree():
			return
		if (
			content != null
			and ritual_icon != null
			and meditation_altar_icon != null
		):
			break

		wait_frames += 1
		var scene_tree: SceneTree = get_tree()
		if scene_tree == null:
			return
		await scene_tree.process_frame

	if not is_inside_tree():
		return
	_apply_first_frame_polish()
	polish_bootstrap_complete = true
	if content != null:
		var reveal: Tween = create_tween()
		reveal.tween_property(content, "modulate", Color.WHITE, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _apply_first_frame_polish() -> void:
	if content == null:
		return
	_replace_pavilion_header_emblem(content)
	if ritual_icon != null:
		ritual_icon.texture = POLISH_SUMMON_GATE
		ritual_icon.modulate = Color.WHITE
	if summon_reveal_icon != null:
		summon_reveal_icon.texture = POLISH_SUMMON_GATE
		summon_reveal_icon.modulate = Color.WHITE
	if meditation_altar_icon != null:
		meditation_altar_icon.texture = POLISH_MEDITATION_ICON
		meditation_altar_icon.modulate = Color.WHITE
	if summon_ten_button != null:
		_apply_commercial_button_icon(summon_ten_button, POLISH_SUMMON_TALISMAN, 34)
	if summon_one_button != null:
		_apply_commercial_button_icon(summon_one_button, POLISH_SUMMON_TALISMAN, 30)
	if starter_button != null:
		_apply_commercial_button_icon(starter_button, POLISH_REWARD_CHEST, 28)
	_restore_summon_focal_if_needed()
	_enforce_mobile_readability(content)


func _readable_font_size(requested_size: int) -> int:
	if requested_size <= 10:
		return 12
	if requested_size == 11:
		return 12
	return requested_size


func _label(
	parent_node: Node,
	value: String,
	font_size: int = 16,
	tint: Color = TEXT_MUTED
) -> Label:
	return super(
		parent_node,
		value,
		_readable_font_size(font_size),
		tint
	)


func _state_badge(
	parent_node: Node,
	value: String,
	accent: Color
) -> Label:
	var label: Label = super(parent_node, value, accent)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", 12)
	if label.get_parent() is PanelContainer:
		(label.get_parent() as PanelContainer).custom_minimum_size.y = 30.0
	return label


func _button(
	parent_node: Node,
	value: String,
	callback: Callable,
	primary: bool,
	accent: Color
) -> Button:
	var button: Button = super(
		parent_node,
		value,
		callback,
		primary,
		accent
	)
	button.custom_minimum_size.y = maxf(
		button.custom_minimum_size.y,
		52.0 if primary else 46.0
	)
	button.add_theme_font_size_override(
		"font_size",
		15 if primary else 14
	)
	button.add_theme_color_override(
		"font_disabled_color",
		Color(0.64, 0.73, 0.70, 0.98)
	)
	return button


func _apply_button_style(
	button: Button,
	accent: Color,
	primary: bool
) -> void:
	super(button, accent, primary)
	button.add_theme_color_override(
		"font_disabled_color",
		Color(0.64, 0.73, 0.70, 0.98)
	)


func _enforce_mobile_readability(root: Node) -> void:
	if root is Label:
		var label := root as Label
		if label.get_theme_font_size("font_size") < 12:
			label.add_theme_font_size_override("font_size", 12)
	elif root is Button:
		var button := root as Button
		if button.get_theme_font_size("font_size") < 14:
			button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override(
			"font_disabled_color",
			Color(0.64, 0.73, 0.70, 0.98)
		)

	for child: Node in root.get_children():
		_enforce_mobile_readability(child)


func _apply_commercial_button_icon(
	button: Button,
	texture: Texture2D,
	max_width: int
) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.icon = texture
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", max_width)
	button.add_theme_constant_override("h_separation", 8)


func _get_summon_slot_icon_path(slot_id: String) -> String:
	return str(
		POLISH_SLOT_PATHS.get(
			slot_id,
			"res://assets/ui/pavilion/icons/summon_talisman.png"
		)
	)


func _get_aura_preview_path(cosmetic_id: String) -> String:
	return str(
		POLISH_AURA_PATHS.get(
			cosmetic_id,
			POLISH_AURA_PATHS["plain"]
		)
	)


func _get_aura_icon_path(cosmetic_id: String) -> String:
	return _get_aura_preview_path(cosmetic_id)


func _build_hero_header() -> void:
	super()
	if content == null or content.get_child_count() <= 0:
		return

	# The base header creates exactly one 54x54 icon emblem. Replace only that
	# emblem texture; the sanctuary banner/background remains untouched.
	var hero_stage: Node = content.get_child(content.get_child_count() - 1)
	_replace_pavilion_header_emblem(hero_stage)


func _replace_pavilion_header_emblem(root: Node) -> bool:
	if root is PanelContainer:
		var panel := root as PanelContainer
		var min_size: Vector2 = panel.custom_minimum_size
		if (
			min_size.x >= 50.0
			and min_size.x <= 58.0
			and min_size.y >= 50.0
			and min_size.y <= 58.0
		):
			for child: Node in panel.get_children():
				if child is TextureRect:
					(child as TextureRect).texture = POLISH_PAVILION_CREST
					return true

	for child: Node in root.get_children():
		if _replace_pavilion_header_emblem(child):
			return true
	return false


func _build_summon_section() -> void:
	super()

	if ritual_icon != null:
		ritual_icon.texture = POLISH_SUMMON_GATE
		ritual_icon.modulate = Color.WHITE

	if summon_ten_button != null:
		summon_ten_button.add_theme_font_size_override("font_size", 19)
		_apply_commercial_button_icon(
			summon_ten_button,
			POLISH_SUMMON_TALISMAN,
			34
		)
	if summon_one_button != null:
		summon_one_button.add_theme_font_size_override("font_size", 14)
		_apply_commercial_button_icon(
			summon_one_button,
			POLISH_SUMMON_TALISMAN,
			30
		)
	if rates_button != null:
		rates_button.add_theme_font_size_override("font_size", 14)
	if starter_button != null:
		starter_button.add_theme_font_size_override("font_size", 14)
		_apply_commercial_button_icon(
			starter_button,
			POLISH_REWARD_CHEST,
			28
		)
	_enforce_mobile_readability(content)


func _build_wish_selector_overlay() -> void:
	super()
	if wish_selector_overlay != null:
		_enforce_mobile_readability(wish_selector_overlay)


func _build_summon_reveal_overlay() -> void:
	super()
	if summon_reveal_icon != null:
		summon_reveal_icon.texture = POLISH_SUMMON_GATE
		summon_reveal_icon.modulate = Color.WHITE
	if summon_reveal_overlay != null:
		_enforce_mobile_readability(summon_reveal_overlay)


func _reset_summon_reveal_visual() -> void:
	super()
	if summon_reveal_icon != null:
		summon_reveal_icon.texture = POLISH_SUMMON_GATE
		summon_reveal_icon.modulate = Color.WHITE


func _build_meditation_section() -> void:
	_build_rewarded_seal_section()
	super()

	if meditation_altar_icon != null:
		meditation_altar_icon.texture = POLISH_MEDITATION_ICON
		meditation_altar_icon.modulate = Color.WHITE

	if cadence_label != null:
		cadence_label.add_theme_font_size_override("font_size", 12)
	if chest != null:
		chest.add_theme_font_size_override("font_size", 14)
		_apply_commercial_button_icon(
			chest,
			POLISH_MEDITATION_ICON,
			32
		)
	_enforce_mobile_readability(content)


func _refresh() -> void:
	super()
	_restore_summon_focal_if_needed()
	_refresh_rewarded_seal_section()
	if content != null:
		_enforce_mobile_readability(content)


func _restore_summon_focal_if_needed() -> void:
	if ritual_icon == null or ritual_icon_frame == null:
		return
	if not ritual_icon_frame.visible:
		return
	if not PavilionManager.get_wish_target_item_id().is_empty():
		return
	ritual_icon.texture = POLISH_SUMMON_GATE
	ritual_icon.modulate = Color.WHITE


func _build_rewarded_seal_section() -> void:
	RewardedLocalization.install()

	var section: VBoxContainer = _section_card(
		content,
		tr("OPTIONAL REWARDED AD"),
		tr("Celestial Patronage"),
		tr(
			"Watch one optional rewarded ad to receive 1 Pavilion Seal. "
			+ "Reward is granted only after completion."
		),
		JADE
	)
	rewarded_seal_panel = section.get_parent() as PanelContainer
	section.add_theme_constant_override("separation", 10)

	var status_stack := VBoxContainer.new()
	status_stack.add_theme_constant_override("separation", 6)
	section.add_child(status_stack)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	status_stack.add_child(status_row)

	rewarded_seal_state_label = _label(
		status_row,
		tr("REWARD PREPARING..."),
		12,
		JADE
	)
	rewarded_seal_state_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rewarded_seal_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rewarded_seal_state_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rewarded_seal_state_label.custom_minimum_size.y = 24.0

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(spacer)

	rewarded_seal_remaining_label = _label(
		status_row,
		"",
		13,
		Color(0.84, 0.92, 0.88, 1.0)
	)
	rewarded_seal_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rewarded_seal_remaining_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rewarded_seal_remaining_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	rewarded_seal_button = _button(
		section,
		tr("WATCH OPTIONAL AD • +1 PAVILION SEAL"),
		_request_rewarded_seal,
		true,
		JADE
	)
	rewarded_seal_button.custom_minimum_size.y = 52.0
	rewarded_seal_button.add_theme_font_size_override("font_size", 15)

	var cadence_note: Label = _label(
		section,
		tr(
			"Once per day • up to 3 rewarded Seals per 7 active-day cycle."
		),
		12,
		Color(0.72, 0.81, 0.79, 1.0)
	)
	cadence_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	rewarded_seal_message_label = _label(
		section,
		"",
		12,
		Color(1.0, 0.84, 0.42, 1.0)
	)
	rewarded_seal_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rewarded_seal_message_label.visible = false

	if not MonetizationManager.reward_delivery_finished.is_connected(
		_on_reward_delivery_finished
	):
		MonetizationManager.reward_delivery_finished.connect(
			_on_reward_delivery_finished
		)
	if not MonetizationManager.rewarded_request_finished.is_connected(
		_on_rewarded_request_finished
	):
		MonetizationManager.rewarded_request_finished.connect(
			_on_rewarded_request_finished
		)

	rewarded_refresh_timer = Timer.new()
	rewarded_refresh_timer.name = "RewardedSealRefreshTimer"
	rewarded_refresh_timer.wait_time = 1.0
	rewarded_refresh_timer.one_shot = false
	rewarded_refresh_timer.timeout.connect(_refresh_rewarded_seal_section)
	add_child(rewarded_refresh_timer)
	rewarded_refresh_timer.start()

	_refresh_rewarded_seal_section()


func _refresh_rewarded_seal_section() -> void:
	if (
		rewarded_seal_panel == null
		or not is_instance_valid(rewarded_seal_panel)
	):
		return

	var summon_unlocked: bool = PavilionManager.is_summon_unlocked()
	rewarded_seal_panel.visible = summon_unlocked
	if not summon_unlocked:
		return

	var cadence: Dictionary = PavilionManager.get_cadence_status()
	var remaining: int = int(cadence.get("rewarded_ads_remaining", 0))
	var cycle_limit: int = RewardedEconomyCatalog.REWARDED_AD_MAX_PER_CYCLE

	rewarded_seal_remaining_label.text = tr(
		"%d / %d rewarded Seals remain this cycle"
	) % [
		remaining,
		cycle_limit
	]

	rewarded_seal_button.text = tr(
		"WATCH OPTIONAL AD • +1 PAVILION SEAL"
	)

	if SaveManager.is_progress_read_only():
		_set_rewarded_state(
			tr("SAVE RECOVERY REQUIRED"),
			Color(0.95, 0.46, 0.40, 1.0)
		)
		rewarded_seal_button.disabled = true
		_show_rewarded_message(
			tr(
				"Reward could not be saved. Restart the game before "
				+ "watching another ad."
			),
			Color(0.95, 0.46, 0.40, 1.0)
		)
		return

	if remaining <= 0:
		_set_rewarded_state(
			tr("CYCLE LIMIT REACHED"),
			Color(0.60, 0.66, 0.64, 1.0)
		)
		rewarded_seal_button.text = tr(
			"NO REWARDED SEALS AVAILABLE"
		)
		rewarded_seal_button.disabled = true
		_show_rewarded_message(
			tr(
				"This cycle has no rewarded Seal claims remaining."
			),
			Color(0.68, 0.74, 0.72, 1.0)
		)
		return

	var policy: Dictionary = (
		MonetizationManager.get_rewarded_policy_status(
			RewardedBridge.PLACEMENT_ID
		)
	)
	var placement_claims: int = int(
		policy.get("placement_claims", 0)
	)
	var daily_limit: int = int(policy.get("daily_limit", 1))
	var cooldown_remaining: int = int(
		policy.get("cooldown_remaining_seconds", 0)
	)

	if placement_claims >= daily_limit:
		_set_rewarded_state(
			tr("CLAIMED TODAY"),
			Color(0.62, 0.72, 0.68, 1.0)
		)
		rewarded_seal_button.text = tr(
			"REWARDED SEAL CLAIMED TODAY"
		)
		rewarded_seal_button.disabled = true
		_show_rewarded_message(
			tr(
				"You already claimed today's rewarded Seal. "
				+ "Come back tomorrow."
			),
			Color(0.68, 0.76, 0.72, 1.0)
		)
		return

	if cooldown_remaining > 0:
		_set_rewarded_state(
			tr("COOLDOWN • %d SEC") % cooldown_remaining,
			Color(0.68, 0.76, 0.72, 1.0)
		)
		rewarded_seal_button.text = tr(
			"REWARDED AD COOLING DOWN"
		)
		rewarded_seal_button.disabled = true
		_show_rewarded_message(
			tr(
				"Please wait briefly before requesting another "
				+ "rewarded ad."
			),
			Color(0.68, 0.76, 0.72, 1.0)
		)
		return

	if bool(policy.get("available", false)):
		_set_rewarded_state(
			tr("READY • OPTIONAL"),
			JADE
		)
		rewarded_seal_button.disabled = false
		_show_rewarded_message("", JADE)
		return

	var runtime: Dictionary = (
		MonetizationManager.get_provider_runtime_status()
	)
	var provider_name: String = str(runtime.get("provider", ""))
	var provider_state: String = str(runtime.get("state", ""))

	if provider_name == "admob" and provider_state in [
		"consent_updating",
		"consent_form_loading",
		"consent_form_showing",
		"ads_initializing",
		"ads_initialized",
		"rewarded_loading",
	]:
		_set_rewarded_state(
			tr("REWARD PREPARING..."),
			Color(0.70, 0.80, 0.76, 1.0)
		)
		_show_rewarded_message(
			tr(
				"Preparing rewarded ad availability. "
				+ "This may take a moment."
			),
			Color(0.72, 0.82, 0.78, 1.0)
		)
	else:
		_set_rewarded_state(
			tr("REWARDED ADS UNAVAILABLE"),
			Color(0.62, 0.68, 0.66, 1.0)
		)
		_show_rewarded_message(
			tr("Rewarded ad unavailable. Try again shortly."),
			Color(0.76, 0.82, 0.78, 1.0)
		)
	rewarded_seal_button.disabled = true


func _set_rewarded_state(
	text_value: String,
	accent: Color
) -> void:
	if rewarded_seal_state_label == null:
		return
	rewarded_seal_state_label.text = text_value
	rewarded_seal_state_label.add_theme_color_override(
		"font_color",
		Color(
			maxf(accent.r, 0.58),
			maxf(accent.g, 0.66),
			maxf(accent.b, 0.64),
			1.0
		)
	)


func _request_rewarded_seal() -> void:
	if SaveManager.is_progress_read_only():
		_show_rewarded_message(
			tr(
				"Reward could not be saved. Restart the game before "
				+ "watching another ad."
			),
			Color(0.95, 0.46, 0.40, 1.0)
		)
		return

	if PavilionManager.get_rewarded_ad_claims_remaining() <= 0:
		_refresh_rewarded_seal_section()
		return

	if not MonetizationManager.show_rewarded(
		RewardedBridge.PLACEMENT_ID
	):
		_show_rewarded_message(
			tr("Rewarded ad unavailable. Try again shortly."),
			Color(0.76, 0.82, 0.78, 1.0)
		)
		_refresh_rewarded_seal_section()
		return

	rewarded_seal_button.disabled = true
	_show_rewarded_message(
		tr(
			"Reward is granted only after the ad confirms completion."
		),
		Color(0.76, 0.88, 0.84, 1.0)
	)


func _on_reward_delivery_finished(
	placement: String,
	success: bool,
	amount: int,
	_message: String
) -> void:
	if placement != RewardedBridge.PLACEMENT_ID:
		return

	if success:
		_show_rewarded_message(
			tr("Reward granted. +%d Pavilion Seal.") % amount,
			GOLD
		)
	else:
		_show_rewarded_message(
			tr(
				"Reward could not be saved. Restart the game before "
				+ "watching another ad."
			),
			Color(0.95, 0.46, 0.40, 1.0)
		)
	_refresh_rewarded_seal_section()


func _on_rewarded_request_finished(
	placement: String,
	status: String
) -> void:
	if placement != RewardedBridge.PLACEMENT_ID:
		return

	match status:
		"completed":
			pass
		"cancelled":
			_show_rewarded_message(
				tr(
					"Ad closed before reward. "
					+ "No Pavilion Seal granted."
				),
				Color(0.72, 0.80, 0.76, 1.0)
			)
		_:
			_show_rewarded_message(
				tr("Rewarded ad unavailable. Try again shortly."),
				Color(0.76, 0.82, 0.78, 1.0)
			)

	_refresh_rewarded_seal_section()


func _show_rewarded_message(
	message: String,
	accent: Color
) -> void:
	if rewarded_seal_message_label == null:
		return
	rewarded_seal_message_label.text = message
	rewarded_seal_message_label.add_theme_color_override(
		"font_color",
		accent
	)
	rewarded_seal_message_label.visible = not message.is_empty()
