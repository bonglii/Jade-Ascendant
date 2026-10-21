extends "res://scripts/ui/trials_production_presenter_unified_reward.gd"

## Approved Ascendant Trials. Managers remain the only reward/save authority.
const DAILY_ART = preload("res://assets/ui/trials/ascendant_v2/daily_header.png")
const RECORDS_ART = preload("res://assets/ui/trials/ascendant_v2/records_header.png")
const SEAL = preload("res://scripts/ui/trials_engraved_seal.gd")
var header_art: TextureRect
var header_panel: PanelContainer
var header_progress: Label
var reset_label: Label
var filters: GridContainer
var footer: VBoxContainer
var selected_filter: String = "all"
var filter_buttons: Dictionary = {}
var clock_tick: float = 0.0
var observed_date: String = ""
var completion_reward: Label
var hall_title: Label
const DISPLAY_FONT = preload("res://assets/ui/library/fonts/archive_serif.ttf")
const FRAME = preload("res://assets/ui/trials/ascendant_v2/record_frame.svg")
const CLAIM_FRAME = preload("res://assets/ui/trials/ascendant_v2/claim_button.svg")

func _label(text_value: String, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = text_value
	label.set_meta("jade_mobile_readability_v2", true)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e9e4cd"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _surface(accent: Color, strong: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10332e") if strong else Color("081d1c")
	style.border_color = accent
	style.set_border_width_all(2 if strong else 1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	return style

func _carved(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 18
	style.texture_margin_right = 18
	style.texture_margin_top = 18
	style.texture_margin_bottom = 18
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _button(text_value: String, gold: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.set_meta("jade_mobile_readability_v2", true)
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 17)
	var accent := Color("bda16a") if gold else Color("50776a")
	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, _surface(accent, gold))
	if gold:
		for state: String in ["normal", "hover", "focus"]:
			button.add_theme_stylebox_override(state, _carved(CLAIM_FRAME))
	button.add_theme_stylebox_override("pressed", _surface(JADE, true))
	button.add_theme_stylebox_override("disabled", _surface(Color("30443d")))
	return button

func _build_presentation() -> void:
	PavilionManager.pavilion_changed.connect(_queue_refresh)
	var old_overlay := scene_root.get_node_or_null("TrialsHallOverlay") as CanvasItem
	if old_overlay != null:
		old_overlay.hide()
		old_overlay.set_process(false)
	presentation_root = Control.new()
	presentation_root.name = "ApprovedTrialsPresentation"
	content_root.add_child(presentation_root)
	presentation_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	presentation_root.anchor_left = 0.035
	presentation_root.anchor_right = 0.965
	presentation_root.offset_top = 78
	presentation_root.offset_bottom = -108
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 10)
	presentation_root.add_child(layout)
	hall_title = _label(tr("TRIALS"), 36)
	var title: Label = hall_title
	title.add_theme_font_override("font", DISPLAY_FONT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"JadeTitle"
	layout.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)
	daily_tab = _button(tr("DAILY"))
	achievement_tab = _button(tr("ACHIEVEMENTS"))
	for tab: Button in [daily_tab, achievement_tab]:
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab)
	daily_tab.pressed.connect(_switch_section.bind("daily"))
	achievement_tab.pressed.connect(_switch_section.bind("achievement"))
	header_panel = PanelContainer.new()
	header_panel.clip_contents = true
	header_panel.add_theme_stylebox_override("panel", _carved(FRAME))
	layout.add_child(header_panel)
	header_art = TextureRect.new()
	header_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	header_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_panel.add_child(header_art)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	header_panel.add_child(info)
	section_title = _label("", 30)
	section_title.theme_type_variation = &"JadeTitle"
	section_title.add_theme_font_override("font", DISPLAY_FONT)
	section_title.add_theme_color_override("font_shadow_color", Color.BLACK)
	section_title.add_theme_constant_override("shadow_offset_y", 2)
	info.add_child(section_title)
	header_progress = _label("", 19)
	info.add_child(header_progress)
	reset_label = _label("", 16)
	reset_label.add_theme_color_override("font_color", MUTED)
	info.add_child(reset_label)
	filters = GridContainer.new()
	filters.columns = 4
	filters.add_theme_constant_override("separation", 4)
	layout.add_child(filters)
	for category: String in ["all", "combat", "journey", "cultivation"]:
		var chip := _button(tr(category.to_upper()))
		chip.add_theme_font_size_override("font_size", 14)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chip_style := _surface(Color("547261"))
		chip_style.content_margin_left = 4
		chip_style.content_margin_right = 4
		chip.add_theme_stylebox_override("normal", chip_style)
		chip.add_theme_stylebox_override("hover", chip_style)
		chip.pressed.connect(_select_filter.bind(category))
		filters.add_child(chip)
		filter_buttons[category] = chip
	for section: String in ["daily", "achievement"]:
		var scroll := ScrollContainer.new()
		scroll.name = "TrialsScrollDaily" if section == "daily" else "TrialsScrollAchievement"
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll.gui_input.connect(_on_trials_scroll_gui_input)
		layout.add_child(scroll)
		var records := VBoxContainer.new()
		records.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		records.add_theme_constant_override("separation", 10)
		scroll.add_child(records)
		if section == "daily":
			daily_scroll = scroll
			daily_list = records
		else:
			achievement_scroll = scroll
			achievement_list = records
	footer = VBoxContainer.new()
	layout.add_child(footer)
	claim_all_button = _button("", true)
	claim_all_button.custom_minimum_size.y = 56
	claim_all_button.pressed.connect(_on_claim_all_pressed)
	footer.add_child(claim_all_button)
	completion_reward = _label("",15)
	completion_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	completion_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_reward.add_theme_color_override("font_color",GOLD)
	footer.add_child(completion_reward)
	presentation_root.resized.connect(_adapt_header)
	_adapt_header()

func _adapt_header() -> void:
	if header_panel == null:
		return
	var compact: bool = presentation_root.size.y < 800
	var landscape: bool = presentation_root.size.y < 390 and presentation_root.size.x > 600
	hall_title.visible = not landscape and presentation_root.size.y >= 450
	header_progress.visible = not landscape
	reset_label.visible = not landscape and presentation_root.size.y >= 450
	filters.columns = 2 if presentation_root.size.x < 310 else 4
	header_panel.custom_minimum_size.y = 66 if landscape else 86 if presentation_root.size.y < 450 else 150 if compact else 210
	section_title.add_theme_font_size_override("font_size", 22 if presentation_root.size.y < 450 else 27 if compact else 32)
	for cards: Dictionary in [daily_card_nodes, achievement_card_nodes]:
		for card: PanelContainer in cards.values():
			_adapt_card(card)

func _refresh() -> void:
	if list_host == null:
		return
	var is_daily: bool = active_section == "daily"
	if is_daily:
		DailyQuestManager.refresh_daily_date()
	observed_date = DailyQuestManager.get_current_date_key()
	section_title.text = tr("Daily Disciplines") if is_daily else tr("Eternal Records")
	header_art.texture = DAILY_ART if is_daily else RECORDS_ART
	var completed: int = DailyQuestManager.get_completed_count() if is_daily else AchievementManager.get_unlocked_count()
	var total: int = DailyQuestManager.get_daily_quest_ids().size() if is_daily else AchievementManager.get_achievement_ids().size()
	header_progress.text = tr("%d / %d completed") % [completed, total]
	filters.visible = not is_daily
	footer.visible = is_daily
	claim_all_button.disabled = _get_claimable_count() <= 0
	claim_all_button.text = tr("CLAIM ALL · %d STONES") % _get_total_claimable_reward() if not claim_all_button.disabled else tr("NO REWARDS READY")
	var completion: Dictionary = PavilionManager.get_daily_completion_reward_preview()
	completion_reward.text = tr("Complete all daily trials: ") + RewardManager.get_reward_summary(completion).replace("\n"," · ") if not completion.is_empty() else tr("Daily completion bonus claimed")
	for tab: Button in [daily_tab, achievement_tab]:
		var selected: bool = (tab == daily_tab) == is_daily
		for state: String in ["normal", "hover"]:
			var tab_style: StyleBox = _surface(Color("446255"))
			if selected:
				tab_style = _carved(CLAIM_FRAME)
			tab.add_theme_stylebox_override(state, tab_style)
	_update_clock()
	_sync_trial_cards(_get_sorted_record_ids())

func _process(delta: float) -> void:
	clock_tick += delta
	if clock_tick < 1.0:
		return
	clock_tick = 0
	_update_clock()
	if observed_date != DailyQuestManager.get_current_date_key():
		_refresh()

func _update_clock() -> void:
	if reset_label == null:
		return
	if active_section != "daily":
		reset_label.text = tr("Your path, recorded forever")
		return
	var clock: Dictionary = Time.get_time_dict_from_system()
	var remaining: int = 86400 - int(clock.hour) * 3600 - int(clock.minute) * 60 - int(clock.second)
	reset_label.text = tr("Resets in %02d:%02d:%02d") % [floori(remaining / 3600.0), floori((remaining % 3600) / 60.0), remaining % 60]

func _sync_trial_cards(record_ids: Array[String]) -> void:
	await super._sync_trial_cards(record_ids)
	_apply_record_filter()

func _select_filter(category: String) -> void:
	selected_filter = category
	achievement_scroll.scroll_vertical = 0
	_apply_record_filter()

func _apply_record_filter() -> void:
	for record_id: String in achievement_card_nodes:
		var card: PanelContainer = achievement_card_nodes[record_id]
		var data: Dictionary = AchievementManager.get_achievement_data(record_id)
		var category: String = str(data.get("category", "journey"))
		var group: String = "combat" if category in ["combat", "boss"] else "cultivation" if category in ["cultivation", "progression"] else "journey"
		card.visible = selected_filter == "all" or selected_filter == group
	for category: String in filter_buttons:
		var button: Button = filter_buttons[category]
		button.add_theme_color_override("font_color", GOLD if category == selected_filter else MUTED)

func _build_trial_card(record_id: String) -> PanelContainer:
	var data: Dictionary = _get_record_data(record_id)
	var claimed: bool = _is_claimed(record_id)
	var claimable: bool = _is_claimable(record_id)
	var card := PanelContainer.new()
	card.set_meta("record_id", record_id)
	card.custom_minimum_size.y = 150
	card.add_theme_stylebox_override("panel", _carved(FRAME))
	var row := HBoxContainer.new()
	row.name = "RecordRow"
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var seal := SEAL.new()
	seal.name = "CategorySeal"
	seal.custom_minimum_size = Vector2(48 if presentation_root.size.x < 400 else 64, 76)
	seal.configure(str(data.get("category", "trial")), "claimed" if claimed else "ready" if claimable else "in_progress", active_section == "daily")
	row.add_child(seal)
	var body := VBoxContainer.new()
	body.name = "RecordBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	row.add_child(body)
	var title := _label(tr(str(data.get("title", record_id))), 23)
	title.add_theme_font_override("font", DISPLAY_FONT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	var description := _label(tr(str(data.get("description", ""))), 16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", MUTED)
	body.add_child(description)
	var progress_row := HBoxContainer.new()
	body.add_child(progress_row)
	var bar := ProgressBar.new()
	bar.name = "TrialProgressBar"
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size.y = 6
	bar.show_percentage = false
	bar.max_value = maxi(1, _get_target(record_id))
	bar.value = _get_progress(record_id)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("21382e")
	track.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = JADE if claimed else GOLD
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	progress_row.add_child(bar)
	var progress_text := _label("%d / %d" % [_get_progress(record_id), _get_target(record_id)], 16)
	progress_text.name = "TrialProgressText"
	progress_row.add_child(progress_text)
	var actions := BoxContainer.new()
	actions.vertical = true
	actions.name = "RecordActions"
	actions.custom_minimum_size.x = 94
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(actions)
	var reward := HBoxContainer.new()
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(reward)
	var stone := TextureRect.new()
	stone.texture = load(SPIRIT_STONE_ICON_PATH) as Texture2D
	stone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stone.custom_minimum_size = Vector2(24, 24)
	reward.add_child(stone)
	reward.add_child(_label(str(_get_reward(record_id)), 21))
	if active_section == "achievement":
		var premium: Dictionary = preload("res://scripts/data/earned_reward_catalog.gd").premium(RewardManager.SOURCE_ACHIEVEMENT,record_id)
		if not premium.is_empty():
			actions.set_meta("premium_reward",true)
			for currency: String in ["celestial_jade","pavilion_seal"]:
				var amount: int=int(premium.get(currency,0))
				if amount<=0:continue
				var currency_icon:=TextureRect.new()
				currency_icon.texture=load("res://assets/ui/shared/resources/"+currency+"_premium.png") as Texture2D
				currency_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
				currency_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				currency_icon.custom_minimum_size=Vector2(24,24)
				reward.add_child(currency_icon)
				var amount_label:=_label(preload("res://scripts/ui/readable_numbers.gd").compact(amount),18)
				amount_label.name="PremiumRewardAmount";amount_label.autowrap_mode=TextServer.AUTOWRAP_OFF
				amount_label.add_theme_color_override("font_color",GOLD)
				reward.add_child(amount_label)
	var action := _button(tr("CLAIM") if claimable else tr("CLAIMED") if claimed else tr("GO") if active_section == "daily" else tr("ONGOING"), claimable)
	action.add_theme_font_size_override("font_size", 14)
	action.disabled = claimed or (active_section != "daily" and not claimable)
	if action.disabled:action.mouse_filter=Control.MOUSE_FILTER_IGNORE
	actions.add_child(action)
	if claimable:
		action.pressed.connect(_on_single_claim.bind(record_id))
	elif not claimed and active_section == "daily":
		action.pressed.connect(_go_to_journey)
	_adapt_card(card)
	return card

func _adapt_card(card: PanelContainer) -> void:
	var row := card.find_child("RecordRow", true, false) as HBoxContainer
	var body := card.find_child("RecordBody", true, false) as VBoxContainer
	var actions := card.find_child("RecordActions", true, false) as BoxContainer
	var seal := card.find_child("CategorySeal", true, false) as Control
	if row == null or body == null or actions == null:
		return
	var narrow: bool = presentation_root.size.x < 430
	var destination: Node = row
	if narrow:
		destination = body
	if actions.get_parent() != destination:
		actions.reparent(destination, false)
	actions.vertical = not narrow or bool(actions.get_meta("premium_reward",false))
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12 if narrow else 4)
	seal.custom_minimum_size.x = 48 if narrow else 64

func _go_to_journey() -> void:
	if _claim_input_blocked():
		return
	if not SceneTransitionManager.is_transitioning:
		SceneTransitionManager.transition_menu_to("res://scenes/ui/chapter_select.tscn")

func _on_claim_all_pressed() -> void:
	if active_section == "daily":
		super._on_claim_all_pressed()

func _play_intro() -> void:
	pass

func _prime_trials_readability(root: Node) -> void:
	if root == presentation_root or (presentation_root != null and presentation_root.is_ancestor_of(root)):
		return
	super._prime_trials_readability(root)
