extends Node

## Inventory-aware first-clear follow-up. Reading never grants/spends or equips.
const SAVE_PATH: String = "user://refine_guide.cfg"
const HOME: String = "res://scenes/ui/main_menu.tscn"
const HERO: String = "res://scenes/ui/equipment_screen.tscn"
const CULTIVATION: String = "res://scenes/ui/cultivation_menu.tscn"
const JOURNEY: String = "res://scenes/ui/chapter_select.tscn"
const ScrollPolicy = preload("res://scripts/ui/mobile_scroll_policy.gd")
var completed: bool = false
var empty_explained: bool = false
var empty_mode: bool = false
var step: int = 0
var elapsed: float = 0.0
var popup: Control
var scene_id: int = 0

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 var config := ConfigFile.new()
 if config.load(SAVE_PATH) == OK:
  completed = bool(config.get_value("refine", "completed", false))
  empty_explained = bool(config.get_value("refine", "empty_explained", false))

func _local(english: String, indonesian: String) -> String:
 return indonesian if SettingsManager.language == "id" else english

func owned_equipment_ids() -> Array[String]:
 var result: Array[String] = []
 for id: String in InventoryManager.get_owned_item_ids():
  if EquipmentManager.has_item_definition(id): result.append(id)
 return result

func has_affordable_cultivation() -> bool:
 for path: String in ["vitality", "sword_power", "swift_qi"]:
  var cost: int = int(ProgressionManager.call("get_" + path + "_cost"))
  if not bool(ProgressionManager.call("is_" + path + "_maxed")) and cost > 0 and ProgressionManager.spirit_stone >= cost:
   return true
 return false

func _process(delta: float) -> void:
 if completed: return
 elapsed += delta
 if elapsed < 0.25: return
 elapsed = 0.0
 var scene: Node = get_tree().current_scene
 if is_instance_valid(popup):
  if scene == null or scene.get_instance_id() != scene_id: _dismiss(false)
  return
 if not should_offer(scene): return
 empty_mode = owned_equipment_ids().is_empty()
 if scene.scene_file_path == HOME: step = 0
 elif step == 0: step = 1
 _show_guide(scene)

func should_offer(scene: Node) -> bool:
 if completed or scene == null or not JourneyManager.is_stage_cleared(1, 1): return false
 if empty_explained and owned_equipment_ids().is_empty(): return false
 if scene.scene_file_path not in [HOME, HERO] or SceneTransitionManager.is_transitioning: return false
 if get_tree().paused or SaveManager.is_progress_read_only(): return false
 # Recovery/Continue remains the primary action. Never cover a saved run.
 if JourneyManager.has_active_run(): return false
 if scene.has_method("_has_checkpoint") and bool(scene.call("_has_checkpoint")): return false
 if scene.scene_file_path == HERO and bool(scene.get("detail_open")): return false
 for name_value: String in ["UnifiedRewardClaimPopup", "SpiritMeditationPremiumPopup", "SanctuaryAnnouncement", "ProfilePopup", "JadeOnboardingOverlay"]:
  var blocker: CanvasItem = get_tree().root.find_child(name_value, true, false) as CanvasItem
  if blocker != null and blocker.is_visible_in_tree(): return false
 var live_ops: Node = get_tree().root.get_node_or_null("LiveOpsManager")
 if live_ops != null and is_instance_valid(live_ops.get("_active_live_popup")): return false
 return true

func guide_copy() -> Dictionary:
 if empty_mode:
  var affordable: bool = has_affordable_cultivation()
  return {
   "title": _local("Your first victory", "Kemenangan pertamamu"),
   "body": _local("Your starting attack works even with an empty backpack. Permanent relics come from equipment rewards and the Pavilion, unlocked after Stage 1-5. ", "Serangan awal tetap tersedia meski backpack kosong. Relik permanen berasal dari hadiah equipment dan Pavilion yang terbuka setelah Stage 1-5. ") + (_local("You can afford a permanent Cultivation upgrade now.", "Spirit Stone-mu cukup untuk upgrade Cultivation permanen sekarang.") if affordable else _local("Continue the Journey to collect rewards and unlock more paths.", "Lanjutkan Journey untuk mengumpulkan hadiah dan membuka jalur baru.")),
   "button": _local("OPEN CULTIVATION", "BUKA CULTIVATION") if affordable else _local("CONTINUE JOURNEY", "LANJUTKAN JOURNEY"),
   "counter": _local("FIRST-CLEAR GUIDE", "PANDUAN KEMENANGAN PERTAMA")
  }
 var titles: Array[String] = [_local("Strengthen your relics", "Perkuat relikmu"), _local("Duplicates unlock stars", "Duplikat membuka bintang"), _local("Weapons have their own levels", "Senjata punya level sendiri")]
 var copy: Array[String] = [
  _local("You own permanent equipment. Open HERO, then tap a relic for its stats and upgrade costs. A red dot appears only when an upgrade is available.", "Kamu sudah memiliki equipment permanen. Buka HERO, lalu ketuk relik untuk melihat stat dan biaya upgrade. Titik merah muncul hanya jika upgrade tersedia."),
  _local("ASCEND STAR consumes one identical duplicate and keeps the main item. Maximum 5 stars; rarity stays the same. No duplicate? Keep collecting.", "NAIK BINTANG memakai satu duplikat identik; item utama tetap dimiliki. Maksimum 5 bintang dan rarity tetap. Belum ada duplikat? Lanjutkan mengumpulkan."),
  _local("Weapon LEVEL UP costs Spirit Stones. Star ranks cap permanent levels at 10 / 20 / 30 / 40 / 50. This is separate from Lv.1–7 skill refinement inside a run. Four armor/accessory pieces form a set; the weapon is independent.", "NAIK LEVEL senjata memakai Spirit Stone. Batas level permanen menurut bintang: 10 / 20 / 30 / 40 / 50. Ini terpisah dari refinement skill Lv.1–7 saat run. Empat armor/aksesori membentuk set; senjata berdiri sendiri.")
 ]
 return {"title": titles[step], "body": copy[step], "button": _local("OPEN HERO", "BUKA HERO") if step == 0 else (_local("DONE", "SELESAI") if step == 2 else _local("NEXT", "LANJUT")), "counter": "JADE ASCENSION · %d / 3" % (step + 1)}

func _show_guide(scene: Node) -> void:
 scene_id = scene.get_instance_id()
 popup = Control.new(); popup.name = "RefineOnboarding"; popup.z_index = 225
 scene.add_child(popup); popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var scrim := ColorRect.new(); scrim.color = Color(.002, .015, .022, .58); popup.add_child(scrim)
 scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scrim.mouse_filter = Control.MOUSE_FILTER_STOP
 var panel := PanelContainer.new(); panel.name = "RefineGuideCard"; popup.add_child(panel)
 panel.anchor_left = .08; panel.anchor_right = .92; panel.anchor_top = .5; panel.anchor_bottom = .5
 var skin := StyleBoxFlat.new(); skin.bg_color = Color(.012, .063, .07, .99); skin.border_color = Color(.68, .88, .77, .8)
 skin.set_border_width_all(1); skin.set_corner_radius_all(16); skin.shadow_color = Color(.09, .55, .43, .16); skin.shadow_size = 12
 for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: skin.set_content_margin(side, 20)
 panel.add_theme_stylebox_override("panel", skin)
 var scroll := ScrollContainer.new(); scroll.name = "GuideScroll"; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; ScrollPolicy.configure(scroll); panel.add_child(scroll)
 var body := VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 14); scroll.add_child(body)
 var copy: Dictionary = guide_copy()
 _label(body, str(copy.counter), 13, Color(.45, .88, .77))
 var emblem := TextureRect.new(); emblem.texture = preload("res://assets/ui/main_menu/polish/sanctuary_medallion.svg")
 emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 emblem.custom_minimum_size = Vector2(60, 60); emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE; body.add_child(emblem)
 _label(body, str(copy.title), 23, Color(1, .86, .56)); _label(body, str(copy.body), 16, Color(.86, .95, .92))
 var button := Button.new(); button.name = "GuideContinue"; button.text = str(copy.button)
 button.custom_minimum_size.y = 52; button.focus_mode = Control.FOCUS_NONE; body.add_child(button)
 for state: String in ["normal", "hover", "pressed"]:
  var texture_style := StyleBoxTexture.new()
  texture_style.texture = load("res://assets/ui/system_v2/custom/buttons/primary_%s.svg" % ("pressed" if state == "pressed" else "normal")) as Texture2D
  texture_style.texture_margin_left = 18; texture_style.texture_margin_right = 18; texture_style.texture_margin_top = 12; texture_style.texture_margin_bottom = 12
  button.add_theme_stylebox_override(state, texture_style)
 button.pressed.connect(_continue.bind(step, popup.get_instance_id()))
 SceneTransitionManager.set_back_handler(Callable(self, "_finish"))
 panel.modulate.a = 0.0
 var tween := panel.create_tween(); tween.tween_property(panel, "modulate:a", 1.0, .2)
 _fit_card.call_deferred(panel, body, scene_id)

func _label(body: VBoxContainer, copy: String, font_size: int, tint: Color) -> void:
 var label := Label.new(); label.text = copy; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_color_override("font_color", tint); body.add_child(label)

func _fit_card(panel: Variant, body: Variant, expected_scene: int) -> void:
 await get_tree().process_frame
 await get_tree().process_frame
 if not is_instance_valid(panel) or not is_instance_valid(body) or scene_id != expected_scene: return
 var height: float = minf(body.get_combined_minimum_size().y + 40, get_viewport().get_visible_rect().size.y * .66)
 panel.offset_top = -height * .5; panel.offset_bottom = height * .5

func _continue(expected_step: int = -1, expected_popup: int = 0) -> void:
 if not is_instance_valid(popup) or popup.is_queued_for_deletion(): return
 if expected_step >= 0 and (step != expected_step or popup.get_instance_id() != expected_popup): return
 if SaveManager.is_progress_read_only() or SceneTransitionManager.is_transitioning: return
 if empty_mode:
  # Re-evaluate after the tap: inventory/costs may have changed while visible.
  if not owned_equipment_ids().is_empty():
   empty_mode = false; step = 0
   var refreshed_scene: Node = get_tree().current_scene
   _dismiss(false)
   if refreshed_scene != null: _show_guide(refreshed_scene)
   return
  var destination: String = CULTIVATION if has_affordable_cultivation() else JOURNEY
  if not _save_mark("empty_explained"): return
  empty_explained = true; _dismiss(true)
  SceneTransitionManager.transition_menu_to(destination); return
 if step == 0:
  step = 1; _dismiss(false); SceneTransitionManager.transition_menu_to(HERO); return
 if step == 2: _finish(); return
 step += 1
 var scene: Node = get_tree().current_scene
 _dismiss(false)
 if scene != null: _show_guide(scene)

func _save_mark(key: String) -> bool:
 var config := ConfigFile.new()
 config.load(SAVE_PATH)
 config.set_value("refine", key, true)
 return config.save(SAVE_PATH) == OK

func _finish() -> void:
 if empty_mode:
  if not _save_mark("empty_explained"): return
  empty_explained = true
 else:
  if completed or not _save_mark("completed"): return
  completed = true
 _dismiss(true)

func _dismiss(restore_back: bool) -> void:
 if is_instance_valid(popup): popup.queue_free()
 popup = null
 if restore_back:
  var scene: Node = get_tree().current_scene
  if scene != null and scene.has_method("handle_system_back"): SceneTransitionManager.set_back_handler(Callable(scene, "handle_system_back"))
