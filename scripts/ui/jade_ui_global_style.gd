extends RefCounted

## Jade Ascendant global UI consistency layer.
##
## Runtime-only presentation normalization.
## This never owns navigation, progression, rewards, save data, inventory,
## equipment, stage state, or localization.
##
## The goal is to make shared chrome read as one product while preserving
## each screen's art direction and explicit local theme overrides.

const UiTokens = preload("res://scripts/ui/jade_ui_tokens.gd")

static var _applied_theme_ids: Dictionary = {}


static func apply_from(control: Control) -> void:
	if control == null:
		return

	var cursor: Control = control

	while cursor != null:
		var candidate_theme: Theme = cursor.theme

		if candidate_theme != null:
			_apply_theme_once(candidate_theme)
			return

		cursor = cursor.get_parent_control()


static func _apply_theme_once(theme: Theme) -> void:
	if theme == null:
		return

	var theme_id: int = int(theme.get_instance_id())

	if _applied_theme_ids.has(theme_id):
		return

	_applied_theme_ids[theme_id] = true

	_apply_shared_text(theme)
	_apply_shared_buttons(theme)
	_apply_shared_resource_chrome(theme)
	_apply_shared_journey_chrome(theme)
	_apply_shared_progress(theme)


static func _apply_shared_text(theme: Theme) -> void:
	theme.set_color(
		"font_color",
		"JadeMutedLabel",
		UiTokens.MUTED_TEXT_GLOBAL
	)
	theme.set_color(
		"font_shadow_color",
		"JadeMutedLabel",
		Color(0.0, 0.0, 0.0, 0.74)
	)
	theme.set_constant(
		"shadow_offset_y",
		"JadeMutedLabel",
		1
	)

	theme.set_color(
		"font_color",
		"JadeSubtitle",
		UiTokens.SUBTITLE_GLOBAL
	)
	theme.set_color(
		"font_shadow_color",
		"JadeSubtitle",
		Color(0.0, 0.0, 0.0, 0.68)
	)
	theme.set_constant(
		"shadow_offset_y",
		"JadeSubtitle",
		1
	)

	theme.set_color(
		"font_color",
		"JadeTitle",
		UiTokens.TITLE_GLOBAL
	)
	theme.set_color(
		"font_shadow_color",
		"JadeTitle",
		Color(0.0, 0.0, 0.0, 0.72)
	)
	theme.set_constant(
		"shadow_offset_x",
		"JadeTitle",
		1
	)
	theme.set_constant(
		"shadow_offset_y",
		"JadeTitle",
		2
	)

	theme.set_color(
		"font_color",
		"JadeHeroName",
		UiTokens.HERO_NAME_GLOBAL
	)
	theme.set_color(
		"font_shadow_color",
		"JadeHeroName",
		Color(0.0, 0.0, 0.0, 0.72)
	)
	theme.set_constant(
		"shadow_offset_x",
		"JadeHeroName",
		1
	)
	theme.set_constant(
		"shadow_offset_y",
		"JadeHeroName",
		2
	)

	theme.set_color(
		"font_color",
		"JadeCurrencyLabel",
		UiTokens.CURRENCY_GLOBAL
	)
	theme.set_color(
		"font_shadow_color",
		"JadeCurrencyLabel",
		Color(0.0, 0.0, 0.0, 0.70)
	)
	theme.set_constant(
		"shadow_offset_y",
		"JadeCurrencyLabel",
		1
	)

	theme.set_color(
		"font_color",
		"JadeQiLabel",
		UiTokens.CYAN
	)
	theme.set_color(
		"font_shadow_color",
		"JadeQiLabel",
		Color(0.0, 0.0, 0.0, 0.66)
	)
	theme.set_constant(
		"shadow_offset_y",
		"JadeQiLabel",
		1
	)


static func _apply_shared_buttons(theme: Theme) -> void:
	var primary_normal := _make_panel_style(
		Color(0.006, 0.115, 0.108, 0.97),
		UiTokens.with_alpha(
			UiTokens.GOLD,
			0.92
		),
		UiTokens.BUTTON_RADIUS,
		2,
		UiTokens.with_alpha(
			UiTokens.JADE,
			0.18
		),
		7
	)
	_set_content_margins(
		primary_normal,
		20.0,
		13.0
	)

	var primary_hover := _make_panel_style(
		Color(0.012, 0.180, 0.157, 0.99),
		UiTokens.GOLD_BRIGHT,
		UiTokens.BUTTON_RADIUS,
		2,
		UiTokens.with_alpha(
			UiTokens.JADE_BRIGHT,
			0.24
		),
		9
	)
	_set_content_margins(
		primary_hover,
		20.0,
		13.0
	)

	var primary_pressed := _make_panel_style(
		Color(0.004, 0.075, 0.082, 1.0),
		UiTokens.with_alpha(
			UiTokens.JADE_BRIGHT,
			0.94
		),
		UiTokens.BUTTON_RADIUS,
		2,
		Color(0.0, 0.0, 0.0, 0.0),
		0
	)
	_set_content_margins(
		primary_pressed,
		20.0,
		13.0
	)

	var secondary_normal := _make_panel_style(
		Color(0.003, 0.032, 0.043, 0.94),
		UiTokens.with_alpha(
			UiTokens.JADE_SOFT,
			0.64
		),
		UiTokens.BUTTON_RADIUS,
		1,
		UiTokens.SHADOW_SOFT,
		4
	)
	_set_content_margins(
		secondary_normal,
		18.0,
		11.0
	)

	var secondary_hover := _make_panel_style(
		Color(0.006, 0.070, 0.076, 0.98),
		UiTokens.with_alpha(
			UiTokens.GOLD,
			0.72
		),
		UiTokens.BUTTON_RADIUS,
		1,
		UiTokens.with_alpha(
			UiTokens.JADE,
			0.12
		),
		5
	)
	_set_content_margins(
		secondary_hover,
		18.0,
		11.0
	)

	var secondary_pressed := _make_panel_style(
		Color(0.003, 0.045, 0.056, 1.0),
		UiTokens.with_alpha(
			UiTokens.JADE_BRIGHT,
			0.74
		),
		UiTokens.BUTTON_RADIUS,
		2,
		Color(0.0, 0.0, 0.0, 0.0),
		0
	)
	_set_content_margins(
		secondary_pressed,
		18.0,
		11.0
	)

	var disabled_style := _make_panel_style(
		Color(0.012, 0.020, 0.027, 0.78),
		Color(0.28, 0.35, 0.36, 0.46),
		UiTokens.BUTTON_RADIUS,
		1,
		Color(0.0, 0.0, 0.0, 0.0),
		0
	)
	_set_content_margins(
		disabled_style,
		18.0,
		11.0
	)

	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_width_left = 2
	focus_style.border_width_top = 2
	focus_style.border_width_right = 2
	focus_style.border_width_bottom = 2
	focus_style.border_color = UiTokens.with_alpha(
		UiTokens.CYAN,
		0.88
	)
	focus_style.corner_radius_top_left = UiTokens.BUTTON_RADIUS
	focus_style.corner_radius_top_right = UiTokens.BUTTON_RADIUS
	focus_style.corner_radius_bottom_left = UiTokens.BUTTON_RADIUS
	focus_style.corner_radius_bottom_right = UiTokens.BUTTON_RADIUS
	focus_style.expand_margin_left = 2.0
	focus_style.expand_margin_top = 2.0
	focus_style.expand_margin_right = 2.0
	focus_style.expand_margin_bottom = 2.0

	theme.set_stylebox(
		"normal",
		"JadePrimaryButton",
		primary_normal
	)
	theme.set_stylebox(
		"hover",
		"JadePrimaryButton",
		primary_hover
	)
	theme.set_stylebox(
		"pressed",
		"JadePrimaryButton",
		primary_pressed
	)
	theme.set_stylebox(
		"disabled",
		"JadePrimaryButton",
		disabled_style
	)
	theme.set_stylebox(
		"focus",
		"JadePrimaryButton",
		focus_style
	)

	theme.set_color(
		"font_color",
		"JadePrimaryButton",
		UiTokens.TEXT_WARM
	)
	theme.set_color(
		"font_hover_color",
		"JadePrimaryButton",
		Color(1.0, 0.97, 0.84, 1.0)
	)
	theme.set_color(
		"font_pressed_color",
		"JadePrimaryButton",
		UiTokens.JADE_BRIGHT
	)
	theme.set_color(
		"font_disabled_color",
		"JadePrimaryButton",
		UiTokens.TEXT_DISABLED
	)

	theme.set_stylebox(
		"normal",
		"JadeSecondaryButton",
		secondary_normal
	)
	theme.set_stylebox(
		"hover",
		"JadeSecondaryButton",
		secondary_hover
	)
	theme.set_stylebox(
		"pressed",
		"JadeSecondaryButton",
		secondary_pressed
	)
	theme.set_stylebox(
		"disabled",
		"JadeSecondaryButton",
		disabled_style
	)
	theme.set_stylebox(
		"focus",
		"JadeSecondaryButton",
		focus_style
	)

	theme.set_color(
		"font_color",
		"JadeSecondaryButton",
		UiTokens.TEXT_PRIMARY
	)
	theme.set_color(
		"font_hover_color",
		"JadeSecondaryButton",
		UiTokens.TEXT_WARM
	)
	theme.set_color(
		"font_pressed_color",
		"JadeSecondaryButton",
		UiTokens.JADE_BRIGHT
	)
	theme.set_color(
		"font_disabled_color",
		"JadeSecondaryButton",
		UiTokens.TEXT_DISABLED
	)


static func _apply_shared_resource_chrome(theme: Theme) -> void:
	var currency_style := _make_panel_style(
		Color(0.002, 0.022, 0.033, 0.94),
		UiTokens.with_alpha(
			UiTokens.GOLD,
			0.72
		),
		UiTokens.PANEL_RADIUS_COMPACT,
		1,
		UiTokens.with_alpha(
			UiTokens.JADE,
			0.12
		),
		5
	)
	_set_content_margins(
		currency_style,
		11.0,
		8.0
	)

	theme.set_stylebox(
		"panel",
		"JadeCurrencyPanel",
		currency_style
	)


static func _apply_shared_journey_chrome(theme: Theme) -> void:
	var badge_style := _make_panel_style(
		Color(0.002, 0.026, 0.036, 0.90),
		UiTokens.with_alpha(
			UiTokens.GOLD,
			0.52
		),
		UiTokens.BADGE_RADIUS,
		1,
		Color(0.0, 0.0, 0.0, 0.0),
		0
	)
	_set_content_margins(
		badge_style,
		8.0,
		4.0
	)

	var hint_style := _make_panel_style(
		Color(0.003, 0.024, 0.035, 0.90),
		UiTokens.with_alpha(
			UiTokens.CYAN,
			0.34
		),
		UiTokens.PANEL_RADIUS_COMPACT,
		1,
		Color(0.0, 0.0, 0.0, 0.0),
		0
	)
	_set_content_margins(
		hint_style,
		14.0,
		8.0
	)

	var selected_style := _make_panel_style(
		Color(0.002, 0.022, 0.033, 0.96),
		UiTokens.with_alpha(
			UiTokens.GOLD,
			0.56
		),
		UiTokens.PANEL_RADIUS,
		1,
		UiTokens.SHADOW_NORMAL,
		6
	)
	_set_content_margins(
		selected_style,
		16.0,
		12.0
	)

	theme.set_stylebox(
		"panel",
		"JadeJourneyBadge",
		badge_style
	)
	theme.set_stylebox(
		"panel",
		"JadeJourneyHintPanel",
		hint_style
	)
	theme.set_stylebox(
		"panel",
		"JadeSelectedTrialPanel",
		selected_style
	)


static func _apply_shared_progress(theme: Theme) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.001, 0.014, 0.021, 0.92)
	background.corner_radius_top_left = 5
	background.corner_radius_top_right = 5
	background.corner_radius_bottom_left = 5
	background.corner_radius_bottom_right = 5
	background.border_width_left = 1
	background.border_width_top = 1
	background.border_width_right = 1
	background.border_width_bottom = 1
	background.border_color = UiTokens.with_alpha(
		UiTokens.JADE_SOFT,
		0.20
	)

	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTokens.JADE
	fill.corner_radius_top_left = 5
	fill.corner_radius_top_right = 5
	fill.corner_radius_bottom_left = 5
	fill.corner_radius_bottom_right = 5

	theme.set_stylebox(
		"background",
		"ProgressBar",
		background
	)
	theme.set_stylebox(
		"fill",
		"ProgressBar",
		fill
	)


static func _make_panel_style(
	background: Color,
	border: Color,
	radius_value: int,
	border_width_value: int,
	shadow: Color,
	shadow_size_value: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = background

	style.border_width_left = border_width_value
	style.border_width_top = border_width_value
	style.border_width_right = border_width_value
	style.border_width_bottom = border_width_value
	style.border_color = border

	style.corner_radius_top_left = radius_value
	style.corner_radius_top_right = radius_value
	style.corner_radius_bottom_left = radius_value
	style.corner_radius_bottom_right = radius_value

	style.shadow_color = shadow
	style.shadow_size = shadow_size_value

	return style


static func _set_content_margins(
	style: StyleBoxFlat,
	horizontal_margin: float,
	vertical_margin: float
) -> void:
	style.content_margin_left = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_bottom = vertical_margin
