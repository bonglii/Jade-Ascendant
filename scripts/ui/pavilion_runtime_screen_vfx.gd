extends "res://scripts/ui/pavilion_runtime_screen.gd"

## Production integration layer for the locked summon VFX + premium result landing.
## v2 composition cleanup removes the legacy result subtree from the visible
## landing state and gives cinematic + result one shared focal axis.
##
## PavilionManager remains the economy/result authority. This script only changes
## presentation orchestration after a summon result has already been committed.

const ProductionSummonVFXHost = preload(
	"res://scripts/ui/summon_vfx/pavilion_production_summon_vfx_host.gd"
)
const PremiumSummonResult = preload(
	"res://scripts/ui/summon_vfx/pavilion_summon_result_premium.gd"
)

var production_summon_vfx_host
var premium_summon_result
var production_reveal_detail_root: Control
var production_reveal_active: bool = false


func _build_summon_reveal_overlay() -> void:
	super()
	if summon_reveal_focus_panel == null:
		return

	if summon_reveal_focus_panel.get_child_count() > 0:
		production_reveal_detail_root = (
			summon_reveal_focus_panel.get_child(0) as Control
		)

	premium_summon_result = PremiumSummonResult.new()
	premium_summon_result.name = "PremiumSummonResult"
	premium_summon_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summon_reveal_focus_panel.add_child(premium_summon_result)
	premium_summon_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Premium backdrop/result must sit above the focus-panel skin but below the
	# cinematic host while a reveal is still resolving.
	premium_summon_result.z_index = 4

	production_summon_vfx_host = ProductionSummonVFXHost.new()
	production_summon_vfx_host.name = "ProductionSummonVFXHost"
	production_summon_vfx_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summon_reveal_focus_panel.add_child(production_summon_vfx_host)
	production_summon_vfx_host.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	# Align cinematic center with the premium relic frame instead of the full
	# legacy focus panel. The small bottom inset is reserved for landed copy.
	production_summon_vfx_host.offset_top = 8.0
	production_summon_vfx_host.offset_bottom = -64.0
	production_summon_vfx_host.z_index = 8

	premium_summon_result.visible = false
	production_summon_vfx_host.visible = false


func _reset_summon_reveal_visual() -> void:
	super()
	production_reveal_active = false
	if production_summon_vfx_host != null:
		production_summon_vfx_host.call("clear_visuals")
		production_summon_vfx_host.visible = false
	if premium_summon_result != null:
		premium_summon_result.call("hide_result")
	if production_reveal_detail_root != null:
		production_reveal_detail_root.visible = true
	if summon_reveal_rarity != null:
		summon_reveal_rarity.visible = true
	if summon_reveal_collection != null:
		summon_reveal_collection.visible = true
	if summon_reveal_stage != null:
		summon_reveal_stage.visible = true
	if summon_reveal_skip != null:
		summon_reveal_skip.disabled = false


func _begin_summon_reveal_sequence(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= summon_reveal_entries.size():
		return

	var raw_entry = summon_reveal_entries[entry_index]
	if not raw_entry is Dictionary:
		await super(entry_index)
		return

	var entry: Dictionary = raw_entry
	var rarity: String = str(entry.get("rarity", "common"))
	if not _uses_locked_production_vfx(rarity):
		_restore_legacy_reveal_surface()
		await super(entry_index)
		return

	summon_reveal_busy = true
	production_reveal_active = true
	summon_reveal_action.disabled = true
	summon_reveal_action.text = tr("REVEALING...")
	summon_reveal_skip.disabled = true
	summon_reveal_generation += 1
	var sequence_generation: int = summon_reveal_generation

	_show_production_cinematic_surface()
	_prepare_summon_omen(entry_index)

	var item_id: String = str(entry.get("item_id", ""))
	var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
	var item_name: String = tr(str(item_data.get("display_name", item_id)))
	var item_icon_path: String = _get_pavilion_equipment_icon_path(item_id)

	var started: bool = bool(
		production_summon_vfx_host.call(
			"play_reveal",
			rarity,
			item_icon_path,
			item_name
		)
	)
	if not started:
		production_reveal_active = false
		_restore_legacy_reveal_surface()
		summon_reveal_busy = false
		summon_reveal_action.disabled = false
		summon_reveal_skip.disabled = false
		await super(entry_index)
		return

	await production_summon_vfx_host.reveal_cue
	if not _production_sequence_is_current(sequence_generation):
		return

	summon_reveal_index = entry_index
	# Populate production state/audio through the existing authority, but keep its
	# legacy detail subtree hidden. PremiumSummonResult owns the visible landing.
	_show_summon_reveal_entry(entry_index)
	summon_reveal_action.disabled = true
	summon_reveal_skip.disabled = true

	await production_summon_vfx_host.sequence_finished
	if not _production_sequence_is_current(sequence_generation):
		return

	production_reveal_active = false
	production_summon_vfx_host.visible = false
	production_summon_vfx_host.call("clear_visuals")
	summon_reveal_busy = false
	summon_reveal_action.disabled = false
	summon_reveal_skip.disabled = false


func _show_summon_reveal_entry(entry_index: int) -> void:
	super(entry_index)
	if entry_index < 0 or entry_index >= summon_reveal_entries.size():
		return

	var raw_entry = summon_reveal_entries[entry_index]
	if not raw_entry is Dictionary:
		return

	var entry: Dictionary = raw_entry
	var item_id: String = str(entry.get("item_id", ""))
	var data: Dictionary = EquipmentManager.get_item_data(item_id)
	var rarity: String = str(entry.get("rarity", data.get("rarity", "common")))
	if rarity not in ["common", "rare", "epic", "legendary"]:
		return

	# Never mix the old detail VBox with the premium result. This is the key v2
	# fix for duplicate labels, text shadows and front/back overlap.
	if production_reveal_detail_root != null:
		production_reveal_detail_root.visible = false
	if summon_reveal_stage != null:
		summon_reveal_stage.visible = false

	var item_name: String = tr(str(data.get("display_name", item_id)))
	var item_icon_path: String = _get_pavilion_equipment_icon_path(item_id)

	var set_id: String = EquipmentSetCatalog.get_set_id_for_item(item_id)
	var equipment_set_name: String = EquipmentSetCatalog.get_display_name(set_id)
	var set_identity: String = EquipmentSetCatalog.get_identity(set_id)
	var slot_name: String = tr(str(data.get("slot", "equipment")).capitalize())

	var meta_text: String = slot_name.to_upper()
	if not equipment_set_name.is_empty():
		meta_text = tr("SET • %s") % tr(equipment_set_name)

	var description_title: String = str(data.get("signature_effect_name", ""))
	var description_text: String = str(
		data.get("signature_effect_description", "")
	)
	if description_title.is_empty():
		description_title = tr("SET IDENTITY") if not set_identity.is_empty() else ""
		description_text = tr(set_identity) if not set_identity.is_empty() else ""

	var state_text: String = tr("NEW DISCOVERY")
	if bool(entry.get("duplicate", false)):
		state_text = tr("DUPLICATE • +%d SHARDS") % int(
			entry.get("duplicate_shards", 0)
		)

	if premium_summon_result != null:
		premium_summon_result.call(
			"show_result",
			rarity,
			item_icon_path,
			item_name,
			meta_text,
			tr(description_title),
			tr(description_text),
			state_text,
			not SettingsManager.reduced_effects
		)

	# The approved art owns result framing. The old focus border is removed only
	# for production cinematic/result states.
	if summon_reveal_focus_panel != null:
		summon_reveal_focus_panel.add_theme_stylebox_override(
			"panel",
			_production_clear_focus_style()
		)


func _production_clear_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style


func _finish_summon_reveal(skipped: bool = false) -> void:
	production_reveal_active = false
	if production_summon_vfx_host != null:
		production_summon_vfx_host.call("clear_visuals")
		production_summon_vfx_host.visible = false
	if premium_summon_result != null:
		premium_summon_result.call("hide_result")
	if production_reveal_detail_root != null:
		production_reveal_detail_root.visible = true
	if summon_reveal_rarity != null:
		summon_reveal_rarity.visible = true
	if summon_reveal_collection != null:
		summon_reveal_collection.visible = true
	if summon_reveal_stage != null:
		summon_reveal_stage.visible = true
	super(skipped)


func _uses_locked_production_vfx(rarity: String) -> bool:
	if SettingsManager.reduced_effects:
		return false
	return rarity in ["common", "rare", "epic", "legendary"]


func _show_production_cinematic_surface() -> void:
	if premium_summon_result != null:
		premium_summon_result.call("hide_result")
	if production_reveal_detail_root != null:
		production_reveal_detail_root.visible = false
	if summon_reveal_stage != null:
		summon_reveal_stage.visible = false
	if summon_reveal_focus_panel != null:
		summon_reveal_focus_panel.add_theme_stylebox_override(
			"panel",
			_production_clear_focus_style()
		)
	if production_summon_vfx_host != null:
		production_summon_vfx_host.visible = true


func _restore_legacy_reveal_surface() -> void:
	production_reveal_active = false
	if premium_summon_result != null:
		premium_summon_result.call("hide_result")
	if production_summon_vfx_host != null:
		production_summon_vfx_host.call("clear_visuals")
		production_summon_vfx_host.visible = false
	if production_reveal_detail_root != null:
		production_reveal_detail_root.visible = true
	if summon_reveal_stage != null:
		summon_reveal_stage.visible = true


func _production_sequence_is_current(sequence_generation: int) -> bool:
	return (
		sequence_generation == summon_reveal_generation
		and summon_reveal_overlay != null
		and summon_reveal_overlay.visible
		and production_reveal_active
	)
