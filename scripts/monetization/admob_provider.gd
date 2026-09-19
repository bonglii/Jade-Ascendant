extends "res://scripts/monetization/offline_provider.gd"

## Android AdMob adapter for Jade Ascendant.
##
## Privacy:
## - Refresh UMP consent on every app launch.
## - Fail closed while consent is unresolved or refresh fails.
## - Initialize/load ads only after NOT_REQUIRED or OBTAINED.
##
## Release safety:
## - Debug Android uses Google's rewarded test unit.
## - Release requires an explicit production ad-unit setting.

const TEST_REWARDED_AD_UNIT_ID: String = "ca-app-pub-3940256099942544/5224354917"
const RELEASE_REWARDED_SETTING: String = "monetization/admob/rewarded_ad_unit_id"

const LOAD_RETRY_INITIAL_SECONDS: float = 15.0
const LOAD_RETRY_MAX_SECONDS: float = 120.0

const REQUIRED_NATIVE_SINGLETONS: Array[String] = [
	"PoingGodotAdMob",
	"PoingGodotAdMobConsentInformation",
	"PoingGodotAdMobUserMessagingPlatform",
	"PoingGodotAdMobRewardedAd"
]

var _state: String = "created"
var _ad_unit_id: String = ""
var _consent_gate_open: bool = false
var _initialization_started: bool = false
var _ads_initialized: bool = false
var _rewarded_loading: bool = false
var _rewarded_ad: RewardedAd
var _consent_form: ConsentForm

var _active_request_id: int = -1
var _reward_earned_for_request: bool = false

var _retry_timer: Timer
var _retry_delay_seconds: float = LOAD_RETRY_INITIAL_SECONDS


func _ready() -> void:
	name = "AdMobProvider"

	if OS.get_name() != "Android":
		_state = "unsupported_platform"
		return

	_ad_unit_id = _resolve_rewarded_ad_unit_id()
	if _ad_unit_id.is_empty():
		_state = "disabled_missing_release_ad_unit"
		return

	if not _native_plugins_available():
		_state = "native_plugin_missing"
		push_error("AdMobProvider: native AdMob/UMP plugin tidak tersedia.")
		return

	_retry_timer = Timer.new()
	_retry_timer.name = "RewardedLoadRetry"
	_retry_timer.one_shot = true
	_retry_timer.wait_time = LOAD_RETRY_INITIAL_SECONDS
	_retry_timer.timeout.connect(_load_rewarded_ad)
	add_child(_retry_timer)

	_begin_consent_update()


func _exit_tree() -> void:
	_destroy_rewarded_ad()


func rewarded_available(_placement: String) -> bool:
	return (
		OS.get_name() == "Android"
		and _consent_gate_open
		and _ads_initialized
		and _rewarded_ad != null
		and not _rewarded_loading
		and _active_request_id < 0
	)


func show_rewarded(request_id: int, placement: String) -> void:
	if request_id < 0 or not rewarded_available(placement):
		request_finished.emit(request_id, "unavailable")
		return

	_active_request_id = request_id
	_reward_earned_for_request = false
	_state = "rewarded_showing"

	var content_callback := FullScreenContentCallback.new()
	content_callback.on_ad_dismissed_full_screen_content = _on_rewarded_dismissed
	content_callback.on_ad_failed_to_show_full_screen_content = _on_rewarded_failed_to_show
	_rewarded_ad.full_screen_content_callback = content_callback

	var reward_listener := OnUserEarnedRewardListener.new()
	reward_listener.on_user_earned_reward = _on_user_earned_reward
	_rewarded_ad.show(reward_listener)


func privacy_options_required() -> bool:
	if OS.get_name() != "Android" or not _native_plugins_available():
		return false
	return (
		UserMessagingPlatform.consent_information.get_privacy_options_requirement_status()
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
	)


func show_privacy_options() -> bool:
	if OS.get_name() != "Android" or not _native_plugins_available():
		return false
	if not privacy_options_required() or _active_request_id >= 0:
		return false

	UserMessagingPlatform.show_privacy_options_form(_on_privacy_options_dismissed)
	return true


func get_runtime_status() -> Dictionary:
	return {
		"provider": "admob",
		"state": _state,
		"test_mode": OS.is_debug_build(),
		"consent_gate_open": _consent_gate_open,
		"ads_initialized": _ads_initialized,
		"rewarded_loading": _rewarded_loading,
		"rewarded_ready": _rewarded_ad != null,
		"privacy_options_required": privacy_options_required()
	}


func _resolve_rewarded_ad_unit_id() -> String:
	if OS.is_debug_build():
		return TEST_REWARDED_AD_UNIT_ID

	var configured: String = str(
		ProjectSettings.get_setting(RELEASE_REWARDED_SETTING, "")
	).strip_edges()

	if configured.is_empty():
		return ""

	if configured == TEST_REWARDED_AD_UNIT_ID:
		push_error("AdMobProvider: release build menolak Google rewarded test ad unit.")
		return ""

	if not configured.begins_with("ca-app-pub-") or "/" not in configured:
		push_error("AdMobProvider: production rewarded ad-unit ID tidak valid.")
		return ""

	return configured


func _native_plugins_available() -> bool:
	for singleton_name: String in REQUIRED_NATIVE_SINGLETONS:
		if not Engine.has_singleton(singleton_name):
			return false
	return true


func _begin_consent_update() -> void:
	_state = "consent_updating"
	_consent_gate_open = false

	var parameters := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(
		parameters,
		_on_consent_update_success,
		_on_consent_update_failure
	)


func _on_consent_update_success() -> void:
	_evaluate_consent_after_update()


func _on_consent_update_failure(_form_error) -> void:
	_state = "consent_update_failed"
	_consent_gate_open = false
	_destroy_rewarded_ad()


func _evaluate_consent_after_update() -> void:
	var information := UserMessagingPlatform.consent_information
	var consent_status: int = information.get_consent_status()

	if _consent_allows_ads(consent_status):
		_open_consent_gate()
		return

	if (
		consent_status == ConsentInformation.ConsentStatus.REQUIRED
		and information.get_is_consent_form_available()
	):
		_state = "consent_form_loading"
		UserMessagingPlatform.load_consent_form(
			_on_consent_form_loaded,
			_on_consent_form_load_failure
		)
		return

	_state = "consent_unresolved"
	_consent_gate_open = false
	_destroy_rewarded_ad()


func _on_consent_form_loaded(consent_form: ConsentForm) -> void:
	if consent_form == null:
		_state = "consent_form_missing"
		return

	_consent_form = consent_form
	_state = "consent_form_showing"
	_consent_form.show(_on_consent_form_dismissed)


func _on_consent_form_load_failure(_form_error) -> void:
	_state = "consent_form_load_failed"
	_consent_gate_open = false
	_consent_form = null
	_destroy_rewarded_ad()


func _on_consent_form_dismissed(form_error) -> void:
	_consent_form = null
	if form_error != null:
		_state = "consent_form_dismiss_failed"
		_consent_gate_open = false
		_destroy_rewarded_ad()
		return

	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	if _consent_allows_ads(status):
		_open_consent_gate()
		return

	_state = "consent_not_granted"
	_consent_gate_open = false
	_destroy_rewarded_ad()


func _on_privacy_options_dismissed(form_error) -> void:
	if form_error != null:
		_state = "privacy_options_failed"
		return

	_destroy_rewarded_ad()
	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	if _consent_allows_ads(status):
		_consent_gate_open = true
		if _ads_initialized:
			_state = "ads_initialized"
			_load_rewarded_ad()
		else:
			_initialize_mobile_ads()
	else:
		_consent_gate_open = false
		_state = "consent_not_granted"


func _consent_allows_ads(consent_status: int) -> bool:
	return consent_status in [
		ConsentInformation.ConsentStatus.NOT_REQUIRED,
		ConsentInformation.ConsentStatus.OBTAINED
	]


func _open_consent_gate() -> void:
	_consent_gate_open = true
	_initialize_mobile_ads()


func _initialize_mobile_ads() -> void:
	if not _consent_gate_open:
		return

	if _ads_initialized:
		_load_rewarded_ad()
		return

	if _initialization_started:
		return

	_initialization_started = true
	_state = "ads_initializing"

	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_mobile_ads_initialized
	MobileAds.initialize(listener)


func _on_mobile_ads_initialized(_initialization_status) -> void:
	_ads_initialized = true
	_initialization_started = false
	_state = "ads_initialized"
	_load_rewarded_ad()


func _load_rewarded_ad() -> void:
	if (
		not _consent_gate_open
		or not _ads_initialized
		or _rewarded_loading
		or _rewarded_ad != null
		or _active_request_id >= 0
		or _ad_unit_id.is_empty()
	):
		return

	_rewarded_loading = true
	_state = "rewarded_loading"

	var request := AdRequest.new()
	request.keywords = []
	request.mediation_extras = []
	request.extras = {}

	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = _on_rewarded_loaded
	callback.on_ad_failed_to_load = _on_rewarded_failed_to_load

	var loader := RewardedAdLoader.new()
	loader.load(_ad_unit_id, request, callback)


func _on_rewarded_loaded(ad: RewardedAd) -> void:
	_rewarded_loading = false
	_retry_delay_seconds = LOAD_RETRY_INITIAL_SECONDS

	if ad == null:
		_state = "rewarded_load_empty"
		_schedule_load_retry()
		return

	_destroy_rewarded_ad()
	_rewarded_ad = ad
	_state = "rewarded_ready"


func _on_rewarded_failed_to_load(_load_error) -> void:
	_rewarded_loading = false
	_state = "rewarded_load_failed"
	_schedule_load_retry()


func _schedule_load_retry() -> void:
	if (
		_retry_timer == null
		or not _consent_gate_open
		or not _ads_initialized
		or _active_request_id >= 0
	):
		return

	_retry_timer.wait_time = _retry_delay_seconds
	if _retry_timer.is_stopped():
		_retry_timer.start()

	_retry_delay_seconds = minf(
		_retry_delay_seconds * 2.0,
		LOAD_RETRY_MAX_SECONDS
	)


func _on_user_earned_reward(_rewarded_item) -> void:
	if _active_request_id < 0 or _reward_earned_for_request:
		return

	_reward_earned_for_request = true
	_emit_reward_confirmed(_active_request_id)


func _on_rewarded_dismissed() -> void:
	if _active_request_id < 0:
		_destroy_rewarded_ad()
		_load_rewarded_ad()
		return

	var finished_request: int = _active_request_id
	var status: String = "completed" if _reward_earned_for_request else "cancelled"

	_active_request_id = -1
	_reward_earned_for_request = false
	_destroy_rewarded_ad()
	_state = "ads_initialized"
	request_finished.emit(finished_request, status)
	_load_rewarded_ad()


func _on_rewarded_failed_to_show(_ad_error) -> void:
	if _active_request_id < 0:
		_destroy_rewarded_ad()
		_load_rewarded_ad()
		return

	var failed_request: int = _active_request_id
	_active_request_id = -1
	_reward_earned_for_request = false
	_destroy_rewarded_ad()
	_state = "rewarded_show_failed"
	request_finished.emit(failed_request, "failed")
	_schedule_load_retry()


func _destroy_rewarded_ad() -> void:
	if _rewarded_ad != null:
		_rewarded_ad.destroy()
		_rewarded_ad = null
