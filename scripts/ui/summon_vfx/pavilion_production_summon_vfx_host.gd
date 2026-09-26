extends Control

## Production-only visual host for already-resolved Pavilion summon results.
## Does not call PavilionManager, InventoryManager, SaveManager, or currency APIs.

signal reveal_cue(rarity_id: String)
signal sequence_finished(rarity_id: String)

const SummonVFXCatalog = preload(
    "res://scripts/ui/summon_vfx/pavilion_summon_vfx_catalog.gd"
)
const RareController = preload(
    "res://scripts/ui/summon_vfx/pavilion_summon_vfx_controller.gd"
)
const EpicController = preload(
    "res://scripts/ui/summon_vfx/pavilion_summon_vfx_epic_controller.gd"
)
const LegendaryController = preload(
    "res://scripts/ui/summon_vfx/pavilion_summon_vfx_legendary_controller.gd"
)

var _controllers: Dictionary = {}
var _busy: bool = false


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true
    _build_controllers()
    call_deferred("_prime_layout")


func is_busy() -> bool:
    return _busy


func play_reveal(
    rarity_id: String,
    item_icon_path: String,
    item_name: String
) -> bool:
    if _busy:
        return false
    if not _controllers.has(rarity_id):
        return false

    _busy = true
    clear_visuals(false)
    _prepare_layouts()

    var controller = _controllers[rarity_id]
    var reveal_callable := Callable(self, "_relay_reveal_cue")
    var finish_callable := Callable(self, "_relay_sequence_finished")
    if not controller.is_connected("reveal_cue", reveal_callable):
        controller.connect(
            "reveal_cue",
            reveal_callable,
            CONNECT_ONE_SHOT
        )
    if not controller.is_connected("sequence_finished", finish_callable):
        controller.connect(
            "sequence_finished",
            finish_callable,
            CONNECT_ONE_SHOT
        )

    var profile: Dictionary = SummonVFXCatalog.get_profile_for_item(
        rarity_id,
        item_name
    )
    controller.call("play_sequence", profile, item_icon_path, item_name)
    return true


func clear_visuals(reset_busy: bool = true) -> void:
    for controller_value in _controllers.values():
        var controller = controller_value
        if controller != null and controller.has_method("clear_sequence"):
            controller.call("clear_sequence")
    if reset_busy:
        _busy = false


func _build_controllers() -> void:
    _controllers = {
        # Common intentionally reuses the locked shared controller, but receives
        # a dedicated low-intensity profile from the catalog.
        "common": _create_controller(RareController, "CommonController"),
        "rare": _create_controller(RareController, "RareController"),
        "epic": _create_controller(EpicController, "EpicController"),
        "legendary": _create_controller(LegendaryController, "LegendaryController"),
    }


func _create_controller(script_resource: Script, node_name: String) -> Control:
    var controller := script_resource.new() as Control
    controller.name = node_name
    controller.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(controller)
    controller.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if controller.has_method("set_external_relic_mode"):
        controller.call("set_external_relic_mode", true)
    return controller


func _prime_layout() -> void:
    if not is_inside_tree():
        return
    await get_tree().process_frame
    if not is_inside_tree():
        return
    _prepare_layouts()


func _prepare_layouts() -> void:
    for controller_value in _controllers.values():
        var controller = controller_value
        if controller != null and controller.has_method("prepare_host_layout"):
            controller.call("prepare_host_layout")


func _relay_reveal_cue(rarity_id: String) -> void:
    reveal_cue.emit(rarity_id)


func _relay_sequence_finished(rarity_id: String) -> void:
    _busy = false
    sequence_finished.emit(rarity_id)
