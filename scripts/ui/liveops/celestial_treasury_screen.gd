extends Control

const LiveOpsUi = preload(
	"res://scripts/ui/liveops/live_ops_ui.gd"
)

const ICON_TREASURY: Texture2D = preload(
	"res://assets/ui/liveops/treasury.png"
)

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


func _ready() -> void:
	if not OS.is_debug_build():
		_back()
		return

	SceneTransitionManager.set_back_handler(_back)

	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("STORE PREVIEW"),
		tr("Celestial Treasury"),
		tr(
			"Google Play prices will be localized by the store "
			+ "when Billing is connected."
		),
		ICON_TREASURY
	)
	content = shell["content"] as VBoxContainer
	(shell["back_button"] as Button).pressed.connect(_back)
	_build_store()


func _build_store() -> void:
	var status := LiveOpsUi.make_card(
		content,
		Color(0.96, 0.78, 0.34, 1.0)
	)
	LiveOpsUi.add_label(
		status,
		tr("DEBUG PREVIEW • PURCHASES DISABLED"),
		12,
		Color(0.98, 0.78, 0.34, 1.0)
	)
	LiveOpsUi.add_label(
		status,
		tr("CURRENT BALANCE"),
		11,
		Color(0.42, 0.86, 0.76, 1.0)
	)
	LiveOpsUi.add_label(
		status,
		tr("%d CELESTIAL JADE") % PavilionManager.get_celestial_jade(),
		15
	)
	LiveOpsUi.add_label(
		status,
		tr("%d PAVILION SEALS") % PavilionManager.get_pavilion_seals(),
		15
	)
	LiveOpsUi.add_label(
		status,
		tr("Prices are intentionally not hardcoded."),
		12,
		Color(0.64, 0.76, 0.73, 1.0)
	)

	var products: Dictionary = PavilionManager.get_iap_product_catalog()
	for product_id: String in PRODUCT_ORDER:
		if not products.has(product_id):
			continue
		var product: Dictionary = products[product_id]
		_add_product_card(product_id, product)


func _add_product_card(
	product_id: String,
	product: Dictionary
) -> void:
	var card := LiveOpsUi.make_card(
		content,
		Color(0.34, 0.86, 0.76, 1.0)
	)
	LiveOpsUi.add_label(
		card,
		tr(str(PRODUCT_NAMES.get(product_id, product_id.to_upper()))),
		18,
		Color(0.94, 0.98, 0.96, 1.0)
	)

	var product_type: String = str(product.get("type", ""))
	var summary: String = ""
	if product_type == "consumable":
		summary = tr("%d JADE") % int(
			product.get("celestial_jade", 0)
		)
	elif product_type == "one_time_bundle":
		summary = tr("%d JADE + %d SEALS") % [
			int(product.get("celestial_jade", 0)),
			int(product.get("pavilion_seal", 0)),
		]
	elif product_type == "monthly_blessing":
		summary = tr("%d JADE NOW + %d/DAY • %d DAYS") % [
			int(product.get("initial_celestial_jade", 0)),
			int(product.get("daily_celestial_jade", 0)),
			int(product.get("duration_days", 0)),
		]
	LiveOpsUi.add_label(
		card,
		summary,
		14,
		Color(0.88, 0.84, 0.62, 1.0)
	)

	var preview_button := LiveOpsUi.add_action_button(
		card,
		tr("BILLING NEXT"),
		Callable(),
		false
	)
	preview_button.disabled = true


func _back() -> void:
	LiveOpsUi.return_home(self)
