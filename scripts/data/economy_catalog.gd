extends RefCounted

## Economy Foundation v2 + Cadence baseline.
## Pure data + validation. Real-money price strings are intentionally NOT stored
## here; storefront-localized prices must come from the verified billing provider.

const CURRENCY_CELESTIAL_JADE: String = "celestial_jade"
const CURRENCY_PAVILION_SEAL: String = "pavilion_seal"

const SUMMON_UNLOCK_CHAPTER: int = 1
const SUMMON_UNLOCK_STAGE: int = 5
const STARTER_SEAL_GRANT: int = 10

const SINGLE_PULL_COUNT: int = 1
const TEN_PULL_COUNT: int = 10
const SINGLE_PULL_JADE_COST: int = 100
const TEN_PULL_JADE_COST: int = 900
const SINGLE_PULL_SEAL_COST: int = 1
const TEN_PULL_SEAL_COST: int = 10

const RATE_BASIS_POINTS: int = 10000
const RARITY_ORDER: Array[String] = [
	"common",
	"rare",
	"epic",
	"legendary"
]
const BASE_DROP_RATE_BP: Dictionary = {
	"common": 6000,
	"rare": 2900,
	"epic": 900,
	"legendary": 200
}
const PITY_LIMITS: Dictionary = {
	"rare_plus": 10,
	"epic_plus": 30,
	"legendary": 50
}
const NATURAL_LEGENDARY_WISH_CHANCE: float = 0.50

## F2P cadence baseline. A day only counts after every active Daily Quest has
## been claimed, so missed calendar days never erase cycle progress.
const DAILY_COMPLETION_JADE: int = 20
const ACTIVE_DAY_CYCLE_LENGTH: int = 7
const ACTIVE_DAY_CYCLE_BONUS_JADE: int = 160
const ACTIVE_DAY_CYCLE_BONUS_SEALS: int = 4
const REWARDED_AD_MAX_PER_CYCLE: int = 3
const REWARDED_AD_SEALS: int = 1

## Progression milestones intentionally begin after the Pavilion unlock.
## Chapter 1 already has the one-time Initiate Gift of 10 Seals.
const PROGRESSION_MILESTONE_GRANTS: Dictionary = {
	"chapter_2_clear": {
		"chapter_id": 2,
		"stage_id": 5,
		"celestial_jade": 0,
		"pavilion_seal": 5
	},
	"chapter_3_clear": {
		"chapter_id": 3,
		"stage_id": 5,
		"celestial_jade": 500,
		"pavilion_seal": 0
	}
}

## Monthly Blessing is billing-ready but storefront-neutral. Purchase price,
## localized currency, receipt validation and subscription state belong to the
## future platform billing provider, never to this catalog.
const MONTHLY_BLESSING_DURATION_DAYS: int = 30
const MONTHLY_BLESSING_INITIAL_JADE: int = 150
const MONTHLY_BLESSING_DAILY_JADE: int = 30

## Deterministic acquisition policy. Common/Rare can still be bought with
## earned Spirit Stones; Epic/Legendary preserve summon value and use summon
## or deterministic Refinement Shard forging instead.
const DIRECT_STONE_RARITIES: Array[String] = ["common", "rare"]

const PRODUCT_TYPE_CONSUMABLE: String = "consumable"
const PRODUCT_TYPE_ONE_TIME_BUNDLE: String = "one_time_bundle"
const PRODUCT_TYPE_MONTHLY_BLESSING: String = "monthly_blessing"

## Grant amounts only. Localized money prices must come from Google Play / App
## Store billing. Nothing here can purchase or grant currency by itself.
const IAP_PRODUCTS: Dictionary = {
	"jade_pouch_100": {
		"type": PRODUCT_TYPE_CONSUMABLE,
		"celestial_jade": 100
	},
	"jade_satchel_550": {
		"type": PRODUCT_TYPE_CONSUMABLE,
		"celestial_jade": 550
	},
	"jade_casket_1200": {
		"type": PRODUCT_TYPE_CONSUMABLE,
		"celestial_jade": 1200
	},
	"jade_vault_2500": {
		"type": PRODUCT_TYPE_CONSUMABLE,
		"celestial_jade": 2500
	},
	"jade_treasury_6500": {
		"type": PRODUCT_TYPE_CONSUMABLE,
		"celestial_jade": 6500
	},
	"jade_ascendant_14000": {
		"type": PRODUCT_TYPE_CONSUMABLE,
		"celestial_jade": 14000
	},
	"starter_support_pack": {
		"type": PRODUCT_TYPE_ONE_TIME_BUNDLE,
		"celestial_jade": 100,
		"pavilion_seal": 3
	},
	"monthly_jade_blessing": {
		"type": PRODUCT_TYPE_MONTHLY_BLESSING,
		"initial_celestial_jade": MONTHLY_BLESSING_INITIAL_JADE,
		"daily_celestial_jade": MONTHLY_BLESSING_DAILY_JADE,
		"duration_days": MONTHLY_BLESSING_DURATION_DAYS
	}
}

static func is_valid() -> bool:
	var total_rate: int = 0
	for rarity: String in RARITY_ORDER:
		if not BASE_DROP_RATE_BP.has(rarity):
			return false
		var rate: int = int(BASE_DROP_RATE_BP[rarity])
		if rate < 0:
			return false
		total_rate += rate
	if total_rate != RATE_BASIS_POINTS:
		return false
	if int(PITY_LIMITS.get("rare_plus", 0)) <= 0:
		return false
	if int(PITY_LIMITS.get("epic_plus", 0)) <= 0:
		return false
	if int(PITY_LIMITS.get("legendary", 0)) <= 0:
		return false
	if NATURAL_LEGENDARY_WISH_CHANCE <= 0.0 or NATURAL_LEGENDARY_WISH_CHANCE > 1.0:
		return false
	if SINGLE_PULL_JADE_COST <= 0 or TEN_PULL_JADE_COST <= 0:
		return false
	if SINGLE_PULL_SEAL_COST <= 0 or TEN_PULL_SEAL_COST <= 0:
		return false
	if TEN_PULL_JADE_COST >= SINGLE_PULL_JADE_COST * TEN_PULL_COUNT:
		return false
	if DAILY_COMPLETION_JADE <= 0 or ACTIVE_DAY_CYCLE_LENGTH <= 0:
		return false
	if ACTIVE_DAY_CYCLE_BONUS_JADE <= 0 or ACTIVE_DAY_CYCLE_BONUS_SEALS <= 0:
		return false
	if REWARDED_AD_MAX_PER_CYCLE < 0 or REWARDED_AD_SEALS <= 0:
		return false
	if MONTHLY_BLESSING_DURATION_DAYS <= 0:
		return false
	if MONTHLY_BLESSING_INITIAL_JADE <= 0 or MONTHLY_BLESSING_DAILY_JADE <= 0:
		return false
	for milestone_id: String in PROGRESSION_MILESTONE_GRANTS.keys():
		var milestone: Dictionary = PROGRESSION_MILESTONE_GRANTS[milestone_id]
		if int(milestone.get("chapter_id", 0)) <= 0:
			return false
		if int(milestone.get("stage_id", 0)) <= 0:
			return false
		if (
			int(milestone.get(CURRENCY_CELESTIAL_JADE, 0)) <= 0
			and int(milestone.get(CURRENCY_PAVILION_SEAL, 0)) <= 0
		):
			return false
	for product_id: String in IAP_PRODUCTS.keys():
		var product: Dictionary = IAP_PRODUCTS[product_id]
		var product_type: String = str(product.get("type", ""))
		if product_type == PRODUCT_TYPE_CONSUMABLE:
			if int(product.get(CURRENCY_CELESTIAL_JADE, 0)) <= 0:
				return false
		elif product_type == PRODUCT_TYPE_ONE_TIME_BUNDLE:
			if (
				int(product.get(CURRENCY_CELESTIAL_JADE, 0)) <= 0
				and int(product.get(CURRENCY_PAVILION_SEAL, 0)) <= 0
			):
				return false
		elif product_type == PRODUCT_TYPE_MONTHLY_BLESSING:
			if int(product.get("initial_celestial_jade", 0)) <= 0:
				return false
			if int(product.get("daily_celestial_jade", 0)) <= 0:
				return false
			if int(product.get("duration_days", 0)) <= 0:
				return false
		else:
			return false
	return true

static func get_summon_cost(pull_count: int) -> Dictionary:
	if pull_count == TEN_PULL_COUNT:
		return {
			CURRENCY_CELESTIAL_JADE: TEN_PULL_JADE_COST,
			CURRENCY_PAVILION_SEAL: TEN_PULL_SEAL_COST
		}
	if pull_count == SINGLE_PULL_COUNT:
		return {
			CURRENCY_CELESTIAL_JADE: SINGLE_PULL_JADE_COST,
			CURRENCY_PAVILION_SEAL: SINGLE_PULL_SEAL_COST
		}
	return {}

static func get_base_drop_rates() -> Dictionary:
	return BASE_DROP_RATE_BP.duplicate(true)

static func get_pity_limits() -> Dictionary:
	return PITY_LIMITS.duplicate(true)

static func get_iap_products() -> Dictionary:
	return IAP_PRODUCTS.duplicate(true)

static func get_iap_product(product_id: String) -> Dictionary:
	if not IAP_PRODUCTS.has(product_id):
		return {}
	var product: Dictionary = IAP_PRODUCTS[product_id]
	return product.duplicate(true)

static func get_progression_milestone_grants() -> Dictionary:
	return PROGRESSION_MILESTONE_GRANTS.duplicate(true)

static func can_direct_buy_rarity(rarity: String) -> bool:
	return rarity in DIRECT_STONE_RARITIES

static func get_drop_rate_disclosure() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for rarity: String in RARITY_ORDER:
		entries.append({
			"rarity": rarity,
			"basis_points": int(BASE_DROP_RATE_BP[rarity]),
			"percent": float(BASE_DROP_RATE_BP[rarity]) / 100.0
		})
	return entries
