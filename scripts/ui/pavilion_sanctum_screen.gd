extends "res://scripts/ui/pavilion_fast_first_frame.gd"
## Approved ritual redesign. Managers remain the only grant/save authority.
const ImperialStyle = preload("res://scripts/ui/pavilion_imperial_style.gd")
var _trial_seal_button: Button
var _paid_status: Label
var _paid_buttons: Array[Button] = []
var _paid_reveal_busy: bool = false
var _paid_reveal_mode: bool = false
var _target_press_pos: Vector2
var _target_scroll_start: int=0
var _target_epoch: int=0
var _target_overlay: ColorRect
var _target_category: String="weapon"
var _sheet_guard_until: int=0
var _banner_title: Label
var _banner_subtitle: Label
var _banner_notice: Label
const SanctumStage = preload("res://scripts/ui/pavilion_sanctum_stage.gd")
var sanctum_stage
var sanctum_shell: PanelContainer
var _focal_tag: Label
var _focal_id: String = ""
var _selection_tween: Tween
var _reveal_stage
var _reveal_box: VBoxContainer
var _phase_copy: Label
var _result_name: Label
var _result_state: Label
var _formation: GridContainer
var _formation_scroll: ScrollContainer
var _formation_opened: Dictionary = {}
var _formation_mode: bool = false
var _ad_hint: Label
var _action_bank: VBoxContainer
var _formation_detail: bool = false
var _cinematic_entry: Dictionary = {}
var _landing_tween: Tween
var _stars_copy: Label
var _result_slot: Label
var _formation_background: TextureRect
const CELESTIAL_SEAL = preload("res://assets/ui/pavilion/sanctum_premium/celestial_seal.png")
func _ready() -> void:
	super()
	_build_summon_reveal_overlay()
	resized.connect(_fit_sanctum)
	_fit_sanctum()
	PavilionManager.banner_client.configuration_changed.connect(_banner_updated)
	PavilionManager.banner_client.watch(self)
func _build_title_and_banner() -> void:
	_banner_title = _label(locked_root,tr("JADE PAVILION"),26,GOLD)
	var title: Label = _banner_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_banner_subtitle = _label(locked_root,tr("THE ANCIENT SANCTUM"),12,TEXT_MUTED)
	var subtitle: Label = _banner_subtitle
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func _build_focal_ritual() -> void:
	sanctum_shell = _panel(locked_root,_production_clear_focus_style())
	sanctum_stage = SanctumStage.new()
	sanctum_stage.name = "InteractiveSanctum"
	sanctum_stage.preview_mode=true
	sanctum_stage.background_visible=false
	sanctum_stage.custom_minimum_size.y = 400.0
	sanctum_shell.add_child(sanctum_stage)
	# Keep inherited reference variables valid without stacking another icon.
	focal_icon = TextureRect.new()
	focal_icon.visible = false
	sanctum_stage.add_child(focal_icon)
	var caption := VBoxContainer.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.anchor_left = 0.04
	caption.anchor_right = 0.96
	caption.anchor_top = 0.80
	caption.anchor_bottom = 1.0
	sanctum_stage.add_child(caption)
	_focal_tag = _label(caption,tr("RATE-UP TARGET"),12,GOLD)
	_focal_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focal_name = _label(caption,"",20,TEXT_MAIN)
	focal_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focal_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_focal_item()
func _refresh_focal_item() -> void:
	super()
	if sanctum_stage == null or focal_icon == null: return
	var current: String = selected_rate_up_item_id
	if current.is_empty() and not featured_items.is_empty(): current = featured_items[0]
	_focal_tag.text = tr("FEATURED RELIC") if selected_rate_up_item_id.is_empty() else tr("RATE-UP TARGET")
	sanctum_stage.set_relic(focal_icon.texture,"legendary")
	if current == _focal_id: return
	_focal_id = current
	if _selection_tween != null: _selection_tween.kill()
	sanctum_stage.modulate = Color.WHITE
	if SettingsManager.reduced_effects: return
	sanctum_stage.modulate.a = 0.60
	_selection_tween = create_tween()
	_selection_tween.tween_property(sanctum_stage,"modulate:a",1.0,0.22)
func _build_featured_selector() -> void:
	featured_row = HBoxContainer.new()
	featured_row.add_theme_constant_override("separation",6)
	locked_root.add_child(featured_row)
	_rebuild_featured_selector()
func _rebuild_featured_selector() -> void:
	if featured_row == null: return
	if featured_row.get_child_count() != featured_items.size() or str(featured_row.get_meta("items",[]))!=str(featured_items):
		featured_row.set_meta("items",featured_items.duplicate())
		for child in featured_row.get_children():
			featured_row.remove_child(child)
			child.queue_free()
		for id: String in featured_items:
			var button := Button.new()
			button.name = id
			button.custom_minimum_size = Vector2(0,90)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.tooltip_text = _item_display_name(id)
			button.pressed.connect(_select_rate_up_item.bind(id))
			featured_row.add_child(button)
			var art := TextureRect.new()
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.texture = _load_item_texture(id)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			button.add_child(art)
			art.anchor_left=0.08;art.anchor_right=0.92;art.anchor_top=0.02;art.anchor_bottom=0.75
			var slot: String = str(EquipmentManager.get_item_data(id).get("slot",""))
			var copy := Label.new()
			copy.mouse_filter=Control.MOUSE_FILTER_IGNORE
			copy.text=tr("Weapon") if slot=="armament" else tr(slot.capitalize())
			copy.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			copy.add_theme_font_size_override("font_size",12)
			copy.add_theme_color_override("font_color",GOLD)
			copy.clip_text=true
			button.add_child(copy)
			copy.anchor_left=0.02;copy.anchor_right=0.98;copy.anchor_top=0.77;copy.anchor_bottom=0.99
	var options: Array[String] = PavilionManager.get_wish_target_options()
	for index in range(featured_items.size()):
		var button := featured_row.get_child(index) as Button
		var selected: bool = featured_items[index] == selected_rate_up_item_id
		button.disabled = featured_items[index] not in options or SaveManager.is_progress_read_only()
		button.modulate.a = 1.0 if not button.disabled else 0.46
		button.add_theme_stylebox_override("normal",_imperial_style(GOLD if selected else JADE_SOFT,selected,false,Vector2(14,14)))
		button.add_theme_stylebox_override("hover",_imperial_style(GOLD,true,false,Vector2(14,14)))
		button.add_theme_stylebox_override("pressed",_imperial_style(GOLD,true,true,Vector2(14,14)))
		button.add_theme_stylebox_override("disabled",_imperial_style(Color(0.4,0.5,0.46),false,false,Vector2(14,14)))
		button.add_theme_stylebox_override("focus",_focus_ring())

func _build_legendary_mandate() -> void:
	var shell: PanelContainer = _panel(locked_root,_relic_tile_style(JADE_SOFT,false))
	shell.add_theme_stylebox_override("panel",_imperial_style(JADE_SOFT,false,false,Vector2(22,24)))
	_action_bank = VBoxContainer.new()
	_action_bank.add_theme_constant_override("separation",8)
	shell.add_child(_action_bank)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",4)
	_action_bank.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	_label(row,tr("LEGENDARY GUARANTEE"),13,GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legendary_value = _label(row,"",13,TEXT_MAIN)
	legendary_value.size_flags_horizontal = Control.SIZE_SHRINK_END
	legendary_value.custom_minimum_size.x = 56
	legendary_bar = ProgressBar.new()
	legendary_bar.show_percentage = false
	legendary_bar.custom_minimum_size.y = 10
	legendary_bar.add_theme_stylebox_override("background",_progress_background_style())
	legendary_bar.add_theme_stylebox_override("fill",_progress_fill_style(JADE))
	box.add_child(legendary_bar)
	legendary_remaining = _label(box,"",12,TEXT_MUTED)
	legendary_remaining.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
func _build_summon_ctas() -> void:
	summon_controls_stack = VBoxContainer.new()
	summon_controls_stack.add_theme_constant_override("separation",8)
	_action_bank.add_child(summon_controls_stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	summon_controls_stack.add_child(row)
	summon_one_button = _button(row,"",_summon.bind(1),true,JADE)
	summon_ten_button = _button(row,"",_summon.bind(10),true,GOLD)
	for button: Button in [summon_one_button,summon_ten_button]:
		button.custom_minimum_size = Vector2(0,66)
		button.add_theme_font_size_override("font_size",16)
func _build_paid_summons() -> void:
	_paid_status = _label(summon_controls_stack, "", 13, JADE)
	_paid_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new(); summon_controls_stack.add_child(row)
	for count: int in [1,10]:
		var cost: int=100 if count==1 else 900
		var button: Button=_button(row,"%d× · %d PAID JADE"%[count,cost],_summon_paid.bind(count),true,GOLD)
		button.custom_minimum_size=Vector2(0,54);button.add_theme_font_size_override("font_size",13)
		_paid_buttons.append(button)
	_trial_seal_button=_button(summon_controls_stack,"",_summon_trial_seal,true,GOLD)
	_trial_seal_button.custom_minimum_size=Vector2(0,54)
	var trials: Node=get_node_or_null("/root/HeavenlyTrialsClient")
	if trials!=null and not trials.is_connected("changed",_refresh_paid_summons):trials.connect("changed",_refresh_paid_summons)
	_button(summon_controls_stack,"SERVER ARMORY · TARGET & GEAR",func() -> void: load("res://scripts/ui/paid_armory_panel.gd").open_for($SafeArea),false,JADE)
	if is_instance_valid(PavilionManager.paid_gameplay): PavilionManager.paid_gameplay.connect("changed",_refresh_paid_summons)
	if not PavilionManager.paid_summon_finished.is_connected(_on_paid_summon_finished): PavilionManager.paid_summon_finished.connect(_on_paid_summon_finished)
	_refresh_paid_summons()
func _refresh_paid_summons() -> void:
	if not is_instance_valid(_paid_status): return
	var paid: Node=PavilionManager.paid_gameplay
	var view: Dictionary=paid.get("snapshot") if is_instance_valid(paid) else {}
	var pity: Dictionary=view.get("pity",{})
	_paid_status.text="SERVER STANDARD · %d PAID JADE\n60%% Common · 29%% Rare · 9%% Epic · 2%% Legendary\nSeparate pity: %d/10 · %d/30 · %d/50"%[int(paid.call("paid_balance")) if paid!=null else 0,int(pity.get("rare_plus",0)),int(pity.get("epic_plus",0)),int(pity.get("legendary",0))]
	var trials: Node=get_node_or_null("/root/HeavenlyTrialsClient")
	var bonus: int=int(trials.snapshot.get("bonus_seals",0)) if trials!=null else 0
	if is_instance_valid(_trial_seal_button):
		_trial_seal_button.visible=bonus>0
		_trial_seal_button.text="BONUS SEAL · %d AVAILABLE"%bonus
		_trial_seal_button.disabled=paid==null or not paid.is_verified_ready() or paid.busy or not PavilionManager.is_summon_unlocked() or _paid_reveal_busy or (is_instance_valid(summon_reveal_overlay) and summon_reveal_overlay.visible)
	for i: int in range(_paid_buttons.size()):
		_paid_buttons[i].disabled=paid==null or not bool(paid.call("can_summon",1 if i==0 else 10)) or not PavilionManager.is_summon_unlocked() or _paid_reveal_busy or (is_instance_valid(summon_reveal_overlay) and summon_reveal_overlay.visible)
func _summon_trial_seal() -> void:
	if _paid_reveal_busy or (is_instance_valid(summon_reveal_overlay) and summon_reveal_overlay.visible): return
	_paid_reveal_busy=true;_refresh_paid_summons()
	if not PavilionManager.request_paid_summon(1,true):
		_paid_reveal_busy=false;_set_status("Connect to recover your bonus Seal.",GOLD);_refresh_paid_summons()

func _summon_paid(count: int) -> void:
	if _paid_reveal_busy or (is_instance_valid(summon_reveal_overlay) and summon_reveal_overlay.visible): return
	_paid_reveal_busy=true;_refresh_paid_summons()
	if not PavilionManager.request_paid_summon(count):
		_paid_reveal_busy=false;_set_status("Connect or recover your pending server request.",GOLD);_refresh_paid_summons()
func _on_paid_summon_finished(result: Dictionary) -> void:
	if not _paid_reveal_busy: return
	_paid_reveal_busy=false
	if bool(result.get("success",false)) and result.get("operation",{}).get("kind") in ["summon","seal_summon"]:
		_paid_reveal_mode=true
		_record_session_history(result);_start_summon_reveal(result)
	else: _set_status(str(result.get("error","Recover your server request.")),GOLD)
	var trials: Node=get_node_or_null("/root/HeavenlyTrialsClient")
	if trials!=null:trials.call("refresh")
	_sync_wallet_balances();_refresh_summon_panel();_refresh_paid_summons()
func _build_utility_rows() -> void:
	_build_paid_summons()
	locked_watch_ad_button = _button(summon_controls_stack,tr("WATCH AD • FREE 1× SUMMON"),_request_locked_rewarded_ad,false,JADE)
	locked_watch_ad_button.custom_minimum_size = Vector2(0,48)
	locked_watch_ad_button.add_theme_font_size_override("font_size",14)
	_ad_hint = _label(summon_controls_stack,"",12,TEXT_MUTED)
	_ad_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ad_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	summon_controls_stack.add_child(row)
	_banner_notice=_label(summon_controls_stack,"",12,GOLD)
	_banner_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_banner_notice.visible=false
	rates_button = _button(row,tr("DROP RATES"),_show_drop_rates_overlay,false,JADE_SOFT)
	_button(row,tr("SUMMON HISTORY"),_show_history_overlay,false,GOLD)
	var target_button: Button=_button(summon_controls_stack,"PILIH TARGET" if SettingsManager.language=="id" else "CHOOSE TARGET",_open_target_picker,false,GOLD)
	target_button.name="BrowseWishTargets"
func _refresh_summon_panel() -> void:
	_sync_banner_presentation()
	super()
	# A previously chosen target stays valid even outside the rotating featured set.
	var saved_target: String=PavilionManager.get_wish_target_item_id()
	if not saved_target.is_empty() and saved_target not in featured_items:
		selected_rate_up_item_id=saved_target
		_refresh_focal_item()
		if _banner_notice!=null:
			_banner_notice.text=tr("SAVED TARGET RETAINED")+" • "+_item_display_name(saved_target)
			_banner_notice.visible=true
	elif _banner_notice!=null: _banner_notice.visible=false
	if summon_one_button != null: summon_one_button.text = _summon_button_text(1)
	if summon_ten_button != null: summon_ten_button.text = _summon_button_text(10)
	_refresh_paid_summons()
func _refresh_rewarded_seal_section() -> void:
	super()
	if _ad_hint == null: return
	var remaining: int = PavilionManager.get_rewarded_ad_claims_remaining()
	_ad_hint.text = tr("%d rewarded Seals remain • 1 Seal = 1 summon") % remaining
	if rewarded_seal_state_label != null and locked_watch_ad_button.disabled:
		_ad_hint.text = rewarded_seal_state_label.text
func _summon(count: int) -> void:
	if _paid_reveal_busy or (summon_reveal_overlay != null and summon_reveal_overlay.visible): return
	_paid_reveal_mode=false
	super(count)
func _build_summon_reveal_overlay() -> void:
	if summon_reveal_overlay != null: return
	summon_reveal_overlay = ColorRect.new()
	summon_reveal_overlay.name = "SanctumRevealOverlay"
	summon_reveal_overlay.color = Color(0.01,0.05,0.04,1)
	summon_reveal_overlay.visible = false
	summon_reveal_overlay.z_index = 100
	$SafeArea.add_child(summon_reveal_overlay)
	summon_reveal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_formation_background=TextureRect.new()
	_formation_background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_formation_background.texture=load("res://assets/ui/pavilion/sanctum_premium/celestial_gate.png")
	_formation_background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_formation_background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_formation_background.modulate=Color(0.22,0.35,0.29,0.4)
	summon_reveal_overlay.add_child(_formation_background)
	_formation_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for edge in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,16)
	summon_reveal_overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reveal_box = VBoxContainer.new()
	_reveal_box.add_theme_constant_override("separation",8)
	margin.add_child(_reveal_box)
	var row := HBoxContainer.new()
	_reveal_box.add_child(row)
	summon_reveal_counter = _label(row,"",14,GOLD)
	summon_reveal_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summon_reveal_skip = _button(row,tr("REVEAL ALL"),_skip_ritual,false,JADE_SOFT)
	summon_reveal_skip.custom_minimum_size = Vector2(0,44)
	_reveal_stage = SanctumStage.new()
	_reveal_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reveal_box.add_child(_reveal_stage)
	_reveal_stage.ritual_finished.connect(_ritual_landed)
	_reveal_stage.relic_appeared.connect(_on_relic_impact)
	_reveal_stage.phase_changed.connect(_on_ritual_phase)
	_phase_copy = _label(_reveal_box,"",13,GOLD)
	_phase_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stars_copy = _label(_reveal_box,"",23,GOLD)
	_stars_copy.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_result_name = _label(_reveal_box,"",26,TEXT_MAIN)
	_result_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_slot = _label(_reveal_box,"",13,TEXT_MUTED)
	_result_slot.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_result_state = _label(_reveal_box,"",13,JADE)
	_result_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_formation_scroll = ScrollContainer.new()
	_formation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_formation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reveal_box.add_child(_formation_scroll)
	_formation = GridContainer.new()
	_formation.columns = 2
	_formation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formation.add_theme_constant_override("h_separation",8)
	_formation.add_theme_constant_override("v_separation",8)
	_formation_scroll.add_child(_formation)
	_formation_scroll.resized.connect(_fit_formation_cells)
	summon_reveal_action = _button(_reveal_box,tr("CONTINUE"),_advance_summon_reveal,true,GOLD)
	summon_reveal_action.custom_minimum_size = Vector2(0,56)
func _start_summon_reveal(result: Dictionary) -> void:
	summon_reveal_payload = result.duplicate(true)
	summon_reveal_entries = result.get("results",[]).duplicate(true)
	if summon_reveal_entries.is_empty(): return
	sanctum_stage.set_process(false)
	_reveal_stage.clear()
	_formation_detail = false
	_formation_mode = summon_reveal_entries.size() > 1
	_formation_opened.clear()
	summon_reveal_index = 0
	summon_reveal_generation += 1
	summon_reveal_overlay.visible = true
	summon_reveal_overlay.move_to_front()
	_formation_scroll.visible = false
	_reveal_stage.visible = true
	_result_name.text = ""
	_result_state.text = ""
	_stars_copy.text = ""
	_result_slot.text = ""
	_result_name.visible=true;_result_state.visible=true;_stars_copy.visible=true;_result_slot.visible=true;_phase_copy.visible=true
	for copy: Label in [_result_name,_result_state,_stars_copy,_result_slot]: copy.modulate.a=0.0
	_formation_background.visible = false
	_phase_copy.text = tr("TALISMAN AWAKENS")
	summon_reveal_counter.text = tr("CELESTIAL FORMATION") if _formation_mode else tr("CELESTIAL SUMMON")
	summon_reveal_skip.text = tr("REVEAL ALL") if _formation_mode else tr("SKIP ANIMATION")
	summon_reveal_action.text = tr("REVEALING...")
	summon_reveal_action.disabled = true
	summon_reveal_busy = true
	var entry: Dictionary = summon_reveal_entries[0]
	if _formation_mode:
		for candidate: Dictionary in summon_reveal_entries:
			if RARITIES.find(str(candidate.get("rarity","common"))) > RARITIES.find(str(entry.get("rarity","common"))): entry = candidate
	_cinematic_entry = entry
	AudioManager.play_sfx("summon_charge")
	var chosen_id: String = str(entry.get("item_id",""))
	_reveal_stage.play(_load_item_texture(chosen_id),str(entry.get("rarity","common")),EquipmentManager.get_loadout_item_star(chosen_id))
	_fit_sanctum()
func _ritual_landed() -> void:
	if not summon_reveal_overlay.visible: return
	summon_reveal_busy = false
	summon_reveal_action.disabled = false
	summon_reveal_action.text = tr("CONTINUE")
	if _formation_detail:
		_paint_formation_seal(summon_reveal_index)
		_show_landed_entry(summon_reveal_entries[summon_reveal_index])
		summon_reveal_action.text=tr("BACK TO FORMATION")
	elif _formation_mode:
		_build_formation()
	else:
		_show_landed_entry(summon_reveal_entries[0])
func _show_landed_entry(entry: Dictionary) -> void:
	var id: String = str(entry.get("item_id",""))
	var rarity: String = str(entry.get("rarity","common"))
	_phase_copy.visible=true;_result_name.visible=true;_result_state.visible=true;_stars_copy.visible=true;_result_slot.visible=true
	_phase_copy.text = tr(rarity.capitalize()).to_upper()
	_phase_copy.add_theme_color_override("font_color",EquipmentVisualCatalog.get_rarity_color(rarity))
	_result_name.text = _item_display_name(id)
	_stars_copy.text = _actual_stars(id)
	_result_slot.text = tr(str(EquipmentManager.get_item_data(id).get("slot","")).capitalize())
	_result_state.text = _entry_state(entry)
	if _landing_tween != null: _landing_tween.kill()
	for copy: Label in [_result_name,_result_state,_stars_copy,_result_slot]: copy.modulate.a=1.0 if SettingsManager.reduced_effects else 0.0
	if not SettingsManager.reduced_effects:
		_landing_tween=create_tween().set_parallel(true)
		for copy: Label in [_result_name,_result_state,_stars_copy,_result_slot]: _landing_tween.tween_property(copy,"modulate:a",1.0,0.32)

func _entry_state(entry: Dictionary) -> String:
	if bool(entry.get("duplicate",false)): return tr("DUPLICATE • +1 COPY")
	return tr("NEW DISCOVERY")
func _build_formation() -> void:
	_result_name.modulate.a=1.0;_result_state.modulate.a=1.0
	_reveal_stage.visible = false
	_reveal_stage.clear()
	_formation_background.visible = true
	_formation_scroll.visible = true
	_stars_copy.text = ""
	_result_slot.text = ""
	_stars_copy.visible=false;_result_slot.visible=false;_phase_copy.visible=false
	_result_name.visible=true;_result_state.visible=true
	_result_name.text = tr("TEN RELICS FORMATION")
	_result_state.text = tr("Tap a seal to reveal its relic.")
	_phase_copy.text = ""
	for child in _formation.get_children():
		_formation.remove_child(child)
		child.queue_free()
	for index in range(summon_reveal_entries.size()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0,166)
		button.add_theme_stylebox_override("normal",_relic_tile_style(JADE_SOFT,false))
		button.add_theme_stylebox_override("hover",_relic_tile_style(GOLD,true))
		button.add_theme_stylebox_override("focus",_relic_tile_style(GOLD,true))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = ""
		var tile := VBoxContainer.new()
		tile.name = "RelicContent"
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_theme_constant_override("separation",4)
		button.add_child(tile)
		tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.offset_left = 8;tile.offset_right = -8;tile.offset_top = 8;tile.offset_bottom = -8
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size.y = 72
		icon.texture = CELESTIAL_SEAL
		tile.add_child(icon)
		var copy: Label = _label(tile,tr("SEALED RELIC")+" %d" % (index+1),14,TEXT_MAIN)
		copy.name = "Name"
		copy.max_lines_visible = 2
		copy.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rarity_copy: Label = _label(tile,"",11,GOLD)
		rarity_copy.name = "Rarity"
		rarity_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var state: Label = _label(tile,"",11,JADE)
		state.name = "State"
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(_open_formation_seal.bind(index))
		_formation.add_child(button)
	_formation_scroll.scroll_vertical = 0
	_fit_sanctum()
func _open_formation_seal(index: int, cinematic: bool = true) -> void:
	if index < 0 or index >= summon_reveal_entries.size() or summon_reveal_busy: return
	if cinematic:
		_begin_formation_detail(index)
	else:
		_paint_formation_seal(index)
func _paint_formation_seal(index: int) -> void:
	if _formation_opened.has(index): return
	var entry: Dictionary = summon_reveal_entries[index]
	var id: String = str(entry.get("item_id",""))
	var rarity: String = str(entry.get("rarity","common"))
	_formation_opened[index] = true
	var button := _formation.get_child(index) as Button
	(button.get_node("RelicContent/Icon") as TextureRect).texture = _load_item_texture(id)
	(button.get_node("RelicContent/Name") as Label).text = _item_display_name(id)
	var rarity_copy := button.get_node("RelicContent/Rarity") as Label
	rarity_copy.text = tr(rarity.capitalize()).to_upper()+"  "+_actual_stars(id)
	rarity_copy.add_theme_color_override("font_color",EquipmentVisualCatalog.get_rarity_color(rarity))
	(button.get_node("RelicContent/State") as Label).text = _entry_state(entry)
	button.tooltip_text = _item_display_name(id)+"\n"+tr(rarity.capitalize())+"\n"+_entry_state(entry)
	button.add_theme_stylebox_override("normal",_relic_tile_style(EquipmentVisualCatalog.get_rarity_color(rarity),true))
	_result_state.text = tr("REVEALED %d / %d") % [_formation_opened.size(),summon_reveal_entries.size()]
	if not SettingsManager.reduced_effects:
		button.modulate.a=0.4
		create_tween().tween_property(button,"modulate:a",1.0,0.25)

func _skip_ritual() -> void:
	if summon_reveal_busy: _reveal_stage.skip()
	if _formation_detail: return
	if _formation_mode:
		for index in range(summon_reveal_entries.size()): _open_formation_seal(index,false)
func _advance_summon_reveal() -> void:
	if summon_reveal_busy: return
	if _formation_detail:
		_return_to_formation()
		return
	if _formation_mode and _formation_opened.size() < summon_reveal_entries.size():
		_skip_ritual()
		return
	_finish_summon_reveal()
func _finish_summon_reveal(_skipped: bool = false) -> void:
	if _landing_tween != null: _landing_tween.kill()
	if _reveal_stage != null: _reveal_stage.clear()
	summon_reveal_generation += 1
	summon_reveal_busy = false
	summon_reveal_overlay.visible = false
	summon_reveal_entries.clear()
	summon_reveal_payload.clear()
	summon_reveal_index = -1
	_formation_opened.clear()
	_formation_detail = false
	_cinematic_entry = {}
	sanctum_stage.set_process(true)
	_refresh_summon_panel()
func _fit_sanctum() -> void:
	if sanctum_stage != null:
		sanctum_stage.custom_minimum_size.y = clampf(size.y*0.33,200,420)
	if _reveal_stage != null: _reveal_stage.custom_minimum_size.y = clampf(size.y*0.38,140,420)
	if featured_row != null:
		for button: Control in featured_row.get_children(): button.custom_minimum_size.y=90 if size.x>=600 else 74
	if _formation != null: _formation.columns = 2
	call_deferred("_fit_formation_cells")

func _button(parent_node: Node, value: String, callback: Callable, primary: bool, accent: Color) -> Button:
	var button: Button = super(parent_node,value,callback,primary,accent)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_button_style(button,accent,primary)
	button.button_down.connect(_button_pressure.bind(button,true))
	button.button_up.connect(_button_pressure.bind(button,false))
	var ornament := button.get_node_or_null("Ornaments")
	if ornament != null: ornament.visible = false
	return button

func _actual_stars(id: String) -> String:
	var star: int = int(PavilionManager.paid_gameplay.call("item_star",id)) if _paid_reveal_mode else EquipmentManager.get_loadout_item_star(id)
	return "★".repeat(star)+"☆".repeat(maxi(0,EquipmentManager.MAX_ASCENSION_STAR-star))
func _begin_formation_detail(index: int) -> void:
	_formation_detail = true
	summon_reveal_index = index
	_formation_scroll.visible = false
	_formation_background.visible = false
	_reveal_stage.visible = true
	_result_name.text = "";_result_state.text = "";_result_slot.text = "";_stars_copy.text = ""
	_result_name.visible=true;_result_state.visible=true;_stars_copy.visible=true;_result_slot.visible=true;_phase_copy.visible=true
	for copy: Label in [_result_name,_result_state,_stars_copy,_result_slot]: copy.modulate.a=0.0
	_phase_copy.text = tr("THE SEAL FALLS SILENT")
	summon_reveal_counter.text = tr("PULL %d OF %d") % [index+1,summon_reveal_entries.size()]
	summon_reveal_action.disabled = true
	summon_reveal_action.text = tr("REVEALING...")
	summon_reveal_skip.text = tr("SKIP ANIMATION")
	summon_reveal_busy = true
	var entry: Dictionary = summon_reveal_entries[index]
	_cinematic_entry = entry
	AudioManager.play_sfx("summon_charge")
	var id: String = str(entry.get("item_id",""))
	_reveal_stage.clear()
	_reveal_stage.play(_load_item_texture(id),str(entry.get("rarity","common")),EquipmentManager.get_loadout_item_star(id))
func _return_to_formation() -> void:
	if _landing_tween != null: _landing_tween.kill()
	_result_name.modulate.a=1.0;_result_state.modulate.a=1.0
	_reveal_stage.clear()
	_reveal_stage.visible = false
	_formation_scroll.visible = true
	_formation_background.visible = true
	_formation_detail = false
	_stars_copy.text = "";_result_slot.text = "";_phase_copy.text = ""
	_stars_copy.visible=false;_result_slot.visible=false;_phase_copy.visible=false
	_result_name.visible=true;_result_state.visible=true
	_result_name.text = tr("TEN RELICS FORMATION")
	_result_state.text = tr("REVEALED %d / %d") % [_formation_opened.size(),summon_reveal_entries.size()]
	summon_reveal_counter.text = tr("CELESTIAL FORMATION")
	summon_reveal_skip.text = tr("REVEAL ALL")
	summon_reveal_action.text = tr("CONTINUE")
	summon_reveal_action.disabled = false
func _fit_formation_cells() -> void:
	if _formation_scroll == null or not _formation_scroll.visible or _formation == null: return
	var row_count: int = ceili(float(_formation.get_child_count())/2.0)
	if row_count == 0: return
	var height: float = clampf((_formation_scroll.size.y-float(row_count-1)*8.0)/float(row_count),190 if size.x<360 else 170,210)
	for button: Control in _formation.get_children():
		button.custom_minimum_size.y = height
		var icon := button.get_node("RelicContent/Icon") as TextureRect
		icon.custom_minimum_size.y = clampf(height*0.37,56,72)
func _relic_tile_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.014,0.062,0.052,0.95)
	style.border_color=Color(accent,0.90 if selected else 0.45)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(8)
	style.content_margin_left=8;style.content_margin_right=8;style.content_margin_top=8;style.content_margin_bottom=8
	style.shadow_color=Color(accent,0.14 if selected else 0.0)
	style.shadow_size=8 if selected else 0
	return style

func _on_relic_impact() -> void:
	if not summon_reveal_overlay.visible or _cinematic_entry.is_empty(): return
	_play_reveal_item_feedback(_reveal_stage.rarity,bool(_cinematic_entry.get("duplicate",false)))

func _on_ritual_phase(message: String) -> void:
	var hinted: bool = _reveal_stage.elapsed/_reveal_stage.duration >= 0.18
	_phase_copy.text = tr(_reveal_stage.rarity.capitalize()).to_upper()+" • "+tr(message) if hinted else tr(message)
	_phase_copy.add_theme_color_override("font_color",EquipmentVisualCatalog.get_rarity_color(_reveal_stage.rarity) if hinted else TEXT_MUTED)
func _install_palace_background() -> void:
	if palace_background != null and is_instance_valid(palace_background): return
	var legacy: Control = get_node_or_null("Backdrop")
	if legacy != null: legacy.visible=false
	palace_background=TextureRect.new()
	palace_background.name="UnifiedPavilionBackground"
	palace_background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	palace_background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	palace_background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	palace_background.texture=load("res://assets/ui/pavilion/sanctum_premium/pavilion_unified.png")
	add_child(palace_background)
	palace_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(palace_background,0)
func _section_card(parent_node: Node, eyebrow: String, title: String, description: String, accent: Color) -> VBoxContainer:
	var box: VBoxContainer = super(parent_node,eyebrow,title,description,accent)
	var shell: PanelContainer = box.get_parent() as PanelContainer
	if shell != null: shell.add_theme_stylebox_override("panel",_imperial_style(accent,false,false,Vector2(26,26)))
	return box
func _show_history_overlay() -> void:
	if is_instance_valid(locked_history_overlay):return
	if not _admit_sheet_open():return
	_close_target_picker();_close_rates_overlay()
	if summon_reveal_overlay != null and summon_reveal_overlay.visible: return
	super()

func _imperial_style(accent: Color, active: bool, depressed: bool, corners: Vector2=Vector2(20,18)) -> StyleBox:
	var style=ImperialStyle.new()
	style.tint=Color(1.0,0.94,0.78) if accent.r>accent.g else Color(0.72,1.0,0.88)
	if not active: style.tint=style.tint.darkened(0.24)
	if depressed: style.tint=style.tint.darkened(0.18)
	style.corner=corners;style.pressed=depressed;style.selected=active
	return style
func _focus_ring() -> StyleBoxFlat:
	var ring:=StyleBoxFlat.new()
	ring.bg_color=Color.TRANSPARENT
	ring.border_color=GOLD
	ring.set_border_width_all(1)
	ring.set_expand_margin_all(-3)
	return ring
func _apply_button_style(button: Button, accent: Color, primary: bool) -> void:
	for state_name: String in ["normal","hover","pressed","disabled"]:
		var style: StyleBox=_imperial_style(accent,primary or state_name=="hover",state_name=="pressed")
		if state_name=="disabled": style.tint=Color(0.30,0.39,0.34)
		button.add_theme_stylebox_override(state_name,style)
	button.add_theme_stylebox_override("focus",_focus_ring())
	button.add_theme_color_override("font_color",Color(1,0.95,0.78) if primary else TEXT_MAIN)
	button.add_theme_color_override("font_hover_color",Color(1,0.98,0.87))
	button.add_theme_color_override("font_disabled_color",Color(0.52,0.61,0.57))
	button.add_theme_color_override("font_shadow_color",Color(0,0.025,0.015,0.9))
	button.add_theme_constant_override("shadow_offset_y",1)
func _build_meditation_section() -> void:
	super()
	if meditation_altar_icon!=null: meditation_altar_icon.texture=CELESTIAL_SEAL
	if meditation_altar_frame!=null:
		meditation_altar_frame.custom_minimum_size=Vector2(104,104)
		meditation_altar_frame.size_flags_vertical=Control.SIZE_SHRINK_CENTER
func _meditation_altar_style(accent: Color, available: bool) -> StyleBoxFlat:
	var style:=super(accent,available)
	style.bg_color=Color(0.012,0.07,0.054)
	style.border_color=Color(0.83,0.67,0.35,0.85 if available else 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(52)
	style.shadow_color=Color(0.18,0.82,0.56,0.18 if available else 0.0)
	style.shadow_size=12 if available else 0
	return style
func _load_featured_items() -> void:
	var banner: Dictionary=PavilionManager.get_banner_configuration()
	if banner.is_empty(): super();return
	featured_items.clear()
	for id: String in banner.featured: featured_items.append(id)
	selected_rate_up_item_id=PavilionManager.get_wish_target_item_id()
func _banner_updated() -> void:
	if summon_reveal_overlay!=null and summon_reveal_overlay.visible:
		return
	_refresh_summon_panel()
	if locked_rates_overlay!=null and is_instance_valid(locked_rates_overlay): _show_drop_rates_overlay()
func _sync_banner_presentation() -> void:
	if summon_reveal_overlay!=null and summon_reveal_overlay.visible: return
	_load_featured_items()
	var banner: Dictionary=PavilionManager.get_banner_configuration()
	if _banner_title!=null: _banner_title.text=str(banner.title) if not banner.is_empty() else tr("JADE PAVILION")
	if _banner_subtitle!=null: _banner_subtitle.text=str(banner.subtitle) if not banner.is_empty() else tr("THE ANCIENT SANCTUM")
	if palace_background!=null:
		palace_background.texture=load(PavilionManager.BannerClient.ARTWORKS.get(str(banner.get("artwork","sanctum")),PavilionManager.BannerClient.ARTWORKS.sanctum))

func _button_pressure(button: Button, down: bool) -> void:
	if SettingsManager.reduced_effects or not is_instance_valid(button): return
	button.pivot_offset=button.size/2.0
	var previous: Variant=button.get_meta("pressure_tween") if button.has_meta("pressure_tween") else null
	if previous is Tween: previous.kill()
	var tween:=create_tween()
	button.set_meta("pressure_tween",tween)
	tween.tween_property(button,"scale",Vector2.ONE*(0.985 if down else 1.0),0.08 if down else 0.14).set_trans(Tween.TRANS_SINE)
func _progress_background_style() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.005,0.025,0.020)
	style.border_color=Color(0.48,0.39,0.21,0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style
func _progress_fill_style(accent: Color) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=accent.darkened(0.25)
	style.border_color=accent.lightened(0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _apply_first_frame_polish() -> void:
	super()
	if meditation_altar_icon!=null: meditation_altar_icon.texture=CELESTIAL_SEAL

# Compact safe-area sheets shared by Rates, History and target selection.
func _build_modal_overlay(title_text: String) -> ColorRect:
	var host: Control=$SafeArea
	var overlay:=ColorRect.new();overlay.name="PavilionCompactSheet";overlay.color=Color(0,.01,.016,.76);overlay.z_index=90
	host.add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel:=PanelContainer.new();panel.name="CompactPanel";panel.self_modulate.a=0;overlay.add_child(panel)
	panel.add_theme_stylebox_override("panel",_imperial_style(GOLD,true,false))
	var root_box:=VBoxContainer.new();root_box.add_theme_constant_override("separation",10);panel.add_child(root_box)
	var heading:=_label(root_box,title_text,20,GOLD);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var sc:=ScrollContainer.new();sc.name="CompactScroll";sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sc.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;sc.follow_focus=true;sc.scroll_deadzone=8;sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;root_box.add_child(sc)
	var body:=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;body.add_theme_constant_override("separation",10);sc.add_child(body)
	var footer:=VBoxContainer.new();footer.name="CompactFooter";root_box.add_child(footer)
	overlay.set_meta("content",body);overlay.set_meta("panel",panel);overlay.set_meta("scroll",sc)
	overlay.resized.connect(_queue_compact_fit.bind(overlay,panel,root_box,sc,body,footer))
	_queue_compact_fit(overlay,panel,root_box,sc,body,footer)
	return overlay

func _queue_compact_fit(overlay: ColorRect,panel: PanelContainer,root_box: VBoxContainer,sc: ScrollContainer,body: VBoxContainer,footer: VBoxContainer) -> void:
	if not is_instance_valid(overlay) or overlay.is_queued_for_deletion():return
	var generation: int=int(overlay.get_meta("fit_generation",0))+1
	overlay.set_meta("fit_generation",generation)
	_fit_compact_popup.call_deferred(overlay,panel,root_box,sc,body,footer,generation)

func _fit_compact_popup(overlay: ColorRect,panel: PanelContainer,root_box: VBoxContainer,sc: ScrollContainer,body: VBoxContainer,footer: VBoxContainer,generation: int) -> void:
	await get_tree().process_frame
	if not is_instance_valid(overlay) or overlay.is_queued_for_deletion() or int(overlay.get_meta("fit_generation"))!=generation:return
	var width: float=minf(560,overlay.size.x-24)
	var skin: StyleBox=panel.get_theme_stylebox("panel")
	body.custom_minimum_size.x=maxf(0,width-skin.get_minimum_size().x-12)
	var choices: GridContainer=body.get_node_or_null("TargetChoices")
	if choices!=null:choices.columns=1 if overlay.size.x<440 else 2
	sc.custom_minimum_size.y=0
	panel.size=Vector2(width,overlay.size.y*.72)
	panel.position.x=(overlay.size.x-width)*.5
	if body.get_child_count()>0:
		var last: Node=body.get_child(body.get_child_count()-1)
		if last is Button:
			body.remove_child(last);footer.add_child(last);last.custom_minimum_size.y=44
	for child: Node in body.get_children():
		if child is Label:
			if child.text==tr("History is visit-only; the frozen production save schema is unchanged."):child.text="Riwayat kunjungan Pavilion ini." if SettingsManager.language=="id" else "History for this Pavilion visit."
			child.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			child.add_theme_font_size_override("font_size",14)
	await get_tree().process_frame
	if not is_instance_valid(overlay) or overlay.is_queued_for_deletion() or int(overlay.get_meta("fit_generation"))!=generation:return
	var fixed: float=root_box.get_child(0).get_combined_minimum_size().y+footer.get_combined_minimum_size().y+skin.get_minimum_size().y+20
	var height: float=minf(overlay.size.y*.72,maxf(fixed+44,body.get_combined_minimum_size().y+fixed))
	sc.custom_minimum_size.y=maxf(44,height-fixed)
	panel.size=Vector2(width,height);panel.position.y=(overlay.size.y-height)*.5;panel.self_modulate.a=1

func _close_target_picker() -> void:
	_target_epoch+=1
	if is_instance_valid(_target_overlay):
		_target_overlay.hide();_target_overlay.queue_free()
	_target_overlay=null

func _open_target_picker(category: String="") -> void:
	if summon_reveal_overlay!=null and summon_reveal_overlay.visible:return
	if is_instance_valid(_target_overlay) and (category.is_empty() or category==_target_category):return
	if not _admit_sheet_open():return
	if not category.is_empty():_target_category=category
	_close_target_picker();_close_rates_overlay();_close_history_overlay()
	_target_overlay=_build_modal_overlay("PILIH TARGET SUMMON" if SettingsManager.language=="id" else "SUMMON TARGET")
	var body: VBoxContainer=_target_overlay.get_meta("content")
	var tabs:=HBoxContainer.new();body.add_child(tabs)
	_button(tabs,"SENJATA" if SettingsManager.language=="id" else "WEAPON",_open_target_picker.bind("weapon"),_target_category=="weapon",GOLD)
	_button(tabs,"SET",_open_target_picker.bind("set"),_target_category=="set",JADE)
	_label(body,"Clear 1–5 membuka seluruh pool equipment & weapon. Target adalah satu item Legendary; ganti target mereset Fate." if SettingsManager.language=="id" else "Clear 1–5 unlocks the full equipment and weapon pool. A target is one Legendary item; changing target resets Fate.",14,MUTED_TEXT)
	var choices:=GridContainer.new();choices.name="TargetChoices";choices.columns=1 if $SafeArea.size.x<440 else 2;choices.add_theme_constant_override("h_separation",8);choices.add_theme_constant_override("v_separation",8);body.add_child(choices)
	var available: Array[String]=PavilionManager.get_wish_target_options()
	for id: String in EquipmentManager.get_item_ids():
		var data: Dictionary=EquipmentManager.get_item_data(id)
		if str(data.get("rarity",""))!="legendary":continue
		if (str(data.get("slot",""))=="armament")!=(_target_category=="weapon"):continue
		var text: String=str(data.get("display_name",id))
		if _target_category=="set":text+="\n"+EquipmentSetCatalog.get_display_name(EquipmentSetCatalog.get_set_id_for_item(id))
		text+=("\n✓ TARGET" if id==PavilionManager.get_wish_target_item_id() else "")
		var button:=_button(choices,text,_choose_browser_target.bind(id,_target_epoch),false,GOLD);button.name="Target_"+id
		button.mouse_filter=Control.MOUSE_FILTER_PASS;button.button_down.connect(_target_button_down)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.custom_minimum_size.y=76
		button.disabled=id not in available or SaveManager.is_progress_read_only()
		button.icon=_load_item_texture(id);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",36)
	_button(body,tr("CLOSE"),_close_target_picker,false,JADE)

func _target_button_down() -> void:
	_target_press_pos=get_global_mouse_position()
	if is_instance_valid(_target_overlay):_target_scroll_start=(_target_overlay.get_meta("scroll") as ScrollContainer).scroll_vertical

func _choose_browser_target(id: String,epoch: int=-1) -> void:
	if epoch>=0 and epoch!=_target_epoch:return
	if not is_instance_valid(_target_overlay) or id not in PavilionManager.get_wish_target_options():return
	if get_global_mouse_position().distance_to(_target_press_pos)>12 or absi((_target_overlay.get_meta("scroll") as ScrollContainer).scroll_vertical-_target_scroll_start)>8:return
	if not PavilionManager.set_wish_target(id):return
	selected_rate_up_item_id=id;_close_target_picker();_refresh_summon_panel()

func _back() -> void:
	if is_instance_valid(_target_overlay):_close_target_picker();return
	if is_instance_valid(locked_rates_overlay):_close_rates_overlay();return
	if is_instance_valid(locked_history_overlay):_close_history_overlay();return
	super()

func _show_drop_rates_overlay() -> void:
	if is_instance_valid(locked_rates_overlay) or (summon_reveal_overlay!=null and summon_reveal_overlay.visible): return
	if not _admit_sheet_open():return
	_close_target_picker();_close_history_overlay()
	super()

func _admit_sheet_open() -> bool:
	if Time.get_ticks_msec()<_sheet_guard_until:return false
	_sheet_guard_until=Time.get_ticks_msec()+140
	return true
