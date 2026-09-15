extends RefCounted

## Shared Jade Ascendant UI design tokens.
## Presentation constants only. No navigation, save, gameplay, or economy authority.
##
## Purpose:
## - keep shared chrome on one visual generation
## - prevent each screen from inventing its own jade/gold/text values
## - provide a stable baseline for later equipment/art passes

const OBSIDIAN: Color = Color(0.002, 0.014, 0.022, 1.0)
const OBSIDIAN_SOFT: Color = Color(0.005, 0.029, 0.039, 1.0)
const OBSIDIAN_GLASS: Color = Color(0.004, 0.027, 0.036, 0.94)

const JADE: Color = Color(0.30, 0.90, 0.75, 1.0)
const JADE_BRIGHT: Color = Color(0.52, 1.0, 0.86, 1.0)
const JADE_SOFT: Color = Color(0.20, 0.64, 0.56, 1.0)

const GOLD: Color = Color(0.96, 0.78, 0.34, 1.0)
const GOLD_BRIGHT: Color = Color(1.0, 0.91, 0.58, 1.0)
const GOLD_DEEP: Color = Color(0.68, 0.45, 0.12, 1.0)

const CYAN: Color = Color(0.39, 0.82, 0.91, 1.0)
const CINNABAR: Color = Color(0.73, 0.095, 0.070, 1.0)

const TEXT_PRIMARY: Color = Color(0.93, 0.96, 0.94, 1.0)
const TEXT_WARM: Color = Color(1.0, 0.94, 0.75, 1.0)
const TEXT_MUTED: Color = Color(0.68, 0.76, 0.75, 1.0)
const TEXT_DISABLED: Color = Color(0.46, 0.52, 0.52, 0.78)

const NAV_HEIGHT: float = 82.0
const NAV_ICON_CENTER_Y: float = 25.0
const NAV_LABEL_TOP: float = 47.0
const NAV_LABEL_BOTTOM_MARGIN: float = 6.0
const NAV_LABEL_FONT_SIZE: int = 12

const NAV_SHELL_RADIUS: int = 15
const NAV_CELL_RADIUS: int = 12
const NAV_ICON_RADIUS: float = 17.5

const BADGE_REFRESH_INTERVAL: float = 0.25
const MOTION_REDRAW_INTERVAL: float = 0.05


static func with_alpha(source_color: Color, alpha_value: float) -> Color:
	return Color(
		source_color.r,
		source_color.g,
		source_color.b,
		alpha_value
	)


static func mix(
	first_color: Color,
	second_color: Color,
	weight: float
) -> Color:
	return first_color.lerp(
		second_color,
		clampf(weight, 0.0, 1.0)
	)

# Shared chrome / hierarchy baseline.
const PANEL_RADIUS: int = 11
const PANEL_RADIUS_COMPACT: int = 8
const BUTTON_RADIUS: int = 10
const BADGE_RADIUS: int = 8

const BORDER_SOFT_ALPHA: float = 0.34
const BORDER_NORMAL_ALPHA: float = 0.60
const BORDER_STRONG_ALPHA: float = 0.82

const SHADOW_SOFT: Color = Color(0.0, 0.0, 0.0, 0.30)
const SHADOW_NORMAL: Color = Color(0.0, 0.0, 0.0, 0.44)

const MUTED_TEXT_GLOBAL: Color = Color(0.72, 0.80, 0.79, 1.0)
const SUBTITLE_GLOBAL: Color = Color(0.39, 0.82, 0.91, 1.0)
const TITLE_GLOBAL: Color = Color(0.97, 0.82, 0.45, 1.0)
const HERO_NAME_GLOBAL: Color = Color(1.0, 0.95, 0.78, 1.0)
const CURRENCY_GLOBAL: Color = Color(0.98, 0.82, 0.43, 1.0)

