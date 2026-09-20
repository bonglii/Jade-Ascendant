extends Node

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const MEDITATION_ICON: Texture2D = preload(
	"res://assets/ui/pavilion/icons/meditation.png"
)
const RewardedBridge = preload(
	"res://scripts/monetization/offline_cultivation_rewarded_bridge.gd"
)
const RewardedLocalization = preload(
	"res://scripts/monetization/monetization_localization.gd"
)

var manager: Node = null
var _attached_home_id: int = 0
var _shortcut: Button = null
var _badge: Label = null
var _popup: Control = null
var _modal_panel: PanelContainer = null
var _result_popup: Control = null
var _result_panel: PanelContainer = null
var _time_label: Label = null
var _tier_label: Label = null
var _rate_label: Label = null
var _reward_label: Label = null
var _hint_label: Label = null
var _claim_button: Button = null
var _rewarded_button: Button = null
var _progress_bar: ProgressBar = null
var _refresh_left: float = 0.0
var _auto_gap_seconds: int = 0
var _auto_shown: bool = false
var _claim_message: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RewardedLocalization.install()
	manager = get_parent()
	_auto_gap_seconds = int(manager.call("get_session_offline_seconds"))
	manager.connect("idle_state_changed", Callable(self, "_refresh_all"))
	manager.connect("idle_reward_claimed", Callable(self, "_on_reward_claimed"))
	manager.connect("offline_gap_detected", Callable(self, "_on_offline_gap"))
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
	call_deferred("_attach_to_home_if_needed")


func _process(delta: float) -> void:
	_attach_to_home_if_needed()
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = 1.0
	_refresh_all()


func _attach_to_home_if_needed() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var scene: Node = tree.current_scene
	if scene.scene_file_path != MAIN_MENU_SCENE:
		_attached_home_id = 0
		_shortcut = null
		_badge = null
		_popup = null
		_result_popup = null
		_result_panel = null
		return
	if not bool(manager.call("is_unlocked")):
		return

	var scene_id: int = int(scene.get_instance_id())
	if _attached_home_id != scene_id:
		var header: HBoxContainer = scene.get_node_or_null(
			"HomeUI/HomeActions/HeaderRow"
		) as HBoxContainer
		if header == null:
			return
		_attached_home_id = scene_id
		_build_shortcut(header)
	_refresh_shortcut()
	_maybe_auto_open()


func _build_shortcut(header: HBoxContainer) -> void:
	_shortcut = Button.new()
	_shortcut.name = "MeditationButton"
	_shortcut.custom_minimum_size = Vector2(128.0, 48.0)
	_shortcut.focus_mode = Control.FOCUS_NONE
	_shortcut.text = tr("MEDITATE")
	_shortcut.icon = MEDITATION_ICON
	_shortcut.expand_icon = true
	_shortcut.add_theme_font_size_override("font_size", 11)
	_shortcut.add_theme_color_override(
		"font_color",
		Color(0.88, 1.0, 0.94, 1.0)
	)
	_apply_shortcut_style(false)
	_shortcut.pressed.connect(_open_popup)
	header.add_child(_shortcut)

	_badge = Label.new()
	_badge.name = "MeditationReadyBadge"
	_badge.anchor_left = 1.0
	_badge.anchor_top = 0.0
	_badge.anchor_right = 1.0
	_badge.anchor_bottom = 0.0
	_badge.offset_left = -18.0
	_badge.offset_top = -4.0
	_badge.offset_right = 4.0
	_badge.offset_bottom = 18.0
	_badge.text = "!"
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 11)
	_badge.add_theme_color_override("font_color", Color(0.08, 0.05, 0.01, 1.0))
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(1.0, 0.78, 0.28, 0.98)
	badge_style.corner_radius_top_left = 9
	badge_style.corner_radius_top_right = 9
	badge_style.corner_radius_bottom_left = 9
	badge_style.corner_radius_bottom_right = 9
	_badge.add_theme_stylebox_override("normal", badge_style)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shortcut.add_child(_badge)


func _apply_shortcut_style(is_ready: bool) -> void:
	if _shortcut == null:
		return
	var border: Color = (
		Color(1.0, 0.78, 0.32, 0.82)
		if is_ready
		else Color(0.34, 0.88, 0.76, 0.48)
	)
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (
			Color(0.016, 0.090, 0.086, 0.98)
			if state_name == "hover"
			else Color(0.004, 0.040, 0.046, 0.96)
		)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = border
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		_shortcut.add_theme_stylebox_override(state_name, style)


func _refresh_shortcut() -> void:
	if _shortcut == null or not is_instance_valid(_shortcut):
		return
	var is_ready: bool = int(manager.call("get_claimable_units")) > 0
	if _badge != null:
		_badge.visible = is_ready
	_shortcut.tooltip_text = (
		tr("SPIRIT MEDITATION")
		+ "  •  "
		+ _format_duration(int(manager.call("get_claimable_seconds")))
	)
	_apply_shortcut_style(is_ready)


func _maybe_auto_open() -> void:
	if (
		_auto_shown
		or _popup != null
		or _result_popup != null
	):
		return
	if _auto_gap_seconds < int(manager.call("get_auto_popup_min_offline_seconds")):
		return
	if int(manager.call("get_claimable_units")) <= 0:
		return
	_auto_shown = true
	call_deferred("_open_popup")


func _on_offline_gap(seconds: int) -> void:
	_auto_gap_seconds = seconds
	_auto_shown = false


func _open_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		return
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path != MAIN_MENU_SCENE:
		return
	_claim_message = ""

	_popup = Control.new()
	_popup.name = "SpiritMeditationPopup"
	_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	_popup.z_index = 120
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	scene.add_child(_popup)
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.0, 0.0, 0.0, 0.62)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	_popup.add_child(scrim)

	var panel := PanelContainer.new()
	_modal_panel = panel
	panel.anchor_left = 0.105
	panel.anchor_top = 0.5
	panel.anchor_right = 0.895
	# Keep the modal centered vertically. Its height still comes entirely from
	# the actual content; no fixed-height dead space is reserved.
	panel.anchor_bottom = 0.5
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.003, 0.030, 0.037, 0.992),
			Color(0.83, 0.68, 0.30, 0.80),
			20
		)
	)
	_popup.add_child(panel)
	panel.modulate.a = 0.0
	var intro_tween: Tween = panel.create_tween()
	intro_tween.tween_property(panel, "modulate:a", 1.0, 0.12)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44.0, 44.0)
	icon.texture = MEDITATION_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", -1)
	header.add_child(title_box)

	var eyebrow := Label.new()
	eyebrow.text = tr("OFFLINE CULTIVATION")
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color(0.45, 0.92, 0.79, 1.0))
	title_box.add_child(eyebrow)

	var title := Label.new()
	title.text = tr("SPIRIT MEDITATION")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
	title_box.add_child(title)

	var close := Button.new()
	close.custom_minimum_size = Vector2(38.0, 38.0)
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(_close_popup)
	header.add_child(close)

	_tier_label = Label.new()
	_tier_label.add_theme_font_size_override("font_size", 14)
	_tier_label.add_theme_color_override("font_color", Color(0.75, 0.98, 0.90, 1.0))
	body.add_child(_tier_label)

	_time_label = Label.new()
	_time_label.custom_minimum_size = Vector2(0.0, 30.0)
	_time_label.add_theme_font_size_override("font_size", 20)
	_time_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.74, 1.0))
	body.add_child(_time_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0.0, 9.0)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = float(manager.call("get_accrual_cap_seconds"))
	_progress_bar.show_percentage = false
	_progress_bar.add_theme_stylebox_override(
		"background",
		_make_panel_style(Color(0.001, 0.014, 0.020, 0.95), Color(0.22, 0.54, 0.48, 0.40), 7)
	)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.20, 0.80, 0.66, 0.98)
	fill.border_width_top = 1
	fill.border_width_bottom = 1
	fill.border_color = Color(1.0, 0.78, 0.30, 0.90)
	fill.corner_radius_top_left = 7
	fill.corner_radius_top_right = 7
	fill.corner_radius_bottom_left = 7
	fill.corner_radius_bottom_right = 7
	_progress_bar.add_theme_stylebox_override("fill", fill)
	body.add_child(_progress_bar)

	_rate_label = Label.new()
	_rate_label.add_theme_font_size_override("font_size", 12)
	_rate_label.add_theme_color_override("font_color", Color(0.62, 0.82, 0.77, 0.96))
	_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_rate_label)

	var reward_panel := PanelContainer.new()
	reward_panel.custom_minimum_size = Vector2(0.0, 78.0)
	reward_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.025, 0.030, 0.020, 0.94), Color(0.95, 0.72, 0.24, 0.66), 14)
	)
	body.add_child(reward_panel)
	var reward_margin := MarginContainer.new()
	reward_margin.add_theme_constant_override("margin_left", 10)
	reward_margin.add_theme_constant_override("margin_top", 8)
	reward_margin.add_theme_constant_override("margin_right", 10)
	reward_margin.add_theme_constant_override("margin_bottom", 8)
	reward_panel.add_child(reward_margin)
	_reward_label = Label.new()
	_reward_label.add_theme_font_size_override("font_size", 17)
	_reward_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_margin.add_child(_reward_label)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.58, 0.75, 0.71, 1.0))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_hint_label)

	var claim_row := HBoxContainer.new()
	claim_row.add_theme_constant_override("separation", 6)
	body.add_child(claim_row)

	_claim_button = Button.new()
	_claim_button.custom_minimum_size = Vector2(0.0, 44.0)
	_claim_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_claim_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_claim_button.text = tr("CLAIM 1×")
	_claim_button.add_theme_font_size_override("font_size", 15)
	_claim_button.pressed.connect(_on_claim_pressed)
	claim_row.add_child(_claim_button)

	_rewarded_button = Button.new()
	_rewarded_button.custom_minimum_size = Vector2(0.0, 44.0)
	_rewarded_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rewarded_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_rewarded_button.text = tr("WATCH AD • 2×")
	_rewarded_button.add_theme_font_size_override("font_size", 14)
	_rewarded_button.add_theme_color_override(
		"font_color",
		Color(1.0, 0.87, 0.46, 1.0)
	)
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		var rewarded_style := StyleBoxFlat.new()
		rewarded_style.bg_color = Color(0.032, 0.050, 0.032, 0.98)
		rewarded_style.border_width_left = 1
		rewarded_style.border_width_top = 1
		rewarded_style.border_width_right = 1
		rewarded_style.border_width_bottom = 1
		rewarded_style.border_color = Color(0.93, 0.70, 0.25, 0.84)
		rewarded_style.corner_radius_top_left = 10
		rewarded_style.corner_radius_top_right = 10
		rewarded_style.corner_radius_bottom_left = 10
		rewarded_style.corner_radius_bottom_right = 10
		_rewarded_button.add_theme_stylebox_override(
			state_name,
			rewarded_style
		)
	_rewarded_button.pressed.connect(_on_rewarded_claim_pressed)
	claim_row.add_child(_rewarded_button)

	SceneTransitionManager.set_back_handler(Callable(self, "_close_popup"))
	_refresh_popup()
	call_deferred("_fit_modal_to_content")


func _fit_modal_to_content() -> void:
	if (
		_modal_panel == null
		or not is_instance_valid(_modal_panel)
	):
		return
	# Containers finish minimum-size propagation after the current layout pass.
	# Give the panel exactly that height; no decorative dead space is reserved.
	var required_height: float = ceil(
		_modal_panel.get_combined_minimum_size().y
	)
	var half_height: float = required_height * 0.5
	_modal_panel.offset_top = -half_height
	_modal_panel.offset_bottom = half_height


func _refresh_popup() -> void:
	if _popup == null or not is_instance_valid(_popup):
		return
	var seconds: int = int(manager.call("get_claimable_seconds"))
	var tier: int = int(manager.call("get_progress_tier"))
	var rates: Dictionary = manager.call("get_rates_for_tier", tier)
	var preview: Dictionary = manager.call("get_claim_preview")
	var reward: Dictionary = preview.get("reward_data", {})
	_tier_label.text = "QI RESONANCE %02d  •  %s" % [
		tier,
		tr(str(manager.call("get_tier_title", tier)))
	]
	_time_label.text = "%s  •  %s / 12H CAP" % [
		tr("ACCUMULATED"),
		_format_duration(seconds)
	]
	_progress_bar.value = float(seconds)
	var shard_text: String = tr("SHARDS LOCKED")
	var interval: int = int(rates.get("shard_interval_units", 0))
	if interval > 0:
		shard_text = "1 SHARD / %s" % _format_duration(
			interval * int(manager.call("get_claim_unit_seconds"))
		)
	_rate_label.text = "%d STONE / H  •  %d HERO EXP / H  •  %s" % [
		int(rates.get("spirit_stone_per_hour", 0)),
		int(rates.get("hero_exp_per_hour", 0)),
		shard_text
	]
	var reward_summary: String = RewardManager.get_reward_summary(
		reward,
		"Gathering Qi..."
	).replace("\n", "  •  ")
	_reward_label.text = "READY TO CLAIM\n" + reward_summary
	if _claim_message.is_empty():
		_hint_label.text = tr(
			"Optional ad doubles this claim only • free 1× claim remains available."
		)
	else:
		_hint_label.text = _claim_message

	var is_ready: bool = int(preview.get("claim_units", 0)) > 0
	var rewarded_pending: bool = bool(
		manager.call("has_pending_rewarded_double_claim")
	)
	var request_active: bool = MonetizationManager.is_rewarded_request_active(
		RewardedBridge.PLACEMENT_ID
	)
	var save_locked: bool = SaveManager.is_progress_read_only()

	_claim_button.disabled = (
		not is_ready
		or save_locked
		or rewarded_pending
		or request_active
	)
	_claim_button.text = (
		tr("CLAIM 1×")
		if is_ready
		else tr("GATHERING QI")
	)

	_rewarded_button.disabled = true
	if not is_ready:
		_rewarded_button.text = tr("2× AFTER 10M")
	elif save_locked:
		_rewarded_button.text = tr("2× AD UNAVAILABLE")
	elif rewarded_pending or request_active:
		_rewarded_button.text = tr("AD PLAYING...")
	else:
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
			_rewarded_button.text = tr("2× CLAIMED TODAY")
		elif cooldown_remaining > 0:
			_rewarded_button.text = (
				tr("2× AD • %dS") % cooldown_remaining
			)
		elif bool(policy.get("available", false)):
			_rewarded_button.text = tr("WATCH AD • 2×")
			_rewarded_button.disabled = false
		else:
			var runtime: Dictionary = (
				MonetizationManager.get_provider_runtime_status()
			)
			var provider_state: String = str(
				runtime.get("state", "")
			)
			if provider_state in [
				"consent_updating",
				"consent_form_loading",
				"consent_form_showing",
				"ads_initializing",
				"ads_initialized",
				"rewarded_loading",
			]:
				_rewarded_button.text = tr("2× AD • PREPARING")
			else:
				_rewarded_button.text = tr("2× AD UNAVAILABLE")

	call_deferred("_fit_modal_to_content")


func _refresh_all() -> void:
	_refresh_shortcut()
	_refresh_popup()


func _on_claim_pressed() -> void:
	var result: Dictionary = manager.call("claim_idle_reward")
	if not bool(result.get("success", false)):
		_claim_message = str(result.get("error", "Claim failed."))
		_refresh_popup()


func _on_rewarded_claim_pressed() -> void:
	if not bool(manager.call("prepare_rewarded_double_claim")):
		_claim_message = tr("Rewarded ad unavailable. Try again shortly.")
		_refresh_popup()
		return

	if not MonetizationManager.show_rewarded(
		RewardedBridge.PLACEMENT_ID
	):
		manager.call("cancel_pending_rewarded_double_claim")
		_claim_message = tr("Rewarded ad unavailable. Try again shortly.")
		_refresh_popup()
		return

	_claim_message = tr(
		"Watch the optional ad to receive exactly 2× the reward shown above."
	)
	_refresh_popup()


func _on_reward_delivery_finished(
	placement: String,
	success: bool,
	_multiplier: int,
	message: String
) -> void:
	if placement != RewardedBridge.PLACEMENT_ID:
		return
	if success:
		# Success UI is owned by _on_reward_claimed(), which receives the
		# exact reward payload committed by RewardManager.
		return
	_claim_message = (
		message
		if not message.is_empty()
		else tr(
			"Reward could not be saved. Restart the game before watching another ad."
		)
	)
	_refresh_all()


func _on_rewarded_request_finished(
	placement: String,
	status: String
) -> void:
	if placement != RewardedBridge.PLACEMENT_ID:
		return
	if status == "cancelled":
		manager.call("cancel_pending_rewarded_double_claim")
		_claim_message = tr(
			"Ad closed before reward. Free 1× claim is still available."
		)
	elif status != "completed":
		manager.call("cancel_pending_rewarded_double_claim")
		_claim_message = tr(
			"Rewarded ad unavailable. Try again shortly."
		)
	_refresh_popup()


func _on_reward_claimed(reward_data: Dictionary) -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("_refresh_home"):
		scene.call("_refresh_home")
	_close_popup()
	_show_claim_result(reward_data)
	_refresh_shortcut()


func _show_claim_result(reward_data: Dictionary) -> void:
	_close_result_popup()
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path != MAIN_MENU_SCENE:
		return

	_result_popup = Control.new()
	_result_popup.name = "MeditationClaimResultPopup"
	_result_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	_result_popup.z_index = 140
	_result_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	scene.add_child(_result_popup)
	_result_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.0, 0.0, 0.0, 0.54)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_result_scrim_input)
	_result_popup.add_child(scrim)

	_result_panel = PanelContainer.new()
	_result_panel.anchor_left = 0.145
	_result_panel.anchor_top = 0.5
	_result_panel.anchor_right = 0.855
	_result_panel.anchor_bottom = 0.5
	_result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.004, 0.030, 0.036, 0.995),
			Color(0.86, 0.70, 0.30, 0.92),
			18
		)
	)
	_result_popup.add_child(_result_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_result_panel.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 9)
	body.add_child(header)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(42.0, 42.0)
	icon.texture = MEDITATION_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", -1)
	header.add_child(title_box)

	var eyebrow := Label.new()
	eyebrow.text = tr("SPIRIT MEDITATION")
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override(
		"font_color",
		Color(0.45, 0.92, 0.79, 1.0)
	)
	title_box.add_child(eyebrow)

	var title := Label.new()
	title.text = tr("CULTIVATION CLAIMED")
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override(
		"font_color",
		Color(1.0, 0.85, 0.44, 1.0)
	)
	title_box.add_child(title)

	var close := Button.new()
	close.custom_minimum_size = Vector2(36.0, 36.0)
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 17)
	close.pressed.connect(_close_result_popup)
	header.add_child(close)

	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 2)
	body.add_child(divider)

	var received := Label.new()
	received.text = tr("REWARDS RECEIVED")
	received.add_theme_font_size_override("font_size", 13)
	received.add_theme_color_override(
		"font_color",
		Color(0.66, 0.82, 0.77, 1.0)
	)
	body.add_child(received)

	var reward_card := PanelContainer.new()
	reward_card.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.018, 0.040, 0.036, 0.98),
			Color(0.28, 0.72, 0.60, 0.55),
			12
		)
	)
	body.add_child(reward_card)

	var reward_margin := MarginContainer.new()
	reward_margin.add_theme_constant_override("margin_left", 12)
	reward_margin.add_theme_constant_override("margin_top", 9)
	reward_margin.add_theme_constant_override("margin_right", 12)
	reward_margin.add_theme_constant_override("margin_bottom", 9)
	reward_card.add_child(reward_margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	reward_margin.add_child(rows)
	_add_claim_result_rows(rows, reward_data)

	var saved := Label.new()
	saved.text = tr("Saved to your cultivation progress.")
	saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	saved.add_theme_font_size_override("font_size", 12)
	saved.add_theme_color_override(
		"font_color",
		Color(0.56, 0.72, 0.68, 1.0)
	)
	body.add_child(saved)

	var continue_button := Button.new()
	continue_button.custom_minimum_size = Vector2(0.0, 42.0)
	continue_button.text = tr("CONTINUE")
	continue_button.add_theme_font_size_override("font_size", 15)
	continue_button.pressed.connect(_close_result_popup)
	body.add_child(continue_button)

	_result_panel.modulate.a = 0.0
	var intro_tween: Tween = _result_panel.create_tween()
	intro_tween.tween_property(
		_result_panel,
		"modulate:a",
		1.0,
		0.12
	)
	call_deferred("_fit_result_popup_to_content")
	SceneTransitionManager.set_back_handler(
		Callable(self, "_close_result_popup")
	)


func _add_claim_result_rows(
	rows: VBoxContainer,
	reward_data: Dictionary
) -> void:
	var added: int = 0
	var spirit_stone: int = maxi(
		int(reward_data.get(
			RewardManager.REWARD_KEY_SPIRIT_STONE,
			0
		)),
		0
	)
	if spirit_stone > 0:
		_add_claim_result_row(
			rows,
			tr("SPIRIT STONE"),
			spirit_stone,
			Color(1.0, 0.84, 0.38, 1.0)
		)
		added += 1

	var hero_exp: int = maxi(
		int(reward_data.get(
			RewardManager.REWARD_KEY_HERO_EXP,
			0
		)),
		0
	)
	if hero_exp > 0:
		_add_claim_result_row(
			rows,
			tr("HERO EXP"),
			hero_exp,
			Color(0.45, 0.92, 0.79, 1.0)
		)
		added += 1

	var raw_items: Variant = reward_data.get(
		RewardManager.REWARD_KEY_ITEMS,
		{}
	)
	if raw_items is Dictionary:
		var item_ids: Array[String] = []
		for raw_item_id: Variant in raw_items.keys():
			item_ids.append(str(raw_item_id))
		item_ids.sort()
		for item_id: String in item_ids:
			var amount: int = maxi(
				int(raw_items.get(item_id, 0)),
				0
			)
			if amount <= 0:
				continue
			var display_name: String = item_id
			if InventoryManager.is_known_item(item_id):
				var item_data: Dictionary = (
					InventoryManager.get_item_data(item_id)
				)
				display_name = str(
					item_data.get("display_name", item_id)
				)
			_add_claim_result_row(
				rows,
				tr(display_name).to_upper(),
				amount,
				Color(0.72, 0.86, 1.0, 1.0)
			)
			added += 1

	if added <= 0:
		var empty := Label.new()
		empty.text = tr("No Reward")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override(
			"font_color",
			Color(0.68, 0.74, 0.72, 1.0)
		)
		rows.add_child(empty)


func _add_claim_result_row(
	rows: VBoxContainer,
	label_text: String,
	amount: int,
	accent: Color
) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 40.0)
	rows.add_child(row)

	var marker := Label.new()
	marker.custom_minimum_size = Vector2(20.0, 0.0)
	marker.text = "•"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 20)
	marker.add_theme_color_override("font_color", accent)
	row.add_child(marker)

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = label_text
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override(
		"font_color",
		Color(0.80, 0.90, 0.87, 1.0)
	)
	row.add_child(name_label)

	var amount_label := Label.new()
	amount_label.text = "+%d" % maxi(amount, 0)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.add_theme_font_size_override("font_size", 18)
	amount_label.add_theme_color_override("font_color", accent)
	row.add_child(amount_label)


func _fit_result_popup_to_content() -> void:
	if (
		_result_panel == null
		or not is_instance_valid(_result_panel)
	):
		return
	var required_height: float = ceil(
		_result_panel.get_combined_minimum_size().y
	)
	var half_height: float = required_height * 0.5
	_result_panel.offset_top = -half_height
	_result_panel.offset_bottom = half_height


func _on_result_scrim_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
	) or (
		event is InputEventScreenTouch
		and (event as InputEventScreenTouch).pressed
	):
		_close_result_popup()


func _close_result_popup() -> void:
	if _result_popup != null and is_instance_valid(_result_popup):
		_result_popup.queue_free()
	_result_popup = null
	_result_panel = null
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("handle_system_back"):
		SceneTransitionManager.set_back_handler(
			Callable(scene, "handle_system_back")
		)
	else:
		SceneTransitionManager.set_back_handler(Callable())


func _on_scrim_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
	) or (
		event is InputEventScreenTouch
		and (event as InputEventScreenTouch).pressed
	):
		_close_popup()


func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null
	_modal_panel = null
	_time_label = null
	_tier_label = null
	_rate_label = null
	_reward_label = null
	_hint_label = null
	_claim_button = null
	_rewarded_button = null
	_progress_bar = null
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("handle_system_back"):
		SceneTransitionManager.set_back_handler(
			Callable(scene, "handle_system_back")
		)
	else:
		SceneTransitionManager.set_back_handler(Callable())


func _format_duration(seconds: int) -> String:
	var safe_seconds: int = maxi(seconds, 0)
	var hours: int = floori(float(safe_seconds) / 3600.0)
	var minutes: int = floori(float(safe_seconds % 3600) / 60.0)
	if hours > 0:
		return "%dH %02dM" % [hours, minutes]
	return "%dM" % minutes


func _make_panel_style(
	background: Color,
	border: Color,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
