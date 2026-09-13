extends Control

## Chapter Select — Journey UI production polish v2.
## Progression remains fully owned by JourneyManager.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const STAGE_SELECT_SCENE: String = "res://scenes/ui/stage_select.tscn"
const JourneyVisualCatalog = preload("res://scripts/ui/journey_visual_catalog.gd")
const WuxiaPlaqueButton = preload("res://scripts/ui/wuxia_plaque_button.gd")

@onready var chapter_list: VBoxContainer = %ChapterList
@onready var hint_label: Label = %HintLabel
@onready var back_button: Button = %BackButton
@onready var realm_backdrop: Control = %RealmBackdrop
@onready var eyebrow_label: Label = %EyebrowLabel
@onready var realm_epithet_label: Label = %RealmEpithetLabel
@onready var subtitle_label: Label = %SubtitleLabel

var chapter_buttons: Dictionary = {}
var chapter_views: Dictionary = {}

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	SceneTransitionManager.set_back_handler(handle_system_back)
	_apply_selected_realm_visuals()
	_build_chapter_buttons()
	_refresh_chapters()

func _apply_selected_realm_visuals() -> void:
	var profile: Dictionary = JourneyVisualCatalog.get_chapter_profile(
		JourneyManager.selected_chapter_id
	)
	if realm_backdrop.has_method("apply_profile"):
		realm_backdrop.call("apply_profile", profile)
	if back_button.has_method("apply_visual_state"):
		back_button.call("apply_visual_state", profile, false, false)
	eyebrow_label.text = str(profile.get("eyebrow", "CELESTIAL JOURNEY"))
	realm_epithet_label.text = str(
		profile.get("realm_epithet", "CULTIVATION REALM")
	)
	subtitle_label.text = str(
		profile.get(
			"realm_hint",
			"Choose a cultivation realm and continue the path toward ascension."
		)
	)

func _build_chapter_buttons() -> void:
	chapter_buttons.clear()
	chapter_views.clear()
	for child: Node in chapter_list.get_children():
		child.queue_free()
	var chapter_ids: Array = JourneyManager.get_chapter_ids()
	for raw_chapter_id: Variant in chapter_ids:
		var chapter_id: int = int(raw_chapter_id)
		var card: Button = _create_chapter_card(chapter_id)
		chapter_list.add_child(card)
		chapter_buttons[chapter_id] = card

func _create_chapter_card(chapter_id: int) -> Button:
	var button: Button = WuxiaPlaqueButton.new() as Button
	button.custom_minimum_size = Vector2(0.0, 142.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.theme_type_variation = &"JadeRealmCard"
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.clip_contents = false
	button.set("plaque_style", 2)
	button.pressed.connect(_on_chapter_pressed.bind(chapter_id))

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 17)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 17)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var seal: PanelContainer = PanelContainer.new()
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.custom_minimum_size = Vector2(70.0, 78.0)
	seal.theme_type_variation = &"JadeRealmSeal"
	row.add_child(seal)

	var seal_content: VBoxContainer = VBoxContainer.new()
	seal_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_content.add_theme_constant_override("separation", 0)
	seal.add_child(seal_content)

	var seal_kicker: Label = Label.new()
	seal_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_kicker.theme_type_variation = &"JadeSubtitle"
	seal_kicker.add_theme_font_size_override("font_size", 9)
	seal_kicker.text = "REALM"
	seal_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_content.add_child(seal_kicker)

	var seal_label: Label = Label.new()
	seal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seal_label.theme_type_variation = &"JadeTitle"
	seal_label.add_theme_font_size_override("font_size", 25)
	seal_label.text = _format_chapter_number(chapter_id)
	seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal_content.add_child(seal_label)

	var content: VBoxContainer = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	row.add_child(content)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 8)
	content.add_child(top_row)

	var kicker: Label = Label.new()
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kicker.theme_type_variation = &"JadeSubtitle"
	kicker.add_theme_font_size_override("font_size", 10)
	top_row.add_child(kicker)

	var badge_panel: PanelContainer = PanelContainer.new()
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.custom_minimum_size = Vector2(82.0, 24.0)
	badge_panel.theme_type_variation = &"JadeJourneyBadge"
	top_row.add_child(badge_panel)

	var status_label: Label = Label.new()
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_panel.add_child(status_label)

	var title: Label = Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.theme_type_variation = &"JadeHeroName"
	title.add_theme_font_size_override("font_size", 21)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)

	var progress_label: Label = Label.new()
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_label.theme_type_variation = &"JadeMutedLabel"
	progress_label.add_theme_font_size_override("font_size", 10)
	content.add_child(progress_label)

	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.custom_minimum_size = Vector2(0.0, 8.0)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.show_percentage = false
	progress_bar.max_value = 1.0
	content.add_child(progress_bar)

	chapter_views[chapter_id] = {
		"kicker": kicker,
		"title": title,
		"progress_label": progress_label,
		"status_label": status_label,
		"badge_panel": badge_panel,
		"progress_bar": progress_bar,
		"seal": seal,
		"seal_label": seal_label
	}
	return button

func _refresh_chapters() -> void:
	var chapter_ids: Array = JourneyManager.get_chapter_ids()
	if chapter_ids.is_empty():
		hint_label.text = "No Chapters are available."
		return
	hint_label.text = (
		"Select an unlocked realm  •  Cleared progress is permanently recorded"
	)
	for raw_chapter_id: Variant in chapter_ids:
		_refresh_chapter_card(int(raw_chapter_id))

func _refresh_chapter_card(chapter_id: int) -> void:
	var button: Button = _get_chapter_button(chapter_id)
	if button == null or not chapter_views.has(chapter_id):
		return
	var view: Dictionary = chapter_views[chapter_id]
	var kicker: Label = view.get("kicker") as Label
	var title: Label = view.get("title") as Label
	var progress_label: Label = view.get("progress_label") as Label
	var status_label: Label = view.get("status_label") as Label
	var badge_panel: PanelContainer = view.get("badge_panel") as PanelContainer
	var progress_bar: ProgressBar = view.get("progress_bar") as ProgressBar
	var seal: PanelContainer = view.get("seal") as PanelContainer
	var chapter_data: Dictionary = JourneyManager.get_chapter_data(chapter_id)
	if chapter_data.is_empty():
		kicker.text = tr("CHAPTER %02d") % chapter_id
		title.text = "Unavailable Realm"
		progress_label.text = "No realm data"
		status_label.text = "UNAVAILABLE"
		progress_bar.value = 0.0
		button.disabled = true
		if button.has_method("set_dimmed_visual"):
			button.call("set_dimmed_visual", true)
		return

	var progress: Dictionary = JourneyManager.get_chapter_progress(chapter_id)
	var is_unlocked: bool = JourneyManager.is_chapter_unlocked(chapter_id)
	var is_selected: bool = JourneyManager.selected_chapter_id == chapter_id
	var status: String = _get_chapter_status_text(is_unlocked, is_selected)
	var total_stages: int = int(progress.get("total_stages", 0))
	var cleared_stages: int = int(progress.get("cleared_stages", 0))
	var unlocked_stages: int = int(progress.get("unlocked_stages", 0))
	var clear_ratio: float = 0.0
	if total_stages > 0:
		clear_ratio = float(cleared_stages) / float(total_stages)

	var realm_epithet: String = str(
		JourneyVisualCatalog.get_chapter_profile(chapter_id).get(
			"realm_epithet",
			"CULTIVATION REALM"
		)
	)
	kicker.text = tr("CHAPTER %02d  •  %s") % [
		chapter_id,
		tr(realm_epithet)
	]
	title.text = str(chapter_data.get("display_name", tr("Unknown Realm")))
	progress_label.text = tr("CLEARED %d/%d    UNLOCKED %d/%d") % [
		cleared_stages,
		total_stages,
		unlocked_stages,
		total_stages
	]
	status_label.text = status
	progress_bar.value = clear_ratio
	button.disabled = not is_unlocked

	var profile: Dictionary = JourneyVisualCatalog.get_chapter_profile(chapter_id)
	_apply_plaque_visual(button, profile, is_selected, not is_unlocked)
	_apply_seal_palette(seal, profile, not is_unlocked)
	_apply_badge_palette(badge_panel, status, profile)
	_apply_progress_palette(progress_bar, profile)
	_apply_status_color(status_label, status, profile)
	button.tooltip_text = tr(
		"Chapter %d — %s\nCleared %d/%d • Unlocked %d/%d"
	) % [
		chapter_id,
		title.text,
		cleared_stages,
		total_stages,
		unlocked_stages,
		total_stages
	]

func _apply_plaque_visual(
	button: Button,
	profile: Dictionary,
	is_selected: bool,
	is_dimmed: bool
) -> void:
	if button.has_method("apply_visual_state"):
		button.call("apply_visual_state", profile, is_selected, is_dimmed)

func _apply_status_color(
	label: Label,
	status: String,
	profile: Dictionary
) -> void:
	var accent: Color = profile.get("accent", Color(0.298, 0.82, 0.647, 1.0))
	var gold: Color = profile.get("gold", Color(0.957, 0.78, 0.357, 1.0))
	match status:
		"SELECTED":
			label.add_theme_color_override("font_color", gold)
		"AVAILABLE":
			label.add_theme_color_override("font_color", accent)
		_:
			label.add_theme_color_override(
				"font_color",
				Color(0.502, 0.553, 0.557, 0.9)
			)

func _apply_seal_palette(
	seal: PanelContainer,
	profile: Dictionary,
	is_dimmed: bool
) -> void:
	if seal == null:
		return
	var accent_soft: Color = profile.get(
		"accent_soft",
		Color(0.184, 0.62, 0.471, 1.0)
	)
	var gold: Color = profile.get("gold", Color(0.957, 0.78, 0.357, 1.0))
	var source: StyleBox = seal.get_theme_stylebox("panel")
	if source is StyleBoxFlat:
		var style: StyleBoxFlat = source.duplicate() as StyleBoxFlat
		if is_dimmed:
			style.bg_color = Color(0.04, 0.055, 0.055, 0.78)
			style.border_color = Color(0.35, 0.38, 0.37, 0.55)
		else:
			style.bg_color = Color(
				accent_soft.r * 0.22,
				accent_soft.g * 0.22,
				accent_soft.b * 0.22,
				0.96
			)
			style.border_color = gold
		seal.add_theme_stylebox_override("panel", style)

func _apply_badge_palette(
	badge_panel: PanelContainer,
	status: String,
	profile: Dictionary
) -> void:
	if badge_panel == null:
		return
	var accent: Color = profile.get("accent", Color(0.298, 0.82, 0.647, 1.0))
	var gold: Color = profile.get("gold", Color(0.957, 0.78, 0.357, 1.0))
	var source: StyleBox = badge_panel.get_theme_stylebox("panel")
	if source is StyleBoxFlat:
		var style: StyleBoxFlat = source.duplicate() as StyleBoxFlat
		match status:
			"SELECTED":
				style.border_color = gold
				style.bg_color = Color(0.12, 0.09, 0.02, 0.82)
			"AVAILABLE":
				style.border_color = accent
				style.bg_color = Color(0.01, 0.09, 0.08, 0.82)
			_:
				style.border_color = Color(0.35, 0.38, 0.37, 0.48)
				style.bg_color = Color(0.025, 0.035, 0.035, 0.78)
		badge_panel.add_theme_stylebox_override("panel", style)

func _apply_progress_palette(
	progress_bar: ProgressBar,
	profile: Dictionary
) -> void:
	var accent: Color = profile.get(
		"accent",
		Color(0.298, 0.82, 0.647, 1.0)
	)
	var fill_source: StyleBox = progress_bar.get_theme_stylebox("fill")
	if fill_source is StyleBoxFlat:
		var fill_style: StyleBoxFlat = fill_source.duplicate() as StyleBoxFlat
		fill_style.bg_color = accent
		progress_bar.add_theme_stylebox_override("fill", fill_style)

func _format_chapter_number(chapter_id: int) -> String:
	if chapter_id >= 1 and chapter_id <= 9:
		return "0%d" % chapter_id
	return str(chapter_id)

func _get_chapter_button(chapter_id: int) -> Button:
	if not chapter_buttons.has(chapter_id):
		return null
	return chapter_buttons[chapter_id] as Button

func _get_chapter_status_text(is_unlocked: bool, is_selected: bool) -> String:
	if not is_unlocked:
		return "LOCKED"
	if is_selected:
		return "SELECTED"
	return "AVAILABLE"

func _on_chapter_pressed(chapter_id: int) -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not JourneyManager.select_chapter(chapter_id):
		push_warning("ChapterSelect: Chapter %d belum tersedia." % chapter_id)
		_refresh_chapters()
		return
	var chapter_data: Dictionary = JourneyManager.get_chapter_data(chapter_id)
	DebugLogger.system(str(
		"Chapter dipilih: ",
		chapter_id,
		" - ",
		str(chapter_data.get("display_name", "Unknown Realm"))
	))
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		STAGE_SELECT_SCENE,
		1
	)
	if change_error != OK:
		push_error(
			"ChapterSelect: gagal membuka Stage Select. Error code: "
			+ str(change_error)
		)

func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	_on_back_pressed()

func _on_back_pressed() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		MAIN_MENU_SCENE,
		-1
	)
	if change_error != OK:
		push_error(
			"ChapterSelect: gagal kembali ke Main Menu. Error code: "
			+ str(change_error)
		)
