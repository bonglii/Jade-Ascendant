extends Control

## REWARD FLY-TO-NAVBAR LAB v1
## Presentation sandbox only. It does not touch SaveManager, RewardManager,
## ProgressionManager, InventoryManager, PavilionManager, DailyQuestManager
## or AchievementManager.

const FlyController = preload(
	"res://scripts/ui/lab/reward_fly_to_navbar_controller.gd"
)

const TRIALS_BG_PATH: String = "res://assets/ui/trials/trials_hall.png"
const FRAME_PATH: String = "res://assets/ui/shared/hub_resource_bar_frame.svg"

const STONE_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/spirit_stone_premium.png"
)
const SHARD_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/refinement_shard_premium.png"
)
const JADE_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/celestial_jade_premium.png"
)
const SEAL_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/pavilion_seal_premium.png"
)

const GOLD := Color(0.96, 0.78, 0.34, 1.0)
const JADE := Color(0.25, 0.88, 0.72, 1.0)
const CYAN := Color(0.30, 0.78, 0.92, 1.0)

var resource_bar: Control
var overlay: Control
var fly_controller: RewardFlyToNavbarLabController
var single_button: Button
var claim_all_button: Button
var source_cards: Array[PanelContainer] = []


func _ready() -> void:
	_build_lab()


func _build_lab() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load(TRIALS_BG_PATH) as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.006, 0.012, 0.63)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	resource_bar = _build_resource_bar()
	add_child(resource_bar)

	var safe := MarginContainer.new()
	safe.anchor_left = 0.04
	safe.anchor_top = 0.0
	safe.anchor_right = 0.96
	safe.anchor_bottom = 1.0
	safe.offset_top = 86.0
	safe.offset_bottom = -24.0
	add_child(safe)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	safe.add_child(box)

	var lab_marker := Label.new()
	lab_marker.text = "REWARD FLY-TO-NAVBAR LAB  •  NO SAVE WRITES"
	lab_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab_marker.theme_type_variation = &"JadeSubtitle"
	lab_marker.add_theme_font_size_override("font_size", 12)
	lab_marker.add_theme_color_override("font_color", Color(0.64, 1.0, 0.88, 1.0))
	box.add_child(lab_marker)

	var title := Label.new()
	title.text = "REWARD DELIVERY MOTION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"JadeTitle"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Reward leaves the claim source, travels to the correct wallet slot, then the balance updates on impact."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.theme_type_variation = &"JadeMutedLabel"
	subtitle.add_theme_font_size_override("font_size", 13)
	box.add_child(subtitle)

	box.add_child(_build_single_demo())
	box.add_child(_build_claim_all_demo())

	var note := Label.new()
	note.text = "Target timing: 0.5–0.75 s  •  teal/gold trail  •  wallet pulse only on impact"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.theme_type_variation = &"JadeMutedLabel"
	note.add_theme_font_size_override("font_size", 11)
	box.add_child(note)

	overlay = Control.new()
	overlay.name = "FlyOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 200
	add_child(overlay)

	fly_controller = FlyController.new()
	fly_controller.name = "RewardFlyController"
	add_child(fly_controller)
	fly_controller.setup(overlay, resource_bar)
	fly_controller.animation_started.connect(_on_animation_started)
	fly_controller.animation_finished.connect(_on_animation_finished)


func _build_resource_bar() -> Control:
	var bar := Control.new()
	bar.name = "SharedHubResourceBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = 80
	bar.anchor_left = 0.03
	bar.anchor_top = 0.0
	bar.anchor_right = 0.97
	bar.anchor_bottom = 0.0
	bar.offset_bottom = 70.0

	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.texture = load(FRAME_PATH) as Texture2D
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(frame)

	var row := HBoxContainer.new()
	row.name = "ResourceRow"
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 9.0
	row.offset_top = 8.0
	row.offset_right = -9.0
	row.offset_bottom = -8.0
	row.add_theme_constant_override("separation", 0)
	bar.add_child(row)

	_add_resource_cell(row, STONE_ICON, "1420", "Spirit Stone")
	_add_resource_cell(row, SHARD_ICON, "18", "Refinement Shard")
	_add_resource_cell(row, JADE_ICON, "90", "Celestial Jade")
	_add_resource_cell(row, SEAL_ICON, "4", "Pavilion Seal")
	return bar


func _add_resource_cell(
	parent: HBoxContainer,
	texture: Texture2D,
	value_text: String,
	tooltip_text: String
) -> void:
	var cell := HBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", 4)
	cell.tooltip_text = tooltip_text
	parent.add_child(cell)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(27.0, 27.0)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)

	var value := Label.new()
	value.text = value_text
	value.custom_minimum_size = Vector2(38.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color(0.97, 0.92, 0.76, 1.0))
	cell.add_child(value)


func _build_single_demo() -> PanelContainer:
	var panel := _demo_panel("SINGLE CLAIM", "Daily Extermination", "+25 Spirit Stones")
	var box := panel.get_meta("box") as VBoxContainer

	var reward_row := HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 8)
	box.add_child(reward_row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(72.0, 72.0)
	icon.texture = STONE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reward_row.add_child(icon)

	var amount := Label.new()
	amount.text = "+25"
	amount.theme_type_variation = &"JadeTitle"
	amount.add_theme_font_size_override("font_size", 30)
	reward_row.add_child(amount)

	single_button = Button.new()
	single_button.name = "PlaySingleClaim"
	single_button.custom_minimum_size = Vector2(0.0, 52.0)
	single_button.theme_type_variation = &"JadePrimaryButton"
	single_button.text = "PLAY SINGLE CLAIM"
	single_button.add_theme_font_size_override("font_size", 14)
	single_button.pressed.connect(_on_single_pressed.bind(icon))
	box.add_child(single_button)

	source_cards.append(panel)
	return panel


func _build_claim_all_demo() -> PanelContainer:
	var panel := _demo_panel("CLAIM ALL", "Three rewards converge first", "+120 Spirit Stones total")
	var box := panel.get_meta("box") as VBoxContainer

	var sources := HBoxContainer.new()
	sources.alignment = BoxContainer.ALIGNMENT_CENTER
	sources.add_theme_constant_override("separation", 26)
	box.add_child(sources)

	for reward_amount: int in [25, 25, 70]:
		var chip := VBoxContainer.new()
		chip.alignment = BoxContainer.ALIGNMENT_CENTER
		sources.add_child(chip)

		var icon := TextureRect.new()
		icon.name = "SourceIcon"
		icon.custom_minimum_size = Vector2(46.0, 46.0)
		icon.texture = STONE_ICON
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip.add_child(icon)

		var label := Label.new()
		label.text = "+%d" % reward_amount
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		chip.add_child(label)

	claim_all_button = Button.new()
	claim_all_button.name = "PlayClaimAll"
	claim_all_button.custom_minimum_size = Vector2(0.0, 52.0)
	claim_all_button.theme_type_variation = &"JadePrimaryButton"
	claim_all_button.text = "PLAY CLAIM ALL"
	claim_all_button.add_theme_font_size_override("font_size", 14)
	claim_all_button.pressed.connect(_on_claim_all_pressed.bind(sources))
	box.add_child(claim_all_button)

	source_cards.append(panel)
	return panel


func _demo_panel(
	eyebrow_text: String,
	title_text: String,
	subtitle_text: String
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 246.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.024, 0.034, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.94, 0.74, 0.30, 0.64)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 7
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	panel.set_meta("box", box)

	var eyebrow := Label.new()
	eyebrow.text = eyebrow_text
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.theme_type_variation = &"JadeSubtitle"
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", CYAN)
	box.add_child(eyebrow)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"JadeHeroName"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.theme_type_variation = &"JadeCurrencyLabel"
	subtitle.add_theme_font_size_override("font_size", 13)
	box.add_child(subtitle)
	return panel


func _on_single_pressed(source_icon: TextureRect) -> void:
	var source := source_icon.get_global_rect().get_center()
	fly_controller.play_single("spirit_stone", 25, source)


func _on_claim_all_pressed(source_row: HBoxContainer) -> void:
	var positions: Array[Vector2] = []
	for child: Node in source_row.get_children():
		var source_icon := child.get_node_or_null("SourceIcon") as TextureRect
		if source_icon != null:
			positions.append(source_icon.get_global_rect().get_center())

	fly_controller.play_claim_all(
		"spirit_stone",
		[25, 25, 70],
		positions
	)


func _on_animation_started(_resource_key: String, _amount: int) -> void:
	single_button.disabled = true
	claim_all_button.disabled = true


func _on_animation_finished(_resource_key: String, _amount: int) -> void:
	single_button.disabled = false
	claim_all_button.disabled = false
