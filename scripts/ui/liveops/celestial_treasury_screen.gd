extends Control

const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")

## HEAVENLY TREASURY — APPROVED TOP-UP PRODUCTION.
## Approved V6.2 layout/artwork. This Control owns presentation, never grants.
## Google Play Billing owns localized product details and checkout. Purchased
## tokens pass transiently through the secure native bridge to server authority;
## the server verifies and consumes before PavilionManager can save a grant.
## Six consumable Celestial Jade packs only. No fabricated offer or price.

const EconomyCatalog = preload("res://scripts/data/economy_catalog.gd")
const HOME_ART: Texture2D = preload("res://assets/ui/main_menu/main_menu_key_art_lin_yue.png")
const FRAME_ART: Texture2D = preload("res://assets/ui/liveops/treasury_production/treasury_window_frame.png")
const HERO_ART: Texture2D = preload("res://assets/ui/liveops/treasury_production/treasury_approved_hero_crop.png")
const DAILY_ART: Texture2D = preload("res://assets/ui/liveops/treasury_production/treasury_daily_chest.png")
const JADE_ART: Texture2D = preload("res://assets/ui/liveops/treasury_production/treasury_jade_chest.png")
const CULTIVATION_ART: Texture2D = preload("res://assets/ui/liveops/treasury_production/treasury_cultivation_chest.png")
const ASCENSION_ART: Texture2D = preload("res://assets/ui/liveops/treasury_production/treasury_ascension_chest.png")
const JADE_ICON: Texture2D = preload("res://assets/ui/shared/resources/celestial_jade_premium.png")

const IVORY: Color = Color(1.0, 0.967, 0.88, 1.0)
const GOLD: Color = Color(0.96, 0.72, 0.28, 1.0)
const LIGHT_GOLD: Color = Color(1.0, 0.90, 0.55, 1.0)
const JADE: Color = Color(0.34, 0.94, 0.79, 1.0)
const QUIET: Color = Color(0.80, 0.89, 0.87, 1.0)
const NIGHT: Color = Color(0.003, 0.025, 0.036, 0.96)
const CARD_DARK: Color = Color(0.002, 0.042, 0.050, 0.97)
const SWIPE_DEADZONE: int = 7

# No first-top-up bonus, daily gift, starter bundle, or monthly blessing:
# this production storefront is a straight consumable Celestial Jade top-up.
# Ascending tier quantities mirror the EconomyCatalog; actual localized prices
# can only be confirmed by Google Play Billing in production.
const OFFER_IDS: Array[String] = [
	"jade_pouch_100",
	"jade_satchel_550",
	"jade_casket_1200",
	"jade_vault_2500",
	"jade_treasury_6500",
	"jade_ascendant_14000",
]
const OFFER_NAMES: Dictionary = {
	"jade_pouch_100": "JADE POUCH",
	"jade_satchel_550": "JADE SATCHEL",
	"jade_casket_1200": "JADE CASKET",
	"jade_vault_2500": "JADE VAULT",
	"jade_treasury_6500": "JADE TREASURY",
	"jade_ascendant_14000": "ASCENDANT RESERVE",
}
const OFFER_COPY: Dictionary = {
	"jade_pouch_100": "A small Celestial Jade supply.",
	"jade_satchel_550": "Jade for your next ascent.",
	"jade_casket_1200": "A reserve for cultivation.",
	"jade_vault_2500": "More Jade for your journey.",
	"jade_treasury_6500": "A substantial Jade reserve.",
	"jade_ascendant_14000": "A grand reserve for ascension.",
}

var _catalog: Dictionary = {}
var _popup: Control
var _inner_background: ColorRect
var _content_viewport: ScrollContainer
var _content_clip: Control
var _frame: TextureRect
var _title: Label
var _subtitle: Label
var _close_button: Button
var _hero: TextureRect
var _hero_rim: Panel
var _offers_caption: Label
var _swipe_caption: Label
var _offer_scroll: ScrollContainer
var _offer_row: HBoxContainer
var _cards: Array[Dictionary] = []
var _details_layer: Control
var _details_panel: Panel
var _details_title: Label
var _details_body: RichTextLabel
var _details_close: Button
var _details_badge: Label
var _details_art: TextureRect
var _details_art_frame: Panel
var _details_reward_panel: Panel
var _details_reward_icon: TextureRect
var _details_reward_amount: Label
var _details_reward_name: Label
var _details_price: Label
var _swiping: bool = false
var _swipe_settling: bool = false
var _scroll_generation: int = 0
var _active_scroll_count: int = 0
var _tap_guard_until_msec: int = 0
var _pressed_scroll_positions: Dictionary = {}

# Presentation-only state. Do not replace the authoritative Billing provider.
var _live_price_data: Dictionary = {}
var _billing_ready: bool = false
var _billing_state: String = "checking"
var _purchase_busy: bool = false
var _active_purchase_id: String = ""
var _selected_id: String = ""
var _billing_message: String = ""
var _message_product_id: String = ""
var _details_purchase: Button
var _details_restore: Button
var _cards_by_id: Dictionary = {}
var _prices_sorted: bool = false

func _ready() -> void:
	# Retain the previous shipping policy: Android builds can open Treasury;
	# non-Android release builds stay fail-closed, desktop debug is QA-only.
	if OS.get_name() != "Android" and not OS.is_debug_build():
		_back()
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	SceneTransitionManager.set_back_handler(_back)
	_catalog = PavilionManager.get_iap_product_catalog()
	_connect_runtime_signals()
	_build_ui()
	_layout_ui()
	resized.connect(_layout_ui)
	PavilionManager.refresh_iap_store_products()
	_refresh_storefront()
	# LiveOpsManager installs a generic close handler after add_child().
	# Defer to restore the details-aware handler once the popup is installed.
	call_deferred("_install_back_handler")

func _install_back_handler() -> void:
	if is_inside_tree():
		SceneTransitionManager.set_back_handler(_back)

func _build_ui() -> void:
	# Home already owns the shared wallet, navigation and approved key art.
	# Only standalone debug scenes need a fallback background.
	if not bool(get_meta("liveops_popup", false)):
		var background := TextureRect.new()
		background.name = "TreasuryStandaloneHomeArt"
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.texture = HOME_ART
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background)

	var scrim := ColorRect.new()
	scrim.name = "TreasuryHomeScrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.0, 0.008, 0.015, 0.74)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	_popup = Control.new()
	_popup.name = "TreasuryProductionPopup"
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.visible = false
	add_child(_popup)

	# Intentionally no extra gold-bordered rectangular backing panel: its old
	# outline was visible OUTSIDE the approved irregular ornamental frame.
	_inner_background = ColorRect.new()
	_inner_background.name = "InteriorOnlyNoOuterOutline"
	_inner_background.color = NIGHT
	_inner_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(_inner_background)

	# Normal-size screens keep their approved geometry. Short displays can
	# scroll vertically instead of compressing artwork onto reward/CTA rows.
	_content_viewport = ScrollContainer.new()
	_content_viewport.name = "TreasuryShortScreenVerticalScroll"
	_content_viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_viewport.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_content_viewport.scroll_deadzone = SWIPE_DEADZONE
	_content_viewport.follow_focus = false
	_content_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.add_child(_content_viewport)

	_content_clip = Control.new()
	_content_clip.name = "TreasuryContentSafeClip"
	_content_clip.clip_contents = true
	_content_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_viewport.add_child(_content_clip)
	_content_viewport.scroll_started.connect(_on_scroll_started)
	_content_viewport.scroll_ended.connect(_on_scroll_ended)

	_hero = TextureRect.new()
	_hero.name = "ApprovedHeroArtwork"
	_hero.texture = HERO_ART
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_clip.add_child(_hero)

	_hero_rim = Panel.new()
	_hero_rim.name = "HeroImageGoldRim"
	_hero_rim.add_theme_stylebox_override("panel", _panel_style(Color.TRANSPARENT, GOLD, 6, 1))
	_hero_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_clip.add_child(_hero_rim)

	_build_gallery()

	_frame = TextureRect.new()
	_frame.name = "ApprovedJadeOrnamentalFrame"
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.texture = FRAME_ART
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(_frame)

	_title = _label("HEAVENLY TREASURY", 35, LIGHT_GOLD)
	_title.name = "LiveTreasuryTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_color_override("font_shadow_color", Color(0.075, 0.018, 0.005, 0.90))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	_popup.add_child(_title)

	_subtitle = _label("Celestial Jade · Treasures for Your Ascension", 14, IVORY)
	_subtitle.name = "LiveTreasurySubtitle"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_popup.add_child(_subtitle)

	_close_button = _button("×", false)
	_close_button.name = "CloseTreasury"
	_close_button.pressed.connect(_back)
	_popup.add_child(_close_button)
	_build_details_overlay()

func _build_gallery() -> void:
	_offers_caption = _label("CELESTIAL JADE PACKS", 15, LIGHT_GOLD)
	_offers_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	_content_clip.add_child(_offers_caption)

	_swipe_caption = _label("6 PACKS  ·  SWIPE  ‹  ›", 12, JADE)
	_swipe_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_swipe_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	_content_clip.add_child(_swipe_caption)

	_offer_scroll = ScrollContainer.new()
	_offer_scroll.name = "OfferHorizontalSwipeArea"
	_offer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_offer_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_offer_scroll.scroll_deadzone = SWIPE_DEADZONE
	_offer_scroll.follow_focus = false
	# PASS lets the short-screen parent handle vertical gestures while this
	# container handles horizontal drags. Buttons remain RELEASE-only.
	_offer_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_clip.add_child(_offer_scroll)

	_offer_row = HBoxContainer.new()
	_offer_row.name = "ScrollableCatalogOfferRow"
	_offer_row.add_theme_constant_override("separation", 8)
	_offer_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_offer_scroll.add_child(_offer_row)

	for id: String in OFFER_IDS:
		var product: Dictionary = _catalog.get(id, {})
		if str(product.get("type", "")) != EconomyCatalog.PRODUCT_TYPE_CONSUMABLE:
			continue
		var card_data: Dictionary = _create_card(id)
		_cards.append(card_data)
		_cards_by_id[id] = card_data

	_offer_scroll.scroll_started.connect(_on_scroll_started)
	_offer_scroll.scroll_ended.connect(_on_scroll_ended)

func _create_card(id: String) -> Dictionary:
	var highlighted: bool = id == "jade_ascendant_14000"
	var accent: Color = GOLD if highlighted else JADE
	var card := Panel.new()
	card.name = "Offer_" + id
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", _panel_style(CARD_DARK, accent, 8, 1))
	_offer_row.add_child(card)

	var badge := _label("LARGEST PACK" if highlighted else "CELESTIAL JADE", 10, LIGHT_GOLD if highlighted else JADE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(badge)

	var title := _label(str(OFFER_NAMES.get(id, id)), 17, LIGHT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	card.add_child(title)

	var description := _label(str(OFFER_COPY.get(id, "")), 12, IVORY)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 3
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(description)

	var art := TextureRect.new()
	art.texture = _art_for(id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)

	var reward := Panel.new()
	reward.add_theme_stylebox_override("panel", _panel_style(Color(0.002, 0.029, 0.035, 0.92), GOLD, 4, 1))
	reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(reward)

	var reward_line := HBoxContainer.new()
	reward_line.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_line.add_theme_constant_override("separation", 4)
	reward.add_child(reward_line)
	var product: Dictionary = _catalog.get(id, {})
	var jade_amount: int = int(product.get("celestial_jade", 0))
	_add_icon_amount(reward_line, JADE_ICON, _thousands(jade_amount))

	var price := _label("LOADING PRICE...", 12, QUIET)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.autowrap_mode = TextServer.AUTOWRAP_OFF
	price.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(price)

	# All VIEW DETAILS buttons use the same neutral style; the largest-pack
	# highlight stays on its card border and badge, not its action state.
	var action := _button("VIEW DETAILS", false)
	action.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	action.keep_pressed_outside = false
	action.mouse_filter = Control.MOUSE_FILTER_PASS
	action.button_down.connect(_on_offer_button_down.bind(action))
	action.pressed.connect(_on_offer_pressed.bind(id, action))
	card.add_child(action)

	return {
		"card": card,
		"badge": badge,
		"title": title,
		"description": description,
		"art": art,
		"reward": reward,
		"reward_line": reward_line,
		"price": price,
		"action": action,
	}

func _add_icon_amount(parent: HBoxContainer, texture: Texture2D, amount: String) -> void:
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 3)
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pair)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(17.0, 17.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair.add_child(icon)
	var count := _label("×" + amount, 12, IVORY)
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	pair.add_child(count)

func _art_for(id: String) -> Texture2D:
	match id:
		"jade_pouch_100":
			return DAILY_ART
		"jade_satchel_550", "jade_casket_1200":
			return JADE_ART
		"jade_vault_2500", "jade_treasury_6500":
			return CULTIVATION_ART
		_:
			return ASCENSION_ART

func _build_details_overlay() -> void:
	_details_layer = Control.new()
	_details_layer.name = "TreasuryPremiumPackDetails"
	_details_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_details_layer.visible = false
	_details_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.add_child(_details_layer)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.009, 0.015, 0.83)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_details_layer.add_child(shade)

	_details_panel = Panel.new()
	_details_panel.name = "PremiumTreasuryDetailSurface"
	var panel_style := _panel_style(Color(0.002, 0.027, 0.040, 0.995), GOLD, 13, 2)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.82)
	panel_style.shadow_size = 16
	_details_panel.add_theme_stylebox_override("panel", panel_style)
	_details_layer.add_child(_details_panel)

	_details_badge = _label("CELESTIAL JADE", 12, JADE)
	_details_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	_details_panel.add_child(_details_badge)

	_details_title = _label("", 23, LIGHT_GOLD)
	_details_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_title.max_lines_visible = 2
	_details_panel.add_child(_details_title)

	# A short marketing line and *only* an actionable transaction message.
	# Idle billing status / sorting / backend descriptions are never shown.
	_details_body = RichTextLabel.new()
	_details_body.bbcode_enabled = false
	_details_body.fit_content = false
	_details_body.scroll_active = true
	_details_body.selection_enabled = false
	_details_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_details_body.add_theme_font_size_override("normal_font_size", 14)
	_details_body.add_theme_color_override("default_color", IVORY)
	_details_panel.add_child(_details_body)

	_details_art = TextureRect.new()
	_details_art.name = "SelectedCelestialChest"
	_details_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_details_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_details_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details_panel.add_child(_details_art)

	_details_art_frame = Panel.new()
	_details_art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details_art_frame.add_theme_stylebox_override(
		"panel", _panel_style(Color.TRANSPARENT, Color(0.91, 0.68, 0.27, 0.86), 8, 1)
	)
	_details_panel.add_child(_details_art_frame)

	_details_reward_panel = Panel.new()
	_details_reward_panel.name = "FeaturedCelestialJadeReward"
	_details_reward_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reward_style := _panel_style(Color(0.012, 0.092, 0.097, 0.99), GOLD, 9, 2)
	reward_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	reward_style.shadow_size = 5
	_details_reward_panel.add_theme_stylebox_override("panel", reward_style)
	_details_panel.add_child(_details_reward_panel)

	_details_reward_icon = TextureRect.new()
	_details_reward_icon.name = "CelestialJadePremiumIcon"
	_details_reward_icon.texture = JADE_ICON
	_details_reward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_details_reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_details_reward_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details_reward_panel.add_child(_details_reward_icon)

	_details_reward_amount = _label("", 32, LIGHT_GOLD)
	_details_reward_amount.name = "CatalogJadeQuantity"
	_details_reward_amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	_details_reward_amount.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_details_reward_panel.add_child(_details_reward_amount)

	_details_reward_name = _label("CELESTIAL JADE", 13, JADE)
	_details_reward_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_details_reward_panel.add_child(_details_reward_name)

	_details_price = _label("", 24, IVORY)
	_details_price.name = "LocalizedPlayPrice"
	_details_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_price.autowrap_mode = TextServer.AUTOWRAP_OFF
	_details_price.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_details_panel.add_child(_details_price)

	_details_purchase = _button("PLEASE WAIT...", true)
	_details_purchase.name = "ConfirmGooglePlayPurchase"
	_details_purchase.disabled = true
	_details_purchase.pressed.connect(_request_purchase)
	_details_panel.add_child(_details_purchase)

	_details_restore = _button("RESTORE PURCHASES", false)
	_details_restore.name = "RestoreViaExistingBillingProvider"
	_details_restore.pressed.connect(_restore_purchases)
	_details_panel.add_child(_details_restore)

	_details_close = _button("CLOSE", false)
	_details_close.pressed.connect(_hide_details)
	_details_panel.add_child(_details_close)

func _layout_ui() -> void:
	if not is_instance_valid(_popup) or size.x <= 0.0 or size.y <= 0.0:
		return
	var compact: bool = size.x < 520.0
	var popup_w: float = minf(size.x - 14.0, 628.0)
	var popup_h: float = minf(size.y - 32.0, 1060.0)
	_popup.position = Vector2((size.x - popup_w) * 0.5, (size.y - popup_h) * 0.50)
	_popup.size = Vector2(popup_w, popup_h)

	# Dimensions come from the approved frame aperture, not the full PNG bounds.
	# The backing color has NO separate outer border, fixing the stray rectangle.
	var safe_x: float = maxf(27.0, popup_w * 0.095)
	var safe_w: float = popup_w - 2.0 * safe_x
	var hero_global_y: float = popup_h * 0.190
	_inner_background.position = Vector2(safe_x, popup_h * 0.108)
	_inner_background.size = Vector2(safe_w, popup_h * 0.795)
	var viewport_h: float = popup_h * 0.905 - hero_global_y
	_content_viewport.position = Vector2(safe_x, hero_global_y)
	_content_viewport.size = Vector2(safe_w, viewport_h)

	_title.position = Vector2(safe_x, popup_h * 0.104)
	# Reserve the close hit target on especially narrow portrait viewports.
	_title.size = Vector2(safe_w - (34.0 if popup_w < 355.0 else 0.0), 52.0 if not compact else 36.0)
	_set_font(_title, 20 if popup_w < 355.0 else (23 if compact else 35))
	_subtitle.position = Vector2(safe_x, popup_h * 0.160)
	_subtitle.size = Vector2(safe_w, 22.0)
	# Do not silently ellipsize the price disclosure on compact displays.
	_subtitle.text = (
		"Celestial Jade · Ascension Treasures"
		if compact else "Celestial Jade · Treasures for Your Ascension"
	)
	_set_font(_subtitle, 14 if not compact else 11)
	_close_button.position = Vector2(popup_w - maxf(59.0, popup_w * 0.135), popup_h * 0.085)
	_close_button.size = Vector2(44.0, 44.0)
	_set_font(_close_button, 26)

	# Without the starter promo, the approved Lin Yue art gets the full hero
	# treatment. The six Jade cards occupy every remaining safe frame row.
	# Keep card labels, artwork, price and CTA in bounded areas, with real
	# horizontal swipe rather than squeezing six cards into the viewport.
	var hero_h: float = clampf(popup_h * 0.255, 105.0, 260.0)
	var heading_y: float = hero_h + 8.0
	var offers_y: float = heading_y + 24.0
	# Card anatomy: header/summary, image, fixed reward/price row and a
	# 44px CTA. Below this height art or labels would collide.
	var min_gallery_h: float = 335.0
	var gallery_h: float = maxf(min_gallery_h, viewport_h - offers_y)
	var content_h: float = offers_y + gallery_h
	_content_clip.custom_minimum_size = Vector2(safe_w, maxf(viewport_h, content_h))
	_content_clip.size = _content_clip.custom_minimum_size
	# Activate vertical swipe only on short viewports; standard-size UI stays
	# exactly in place and uses horizontal swipe for all six Jade packs.
	if content_h > viewport_h + 1.0:
		_content_viewport.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	else:
		_content_viewport.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_hero.position = Vector2.ZERO
	_hero.size = Vector2(safe_w, hero_h)
	_hero_rim.position = _hero.position
	_hero_rim.size = _hero.size

	_offers_caption.position = Vector2(3.0, heading_y)
	_offers_caption.size = Vector2(safe_w * 0.61, 23.0)
	_offers_caption.text = "JADE PACKS" if safe_w < 300.0 else "CELESTIAL JADE PACKS"
	_set_font(_offers_caption, 14 if compact else 17)
	_swipe_caption.position = Vector2(safe_w * 0.61, heading_y)
	_swipe_caption.size = Vector2(safe_w * 0.39 - 2.0, 23.0)
	_swipe_caption.text = "SWIPE  ‹  ›" if compact else "6 PACKS  ·  SWIPE  ‹  ›"
	_set_font(_swipe_caption, 11)

	_offer_scroll.position = Vector2(0.0, offers_y)
	_offer_scroll.size = Vector2(safe_w, gallery_h)
	var spacing: float = 9.0
	_offer_row.add_theme_constant_override("separation", int(spacing))
	var card_w: float = (
		maxf(152.0, minf(210.0, safe_w * 0.60))
		if compact else maxf(171.0, minf(242.0, safe_w * 0.365))
	)
	# Six catalog-backed cards are wider than the ScrollContainer viewport.
	# This makes swipe functional and avoids micro-font, one-glyph wrapping.
	for entry: Dictionary in _cards:
		_layout_card(entry, card_w, gallery_h, compact)

	# Preview stays inside the ornamental safe area on short viewports.
	# Award card, actual price and purchase CTA stay fixed even with longer
	# transaction feedback; the short explanation can scroll independently.
	var details_h: float = minf(552.0, maxf(470.0, popup_h * 0.53))
	details_h = minf(details_h, popup_h - 36.0)
	var panel_w: float = safe_w - 12.0
	_details_panel.position = Vector2(safe_x + 6.0, (popup_h - details_h) * 0.50)
	_details_panel.size = Vector2(panel_w, details_h)
	_details_badge.position = Vector2(18.0, 12.0)
	_details_badge.size = Vector2(panel_w - 36.0, 20.0)
	_set_font(_details_badge, 12)
	_details_title.position = Vector2(15.0, 34.0)
	_details_title.size = Vector2(panel_w - 30.0, 43.0)
	_set_font(_details_title, 19 if compact else 23)
	_details_body.position = Vector2(19.0, 78.0)
	_details_body.size = Vector2(panel_w - 38.0, 49.0)
	var art_y: float = 132.0
	var reward_y: float = details_h - 244.0
	_details_art.position = Vector2(16.0, art_y)
	_details_art.size = Vector2(panel_w - 32.0, maxf(60.0, reward_y - art_y - 8.0))
	_details_art_frame.position = _details_art.position
	_details_art_frame.size = _details_art.size
	_details_reward_panel.position = Vector2(16.0, reward_y)
	_details_reward_panel.size = Vector2(panel_w - 32.0, 92.0)
	var reward_w: float = _details_reward_panel.size.x
	_details_reward_icon.position = Vector2(13.0, 15.0)
	_details_reward_icon.size = Vector2(61.0, 61.0)
	_details_reward_amount.position = Vector2(80.0, 12.0)
	_details_reward_amount.size = Vector2(reward_w - 92.0, 43.0)
	_set_font(_details_reward_amount, 28 if compact else 33)
	_details_reward_name.position = Vector2(82.0, 57.0)
	_details_reward_name.size = Vector2(reward_w - 95.0, 23.0)
	_set_font(_details_reward_name, 13)
	_details_price.position = Vector2(16.0, details_h - 148.0)
	_details_price.size = Vector2(panel_w - 32.0, 34.0)
	_set_font(_details_price, 19 if compact else 24)
	_details_purchase.position = Vector2(16.0, details_h - 103.0)
	_details_purchase.size = Vector2(panel_w - 32.0, 44.0)
	_set_font(_details_purchase, 13 if compact else 15)
	# Restore stays available but never competes visually with BUY NOW.
	var secondary_y: float = details_h - 53.0
	var secondary_w: float = (panel_w - 40.0) * 0.50
	_details_restore.position = Vector2(16.0, secondary_y)
	_details_restore.size = Vector2(secondary_w, 38.0)
	_details_restore.text = "RESTORE" if compact else "RESTORE PURCHASES"
	_set_font(_details_restore, 12 if compact else 13)
	_details_close.position = Vector2(24.0 + secondary_w, secondary_y)
	_details_close.size = Vector2(secondary_w, 38.0)
	_set_font(_details_close, 13 if compact else 14)
	_popup.visible = true

func _layout_card(entry: Dictionary, card_w: float, card_h: float, compact: bool) -> void:
	var card := entry["card"] as Panel
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	var badge := entry["badge"] as Label
	badge.position = Vector2(6.0, 6.0)
	badge.size = Vector2(card_w - 12.0, 17.0)
	_set_font(badge, 10)
	var title := entry["title"] as Label
	# Separate the title's two-line slot from the body copy. The former
	# layout ended the title at 68px and began copy at 67px (1px overlap).
	title.position = Vector2(8.0, 28.0)
	title.size = Vector2(card_w - 16.0, 55.0)
	_set_font(title, 17 if compact else 18)
	var description := entry["description"] as Label
	description.position = Vector2(8.0, 97.0)
	description.size = Vector2(card_w - 16.0, 52.0)
	_set_font(description, 11 if compact else 12)
	var art := entry["art"] as TextureRect
	art.position = Vector2(5.0, 157.0)
	art.size = Vector2(card_w - 10.0, card_h - 280.0)
	var reward := entry["reward"] as Panel
	reward.position = Vector2(7.0, card_h - 116.0)
	reward.size = Vector2(card_w - 14.0, 33.0)
	var reward_line := entry["reward_line"] as HBoxContainer
	reward_line.position = Vector2(3.0, 4.0)
	reward_line.size = Vector2(reward.size.x - 6.0, 25.0)
	var price := entry["price"] as Label
	price.position = Vector2(5.0, card_h - 79.0)
	price.size = Vector2(card_w - 10.0, 21.0)
	_set_font(price, 11 if compact else 12)
	var action := entry["action"] as Button
	action.position = Vector2(7.0, card_h - 52.0)
	action.size = Vector2(card_w - 14.0, 44.0)
	_set_font(action, 13 if compact else 14)

func _on_offer_button_down(button: Button) -> void:
	_pressed_scroll_positions[button.get_instance_id()] = Vector2i(
		_offer_scroll.scroll_horizontal,
		_content_viewport.scroll_vertical
	)

func _on_offer_pressed(id: String, button: Button) -> void:
	var current_position := Vector2i(
		_offer_scroll.scroll_horizontal,
		_content_viewport.scroll_vertical
	)
	var pressed_position: Vector2i = _pressed_scroll_positions.get(
		button.get_instance_id(), current_position
	)
	_pressed_scroll_positions.erase(button.get_instance_id())
	# Do not use Button.disabled as the scroll guard: that visibly dims every
	# VIEW DETAILS button during touch movement. Block activation instead.
	if (
		_swiping or _swipe_settling
		or Time.get_ticks_msec() < _tap_guard_until_msec
		or absi(current_position.x - pressed_position.x) >= SWIPE_DEADZONE
		or absi(current_position.y - pressed_position.y) >= SWIPE_DEADZONE
		or _purchase_busy
	):
		return
	_show_details(id)

func _on_scroll_started() -> void:
	_active_scroll_count += 1
	_scroll_generation += 1
	_swiping = true
	_swipe_settling = true
	_tap_guard_until_msec = Time.get_ticks_msec() + 190

func _on_scroll_ended() -> void:
	_active_scroll_count = maxi(0, _active_scroll_count - 1)
	_tap_guard_until_msec = Time.get_ticks_msec() + 190
	if _active_scroll_count > 0:
		return
	var generation: int = _scroll_generation
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(0.19).timeout
	if not is_inside_tree() or generation != _scroll_generation or _active_scroll_count > 0:
		return
	_swiping = false
	_swipe_settling = false
	_pressed_scroll_positions.clear()

func _show_details(id: String) -> void:
	if not _catalog.has(id) or not (id in OFFER_IDS):
		return
	_selected_id = id
	_details_title.text = str(OFFER_NAMES.get(id, "CELESTIAL JADE PACK"))
	_details_badge.text = "LARGEST PACK" if id == "jade_ascendant_14000" else "CELESTIAL JADE"
	_details_art.texture = _art_for(id)
	_update_details()
	_details_body.scroll_to_line(0)
	_details_layer.visible = true

func _hide_details() -> void:
	_details_layer.visible = false
	if not _purchase_busy:
		_selected_id = ""

func _thousands(value: int) -> String:
	var digits: String = str(value)
	var result: String = ""
	for i: int in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits.substr(i, 1)
	return result

func _set_font(control: Control, point_size: int) -> void:
	if control.get_theme_font_size("font_size") != point_size:
		control.add_theme_font_size_override("font_size", point_size)

func _label(value: String, point_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", ink)
	# Popup children are hosted under Home, which normally applies a deferred
	# font floor to newly-added Labels. LAB-APPROVED sizes have already been
	# finalized by _layout_ui; give typography one effective owner.
	label.set_meta(&"jade_mobile_readability_v2", true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.keep_pressed_outside = false
	button.add_theme_font_size_override("font_size", 14)
	button.set_meta(&"jade_mobile_readability_v2", true)
	button.add_theme_color_override("font_color", Color(0.10, 0.050, 0.005) if primary else IVORY)
	button.add_theme_stylebox_override("normal", _panel_style(
		Color(1.0, 0.78, 0.32, 1.0) if primary else Color(0.01, 0.080, 0.092, 0.99), GOLD, 7, 1
	))
	button.add_theme_stylebox_override("hover", _panel_style(
		Color(1.0, 0.88, 0.48, 1.0) if primary else Color(0.02, 0.13, 0.14, 1.0), LIGHT_GOLD, 7, 1
	))
	button.add_theme_stylebox_override("pressed", _panel_style(
		Color(0.83, 0.58, 0.21, 1.0) if primary else Color(0.01, 0.045, 0.050, 1.0), GOLD, 7, 1
	))
	return button

func _panel_style(fill: Color, edge: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()

func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_back()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_back()

func _back() -> void:
	if is_instance_valid(_details_layer) and _details_layer.visible:
		_hide_details()
		return
	LiveOpsUi.return_home(self)


# --- Google Play Billing: authoritative runtime integration ---

func _connect_runtime_signals() -> void:
	if not PavilionManager.store_products_updated.is_connected(_on_store_products_updated):
		PavilionManager.store_products_updated.connect(_on_store_products_updated)
	if not PavilionManager.billing_purchase_state_changed.is_connected(_on_purchase_state_changed):
		PavilionManager.billing_purchase_state_changed.connect(_on_purchase_state_changed)
	if not PavilionManager.purchase_delivery_finished.is_connected(_on_purchase_delivery_finished):
		PavilionManager.purchase_delivery_finished.connect(_on_purchase_delivery_finished)
	if not PavilionManager.billing_entitlements_changed.is_connected(_on_entitlements_changed):
		PavilionManager.billing_entitlements_changed.connect(_on_entitlements_changed)
	if not PavilionManager.pavilion_changed.is_connected(_on_pavilion_changed):
		PavilionManager.pavilion_changed.connect(_on_pavilion_changed)


func _refresh_storefront() -> void:
	# Monetary prices are NEVER inferred from the art or the tier quantity.
	var runtime: Dictionary = PavilionManager.get_billing_runtime_status()
	_billing_ready = bool(runtime.get("ready", false))
	_billing_state = str(runtime.get("state", "unavailable"))
	_live_price_data = PavilionManager.get_iap_store_products()
	for product_id: String in OFFER_IDS:
		if not _cards_by_id.has(product_id):
			continue
		var entry: Dictionary = _cards_by_id[product_id]
		var price_label: Label = entry["price"] as Label
		var shown_price: String = _available_formatted_price(product_id)
		var next_text: String = "LOADING PRICE..."
		if not PavilionManager.is_iap_purchase_supported(product_id):
			next_text = "NOT AVAILABLE"
		elif not shown_price.is_empty():
			next_text = shown_price
		elif not _billing_ready and _billing_state in ["missing", "disconnected", "connect_error", "unavailable"]:
			next_text = "STORE UNAVAILABLE"
		if price_label.text != next_text:
			price_label.text = next_text
	_apply_play_price_order()
	if is_instance_valid(_details_layer) and _details_layer.visible:
		_update_details()


func _available_formatted_price(product_id: String) -> String:
	if not _billing_ready or not PavilionManager.is_iap_purchase_supported(product_id):
		return ""
	if not _live_price_data.has(product_id):
		return ""
	var info: Dictionary = _live_price_data[product_id]
	if int(info.get("price_amount_micros", 0)) <= 0:
		return ""
	return str(info.get("formatted_price", "")).strip_edges()


func _apply_play_price_order() -> void:
	# Keep catalog-quantity order while price data is incomplete. Once every
	# paid tier has a comparable Google Play price, sort actual money prices.
	var sorted_ids: Array[String] = []
	var currency_code: String = ""
	for product_id: String in OFFER_IDS:
		if _available_formatted_price(product_id).is_empty():
			_prices_sorted = false
			return
		var info: Dictionary = _live_price_data[product_id]
		var code: String = str(info.get("price_currency_code", ""))
		if code.is_empty():
			_prices_sorted = false
			return
		if currency_code.is_empty():
			currency_code = code
		elif currency_code != code:
			_prices_sorted = false
			return
		sorted_ids.append(product_id)
	for left_index: int in range(sorted_ids.size()):
		for right_index: int in range(left_index + 1, sorted_ids.size()):
			var left_id: String = sorted_ids[left_index]
			var right_id: String = sorted_ids[right_index]
			var left_info: Dictionary = _live_price_data[left_id]
			var right_info: Dictionary = _live_price_data[right_id]
			if int(right_info.get("price_amount_micros", 0)) < int(left_info.get("price_amount_micros", 0)):
				sorted_ids[left_index] = right_id
				sorted_ids[right_index] = left_id
	for child_index: int in range(sorted_ids.size()):
		var entry: Dictionary = _cards_by_id[sorted_ids[child_index]]
		var card: Panel = entry["card"] as Panel
		if _offer_row.get_child(child_index) != card:
			_offer_row.move_child(card, child_index)
	_prices_sorted = true


func _update_details() -> void:
	if _selected_id.is_empty() or not _catalog.has(_selected_id):
		return
	var product: Dictionary = _catalog[_selected_id]
	var jade_count: int = int(product.get("celestial_jade", 0))
	var shown_price: String = _available_formatted_price(_selected_id)
	_details_reward_amount.text = _thousands(jade_count)
	_details_price.text = shown_price if not shown_price.is_empty() else "PRICE UNAVAILABLE"

	# Remove idle diagnostics such as Billing READY, Play price labels and
	# price-sort implementation details. Keep real transaction messages for
	# pending purchases, failure, cancellation and save recovery.
	var body: String = str(OFFER_COPY.get(_selected_id, ""))
	if (
		not _billing_message.is_empty()
		and (_message_product_id.is_empty() or _message_product_id == _selected_id)
	):
		body += "\n" + _billing_message
	if _details_body.text != body:
		_details_body.text = body

	var can_purchase: bool = (
		not _purchase_busy
		and not shown_price.is_empty()
		and PavilionManager.is_iap_purchase_supported(_selected_id)
	)
	_details_purchase.disabled = not can_purchase
	if _purchase_busy:
		_details_purchase.text = "PROCESSING PURCHASE..."
	elif can_purchase:
		_details_purchase.text = "BUY NOW  ·  " + shown_price
	else:
		_details_purchase.text = "UNAVAILABLE"
	_details_restore.disabled = _purchase_busy

func _request_purchase() -> void:
	if _selected_id.is_empty() or _purchase_busy:
		return
	if _available_formatted_price(_selected_id).is_empty():
		_billing_message = "Google Play price is not available. No purchase started."
		_update_details()
		return
	_purchase_busy = true
	_active_purchase_id = _selected_id
	_billing_message = "Opening Google Play purchase..."
	_message_product_id = _selected_id
	_update_details()
	# Google Play opens checkout; the purchase token is forwarded transiently
	# to secure native/server authority. Treasury never consumes or grants.
	if not PavilionManager.purchase_iap(_active_purchase_id):
		_purchase_busy = false
		_active_purchase_id = ""
		_refresh_storefront()


func _restore_purchases() -> void:
	if _purchase_busy:
		return
	_billing_message = "Checking Google Play for recoverable purchases..."
	_message_product_id = ""
	_update_details()
	PavilionManager.restore_iap_purchases()


func _on_store_products_updated(_products: Dictionary) -> void:
	_refresh_storefront()


func _on_purchase_state_changed(product_id: String, status: String, message: String) -> void:
	if status in ["opening", "pending", "verification_required"]:
		_purchase_busy = true
		if not product_id.is_empty():
			_active_purchase_id = product_id
	elif status in [
		"verification_in_progress",
		"verification_deferred",
		"recovery_deferred",
	]:
		# A secure authority request already owns the current transaction.
		# Deferred recovery must not overwrite that active product id.
		_purchase_busy = true
	elif status in [
		"cancelled",
		"failed",
		"launch_failed",
		"unavailable",
		"unsupported",
		"price_unavailable",
		"invalid",
		"identity_preparing",
		"identity_unavailable",
		"secure_verification_unavailable",
		"secure_verification_failed",
		"delivered",
	]:
		_purchase_busy = false
		_active_purchase_id = ""
	if not message.is_empty():
		_billing_message = tr(message)
		_message_product_id = product_id
	_refresh_storefront()


func _on_purchase_delivery_finished(product_id: String, success: bool, message: String) -> void:
	# Delivery is terminal for this Treasury presentation transaction on both
	# success and failure. Recovery can start another verification afterwards.
	_purchase_busy = false
	_active_purchase_id = ""
	_message_product_id = product_id
	_billing_message = (
		"PURCHASE SAVED · REWARD DELIVERED"
		if success
		else tr(message)
	)
	_refresh_storefront()


func _on_entitlements_changed(_product_ids: Array[String]) -> void:
	_refresh_storefront()


func _on_pavilion_changed() -> void:
	_refresh_storefront()
