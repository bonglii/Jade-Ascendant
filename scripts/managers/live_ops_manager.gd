extends Node

## Home Live UI Phase 1
##
## Persistence strategy:
## - Reuses PavilionManager's permanent claimed_milestone_ids ledger with a
##   namespaced `liveops:` prefix.
## - Login activity/read flags are single-domain atomic writes.
## - Reward claims append their permanent claim marker to the Pavilion snapshot
##   passed into RewardManager, so reward + claim state commit atomically.
## - No new SaveManager domain or autoload is introduced.
##
## This intentionally keeps the first production pass small while remaining
## idempotent and safe across restarts.
signal live_ops_changed

const LiveOpsLocalization = preload(
	"res://scripts/liveops/live_ops_localization.gd"
)

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const ACTIVE_PREFIX: String = "liveops:new_player:active:"
const LOGIN_CLAIM_PREFIX: String = "liveops:new_player:claim:"
const MAIL_READ_PREFIX: String = "liveops:mail:read:"
const MAIL_CLAIM_PREFIX: String = "liveops:mail:claim:"

const LOGIN_DAY_COUNT: int = 7
const DATE_CHECK_INTERVAL: float = 20.0

const EVENT_ID_SEVEN_DAYS: String = "seven_days_of_ascension"
const EVENT_ID_JADE_VALLEY_PILGRIMAGE: String = "jade_valley_pilgrimage"
const EVENT_ID_CELESTIAL_BOSS_HUNT: String = "celestial_boss_hunt"
const EVENT_ID_HEAVENLY_LADDER: String = "heavenly_ladder"
const PILGRIMAGE_CLAIM_PREFIX: String = (
	"liveops:jade_valley_pilgrimage:claim:"
)
const BOSS_HUNT_CLAIM_PREFIX: String = "liveops:celestial_boss_hunt:claim:"
const HEAVENLY_LADDER_CLAIM_PREFIX: String = "liveops:heavenly_ladder:claim:"
const BOSS_HUNT_REWARDED_PLACEMENT: String = "liveops_boss_hunt_double"
const BOSS_HUNT_REWARDED_MULTIPLIER: int = 2

const EVENT_ORDER: Array[String] = [
	EVENT_ID_SEVEN_DAYS,
	EVENT_ID_JADE_VALLEY_PILGRIMAGE,
	EVENT_ID_CELESTIAL_BOSS_HUNT,
	EVENT_ID_HEAVENLY_LADDER,
]
const EVENT_CATALOG: Dictionary = {
	"seven_days_of_ascension": {
		"title": "SEVEN DAYS OF ASCENSION",
		"description": (
			"Continue your cultivation journey and collect the rewards "
			+ "you have earned."
		),
		"scene_path": "res://scenes/ui/new_player_event_screen.tscn",
		"featured": true,
		"active": true,
		"authority": "live_ops_manager",
		"reward_authority": "reward_manager",
		"progress_kind": "seven_day_login",
	},
	"jade_valley_pilgrimage": {
		"title": "JADE VALLEY PILGRIMAGE",
		"description": (
			"Clear key trials across Verdant Qi Valley and claim "
			+ "pilgrimage offerings."
		),
		"scene_path": (
			"res://scenes/ui/jade_valley_pilgrimage_screen.tscn"
		),
		"featured": false,
		"active": true,
		"authority": "live_ops_manager",
		"reward_authority": "reward_manager",
		"progress_kind": "journey_stage_milestones",
	},
	"celestial_boss_hunt": {
		"title": "CELESTIAL BOSS HUNT",
		"description": (
			"Defeat the sovereign at the end of each realm and claim "
			+ "one-time celestial bounties."
		),
		"scene_path": "res://scenes/ui/celestial_boss_hunt_screen.tscn",
		"featured": false,
		"active": true,
		"authority": "live_ops_manager",
		"reward_authority": "reward_manager",
		"progress_kind": "journey_chapter_final_bounties",
	},
	"heavenly_ladder": {
		"title": "HEAVENLY LADDER",
		"description": (
			"Clear stages across every realm and ascend the Heavenly Ladder "
			+ "for one-time rewards."
		),
		"scene_path": "res://scenes/ui/heavenly_ladder_screen.tscn",
		"featured": false,
		"active": true,
		"authority": "live_ops_manager",
		"reward_authority": "reward_manager",
		"progress_kind": "journey_total_clear_milestones",
	},
}

const PILGRIMAGE_MILESTONE_ORDER: Array[String] = [
	"bamboo_mist_passage",
	"storm_peak_oath",
	"sovereign_gate",
]
const PILGRIMAGE_MILESTONES: Dictionary = {
	"bamboo_mist_passage": {
		"title": "BAMBOO MIST PASSAGE",
		"description": "Clear Stage 1-2: Bamboo Mist Pass.",
		"chapter_id": 1,
		"stage_id": 2,
		"reward": {"spirit_stone": 75, "items": {}},
	},
	"storm_peak_oath": {
		"title": "STORM PEAK OATH",
		"description": "Clear Stage 1-4: Storm Peak Approach.",
		"chapter_id": 1,
		"stage_id": 4,
		"reward": {
			"spirit_stone": 125,
			"items": {"refinement_shard": 1},
		},
	},
	"sovereign_gate": {
		"title": "SOVEREIGN GATE",
		"description": (
			"Clear Stage 1-5: Sovereign's Celestial Gate."
		),
		"chapter_id": 1,
		"stage_id": 5,
		"reward": {
			"spirit_stone": 200,
			"items": {"refinement_shard": 2},
		},
	},
}

const BOSS_HUNT_MILESTONE_ORDER: Array[String] = [
	"verdant_sovereign",
	"crimson_moon_master",
	"star_palace_sovereign",
	"frostbound_sovereign",
	"primordial_sun_sovereign",
]
const BOSS_HUNT_MILESTONES: Dictionary = {
	"verdant_sovereign": {
		"title": "VERDANT SOVEREIGN BOUNTY",
		"description": "Clear Stage 1-5 and defeat the Jade Valley Sovereign.",
		"chapter_id": 1,
		"stage_id": 5,
		"reward": {"spirit_stone": 150, "items": {"refinement_shard": 1}},
	},
	"crimson_moon_master": {
		"title": "CRIMSON MOON BOUNTY",
		"description": "Clear Stage 2-5 and defeat the Crimson Moon Sect Master.",
		"chapter_id": 2,
		"stage_id": 5,
		"reward": {"spirit_stone": 250, "items": {"refinement_shard": 2}},
	},
	"star_palace_sovereign": {
		"title": "STAR PALACE BOUNTY",
		"description": "Clear Stage 3-5 and defeat the Star Palace Celestial Sovereign.",
		"chapter_id": 3,
		"stage_id": 5,
		"reward": {"spirit_stone": 400, "items": {"refinement_shard": 3}},
	},
	"frostbound_sovereign": {
		"title": "FROSTBOUND BOUNTY",
		"description": "Clear Stage 4-5 and defeat the Frostbound Sovereign.",
		"chapter_id": 4,
		"stage_id": 5,
		"reward": {"spirit_stone": 600, "items": {"refinement_shard": 4}},
	},
	"primordial_sun_sovereign": {
		"title": "PRIMORDIAL SUN BOUNTY",
		"description": "Clear Stage 5-5 and defeat the Primordial Sun Sovereign.",
		"chapter_id": 5,
		"stage_id": 5,
		"reward": {"spirit_stone": 900, "items": {"refinement_shard": 5}},
	},
}
const HEAVENLY_LADDER_MILESTONE_ORDER: Array[String] = [
	"first_ascent",
	"cloud_step",
	"jade_stair",
	"starward_step",
	"heaven_gate",
	"celestial_arch",
	"sovereign_height",
	"ascendant_summit",
]
const HEAVENLY_LADDER_MILESTONES: Dictionary = {
	"first_ascent": {
		"title": "FIRST ASCENT",
		"required_clears": 3,
		"reward": {"spirit_stone": 60, "items": {}},
	},
	"cloud_step": {
		"title": "CLOUD STEP",
		"required_clears": 6,
		"reward": {"spirit_stone": 100, "items": {"refinement_shard": 1}},
	},
	"jade_stair": {
		"title": "JADE STAIR",
		"required_clears": 9,
		"reward": {"spirit_stone": 140, "items": {"refinement_shard": 1}},
	},
	"starward_step": {
		"title": "STARWARD STEP",
		"required_clears": 12,
		"reward": {"spirit_stone": 200, "items": {"refinement_shard": 2}},
	},
	"heaven_gate": {
		"title": "HEAVEN GATE",
		"required_clears": 15,
		"reward": {"spirit_stone": 260, "items": {"refinement_shard": 2}},
	},
	"celestial_arch": {
		"title": "CELESTIAL ARCH",
		"required_clears": 18,
		"reward": {"spirit_stone": 340, "items": {"refinement_shard": 3}},
	},
	"sovereign_height": {
		"title": "SOVEREIGN HEIGHT",
		"required_clears": 22,
		"reward": {"spirit_stone": 450, "items": {"refinement_shard": 4}},
	},
	"ascendant_summit": {
		"title": "ASCENDANT SUMMIT",
		"required_clears": 26,
		"reward": {"spirit_stone": 600, "items": {"refinement_shard": 5}},
	},
}

const LOGIN_REWARDS: Dictionary = {
	1: {"spirit_stone": 100, "items": {}},
	2: {"spirit_stone": 150, "items": {"refinement_shard": 2}},
	3: {"spirit_stone": 200, "items": {"refinement_shard": 3}},
	4: {"spirit_stone": 250, "items": {"refinement_shard": 5}},
	5: {"spirit_stone": 300, "items": {"refinement_shard": 7}},
	6: {"spirit_stone": 400, "items": {"refinement_shard": 10}},
	7: {"spirit_stone": 600, "items": {"refinement_shard": 20}},
}

const MAIL_ORDER: Array[String] = [
	"welcome_initiate",
	"celestial_path_notice",
]

const MAIL_CATALOG: Dictionary = {
	"welcome_initiate": {
		"sender": "JADE SANCTUARY",
		"title": "Welcome, Wandering Cultivator",
		"body": (
			"Your first steps on the immortal path have begun. "
			+ "Accept these supplies and prepare for the trials ahead."
		),
		"reward": {
			"spirit_stone": 150,
			"items": {"refinement_shard": 3},
		},
	},
	"celestial_path_notice": {
		"sender": "CELESTIAL PAVILION",
		"title": "Seven Days of Ascension",
		"body": (
			"Return on seven active days to unlock newcomer supplies. "
			+ "Missed calendar days do not erase your progress."
		),
		"reward": {},
	},
}

var _active_live_popup: Control = null
var _active_live_popup_scene: String = ""
var _date_check_elapsed: float = 0.0
var _last_date_key: String = ""
var _boss_hunt_pending_milestone: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	LiveOpsLocalization.install()
	_last_date_key = _get_current_date_key()
	_record_current_active_day()
	_audit_event_catalog()
	_audit_reward_catalog()
	var verified_callback := Callable(
		self,
		"_on_boss_hunt_verified_rewarded_completed"
	)
	if not MonetizationManager.verified_rewarded_completed.is_connected(verified_callback):
		MonetizationManager.verified_rewarded_completed.connect(verified_callback)
	var finished_callback := Callable(
		self,
		"_on_boss_hunt_rewarded_request_finished"
	)
	if not MonetizationManager.rewarded_request_finished.is_connected(finished_callback):
		MonetizationManager.rewarded_request_finished.connect(finished_callback)
	DebugLogger.system(str(
		"LiveOps Phase 1 aktif | Active day: ",
		get_active_login_day_count(),
		"/",
		LOGIN_DAY_COUNT
	))


func _process(delta: float) -> void:
	_date_check_elapsed += delta
	if _date_check_elapsed < DATE_CHECK_INTERVAL:
		return
	_date_check_elapsed = 0.0

	var current_date: String = _get_current_date_key()
	if current_date == _last_date_key:
		return
	_last_date_key = current_date
	_record_current_active_day()


func _audit_event_catalog() -> void:
	var event_ids: Array[String] = get_event_ids()
	if event_ids.size() != EVENT_ORDER.size():
		push_error(
			"LiveOpsManager: event order contains duplicate or unknown IDs."
		)
	if event_ids.size() != EVENT_CATALOG.size():
		push_error(
			"LiveOpsManager: event catalog/order coverage is incomplete."
		)

	var featured_count: int = 0
	for event_id: String in event_ids:
		var event: Dictionary = get_event(event_id)
		var title: String = str(event.get("title", "")).strip_edges()
		var description: String = str(
			event.get("description", "")
		).strip_edges()
		var scene_path: String = str(
			event.get("scene_path", "")
		).strip_edges()
		var authority: String = str(
			event.get("authority", "")
		).strip_edges()
		var reward_authority: String = str(
			event.get("reward_authority", "")
		).strip_edges()
		var progress_kind: String = str(
			event.get("progress_kind", "")
		).strip_edges()

		if (
			title.is_empty()
			or description.is_empty()
			or scene_path.is_empty()
			or progress_kind.is_empty()
		):
			push_error(
				"LiveOpsManager: event metadata incomplete for " + event_id
			)
		if (
			authority != "live_ops_manager"
			or reward_authority != "reward_manager"
		):
			push_error(
				"LiveOpsManager: event authority boundary invalid for "
				+ event_id
			)
		if event.has("reward") or event.has("rewards"):
			push_error(
				"LiveOpsManager: event catalog must remain metadata-only: "
				+ event_id
			)
		if (
			not scene_path.begins_with("res://")
			or not ResourceLoader.exists(scene_path, "PackedScene")
		):
			push_error(
				"LiveOpsManager: event scene is unavailable for " + event_id
			)
		if bool(event.get("featured", false)):
			featured_count += 1

	if featured_count != 1:
		push_error(
			"LiveOpsManager: exactly one featured event is required."
		)


func get_event_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_event_id: String in EVENT_ORDER:
		var event_id: String = raw_event_id.strip_edges()
		if (
			event_id.is_empty()
			or event_id in result
			or not EVENT_CATALOG.has(event_id)
		):
			continue
		result.append(event_id)
	return result


func has_event(event_id: String) -> bool:
	return EVENT_CATALOG.has(event_id)


func get_event(event_id: String) -> Dictionary:
	if not has_event(event_id):
		return {}
	var catalog_event: Dictionary = EVENT_CATALOG[event_id]
	var event: Dictionary = catalog_event.duplicate(true)
	event["id"] = event_id
	return event


func get_active_event_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event_id: String in get_event_ids():
		var event: Dictionary = get_event(event_id)
		if event.is_empty() or not bool(event.get("active", false)):
			continue
		result.append(event)
	return result


func get_featured_event() -> Dictionary:
	for event: Dictionary in get_active_event_entries():
		if bool(event.get("featured", false)):
			return event.duplicate(true)
	return {}


func _audit_reward_catalog() -> void:
	for day: int in range(1, LOGIN_DAY_COUNT + 1):
		var reward: Dictionary = get_login_reward(day)
		if not RewardManager.is_valid_reward(
			RewardManager.SOURCE_PAVILION,
			"live_ops_login_day_%d" % day,
			reward
		):
			push_error(
				"LiveOpsManager: invalid login reward catalog day "
				+ str(day)
			)

	for milestone_id: String in get_pilgrimage_milestone_ids():
		var milestone: Dictionary = get_pilgrimage_milestone(
			milestone_id
		)
		var reward: Dictionary = milestone.get("reward", {})
		if not RewardManager.is_valid_reward(
			RewardManager.SOURCE_PAVILION,
			"live_ops_jade_valley_pilgrimage_" + milestone_id,
			reward
		):
			push_error(
				"LiveOpsManager: invalid pilgrimage reward "
				+ milestone_id
			)

	for milestone_id: String in get_boss_hunt_milestone_ids():
		var milestone: Dictionary = get_boss_hunt_milestone(milestone_id)
		var reward: Dictionary = milestone.get("reward", {})
		var doubled_reward: Dictionary = _multiply_reward(
			reward,
			BOSS_HUNT_REWARDED_MULTIPLIER
		)
		if not RewardManager.is_valid_reward(
			RewardManager.SOURCE_PAVILION,
			"live_ops_celestial_boss_hunt_" + milestone_id + "_normal",
			reward
		):
			push_error("LiveOpsManager: invalid Boss Hunt reward " + milestone_id)
		if not RewardManager.is_valid_reward(
			RewardManager.SOURCE_PAVILION,
			"live_ops_celestial_boss_hunt_" + milestone_id + "_rewarded_audit",
			doubled_reward
		):
			push_error("LiveOpsManager: invalid doubled Boss Hunt reward " + milestone_id)
	for milestone_id: String in get_heavenly_ladder_milestone_ids():
		var milestone: Dictionary = get_heavenly_ladder_milestone(milestone_id)
		var reward: Dictionary = milestone.get("reward", {})
		if not RewardManager.is_valid_reward(
			RewardManager.SOURCE_PAVILION,
			"live_ops_heavenly_ladder_" + milestone_id,
			reward
		):
			push_error(
				"LiveOpsManager: invalid Heavenly Ladder reward " + milestone_id
			)

	var mail_ids: Array[String] = get_mail_ids()
	if mail_ids.size() != MAIL_ORDER.size():
		push_error(
			"LiveOpsManager: mailbox order contains duplicate or unknown IDs."
		)
	if mail_ids.size() != MAIL_CATALOG.size():
		push_error(
			"LiveOpsManager: mailbox catalog/order coverage is incomplete."
		)

	for mail_id: String in mail_ids:
		var mail: Dictionary = get_mail(mail_id)
		var reward: Dictionary = mail.get("reward", {})
		if reward.is_empty():
			continue
		if not RewardManager.is_valid_reward(
			RewardManager.SOURCE_PAVILION,
			"live_ops_mail_" + mail_id,
			reward
		):
			push_error(
				"LiveOpsManager: invalid mailbox reward " + mail_id
			)


func _get_current_date_key() -> String:
	if DailyQuestManager != null and DailyQuestManager.has_method(
		"get_current_date_key"
	):
		return str(DailyQuestManager.get_current_date_key())
	return Time.get_date_string_from_system()


func _get_ledger() -> Array[String]:
	var result: Array[String] = []
	var raw_ledger: Variant = PavilionManager.state.get(
		"claimed_milestone_ids",
		[]
	)
	if raw_ledger is Array:
		for raw_entry: Variant in raw_ledger:
			var entry: String = str(raw_entry)
			if entry.is_empty() or entry in result:
				continue
			result.append(entry)
	return result


func _build_pavilion_snapshot(ledger: Array[String]) -> Dictionary:
	var next_state: Dictionary = PavilionManager.state.duplicate(true)
	next_state["version"] = 1
	next_state["claimed_milestone_ids"] = ledger.duplicate()
	return next_state


func _apply_pavilion_snapshot(next_state: Dictionary) -> void:
	PavilionManager.state = next_state.duplicate(true)
	PavilionManager.pavilion_changed.emit()
	live_ops_changed.emit()


func _commit_ledger(ledger: Array[String]) -> bool:
	if SaveManager.is_progress_read_only():
		return false
	var next_state: Dictionary = _build_pavilion_snapshot(ledger)
	var result: Dictionary = SaveManager.write_save_data(
		"pavilion",
		next_state
	)
	if not bool(result.get("success", false)):
		return false
	_apply_pavilion_snapshot(next_state)
	return true


func _is_valid_date_key(date_key: String) -> bool:
	var value: String = date_key.strip_edges()
	if (
		value.length() != 10
		or value.substr(4, 1) != "-"
		or value.substr(7, 1) != "-"
	):
		return false

	var year_text: String = value.substr(0, 4)
	var month_text: String = value.substr(5, 2)
	var day_text: String = value.substr(8, 2)
	for numeric_part: String in [year_text, month_text, day_text]:
		for index: int in range(numeric_part.length()):
			var code: int = numeric_part.unicode_at(index)
			if code < 48 or code > 57:
				return false

	var year: int = int(year_text)
	var month: int = int(month_text)
	var day: int = int(day_text)
	if year < 1970 or month < 1 or month > 12 or day < 1:
		return false

	var max_day: int = 31
	match month:
		4, 6, 9, 11:
			max_day = 30
		2:
			var leap_year: bool = (
				year % 400 == 0
				or (year % 4 == 0 and year % 100 != 0)
			)
			max_day = 29 if leap_year else 28
	return day <= max_day


func _get_latest_active_date_key() -> String:
	var latest: String = ""
	for entry: String in _get_ledger():
		if not entry.begins_with(ACTIVE_PREFIX):
			continue
		var date_key: String = entry.trim_prefix(ACTIVE_PREFIX)
		if not _is_valid_date_key(date_key):
			continue
		if latest.is_empty() or date_key.casecmp_to(latest) > 0:
			latest = date_key
	return latest


func _record_active_date(date_key: String) -> bool:
	if get_active_login_day_count() >= LOGIN_DAY_COUNT:
		return false

	var current_date: String = date_key.strip_edges()
	if not _is_valid_date_key(current_date):
		return false

	# Offline v1 intentionally uses the local calendar, but progress itself is
	# monotonic: duplicate/backward dates cannot manufacture additional days.
	var latest: String = _get_latest_active_date_key()
	if not latest.is_empty() and current_date.casecmp_to(latest) <= 0:
		return false

	var marker: String = ACTIVE_PREFIX + current_date
	var ledger: Array[String] = _get_ledger()
	if marker in ledger:
		return false

	ledger.append(marker)
	if not _commit_ledger(ledger):
		return false

	DebugLogger.system(str(
		"LiveOps active login recorded | Day ",
		get_active_login_day_count(),
		" | ",
		current_date
	))
	return true


func _record_current_active_day() -> bool:
	return _record_active_date(_get_current_date_key())


func get_active_login_day_count() -> int:
	var seen_dates: Dictionary = {}
	for entry: String in _get_ledger():
		if not entry.begins_with(ACTIVE_PREFIX):
			continue
		var date_key: String = entry.trim_prefix(ACTIVE_PREFIX)
		if not _is_valid_date_key(date_key) or seen_dates.has(date_key):
			continue
		seen_dates[date_key] = true
	return clampi(seen_dates.size(), 0, LOGIN_DAY_COUNT)


func get_login_reward(day: int) -> Dictionary:
	if not LOGIN_REWARDS.has(day):
		return {}
	var reward: Dictionary = LOGIN_REWARDS[day]
	return reward.duplicate(true)


func is_login_day_unlocked(day: int) -> bool:
	return (
		day >= 1
		and day <= LOGIN_DAY_COUNT
		and day <= get_active_login_day_count()
	)


func is_login_day_claimed(day: int) -> bool:
	if day < 1 or day > LOGIN_DAY_COUNT:
		return false
	return LOGIN_CLAIM_PREFIX + str(day) in _get_ledger()


func get_login_claimable_count() -> int:
	var count: int = 0
	for day: int in range(1, LOGIN_DAY_COUNT + 1):
		if is_login_day_unlocked(day) and not is_login_day_claimed(day):
			count += 1
	return count


func is_new_player_event_complete() -> bool:
	for day: int in range(1, LOGIN_DAY_COUNT + 1):
		if not is_login_day_claimed(day):
			return false
	return true


func claim_login_day(day: int) -> bool:
	if (
		not is_login_day_unlocked(day)
		or is_login_day_claimed(day)
		or SaveManager.is_progress_read_only()
	):
		return false

	var reward: Dictionary = get_login_reward(day)
	if reward.is_empty():
		return false

	var ledger: Array[String] = _get_ledger()
	var claim_marker: String = LOGIN_CLAIM_PREFIX + str(day)
	ledger.append(claim_marker)
	var next_pavilion: Dictionary = _build_pavilion_snapshot(ledger)

	var result: Dictionary = RewardManager.grant_reward(
		RewardManager.SOURCE_PAVILION,
		"live_ops_login_day_%d" % day,
		reward,
		{"pavilion": next_pavilion}
	)
	if not bool(result.get("success", false)):
		return false

	_apply_pavilion_snapshot(next_pavilion)
	return true


func get_pilgrimage_milestone_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id: String in PILGRIMAGE_MILESTONE_ORDER:
		var milestone_id: String = raw_id.strip_edges()
		if (
			milestone_id.is_empty()
			or milestone_id in result
			or not PILGRIMAGE_MILESTONES.has(milestone_id)
		):
			continue
		result.append(milestone_id)
	return result


func get_pilgrimage_milestone(
	milestone_id: String
) -> Dictionary:
	if not PILGRIMAGE_MILESTONES.has(milestone_id):
		return {}
	var catalog_entry: Dictionary = PILGRIMAGE_MILESTONES[
		milestone_id
	]
	var milestone: Dictionary = catalog_entry.duplicate(true)
	milestone["id"] = milestone_id
	milestone["unlocked"] = is_pilgrimage_milestone_unlocked(
		milestone_id
	)
	milestone["claimed"] = is_pilgrimage_milestone_claimed(
		milestone_id
	)
	return milestone


func is_pilgrimage_milestone_unlocked(
	milestone_id: String
) -> bool:
	if not PILGRIMAGE_MILESTONES.has(milestone_id):
		return false
	var milestone: Dictionary = PILGRIMAGE_MILESTONES[
		milestone_id
	]
	return JourneyManager.is_stage_cleared(
		int(milestone.get("chapter_id", 0)),
		int(milestone.get("stage_id", 0))
	)


func is_pilgrimage_milestone_claimed(
	milestone_id: String
) -> bool:
	if not PILGRIMAGE_MILESTONES.has(milestone_id):
		return false
	return (
		PILGRIMAGE_CLAIM_PREFIX + milestone_id
	) in _get_ledger()


func get_pilgrimage_unlocked_count() -> int:
	var count: int = 0
	for milestone_id: String in get_pilgrimage_milestone_ids():
		if is_pilgrimage_milestone_unlocked(milestone_id):
			count += 1
	return count


func get_pilgrimage_claimed_count() -> int:
	var count: int = 0
	for milestone_id: String in get_pilgrimage_milestone_ids():
		if is_pilgrimage_milestone_claimed(milestone_id):
			count += 1
	return count


func get_pilgrimage_claimable_count() -> int:
	var count: int = 0
	for milestone_id: String in get_pilgrimage_milestone_ids():
		if (
			is_pilgrimage_milestone_unlocked(milestone_id)
			and not is_pilgrimage_milestone_claimed(milestone_id)
		):
			count += 1
	return count


func is_pilgrimage_complete() -> bool:
	var milestone_ids: Array[String] = (
		get_pilgrimage_milestone_ids()
	)
	return (
		not milestone_ids.is_empty()
		and get_pilgrimage_claimed_count() == milestone_ids.size()
	)


func claim_pilgrimage_milestone(
	milestone_id: String
) -> bool:
	if (
		not PILGRIMAGE_MILESTONES.has(milestone_id)
		or not is_pilgrimage_milestone_unlocked(milestone_id)
		or is_pilgrimage_milestone_claimed(milestone_id)
		or SaveManager.is_progress_read_only()
	):
		return false

	var milestone: Dictionary = PILGRIMAGE_MILESTONES[
		milestone_id
	]
	var reward: Dictionary = milestone.get(
		"reward",
		{}
	).duplicate(true)
	if reward.is_empty():
		return false

	var ledger: Array[String] = _get_ledger()
	var claim_marker: String = (
		PILGRIMAGE_CLAIM_PREFIX + milestone_id
	)
	ledger.append(claim_marker)
	var next_pavilion: Dictionary = _build_pavilion_snapshot(
		ledger
	)

	var result: Dictionary = RewardManager.grant_reward(
		RewardManager.SOURCE_PAVILION,
		"live_ops_jade_valley_pilgrimage_" + milestone_id,
		reward,
		{"pavilion": next_pavilion}
	)
	if not bool(result.get("success", false)):
		return false

	_apply_pavilion_snapshot(next_pavilion)
	return true



func get_boss_hunt_milestone_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id: String in BOSS_HUNT_MILESTONE_ORDER:
		var milestone_id: String = raw_id.strip_edges()
		if (
			milestone_id.is_empty()
			or milestone_id in result
			or not BOSS_HUNT_MILESTONES.has(milestone_id)
		):
			continue
		result.append(milestone_id)
	return result


func get_boss_hunt_milestone(milestone_id: String) -> Dictionary:
	if not BOSS_HUNT_MILESTONES.has(milestone_id):
		return {}
	var milestone: Dictionary = (
		BOSS_HUNT_MILESTONES[milestone_id] as Dictionary
	).duplicate(true)
	milestone["id"] = milestone_id
	milestone["unlocked"] = is_boss_hunt_milestone_unlocked(milestone_id)
	milestone["claimed"] = is_boss_hunt_milestone_claimed(milestone_id)
	return milestone


func is_boss_hunt_milestone_unlocked(milestone_id: String) -> bool:
	if not BOSS_HUNT_MILESTONES.has(milestone_id):
		return false
	var milestone: Dictionary = BOSS_HUNT_MILESTONES[milestone_id]
	return JourneyManager.is_stage_cleared(
		int(milestone.get("chapter_id", 0)),
		int(milestone.get("stage_id", 0))
	)


func is_boss_hunt_milestone_claimed(milestone_id: String) -> bool:
	if not BOSS_HUNT_MILESTONES.has(milestone_id):
		return false
	return BOSS_HUNT_CLAIM_PREFIX + milestone_id in _get_ledger()


func get_boss_hunt_unlocked_count() -> int:
	var count: int = 0
	for milestone_id: String in get_boss_hunt_milestone_ids():
		if is_boss_hunt_milestone_unlocked(milestone_id):
			count += 1
	return count


func get_boss_hunt_claimed_count() -> int:
	var count: int = 0
	for milestone_id: String in get_boss_hunt_milestone_ids():
		if is_boss_hunt_milestone_claimed(milestone_id):
			count += 1
	return count


func get_boss_hunt_claimable_count() -> int:
	var count: int = 0
	for milestone_id: String in get_boss_hunt_milestone_ids():
		if (
			is_boss_hunt_milestone_unlocked(milestone_id)
			and not is_boss_hunt_milestone_claimed(milestone_id)
		):
			count += 1
	return count


func get_boss_hunt_pending_milestone() -> String:
	return _boss_hunt_pending_milestone


func get_boss_hunt_rewarded_policy_status() -> Dictionary:
	var policy: Dictionary = MonetizationManager.get_rewarded_policy_status(
		BOSS_HUNT_REWARDED_PLACEMENT
	)
	policy["pending_milestone_id"] = _boss_hunt_pending_milestone
	return policy


func is_boss_hunt_double_available(milestone_id: String) -> bool:
	return (
		BOSS_HUNT_MILESTONES.has(milestone_id)
		and is_boss_hunt_milestone_unlocked(milestone_id)
		and not is_boss_hunt_milestone_claimed(milestone_id)
		and not SaveManager.is_progress_read_only()
		and _boss_hunt_pending_milestone.is_empty()
		and MonetizationManager.rewarded_available(BOSS_HUNT_REWARDED_PLACEMENT)
	)


func _multiply_reward(reward: Dictionary, multiplier: int) -> Dictionary:
	var factor: int = maxi(multiplier, 1)
	var items: Dictionary = {}
	var raw_items: Variant = reward.get("items", {})
	if raw_items is Dictionary:
		for raw_item_id: Variant in (raw_items as Dictionary).keys():
			var item_id: String = str(raw_item_id)
			var amount: int = int((raw_items as Dictionary).get(raw_item_id, 0))
			if not item_id.is_empty() and amount > 0:
				items[item_id] = amount * factor
	return RewardManager.create_reward_data(
		int(reward.get("spirit_stone", 0)) * factor,
		items,
		int(reward.get("hero_exp", 0)) * factor
	)


func _grant_boss_hunt_reward(
	milestone_id: String,
	reward: Dictionary,
	source_suffix: String
) -> Dictionary:
	if (
		not BOSS_HUNT_MILESTONES.has(milestone_id)
		or not is_boss_hunt_milestone_unlocked(milestone_id)
		or is_boss_hunt_milestone_claimed(milestone_id)
		or SaveManager.is_progress_read_only()
	):
		return {"success": false, "error": "Boss bounty is not claimable."}
	var ledger: Array[String] = _get_ledger()
	ledger.append(BOSS_HUNT_CLAIM_PREFIX + milestone_id)
	var next_pavilion: Dictionary = _build_pavilion_snapshot(ledger)
	var result: Dictionary = RewardManager.grant_reward(
		RewardManager.SOURCE_PAVILION,
		"live_ops_celestial_boss_hunt_" + milestone_id + "_" + source_suffix,
		reward,
		{"pavilion": next_pavilion}
	)
	if not bool(result.get("success", false)):
		return result
	_apply_pavilion_snapshot(next_pavilion)
	return result


func claim_boss_hunt_milestone(milestone_id: String) -> bool:
	if not _boss_hunt_pending_milestone.is_empty():
		return false
	var milestone: Dictionary = get_boss_hunt_milestone(milestone_id)
	if milestone.is_empty():
		return false
	var result: Dictionary = _grant_boss_hunt_reward(
		milestone_id,
		(milestone.get("reward", {}) as Dictionary).duplicate(true),
		"normal"
	)
	return bool(result.get("success", false))


func request_boss_hunt_double_claim(milestone_id: String) -> bool:
	if not is_boss_hunt_double_available(milestone_id):
		return false
	_boss_hunt_pending_milestone = milestone_id
	if not MonetizationManager.show_rewarded(BOSS_HUNT_REWARDED_PLACEMENT):
		_boss_hunt_pending_milestone = ""
		live_ops_changed.emit()
		return false
	live_ops_changed.emit()
	return true


func _on_boss_hunt_verified_rewarded_completed(
	placement: String,
	grant_id: String
) -> void:
	if placement != BOSS_HUNT_REWARDED_PLACEMENT:
		return
	var milestone_id: String = _boss_hunt_pending_milestone
	_boss_hunt_pending_milestone = ""
	if milestone_id.is_empty():
		MonetizationManager.publish_reward_delivery_result(
			placement, false, 0, "No pending boss bounty."
		)
		live_ops_changed.emit()
		return
	var milestone: Dictionary = get_boss_hunt_milestone(milestone_id)
	var doubled_reward: Dictionary = _multiply_reward(
		milestone.get("reward", {}),
		BOSS_HUNT_REWARDED_MULTIPLIER
	)
	var result: Dictionary = _grant_boss_hunt_reward(
		milestone_id,
		doubled_reward,
		"rewarded_" + grant_id
	)
	var granted: bool = bool(result.get("success", false))
	var message: String = (
		RewardManager.get_reward_summary(doubled_reward, "Reward claimed.")
		if granted
		else str(result.get("error", "Boss bounty delivery failed."))
	)
	MonetizationManager.publish_reward_delivery_result(
		placement,
		granted,
		int(doubled_reward.get("spirit_stone", 0)) if granted else 0,
		message
	)
	live_ops_changed.emit()


func _on_boss_hunt_rewarded_request_finished(
	placement: String,
	_status: String
) -> void:
	if placement != BOSS_HUNT_REWARDED_PLACEMENT:
		return
	if not _boss_hunt_pending_milestone.is_empty():
		_boss_hunt_pending_milestone = ""
		live_ops_changed.emit()


func get_heavenly_ladder_milestone_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id: String in HEAVENLY_LADDER_MILESTONE_ORDER:
		var milestone_id: String = raw_id.strip_edges()
		if (
			milestone_id.is_empty()
			or milestone_id in result
			or not HEAVENLY_LADDER_MILESTONES.has(milestone_id)
		):
			continue
		result.append(milestone_id)
	return result


func get_heavenly_ladder_total_stage_count() -> int:
	var total: int = 0
	for chapter_id: int in JourneyManager.get_chapter_ids():
		total += JourneyManager.get_stage_ids(chapter_id).size()
	return total


func get_heavenly_ladder_cleared_stage_count() -> int:
	var cleared: int = 0
	for chapter_id: int in JourneyManager.get_chapter_ids():
		for stage_id: int in JourneyManager.get_stage_ids(chapter_id):
			if JourneyManager.is_stage_cleared(chapter_id, stage_id):
				cleared += 1
	return cleared


func get_heavenly_ladder_milestone(milestone_id: String) -> Dictionary:
	if not HEAVENLY_LADDER_MILESTONES.has(milestone_id):
		return {}
	var milestone: Dictionary = (
		HEAVENLY_LADDER_MILESTONES[milestone_id] as Dictionary
	).duplicate(true)
	milestone["id"] = milestone_id
	milestone["unlocked"] = is_heavenly_ladder_milestone_unlocked(milestone_id)
	milestone["claimed"] = is_heavenly_ladder_milestone_claimed(milestone_id)
	return milestone


func is_heavenly_ladder_milestone_unlocked(milestone_id: String) -> bool:
	if not HEAVENLY_LADDER_MILESTONES.has(milestone_id):
		return false
	var milestone: Dictionary = HEAVENLY_LADDER_MILESTONES[milestone_id]
	return get_heavenly_ladder_cleared_stage_count() >= int(
		milestone.get("required_clears", 0)
	)


func is_heavenly_ladder_milestone_claimed(milestone_id: String) -> bool:
	if not HEAVENLY_LADDER_MILESTONES.has(milestone_id):
		return false
	return HEAVENLY_LADDER_CLAIM_PREFIX + milestone_id in _get_ledger()


func get_heavenly_ladder_claimed_count() -> int:
	var count: int = 0
	for milestone_id: String in get_heavenly_ladder_milestone_ids():
		if is_heavenly_ladder_milestone_claimed(milestone_id):
			count += 1
	return count


func get_heavenly_ladder_claimable_count() -> int:
	var count: int = 0
	for milestone_id: String in get_heavenly_ladder_milestone_ids():
		if (
			is_heavenly_ladder_milestone_unlocked(milestone_id)
			and not is_heavenly_ladder_milestone_claimed(milestone_id)
		):
			count += 1
	return count


func is_heavenly_ladder_complete() -> bool:
	var milestone_ids: Array[String] = get_heavenly_ladder_milestone_ids()
	return (
		not milestone_ids.is_empty()
		and get_heavenly_ladder_claimed_count() == milestone_ids.size()
	)


func claim_heavenly_ladder_milestone(milestone_id: String) -> bool:
	if (
		not HEAVENLY_LADDER_MILESTONES.has(milestone_id)
		or not is_heavenly_ladder_milestone_unlocked(milestone_id)
		or is_heavenly_ladder_milestone_claimed(milestone_id)
		or SaveManager.is_progress_read_only()
	):
		return false

	var milestone: Dictionary = HEAVENLY_LADDER_MILESTONES[milestone_id]
	var reward: Dictionary = milestone.get("reward", {}).duplicate(true)
	if reward.is_empty():
		return false

	var ledger: Array[String] = _get_ledger()
	ledger.append(HEAVENLY_LADDER_CLAIM_PREFIX + milestone_id)
	var next_pavilion: Dictionary = _build_pavilion_snapshot(ledger)
	var result: Dictionary = RewardManager.grant_reward(
		RewardManager.SOURCE_PAVILION,
		"live_ops_heavenly_ladder_" + milestone_id,
		reward,
		{"pavilion": next_pavilion}
	)
	if not bool(result.get("success", false)):
		return false

	_apply_pavilion_snapshot(next_pavilion)
	return true


func get_mail_ids() -> Array[String]:
	var result: Array[String] = []
	for mail_id: String in MAIL_ORDER:
		var normalized: String = mail_id.strip_edges()
		if (
			normalized.is_empty()
			or normalized in result
			or not MAIL_CATALOG.has(normalized)
		):
			continue
		result.append(normalized)
	return result


func get_mail(mail_id: String) -> Dictionary:
	if not MAIL_CATALOG.has(mail_id):
		return {}
	var catalog_mail: Dictionary = MAIL_CATALOG[mail_id]
	var mail: Dictionary = catalog_mail.duplicate(true)
	mail["id"] = mail_id
	mail["read"] = is_mail_read(mail_id)
	mail["claimed"] = is_mail_claimed(mail_id)
	return mail


func get_mail_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for mail_id: String in get_mail_ids():
		var mail: Dictionary = get_mail(mail_id)
		if not mail.is_empty():
			entries.append(mail)
	return entries


func is_mail_read(mail_id: String) -> bool:
	if not MAIL_CATALOG.has(mail_id):
		return false
	return MAIL_READ_PREFIX + mail_id in _get_ledger()


func is_mail_claimed(mail_id: String) -> bool:
	if not MAIL_CATALOG.has(mail_id):
		return false
	var mail: Dictionary = MAIL_CATALOG[mail_id]
	var reward: Dictionary = mail.get("reward", {})
	if reward.is_empty():
		return true
	return MAIL_CLAIM_PREFIX + mail_id in _get_ledger()


func get_mail_unread_count() -> int:
	var count: int = 0
	for mail_id: String in get_mail_ids():
		if not is_mail_read(mail_id):
			count += 1
	return count


func get_mail_claimable_count() -> int:
	var count: int = 0
	for mail_id: String in get_mail_ids():
		var mail: Dictionary = MAIL_CATALOG.get(mail_id, {})
		var reward: Dictionary = mail.get("reward", {})
		if not reward.is_empty() and not is_mail_claimed(mail_id):
			count += 1
	return count


func mark_all_mail_read() -> bool:
	var ledger: Array[String] = _get_ledger()
	var changed: bool = false
	for mail_id: String in get_mail_ids():
		var marker: String = MAIL_READ_PREFIX + mail_id
		if marker in ledger:
			continue
		ledger.append(marker)
		changed = true
	if not changed:
		return true
	return _commit_ledger(ledger)


func claim_mail(mail_id: String) -> bool:
	if (
		not MAIL_CATALOG.has(mail_id)
		or is_mail_claimed(mail_id)
		or SaveManager.is_progress_read_only()
	):
		return false

	var catalog_mail: Dictionary = MAIL_CATALOG[mail_id]
	var reward: Dictionary = catalog_mail.get("reward", {})
	if reward.is_empty():
		return false

	var ledger: Array[String] = _get_ledger()
	var read_marker: String = MAIL_READ_PREFIX + mail_id
	var claim_marker: String = MAIL_CLAIM_PREFIX + mail_id
	if read_marker not in ledger:
		ledger.append(read_marker)
	ledger.append(claim_marker)

	var next_pavilion: Dictionary = _build_pavilion_snapshot(ledger)
	var result: Dictionary = RewardManager.grant_reward(
		RewardManager.SOURCE_PAVILION,
		"live_ops_mail_" + mail_id,
		reward,
		{"pavilion": next_pavilion}
	)
	if not bool(result.get("success", false)):
		return false

	_apply_pavilion_snapshot(next_pavilion)
	return true


func get_home_mail_badge_count() -> int:
	return maxi(
		get_mail_unread_count(),
		get_mail_claimable_count()
	)


func open_live_popup(scene_path: String) -> void:
	if SceneTransitionManager.is_transitioning or not ResourceLoader.exists(scene_path, "PackedScene"):
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null or tree.current_scene.scene_file_path != MAIN_MENU_SCENE:
		SceneTransitionManager.transition_menu_to(scene_path, 1)
		return
	if is_instance_valid(_active_live_popup):
		_active_live_popup.hide()
		_active_live_popup.queue_free()
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	var popup := packed.instantiate() as Control
	if popup == null:
		return
	popup.set_meta("liveops_popup", true)
	popup.z_index = 100
	tree.current_scene.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_active_live_popup = popup
	_active_live_popup_scene = scene_path
	SceneTransitionManager.set_back_handler(close_live_popup)


func close_live_popup() -> void:
	var popup := _active_live_popup
	_active_live_popup = null
	_active_live_popup_scene = ""
	if is_instance_valid(popup):
		popup.hide()
		popup.queue_free()
	var tree := get_tree()
	if tree != null and tree.current_scene != null and tree.current_scene.has_method("handle_system_back"):
		SceneTransitionManager.set_back_handler(Callable(tree.current_scene, "handle_system_back"))
