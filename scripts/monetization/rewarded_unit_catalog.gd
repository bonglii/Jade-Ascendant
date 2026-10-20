extends RefCounted

## One App ID; distinct rewarded inventory per purpose. Names are documentation,
## SDK IDs are supplied by the owner. No fallback to the legacy shared unit.
const REVISION: int = 1
const APP_ID: String = "ca-app-pub-3082528078187093~9576090733"
const TEST_UNIT: String = "ca-app-pub-3940256099942544/5224354917"
const UNITS: Dictionary = {
	"dice": {"name": "Rewarded_Event_Dice", "id": "ca-app-pub-3082528078187093/8339864838", "reward": "Dice"},
	"pavilion": {"name": "Rewarded_Pavilion_Pull", "id": "ca-app-pub-3082528078187093/2136559730", "reward": "PavilionSeal"},
	"revive": {"name": "Rewarded_Revive", "id": "ca-app-pub-3082528078187093/9686167686", "reward": "Revive"},
	"general": {"name": "Rewarded_General_Bonus", "id": "ca-app-pub-3082528078187093/9338683323", "reward": "Bonus"}
}
const PLACEMENTS: Dictionary = {
	"odyssey_roll": "dice",
	"pavilion_seal": "pavilion",
	"game_over_revive": "revive",
	"offline_cultivation_double": "general",
	"liveops_boss_hunt_double": "general",
	"liveops_treasure_hunt_double": "general"
}

static func unit_for(placement: String) -> String:
	return str(PLACEMENTS.get(placement, ""))

static func unit_id(unit: String, debug_build: bool) -> String:
	if not UNITS.has(unit): return ""
	return TEST_UNIT if debug_build else str(UNITS[unit].id)

static func release_configuration_valid(app_id: String, ids: Dictionary) -> bool:
	if app_id != APP_ID or ids.size() != UNITS.size(): return false
	var seen: Dictionary = {}
	var pattern := RegEx.new()
	if pattern.compile("^ca-app-pub-[0-9]{16}/[0-9]{10}$") != OK: return false
	for unit: String in UNITS:
		var value: String = str(ids.get(unit, ""))
		if pattern.search(value) == null or value == TEST_UNIT: return false
		if value.get_slice("/", 0) != app_id.get_slice("~", 0) or seen.has(value): return false
		seen[value] = true
	return true
