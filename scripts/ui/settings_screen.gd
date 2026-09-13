extends Control

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

@onready var back_button: Button = %BackButton
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var master_value_label: Label = %MasterValueLabel
@onready var music_value_label: Label = %MusicValueLabel
@onready var sfx_value_label: Label = %SFXValueLabel
@onready var reset_button: Button = %ResetButton
@onready var routing_status_label: Label = %RoutingStatusLabel

var is_syncing_ui: bool = false
var presentation_toggles: Dictionary = {}
var fps_choice: OptionButton
var language_choice: OptionButton

func _ready() -> void:
	_build_presentation_options()
	_connect_signals()
	SceneTransitionManager.set_back_handler(handle_system_back)
	_sync_from_settings()
	DebugLogger.system(str("Settings Screen aktif!"))

func _connect_signals() -> void:
	back_button.pressed.connect(_return_to_journey)
	reset_button.pressed.connect(_on_reset_pressed)
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	SettingsManager.settings_changed.connect(_sync_from_settings)

func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	_return_to_journey()

func _sync_from_settings() -> void:
	is_syncing_ui = true
	master_slider.value = SettingsManager.get_master_volume() * 100.0
	music_slider.value = SettingsManager.get_music_volume() * 100.0
	sfx_slider.value = SettingsManager.get_sfx_volume() * 100.0
	_update_value_labels()
	if SettingsManager.are_audio_buses_ready():
		routing_status_label.text = tr("MUSIC & SOUND")
	else:
		routing_status_label.text = tr("Sound is temporarily unavailable.")
	for key in presentation_toggles:
		presentation_toggles[key].set_pressed_no_signal(bool(SettingsManager.get(str(key))))
	fps_choice.select(0 if SettingsManager.frame_limit == 60 else 1)
	language_choice.select(1 if SettingsManager.language == "id" else 0)
	is_syncing_ui = false

func _update_value_labels() -> void:
	master_value_label.text = "%d%%" % int(round(master_slider.value))
	music_value_label.text = "%d%%" % int(round(music_slider.value))
	sfx_value_label.text = "%d%%" % int(round(sfx_slider.value))

func _on_master_changed(value: float) -> void:
	master_value_label.text = "%d%%" % int(round(value))
	if is_syncing_ui:
		return
	SettingsManager.set_master_volume(value / 100.0)

func _on_music_changed(value: float) -> void:
	music_value_label.text = "%d%%" % int(round(value))
	if is_syncing_ui:
		return
	SettingsManager.set_music_volume(value / 100.0)

func _on_sfx_changed(value: float) -> void:
	sfx_value_label.text = "%d%%" % int(round(value))
	if is_syncing_ui:
		return
	SettingsManager.set_sfx_volume(value / 100.0)

func _on_reset_pressed() -> void:
	SettingsManager.reset_audio_defaults()

func _return_to_journey() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		push_error("SettingsScreen: Main Menu scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(MAIN_MENU_SCENE, -1)
	if change_error != OK:
		push_error(
			"SettingsScreen: gagal kembali ke Journey. Error code: "
			+ str(change_error)
		)

func _build_presentation_options() -> void:
	var parent_box: VBoxContainer = get_node("SafeArea/Scroll/Content") as VBoxContainer
	var existing_card: PanelContainer = get_node("SafeArea/Scroll/Content/AudioCard") as PanelContainer

	var comfort_card: PanelContainer = _create_settings_card(parent_box, existing_card, tr("COMFORT"), tr("Combat Presentation"), tr("Tune motion and combat feedback without changing game balance."))
	var comfort_box: VBoxContainer = comfort_card.get_child(0) as VBoxContainer
	var options: Dictionary = {
		"screen_shake": tr("Screen shake"),
		"reduced_effects": tr("Reduced flashes & effects"),
		"damage_numbers": tr("Damage numbers"),
		"haptics": tr("Vibration feedback")
	}
	for raw_key in options:
		var key: String = str(raw_key)
		var toggle: CheckButton = CheckButton.new()
		toggle.text = str(options[key])
		toggle.custom_minimum_size.y = 44.0
		toggle.add_theme_font_size_override("font_size", 14)
		comfort_box.add_child(toggle)
		toggle.toggled.connect(_on_presentation_toggled.bind(key))
		presentation_toggles[key] = toggle

	var system_card: PanelContainer = _create_settings_card(parent_box, existing_card, tr("SYSTEM"), tr("Display & Language"), tr("Choose the performance target and interface language for this device."))
	var system_box: VBoxContainer = system_card.get_child(0) as VBoxContainer
	fps_choice = OptionButton.new()
	fps_choice.add_item(tr("60 FPS  •  SMOOTH"))
	fps_choice.add_item(tr("30 FPS  •  BATTERY SAVER"))
	fps_choice.custom_minimum_size.y = 44.0
	fps_choice.item_selected.connect(_on_fps_selected)
	system_box.add_child(fps_choice)
	language_choice = OptionButton.new()
	language_choice.add_item("English")
	language_choice.add_item("Bahasa Indonesia")
	language_choice.custom_minimum_size.y = 44.0
	language_choice.item_selected.connect(_on_language_selected)
	system_box.add_child(language_choice)
	var privacy: Button = Button.new()
	privacy.text = tr("PRIVACY, SUPPORT & CREDITS")
	privacy.custom_minimum_size.y = 44.0
	privacy.theme_type_variation = &"JadeSecondaryButton"
	privacy.add_theme_font_size_override("font_size", 13)
	privacy.pressed.connect(_open_privacy)
	system_box.add_child(privacy)

	# Keep reset as the final destructive-ish utility action.
	parent_box.move_child(comfort_card, parent_box.get_child_count() - 2)
	parent_box.move_child(system_card, parent_box.get_child_count() - 2)

func _create_settings_card(parent_box: VBoxContainer, source_card: PanelContainer, eyebrow: String, title_text: String, subtitle_text: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", source_card.get_theme_stylebox("panel"))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var eyebrow_label: Label = Label.new()
	eyebrow_label.text = eyebrow
	eyebrow_label.add_theme_font_size_override("font_size", 10)
	eyebrow_label.add_theme_color_override("font_color", Color(0.34, 0.90, 0.78, 1.0))
	box.add_child(eyebrow_label)
	var title_label: Label = Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.42, 1.0))
	box.add_child(title_label)
	var subtitle_label: Label = Label.new()
	subtitle_label.text = subtitle_text
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.70, 1.0))
	box.add_child(subtitle_label)
	parent_box.add_child(card)
	return card

func _open_privacy() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		"res://scenes/ui/privacy_screen.tscn",
		1
	)
	if change_error != OK:
		push_error(
			"SettingsScreen: gagal membuka Privacy. Error code: "
			+ str(change_error)
		)

func _on_presentation_toggled(enabled: bool, key: String) -> void:
	SettingsManager.set_presentation(key, enabled)

func _on_fps_selected(index: int) -> void:
	SettingsManager.set_presentation("frame_limit", 60 if index == 0 else 30)

func _on_language_selected(index: int) -> void:
	SettingsManager.set_presentation("language", "id" if index == 1 else "en")
	# Rebuild formatted and dynamically created labels in the chosen language.
	get_tree().reload_current_scene.call_deferred()
