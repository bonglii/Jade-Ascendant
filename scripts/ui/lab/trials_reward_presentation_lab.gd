extends Control

## TRIALS REWARD PRESENTATION LAB
## Visual / interaction prototype only.
## Does NOT call AchievementManager, DailyQuestManager, RewardManager,
## ProgressionManager or SaveManager. No player progress can be changed.

const TRIALS_BG_PATH: String = "res://assets/ui/trials/trials_hall.png"
const DAILY_ICON_PATH: String = "res://assets/ui/icons/actions/daily.png"
const ACHIEVEMENT_ICON_PATH: String = "res://assets/ui/icons/actions/achievement.png"
const SPIRIT_STONE_ICON_PATH: String = (
	"res://assets/ui/shared/resources/spirit_stone_premium.png"
)
const REFINEMENT_SHARD_ICON_PATH: String = (
	"res://assets/ui/shared/resources/refinement_shard_premium.png"
)
const CELESTIAL_JADE_ICON_PATH: String = (
	"res://assets/ui/shared/resources/celestial_jade_premium.png"
)
const PAVILION_SEAL_ICON_PATH: String = (
	"res://assets/ui/shared/resources/pavilion_seal_premium.png"
)

const HubNavScript = preload("res://scripts/ui/wuxia_hub_nav.gd")
const TrialsHallOverlayScript = preload(
	"res://scripts/ui/trials_hall_overlay.gd"
)

const GOLD := Color(0.96, 0.78, 0.34, 1.0)
const JADE := Color(0.25, 0.88, 0.72, 1.0)
const CYAN := Color(0.30, 0.78, 0.92, 1.0)
const MUTED := Color(0.67, 0.76, 0.75, 1.0)
const OBSIDIAN := Color(0.003, 0.014, 0.024, 0.96)

var active_section: String = "daily"
var mock_balance: int = 1420
var daily_claimed: Dictionary = {
	"daily_extermination": false,
	"daily_cultivation": false,
	"daily_ascension": true,
}
var achievement_claimed: Dictionary = {
	"first_blood": false,
	"path_opened": false,
	"boss_breaker": true,
}

var content_host: VBoxContainer
var daily_tab: Button
var achievement_tab: Button
var ready_value_label: Label
var reward_value_label: Label
var claim_all_button: Button
var list_host: VBoxContainer
var overlay: Control
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_source: Label
var overlay_amount: Label
var overlay_balance: Label
var overlay_icon: TextureRect
var overlay_chips: HBoxContainer
var overlay_close: Button
var intro_tween: Tween
var overlay_tween: Tween
var hall_overlay: Control
var hub_nav: Control

var daily_records: Array[Dictionary] = [
	{
		"id": "daily_extermination",
		"title": "Daily Extermination",
		"description": "Defeat 20 enemies.",
		"category": "COMBAT",
		"progress": 20,
		"target": 20,
		"reward": 25,
		"state": "reward_ready",
	},
	{
		"id": "daily_cultivation",
		"title": "Daily Cultivation",
		"description": "Reach Level 5 during a run.",
		"category": "PROGRESSION",
		"progress": 5,
		"target": 5,
		"reward": 25,
		"state": "reward_ready",
	},
	{
		"id": "daily_ascension",
		"title": "Daily Ascension",
		"description": "Clear 1 stage.",
		"category": "JOURNEY",
		"progress": 1,
		"target": 1,
		"reward": 50,
		"state": "claimed",
	},
]

var achievement_records: Array[Dictionary] = [
	{
		"id": "first_blood",
		"title": "First Blood",
		"description": "Defeat your first enemy.",
		"category": "COMBAT",
		"progress": 1,
		"target": 1,
		"reward": 20,
		"state": "reward_ready",
	},
	{
		"id": "path_opened",
		"title": "Path Opened",
		"description": "Clear your first stage.",
		"category": "JOURNEY",
		"progress": 1,
		"target": 1,
		"reward": 100,
		"state": "reward_ready",
	},
	{
		"id": "boss_breaker",
		"title": "Boss Breaker",
		"description": "Defeat your first Stage Boss.",
		"category": "BOSS",
		"progress": 1,
		"target": 1,
		"reward": 100,
		"state": "claimed",
	},
]


func _ready() -> void:
	_build_lab()
	_refresh_section()
	call_deferred("_play_intro")
	queue_redraw()



func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 2.0 or h <= 2.0:
		return

	# Ceremonial outer rails: restrained, not another glowing panel.
	draw_line(
		Vector2(12.0, 8.0),
		Vector2(w - 12.0, 8.0),
		Color(0.96, 0.76, 0.30, 0.44),
		1.0,
		true
	)
	draw_line(
		Vector2(9.0, 20.0),
		Vector2(9.0, h - 20.0),
		Color(0.26, 0.84, 0.72, 0.20),
		1.0,
		true
	)
	draw_line(
		Vector2(w - 9.0, 20.0),
		Vector2(w - 9.0, h - 20.0),
		Color(0.96, 0.76, 0.30, 0.20),
		1.0,
		true
	)

	for p: Vector2 in [
		Vector2(12.0, 8.0),
		Vector2(w - 12.0, 8.0),
		Vector2(9.0, h - 20.0),
		Vector2(w - 9.0, h - 20.0),
	]:
		draw_circle(p, 2.6, Color(1.0, 0.80, 0.36, 0.78))

func _build_lab() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.texture = load(TRIALS_BG_PATH) as Texture2D
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.006, 0.012, 0.44)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	hall_overlay = Control.new()
	hall_overlay.name = "ProductionTrialsHallOverlay"
	hall_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hall_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hall_overlay.set_script(TrialsHallOverlayScript)
	hall_overlay.set("mode", "daily")
	add_child(hall_overlay)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 18)
	safe.add_theme_constant_override("margin_top", 12)
	safe.add_theme_constant_override("margin_right", 18)
	safe.add_theme_constant_override("margin_bottom", 18)
	add_child(safe)

	content_host = VBoxContainer.new()
	content_host.add_theme_constant_override("separation", 9)
	safe.add_child(content_host)

	content_host.add_child(_build_resource_bar())
	content_host.add_child(_build_lab_status())
	content_host.add_child(_build_hero_panel())
	content_host.add_child(_build_tabs())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0.0, 410.0)
	content_host.add_child(scroll)

	list_host = VBoxContainer.new()
	list_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_host.add_theme_constant_override("separation", 10)
	scroll.add_child(list_host)

	content_host.add_child(_build_production_hub_nav())
	call_deferred("_lock_lab_navigation")
	_build_reward_overlay()


func _build_resource_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 70.0)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.002, 0.018, 0.027, 0.97),
			Color(0.92, 0.72, 0.27, 0.70),
			16,
			1
		)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	margin.add_child(row)

	row.add_child(_resource_chip(SPIRIT_STONE_ICON_PATH, str(mock_balance), GOLD))
	row.add_child(_resource_chip(REFINEMENT_SHARD_ICON_PATH, "18", JADE))
	row.add_child(_resource_chip(CELESTIAL_JADE_ICON_PATH, "90", Color(0.72, 0.55, 1.0)))
	row.add_child(_resource_chip(PAVILION_SEAL_ICON_PATH, "4", CYAN))
	return panel


func _resource_chip(path: String, amount: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.004, 0.030, 0.038, 0.96),
			Color(accent.r, accent.g, accent.b, 0.62),
			12,
			1
		)
	)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30.0, 30.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(path) as Texture2D
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var value := Label.new()
	value.text = amount
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color(0.96, 0.93, 0.82, 1.0))
	row.add_child(value)
	return chip


func _build_lab_status() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 34.0)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.02, 0.10, 0.105, 0.92),
			Color(0.32, 0.90, 0.75, 0.52),
			9,
			1
		)
	)
	var label := Label.new()
	label.text = "TRIALS PRESENTATION LAB  •  NO SAVE WRITES"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.66, 1.0, 0.88, 1.0))
	panel.add_child(label)
	return panel



func _build_hero_panel() -> PanelContainer:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(0.0, 184.0)
	outer.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(0.001, 0.018, 0.029, 0.99),
			Color(1.0, 0.78, 0.30, 0.92),
			Color(0.20, 0.86, 0.72, 0.36),
			18
		)
	)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 4)
	outer_margin.add_theme_constant_override("margin_top", 4)
	outer_margin.add_theme_constant_override("margin_right", 4)
	outer_margin.add_theme_constant_override("margin_bottom", 4)
	outer.add_child(outer_margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_ornate_inner_style(
			Color(0.002, 0.030, 0.043, 0.97),
			Color(0.29, 0.88, 0.75, 0.46),
			14
		)
	)
	outer_margin.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_box)

	var eyebrow := Label.new()
	eyebrow.text = "CELESTIAL TRIALS HALL"
	eyebrow.theme_type_variation = &"JadeSubtitle"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", CYAN)
	title_box.add_child(eyebrow)

	var title := Label.new()
	title.text = "DAILY DISCIPLINES"
	title.name = "SectionTitle"
	title.theme_type_variation = &"JadeTitle"
	title.add_theme_font_size_override("font_size", 29)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Complete trials. Claim rewards. Temper your path."
	subtitle.theme_type_variation = &"JadeMutedLabel"
	subtitle.add_theme_font_size_override("font_size", 13)
	title_box.add_child(subtitle)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(88.0, 88.0)
	icon_frame.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(0.008, 0.050, 0.058, 0.92),
			Color(1.0, 0.77, 0.29, 0.78),
			Color(0.28, 0.90, 0.75, 0.34),
			18
		)
	)
	top.add_child(icon_frame)

	var icon := TextureRect.new()
	icon.name = "SectionIcon"
	icon.custom_minimum_size = Vector2(82.0, 82.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(DAILY_ICON_PATH) as Texture2D
	icon_frame.add_child(icon)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	box.add_child(stats)

	stats.add_child(_stat_chip("READY", "2", GOLD))
	stats.add_child(_stat_chip("REWARD", "50", JADE))

	claim_all_button = Button.new()
	claim_all_button.custom_minimum_size = Vector2(176.0, 48.0)
	claim_all_button.theme_type_variation = &"JadePrimaryButton"
	claim_all_button.add_theme_font_size_override("font_size", 14)
	claim_all_button.text = "CLAIM ALL  ◆  50"
	claim_all_button.pressed.connect(_on_claim_all_pressed)
	stats.add_child(claim_all_button)

	ready_value_label = _find_named(stats.get_child(0), "Value") as Label
	reward_value_label = _find_named(stats.get_child(1), "Value") as Label
	return outer



func _stat_chip(label_text: String, value_text: String, accent: Color) -> PanelContainer:
	var outer := PanelContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(0.003, 0.034, 0.043, 0.97),
			Color(accent.r, accent.g, accent.b, 0.66),
			Color(1.0, 0.78, 0.30, 0.24),
			11
		)
	)

	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 2)
	inset.add_theme_constant_override("margin_top", 2)
	inset.add_theme_constant_override("margin_right", 2)
	inset.add_theme_constant_override("margin_bottom", 2)
	outer.add_child(inset)

	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override(
		"panel",
		_ornate_inner_style(
			Color(0.005, 0.048, 0.058, 0.94),
			Color(accent.r, accent.g, accent.b, 0.28),
			8
		)
	)
	inset.add_child(inner)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(box)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", MUTED)
	box.add_child(label)

	var value := Label.new()
	value.name = "Value"
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", accent)
	box.add_child(value)
	return outer


func _build_tabs() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	daily_tab = Button.new()
	daily_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	daily_tab.custom_minimum_size = Vector2(0.0, 50.0)
	daily_tab.text = "DAILY"
	daily_tab.add_theme_font_size_override("font_size", 14)
	daily_tab.pressed.connect(_switch_section.bind("daily"))
	row.add_child(daily_tab)

	achievement_tab = Button.new()
	achievement_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_tab.custom_minimum_size = Vector2(0.0, 50.0)
	achievement_tab.text = "ACHIEVEMENTS"
	achievement_tab.add_theme_font_size_override("font_size", 14)
	achievement_tab.pressed.connect(_switch_section.bind("achievement"))
	row.add_child(achievement_tab)
	return row


func _refresh_section() -> void:
	if list_host == null:
		return

	for child: Node in list_host.get_children():
		child.queue_free()

	var records: Array[Dictionary] = (
		daily_records
		if active_section == "daily"
		else achievement_records
	)
	var claimed_map: Dictionary = (
		daily_claimed
		if active_section == "daily"
		else achievement_claimed
	)

	var ready_count := 0
	var reward_total := 0
	for record: Dictionary in records:
		var record_id := str(record.get("id", ""))
		if bool(claimed_map.get(record_id, false)):
			continue
		if str(record.get("state", "")) == "reward_ready":
			ready_count += 1
			reward_total += int(record.get("reward", 0))

	daily_tab.theme_type_variation = (
		&"JadePrimaryButton"
		if active_section == "daily"
		else &"JadeSecondaryButton"
	)
	achievement_tab.theme_type_variation = (
		&"JadePrimaryButton"
		if active_section == "achievement"
		else &"JadeSecondaryButton"
	)

	# The Lab discovers its hero title/icon by local names only; it does not depend on production node paths.
	var section_title := _find_named(self, "SectionTitle") as Label
	var section_icon := _find_named(self, "SectionIcon") as TextureRect
	if section_title != null:
		section_title.text = (
			"DAILY DISCIPLINES"
			if active_section == "daily"
			else "ETERNAL RECORDS"
		)
	if section_icon != null:
		section_icon.texture = load(
			DAILY_ICON_PATH
			if active_section == "daily"
			else ACHIEVEMENT_ICON_PATH
		) as Texture2D

	ready_value_label.text = str(ready_count)
	reward_value_label.text = str(reward_total)
	claim_all_button.disabled = ready_count <= 0
	claim_all_button.text = (
		"CLAIM ALL  ◆  %d" % reward_total
		if ready_count > 0
		else "ALL REWARDS SETTLED"
	)

	for record: Dictionary in records:
		list_host.add_child(_build_trial_card(record, claimed_map))



func _build_trial_card(
	record: Dictionary,
	claimed_map: Dictionary
) -> PanelContainer:
	var id := str(record.get("id", ""))
	var is_claimed := bool(claimed_map.get(id, false))
	var state := "claimed" if is_claimed else str(record.get("state", "in_progress"))
	var category := str(record.get("category", "TRIAL"))
	var accent := _category_color(category)
	var is_reward_ready := state == "reward_ready"

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(0.0, 164.0)
	outer.modulate = Color(1, 1, 1, 0.76 if is_claimed else 1.0)
	outer.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(0.002, 0.019, 0.029, 0.99),
			GOLD if is_reward_ready else Color(accent.r, accent.g, accent.b, 0.76),
			Color(0.26, 0.88, 0.73, 0.32),
			14
		)
	)

	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 3)
	inset.add_theme_constant_override("margin_top", 3)
	inset.add_theme_constant_override("margin_right", 3)
	inset.add_theme_constant_override("margin_bottom", 3)
	outer.add_child(inset)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override(
		"panel",
		_ornate_inner_style(
			Color(
				0.008 if is_reward_ready else 0.003,
				0.041 if is_reward_ready else 0.026,
				0.044 if is_reward_ready else 0.036,
				0.98
			),
			Color(
				1.0 if is_reward_ready else accent.r,
				0.78 if is_reward_ready else accent.g,
				0.30 if is_reward_ready else accent.b,
				0.36 if is_reward_ready else 0.28
			),
			11
		)
	)
	inset.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 9)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	margin.add_child(row)

	var icon_outer := PanelContainer.new()
	icon_outer.custom_minimum_size = Vector2(76.0, 76.0)
	icon_outer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon_outer.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(accent.r * 0.05, accent.g * 0.05, accent.b * 0.05, 0.98),
			GOLD if is_reward_ready else Color(accent.r, accent.g, accent.b, 0.76),
			Color(0.95, 0.76, 0.30, 0.20),
			14
		)
	)
	row.add_child(icon_outer)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(66.0, 66.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(
		DAILY_ICON_PATH if active_section == "daily" else ACHIEVEMENT_ICON_PATH
	) as Texture2D
	icon_outer.add_child(icon)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	row.add_child(body)

	var rune_rail := HBoxContainer.new()
	rune_rail.add_theme_constant_override("separation", 5)
	body.add_child(rune_rail)
	var rune := Label.new()
	rune.text = "◆"
	rune.add_theme_font_size_override("font_size", 8)
	rune.add_theme_color_override(
		"font_color",
		GOLD if is_reward_ready else Color(accent.r, accent.g, accent.b, 0.82)
	)
	rune_rail.add_child(rune)
	rune_rail.add_child(
		_ornament_line(
			Color(
				1.0 if is_reward_ready else accent.r,
				0.78 if is_reward_ready else accent.g,
				0.30 if is_reward_ready else accent.b,
				0.38
			)
		)
	)

	var title_row := HBoxContainer.new()
	body.add_child(title_row)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = str(record.get("title", "Trial"))
	title.theme_type_variation = &"JadeHeroName"
	title.add_theme_font_size_override("font_size", 19)
	title_row.add_child(title)

	var state_label := Label.new()
	state_label.text = (
		"REWARD READY"
		if is_reward_ready
		else ("CLAIMED" if is_claimed else "IN PROGRESS")
	)
	state_label.add_theme_font_size_override("font_size", 12)
	state_label.add_theme_color_override(
		"font_color",
		GOLD if is_reward_ready else (JADE if is_claimed else accent)
	)
	if is_reward_ready:
		state_label.add_theme_color_override(
			"font_shadow_color",
			Color(1.0, 0.66, 0.16, 0.42)
		)
		state_label.add_theme_constant_override("shadow_offset_y", 1)
	title_row.add_child(state_label)

	var meta := Label.new()
	meta.text = "%s  •  %s" % [
		category,
		"DAILY DISCIPLINE" if active_section == "daily" else "PERMANENT RECORD"
	]
	meta.theme_type_variation = &"JadeSubtitle"
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", accent)
	body.add_child(meta)

	var description := Label.new()
	description.text = str(record.get("description", ""))
	description.theme_type_variation = &"JadeMutedLabel"
	description.add_theme_font_size_override("font_size", 14)
	body.add_child(description)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	body.add_child(progress_row)

	var progress := ProgressBar.new()
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.custom_minimum_size = Vector2(0.0, 11.0)
	progress.max_value = float(maxi(int(record.get("target", 1)), 1))
	progress.value = float(int(record.get("progress", 0)))
	progress.show_percentage = false
	progress.add_theme_stylebox_override(
		"background",
		_panel_style(
			Color(0.002, 0.012, 0.020, 0.98),
			Color(0.28, 0.82, 0.70, 0.38),
			5,
			1
		)
	)
	progress.add_theme_stylebox_override(
		"fill",
		_make_trial_progress_fill(
			GOLD if is_reward_ready else accent,
			is_reward_ready
		)
	)
	progress_row.add_child(progress)

	var progress_text := Label.new()
	progress_text.custom_minimum_size = Vector2(64.0, 0.0)
	progress_text.text = "%d / %d" % [
		int(record.get("progress", 0)),
		int(record.get("target", 1))
	]
	progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_text.add_theme_font_size_override("font_size", 12)
	progress_row.add_child(progress_text)

	var action_row := HBoxContainer.new()
	body.add_child(action_row)

	var reward := Label.new()
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward.text = "REWARD  ◆  %d SPIRIT STONE" % int(record.get("reward", 0))
	reward.theme_type_variation = &"JadeCurrencyLabel"
	reward.add_theme_font_size_override("font_size", 12)
	action_row.add_child(reward)

	var action := Button.new()
	action.custom_minimum_size = Vector2(132.0, 40.0)
	action.add_theme_font_size_override("font_size", 12)
	if is_reward_ready:
		action.text = "CLAIM  ◆  +%d" % int(record.get("reward", 0))
		action.theme_type_variation = &"JadePrimaryButton"
		_apply_reward_ready_button_style(action)
		action.pressed.connect(_on_single_claim.bind(id))
	elif is_claimed:
		action.text = "CLAIMED"
		action.disabled = true
		action.theme_type_variation = &"JadeSecondaryButton"
	else:
		action.text = "IN PROGRESS"
		action.disabled = true
		action.theme_type_variation = &"JadeSecondaryButton"
	action_row.add_child(action)

	return outer


func _build_production_hub_nav() -> Control:
	hub_nav = Control.new()
	hub_nav.name = "HubNav"
	hub_nav.custom_minimum_size = Vector2(0.0, 88.0)
	hub_nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub_nav.set_script(HubNavScript)
	hub_nav.set("active_tab", 3)
	return hub_nav


func _lock_lab_navigation() -> void:
	# Keep the exact production nav visuals, but prevent this visual sandbox
	# from leaving the LAB when a tab is tapped.
	if hub_nav == null:
		return
	for child: Node in hub_nav.get_children():
		if child is Button:
			(child as Button).disabled = true
			(child as Button).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_reward_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.006, 0.012, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	overlay_panel = PanelContainer.new()
	overlay_panel.custom_minimum_size = Vector2(520.0, 566.0)
	overlay_panel.pivot_offset = Vector2(260.0, 274.0)
	overlay_panel.add_theme_stylebox_override(
		"panel",
		_ornate_outer_style(
			Color(0.001, 0.020, 0.031, 0.995),
			Color(1.0, 0.79, 0.30, 0.98),
			Color(0.27, 0.90, 0.75, 0.52),
			24
		)
	)
	center.add_child(overlay_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	overlay_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)

	var eyebrow := Label.new()
	eyebrow.text = "CELESTIAL TRIALS"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.theme_type_variation = &"JadeSubtitle"
	eyebrow.add_theme_font_size_override("font_size", 13)
	box.add_child(eyebrow)

	overlay_title = Label.new()
	overlay_title.text = "REWARD SECURED"
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.theme_type_variation = &"JadeTitle"
	overlay_title.add_theme_font_size_override("font_size", 34)
	box.add_child(overlay_title)

	var divider := HSeparator.new()
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	box.add_child(divider)

	var halo := PanelContainer.new()
	halo.custom_minimum_size = Vector2(164.0, 164.0)
	halo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	halo.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.02, 0.12, 0.11, 0.78),
			Color(1.0, 0.79, 0.30, 0.88),
			82,
			2
		)
	)
	box.add_child(halo)

	overlay_icon = TextureRect.new()
	overlay_icon.custom_minimum_size = Vector2(136.0, 136.0)
	overlay_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay_icon.texture = load(SPIRIT_STONE_ICON_PATH) as Texture2D
	overlay_icon.pivot_offset = Vector2(68.0, 68.0)
	halo.add_child(overlay_icon)

	overlay_amount = Label.new()
	overlay_amount.text = "+25"
	overlay_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_amount.theme_type_variation = &"JadeTitle"
	overlay_amount.add_theme_font_size_override("font_size", 46)
	box.add_child(overlay_amount)

	var currency := Label.new()
	currency.text = "SPIRIT STONES"
	currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	currency.theme_type_variation = &"JadeCurrencyLabel"
	currency.add_theme_font_size_override("font_size", 15)
	box.add_child(currency)

	overlay_source = Label.new()
	overlay_source.text = "Daily Extermination"
	overlay_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_source.theme_type_variation = &"JadeHeroName"
	overlay_source.add_theme_font_size_override("font_size", 18)
	box.add_child(overlay_source)

	overlay_chips = HBoxContainer.new()
	overlay_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_chips.add_theme_constant_override("separation", 8)
	box.add_child(overlay_chips)

	overlay_balance = Label.new()
	overlay_balance.text = "BALANCE  1,420  →  1,445"
	overlay_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_balance.theme_type_variation = &"JadeMutedLabel"
	overlay_balance.add_theme_font_size_override("font_size", 13)
	box.add_child(overlay_balance)

	overlay_close = Button.new()
	overlay_close.custom_minimum_size = Vector2(300.0, 54.0)
	overlay_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_close.theme_type_variation = &"JadePrimaryButton"
	overlay_close.text = "CONTINUE"
	overlay_close.add_theme_font_size_override("font_size", 16)
	overlay_close.pressed.connect(_hide_reward_overlay)
	box.add_child(overlay_close)


func _on_single_claim(record_id: String) -> void:
	var record := _get_record(record_id)
	if record.is_empty():
		return

	var claimed_map: Dictionary = (
		daily_claimed
		if active_section == "daily"
		else achievement_claimed
	)
	if bool(claimed_map.get(record_id, false)):
		return

	claimed_map[record_id] = true
	var amount := int(record.get("reward", 0))
	_show_reward_overlay(
		str(record.get("title", "Trial Reward")),
		amount,
		1
	)


func _on_claim_all_pressed() -> void:
	var records: Array[Dictionary] = (
		daily_records
		if active_section == "daily"
		else achievement_records
	)
	var claimed_map: Dictionary = (
		daily_claimed
		if active_section == "daily"
		else achievement_claimed
	)

	var total := 0
	var count := 0
	for record: Dictionary in records:
		var record_id := str(record.get("id", ""))
		if bool(claimed_map.get(record_id, false)):
			continue
		if str(record.get("state", "")) != "reward_ready":
			continue
		claimed_map[record_id] = true
		total += int(record.get("reward", 0))
		count += 1

	if count <= 0:
		return
	_show_reward_overlay(
		"Daily Rewards" if active_section == "daily" else "Eternal Records",
		total,
		count
	)


func _show_reward_overlay(
	source_title: String,
	amount: int,
	reward_count: int
) -> void:
	var previous_balance := mock_balance
	mock_balance += amount

	overlay.visible = true
	overlay.modulate = Color(1, 1, 1, 0)
	overlay_panel.scale = Vector2(0.84, 0.84)
	overlay_icon.scale = Vector2(0.60, 0.60)
	overlay_icon.modulate = Color(1, 1, 1, 0.20)

	overlay_title.text = (
		"REWARDS SECURED"
		if reward_count > 1
		else "REWARD SECURED"
	)
	overlay_source.text = source_title
	overlay_amount.text = "+%d" % amount
	overlay_balance.text = "BALANCE  %s  →  %s" % [
		_format_number(previous_balance),
		_format_number(mock_balance)
	]

	for child: Node in overlay_chips.get_children():
		child.queue_free()
	if reward_count > 1:
		for index: int in range(reward_count):
			var chip := Label.new()
			chip.text = "REWARD %02d" % (index + 1)
			chip.add_theme_font_size_override("font_size", 10)
			chip.add_theme_color_override("font_color", GOLD)
			overlay_chips.add_child(chip)

	_play_claim_audio()

	if overlay_tween != null and overlay_tween.is_valid():
		overlay_tween.kill()
	overlay_tween = create_tween()
	overlay_tween.set_parallel(true)
	overlay_tween.tween_property(
		overlay,
		"modulate:a",
		1.0,
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	overlay_tween.tween_property(
		overlay_panel,
		"scale",
		Vector2.ONE,
		0.34
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	overlay_tween.tween_property(
		overlay_icon,
		"modulate:a",
		1.0,
		0.20
	)
	var icon_tween := create_tween()
	icon_tween.tween_property(
		overlay_icon,
		"scale",
		Vector2(1.12, 1.12),
		0.24
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	icon_tween.tween_property(
		overlay_icon,
		"scale",
		Vector2.ONE,
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _hide_reward_overlay() -> void:
	if not overlay.visible:
		return
	if overlay_tween != null and overlay_tween.is_valid():
		overlay_tween.kill()
	overlay_tween = create_tween()
	overlay_tween.set_parallel(true)
	overlay_tween.tween_property(overlay, "modulate:a", 0.0, 0.14)
	overlay_tween.tween_property(
		overlay_panel,
		"scale",
		Vector2(0.94, 0.94),
		0.14
	)
	await overlay_tween.finished
	overlay.visible = false
	_refresh_section()
	_refresh_resource_bar_balance()


func _refresh_resource_bar_balance() -> void:
	# The first chip's value is deliberately discovered from its subtree so the
	# Lab does not depend on production resource-bar node paths.
	var resource_panel := content_host.get_child(0)
	if resource_panel == null:
		return
	var labels := _find_labels(resource_panel)
	for label: Label in labels:
		if label.text == str(mock_balance):
			return
	# The Spirit Stone value is the first numeric Label in the resource bar.
	for label: Label in labels:
		if label.text.is_valid_int():
			label.text = str(mock_balance)
			return


func _switch_section(section: String) -> void:
	if section == active_section:
		return
	active_section = section
	if hall_overlay != null:
		hall_overlay.set(
			"mode",
			"daily" if active_section == "daily" else "records"
		)
		hall_overlay.queue_redraw()
	_refresh_section()
	_play_ui_audio("ui_tab")


func _get_record(record_id: String) -> Dictionary:
	var records: Array[Dictionary] = (
		daily_records
		if active_section == "daily"
		else achievement_records
	)
	for record: Dictionary in records:
		if str(record.get("id", "")) == record_id:
			return record
	return {}


func _play_intro() -> void:
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()
	content_host.modulate = Color(1, 1, 1, 0)
	content_host.position.y += 18.0
	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(
		content_host,
		"modulate:a",
		1.0,
		0.24
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(
		content_host,
		"position:y",
		content_host.position.y - 18.0,
		0.30
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_claim_audio() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", "claim")


func _play_ui_audio(cue: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", cue)


func _category_color(category: String) -> Color:
	match category.to_upper():
		"COMBAT":
			return Color(0.98, 0.43, 0.33, 1.0)
		"PROGRESSION":
			return Color(0.36, 0.82, 1.0, 1.0)
		"JOURNEY":
			return Color(0.30, 0.91, 0.69, 1.0)
		"BOSS":
			return Color(1.0, 0.68, 0.22, 1.0)
		"CULTIVATION":
			return Color(0.78, 0.60, 1.0, 1.0)
		_:
			return JADE




func _make_trial_progress_fill(
	accent: Color,
	is_reward_ready: bool
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = (
		Color(1.0, 0.72, 0.20, 0.34)
		if is_reward_ready
		else Color(accent.r, accent.g, accent.b, 0.18)
	)
	style.shadow_size = 3
	return style


func _apply_reward_ready_button_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.012, 0.105, 0.090, 0.98)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.98, 0.78, 0.30, 0.98)
	normal.corner_radius_top_left = 9
	normal.corner_radius_top_right = 9
	normal.corner_radius_bottom_left = 9
	normal.corner_radius_bottom_right = 9
	normal.shadow_color = Color(0.92, 0.66, 0.18, 0.26)
	normal.shadow_size = 5
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.018, 0.145, 0.122, 0.99)
	hover.border_color = Color(1.0, 0.88, 0.52, 1.0)
	hover.shadow_color = Color(0.34, 0.92, 0.75, 0.26)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.004, 0.066, 0.066, 1.0)
	pressed.border_color = Color(0.32, 0.91, 0.76, 0.96)
	pressed.shadow_size = 2
	button.add_theme_stylebox_override("pressed", pressed)

func _ornament_line(color: Color) -> Control:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _ornate_outer_style(
	background: Color,
	primary_border: Color,
	secondary_glow: Color,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = primary_border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = secondary_glow
	style.shadow_size = 8
	return style


func _ornate_inner_style(
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


func _panel_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 5
	return style


func _find_named(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var found := _find_named(child, target_name)
		if found != null:
			return found
	return null


func _find_labels(node: Node) -> Array[Label]:
	var result: Array[Label] = []
	if node is Label:
		result.append(node as Label)
	for child: Node in node.get_children():
		result.append_array(_find_labels(child))
	return result


func _format_number(value: int) -> String:
	var text := str(maxi(value, 0))
	var result := ""
	var digits := 0
	for index: int in range(text.length() - 1, -1, -1):
		if digits > 0 and digits % 3 == 0:
			result = "," + result
		result = text[index] + result
		digits += 1
	return result
