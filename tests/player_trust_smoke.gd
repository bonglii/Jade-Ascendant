extends SceneTree
const Provider = preload("res://tests/fixtures/admob_privacy_fixture.gd")
var checks: int = 0
var failures: int = 0
var earned: int = 0
class FakeAd extends RewardedAd:
 var destroys: int = 0
 var listener: OnUserEarnedRewardListener
 func show(value := OnUserEarnedRewardListener.new()) -> void: listener = value
 func _init() -> void: super(123)
 func destroy() -> void: destroys += 1
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error("PLAYER_TRUST " + label)
func frames(count: int = 6) -> void:
 for i: int in range(count): await process_frame
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_paid_v2_qa"): quit(2); return
 create_timer(30.0).timeout.connect(func(): push_error("PLAYER_TRUST_TIMEOUT"); quit(1))
 await frames()
 # Editor-only SDK mock singletons may initialize before SceneTree exists.
 # Own those fixture nodes in this disposable tree so normal teardown frees them.
 var factory: Script = load("res://addons/admob/internal/mock/mock_admob_factory.gd")
 for mock: Variant in factory.get("_mocks").values():
  if mock is Node and not mock.is_inside_tree(): root.add_child(mock)
 var provider: Node = Provider.new(); root.add_child(provider); await frames(2)
 var first := FakeAd.new()
 provider.set("_consent_gate_open", true); provider.set("_rewarded_ad", first); provider.set("_rewarded_loading", true)
 provider.call("_pause_ads_for_privacy")
 check(first.destroys == 1 and provider.get("_rewarded_ad") == null and not provider.get("_consent_gate_open") and not provider.get("_rewarded_loading"), "privacy invalidation destroys current ad and closes requests")
 var epoch: int = provider.get("_load_epoch")
 provider.set("_consent_gate_open", true); provider.set("_rewarded_loading", true)
 var stale := FakeAd.new(); provider.call("_on_rewarded_loaded", stale, epoch - 1)
 check(stale.destroys == 1 and provider.get("_rewarded_ad") == null and provider.get("_rewarded_loading"), "late previous-consent load is destroyed without clearing the current load")
 provider.call("_on_rewarded_failed_to_load", null, epoch - 1)
 check(provider.get("_rewarded_loading"), "stale failure cannot mutate current request")
 var current := FakeAd.new(); provider.call("_on_rewarded_loaded", current, epoch)
 check(provider.get("_rewarded_ad") == current and not provider.get("_rewarded_loading"), "current allowed load is retained")
 provider.set("_privacy_form_open", true)
 var blocked := FakeAd.new(); provider.call("_on_rewarded_loaded", blocked, epoch)
 check(blocked.destroys == 1, "privacy form blocks new ad acceptance")
 provider.call("_on_privacy_options_dismissed", {})
 check(not provider.get("_privacy_form_open") and not provider.get("_consent_gate_open") and provider.get("_rewarded_ad") == null, "privacy form error fails closed")
 provider.connect("reward_confirmed", func(_id: int): earned += 1)
 provider.set("_active_request_id", 42)
 provider.call("_on_user_earned_reward", {}, 41); check(earned == 0, "other request cannot grant")
 provider.call("_on_user_earned_reward", {}, 42); provider.call("_on_user_earned_reward", {}, 42)
 check(earned == 1, "matching earned callback grants once")
 provider.set("_active_request_id", -1)
 var wired: Node = load("res://tests/admob_reward_fence_fixture.gd").new()
 root.add_child(wired); await frames(2)
 var wired_ad := FakeAd.new(); wired.set("_rewarded_ad", wired_ad)
 var wired_earned: Array[int] = []
 var wired_ended: Array[String] = []
 wired.connect("reward_confirmed", func(id: int): wired_earned.append(id))
 wired.connect("request_finished", func(_id: int, status: String): wired_ended.append(status))
 wired.call("show_rewarded", 71, "pavilion_seal")
 check(wired_ad.listener != null, "actual show binds the SDK earned listener")
 wired_ad.listener.on_user_earned_reward.call(null)
 wired_ad.listener.on_user_earned_reward.call(null)
 wired_ad.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
 await frames(2)
 check(wired_earned == [71] and wired_ended == ["completed"], "SDK listener and dismissal path grant once and finish")
 wired.queue_free()
 var manager: Node = root.get_node("MonetizationManager"); var original: Node = manager.get("provider")
 manager.set("provider", provider)
 for language: String in ["en", "id"]:
  root.get_node("SettingsManager").set("language", language)
  change_scene_to_file("res://scenes/ui/privacy_screen.tscn"); await frames(12)
  var screen: Node = current_scene
  var email: String = screen.call("deletion_request_email_url")
  check(email.begins_with("mailto:yungdevstudio@gmail.com?subject=") and not email.contains("Bearer") and not email.contains("owner_binding") and not email.contains("firebase_uid"), "deletion draft contains no private credentials/identity")
  var labels: String = ""
  for label: Label in screen.find_children("*", "Label", true, false): labels += label.text + "\n"
  check(not labels.contains("Cloud Save is not available") and not labels.contains("pengiriman lokal"), "obsolete offline-only disclosures removed")
  var privacy_button: Button = screen.get("_ad_privacy_button")
  provider.set("required", false); screen.call("_refresh_privacy_access"); check(not privacy_button.visible, "not-required privacy entry hidden")
  provider.set("required", true); screen.call("_refresh_privacy_access"); check(privacy_button.visible, "privacy entry appears after delayed UMP update")
  for size: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(648, 1152)]:
   root.size = size; await frames(4)
   for button: Button in screen.find_children("*", "Button", true, false):
    if button.text not in ["REQUEST ACCOUNT DELETION", "MINTA PENGHAPUSAN AKUN", "EMAIL A DELETION REQUEST", "EMAIL PERMINTAAN PENGHAPUSAN"]: continue
    var font: Font = button.get_theme_font("font")
    check(button.size.x <= button.get_viewport_rect().size.x - 16 and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x < button.size.x - 12 and button.size.y >= 48 and button.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE, "complete deletion action fits mobile and releases after touch")
 manager.set("provider", original)
 provider.queue_free()
 change_scene_to_file("res://scenes/ui/settings_screen.tscn"); await frames(10)
 var support: String = current_scene.call("get_support_summary")
 check(support.contains("Ads consent gate=") and support.contains("Ads privacy options required=") and support.contains("Ads native plugins="), "release support exposes safe ad diagnostics")
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 current_scene.queue_free(); await frames(2)
 print("PLAYER_TRUST_QA checks=%d failures=%d; SDK_FORM_AND_REAL_AD=NOT_PHONE_TESTED" % [checks, failures])
 call_deferred("quit", 1 if failures else 0)
