extends Control

## Cultivation Hub — production presentation.
## Approved Cultivate LAB V13 visual contract integrated with real progression.
## ProgressionManager remains the sole authority for permanent cultivation state,
## Spirit Stone costs, purchase validation and save persistence.
## SharedHubResourceBar and WuxiaHubNav remain the locked production chrome.

const UI_FONT: Font = preload("res://addons/admob/assets/fonts/NotoSansSC-Regular.otf")

const SPIRIT_STONE_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/spirit_stone_premium.png"
)
const APPROVED_SANCTUM_BG: Texture2D = preload(
	"res://assets/ui/cultivation/cultivation_inner_sea_sanctum_v6.png"
)

const PATH_ICONS: Dictionary = {
	"vitality": preload("res://assets/ui/cultivation/meridian_vitality.png"),
	"sword_power": preload("res://assets/ui/cultivation/meridian_sword_power.png"),
	"swift_qi": preload("res://assets/ui/cultivation/meridian_swift_qi.png"),
}

const MeridianMapScript = preload(
	"res://scripts/ui/cultivation_formation.gd"
)
const BreakthroughFxScript = preload(
	"res://scripts/ui/cultivation_breakthrough_fx.gd"
)

const MOBILE_SCROLL_DEADZONE: int = 6
const PRESS_SCROLL_CANCEL_DISTANCE: int = 6

const HEALTH_PER_VITALITY_LEVEL: int = 5
const SWORD_POWER_PERCENT_PER_LEVEL: int = 10
const SWIFT_QI_COOLDOWN_MULTIPLIER: float = 0.95
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

const GOLD := Color(0.98, 0.79, 0.32, 1.0)
const GOLD_BRIGHT := Color(1.0, 0.91, 0.62, 1.0)
const JADE := Color(0.28, 0.93, 0.73, 1.0)
const TEXT := Color(0.93, 0.96, 0.94, 1.0)
const MUTED := Color(0.67, 0.78, 0.75, 1.0)

const PATH_IDS: Array[String] = ["vitality", "sword_power", "swift_qi"]
const PATH_DATA: Dictionary = {
	"vitality": {
		"name": "Vitality",
		"kicker": "BODY MERIDIAN",
		"doctrine": "TEMPER THE VESSEL",
		"description": "Fortify Lin Yue's body so every journey begins with a deeper reservoir of life and qi.",
		"accent": Color(0.34, 0.98, 0.67, 1.0),
	},
	"sword_power": {
		"name": "Sword Power",
		"kicker": "SWORD DAO MERIDIAN",
		"doctrine": "CONDENSE SWORD INTENT",
		"description": "Compress sword intent into a permanent edge that empowers every weapon technique.",
		"accent": Color(1.0, 0.76, 0.25, 1.0),
	},
	"swift_qi": {
		"name": "Swift Qi",
		"kicker": "FLOWING QI MERIDIAN",
		"doctrine": "QUICKEN THE INNER CURRENT",
		"description": "Open the meridian flow so spiritual power cycles faster between attacks.",
		"accent": Color(0.28, 0.86, 1.0, 1.0),
	},
}

var selected_path: String = "vitality"

@onready var content_host: Control = $Content

var body_scroll: ScrollContainer = null
var body_content: VBoxContainer = null
var mastery_value: Label = null
var mastery_meter: ProgressBar = null
var meridian_map: Control = null
var selected_icon: TextureRect = null
var selected_kicker: Label = null
var selected_name: Label = null
var selected_doctrine: Label = null
var selected_level: Label = null
var selected_description: Label = null
var current_value: Label = null
var next_value: Label = null
var cost_value: Label = null
var refine_button: Button = null
var refine_hint: Label = null
var focus_sheet: PanelContainer = null
var focus_accent: ColorRect = null
var result_layer: Control = null
var result_panel: PanelContainer = null
var result_icon: TextureRect = null
var result_kicker: Label = null
var result_name: Label = null
var result_transition: Label = null
var result_effect: Label = null
var result_spend: Label = null
var result_message: Label = null
var result_before_value: Label = null
var result_after_value: Label = null
var result_cost_value: Label = null
var result_fx: Control = null
var _refine_press_scroll_y: int = 0
var result_tween: Tween = null
var intro_tween: Tween = null

func _ready() -> void:
	SceneTransitionManager.set_back_handler(handle_system_back)
	_build_atmosphere()
	_build_body()
	_build_result_layer()
	if not ProgressionManager.cultivation_upgraded.is_connected(_on_cultivation_upgraded):
		ProgressionManager.cultivation_upgraded.connect(_on_cultivation_upgraded)
	_refresh_all()
	resized.connect(_layout_result_panel)
	call_deferred("_layout_result_panel")
	call_deferred("_configure_mobile_scroll")
	call_deferred("_play_intro")
	DebugLogger.system("Cultivation production presentation active.")

func _build_atmosphere() -> void:
	var background := TextureRect.new()
	background.name = "ApprovedCultivationSanctum"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture = APPROVED_SANCTUM_BG
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.z_index = -100
	add_child(background)

	var readability_veil := ColorRect.new()
	readability_veil.name = "SanctumReadabilityVeil"
	readability_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	readability_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readability_veil.color = Color(0.002, 0.020, 0.028, 0.28)
	readability_veil.z_index = -99
	add_child(readability_veil)

	var upper_glass := ColorRect.new()
	upper_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upper_glass.anchor_left = 0.0
	upper_glass.anchor_top = 0.0
	upper_glass.anchor_right = 1.0
	upper_glass.anchor_bottom = 0.34
	upper_glass.color = Color(0.0, 0.018, 0.026, 0.22)
	upper_glass.z_index = -98
	add_child(upper_glass)

	var lower_glass := ColorRect.new()
	lower_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower_glass.anchor_left = 0.0
	lower_glass.anchor_top = 0.67
	lower_glass.anchor_right = 1.0
	lower_glass.anchor_bottom = 1.0
	lower_glass.color = Color(0.0, 0.012, 0.020, 0.30)
	lower_glass.z_index = -98
	add_child(lower_glass)

func _build_body() -> void:
	body_scroll = ScrollContainer.new()
	body_scroll.name = "CultivateProductionScroll"
	body_scroll.anchor_left = 0.025
	body_scroll.anchor_top = 0.0
	body_scroll.anchor_right = 0.975
	body_scroll.anchor_bottom = 1.0
	body_scroll.offset_top = 76.0
	body_scroll.offset_bottom = -102.0
	body_scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	body_scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.scroll_deadzone = MOBILE_SCROLL_DEADZONE
	content_host.add_child(body_scroll)

	body_content = VBoxContainer.new()
	body_content.name = "CultivateProductionBody"
	body_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_content.add_theme_constant_override("separation", 14)
	body_scroll.add_child(body_content)

	body_content.add_child(_build_intro())
	body_content.add_child(_build_ritual_stage())
	body_content.add_child(_build_focus_sheet())
	body_content.add_child(_build_footer_ornament())
	body_content.add_child(_spacer(2.0))

func _build_intro() -> Control:
	var host := MarginContainer.new()
	host.custom_minimum_size = Vector2(0.0, 142.0)
	host.add_theme_constant_override("margin_left", 10)
	host.add_theme_constant_override("margin_right", 10)
	host.add_theme_constant_override("margin_top", 3)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	host.add_child(box)

	var eyebrow := _label("INNER SEA  /  PERMANENT CULTIVATION", 13, JADE)
	box.add_child(eyebrow)

	var title := _label("ASCEND THE MERIDIANS", 35, GOLD_BRIGHT)
	title.add_theme_constant_override("outline_size", 3)
	box.add_child(title)

	var subtitle := _label(
		"Temper the vessel, condense sword intent, and awaken the current of qi.",
		17,
		Color(0.84, 0.91, 0.89, 1.0)
	)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle)

	var mastery_row := HBoxContainer.new()
	mastery_row.add_theme_constant_override("separation", 10)
	box.add_child(mastery_row)

	var mastery_kicker := _label("DAO FOUNDATION", 13, Color(0.74, 0.84, 0.81, 1.0))
	mastery_row.add_child(mastery_kicker)

	mastery_value = _label("4 / 30", 16, GOLD_BRIGHT)
	mastery_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mastery_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mastery_row.add_child(mastery_value)

	mastery_meter = ProgressBar.new()
	mastery_meter.custom_minimum_size = Vector2(0.0, 10.0)
	mastery_meter.show_percentage = false
	mastery_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mastery_meter.add_theme_stylebox_override(
		"background",
		_meter_style(Color(0.002, 0.023, 0.031, 0.92), Color(0.21, 0.53, 0.48, 0.30))
	)
	mastery_meter.add_theme_stylebox_override(
		"fill",
		_meter_style(Color(0.27, 0.89, 0.70, 0.98), Color(0.98, 0.80, 0.36, 0.78))
	)
	box.add_child(mastery_meter)
	return host

func _build_ritual_stage() -> Control:
	var host := Control.new()
	host.name = "MeridianRitualStage"
	host.custom_minimum_size = Vector2(0.0, 600.0)
	host.mouse_filter = Control.MOUSE_FILTER_PASS

	var section_kicker := _label("MERIDIAN RITUAL ARRAY", 13, Color(0.66, 0.82, 0.78, 1.0))
	section_kicker.position = Vector2(10.0, 2.0)
	section_kicker.size = Vector2(280.0, 22.0)
	host.add_child(section_kicker)

	var section_title := _label("Three Paths. One Dao Core.", 25, TEXT)
	section_title.position = Vector2(10.0, 24.0)
	section_title.size = Vector2(460.0, 32.0)
	host.add_child(section_title)

	var rule := ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.color = Color(0.29, 0.90, 0.72, 0.22)
	rule.position = Vector2(10.0, 61.0)
	rule.size = Vector2(310.0, 1.0)
	host.add_child(rule)

	meridian_map = Control.new()
	meridian_map.name = "MeridianRitualArray"
	meridian_map.anchor_left = 0.0
	meridian_map.anchor_top = 0.0
	meridian_map.anchor_right = 1.0
	meridian_map.anchor_bottom = 1.0
	meridian_map.offset_left = 0.0
	meridian_map.offset_top = 67.0
	meridian_map.offset_right = 0.0
	meridian_map.offset_bottom = 0.0
	meridian_map.mouse_filter = Control.MOUSE_FILTER_PASS
	meridian_map.set_script(MeridianMapScript)
	host.add_child(meridian_map)
	meridian_map.connect("path_selected", _on_path_selected)
	return host

func _build_focus_sheet() -> PanelContainer:
	focus_sheet = PanelContainer.new()
	focus_sheet.name = "SelectedMeridianSheet"
	focus_sheet.custom_minimum_size = Vector2(0.0, 352.0)
	focus_sheet.add_theme_stylebox_override(
		"panel",
		_sheet_style(Color(0.002, 0.020, 0.029, 0.86), Color(0.32, 0.86, 0.74, 0.40))
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 17)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 17)
	focus_sheet.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	focus_accent = ColorRect.new()
	focus_accent.custom_minimum_size = Vector2(0.0, 3.0)
	focus_accent.color = GOLD
	focus_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(focus_accent)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 13)
	box.add_child(header)

	selected_icon = TextureRect.new()
	selected_icon.custom_minimum_size = Vector2(96.0, 96.0)
	selected_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selected_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	selected_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(selected_icon)

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	header.add_child(names)

	selected_kicker = _label("SWORD DAO MERIDIAN", 14, GOLD)
	names.add_child(selected_kicker)

	selected_name = _label("Sword Power", 33, TEXT)
	names.add_child(selected_name)

	selected_doctrine = _label("CONDENSE SWORD INTENT", 15, Color(0.78, 0.87, 0.84, 1.0))
	names.add_child(selected_doctrine)

	selected_level = _label("LV 1 / 10", 18, GOLD_BRIGHT)
	selected_level.custom_minimum_size = Vector2(96.0, 0.0)
	selected_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	selected_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(selected_level)

	selected_description = _label("", 18, Color(0.86, 0.93, 0.91, 1.0))
	selected_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_description.custom_minimum_size = Vector2(0.0, 58.0)
	box.add_child(selected_description)

	var effect_row := HBoxContainer.new()
	effect_row.add_theme_constant_override("separation", 18)
	box.add_child(effect_row)

	var current_column := _effect_column("CURRENT FOUNDATION", JADE)
	current_value = current_column.get_node("Value") as Label
	effect_row.add_child(current_column)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(1.0, 62.0)
	divider.color = Color(0.44, 0.76, 0.69, 0.18)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_row.add_child(divider)

	var next_column := _effect_column("AFTER REFINEMENT", GOLD)
	next_value = next_column.get_node("Value") as Label
	effect_row.add_child(next_column)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 11)
	box.add_child(action_row)

	var cost_group := VBoxContainer.new()
	cost_group.custom_minimum_size = Vector2(142.0, 70.0)
	cost_group.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_group.add_theme_constant_override("separation", 2)
	action_row.add_child(cost_group)

	var cost_caption := _label("REFINEMENT COST", 11, Color(0.68, 0.79, 0.76, 1.0))
	cost_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_group.add_child(cost_caption)

	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 5)
	cost_group.add_child(cost_row)

	var cost_icon := TextureRect.new()
	cost_icon.custom_minimum_size = Vector2(30.0, 30.0)
	cost_icon.texture = SPIRIT_STONE_ICON
	cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_child(cost_icon)

	cost_value = _label("200", 19, GOLD_BRIGHT)
	cost_row.add_child(cost_value)

	refine_button = Button.new()
	refine_button.name = "RefineMeridianButton"
	refine_button.custom_minimum_size = Vector2(0.0, 70.0)
	refine_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refine_button.text = "REFINE MERIDIAN"
	refine_button.add_theme_font_override("font", UI_FONT)
	refine_button.add_theme_font_size_override("font_size", 20)
	refine_button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.73, 1.0))
	refine_button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.86, 1.0))
	refine_button.add_theme_color_override("font_disabled_color", Color(0.48, 0.56, 0.54, 0.82))
	refine_button.add_theme_stylebox_override("normal", _refine_style(Color(0.012, 0.105, 0.091, 0.98), GOLD, 7))
	refine_button.add_theme_stylebox_override("hover", _refine_style(Color(0.018, 0.158, 0.130, 0.99), GOLD_BRIGHT, 11))
	refine_button.add_theme_stylebox_override("pressed", _refine_style(Color(0.004, 0.064, 0.068, 1.0), JADE, 2))
	refine_button.add_theme_stylebox_override("disabled", _refine_style(Color(0.010, 0.020, 0.026, 0.84), Color(0.25, 0.32, 0.32, 0.58), 0))
	refine_button.mouse_filter = Control.MOUSE_FILTER_PASS
	refine_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	refine_button.keep_pressed_outside = false
	refine_button.button_down.connect(_on_refine_button_down)
	refine_button.pressed.connect(_on_refine_pressed)
	action_row.add_child(refine_button)

	refine_hint = _label("Permanent cultivation • persists between journeys", 14, MUTED)
	refine_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(refine_hint)
	return focus_sheet

func _effect_column(caption_text: String, accent: Color) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)

	var caption := _label(caption_text, 13, Color(0.69, 0.81, 0.78, 1.0))
	column.add_child(caption)

	var value := _label("+10% POWER", 21, accent)
	value.name = "Value"
	column.add_child(value)
	return column

func _build_footer_ornament() -> Control:
	var host := Control.new()
	host.name = "InnerSeaFooter"
	host.custom_minimum_size = Vector2(0.0, 46.0)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := ColorRect.new()
	left.color = Color(JADE.r, JADE.g, JADE.b, 0.18)
	left.position = Vector2(20.0, 28.0)
	left.size = Vector2(150.0, 1.0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(left)

	var right := ColorRect.new()
	right.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.18)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -170.0
	right.offset_right = -20.0
	right.offset_top = 28.0
	right.offset_bottom = 29.0
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(right)

	var seal := _label("◇", 18, GOLD)
	seal.anchor_left = 0.5
	seal.anchor_right = 0.5
	seal.offset_left = -20.0
	seal.offset_right = 20.0
	seal.offset_top = 16.0
	seal.offset_bottom = 42.0
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.add_child(seal)

	var copy := _label("PERMANENT CULTIVATION  •  THREE MERIDIANS  •  ONE DAO", 11, Color(0.57, 0.70, 0.67, 0.88))
	copy.anchor_left = 0.0
	copy.anchor_right = 1.0
	copy.offset_top = 45.0
	copy.offset_bottom = 68.0
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.add_child(copy)
	return host

func _build_result_layer() -> void:
	result_layer = Control.new()
	result_layer.name = "BreakthroughResultLayer"
	result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.visible = false
	result_layer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	result_layer.z_index = 300
	add_child(result_layer)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.006, 0.012, 0.79)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	result_layer.add_child(dim)

	result_fx = Control.new()
	result_fx.name = "BreakthroughRitualFx"
	result_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_fx.set_script(BreakthroughFxScript)
	result_layer.add_child(result_fx)

	result_panel = PanelContainer.new()
	result_panel.anchor_left = 0.045
	result_panel.anchor_top = 0.0
	result_panel.anchor_right = 0.955
	result_panel.anchor_bottom = 0.0
	result_panel.offset_top = 112.0
	result_panel.offset_bottom = 762.0
	result_panel.add_theme_stylebox_override("panel", _result_style(GOLD))
	result_layer.add_child(result_panel)

	var result_shell := VBoxContainer.new()
	result_shell.name = "BreakthroughResultShell"
	result_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_shell.alignment = BoxContainer.ALIGNMENT_BEGIN
	result_shell.add_theme_constant_override("separation", 6)
	result_panel.add_child(result_shell)

	# Breakthrough result is intentionally NOT scrollable. The complete result,
	# comparison, spend summary, and RETURN TO INNER SEA CTA must all be visible
	# in the first frame on a phone.
	var result_body := MarginContainer.new()
	result_body.name = "BreakthroughResultBody"
	result_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	result_body.add_theme_constant_override("margin_left", 24)
	result_body.add_theme_constant_override("margin_top", 14)
	result_body.add_theme_constant_override("margin_right", 24)
	result_body.add_theme_constant_override("margin_bottom", 4)
	result_shell.add_child(result_body)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	result_body.add_child(box)

	result_kicker = _label("MERIDIAN BREAKTHROUGH", 14, JADE)
	result_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_kicker)

	var result_title := _label("REFINEMENT COMPLETE", 30, GOLD_BRIGHT)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_constant_override("outline_size", 3)
	box.add_child(result_title)

	result_message = _label(
		"The inner current stabilizes. The meridian crosses its next threshold.",
		15,
		Color(0.79, 0.88, 0.85, 1.0)
	)
	result_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(result_message)

	var rule_row := HBoxContainer.new()
	rule_row.add_theme_constant_override("separation", 10)
	box.add_child(rule_row)
	var rule_left := ColorRect.new()
	rule_left.custom_minimum_size = Vector2(0.0, 1.0)
	rule_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_left.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.30)
	rule_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_row.add_child(rule_left)
	var seal := _label("◇", 15, GOLD)
	seal.custom_minimum_size = Vector2(28.0, 22.0)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_row.add_child(seal)
	var rule_right := ColorRect.new()
	rule_right.custom_minimum_size = Vector2(0.0, 1.0)
	rule_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_right.color = Color(JADE.r, JADE.g, JADE.b, 0.30)
	rule_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_row.add_child(rule_right)

	var icon_halo := PanelContainer.new()
	icon_halo.custom_minimum_size = Vector2(108.0, 108.0)
	icon_halo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_halo.add_theme_stylebox_override(
		"panel",
		_result_icon_halo_style(GOLD)
	)
	box.add_child(icon_halo)

	var icon_center := CenterContainer.new()
	icon_halo.add_child(icon_center)
	result_icon = TextureRect.new()
	result_icon.custom_minimum_size = Vector2(80.0, 80.0)
	result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(result_icon)

	result_name = _label("Sword Power", 26, TEXT)
	result_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_name)

	result_transition = _label("LV 1   →   LV 2", 23, GOLD_BRIGHT)
	result_transition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_transition)

	result_effect = _label("PERMANENT PATH ADVANCED", 13, JADE)
	result_effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_effect)

	var compare_row := HBoxContainer.new()
	compare_row.add_theme_constant_override("separation", 10)
	box.add_child(compare_row)
	var before_card := _result_stat_card("BEFORE", "+10% POWER", Color(0.67, 0.77, 0.75, 1.0))
	result_before_value = before_card.get_node("Body/Value") as Label
	compare_row.add_child(before_card)
	var after_card := _result_stat_card("AFTER BREAKTHROUGH", "+20% POWER", GOLD_BRIGHT)
	result_after_value = after_card.get_node("Body/Value") as Label
	compare_row.add_child(after_card)

	var spend_panel := PanelContainer.new()
	spend_panel.add_theme_stylebox_override(
		"panel",
		_result_subpanel_style(Color(0.002, 0.030, 0.038, 0.90), Color(0.31, 0.78, 0.68, 0.26))
	)
	box.add_child(spend_panel)
	var spend_margin := MarginContainer.new()
	spend_margin.add_theme_constant_override("margin_left", 15)
	spend_margin.add_theme_constant_override("margin_top", 7)
	spend_margin.add_theme_constant_override("margin_right", 15)
	spend_margin.add_theme_constant_override("margin_bottom", 7)
	spend_panel.add_child(spend_margin)
	var spend_row := HBoxContainer.new()
	spend_row.add_theme_constant_override("separation", 10)
	spend_margin.add_child(spend_row)
	var spend_copy := VBoxContainer.new()
	spend_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spend_row.add_child(spend_copy)
	var spend_caption := _label("SPIRIT STONE BALANCE", 11, Color(0.66, 0.78, 0.75, 1.0))
	spend_copy.add_child(spend_caption)
	result_spend = _label("3.770  →  3.570", 19, Color(0.93, 0.96, 0.90, 1.0))
	spend_copy.add_child(result_spend)
	var cost_copy := VBoxContainer.new()
	cost_copy.custom_minimum_size = Vector2(116.0, 0.0)
	spend_row.add_child(cost_copy)
	var cost_caption := _label("REFINEMENT COST", 11, Color(0.66, 0.78, 0.75, 1.0))
	cost_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_copy.add_child(cost_caption)
	result_cost_value = _label("-200", 19, GOLD_BRIGHT)
	result_cost_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_copy.add_child(result_cost_value)

	var action_margin := MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", 26)
	action_margin.add_theme_constant_override("margin_top", 4)
	action_margin.add_theme_constant_override("margin_right", 26)
	action_margin.add_theme_constant_override("margin_bottom", 6)
	result_shell.add_child(action_margin)

	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 5)
	action_margin.add_child(action_box)

	var continue_button := Button.new()
	continue_button.custom_minimum_size = Vector2(0.0, 56.0)
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button.text = "RETURN TO INNER SEA"
	continue_button.add_theme_font_override("font", UI_FONT)
	continue_button.add_theme_font_size_override("font_size", 19)
	continue_button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.73, 1.0))
	continue_button.add_theme_stylebox_override("normal", _refine_style(Color(0.010, 0.098, 0.086, 0.98), GOLD, 7))
	continue_button.add_theme_stylebox_override("hover", _refine_style(Color(0.017, 0.145, 0.120, 0.99), GOLD_BRIGHT, 10))
	continue_button.add_theme_stylebox_override("pressed", _refine_style(Color(0.004, 0.060, 0.064, 1.0), JADE, 2))
	continue_button.mouse_filter = Control.MOUSE_FILTER_PASS
	continue_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	continue_button.keep_pressed_outside = false
	continue_button.pressed.connect(_hide_result)
	action_box.add_child(continue_button)

	var footer := _label("INNER SEA  •  PERMANENT CULTIVATION", 12, Color(0.61, 0.73, 0.70, 0.94))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_box.add_child(footer)

func _layout_result_panel() -> void:
	if result_panel == null or size.x <= 2.0 or size.y <= 2.0:
		return

	var horizontal_margin: float = maxf(12.0, size.x * 0.045)
	var max_available_height: float = maxf(size.y - 150.0, 500.0)
	var resolved_minimum: Vector2 = result_panel.get_combined_minimum_size()
	var target_height: float = clampf(
		resolved_minimum.y + 6.0,
		500.0,
		minf(585.0, max_available_height)
	)
	var top_y: float = maxf(76.0, (size.y - target_height) * 0.46)

	result_panel.anchor_left = 0.0
	result_panel.anchor_top = 0.0
	result_panel.anchor_right = 0.0
	result_panel.anchor_bottom = 0.0
	result_panel.position = Vector2(horizontal_margin, top_y)
	result_panel.size = Vector2(
		maxf(size.x - horizontal_margin * 2.0, 280.0),
		target_height
	)

func _result_stat_card(caption_text: String, value_text: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 64.0)
	card.add_theme_stylebox_override(
		"panel",
		_result_subpanel_style(Color(0.002, 0.025, 0.034, 0.92), Color(accent.r, accent.g, accent.b, 0.28))
	)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 3)
	card.add_child(body)
	var caption := _label(caption_text, 11, Color(0.65, 0.77, 0.74, 1.0))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(caption)
	var value := _label(value_text, 20, accent)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(value)
	return card

func _result_subpanel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 12.0
	style.content_margin_top = 9.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 9.0
	return style

func _result_icon_halo_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.08, accent.g * 0.08, accent.b * 0.08, 0.76)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.76)
	style.corner_radius_top_left = 94
	style.corner_radius_top_right = 94
	style.corner_radius_bottom_left = 94
	style.corner_radius_bottom_right = 94
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.17)
	style.shadow_size = 16
	return style

func _refresh_all() -> void:
	_refresh_mastery()
	_refresh_map()
	_refresh_focus()

func _refresh_mastery() -> void:
	var total: int = (
		ProgressionManager.vitality_level
		+ ProgressionManager.sword_power_level
		+ ProgressionManager.swift_qi_level
	)
	var total_max: int = (
		ProgressionManager.VITALITY_MAX_LEVEL
		+ ProgressionManager.SWORD_POWER_MAX_LEVEL
		+ ProgressionManager.SWIFT_QI_MAX_LEVEL
	)
	if mastery_value != null:
		mastery_value.text = "%d / %d" % [total, total_max]
	if mastery_meter != null:
		mastery_meter.max_value = float(maxi(total_max, 1))
		mastery_meter.value = float(total)

func _refresh_map() -> void:
	if meridian_map == null:
		return
	var state: Dictionary = {}
	for path_id: String in PATH_IDS:
		var level: int = _get_level(path_id)
		var max_level: int = _get_max_level(path_id)
		state[path_id] = {
			"level": level,
			"max_level": max_level,
			"maxed": _is_maxed(path_id),
			"affordable": not _is_maxed(path_id) and ProgressionManager.spirit_stone >= _get_cost(path_id),
		}
	meridian_map.call("set_state", state, selected_path)

func _refresh_focus() -> void:
	var data: Dictionary = PATH_DATA.get(selected_path, PATH_DATA["vitality"])
	var level: int = _get_level(selected_path)
	var max_level: int = _get_max_level(selected_path)
	var maxed: bool = _is_maxed(selected_path)
	var cost: int = _get_cost(selected_path)
	var accent: Color = data.get("accent", JADE)

	selected_icon.texture = PATH_ICONS[selected_path] as Texture2D
	selected_kicker.text = tr(str(data.get("kicker", "MERIDIAN")))
	selected_kicker.add_theme_color_override("font_color", accent)
	selected_name.text = tr(str(data.get("name", "Cultivation")))
	selected_name.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82, 1.0))
	selected_doctrine.text = tr(str(data.get("doctrine", "REFINE THE DAO")))
	selected_doctrine.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.18))
	selected_level.text = tr("LV %d / %d") % [level, max_level]
	selected_description.text = tr(str(data.get("description", "")))
	current_value.text = _effect_text(selected_path, level)
	current_value.add_theme_color_override("font_color", accent)
	next_value.text = tr("PERFECTED") if maxed else _effect_text(selected_path, level + 1)
	cost_value.text = tr("MAX") if maxed else _format_count(cost)
	focus_accent.color = Color(accent.r, accent.g, accent.b, 0.92)
	focus_sheet.add_theme_stylebox_override(
		"panel",
		_sheet_style(
			Color(0.002, 0.020, 0.029, 0.86),
			Color(accent.r, accent.g, accent.b, 0.46)
		)
	)

	if maxed:
		refine_button.disabled = true
		refine_button.text = tr("MERIDIAN PERFECTED")
		refine_hint.text = tr("This path has reached its current cultivation limit.")
	else:
		var can_afford: bool = ProgressionManager.spirit_stone >= cost
		refine_button.disabled = not can_afford
		refine_button.text = tr("REFINE MERIDIAN")
		refine_hint.text = (
			tr("Permanent cultivation • persists between journeys")
			if can_afford
			else tr("Need %s more Spirit Stones") % _format_count(
				maxi(cost - ProgressionManager.spirit_stone, 0)
			)
		)

func _on_path_selected(path_id: String) -> void:
	if not PATH_IDS.has(path_id):
		return
	selected_path = path_id
	if meridian_map != null:
		meridian_map.call("set_selected_path", selected_path)
	_refresh_focus()

func _on_refine_button_down() -> void:
	_refine_press_scroll_y = body_scroll.scroll_vertical if body_scroll != null else 0

func _on_refine_pressed() -> void:
	if body_scroll != null:
		var scroll_delta: int = absi(body_scroll.scroll_vertical - _refine_press_scroll_y)
		if scroll_delta >= PRESS_SCROLL_CANCEL_DISTANCE:
			return

	if _is_maxed(selected_path):
		_refresh_focus()
		return

	var cost: int = _get_cost(selected_path)
	var before_balance: int = ProgressionManager.spirit_stone
	if before_balance < cost:
		_refresh_focus()
		return

	var old_level: int = _get_level(selected_path)
	if not _buy_selected_path():
		_refresh_all()
		return

	var new_level: int = _get_level(selected_path)
	var after_balance: int = ProgressionManager.spirit_stone
	if meridian_map != null:
		meridian_map.call("celebrate", selected_path)
	_refresh_all()
	_show_result(
		selected_path,
		old_level,
		new_level,
		cost,
		before_balance,
		after_balance
	)

func _on_cultivation_upgraded(_upgrade_id: String, _new_level: int) -> void:
	_refresh_all()

func _show_result(
	path_id: String,
	old_level: int,
	new_level: int,
	cost: int,
	before_balance: int,
	after_balance: int
) -> void:
	var data: Dictionary = PATH_DATA.get(path_id, PATH_DATA["vitality"])
	var accent: Color = data.get("accent", JADE)
	result_icon.texture = PATH_ICONS[path_id] as Texture2D
	result_name.text = str(data.get("name", "Cultivation"))
	result_name.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.28))
	result_transition.text = "LV %d   →   LV %d" % [old_level, new_level]
	result_effect.text = "PERMANENT PATH ADVANCED"
	result_effect.add_theme_color_override("font_color", accent)
	result_before_value.text = _effect_text(path_id, old_level)
	result_before_value.add_theme_color_override("font_color", Color(0.72, 0.80, 0.78, 1.0))
	result_after_value.text = _effect_text(path_id, new_level)
	result_after_value.add_theme_color_override("font_color", accent.lerp(GOLD_BRIGHT, 0.24))
	result_spend.text = "%s   →   %s" % [
		_format_count(before_balance),
		_format_count(after_balance),
	]
	result_cost_value.text = "-%s" % _format_count(cost)
	result_cost_value.add_theme_color_override("font_color", accent.lerp(GOLD_BRIGHT, 0.48))
	result_panel.add_theme_stylebox_override("panel", _result_style(accent))

	# The result subtree starts hidden. On the very first breakthrough, wait one
	# rendered frame after exposing it at alpha 0 so Container minimum sizes are
	# identical to every later reveal before calculating the modal geometry.
	result_layer.visible = true
	result_layer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	result_panel.scale = Vector2.ONE
	await get_tree().process_frame
	if not is_instance_valid(result_layer) or not is_instance_valid(result_panel):
		return
	_layout_result_panel()

	if result_fx != null:
		result_fx.call("configure", accent)
		result_fx.call("celebrate")

	result_panel.scale = Vector2(0.94, 0.94) if not _reduced_effects_enabled() else Vector2.ONE
	result_panel.pivot_offset = result_panel.size * 0.5
	result_icon.scale = Vector2(0.64, 0.64) if not _reduced_effects_enabled() else Vector2.ONE
	result_icon.pivot_offset = result_icon.size * 0.5

	if result_tween != null and result_tween.is_valid():
		result_tween.kill()
	result_tween = create_tween()
	result_tween.set_parallel(true)
	result_tween.tween_property(result_layer, "modulate:a", 1.0, 0.18)
	if not _reduced_effects_enabled():
		result_tween.tween_property(result_panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		result_tween.tween_property(result_icon, "scale", Vector2(1.08, 1.08), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var settle := create_tween()
		settle.tween_interval(0.24)
		settle.tween_property(result_icon, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _hide_result() -> void:
	if not result_layer.visible:
		return
	if result_tween != null and result_tween.is_valid():
		result_tween.kill()
	result_tween = create_tween()
	result_tween.set_parallel(true)
	result_tween.tween_property(result_layer, "modulate:a", 0.0, 0.14)
	if not _reduced_effects_enabled():
		result_tween.tween_property(result_panel, "scale", Vector2(0.97, 0.97), 0.14)
	await result_tween.finished
	if is_instance_valid(result_layer):
		result_layer.visible = false

func _play_intro() -> void:
	if body_content == null:
		return
	if _reduced_effects_enabled():
		body_content.modulate = Color.WHITE
		return
	body_content.modulate = Color(1.0, 1.0, 1.0, 0.0)
	body_content.position.y += 20.0
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()
	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(body_content, "modulate:a", 1.0, 0.24)
	intro_tween.tween_property(body_content, "position:y", body_content.position.y - 20.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _configure_mobile_scroll() -> void:
	# Exact production/Pavilion mobile scroll contract:
	# - 6 px deadzone
	# - horizontal scrolling disabled
	# - vertical scrollbar hidden on Android/iOS
	# - STOP descendants become PASS so drag reaches the ScrollContainer
	# Interactive meridian/refine controls add their own 6 px scroll-delta guard.
	# The breakthrough result itself is deliberately static/non-scrollable.
	if body_scroll == null:
		return
	body_scroll.scroll_deadzone = MOBILE_SCROLL_DEADZONE
	var mobile_display: bool = OS.has_feature("android") or OS.has_feature("ios")
	if mobile_display:
		body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	else:
		body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_configure_scroll_descendants(body_scroll)

func _configure_scroll_descendants(root: Node) -> void:
	for child: Node in root.get_children():
		if child is Control:
			var control := child as Control
			if control.mouse_filter == Control.MOUSE_FILTER_STOP:
				control.mouse_filter = Control.MOUSE_FILTER_PASS
		_configure_scroll_descendants(child)

func _get_cost(path_id: String) -> int:
	match path_id:
		"vitality":
			return ProgressionManager.get_vitality_cost()
		"sword_power":
			return ProgressionManager.get_sword_power_cost()
		"swift_qi":
			return ProgressionManager.get_swift_qi_cost()
		_:
			return 0

func _get_level(path_id: String) -> int:
	match path_id:
		"vitality":
			return ProgressionManager.vitality_level
		"sword_power":
			return ProgressionManager.sword_power_level
		"swift_qi":
			return ProgressionManager.swift_qi_level
		_:
			return 0

func _get_max_level(path_id: String) -> int:
	match path_id:
		"vitality":
			return ProgressionManager.VITALITY_MAX_LEVEL
		"sword_power":
			return ProgressionManager.SWORD_POWER_MAX_LEVEL
		"swift_qi":
			return ProgressionManager.SWIFT_QI_MAX_LEVEL
		_:
			return 0

func _is_maxed(path_id: String) -> bool:
	match path_id:
		"vitality":
			return ProgressionManager.is_vitality_maxed()
		"sword_power":
			return ProgressionManager.is_sword_power_maxed()
		"swift_qi":
			return ProgressionManager.is_swift_qi_maxed()
		_:
			return true

func _buy_selected_path() -> bool:
	match selected_path:
		"vitality":
			return ProgressionManager.buy_vitality()
		"sword_power":
			return ProgressionManager.buy_sword_power()
		"swift_qi":
			return ProgressionManager.buy_swift_qi()
		_:
			return false

func _effect_text(path_id: String, level: int) -> String:
	match path_id:
		"vitality":
			return "+%d MAX HP" % (level * HEALTH_PER_VITALITY_LEVEL)
		"sword_power":
			return "+%d%% POWER" % (level * SWORD_POWER_PERCENT_PER_LEVEL)
		"swift_qi":
			var cooldown: float = pow(SWIFT_QI_COOLDOWN_MULTIPLIER, float(level))
			return "%.3f ATTACKS/S" % (1.0 / maxf(cooldown, 0.2))
		_:
			return "CURRENT EFFECT"

func handle_system_back() -> void:
	if result_layer != null and result_layer.visible:
		_hide_result()
		return
	_return_to_journey()

func _return_to_journey() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		push_error("CultivationMenu: Main Menu scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		MAIN_MENU_SCENE,
		-1
	)
	if change_error != OK:
		push_error(
			"CultivationMenu: gagal kembali ke Journey Hub. Error code: "
			+ str(change_error)
		)

func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", UI_FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.78))
	result.add_theme_constant_override("shadow_offset_y", 1)
	return result

func _sheet_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	style.shadow_size = 12
	return style

func _meter_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _refine_style(background: Color, border: Color, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 16.0
	style.content_margin_top = 10.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(border.r, border.g, border.b, 0.18)
	style.shadow_size = shadow_size
	return style

func _result_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.001, 0.022, 0.032, 0.995)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.12)
	style.shadow_size = 22
	return style

func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _reduced_effects_enabled() -> bool:
	return is_instance_valid(SettingsManager) and bool(SettingsManager.reduced_effects)

func _format_count(value: int) -> String:
	var remaining: String = str(maxi(value, 0))
	var groups: Array[String] = []
	while remaining.length() > 3:
		groups.push_front(remaining.right(3))
		remaining = remaining.left(remaining.length() - 3)
	groups.push_front(remaining)
	return ".".join(groups)
