extends RefCounted

const PRODUCT_ID: String = "gale_starter_pack"
const INDONESIA_PRICE: int = 39000
const UNLOCK_CHAPTER: int = 1
const UNLOCK_STAGE: int = 5
const OFFER_SCENE: String = "res://scenes/ui/gale_starter_pack.tscn"
const ITEMS: Array[String] = [
	"gale_parasol", "galeweave_robe", "galeweave_bracer", "galeweave_boots", "galeweave_pendant"
]

static func preview_available() -> bool:
	return OS.is_debug_build() and JourneyManager.is_stage_cleared(UNLOCK_CHAPTER, UNLOCK_STAGE)

static func target_price() -> String:
	return "Rp%d.%03d" % [floori(INDONESIA_PRICE / 1000.0), INDONESIA_PRICE % 1000]
