extends Control

## Jade Ascendant / Settings — mobile-first premium presentation.
## Existing SettingsManager/audio/locale callbacks are unchanged in semantics.
## Runtime presentation is intentionally local to this screen; gameplay UI is not modified.
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const ControlPrefs = preload("res://scripts/ui/joystick_prefs.gd")
const JADE: Color = Color(0.23, 0.89, 0.76, 1.0)
const GOLD: Color = Color(0.99, 0.80, 0.42, 1.0)
const IVORY: Color = Color(0.95, 0.97, 0.92, 1.0)
const MUTED: Color = Color(0.76, 0.85, 0.81, 1.0)
const AQUA: Color = Color(0.29, 0.76, 1.0, 1.0)
const SCROLL_GESTURE_DEADZONE: float = 15.0

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
var fps_choice: OptionButton = null
var language_choice: OptionButton = null
var joystick_size_choice: OptionButton = null
var joystick_opacity_slider: HSlider = null
var joystick_opacity_label: Label = null
var reset_controls_button: Button = null
var _styled_cards: Array[PanelContainer] = []
var _settings_scroll: ScrollContainer = null
var _control_size_index: int = 1
var _control_opacity: float = 1.0
# Input arbitration is local to Settings; mobile_safe_area retains its shared behavior.
var _scroll_touch_index: int = -1
var _scroll_mouse_down: bool = false
var _scroll_pointer_start: Vector2 = Vector2.ZERO
var _scroll_gesture_active: bool = false
var _scroll_gesture_generation: int = 0
var _gesture_origin_slider: HSlider = null
var _gesture_origin_slider_value: float = 0.0
var _gesture_vertical_slider_scroll: bool = false

# Existing debug-only monetization test authority is retained, not shipped in release.
var monetization_qa_status_label: Label
var monetization_qa_event_label: Label
var monetization_qa_rewarded_button: Button
var monetization_qa_privacy_button: Button
var monetization_qa_timer: Timer
var monetization_qa_sequence: int = 0


func _ready() -> void:
	_control_size_index = ControlPrefs.get_size_index()
	_control_opacity = ControlPrefs.get_opacity()
	_build_presentation_options()
	_apply_settings_visual_polish()
	_connect_signals()
	SceneTransitionManager.set_back_handler(handle_system_back)
	_sync_from_settings()
	# SafeArea configures touch scrolling via call_deferred. Our policy must run
	# afterward so the local deadzone is not overwritten by its shared default.
	call_deferred("_configure_settings_scroll_gestures")
	_play_settings_entrance()
	DebugLogger.system(str("Settings Screen aktif!"))


func _local(en: String, id: String) -> String:
	return id if SettingsManager.language == "id" else en


func _configure_settings_scroll_gestures() -> void:
	if not is_inside_tree() or _settings_scroll == null:
		return
	_settings_scroll.scroll_deadzone = int(SCROLL_GESTURE_DEADZONE)
	_settings_scroll.follow_focus = false
	# Shared mobile safe area deliberately leaves descendants in PASS mode so
	# vertical gestures can reach the ScrollContainer. OptionButton defaults to
	# action-on-PRESS, which opens popups in the middle of swipes. Every dropdown
	# in this screen instead opens only on a deliberate release.
	for option: OptionButton in [joystick_size_choice, fps_choice, language_choice]:
		if option == null:
			continue
		option.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		option.mouse_filter = Control.MOUSE_FILTER_PASS


func _input(event: InputEvent) -> void:
	# This observes touch/mouse drags before GUI controls emit selections.
	# It never consumes input: scrolling and slider drags still work normally.
	if _settings_scroll == null or not is_inside_tree():
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _scroll_touch_index < 0 and _point_is_in_scroll(touch.position):
				_scroll_touch_index = touch.index
				_begin_scroll_pointer(touch.position)
		elif touch.index == _scroll_touch_index:
			_scroll_touch_index = -1
			_release_scroll_gesture()
		return
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _scroll_touch_index:
			_register_scroll_drag(drag.position)
		return
	# Editor mouse testing follows the same swipe/tap distinction. Ignore
	# emulated mouse-down while native touch is already active.
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed and _scroll_touch_index < 0 and _point_is_in_scroll(click.position):
			_scroll_mouse_down = true
			_begin_scroll_pointer(click.position)
		elif not click.pressed and _scroll_mouse_down:
			_scroll_mouse_down = false
			_release_scroll_gesture()
		return
	if event is InputEventMouseMotion and _scroll_mouse_down and _scroll_touch_index < 0:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_register_scroll_drag(motion.position)


func _point_is_in_scroll(viewport_position: Vector2) -> bool:
	return _settings_scroll.get_global_rect().has_point(viewport_position)


func _begin_scroll_pointer(viewport_position: Vector2) -> void:
	_scroll_pointer_start = viewport_position
	_gesture_origin_slider = null
	_gesture_origin_slider_value = 0.0
	_gesture_vertical_slider_scroll = false
	for slider: HSlider in [master_slider, music_slider, sfx_slider, joystick_opacity_slider]:
		if slider != null and slider.get_global_rect().has_point(viewport_position):
			_gesture_origin_slider = slider
			_gesture_origin_slider_value = slider.value
			break


func _register_scroll_drag(viewport_position: Vector2) -> void:
	var displacement: Vector2 = viewport_position - _scroll_pointer_start
	if displacement.length() < SCROLL_GESTURE_DEADZONE:
		return
	# A vertical swipe over a horizontal slider is navigation, not a volume
	# change. Re-evaluate direction during the gesture so a diagonal start
	# cannot silently commit a volume change when it becomes a vertical scroll.
	if (
		_gesture_origin_slider != null
		and not _gesture_vertical_slider_scroll
		and absf(displacement.y) > absf(displacement.x)
	):
		_gesture_vertical_slider_scroll = true
		_restore_slider_before_scroll()
	if _scroll_gesture_active:
		return
	_scroll_gesture_active = true
	_scroll_gesture_generation += 1
	# An already-open popup must not remain stacked above a scrolling page.
	for option: OptionButton in [joystick_size_choice, fps_choice, language_choice]:
		if option != null and option.get_popup().visible:
			option.get_popup().hide()


func _release_scroll_gesture() -> void:
	if not _scroll_gesture_active:
		_gesture_origin_slider = null
		return
	var generation: int = _scroll_gesture_generation
	_clear_scroll_suppression.call_deferred(generation)


func _clear_scroll_suppression(generation: int) -> void:
	if generation != _scroll_gesture_generation:
		return
	if _scroll_touch_index >= 0 or _scroll_mouse_down:
		return
	_scroll_gesture_active = false
	_gesture_vertical_slider_scroll = false
	_gesture_origin_slider = null


func _restore_slider_before_scroll() -> void:
	if _gesture_origin_slider == master_slider:
		SettingsManager.set_master_volume(_gesture_origin_slider_value / 100.0)
	elif _gesture_origin_slider == music_slider:
		SettingsManager.set_music_volume(_gesture_origin_slider_value / 100.0)
	elif _gesture_origin_slider == sfx_slider:
		SettingsManager.set_sfx_volume(_gesture_origin_slider_value / 100.0)
	elif _gesture_origin_slider == joystick_opacity_slider:
		_save_joystick_preferences(_control_size_index, _gesture_origin_slider_value / 100.0)
	if _gesture_origin_slider != null:
		_gesture_origin_slider.set_value_no_signal(_gesture_origin_slider_value)
	_update_value_labels()
	if joystick_opacity_slider != null:
		_update_joystick_opacity_text(joystick_opacity_slider.value)


func _protect_vertical_slider_value(slider: HSlider) -> bool:
	if not _gesture_vertical_slider_scroll or _gesture_origin_slider != slider:
		return false
	slider.set_value_no_signal(_gesture_origin_slider_value)
	_update_value_labels()
	if slider == joystick_opacity_slider:
		_update_joystick_opacity_text(_gesture_origin_slider_value)
	return true


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
	routing_status_label.text = (
		_local("MUSIC & SOUND", "MUSIK & SUARA")
		if SettingsManager.are_audio_buses_ready()
		else _local("AUDIO UNAVAILABLE", "AUDIO TIDAK TERSEDIA")
	)
	for key in presentation_toggles:
		var toggle: CheckButton = presentation_toggles[key] as CheckButton
		if toggle != null:
			toggle.set_pressed_no_signal(bool(SettingsManager.get(str(key))))
			toggle.text = _local("ON", "AKTIF") if toggle.button_pressed else _local("OFF", "MATI")
	if fps_choice != null:
		fps_choice.select(0 if SettingsManager.frame_limit == 60 else 1)
	if language_choice != null:
		language_choice.select(1 if SettingsManager.language == "id" else 0)
	if joystick_size_choice != null:
		joystick_size_choice.select(_control_size_index)
	if joystick_opacity_slider != null:
		joystick_opacity_slider.value = _control_opacity * 100.0
		_update_joystick_opacity_text(joystick_opacity_slider.value)
	is_syncing_ui = false


func _update_value_labels() -> void:
	master_value_label.text = "%d%%" % int(round(master_slider.value))
	music_value_label.text = "%d%%" % int(round(music_slider.value))
	sfx_value_label.text = "%d%%" % int(round(sfx_slider.value))


func _on_master_changed(value: float) -> void:
	if _protect_vertical_slider_value(master_slider):
		return
	master_value_label.text = "%d%%" % int(round(value))
	if not is_syncing_ui:
		SettingsManager.set_master_volume(value / 100.0)


func _on_music_changed(value: float) -> void:
	if _protect_vertical_slider_value(music_slider):
		return
	music_value_label.text = "%d%%" % int(round(value))
	if not is_syncing_ui:
		SettingsManager.set_music_volume(value / 100.0)


func _on_sfx_changed(value: float) -> void:
	if _protect_vertical_slider_value(sfx_slider):
		return
	sfx_value_label.text = "%d%%" % int(round(value))
	if not is_syncing_ui:
		SettingsManager.set_sfx_volume(value / 100.0)


func _on_reset_pressed() -> void:
	if _scroll_gesture_active:
		return
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
	var source_card: PanelContainer = get_node("SafeArea/Scroll/Content/AudioCard") as PanelContainer
	# Restore Audio Defaults belongs to the Audio card, not between unrelated cards.
	var audio_content: VBoxContainer = source_card.get_node("AudioContent") as VBoxContainer
	var audio_actions: HBoxContainer = parent_box.get_node("Actions") as HBoxContainer
	audio_actions.reparent(audio_content)

	var control_card: PanelContainer = _create_settings_card(
		parent_box, source_card, _local("CONTROLS", "KONTROL"),
		_local("Movement & Joystick", "Gerakan & Joystick"),
		_local("Customize the floating movement control.", "Sesuaikan kontrol gerak mengambang.")
	)
	var control_box: VBoxContainer = control_card.get_child(0) as VBoxContainer
	_add_section_rule(control_box, AQUA)
	_add_setting_label(control_box, _local("Joystick Size", "Ukuran Joystick"),
		_local("Choose a comfortable thumb target.", "Pilih ukuran yang nyaman untuk ibu jari."))
	joystick_size_choice = OptionButton.new()
	joystick_size_choice.name = "JoystickSize"
	joystick_size_choice.add_item(_local("COMPACT", "KECIL"))
	joystick_size_choice.add_item(_local("STANDARD", "NORMAL"))
	joystick_size_choice.add_item(_local("LARGE", "BESAR"))
	joystick_size_choice.custom_minimum_size.y = 56.0
	control_box.add_child(joystick_size_choice)
	_apply_dropdown_polish(joystick_size_choice)
	joystick_size_choice.item_selected.connect(_on_joystick_size_selected)
	_add_setting_label(control_box, _local("Joystick Opacity", "Opasitas Joystick"),
		_local("Adjust visibility during movement.", "Atur keterlihatan saat bergerak."))
	var opacity_row := HBoxContainer.new()
	opacity_row.add_theme_constant_override("separation", 12)
	control_box.add_child(opacity_row)
	joystick_opacity_slider = HSlider.new()
	joystick_opacity_slider.name = "JoystickOpacity"
	joystick_opacity_slider.min_value = 40.0
	joystick_opacity_slider.max_value = 100.0
	joystick_opacity_slider.step = 5.0
	joystick_opacity_slider.custom_minimum_size.y = 54.0
	joystick_opacity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opacity_row.add_child(joystick_opacity_slider)
	joystick_opacity_label = Label.new()
	joystick_opacity_label.custom_minimum_size.x = 64.0
	joystick_opacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	joystick_opacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	opacity_row.add_child(joystick_opacity_label)
	joystick_opacity_slider.value_changed.connect(_on_joystick_opacity_changed)
	reset_controls_button = Button.new()
	reset_controls_button.text = _local("RESET CONTROLS", "RESET KONTROL")
	reset_controls_button.custom_minimum_size.y = 48.0
	control_box.add_child(reset_controls_button)
	reset_controls_button.pressed.connect(_on_reset_controls_pressed)

	var comfort_card: PanelContainer = _create_settings_card(
		parent_box, source_card, _local("COMFORT", "KENYAMANAN"),
		_local("Combat Presentation", "Tampilan Pertarungan"),
		_local("Tune visual feedback without changing combat balance.",
			"Atur efek visual tanpa mengubah keseimbangan pertarungan.")
	)
	var comfort_box: VBoxContainer = comfort_card.get_child(0) as VBoxContainer
	_add_section_rule(comfort_box, JADE)
	var entries: Array[Dictionary] = [
		{"key":"screen_shake", "title":_local("Screen Shake", "Guncangan Layar"),
		 "hint":_local("Camera motion on heavy impacts.", "Gerakan kamera saat hantaman besar.")},
		{"key":"reduced_effects", "title":_local("Reduced Flashes & Effects", "Kurangi Kilatan & Efek"),
		 "hint":_local("Reduce intense visual effects.", "Kurangi efek visual yang intens.")},
		{"key":"damage_numbers", "title":_local("Damage Numbers", "Angka Damage"),
		 "hint":_local("Show damage during combat.", "Tampilkan damage saat bertarung.")},
		{"key":"haptics", "title":_local("Vibration Feedback", "Getaran"),
		 "hint":_local("Vibrate on supported devices.", "Getaran pada perangkat yang mendukung.")}
	]
	for item in entries:
		_add_combat_toggle(comfort_box, item)

	var system_card: PanelContainer = _create_settings_card(
		parent_box, source_card, _local("DISPLAY", "TAMPILAN"),
		_local("Performance & Language", "Performa & Bahasa"),
		_local("Adjust frame rate and language on this device.",
			"Atur frame rate dan bahasa di perangkat ini.")
	)
	var system_box: VBoxContainer = system_card.get_child(0) as VBoxContainer
	_add_section_rule(system_box, GOLD)
	_add_setting_label(system_box, _local("Frame Rate", "Frame Rate"),
		_local("60 FPS for smooth play, 30 FPS to save battery.",
			"60 FPS untuk gerakan halus, 30 FPS untuk hemat baterai."))
	fps_choice = OptionButton.new()
	fps_choice.add_item(tr("60 FPS  •  SMOOTH"))
	fps_choice.add_item(tr("30 FPS  •  BATTERY SAVER"))
	fps_choice.custom_minimum_size.y = 56.0
	fps_choice.item_selected.connect(_on_fps_selected)
	system_box.add_child(fps_choice)
	_apply_dropdown_polish(fps_choice)
	_add_setting_label(system_box, _local("Language", "Bahasa"),
		_local("Interface language; saved automatically.", "Bahasa antarmuka; disimpan otomatis."))
	language_choice = OptionButton.new()
	language_choice.add_item("English")
	language_choice.add_item("Bahasa Indonesia")
	language_choice.custom_minimum_size.y = 56.0
	language_choice.item_selected.connect(_on_language_selected)
	system_box.add_child(language_choice)
	_apply_dropdown_polish(language_choice)
	var privacy := Button.new()
	privacy.text = tr("PRIVACY, SUPPORT & CREDITS")
	privacy.custom_minimum_size.y = 52.0
	privacy.theme_type_variation = &"JadeSecondaryButton"
	privacy.add_theme_font_size_override("font_size", 15)
	privacy.pressed.connect(_open_privacy)
	system_box.add_child(privacy)

	_build_monetization_qa(parent_box, source_card)


func _add_combat_toggle(box: VBoxContainer, item: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 64.0
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var name_label := Label.new()
	name_label.text = str(item.get("title", ""))
	name_label.add_theme_color_override("font_color", IVORY)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(name_label)
	var hint := Label.new()
	hint.text = str(item.get("hint", ""))
	hint.add_theme_color_override("font_color", MUTED)
	hint.add_theme_font_size_override("font_size", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(hint)
	var toggle := CheckButton.new()
	# Toggle only on release so a scroll gesture never commits on touch-down.
	toggle.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	toggle.name = str(item.get("key", ""))
	toggle.custom_minimum_size = Vector2(90, 58)
	toggle.add_theme_color_override("font_color", JADE)
	toggle.add_theme_font_size_override("font_size", 14)
	row.add_child(toggle)
	var key: String = str(item.get("key", ""))
	toggle.toggled.connect(_on_presentation_toggled.bind(key))
	presentation_toggles[key] = toggle
	_add_section_rule(box, Color(0.25, 0.68, 0.60, 0.26))


func _add_setting_label(box: VBoxContainer, name_text: String, hint_text: String) -> void:
	var title := Label.new()
	title.text = name_text
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", IVORY)
	box.add_child(title)
	var hint := Label.new()
	hint.text = hint_text
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", MUTED)
	box.add_child(hint)


func _add_section_rule(box: VBoxContainer, accent: Color) -> void:
	var divider := ColorRect.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = Color(accent.r, accent.g, accent.b, 0.50)
	divider.custom_minimum_size.y = 2.0
	box.add_child(divider)


func _on_joystick_size_selected(index: int) -> void:
	if _scroll_gesture_active:
		_sync_from_settings()
		return
	if is_syncing_ui:
		return
	_save_joystick_preferences(index, joystick_opacity_slider.value / 100.0)


func _on_joystick_opacity_changed(value: float) -> void:
	if _protect_vertical_slider_value(joystick_opacity_slider):
		return
	_update_joystick_opacity_text(value)
	if is_syncing_ui:
		return
	_save_joystick_preferences(joystick_size_choice.selected, value / 100.0)


func _update_joystick_opacity_text(value: float) -> void:
	if joystick_opacity_label != null:
		joystick_opacity_label.text = "%d%%" % int(round(value))


func _save_joystick_preferences(size_index: int, opacity: float) -> void:
	var save_error: Error = ControlPrefs.save_preferences(size_index, opacity)
	if save_error == OK:
		_control_size_index = clampi(size_index, 0, 2)
		_control_opacity = clampf(opacity, 0.40, 1.0)
	else:
		push_warning("SettingsScreen: joystick preferences save failed: " + str(save_error))


func _on_reset_controls_pressed() -> void:
	if _scroll_gesture_active:
		return
	var save_error: Error = ControlPrefs.save_preferences(1, 1.0)
	if save_error == OK:
		_control_size_index = 1
		_control_opacity = 1.0
	else:
		push_warning("SettingsScreen: joystick reset failed: " + str(save_error))
	_sync_from_settings()


func _apply_dropdown_polish(option: OptionButton) -> void:
	if option == null:
		return
	# Native OptionButton defaults to click-on-PRESS. Within ScrollContainer this
	# is indistinguishable from the beginning of a scroll until the finger moves.
	option.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	option.mouse_filter = Control.MOUSE_FILTER_PASS
	option.pressed.connect(_on_dropdown_pressed.bind(option))
	var base_style: StyleBoxFlat = _style_for_control(AQUA)
	base_style.bg_color = Color(0.004, 0.035, 0.048, 0.99)
	base_style.border_color = Color(0.24, 0.82, 0.81, 0.86)
	base_style.content_margin_left = 16.0
	base_style.content_margin_right = 38.0
	base_style.content_margin_top = 12.0
	base_style.content_margin_bottom = 12.0
	var hover: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.013, 0.100, 0.105, 0.99)
	hover.border_color = GOLD
	var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.006, 0.070, 0.080, 1.0)
	var disabled: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.007, 0.022, 0.031, 0.95)
	disabled.border_color = Color(0.36, 0.49, 0.48, 0.62)
	for suffix in ["", "_mirrored"]:
		option.add_theme_stylebox_override("normal" + suffix, base_style)
		option.add_theme_stylebox_override("hover" + suffix, hover)
		option.add_theme_stylebox_override("pressed" + suffix, pressed)
		option.add_theme_stylebox_override("disabled" + suffix, disabled)
	option.add_theme_stylebox_override("focus", hover)
	option.add_theme_color_override("font_color", IVORY)
	option.add_theme_color_override("font_hover_color", GOLD)
	option.add_theme_color_override("font_pressed_color", IVORY)
	option.add_theme_color_override("font_hover_pressed_color", GOLD)
	option.add_theme_color_override("font_focus_color", GOLD)
	option.add_theme_color_override("font_disabled_color", MUTED.darkened(0.30))
	option.add_theme_font_size_override("font_size", 16)
	option.add_theme_constant_override("modulate_arrow", 1)
	option.add_theme_constant_override("arrow_margin", 14)
	var popup: PopupMenu = option.get_popup()
	if popup == null:
		return
	# PopupMenu is a Window, so inherited Control overrides can fall back to
	# Godot's grey default. Give the popup an explicit PopupMenu-only Theme.
	popup.prefer_native_menu = false
	var popup_theme: Theme = Theme.new()
	if theme != null and theme.default_font != null:
		popup_theme.default_font = theme.default_font
	popup_theme.set_font("font", "PopupMenu", option.get_theme_font("font"))
	var popup_panel := StyleBoxFlat.new()
	popup_panel.bg_color = Color(0.003, 0.029, 0.041, 1.0)
	popup_panel.set_border_width_all(2)
	popup_panel.border_color = Color(0.80, 0.65, 0.34, 0.95)
	popup_panel.set_corner_radius_all(10)
	popup_panel.content_margin_left = 8.0
	popup_panel.content_margin_right = 8.0
	popup_panel.content_margin_top = 8.0
	popup_panel.content_margin_bottom = 8.0
	popup_panel.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	popup_panel.shadow_size = 10
	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = Color(0.040, 0.164, 0.158, 1.0)
	popup_hover.set_border_width_all(1)
	popup_hover.border_color = Color(0.96, 0.77, 0.37, 0.95)
	popup_hover.set_corner_radius_all(6)
	popup_hover.content_margin_left = 7.0
	popup_hover.content_margin_right = 7.0
	popup_hover.content_margin_top = 5.0
	popup_hover.content_margin_bottom = 5.0
	var popup_separator := StyleBoxFlat.new()
	popup_separator.bg_color = Color(0.31, 0.80, 0.69, 0.46)
	popup_separator.content_margin_top = 1.0
	popup_separator.content_margin_bottom = 1.0
	popup_theme.set_stylebox("panel", "PopupMenu", popup_panel)
	popup_theme.set_stylebox("hover", "PopupMenu", popup_hover)
	popup_theme.set_stylebox("separator", "PopupMenu", popup_separator)
	popup_theme.set_stylebox("labeled_separator_left", "PopupMenu", popup_separator)
	popup_theme.set_stylebox("labeled_separator_right", "PopupMenu", popup_separator)
	popup_theme.set_color("font_color", "PopupMenu", IVORY)
	popup_theme.set_color("font_hover_color", "PopupMenu", Color(1.0, 0.90, 0.65, 1.0))
	popup_theme.set_color("font_disabled_color", "PopupMenu", MUTED.darkened(0.3))
	popup_theme.set_color("font_separator_color", "PopupMenu", JADE)
	popup_theme.set_color("font_outline_color", "PopupMenu", Color(0.0, 0.0, 0.0, 0.96))
	popup_theme.set_font_size("font_size", "PopupMenu", 16)
	popup_theme.set_constant("outline_size", "PopupMenu", 1)
	popup_theme.set_constant("v_separation", "PopupMenu", 11)
	popup_theme.set_constant("item_start_padding", "PopupMenu", 14)
	popup_theme.set_constant("item_end_padding", "PopupMenu", 14)
	popup_theme.set_constant("h_separation", "PopupMenu", 8)
	popup.theme = popup_theme
	# Direct overrides make the appearance explicit even when a parent theme
	# is updated by the shared mobile style pass after Settings._ready().
	popup.add_theme_stylebox_override("panel", popup_panel)
	popup.add_theme_stylebox_override("hover", popup_hover)
	popup.add_theme_stylebox_override("separator", popup_separator)
	popup.add_theme_color_override("font_color", IVORY)
	popup.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.65, 1.0))
	popup.add_theme_font_size_override("font_size", 16)



func _on_dropdown_pressed(option: OptionButton) -> void:
	if not _scroll_gesture_active:
		return
	# If Godot still activates an OptionButton at finger release following a
	# swipe, collapse the popup before its first rendered frame.
	option.get_popup().hide.call_deferred()


func _style_for_control(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.005, 0.045, 0.061, 0.99)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 2
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.82)
	sb.corner_radius_top_left = 9
	sb.corner_radius_top_right = 9
	sb.corner_radius_bottom_left = 9
	sb.corner_radius_bottom_right = 9
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.11)
	sb.shadow_size = 4
	return sb


func _make_premium_card_style(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.004, 0.029, 0.042, 0.977)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 3
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.75)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 20.0
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.14)
	sb.shadow_size = 11
	sb.expand_margin_left = 1.0
	sb.expand_margin_right = 1.0
	sb.expand_margin_top = 1.0
	sb.expand_margin_bottom = 1.0
	return sb


func _apply_settings_visual_polish() -> void:
	_settings_scroll = get_node("SafeArea/Scroll") as ScrollContainer
	var content: VBoxContainer = get_node("SafeArea/Scroll/Content") as VBoxContainer
	content.add_theme_constant_override("separation", 18)
	_settings_scroll.anchor_top = 0.10
	_settings_scroll.anchor_bottom = 0.975
	_settings_scroll.scroll_deadzone = int(SCROLL_GESTURE_DEADZONE)
	_settings_scroll.follow_focus = false
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# SafeArea already applies device insets, so this pinned rail never covers a notch.
	_build_sticky_navigation()
	var header: PanelContainer = content.get_node("Header") as PanelContainer
	header.custom_minimum_size.y = 124.0
	header.add_theme_stylebox_override("panel", _make_premium_card_style(GOLD))
	_stylize_header(header)
	var audio: PanelContainer = content.get_node("AudioCard") as PanelContainer
	audio.custom_minimum_size.y = 0.0
	audio.add_theme_stylebox_override("panel", _make_premium_card_style(JADE))
	_styled_cards.append(audio)
	var audio_content: VBoxContainer = audio.get_node("AudioContent") as VBoxContainer
	audio_content.add_theme_constant_override("separation", 13)
	var audio_eyebrow: Label = audio.get_node("AudioContent/AudioHeading/AudioText/AudioEyebrow") as Label
	var audio_title: Label = audio.get_node("AudioContent/AudioHeading/AudioText/AudioTitle") as Label
	audio_eyebrow.add_theme_font_size_override("font_size", 13)
	audio_title.add_theme_font_size_override("font_size", 23)
	audio_title.add_theme_color_override("font_color", GOLD)
	routing_status_label.add_theme_font_size_override("font_size", 12)
	routing_status_label.add_theme_color_override("font_color", JADE)
	_add_section_rule(audio_content, JADE)
	for key in ["Master", "Music", "SFX"]:
		_stylize_audio_row(audio, key)
	var note: Label = audio.get_node("AudioContent/PersistenceNote") as Label
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", MUTED)
	note.text = _local("Changes apply instantly • saved on this device",
		"Langsung diterapkan • tersimpan di perangkat")
	reset_button.custom_minimum_size.y = 52.0
	reset_button.add_theme_font_size_override("font_size", 14)
	_stylize_button(reset_button, GOLD)
	# Runtime-generated cards also get premium visuals in one consistent pass.
	var dynamic_cards: Array[PanelContainer] = []
	for child in content.get_children():
		if child is PanelContainer and child != header and child != audio:
			dynamic_cards.append(child as PanelContainer)
	var accents: Array[Color] = [AQUA, JADE, GOLD, Color(0.67, 0.50, 0.90, 1.0)]
	for index in range(dynamic_cards.size()):
		var accent: Color = accents[mini(index, accents.size() - 1)]
		var card: PanelContainer = dynamic_cards[index]
		card.add_theme_stylebox_override("panel", _make_premium_card_style(accent))
		_styled_cards.append(card)
		_stylize_dynamic_card(card, accent)
	if joystick_opacity_slider != null:
		_style_slider(joystick_opacity_slider, AQUA)
	if joystick_opacity_label != null:
		joystick_opacity_label.add_theme_color_override("font_color", GOLD)
		joystick_opacity_label.add_theme_font_size_override("font_size", 16)
	if reset_controls_button != null:
		_stylize_button(reset_controls_button, AQUA)
	content.add_theme_constant_override("separation", 18)


func _build_sticky_navigation() -> void:
	var safe_area: Control = get_node("SafeArea") as Control
	var old_top: HBoxContainer = get_node("SafeArea/Scroll/Content/TopRow") as HBoxContainer
	var rail := PanelContainer.new()
	rail.name = "PinnedSettingsNav"
	rail.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rail.anchor_left = 0.055
	rail.anchor_right = 0.945
	rail.anchor_top = 0.018
	rail.anchor_bottom = 0.018
	rail.offset_bottom = 71.0
	rail.mouse_filter = Control.MOUSE_FILTER_PASS
	var rail_style: StyleBoxFlat = _make_premium_card_style(GOLD)
	rail_style.content_margin_top = 8.0
	rail_style.content_margin_bottom = 8.0
	rail.add_theme_stylebox_override("panel", rail_style)
	safe_area.add_child(rail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	rail.add_child(row)
	back_button.reparent(row)
	back_button.custom_minimum_size = Vector2(104, 49)
	back_button.text = _local("‹  HOME", "‹  BERANDA")
	_stylize_button(back_button, GOLD)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var status := Label.new()
	status.text = _local("SETTINGS  •  DEVICE", "PENGATURAN  •  PERANGKAT")
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", JADE)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(status)
	old_top.hide()


func _stylize_header(header: PanelContainer) -> void:
	var icon: TextureRect = header.get_node("HeaderRow/SettingsIcon") as TextureRect
	icon.custom_minimum_size = Vector2(70, 70)
	icon.modulate = Color(0.45, 1.0, 0.85, 1.0)
	var text_group: VBoxContainer = header.get_node("HeaderRow/HeaderText") as VBoxContainer
	text_group.add_theme_constant_override("separation", 4)
	var eyebrow: Label = text_group.get_node("Eyebrow") as Label
	var title: Label = text_group.get_node("Title") as Label
	var subtitle: Label = text_group.get_node("Subtitle") as Label
	eyebrow.text = "JADE ASCENDANT  •  SANCTUARY"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", JADE)
	title.text = _local("SETTINGS", "PENGATURAN")
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	subtitle.text = _local("Shape your journey • changes save automatically",
		"Sesuaikan perjalanan • perubahan disimpan otomatis")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", MUTED)


func _stylize_audio_row(audio: PanelContainer, key: String) -> void:
	var row: VBoxContainer = audio.get_node("AudioContent/%sRow" % key) as VBoxContainer
	row.add_theme_constant_override("separation", 7)
	var name_label: Label = row.get_node("%sTop/%sLabel" % [key, key]) as Label
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", IVORY)
	var hint: Label = row.get_node("%sHint" % key) as Label
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var value_label: Label = row.get_node("%sTop/%sValueLabel" % [key, key]) as Label
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", GOLD)
	var slider: HSlider = row.get_node("%sSlider" % key) as HSlider
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size.y = 48.0
	_style_slider(slider, JADE)


func _style_slider(slider: HSlider, accent: Color) -> void:
	var jade_knob: Texture2D = load("res://assets/ui/settings/jade_slider_knob.svg") as Texture2D
	if jade_knob != null:
		slider.add_theme_icon_override("grabber", jade_knob)
		slider.add_theme_icon_override("grabber_highlight", jade_knob)
	var track: StyleBoxFlat = _style_for_control(accent)
	track.bg_color = Color(0.001, 0.017, 0.028, 1.0)
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	track.corner_radius_top_left = 7
	track.corner_radius_top_right = 7
	track.corner_radius_bottom_left = 7
	track.corner_radius_bottom_right = 7
	var fill: StyleBoxFlat = track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(accent.r, accent.g, accent.b, 0.96)
	fill.border_color = GOLD
	fill.shadow_color = Color(accent.r, accent.g, accent.b, 0.40)
	fill.shadow_size = 7
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)


func _stylize_button(button: Button, accent: Color) -> void:
	var normal: StyleBoxFlat = _style_for_control(accent)
	normal.bg_color = Color(0.009, 0.080, 0.092, 0.97)
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.border_color = GOLD
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.30)
	hover.shadow_size = 7
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.013, 0.12, 0.13, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", GOLD)


func _stylize_dynamic_card(card: PanelContainer, accent: Color) -> void:
	var box: VBoxContainer = card.get_child(0) as VBoxContainer
	box.add_theme_constant_override("separation", 10)
	if box.get_child_count() >= 3:
		var eyebrow: Label = box.get_child(0) as Label
		var title: Label = box.get_child(1) as Label
		var subtitle: Label = box.get_child(2) as Label
		if eyebrow != null:
			eyebrow.add_theme_font_size_override("font_size", 12)
			eyebrow.add_theme_color_override("font_color", accent)
		if title != null:
			title.add_theme_font_size_override("font_size", 22)
			title.add_theme_color_override("font_color", GOLD)
		if subtitle != null:
			subtitle.add_theme_font_size_override("font_size", 14)
			subtitle.add_theme_color_override("font_color", MUTED)


func _play_settings_entrance() -> void:
	if SettingsManager.reduced_effects:
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for i in range(_styled_cards.size()):
		var card: PanelContainer = _styled_cards[i]
		card.modulate.a = 0.0
		tween.tween_property(card, "modulate:a", 1.0, 0.22).set_delay(0.045 * float(i))


func _create_settings_card(parent_box: VBoxContainer, source_card: PanelContainer,
		eyebrow: String, title_text: String, subtitle_text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", source_card.get_theme_stylebox("panel"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var eyebrow_label := Label.new()
	eyebrow_label.text = eyebrow
	eyebrow_label.add_theme_font_size_override("font_size", 12)
	eyebrow_label.add_theme_color_override("font_color", JADE)
	box.add_child(eyebrow_label)
	var title_label := Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", GOLD)
	box.add_child(title_label)
	var subtitle_label := Label.new()
	subtitle_label.text = subtitle_text
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", MUTED)
	box.add_child(subtitle_label)
	parent_box.add_child(card)
	return card


func _open_privacy() -> void:
	if _scroll_gesture_active:
		return
	if SceneTransitionManager.is_transitioning:
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(
		"res://scenes/ui/privacy_screen.tscn", 1
	)
	if change_error != OK:
		push_error("SettingsScreen: gagal membuka Privacy. Error code: " + str(change_error))


func _on_presentation_toggled(enabled: bool, key: String) -> void:
	if _scroll_gesture_active:
		_sync_from_settings()
		return
	SettingsManager.set_presentation(key, enabled)


func _on_fps_selected(index: int) -> void:
	if _scroll_gesture_active:
		_sync_from_settings()
		return
	SettingsManager.set_presentation("frame_limit", 60 if index == 0 else 30)


func _on_language_selected(index: int) -> void:
	if _scroll_gesture_active:
		_sync_from_settings()
		return
	SettingsManager.set_presentation("language", "id" if index == 1 else "en")
	get_tree().reload_current_scene.call_deferred()


## Debug-only AdMob/UMP QA. Existing behavior intentionally remains separate
## from the release Settings surface and never grants in-game currency.
func _build_monetization_qa(parent_box: VBoxContainer, source_card: PanelContainer) -> void:
	if not OS.is_debug_build():
		return
	var qa_card: PanelContainer = _create_settings_card(
		parent_box, source_card, "DEBUG QA", "Monetization Runtime",
		"Test-only AdMob/UMP diagnostics. Excluded from release behavior."
	)
	var qa_box: VBoxContainer = qa_card.get_child(0) as VBoxContainer
	monetization_qa_status_label = Label.new()
	monetization_qa_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	monetization_qa_status_label.add_theme_font_size_override("font_size", 12)
	monetization_qa_status_label.add_theme_color_override("font_color", MUTED)
	qa_box.add_child(monetization_qa_status_label)
	monetization_qa_event_label = Label.new()
	monetization_qa_event_label.text = "Last event: none"
	monetization_qa_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	monetization_qa_event_label.add_theme_font_size_override("font_size", 12)
	monetization_qa_event_label.add_theme_color_override("font_color", GOLD)
	qa_box.add_child(monetization_qa_event_label)
	monetization_qa_rewarded_button = Button.new()
	monetization_qa_rewarded_button.text = "SHOW GOOGLE TEST REWARDED"
	monetization_qa_rewarded_button.custom_minimum_size.y = 52.0
	monetization_qa_rewarded_button.theme_type_variation = &"JadeSecondaryButton"
	monetization_qa_rewarded_button.pressed.connect(_on_monetization_qa_rewarded_pressed)
	qa_box.add_child(monetization_qa_rewarded_button)
	monetization_qa_privacy_button = Button.new()
	monetization_qa_privacy_button.text = "OPEN PRIVACY OPTIONS"
	monetization_qa_privacy_button.custom_minimum_size.y = 52.0
	monetization_qa_privacy_button.theme_type_variation = &"JadeSecondaryButton"
	monetization_qa_privacy_button.pressed.connect(_on_monetization_qa_privacy_pressed)
	qa_box.add_child(monetization_qa_privacy_button)
	var warning_label := Label.new()
	warning_label.text = (
		"QA only • reward callback is observed but no Pavilion currency is granted."
	)
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.add_theme_font_size_override("font_size", 11)
	warning_label.add_theme_color_override("font_color", MUTED)
	qa_box.add_child(warning_label)
	if not MonetizationManager.operation_finished.is_connected(_on_monetization_qa_operation_finished):
		MonetizationManager.operation_finished.connect(_on_monetization_qa_operation_finished)
	if not MonetizationManager.rewarded_completed.is_connected(_on_monetization_qa_rewarded_completed):
		MonetizationManager.rewarded_completed.connect(_on_monetization_qa_rewarded_completed)
	monetization_qa_timer = Timer.new()
	monetization_qa_timer.wait_time = 0.5
	monetization_qa_timer.one_shot = false
	monetization_qa_timer.timeout.connect(_refresh_monetization_qa)
	add_child(monetization_qa_timer)
	monetization_qa_timer.start()
	_refresh_monetization_qa()


func _refresh_monetization_qa() -> void:
	if (
		not OS.is_debug_build()
		or monetization_qa_status_label == null
		or not is_instance_valid(monetization_qa_status_label)
	):
		return
	var status: Dictionary = MonetizationManager.get_provider_runtime_status()
	var provider_name: String = str(status.get("provider", "unknown"))
	var state_name: String = str(status.get("state", "unknown"))
	var consent_open: bool = bool(status.get("consent_gate_open", false))
	var ads_initialized: bool = bool(status.get("ads_initialized", false))
	var rewarded_loading: bool = bool(status.get("rewarded_loading", false))
	var rewarded_ready: bool = bool(status.get("rewarded_ready", false))
	var privacy_required: bool = bool(status.get("privacy_options_required", false))
	monetization_qa_status_label.text = (
		"Provider: %s\nState: %s\nConsent gate: %s  •  SDK: %s\n"
		+ "Rewarded: %s  •  Privacy options: %s"
	) % [
		provider_name,
		state_name,
		"OPEN" if consent_open else "CLOSED",
		"READY" if ads_initialized else "WAIT",
		"READY" if rewarded_ready else ("LOADING" if rewarded_loading else "WAIT"),
		"REQUIRED" if privacy_required else "NOT REQUIRED"
	]
	var placement: String = _next_monetization_qa_placement()
	monetization_qa_rewarded_button.disabled = not (
		OS.get_name() == "Android" and MonetizationManager.rewarded_available(placement)
	)
	monetization_qa_privacy_button.disabled = not (
		OS.get_name() == "Android" and MonetizationManager.privacy_options_required()
	)


func _next_monetization_qa_placement() -> String:
	return "qa_rewarded_%d" % (monetization_qa_sequence + 1)


func _on_monetization_qa_rewarded_pressed() -> void:
	if _scroll_gesture_active:
		return
	var placement: String = _next_monetization_qa_placement()
	if MonetizationManager.show_rewarded(placement):
		monetization_qa_sequence += 1
		monetization_qa_event_label.text = "Last event: request started • " + placement
	else:
		monetization_qa_event_label.text = "Last event: rewarded unavailable"
	_refresh_monetization_qa()


func _on_monetization_qa_privacy_pressed() -> void:
	if _scroll_gesture_active:
		return
	if MonetizationManager.show_privacy_options():
		monetization_qa_event_label.text = "Last event: privacy options opened"
	else:
		monetization_qa_event_label.text = "Last event: privacy options unavailable"
	_refresh_monetization_qa()


func _on_monetization_qa_operation_finished(status: String) -> void:
	if monetization_qa_event_label == null:
		return
	monetization_qa_event_label.text = "Last event: request finished • " + status
	_refresh_monetization_qa()


func _on_monetization_qa_rewarded_completed(placement: String) -> void:
	if monetization_qa_event_label == null:
		return
	monetization_qa_event_label.text = "Last event: REWARD CALLBACK OK • " + placement
	_refresh_monetization_qa()
