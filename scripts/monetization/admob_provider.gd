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
## - Release requires explicit production App ID + rewarded ad unit.
## - Sample/test IDs and mismatched publisher IDs fail closed.

const TEST_REWARDED_AD_UNIT_ID: String = "ca-app-pub-3940256099942544/5224354917"
const GOOGLE_SAMPLE_ANDROID_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"
const ANDROID_APP_ID_SETTING: String = "admob/general/android/app_id"
const UnitCatalog = preload("res://scripts/monetization/rewarded_unit_catalog.gd")

const CONSENT_RETRY_INITIAL_SECONDS: float = 5.0
const CONSENT_RETRY_MAX_SECONDS: float = 60.0
const LOAD_RETRY_INITIAL_SECONDS: float = 15.0
const LOAD_RETRY_MAX_SECONDS: float = 120.0

const REQUIRED_NATIVE_SINGLETONS: Array[String] = [
	"PoingGodotAdMob",
	"PoingGodotAdMobConsentInformation",
	"PoingGodotAdMobUserMessagingPlatform",
	"PoingGodotAdMobRewardedAd"
]

var _state: String = "created"
var _load_epoch: int = 0
var _privacy_form_open: bool = false
var _consent_gate_open: bool = false
var _initialization_started: bool = false
var _ads_initialized: bool = false
# Each unit owns its cache, load generation, retry backoff and safe status.
var _units: Dictionary = {}
var _active_unit: String = ""
var _consent_form: ConsentForm

var _odyssey_ssv_nonce: String = ""
var _trials_ssv_nonce: String = ""
var _active_request_id: int = -1
var _reward_earned_for_request: bool = false
var _request_finishing: bool = false
var _last_load_error_code: int = -1

var _consent_retry_timer: Timer
var _consent_retry_delay_seconds: float = CONSENT_RETRY_INITIAL_SECONDS


func _ready() -> void:
	name = "AdMobProvider"

	if OS.get_name() != "Android":
		_state = "unsupported_platform"
		_trace_state()
		return

	if not OS.is_debug_build() and not _production_configuration_valid():
		_state = "disabled_invalid_release_config"
		_trace_state()
		return


	if not _native_plugins_available():
		_state = "native_plugin_missing"
		_trace_state()
		push_error("AdMobProvider: native AdMob/UMP plugin tidak tersedia.")
		return

	_consent_retry_timer = Timer.new()
	_consent_retry_timer.name = "ConsentUpdateRetry"
	_consent_retry_timer.one_shot = true
	_consent_retry_timer.wait_time = CONSENT_RETRY_INITIAL_SECONDS
	_consent_retry_timer.timeout.connect(_begin_consent_update)
	add_child(_consent_retry_timer)


	_begin_consent_update()


func _exit_tree() -> void:
	_destroy_rewarded_ad()


func _ads_platform_supported() -> bool:
	return OS.get_name() == "Android"


func _slot(unit: String) -> Dictionary:
	if not UnitCatalog.UNITS.has(unit) and not (unit=="trials" and not UnitCatalog.trials_unit_id.is_empty()): return {}
	if not _units.has(unit):
		_units[unit] = {"ad": null, "loaded_at": -1, "loading": false,
			"generation": 0, "load_started": -1, "retry_at": 0, "retry_delay": LOAD_RETRY_INITIAL_SECONDS,
			"state": "idle", "last_error": -1}
	return _units[unit]


func rewarded_available(placement: String) -> bool:
	var unit: String = UnitCatalog.unit_for(placement)
	if unit.is_empty() or (unit=="trials" and UnitCatalog.trials_unit_id.is_empty()): return false
	if _ads_platform_supported(): warm_rewarded_ad(placement)
	var slot: Dictionary = _slot(unit)
	return (_ads_platform_supported() and _consent_gate_open and not _privacy_form_open
		and _ads_initialized and slot.ad != null and not slot.loading and _active_request_id < 0)


func _ad_clock_ms() -> int:
	return Time.get_ticks_msec()


func warm_rewarded_ad(placement: String = "odyssey_roll") -> void:
	var unit: String = UnitCatalog.unit_for(placement)
	if unit.is_empty() or (unit=="trials" and UnitCatalog.trials_unit_id.is_empty()) or _active_request_id >= 0: return
	var slot: Dictionary = _slot(unit)
	if slot.ad != null and int(slot.loaded_at) >= 0 and _ad_clock_ms() - int(slot.loaded_at) >= 55 * 60 * 1000:
		_destroy_unit_ad(unit)
	if _ad_clock_ms() < int(slot.retry_at): return
	_load_rewarded_ad(unit)


func _warm_all_units() -> void:
	var configured: Array = UnitCatalog.UNITS.keys()
	if not UnitCatalog.trials_unit_id.is_empty(): configured.append("trials")
	for unit: String in configured:
		if _ad_clock_ms() >= int(_slot(unit).retry_at): _load_rewarded_ad(unit)


func _process(_delta: float) -> void:
	if not _consent_gate_open or _privacy_form_open or not _ads_initialized or _active_request_id >= 0: return
	for unit: String in _units:
		var slot: Dictionary = _units[unit]
		if slot.loading and _ad_clock_ms() - int(slot.load_started) >= 45000:
			slot.loading = false
			slot.generation = int(slot.generation) + 1
			slot.last_error = -2
			slot.state = "load_timeout"
			_schedule_load_retry(unit)
		if int(slot.retry_at) > 0 and _ad_clock_ms() >= int(slot.retry_at):
			slot.retry_at = 0
			_load_rewarded_ad(unit)


func is_rewarded_showing(request_id: int) -> bool:
	return request_id >= 0 and _active_request_id == request_id


func prepare_odyssey_ssv(nonce: String) -> void:
	_odyssey_ssv_nonce = nonce if nonce.length() == 32 and nonce.is_valid_hex_number(false) else ""


func prepare_trials_ssv(nonce: String) -> void:
	_trials_ssv_nonce=nonce if nonce.length()==32 and nonce.is_valid_hex_number(false) else ""

func configure_trials_unit(value: String) -> bool:
	if value==UnitCatalog.trials_unit_id: return not value.is_empty()
	if _active_unit=="trials": return false
	var previous: String=UnitCatalog.trials_unit_id
	if not UnitCatalog.configure_trials(value): return false
	if not previous.is_empty(): _destroy_unit_ad("trials")
	return true

func show_rewarded(request_id: int, placement: String) -> void:
	if request_id < 0 or not rewarded_available(placement):
		request_finished.emit(request_id, "unavailable")
		return
	if placement == "odyssey_roll" and _odyssey_ssv_nonce.is_empty():
		request_finished.emit(request_id, "unavailable")
		return
	if placement=="heavenly_trials_bonus" and _trials_ssv_nonce.is_empty():
		request_finished.emit(request_id,"unavailable"); return
	var unit: String = UnitCatalog.unit_for(placement)
	var ad: RewardedAd = _slot(unit).ad
	var verification := ServerSideVerificationOptions.new()
	verification.custom_data = _odyssey_ssv_nonce if placement == "odyssey_roll" else _trials_ssv_nonce if placement=="heavenly_trials_bonus" else ""
	verification.user_id = verification.custom_data
	ad.set_server_side_verification_options(verification)
	# A nonce belongs to the dice intent only; never carry it into another unit.
	_odyssey_ssv_nonce = ""
	_trials_ssv_nonce = ""
	_active_unit = unit
	_active_request_id = request_id
	_reward_earned_for_request = false
	_request_finishing = false
	_slot(unit).state = "showing"
	_state = "rewarded_showing"
	_trace_state()
	var content_callback := FullScreenContentCallback.new()
	content_callback.on_ad_dismissed_full_screen_content = _on_rewarded_dismissed.bind(request_id)
	content_callback.on_ad_failed_to_show_full_screen_content = _on_rewarded_failed_to_show.bind(request_id)
	ad.full_screen_content_callback = content_callback
	var reward_listener := OnUserEarnedRewardListener.new()
	reward_listener.on_user_earned_reward = _on_user_earned_reward.bind(request_id)
	ad.show(reward_listener)


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
	if not privacy_options_required() or _active_request_id >= 0 or _privacy_form_open or _state in ["consent_updating", "consent_form_loading", "consent_form_showing"]:
		return false

	_pause_ads_for_privacy()
	_privacy_form_open = true
	_state = "privacy_options_showing"
	_trace_state()
	UserMessagingPlatform.show_privacy_options_form(_on_privacy_options_dismissed)
	return true


func get_runtime_status() -> Dictionary:
	var details: Dictionary = {}
	var ready_count: int = 0
	var loading: bool = false
	for unit: String in UnitCatalog.UNITS:
		var slot: Dictionary = _slot(unit)
		var unit_ready: bool = slot.ad != null and not slot.loading and _active_unit != unit
		if unit_ready: ready_count += 1
		loading = loading or bool(slot.loading)
		details[unit] = {"state": slot.state, "ready": unit_ready, "loading": slot.loading,
			"last_load_error_code": slot.last_error}
	var state: String = _state
	if _consent_gate_open and _ads_initialized and _active_request_id < 0:
		state = "rewarded_ready" if ready_count > 0 else "rewarded_loading" if loading else "rewarded_waiting"
	return {
		"provider": "admob", "state": state, "test_mode": OS.is_debug_build(),
		"last_load_error_code": _last_load_error_code, "consent_gate_open": _consent_gate_open,
		"consent_retry_scheduled": _consent_retry_timer != null and not _consent_retry_timer.is_stopped(),
		"consent_retry_delay_seconds": _consent_retry_delay_seconds, "ads_initialized": _ads_initialized,
		"rewarded_loading": loading, "rewarded_ready": ready_count > 0,
		"privacy_options_required": privacy_options_required(), "privacy_form_open": _privacy_form_open,
		"native_plugins_available": _native_plugins_available() if _ads_platform_supported() else false,
		"rewarded_units_revision": UnitCatalog.REVISION, "active_unit": _active_unit, "units": details
	}


func _production_configuration_valid() -> bool:
	var ids: Dictionary = {}
	for unit: String in UnitCatalog.UNITS: ids[unit] = UnitCatalog.unit_id(unit, false)
	var valid: bool = UnitCatalog.release_configuration_valid(str(ProjectSettings.get_setting(ANDROID_APP_ID_SETTING, "")).strip_edges(), ids)
	if not valid: push_error("AdMobProvider: production App ID or distinct rewarded-unit configuration invalid.")
	return valid


func _uses_test_ads() -> bool:
	return OS.is_debug_build()


func _resolve_rewarded_ad_unit_id(unit: String = "dice") -> String:
	return UnitCatalog.unit_id(unit, _uses_test_ads())


func _is_valid_app_id(value: String) -> bool:
	var expression := RegEx.new()
	if expression.compile("^ca-app-pub-[0-9]{16}~[0-9]{10}$") != OK:
		return false
	return expression.search(value) != null


func _is_valid_rewarded_id(value: String) -> bool:
	var expression := RegEx.new()
	if expression.compile("^ca-app-pub-[0-9]{16}/[0-9]{10}$") != OK:
		return false
	return expression.search(value) != null


func _publisher_prefix(value: String, separator: String) -> String:
	var separator_index: int = value.find(separator)
	if separator_index <= 0:
		return ""
	return value.substr(0, separator_index)


func _native_plugins_available() -> bool:
	for singleton_name: String in REQUIRED_NATIVE_SINGLETONS:
		if not Engine.has_singleton(singleton_name):
			return false
	return true


func _begin_consent_update() -> void:
	if _privacy_form_open: return
	_pause_ads_for_privacy()
	_state = "consent_updating"
	_trace_state()
	_consent_gate_open = false
	_destroy_rewarded_ad()
	if (
		_consent_retry_timer != null
		and not _consent_retry_timer.is_stopped()
	):
		_consent_retry_timer.stop()

	var parameters := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(
		parameters,
		_on_consent_update_success,
		_on_consent_update_failure
	)


func _on_consent_update_success() -> void:
	_reset_consent_retry()
	_evaluate_consent_after_update()


func _on_consent_update_failure(_form_error) -> void:
	_state = "consent_update_failed"
	_trace_state()
	_consent_gate_open = false
	_destroy_rewarded_ad()
	_schedule_consent_retry()


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
		_trace_state()
		UserMessagingPlatform.load_consent_form(
			_on_consent_form_loaded,
			_on_consent_form_load_failure
		)
		return

	_state = "consent_unresolved"
	_trace_state()
	_consent_gate_open = false
	_destroy_rewarded_ad()
	_schedule_consent_retry()


func _on_consent_form_loaded(consent_form: ConsentForm) -> void:
	if consent_form == null:
		_state = "consent_form_missing"
		_trace_state()
		_consent_gate_open = false
		_consent_form = null
		_destroy_rewarded_ad()
		_schedule_consent_retry()
		return

	_consent_form = consent_form
	_state = "consent_form_showing"
	_trace_state()
	_consent_form.show(_on_consent_form_dismissed)


func _on_consent_form_load_failure(_form_error) -> void:
	_state = "consent_form_load_failed"
	_trace_state()
	_consent_gate_open = false
	_consent_form = null
	_destroy_rewarded_ad()
	_schedule_consent_retry()


func _on_consent_form_dismissed(form_error) -> void:
	_consent_form = null
	if form_error != null:
		_state = "consent_form_dismiss_failed"
		_trace_state()
		_consent_gate_open = false
		_destroy_rewarded_ad()
		_schedule_consent_retry()
		return

	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	if _consent_allows_ads(status):
		_open_consent_gate()
		return

	_state = "consent_not_granted"
	_trace_state()
	_consent_gate_open = false
	_destroy_rewarded_ad()


func _on_privacy_options_dismissed(form_error) -> void:
	_privacy_form_open = false
	if form_error != null:
		_pause_ads_for_privacy()
		_state = "privacy_options_failed"
		_trace_state()
		_schedule_consent_retry()
		return

	_destroy_rewarded_ad()
	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	if _consent_allows_ads(status):
		_consent_gate_open = true
		if _ads_initialized:
			_state = "ads_initialized"
			_trace_state()
			_warm_all_units()
		else:
			_initialize_mobile_ads()
	else:
		_consent_gate_open = false
		_state = "consent_not_granted"
		_trace_state()


func _consent_allows_ads(consent_status: int) -> bool:
	return consent_status in [
		ConsentInformation.ConsentStatus.NOT_REQUIRED,
		ConsentInformation.ConsentStatus.OBTAINED
	]


func _schedule_consent_retry() -> void:
	if (
		_consent_retry_timer == null
		or _consent_gate_open
		or _active_request_id >= 0
	):
		return

	_consent_retry_timer.wait_time = _consent_retry_delay_seconds
	if _consent_retry_timer.is_stopped():
		_consent_retry_timer.start()

	_consent_retry_delay_seconds = minf(
		_consent_retry_delay_seconds * 2.0,
		CONSENT_RETRY_MAX_SECONDS
	)


func _reset_consent_retry() -> void:
	_consent_retry_delay_seconds = CONSENT_RETRY_INITIAL_SECONDS
	if (
		_consent_retry_timer != null
		and not _consent_retry_timer.is_stopped()
	):
		_consent_retry_timer.stop()


func _open_consent_gate() -> void:
	_reset_consent_retry()
	_consent_gate_open = true
	_initialize_mobile_ads()


func _initialize_mobile_ads() -> void:
	if not _consent_gate_open:
		return

	if _ads_initialized:
		_warm_all_units()
		return

	if _initialization_started:
		return

	_initialization_started = true
	_state = "ads_initializing"
	_trace_state()

	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_mobile_ads_initialized
	MobileAds.initialize(listener)


func _on_mobile_ads_initialized(_initialization_status) -> void:
	_ads_initialized = true
	_initialization_started = false
	_state = "ads_initialized"
	_trace_state()
	_warm_all_units()


func _load_rewarded_ad(unit: String = "dice") -> void:
	if not UnitCatalog.UNITS.has(unit) and not (unit=="trials" and not UnitCatalog.trials_unit_id.is_empty()): return
	var slot: Dictionary = _slot(unit)
	if not _consent_gate_open or _privacy_form_open or not _ads_initialized or bool(slot.loading) or slot.ad != null or _active_request_id >= 0: return
	if _ad_clock_ms() < int(slot.retry_at): return
	var id: String = _resolve_rewarded_ad_unit_id(unit)
	if id.is_empty(): slot.state = "invalid_configuration"; return
	slot.loading = true
	slot.load_started = _ad_clock_ms()
	slot.generation = int(slot.generation) + 1
	slot.state = "loading"
	var request := AdRequest.new()
	request.keywords = []
	request.mediation_extras = []
	request.extras = {}
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = _on_rewarded_loaded.bind(_load_epoch, unit, int(slot.generation))
	callback.on_ad_failed_to_load = _on_rewarded_failed_to_load.bind(_load_epoch, unit, int(slot.generation))
	_request_ad(id, request, callback)


func _request_ad(id: String, request: AdRequest, callback: RewardedAdLoadCallback) -> void:
	var loader := RewardedAdLoader.new()
	loader.load(id, request, callback)


func _current_load(epoch: int, unit: String, generation: int) -> bool:
	return (_units.has(unit) and epoch == _load_epoch and generation == int(_units[unit].generation)
		and bool(_units[unit].loading) and _consent_gate_open and not _privacy_form_open)


func _on_rewarded_loaded(ad: RewardedAd, epoch: int, unit: String, generation: int) -> void:
	if not _current_load(epoch, unit, generation):
		# Duplicate callbacks must not destroy the very object already held by us.
		if ad != null and (not _units.has(unit) or _units[unit].ad != ad): ad.destroy()
		return
	var slot: Dictionary = _units[unit]
	slot.loading = false
	slot.last_error = -1
	_last_load_error_code = -1
	if ad == null:
		slot.state = "load_empty"
		_schedule_load_retry(unit)
		return
	slot.ad = ad
	slot.loaded_at = _ad_clock_ms()
	slot.retry_at = 0
	slot.retry_delay = LOAD_RETRY_INITIAL_SECONDS
	slot.state = "ready"
	_trace_unit(unit)


func _on_rewarded_failed_to_load(load_error, epoch: int, unit: String, generation: int) -> void:
	if not _current_load(epoch, unit, generation): return
	var slot: Dictionary = _units[unit]
	slot.last_error = int(load_error.code) if load_error != null else -1
	_last_load_error_code = int(slot.last_error)
	slot.loading = false
	slot.state = "load_failed"
	_schedule_load_retry(unit)
	_trace_unit(unit)


func _schedule_load_retry(unit: String) -> void:
	if not _units.has(unit) or not _consent_gate_open or not _ads_initialized: return
	var slot: Dictionary = _units[unit]
	if int(slot.retry_at) <= 0:
		slot.retry_at = _ad_clock_ms() + int(float(slot.retry_delay) * 1000.0)
		slot.retry_delay = minf(float(slot.retry_delay) * 2.0, LOAD_RETRY_MAX_SECONDS)


func _trace_unit(unit: String) -> void:
	if OS.get_name() == "Android":
		print("JADE_ADS_QA unit=", unit, " state=", _slot(unit).state, " code=", _slot(unit).last_error)


func _on_user_earned_reward(_rewarded_item, request_id: int) -> void:
	if request_id < 0 or request_id != _active_request_id or _reward_earned_for_request or not _consent_gate_open or _privacy_form_open:
		return
	_reward_earned_for_request = true
	if OS.get_name() == "Android":
		print("JADE_ADS_QA earned=confirmed")
	_emit_reward_confirmed(request_id)


func _on_rewarded_dismissed(request_id: int) -> void:
	if request_id < 0 or request_id != _active_request_id or _request_finishing:
		return
	_request_finishing = true
	# Drain already queued SDK callbacks for this request; never credit a later ad.
	_finalize_rewarded_dismissal.call_deferred(request_id)


func _finalize_rewarded_dismissal(request_id: int) -> void:
	if request_id != _active_request_id or not _request_finishing:
		return
	var status: String = "completed" if _reward_earned_for_request else "cancelled"
	var unit: String = _active_unit
	_active_request_id = -1
	_active_unit = ""
	_reward_earned_for_request = false
	_request_finishing = false
	_destroy_unit_ad(unit)
	_state = "ads_initialized"
	_trace_state()
	request_finished.emit(request_id, status)
	_warm_all_units()


func _on_rewarded_failed_to_show(_ad_error, request_id: int) -> void:
	if request_id < 0 or request_id != _active_request_id or _request_finishing:
		return
	var unit: String = _active_unit
	_active_request_id = -1
	_active_unit = ""
	_reward_earned_for_request = false
	_request_finishing = false
	_destroy_unit_ad(unit)
	_state = "rewarded_show_failed"
	_trace_state()
	request_finished.emit(request_id, "failed")
	_schedule_load_retry(unit)


func _trace_state() -> void:
	if OS.get_name() == "Android":
		print("JADE_ADS_QA state=", _state, " test=", OS.is_debug_build())


func _destroy_unit_ad(unit: String) -> void:
	if not _units.has(unit): return
	var slot: Dictionary = _units[unit]
	var ad: RewardedAd = slot.ad
	slot.ad = null
	slot.loaded_at = -1
	if ad != null: ad.destroy()
	if not slot.loading: slot.state = "idle"


func _destroy_rewarded_ad() -> void:
	for unit: String in _units: _destroy_unit_ad(unit)


func _pause_ads_for_privacy() -> void:
	_consent_gate_open = false
	_load_epoch += 1
	_odyssey_ssv_nonce = ""
	if _consent_retry_timer != null: _consent_retry_timer.stop()
	for unit: String in _units:
		var slot: Dictionary = _units[unit]
		slot.generation = int(slot.generation) + 1
		slot.loading = false
		slot.retry_at = 0
		slot.retry_delay = LOAD_RETRY_INITIAL_SECONDS
	_destroy_rewarded_ad()
