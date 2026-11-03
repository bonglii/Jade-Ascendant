extends "res://scripts/ui/pavilion_sanctum_screen.gd"
## Approved Pavilion redesign. All spending still uses the existing managers.
const ScrollPolicy = preload("res://scripts/ui/mobile_scroll_policy.gd")
var focus_pages: Dictionary = {}
var focus_tabs: Dictionary = {}
var focus_tab: String = "summon"
var paid_mode: bool = false
var _focus_daily: Button
var _focus_modes: Array[Button] = []
var _focus_normal_row: Control
var _focus_paid_note: Label
var _focus_use_seals: Button
var _focus_target: Button
var _focus_armory: Button
var _focus_sheet: ColorRect
var _focus_sheet_kind: String = ""
var _focus_aura_preview: Control
var _focus_aura_grid: GridContainer
var _focus_aura_name: Label
var _focus_aura_info: Label
var _focus_aura_action: Button
var _focus_aura_id: String = "plain"
var _focus_aura_buttons: Dictionary = {}
var _focus_result_stats: Label
var _focus_result_hero: Button
var _focus_mutation_busy: bool = false

func _unit() -> float:
	return clampf(size.x / 400.0, 0.80, 1.65)

func _copy(indonesian: String, english: String) -> String:
	return indonesian if SettingsManager.language == "id" else english

func _label(parent_node: Node, value: String, font_size: int = 16, tint: Color = TEXT_MUTED) -> Label:
	var label: Label = super(parent_node, value, maxi(12, int(float(font_size) * _unit())), tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(parent_node: Node, value: String, callback: Callable, primary: bool, accent: Color) -> Button:
	var button: Button = super(parent_node, value, callback, primary, accent)
	button.custom_minimum_size = Vector2(0.0, 44.0 * _unit())
	button.add_theme_font_size_override("font_size", maxi(12, int(15.0 * _unit())))
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	return button

func _build_hero_header() -> void:
	_install_palace_background()
	var heading := HBoxContainer.new()
	content.add_child(heading)
	_label(heading, _copy("Paviliun", "Pavilion"), 26, GOLD)
	_focus_daily = _button(heading, "", _open_daily, false, JADE)
	_focus_daily.name = "PavilionDaily"
	# A compact HBox action must retain the natural width of its caption.
	# Wrapping + SHRINK_END collapses it to the skin margins and grows a column.
	_focus_daily.autowrap_mode = TextServer.AUTOWRAP_OFF
	_focus_daily.size_flags_horizontal = Control.SIZE_SHRINK_END
	var more: Button = _button(heading, "...", _open_privacy, false, JADE_SOFT)
	more.name = "PavilionMore"
	more.autowrap_mode = TextServer.AUTOWRAP_OFF
	more.custom_minimum_size.x = 44.0 * _unit()
	more.size_flags_horizontal = Control.SIZE_SHRINK_END
	more.tooltip_text = tr("PRIVACY & SUPPORT")
	var tabs := HBoxContainer.new()
	tabs.name = "PavilionTabs"
	content.add_child(tabs)
	var available_pages: Array[String] = ["summon"]
	if PavilionManager.is_aura_feature_enabled(): available_pages.append("aura")
	tabs.visible = available_pages.size() > 1
	for key: String in available_pages:
		var caption: String = {"summon":"Summon", "aura":"Aura"}[key]
		var tab: Button = _button(tabs, caption, _select_focus_tab.bind(key), key == focus_tab, GOLD)
		tab.name = "PavilionTab_" + key
		focus_tabs[key] = tab
	for key: String in available_pages:
		var page := VBoxContainer.new()
		page.name = "PavilionPage_" + key
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", int(10.0 * _unit()))
		page.visible = key == focus_tab
		content.add_child(page)
		focus_pages[key] = page

func _finish_pavilion_initialization(startup_started_at: int) -> void:
	if _initial_ui_ready or not is_inside_tree(): return
	_initial_ui_ready = true
	scroll_container = $SafeArea/Scroll
	ScrollPolicy.configure(scroll_container)
	_build_status_banner()
	content.move_child(status_panel, 2)
	_build_summon_section()
	# Preserve ad callbacks and readiness; the legacy service panel stays hidden.
	_build_rewarded_seal_section()
	if is_instance_valid(rewarded_seal_panel): rewarded_seal_panel.visible = false
	if not PavilionManager.pavilion_changed.is_connected(_refresh): PavilionManager.pavilion_changed.connect(_refresh)
	_refresh()
	ScrollPolicy.prepare_tree(content)
	scroll_container.visible = true
	DebugLogger.system("Pavilion focused UI ready | %d ms" % (Time.get_ticks_msec() - startup_started_at))

func _build_summon_section() -> void:
	_load_featured_items()
	locked_root = VBoxContainer.new()
	locked_root.name = "FocusedSummon"
	locked_root.add_theme_constant_override("separation", int(8.0 * _unit()))
	focus_pages.summon.add_child(locked_root)
	var modes := HBoxContainer.new()
	locked_root.add_child(modes)
	for use_paid: bool in [false, true]:
		var caption: String = _copy("Jade Berbayar", "Paid Jade") if use_paid else _copy("Jade & Segel", "Jade & Seals")
		var action: Button = _button(modes, caption, _select_summon_mode.bind(use_paid), not use_paid, JADE)
		_focus_modes.append(action)
	_build_title_and_banner()
	_build_featured_selector()
	_build_focal_ritual()
	_build_legendary_mandate()
	_build_summon_ctas()
	_focus_normal_row = summon_one_button.get_parent()
	_build_utility_rows()
	starter_button = _button(locked_root, tr("CLAIM INITIATE GIFT • +10 PAVILION SEALS"), _claim_starter_seals, false, JADE)
	starter_button.visible = false

func _build_title_and_banner() -> void:
	_banner_title = _label(locked_root, "", 15, GOLD)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_subtitle = _label(locked_root, "", 12, TEXT_MUTED)
	_banner_subtitle.visible = false

func _build_focal_ritual() -> void:
	sanctum_shell = _panel(locked_root, _production_clear_focus_style())
	sanctum_stage = SanctumStage.new()
	sanctum_stage.name = "InteractiveSanctum"
	sanctum_stage.preview_mode = true
	sanctum_stage.background_visible = false
	sanctum_stage.custom_minimum_size.y = 160.0 * _unit()
	sanctum_shell.add_child(sanctum_stage)
	focal_icon = TextureRect.new()
	focal_icon.visible = false
	sanctum_stage.add_child(focal_icon)
	_focal_tag = _label(locked_root, "", 12, GOLD)
	_focal_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focal_name = _label(locked_root, "", 20, TEXT_MAIN)
	focal_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh_focal_item()

func _build_featured_selector() -> void:
	_lock_notice = _label(locked_root, "", 14, GOLD)
	featured_row = HBoxContainer.new()
	featured_row.visible = false
	locked_root.add_child(featured_row)
	var row := HBoxContainer.new()
	locked_root.add_child(row)
	_focus_target = _button(row, _copy("Ganti target ›", "Change target ›"), _open_target_picker, false, GOLD)
	_focus_target.name = "BrowseWishTargets"
	_focus_target.autowrap_mode = TextServer.AUTOWRAP_OFF
	_focus_target.size_flags_horizontal = Control.SIZE_SHRINK_END
	_label(row, _copy("Pilih satu Legendary", "Choose one Legendary"), 12, TEXT_MUTED)

func _rebuild_featured_selector() -> void:
	# The complete catalog remains in the picker; avoid duplicate target strips.
	return

func _build_paid_summons() -> void:
	_paid_status = _label(summon_controls_stack, "", 13, JADE)
	var row := HBoxContainer.new()
	summon_controls_stack.add_child(row)
	row.add_theme_constant_override("separation", 10)
	for count: int in [1, 10]:
		var cost: int = 100 if count == 1 else 900
		var action: Button = _button(row, "Summon ×%d\n%d %s" % [count, cost, _copy("Jade berbayar", "paid Jade")], _summon_paid.bind(count), true, GOLD)
		action.custom_minimum_size.y = 66.0 * _unit()
		_paid_buttons.append(action)
	_focus_paid_note = _label(summon_controls_stack, "", 12, TEXT_MUTED)
	_focus_use_seals = _button(summon_controls_stack, _copy("Gunakan Segel dulu ›", "Use Seals first ›"), _select_summon_mode.bind(false), false, JADE)
	_trial_seal_button = _button(summon_controls_stack, "", _summon_trial_seal, false, GOLD)
	_focus_armory = _button(summon_controls_stack, _copy("Perlengkapan server ›", "Server equipment ›"), _open_server_armory, false, JADE)
	var trials: Node = get_node_or_null("/root/HeavenlyTrialsClient")
	if trials != null and not trials.is_connected("changed", _refresh_paid_summons): trials.connect("changed", _refresh_paid_summons)
	if is_instance_valid(PavilionManager.paid_gameplay): PavilionManager.paid_gameplay.connect("changed", _refresh)
	if not PavilionManager.paid_summon_finished.is_connected(_on_paid_summon_finished): PavilionManager.paid_summon_finished.connect(_on_paid_summon_finished)

func _build_utility_rows() -> void:
	_build_paid_summons()
	locked_watch_ad_button = _button(summon_controls_stack, tr("WATCH AD • FREE 1× SUMMON"), _request_locked_rewarded_ad, false, JADE)
	_ad_hint = _label(summon_controls_stack, "", 12, TEXT_MUTED)
	_banner_notice = _label(summon_controls_stack, "", 12, GOLD)
	_banner_notice.visible = false
	var row := HBoxContainer.new()
	summon_controls_stack.add_child(row)
	rates_button = _button(row, _copy("Peluang", "Odds"), _show_drop_rates_overlay, false, JADE_SOFT)
	_button(row, _copy("Riwayat", "History"), _show_history_overlay, false, JADE_SOFT)
	_button(row, _copy("Info", "Info"), _open_mode_info, false, JADE_SOFT)
	_button(summon_controls_stack,_copy("Target koleksi & build ›","Collection target & build ›"),func():load("res://scripts/experience/menu_guide.gd").open(self,"pavilion"),false,JADE)

func _refresh() -> void:
	if not is_instance_valid(_focus_daily) or not is_instance_valid(locked_root): return
	_sync_wallet_balances()
	_refresh_status()
	_refresh_summon_panel()
	_refresh_rewarded_seal_section()
	_focus_daily.text = _copy("Harian +20", "Daily +20") if PavilionManager.can_claim_meditation() else _copy("Harian ✓", "Daily ✓")
	_rebuild_auras()

func _refresh_summon_panel() -> void:
	super()
	if not is_instance_valid(_focus_target): return
	_focus_target.get_parent().visible = true
	_focus_target.disabled = paid_mode and (not is_instance_valid(PavilionManager.paid_gameplay) or not PavilionManager.paid_gameplay.is_verified_ready() or PavilionManager.paid_gameplay.busy)
	_banner_title.visible = not paid_mode and not PavilionManager.get_banner_configuration().is_empty()
	if paid_mode:
		var target: String = _target_picker_id()
		_focal_tag.text = _copy("TARGET · JADE BERBAYAR", "TARGET · PAID JADE")
		focal_name.text = _item_display_name(target) if not target.is_empty() else _copy("Pilih target Legendary", "Choose a Legendary target")
		sanctum_stage.set_relic(_load_item_texture(target) if not target.is_empty() else load("res://assets/ui/pavilion/icons/reward_chest.png"), "legendary")
		var paid: Node = PavilionManager.paid_gameplay
		var verified: bool = is_instance_valid(paid) and paid.is_verified_ready()
		var snapshot: Dictionary = paid.snapshot if is_instance_valid(paid) else {}
		var counter: int = int(snapshot.get("pity", {}).get("legendary", 0))
		legendary_bar.value = counter if verified else 0
		legendary_value.text = "%d / 50" % counter if verified else "… / 50"
		legendary_remaining.text = (_copy("Jaminan terpisah · paling lambat %d summon lagi.", "Separate guarantee · within %d more summons.") % maxi(50 - counter, 0)) if verified else _copy("Hubungkan akun untuk memeriksa progres jaminan.", "Connect your account to verify guarantee progress.")
		if verified and not target.is_empty():
			legendary_remaining.text += "\n" + (_copy("Wish Fate aktif · Legendary berikutnya sesuai target.", "Wish Fate active · next Legendary matches your target.") if bool(snapshot.get("wish_guaranteed", false)) else _copy("Wish Fate · Target dan progres terpisah dari Jade & Segel.", "Wish Fate · Target and progress are separate from Jade & Seals."))
		_banner_notice.visible = false
	_fit_sanctum()

func _refresh_paid_summons() -> void:
	super()
	if not is_instance_valid(_focus_paid_note): return
	var owns_seals: bool = PavilionManager.get_pavilion_seals() > 0
	_focus_normal_row.visible = not paid_mode
	_paid_buttons[0].get_parent().visible = paid_mode
	_paid_status.visible = paid_mode
	var view: Dictionary = PavilionManager.get_server_jade_view()
	_paid_status.text = _copy("Jade berbayar: ", "Paid Jade: ") + (_format_count(int(view.balance)) if int(view.get("balance", -1)) >= 0 else "…")
	_focus_paid_note.visible = paid_mode
	_focus_paid_note.text = _copy("Segel biasa dipakai lebih dulu. Saldo berbayar tetap tersimpan.", "Use regular Seals first. Your paid balance is retained.") if owns_seals else _copy("Pilih target Legendary di atas. Target dan jaminan Jade berbayar tersimpan terpisah.", "Choose a Legendary target above. Paid Jade target and guarantee are retained separately.")
	_focus_use_seals.visible = paid_mode and owns_seals
	for action: Button in _paid_buttons:
		action.disabled = action.disabled or owns_seals
	_trial_seal_button.visible = _trial_seal_button.visible and paid_mode
	_focus_armory.visible = false
	if is_instance_valid(locked_watch_ad_button): locked_watch_ad_button.visible = not paid_mode
	if is_instance_valid(_ad_hint): _ad_hint.visible = not paid_mode
	if is_instance_valid(starter_button): starter_button.visible = not paid_mode and PavilionManager.can_claim_starter_seals()
	for index: int in range(_focus_modes.size()): _apply_button_style(_focus_modes[index], GOLD if index == 1 else JADE, paid_mode == (index == 1))

func _summon_paid(count: int) -> void:
	# Never silently turn an explicit paid-mode tap into a different transaction.
	if PavilionManager.get_pavilion_seals() > 0:
		_set_status(_copy("Gunakan Segel biasa terlebih dahulu.", "Use your regular Seals first."), GOLD)
		return
	super(count)

func _select_summon_mode(use_paid: bool) -> void:
	if _paid_reveal_busy or (is_instance_valid(summon_reveal_overlay) and summon_reveal_overlay.visible): return
	_close_focus_sheet()
	_close_target_picker()
	_close_rates_overlay()
	_close_history_overlay()
	paid_mode = use_paid
	if paid_mode and is_instance_valid(PavilionManager.paid_gameplay):
		PavilionManager.paid_gameplay.refresh_if_stale()
	_refresh_summon_panel()

func _select_focus_tab(key: String) -> void:
	if not focus_pages.has(key) or _paid_reveal_busy or (is_instance_valid(summon_reveal_overlay) and summon_reveal_overlay.visible): return
	_close_focus_sheet()
	_close_target_picker()
	_close_rates_overlay()
	_close_history_overlay()
	focus_tab = key
	for page_key: String in focus_pages:
		focus_pages[page_key].visible = page_key == key
		_apply_button_style(focus_tabs[page_key], GOLD, page_key == key)
	if key == "aura" and not is_instance_valid(_focus_aura_preview): _build_aura_section()
	_refresh()
	scroll_container.scroll_vertical = 0
	ScrollPolicy.prepare_tree(content)
	if is_instance_valid(sanctum_stage): sanctum_stage.set_process(key == "summon" and not SettingsManager.reduced_effects)

func _open_server_armory() -> void:
	_close_focus_sheet()
	SceneTransitionManager.transition_menu_to("res://scenes/ui/equipment_screen.tscn", 1)

func _new_focus_sheet(title_text: String, kind: String) -> VBoxContainer:
	_close_focus_sheet()
	_close_target_picker()
	_close_rates_overlay()
	_close_history_overlay()
	_focus_sheet = _build_modal_overlay(title_text)
	_focus_sheet_kind = kind
	var footer: VBoxContainer = _focus_sheet.get_meta("footer")
	_button(footer, _copy("Tutup", "Close"), _close_focus_sheet, false, JADE_SOFT)
	return _focus_sheet.get_meta("content")

func _close_focus_sheet() -> void:
	if is_instance_valid(_focus_sheet):
		_focus_sheet.get_parent().remove_child(_focus_sheet)
		_focus_sheet.queue_free()
	_focus_sheet = null
	_focus_sheet_kind = ""

func _open_daily() -> void:
	var body: VBoxContainer = _new_focus_sheet(_copy("Meditasi harian", "Daily meditation"), "daily")
	_label(body, _copy("Luangkan waktu untuk bermeditasi. Hadiah: +20 Batu Roh.", "Take a moment to meditate. Reward: +20 Spirit Stones."), 15, TEXT_MAIN)
	var cadence: Dictionary = PavilionManager.get_cadence_status()
	_label(body, _copy("Siklus Daily Quest: %d/%d hari aktif.", "Daily Quest cycle: %d/%d active days.") % [int(cadence.get("active_days", 0)), int(cadence.get("cycle_length", 7))], 13, TEXT_MUTED)
	var action: Button = _button(body, _copy("Klaim +20 Batu Roh", "Claim +20 Spirit Stones") if PavilionManager.can_claim_meditation() else _copy("Sudah diklaim hari ini", "Claimed today"), _claim_focus_daily, true, JADE)
	action.name = "ClaimDaily"
	action.disabled = not PavilionManager.can_claim_meditation()

func _claim_focus_daily() -> void:
	if _focus_mutation_busy or not PavilionManager.can_claim_meditation(): return
	_focus_mutation_busy = true
	_close_focus_sheet()
	_meditate()
	_focus_mutation_busy = false
	_refresh()

func _open_mode_info() -> void:
	var body: VBoxContainer = _new_focus_sheet(_copy("Tentang summon", "About summons"), "info")
	if paid_mode:
		_label(body, _copy("Pilih senjata atau equipment Legendary dengan Ganti Target. Wish Fate dan progres jaminan berbayar tersimpan terpisah dari Jade & Segel.", "Choose a Legendary weapon or equipment using Change Target. Paid Wish Fate and guarantee progress are retained separately from Jade & Seals."), 15, TEXT_MAIN)
	else:
		_label(body, _copy("Segel digunakan lebih dulu. Untuk ×10, sisa summon setelah Segel memakai harga Jade yang telah didiskon. Biaya tepat terlihat pada tombol.", "Seals are used first. For ×10, remaining pulls use the discounted Jade price. The exact cost is shown on the button."), 15, TEXT_MAIN)
		_label(body, _copy("Jaminan Legendary berlaku pada rarity. Wish Fate mengatur target: jika Legendary meleset dari target, Legendary berikutnya cocok dengan target. Mengganti target mereset Fate.", "The Legendary guarantee concerns rarity. Wish Fate governs the target: after missing it, the next Legendary matches your target. Changing target resets Fate."), 14, TEXT_MUTED)
	_label(body, _copy("Duplikat perlengkapan disimpan sebagai salinan untuk kenaikan bintang. Level senjata dan bintang merupakan progres terpisah.", "Equipment duplicates are retained as copies for star ascension. Weapon levels and stars progress separately."), 14, TEXT_MUTED)

func _show_drop_rates_overlay() -> void:
	if not paid_mode:
		_close_focus_sheet()
		super()
		return
	var body: VBoxContainer = _new_focus_sheet(_copy("Peluang · Summon Standar", "Odds · Standard Summon"), "paid_odds")
	_label(body, "Common 60% · Rare 29%\nEpic 9% · Legendary 2%", 16, TEXT_MAIN)
	_label(body, _copy("Jaminan: Rare+ pada 10, Epic+ pada 30, Legendary pada 50. Progres terpisah dari Jade & Segel. Target Legendary: 50% saat Legendary, dijamin setelah meleset atau pada pity 50.", "Guarantees: Rare+ at 10, Epic+ at 30, Legendary at 50. Progress is separate from Jade & Seals. Legendary target: 50% on Legendary, guaranteed after a miss or at pity 50."), 14, TEXT_MUTED)

func _show_history_overlay() -> void:
	_close_focus_sheet()
	super()

func _target_picker_id() -> String:
	if not paid_mode: return super()
	var paid: Node = PavilionManager.paid_gameplay
	return str(paid.snapshot.get("wish", "")) if is_instance_valid(paid) and paid.is_verified_ready() else ""

func _target_picker_options() -> Array[String]:
	if not paid_mode: return super()
	var ids: Array[String] = []
	for id: String in EquipmentManager.get_item_ids():
		var data: Dictionary = EquipmentManager.get_item_data(id)
		if data.get("rarity", "") == "legendary" and not bool(data.get("event_only", false)): ids.append(id)
	return ids

func _open_target_picker(category: String = "") -> void:
	if paid_mode and (not is_instance_valid(PavilionManager.paid_gameplay) or not PavilionManager.paid_gameplay.is_verified_ready() or PavilionManager.paid_gameplay.busy): return
	_close_focus_sheet()
	super(category)

func _choose_browser_target(id: String, epoch: int = -1) -> void:
	if epoch >= 0 and epoch != _target_epoch: return
	if not is_instance_valid(_target_overlay) or id not in _target_picker_options(): return
	if get_global_mouse_position().distance_to(_target_press_pos) > 12 or absi((_target_overlay.get_meta("scroll") as ScrollContainer).scroll_vertical - _target_scroll_start) > 8: return
	var old_target: String = _target_picker_id()
	if id == old_target: _close_target_picker(); return
	var body: VBoxContainer = _new_focus_sheet(_copy("Ganti target?", "Change target?"), "target_confirm")
	_label(body, _item_display_name(id), 19, GOLD)
	_label(body, _copy("Mengganti target mereset Wish Fate. Hitungan jaminan rarity tetap tersimpan.", "Changing target resets Wish Fate. Rarity guarantee counters are retained."), 14, TEXT_MAIN)
	var action: Button = _button(body, _copy("Pilih target ini", "Choose this target"), _confirm_focus_target.bind(id, old_target, paid_mode), true, GOLD)
	action.name = "ConfirmWishTarget"
	action.disabled = SaveManager.is_progress_read_only()

func _confirm_focus_target(id: String, old_target: String, expected_paid: bool = false) -> void:
	if _focus_mutation_busy or paid_mode != expected_paid or _target_picker_id() != old_target: _close_focus_sheet(); return
	_focus_mutation_busy = true
	_close_focus_sheet()
	if paid_mode:
		if not PavilionManager.paid_gameplay.submit("wish", {"item_id":id}): _set_status(_copy("Belum tersimpan. Periksa koneksi lalu coba lagi.", "Not saved. Check your connection and retry."), GOLD)
	elif PavilionManager.set_wish_target(id): selected_rate_up_item_id = id
	_focus_mutation_busy = false
	_refresh_summon_panel()

func _build_forge_section() -> void: pass
func _rebuild_equipment() -> void: pass
func _open_equipment_detail(_id: String) -> void: pass

func _build_aura_section() -> void:
	if not PavilionManager.is_aura_feature_enabled() or not focus_pages.has("aura"): return
	var page: VBoxContainer = focus_pages.aura
	_label(page, _copy("Aura kultivasi", "Cultivation aura"), 22, GOLD)
	_label(page, _copy("Hanya penampilan · tidak menambah atribut.", "Cosmetic only · no stat bonus."), 13, TEXT_MUTED)
	_focus_aura_preview = load("res://scripts/ui/pavilion_aura_preview.gd").new()
	_focus_aura_preview.name = "AuraOnHeroPreview"
	_focus_aura_preview.custom_minimum_size.y = 210.0 * _unit()
	page.add_child(_focus_aura_preview)
	_focus_aura_name = _label(page, "", 19, GOLD)
	_focus_aura_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_aura_grid = GridContainer.new()
	_focus_aura_grid.columns = 2
	_focus_aura_grid.add_theme_constant_override("h_separation", 8)
	_focus_aura_grid.add_theme_constant_override("v_separation", 8)
	page.add_child(_focus_aura_grid)
	for id: String in PavilionManager.COSMETICS:
		var action: Button = _button(_focus_aura_grid, "", _preview_focus_aura.bind(id), false, JADE)
		action.name = "AuraChoice_" + id
		action.custom_minimum_size.y = 60.0 * _unit()
		_focus_aura_buttons[id] = action
	_focus_aura_info = _label(page, "", 14, TEXT_MUTED)
	_focus_aura_action = _button(page, "", _apply_focus_aura, true, JADE)
	_focus_aura_action.name = "ApplyAura"
	_focus_aura_id = PavilionManager.get_cosmetic_id()

func _preview_focus_aura(id: String) -> void:
	if not PavilionManager.is_aura_feature_enabled(): return
	if not PavilionManager.COSMETICS.has(id): return
	_focus_aura_id = id
	_rebuild_auras()

func _rebuild_auras() -> void:
	if focus_tab != "aura" or not is_instance_valid(_focus_aura_preview): return
	_focus_aura_preview.show_aura(_focus_aura_id)
	_focus_aura_name.text = tr(str(PavilionManager.get_cosmetic_data(_focus_aura_id).get("name", "")))
	for id: String in _focus_aura_buttons:
		var action: Button = _focus_aura_buttons[id]
		var state: String = _copy("Terpasang", "Equipped") if id == PavilionManager.get_cosmetic_id() else (_copy("Dimiliki", "Owned") if PavilionManager.is_cosmetic_owned(id) else (_copy("Tersedia", "Available") if PavilionManager.is_cosmetic_unlocked(id) else _copy("Terkunci", "Locked")))
		action.text = tr(str(PavilionManager.get_cosmetic_data(id).get("name", id))) + "\n" + state
		_apply_button_style(action, GOLD if _focus_aura_id == id else JADE_SOFT, _focus_aura_id == id)
	var definition: Dictionary = PavilionManager.get_cosmetic_data(_focus_aura_id)
	var price: int = int(PavilionManager.get_cosmetic_cost(_focus_aura_id).get("spirit_stone", 0))
	var current: bool = _focus_aura_id == PavilionManager.get_cosmetic_id()
	var unlocked: bool = PavilionManager.is_cosmetic_unlocked(_focus_aura_id)
	var owned: bool = PavilionManager.is_cosmetic_owned(_focus_aura_id)
	_focus_aura_info.text = _copy("Pilih aura untuk mencobanya pada hero.", "Select an aura to preview it on your hero.")
	if not unlocked:
		_focus_aura_info.text = _copy("Syarat: selesaikan stage %d–%d.", "Requirement: clear stage %d–%d.") % [int(definition.get("chapter", 0)), int(definition.get("stage", 0))]
		var required: String = str(definition.get("requires_cosmetic", ""))
		if not required.is_empty(): _focus_aura_info.text += "\n" + _copy("Memerlukan ", "Requires ") + tr(str(PavilionManager.get_cosmetic_data(required).get("name", required)))
	elif not owned and price > 0:
		_focus_aura_info.text = _copy("Biaya: %s Batu Roh · Saldo: %s", "Cost: %s Spirit Stones · Balance: %s") % [_format_count(price), _format_count(ProgressionManager.spirit_stone)]
		if ProgressionManager.spirit_stone < price: _focus_aura_info.text += "\n" + _copy("Masih kurang %s Batu Roh.", "Need %s more Spirit Stones.") % _format_count(price - ProgressionManager.spirit_stone)
	_focus_aura_action.text = _copy("Sudah terpasang", "Equipped") if current else (_copy("Buka & pakai · %s Batu Roh", "Unlock & equip · %s Spirit Stones") % _format_count(price) if not owned and price > 0 else _copy("Pakai aura", "Equip aura"))
	_focus_aura_action.disabled = current or not unlocked or SaveManager.is_progress_read_only() or (not owned and price > ProgressionManager.spirit_stone)

func _apply_focus_aura() -> void:
	if not PavilionManager.is_aura_feature_enabled(): return
	if _focus_mutation_busy or _focus_aura_action.disabled: return
	_focus_mutation_busy = true
	_select_cosmetic(_focus_aura_id)
	_focus_mutation_busy = false
	_refresh()

func _build_summon_reveal_overlay() -> void:
	if is_instance_valid(summon_reveal_overlay): return
	super()
	_focus_result_stats = _label(_result_details, "", 14, TEXT_MAIN)
	_focus_result_stats.name = "RevealedEquipmentBenefits"
	_focus_result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_result_stats.visible = false
	_focus_result_hero = _button(_reveal_box, _copy("Lihat & pasang di Hero ›", "View & equip in Hero ›"), _open_focus_hero, false, JADE)
	_focus_result_hero.name = "RevealedHeroAction"
	_focus_result_hero.visible = false
	ScrollPolicy.prepare_tree(summon_reveal_overlay)

func _hide_result_identity() -> void:
	super()
	if is_instance_valid(_focus_result_stats): _focus_result_stats.text = ""; _focus_result_stats.visible = false
	if is_instance_valid(_focus_result_hero): _focus_result_hero.visible = false

func _show_landed_entry(entry: Dictionary) -> void:
	super(entry)
	var id: String = str(entry.get("item_id", ""))
	_focus_result_stats.text = EquipmentVisualCatalog.get_stat_summary(EquipmentManager.get_item_data(id))
	_focus_result_stats.visible = true
	_focus_result_hero.visible = true
	_fit_sanctum()

func _build_formation() -> void:
	super()
	_focus_result_stats.visible = false
	_focus_result_hero.visible = _formation_opened.size() == summon_reveal_entries.size()

func _paint_formation_seal(index: int) -> void:
	super(index)
	if is_instance_valid(_focus_result_hero): _focus_result_hero.visible = _formation_opened.size() == summon_reveal_entries.size()

func _open_focus_hero() -> void:
	if SceneTransitionManager.is_transitioning or _paid_reveal_busy or summon_reveal_busy: return
	_close_focus_sheet()
	if is_instance_valid(summon_reveal_overlay) and summon_reveal_overlay.visible: _finish_summon_reveal()
	SceneTransitionManager.transition_menu_to("res://scenes/ui/equipment_screen.tscn")

func _fit_sanctum() -> void:
	super()
	if is_instance_valid(sanctum_stage): sanctum_stage.custom_minimum_size.y = clampf(size.y * 0.22, 130.0 * _unit(), 200.0 * _unit())
	if is_instance_valid(summon_one_button):
		for action: Button in [summon_one_button, summon_ten_button]:
			action.custom_minimum_size.y = 66.0 * _unit()
			action.add_theme_font_size_override("font_size", int(15.0 * _unit()))
	if is_instance_valid(_reveal_stage):
		_reveal_stage.custom_minimum_size.y = 56.0 * _unit()
		_result_details.custom_minimum_size.y = 0
		_result_name.add_theme_font_size_override("font_size", int(20.0 * _unit()))

func _fit_compact_popup(overlay: ColorRect, panel: PanelContainer, root_box: VBoxContainer, sc: ScrollContainer, body: VBoxContainer, footer: VBoxContainer, generation: int) -> void:
	await get_tree().process_frame
	if not is_instance_valid(overlay) or overlay.is_queued_for_deletion() or int(overlay.get_meta("fit_generation", 0)) != generation: return
	var width: float = minf(560.0 * _unit(), overlay.size.x - 24.0)
	var skin: StyleBox = panel.get_theme_stylebox("panel")
	body.custom_minimum_size.x = maxf(0.0, width - skin.get_minimum_size().x - 12.0)
	var choices: GridContainer = body.get_node_or_null("TargetChoices")
	if choices != null: choices.columns = 1 if overlay.size.x < 600 else 2
	if body.get_child_count() > 0:
		var last: Node = body.get_child(body.get_child_count() - 1)
		if last is Button:
			body.remove_child(last)
			footer.add_child(last)
			footer.move_child(last, 0)
	for child: Node in body.get_children():
		if child is Label: child.add_theme_font_size_override("font_size", int(14.0 * _unit()))
	for child: Node in footer.get_children():
		if child is Button: child.custom_minimum_size.y = 44.0 * _unit()
	sc.custom_minimum_size.y = 0
	panel.size = Vector2(width, overlay.size.y * 0.72)
	panel.position.x = (overlay.size.x - width) * 0.5
	await get_tree().process_frame
	if not is_instance_valid(overlay) or overlay.is_queued_for_deletion() or int(overlay.get_meta("fit_generation", 0)) != generation: return
	var fixed: float = root_box.get_child(0).get_combined_minimum_size().y + footer.get_combined_minimum_size().y + skin.get_minimum_size().y + 20.0
	var height: float = minf(overlay.size.y * 0.74, maxf(fixed + 44.0, body.get_combined_minimum_size().y + fixed))
	sc.custom_minimum_size.y = maxf(44.0, height - fixed)
	panel.size = Vector2(width, height)
	panel.position.y = (overlay.size.y - height) * 0.5
	panel.modulate.a = 1.0
	ScrollPolicy.prepare_tree(overlay)

func _back() -> void:
	if is_instance_valid(_focus_sheet): _close_focus_sheet(); return
	if focus_tab != "summon": _select_focus_tab("summon"); return
	super()

func handle_system_back() -> void:
	_back()
