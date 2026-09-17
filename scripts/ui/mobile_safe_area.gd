extends Control

## Attach to a full-rect UI layer whose direct parent is a Control.
## Keep full-screen artwork outside this layer.
##
## Global UI consistency is applied here because this node already exists
## across the polished menu family and enters _ready() before the owning
## screen. Screen-specific local overrides remain authoritative.
##
## Mobile interaction pass:
## - Buttons nested inside ScrollContainer use PASS so drag gestures reach the
##   scroll parent instead of turning every attempted swipe into a tap.
## - An explicit deadzone keeps deliberate taps reliable after enabling PASS.
## - Contextual FTUE is device-local and does not touch gameplay save domains.

const REFRESH_INTERVAL: float = 0.25
const MOBILE_SCROLL_DEADZONE: int = 6
const ONBOARDING_PATH: String = "user://jade_onboarding.cfg"
const ONBOARDING_SECTION: String = "tutorials"
const ONBOARDING_META_SECTION: String = "meta"
const ONBOARDING_VERSION: int = 2
const ONBOARDING_OVERLAY_NAME: String = "JadeOnboardingOverlay"
const JadeUiGlobalStyle = preload(
	"res://scripts/ui/jade_ui_global_style.gd"
)

const ONBOARDING_STEPS: Dictionary = {
	"home": [
		{
			"eyebrow": "FIRST STEPS",
			"title": "BEGIN YOUR JOURNEY",
			"body": "ENTER JOURNEY is the main path forward. Choose a realm and stage, survive its waves, defeat the guardian, and unlock the next step of Lin Yue's ascension."
		},
		{
			"eyebrow": "PREPARE BETWEEN TRIALS",
			"title": "HERO & PAVILION",
			"body": "Use HERO to manage permanent equipment. Visit PAVILION for summoning, forging, meditation, and cultivation cosmetics. Both are always available from the bottom navigation."
		}
	],
	"equipment": [
		{
			"eyebrow": "HERO LOADOUT",
			"title": "FIVE PERMANENT SLOTS",
			"body": "Armament, Robe, Bracer, Boots, and Pendant shape Lin Yue before a run begins. Tap a slot to inspect the relics you own for that position."
		},
		{
			"eyebrow": "MOBILE CONTROLS",
			"title": "SWIPE TO BROWSE • TAP TO CHOOSE",
			"body": "Swipe vertically to browse equipment. Use a short tap to inspect or choose an item; dragging stays reserved for scrolling."
		}
	],
	"pavilion": [
		{
			"eyebrow": "JADE PAVILION",
			"title": "RESOURCES & CELESTIAL ARMORY",
			"body": "Spirit Stones support permanent growth. Refinement Shards support deterministic forging. Celestial Jade and Pavilion Seals power the Celestial Armory. Summoning unlocks after Chapter 1 • Stage 5."
		},
		{
			"eyebrow": "CHOOSE YOUR PATH",
			"title": "SUMMON OR FORGE",
			"body": "Summon from the progression-unlocked pool with visible rates and pity rules, or use Forge when you want a deterministic equipment path. Daily Meditation and cosmetic auras live here too."
		}
	]
}

var _refresh_elapsed: float = 0.0
var _mobile_display: bool = false
var _tutorial_key: String = ""
var _tutorial_step_index: int = 0
var _tutorial_overlay: ColorRect = null
var _tutorial_eyebrow_label: Label = null
var _tutorial_title_label: Label = null
var _tutorial_body_label: Label = null
var _tutorial_step_label: Label = null
var _tutorial_next_button: Button = null


func _ready() -> void:
	_mobile_display = (
		OS.has_feature("android")
		or OS.has_feature("ios")
	)

	JadeUiGlobalStyle.apply_from(self)

	get_viewport().size_changed.connect(_queue_refresh)

	var parent_control: Control = get_parent_control()
	if parent_control != null:
		parent_control.resized.connect(_queue_refresh)

	if _mobile_display and not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)

	set_process(_mobile_display)
	refresh_safe_area()
	_queue_refresh()
	call_deferred("_configure_mobile_scroll_input")
	call_deferred("_maybe_show_onboarding")


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)


func _process(delta: float) -> void:
	_refresh_elapsed += delta

	if _refresh_elapsed >= REFRESH_INTERVAL:
		_refresh_elapsed = 0.0
		refresh_safe_area()


func _queue_refresh() -> void:
	refresh_safe_area.call_deferred()


func refresh_safe_area() -> void:
	if not is_inside_tree():
		return

	var parent_control: Control = get_parent_control()

	if (
		parent_control == null
		or not parent_control.size.x > 0.0
		or not parent_control.size.y > 0.0
	):
		return

	var available_rect: Rect2 = Rect2(
		Vector2.ZERO,
		parent_control.size
	)
	var content_rect: Rect2 = available_rect

	if _mobile_display:
		var display_safe_rect: Rect2 = Rect2(
			DisplayServer.get_display_safe_area()
		)
		var parent_to_screen: Transform2D = (
			parent_control.get_screen_transform()
		)

		if (
			display_safe_rect.has_area()
			and not is_zero_approx(
				parent_to_screen.determinant()
			)
		):
			var local_safe_rect: Rect2 = (
				parent_to_screen.affine_inverse()
				* display_safe_rect
			)
			var intersection_rect: Rect2 = (
				available_rect.intersection(
					local_safe_rect
				)
			)

			if intersection_rect.has_area():
				content_rect = intersection_rect

	# Assign absolute insets, never accumulate padding on subsequent refreshes.
	offset_left = content_rect.position.x
	offset_top = content_rect.position.y
	offset_right = (
		content_rect.end.x
		- available_rect.end.x
	)
	offset_bottom = (
		content_rect.end.y
		- available_rect.end.y
	)


func _configure_mobile_scroll_input() -> void:
	if not _mobile_display or not is_inside_tree():
		return
	_configure_scroll_tree(self)


func _configure_scroll_tree(root_node: Node) -> void:
	for child_node: Node in root_node.get_children():
		if child_node is ScrollContainer:
			_configure_scroll_container(child_node as ScrollContainer)
		_configure_scroll_tree(child_node)


func _configure_scroll_container(scroll_container: ScrollContainer) -> void:
	scroll_container.scroll_deadzone = MOBILE_SCROLL_DEADZONE
	# Mobile uses direct touch drag, so keep vertical scrolling enabled while
	# hiding the desktop-style grabber/track on the right edge.
	if scroll_container.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_configure_scroll_descendants(scroll_container)


func _configure_scroll_descendants(root_node: Node) -> void:
	for child_node: Node in root_node.get_children():
		if child_node is ScrollContainer:
			_configure_scroll_container(child_node as ScrollContainer)
			continue
		if child_node is Control:
			var child_control := child_node as Control
			# Complex Pavilion/Trials cards contain nested panels and labels. A STOP
			# anywhere in that chain prevents the ScrollContainer from seeing the
			# finger drag. PASS preserves taps while allowing the scroll ancestor
			# to arbitrate the gesture. Existing IGNORE controls stay untouched.
			if child_control.mouse_filter == Control.MOUSE_FILTER_STOP:
				child_control.mouse_filter = Control.MOUSE_FILTER_PASS
		_configure_scroll_descendants(child_node)


func _on_tree_node_added(added_node: Node) -> void:
	if not _mobile_display or not is_inside_tree():
		return
	if added_node == self or not is_ancestor_of(added_node):
		return
	if added_node is ScrollContainer:
		_configure_scroll_container(added_node as ScrollContainer)
		return
	if added_node is Control and _find_scroll_ancestor(added_node) != null:
		var added_control := added_node as Control
		if added_control.mouse_filter == Control.MOUSE_FILTER_STOP:
			added_control.mouse_filter = Control.MOUSE_FILTER_PASS


func _find_scroll_ancestor(start_node: Node) -> ScrollContainer:
	var ancestor_node: Node = start_node.get_parent()
	while ancestor_node != null and ancestor_node != self:
		if ancestor_node is ScrollContainer:
			return ancestor_node as ScrollContainer
		ancestor_node = ancestor_node.get_parent()
	return null


func _maybe_show_onboarding() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	_prepare_onboarding_state()
	_tutorial_key = _tutorial_key_for_scene()
	if _tutorial_key.is_empty() or _is_tutorial_complete(_tutorial_key):
		return
	var tutorial_steps: Array = ONBOARDING_STEPS.get(_tutorial_key, [])
	if tutorial_steps.is_empty():
		return
	_build_onboarding_overlay()
	if not is_instance_valid(_tutorial_overlay):
		return
	_tutorial_step_index = 0
	_refresh_onboarding_step()


func _prepare_onboarding_state() -> void:
	var onboarding_config := ConfigFile.new()
	var load_error: Error = onboarding_config.load(ONBOARDING_PATH)
	var stored_version: int = 0
	if load_error == OK:
		stored_version = int(
			onboarding_config.get_value(
				ONBOARDING_META_SECTION,
				"version",
				0
			)
		)

	if stored_version >= ONBOARDING_VERSION:
		return

	# Migration rule: players who already cleared any stage before this FTUE
	# version existed are veterans. Do not interrupt an established account
	# with introductory menu cards after an update.
	if _is_established_player_before_ftue():
		for raw_tutorial_key in ONBOARDING_STEPS.keys():
			onboarding_config.set_value(
				ONBOARDING_SECTION,
				str(raw_tutorial_key),
				true
			)
		onboarding_config.set_value(
			ONBOARDING_META_SECTION,
			"veteran_migrated",
			true
		)

	onboarding_config.set_value(
		ONBOARDING_META_SECTION,
		"version",
		ONBOARDING_VERSION
	)
	onboarding_config.set_value(
		ONBOARDING_META_SECTION,
		"initialized",
		true
	)
	var save_error: Error = onboarding_config.save(ONBOARDING_PATH)
	if save_error != OK:
		push_warning(
			"Onboarding: gagal menyimpan state migrasi ke %s"
			% ONBOARDING_PATH
		)


func _is_established_player_before_ftue() -> bool:
	if not is_instance_valid(JourneyManager):
		return false
	return not JourneyManager.cleared_stage_keys.is_empty()


func _tutorial_key_for_scene() -> String:
	var current_scene_node: Node = get_tree().current_scene
	if current_scene_node == null:
		return ""
	var current_scene_path: String = current_scene_node.scene_file_path
	match current_scene_path:
		"res://scenes/ui/main_menu.tscn":
			return "home"
		"res://scenes/ui/equipment_screen.tscn":
			return "equipment"
		"res://scenes/ui/pavilion_screen.tscn":
			return "pavilion"
		_:
			return ""


func _is_tutorial_complete(tutorial_key: String) -> bool:
	var onboarding_config := ConfigFile.new()
	var load_error: Error = onboarding_config.load(ONBOARDING_PATH)
	if load_error != OK:
		return false
	return bool(onboarding_config.get_value(ONBOARDING_SECTION, tutorial_key, false))


func _mark_tutorial_complete() -> void:
	if _tutorial_key.is_empty():
		return
	var onboarding_config := ConfigFile.new()
	onboarding_config.load(ONBOARDING_PATH)
	onboarding_config.set_value(ONBOARDING_SECTION, _tutorial_key, true)
	onboarding_config.set_value(
		ONBOARDING_META_SECTION,
		"version",
		ONBOARDING_VERSION
	)
	var save_error: Error = onboarding_config.save(ONBOARDING_PATH)
	if save_error != OK:
		push_warning(
			"Onboarding: gagal menyimpan completion state ke %s"
			% ONBOARDING_PATH
		)


func _build_onboarding_overlay() -> void:
	var parent_control: Control = get_parent_control()
	if parent_control == null or parent_control.has_node(ONBOARDING_OVERLAY_NAME):
		return

	_tutorial_overlay = ColorRect.new()
	_tutorial_overlay.name = ONBOARDING_OVERLAY_NAME
	_tutorial_overlay.color = Color(0.0, 0.012, 0.018, 0.90)
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_overlay.z_index = 500
	parent_control.add_child(_tutorial_overlay)
	_tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center_container := CenterContainer.new()
	center_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_tutorial_overlay.add_child(center_container)
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tutorial_panel := PanelContainer.new()
	tutorial_panel.custom_minimum_size = Vector2(520.0, 0.0)
	tutorial_panel.add_theme_stylebox_override("panel", _onboarding_panel_style())
	center_container.add_child(tutorial_panel)

	var tutorial_box := VBoxContainer.new()
	tutorial_box.add_theme_constant_override("separation", 10)
	tutorial_panel.add_child(tutorial_box)

	_tutorial_step_label = Label.new()
	_tutorial_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tutorial_step_label.add_theme_font_size_override("font_size", 11)
	_tutorial_step_label.add_theme_color_override("font_color", Color(0.68, 0.82, 0.78, 1.0))
	tutorial_box.add_child(_tutorial_step_label)

	_tutorial_eyebrow_label = Label.new()
	_tutorial_eyebrow_label.add_theme_font_size_override("font_size", 12)
	_tutorial_eyebrow_label.add_theme_color_override("font_color", Color(0.42, 0.96, 0.80, 1.0))
	tutorial_box.add_child(_tutorial_eyebrow_label)

	_tutorial_title_label = Label.new()
	_tutorial_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_title_label.add_theme_font_size_override("font_size", 25)
	_tutorial_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52, 1.0))
	tutorial_box.add_child(_tutorial_title_label)

	var divider_line := ColorRect.new()
	divider_line.custom_minimum_size = Vector2(0.0, 2.0)
	divider_line.color = Color(0.32, 0.88, 0.72, 0.44)
	divider_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_box.add_child(divider_line)

	_tutorial_body_label = Label.new()
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_body_label.add_theme_font_size_override("font_size", 15)
	_tutorial_body_label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.91, 1.0))
	_tutorial_body_label.custom_minimum_size.y = 112.0
	tutorial_box.add_child(_tutorial_body_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	tutorial_box.add_child(button_row)

	var skip_button := Button.new()
	skip_button.name = "OnboardingSkipButton"
	skip_button.text = tr("SKIP GUIDE")
	skip_button.custom_minimum_size = Vector2(132.0, 52.0)
	skip_button.pressed.connect(_finish_onboarding)
	button_row.add_child(skip_button)

	_tutorial_next_button = Button.new()
	_tutorial_next_button.name = "OnboardingNextButton"
	_tutorial_next_button.text = tr("NEXT")
	_tutorial_next_button.custom_minimum_size = Vector2(0.0, 52.0)
	_tutorial_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_next_button.pressed.connect(_advance_onboarding)
	button_row.add_child(_tutorial_next_button)


func _onboarding_panel_style() -> StyleBoxFlat:
	var panel_style_box := StyleBoxFlat.new()
	panel_style_box.bg_color = Color(0.002, 0.028, 0.036, 0.985)
	panel_style_box.border_width_left = 2
	panel_style_box.border_width_top = 2
	panel_style_box.border_width_right = 2
	panel_style_box.border_width_bottom = 3
	panel_style_box.border_color = Color(0.82, 0.68, 0.30, 0.82)
	panel_style_box.corner_radius_top_left = 16
	panel_style_box.corner_radius_top_right = 16
	panel_style_box.corner_radius_bottom_left = 16
	panel_style_box.corner_radius_bottom_right = 16
	panel_style_box.content_margin_left = 24.0
	panel_style_box.content_margin_top = 22.0
	panel_style_box.content_margin_right = 24.0
	panel_style_box.content_margin_bottom = 22.0
	panel_style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	panel_style_box.shadow_size = 14
	return panel_style_box


func _refresh_onboarding_step() -> void:
	var tutorial_steps: Array = ONBOARDING_STEPS.get(_tutorial_key, [])
	if tutorial_steps.is_empty() or _tutorial_step_index >= tutorial_steps.size():
		_finish_onboarding()
		return
	var tutorial_data: Dictionary = tutorial_steps[_tutorial_step_index]
	_tutorial_step_label.text = "%d / %d" % [_tutorial_step_index + 1, tutorial_steps.size()]
	_tutorial_eyebrow_label.text = tr(str(tutorial_data.get("eyebrow", "")))
	_tutorial_title_label.text = tr(str(tutorial_data.get("title", "")))
	_tutorial_body_label.text = tr(str(tutorial_data.get("body", "")))
	_tutorial_next_button.text = (
		tr("GOT IT")
		if _tutorial_step_index >= tutorial_steps.size() - 1
		else tr("NEXT")
	)


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_tutorial_overlay):
		return

	if event.is_action_pressed("ui_accept"):
		_advance_onboarding()
		get_viewport().set_input_as_handled()
		return

	# Android Back / Esc closes only the FTUE modal. It must never leak into
	# the screen-level back handler and transition away behind the overlay.
	if event.is_action_pressed("ui_cancel"):
		_finish_onboarding()
		get_viewport().set_input_as_handled()


func _advance_onboarding() -> void:
	var tutorial_steps: Array = ONBOARDING_STEPS.get(_tutorial_key, [])
	if _tutorial_step_index >= tutorial_steps.size() - 1:
		_finish_onboarding()
		return
	_tutorial_step_index += 1
	_refresh_onboarding_step()


func _finish_onboarding() -> void:
	_mark_tutorial_complete()
	if is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.queue_free()
	_tutorial_overlay = null
	_tutorial_eyebrow_label = null
	_tutorial_title_label = null
	_tutorial_body_label = null
	_tutorial_step_label = null
	_tutorial_next_button = null
