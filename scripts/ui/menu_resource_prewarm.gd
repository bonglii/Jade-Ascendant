extends Node

## Keeps heavy hub resources warm before the player taps HERO/PAVILION.
## Loading happens through ResourceLoader's threaded path and card creation is
## still batched by each screen, so this does not replace runtime QA.

const EquipmentVisualCatalog = preload("res://scripts/ui/equipment_visual_catalog.gd")

const PRIORITY_RESOURCES: PackedStringArray = [
    "res://scenes/ui/equipment_screen.tscn",
    "res://scenes/ui/pavilion_screen.tscn",
    "res://assets/ui/pavilion/polish/pavilion_sanctuary_banner.svg",
    "res://assets/ui/pavilion/polish/meditation_altar.svg",
    "res://assets/ui/pavilion/polish/pavilion_seal.svg",
    "res://assets/ui/pavilion/polish/celestial_jade.svg",
    "res://assets/ui/pavilion/polish/wanderer_jade_jian.svg"
]

var _warm_cache: Dictionary = {}
var _prewarm_started: bool = false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _start_prewarm.call_deferred()


func _start_prewarm() -> void:
    if _prewarm_started:
        return
    _prewarm_started = true
    await get_tree().process_frame

    for resource_path_value: String in PRIORITY_RESOURCES:
        await _prewarm_resource(resource_path_value)

    var icon_paths: Array[String] = []
    for raw_path: Variant in EquipmentVisualCatalog.ITEM_ICON_PATHS.values():
        var icon_path_value: String = str(raw_path)
        if not icon_path_value.is_empty() and icon_path_value not in icon_paths:
            icon_paths.append(icon_path_value)

    for icon_index: int in range(icon_paths.size()):
        await _prewarm_resource(icon_paths[icon_index])
        if (icon_index + 1) % 4 == 0:
            await get_tree().process_frame

    DebugLogger.system(str(
        "Menu resource prewarm selesai | Cached: ",
        _warm_cache.size()
    ))


func _prewarm_resource(resource_path_value: String) -> void:
    if resource_path_value.is_empty() or not ResourceLoader.exists(resource_path_value):
        return

    if ResourceLoader.has_cached(resource_path_value):
        var cached_resource: Resource = ResourceLoader.load(
            resource_path_value,
            "",
            ResourceLoader.CACHE_MODE_REUSE
        )
        if cached_resource != null:
            _warm_cache[resource_path_value] = cached_resource
        return

    var request_error: Error = ResourceLoader.load_threaded_request(
        resource_path_value,
        "",
        true,
        ResourceLoader.CACHE_MODE_REUSE
    )
    if request_error != OK:
        return

    while is_inside_tree():
        var progress: Array = []
        var load_status: int = ResourceLoader.load_threaded_get_status(
            resource_path_value,
            progress
        )
        if load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            await get_tree().process_frame
            continue
        if load_status == ResourceLoader.THREAD_LOAD_LOADED:
            var loaded_resource: Resource = ResourceLoader.load_threaded_get(
                resource_path_value
            )
            if loaded_resource != null:
                _warm_cache[resource_path_value] = loaded_resource
        return
