extends Control

const LiveOpsUi = preload("res://scripts/ui/liveops/live_ops_ui.gd")
const ICON_TREASURY: Texture2D = preload("res://assets/ui/liveops/treasury.png")

const PRODUCT_ORDER: Array[String] = [
	"jade_pouch_100",
	"jade_satchel_550",
	"jade_casket_1200",
	"jade_vault_2500",
	"jade_treasury_6500",
	"jade_ascendant_14000",
	"starter_support_pack",
	"monthly_jade_blessing",
]

const PRODUCT_NAMES: Dictionary = {
	"jade_pouch_100": "JADE POUCH",
	"jade_satchel_550": "JADE SATCHEL",
	"jade_casket_1200": "JADE CASKET",
	"jade_vault_2500": "JADE VAULT",
	"jade_treasury_6500": "JADE TREASURY",
	"jade_ascendant_14000": "ASCENDANT RESERVE",
	"starter_support_pack": "STARTER SUPPORT PACK",
	"monthly_jade_blessing": "MONTHLY JADE BLESSING",
}

var content: VBoxContainer
var store_scroll: ScrollContainer
var status_label: Label
var jade_balance_label: Label
var seal_balance_label: Label
var message_label: Label
var product_price_labels: Dictionary = {}
var product_buttons: Dictionary = {}


func _ready() -> void:
	# Treasury must remain reachable in Android release/Internal Testing builds.
	# Keep non-Android release builds fail-closed; debug desktop stays available
	# for QA.
	if OS.get_name() != "Android" and not OS.is_debug_build():
		_back()
		return
	SceneTransitionManager.set_back_handler(_back)

	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("CELESTIAL TREASURY"),
		tr("Celestial Treasury"),
		tr(
			"Prices are loaded directly from Google Play. "
			+ "No price is hardcoded."
		),
		ICON_TREASURY
	)
	content = shell["content"] as VBoxContainer
	store_scroll = shell.get("scroll") as ScrollContainer
	(shell["back_button"] as Button).pressed.connect(_back)
	_connect_runtime_signals()
	_build_store()
	_configure_mobile_scroll()
	PavilionManager.refresh_iap_store_products()
	_refresh_storefront()


func _connect_runtime_signals() -> void:
	if not PavilionManager.store_products_updated.is_connected(
		_on_store_products_updated
	):
		PavilionManager.store_products_updated.connect(
			_on_store_products_updated
		)
	if not PavilionManager.billing_purchase_state_changed.is_connected(
		_on_purchase_state_changed
	):
		PavilionManager.billing_purchase_state_changed.connect(
			_on_purchase_state_changed
		)
	if not PavilionManager.purchase_delivery_finished.is_connected(
		_on_purchase_delivery_finished
	):
		PavilionManager.purchase_delivery_finished.connect(
			_on_purchase_delivery_finished
		)
	if not PavilionManager.billing_entitlements_changed.is_connected(
		_on_entitlements_changed
	):
		PavilionManager.billing_entitlements_changed.connect(
			_on_entitlements_changed
		)
	if not PavilionManager.pavilion_changed.is_connected(
		_on_pavilion_changed
	):
		PavilionManager.pavilion_changed.connect(
			_on_pavilion_changed
		)


func _build_store() -> void:
	var status_card := LiveOpsUi.make_card(
		content,
		Color(0.96, 0.78, 0.34, 1.0)
	)
	status_label = LiveOpsUi.add_label(
		status_card,
		tr("GOOGLE PLAY BILLING • CHECKING"),
		12,
		Color(0.98, 0.78, 0.34, 1.0)
	)
	LiveOpsUi.add_label(
		status_card,
		tr("CURRENT BALANCE"),
		11,
		Color(0.42, 0.86, 0.76, 1.0)
	)
	jade_balance_label = LiveOpsUi.add_label(
		status_card,
		"",
		16
	)
	seal_balance_label = LiveOpsUi.add_label(
		status_card,
		"",
		14
	)
	message_label = LiveOpsUi.add_label(
		status_card,
		tr(
			"Purchases are optional and do not block progression."
		),
		11,
		Color(0.64, 0.76, 0.73, 1.0)
	)
	var restore_button := LiveOpsUi.add_action_button(
		status_card,
		tr("RESTORE PURCHASES"),
		_restore_purchases,
		false
	)
	restore_button.custom_minimum_size.y = 42.0

	var products: Dictionary = PavilionManager.get_iap_product_catalog()
	for product_id: String in PRODUCT_ORDER:
		if products.has(product_id):
			_add_product_card(
				product_id,
				products[product_id]
			)


func _configure_mobile_scroll() -> void:
	if store_scroll == null or not is_instance_valid(store_scroll):
		return

	# Treasury creates its product buttons after LiveOpsUi installed the shared
	# scroll guard. Make all newly-created controls bubble touch drag events back
	# to the ScrollContainer while preserving normal taps.
	store_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	store_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	store_scroll.scroll_deadzone = 6
	store_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	store_scroll.follow_focus = false

	_make_store_tree_scroll_friendly(content)


func _make_store_tree_scroll_friendly(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Button:
			var button := child as Button
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
			button.keep_pressed_outside = false
		elif child is Label or child is TextureRect:
			(child as Control).mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
		elif child is Control:
			(child as Control).mouse_filter = (
				Control.MOUSE_FILTER_PASS
			)

		_make_store_tree_scroll_friendly(child)


func _add_product_card(
	product_id: String,
	product: Dictionary
) -> void:
	var product_type := str(product.get("type", ""))
	var accent := (
		Color(0.96, 0.76, 0.30, 1.0)
		if product_type == "one_time_bundle"
		else Color(0.34, 0.86, 0.76, 1.0)
	)
	var card := LiveOpsUi.make_card(content, accent)
	LiveOpsUi.add_label(
		card,
		tr(str(
			PRODUCT_NAMES.get(
				product_id,
				product_id.to_upper()
			)
		)),
		18,
		Color(0.94, 0.98, 0.96, 1.0)
	)
	LiveOpsUi.add_label(
		card,
		_product_summary(product),
		14,
		Color(0.88, 0.84, 0.62, 1.0)
	)
	var price := LiveOpsUi.add_label(
		card,
		tr("PRICE FROM GOOGLE PLAY"),
		14,
		Color(0.42, 0.86, 0.76, 1.0)
	)
	product_price_labels[product_id] = price
	var button := LiveOpsUi.add_action_button(
		card,
		tr("CHECKING STORE..."),
		Callable(self, "_request_purchase").bind(
			product_id
		),
		product_type == "one_time_bundle"
	)
	button.disabled = true
	product_buttons[product_id] = button

	if product_type == "monthly_blessing":
		LiveOpsUi.add_label(
			card,
			tr(
				"COMING LATER • PURCHASE FLOW NOT ENABLED YET"
			),
			10,
			Color(0.62, 0.68, 0.66, 1.0)
		)


func _product_summary(product: Dictionary) -> String:
	var product_type := str(product.get("type", ""))
	if product_type == "consumable":
		return tr("%d JADE") % int(
			product.get("celestial_jade", 0)
		)
	if product_type == "one_time_bundle":
		return tr("%d JADE + %d SEALS") % [
			int(product.get("celestial_jade", 0)),
			int(product.get("pavilion_seal", 0)),
		]
	if product_type == "monthly_blessing":
		return tr(
			"%d JADE NOW + %d/DAY • %d DAYS"
		) % [
			int(product.get(
				"initial_celestial_jade",
				0
			)),
			int(product.get(
				"daily_celestial_jade",
				0
			)),
			int(product.get("duration_days", 0)),
		]
	return tr("UNAVAILABLE")


func _refresh_storefront() -> void:
	_refresh_balances()
	var runtime := PavilionManager.get_billing_runtime_status()
	var runtime_state := str(
		runtime.get("state", "unavailable")
	)
	var billing_ready := bool(
		runtime.get("ready", false)
	)
	var store_products := PavilionManager.get_iap_store_products()
	status_label.text = (
		tr("GOOGLE PLAY BILLING • READY")
		if billing_ready and not store_products.is_empty()
		else tr("GOOGLE PLAY BILLING • %s")
			% runtime_state.to_upper()
	)

	for product_id: String in PRODUCT_ORDER:
		if not product_buttons.has(product_id):
			continue
		var button: Button = product_buttons[product_id]
		var price_label: Label = product_price_labels[
			product_id
		]

		if not PavilionManager.is_iap_purchase_supported(
			product_id
		):
			button.disabled = true
			button.text = tr("NOT AVAILABLE YET")
			price_label.text = tr("COMING LATER")
			continue

		if (
			product_id == "starter_support_pack"
			and PavilionManager.has_claimed_one_time_product(
				product_id
			)
		):
			button.disabled = true
			button.text = tr("OWNED")
			price_label.text = tr("PURCHASED")
			continue

		if not store_products.has(product_id):
			button.disabled = true
			button.text = tr("CHECKING STORE...")
			price_label.text = tr(
				"PRICE FROM GOOGLE PLAY"
			)
			continue

		var detail: Dictionary = store_products[
			product_id
		]
		var formatted_price := str(
			detail.get("formatted_price", "")
		)
		price_label.text = (
			formatted_price
			if not formatted_price.is_empty()
			else tr("PRICE FROM GOOGLE PLAY")
		)
		button.disabled = false
		button.text = (
			tr("PURCHASE • %s")
			% price_label.text
		)


func _refresh_balances() -> void:
	if jade_balance_label != null:
		jade_balance_label.text = (
			tr("%d CELESTIAL JADE")
			% PavilionManager.get_celestial_jade()
		)
	if seal_balance_label != null:
		seal_balance_label.text = (
			tr("%d PAVILION SEALS")
			% PavilionManager.get_pavilion_seals()
		)


func _request_purchase(product_id: String) -> void:
	var button: Button = product_buttons.get(
		product_id
	)
	if button != null:
		button.disabled = true
		button.text = tr("OPENING GOOGLE PLAY...")
	message_label.text = tr(
		"Waiting for Google Play purchase result..."
	)
	if not PavilionManager.purchase_iap(product_id):
		# The billing provider already emitted the concrete Google Play error.
		# Preserve it on screen so Internal Testing can diagnose launch failures.
		_refresh_storefront()


func _restore_purchases() -> void:
	message_label.text = tr(
		"Checking Google Play for recoverable purchases..."
	)
	PavilionManager.restore_iap_purchases()


func _on_store_products_updated(
	_products: Dictionary
) -> void:
	_refresh_storefront()


func _on_purchase_state_changed(
	product_id: String,
	status: String,
	message: String
) -> void:
	if (
		not product_id.is_empty()
		and product_buttons.has(product_id)
	):
		var button: Button = product_buttons[
			product_id
		]
		if status in ["opening", "granting"]:
			button.disabled = true
	if not message.is_empty():
		message_label.text = tr(message)
	if status in [
		"cancelled",
		"failed",
		"launch_failed",
		"unavailable",
		"completed",
	]:
		_refresh_storefront()


func _on_purchase_delivery_finished(
	_product_id: String,
	success: bool,
	message: String
) -> void:
	message_label.text = (
		tr("PURCHASE SAVED • REWARD DELIVERED")
		if success
		else tr(message)
	)
	_refresh_storefront()


func _on_entitlements_changed(
	_product_ids: Array[String]
) -> void:
	_refresh_storefront()


func _on_pavilion_changed() -> void:
	_refresh_storefront()


func _back() -> void:
	LiveOpsUi.return_home(self)
