extends Control

## Pavilion Summon VFX Sandbox — Combined Rarity Gate.
## Runs the already-approved Rare / Epic / Legendary vertical slices inside one
## host so we can validate switching, cleanup between reveals, hierarchy, and
## consistent framing before production Pavilion integration.
## Presentation-only: no PavilionManager, currency, pity, Wish Fate, save, or
## inventory calls.

const SummonVFXCatalog = preload(
    "res://scripts/ui/summon_vfx/pavilion_summon_vfx_catalog.gd"
)

const RARE_ITEM_ICON: String = "res://assets/ui/equipment/final/mistveil_jian.png"
const RARE_ITEM_NAME: String = "Mistveil Jian"
const EPIC_ITEM_ICON: String = "res://assets/ui/equipment/final/cinnabar_moon_saber.png"
const EPIC_ITEM_NAME: String = "Cinnabar Moon Saber"
const LEGENDARY_ITEM_ICON: String = "res://assets/ui/equipment/final/nine_heavens_star_sword.png"
const LEGENDARY_ITEM_NAME: String = "Nine Heavens Star Sword"

const RARE_COLOR: Color = Color(0.28, 0.95, 0.78, 1.0)
const EPIC_COLOR: Color = Color(0.72, 0.48, 0.96, 1.0)
const LEGENDARY_COLOR: Color = Color(1.0, 0.76, 0.24, 1.0)

@onready var backdrop: Control = $Backdrop
@onready var stage_frame: PanelContainer = $SafeArea/Margin/Stack/StageFrame
@onready var rare_controller: Control = $SafeArea/Margin/Stack/StageFrame/RareController
@onready var epic_controller: Control = $SafeArea/Margin/Stack/StageFrame/EpicController
@onready var legendary_controller: Control = $SafeArea/Margin/Stack/StageFrame/LegendaryController
@onready var rare_button: Button = $SafeArea/Margin/Stack/RarityButtons/RareButton
@onready var epic_button: Button = $SafeArea/Margin/Stack/RarityButtons/EpicButton
@onready var legendary_button: Button = $SafeArea/Margin/Stack/RarityButtons/LegendaryButton
@onready var replay_button: Button = $SafeArea/Margin/Stack/ReplayButton
@onready var subtitle: Label = $SafeArea/Margin/Stack/Subtitle
@onready var status_label: Label = $SafeArea/Margin/Stack/StatusLabel

var _playing: bool = false
var _selected_rarity: String = "rare"


func _ready() -> void:
    rare_button.pressed.connect(Callable(self, "_play_rarity").bind("rare"))
    epic_button.pressed.connect(Callable(self, "_play_rarity").bind("epic"))
    legendary_button.pressed.connect(Callable(self, "_play_rarity").bind("legendary"))
    replay_button.pressed.connect(_replay_selected)

    rare_controller.sequence_started.connect(_on_sequence_started)
    epic_controller.sequence_started.connect(_on_sequence_started)
    legendary_controller.sequence_started.connect(_on_sequence_started)
    rare_controller.sequence_finished.connect(_on_sequence_finished)
    epic_controller.sequence_finished.connect(_on_sequence_finished)
    legendary_controller.sequence_finished.connect(_on_sequence_finished)

    _clear_all_controllers()
    _apply_rarity_presentation("rare")
    call_deferred("_prime_initial_layout")


func _prime_initial_layout() -> void:
    # Two frames guarantee PanelContainer + mobile safe-area layout has settled
    # before any controller calculates its focal center.
    await get_tree().process_frame
    await get_tree().process_frame
    _prepare_all_controller_layouts()
    _play_rarity("rare")


func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_1:
            _play_rarity("rare")
        KEY_2:
            _play_rarity("epic")
        KEY_3:
            _play_rarity("legendary")
        KEY_SPACE:
            _replay_selected()


func _play_rarity(rarity_id: String) -> void:
    if _playing:
        return

    _selected_rarity = rarity_id
    _playing = true
    _set_buttons_enabled(false)
    _clear_all_controllers()
    _apply_rarity_presentation(rarity_id)

    # All controllers stay visible but empty so PanelContainer continuously gives
    # Rare/Epic/Legendary the same valid stage rect. Reconfirm after one frame
    # before spawning the first VFX node.
    await get_tree().process_frame
    _prepare_all_controller_layouts()

    var controller: Control = _controller_for(rarity_id)
    var item_icon: String = _item_icon_for(rarity_id)
    var item_name: String = _item_name_for(rarity_id)
    var profile: Dictionary = SummonVFXCatalog.get_profile_for_item(
        rarity_id,
        item_name
    )

    status_label.text = "PLAYING • %s" % str(profile.get("display_name", rarity_id.to_upper()))
    await controller.play_sequence(profile, item_icon, item_name)


func _replay_selected() -> void:
    _play_rarity(_selected_rarity)


func _clear_all_controllers() -> void:
    for controller: Control in [rare_controller, epic_controller, legendary_controller]:
        if controller.has_method("clear_sequence"):
            controller.call("clear_sequence")


func _prepare_all_controller_layouts() -> void:
    for controller: Control in [rare_controller, epic_controller, legendary_controller]:
        if controller.has_method("prepare_host_layout"):
            controller.call("prepare_host_layout")


func _controller_for(rarity_id: String) -> Control:
    match rarity_id:
        "epic":
            return epic_controller
        "legendary":
            return legendary_controller
        _:
            return rare_controller


func _item_icon_for(rarity_id: String) -> String:
    match rarity_id:
        "epic":
            return EPIC_ITEM_ICON
        "legendary":
            return LEGENDARY_ITEM_ICON
        _:
            return RARE_ITEM_ICON


func _item_name_for(rarity_id: String) -> String:
    match rarity_id:
        "epic":
            return EPIC_ITEM_NAME
        "legendary":
            return LEGENDARY_ITEM_NAME
        _:
            return RARE_ITEM_NAME


func _apply_rarity_presentation(rarity_id: String) -> void:
    var accent: Color = RARE_COLOR
    var title_text: String = "RARE • Jade Mist Invocation"
    var profile: Dictionary = {
        "sky_top": Color(0.001, 0.012, 0.024, 1.0),
        "sky_bottom": Color(0.004, 0.060, 0.066, 1.0),
        "mountain_far": Color(0.018, 0.115, 0.112, 0.84),
        "mountain_near": Color(0.004, 0.046, 0.052, 0.98),
        "mist": Color(0.26, 0.92, 0.78, 0.10),
        "moon": Color(1.0, 0.82, 0.40, 0.10),
        "accent": RARE_COLOR,
        "gold": Color(0.98, 0.78, 0.30, 1.0),
    }

    if rarity_id == "epic":
        accent = EPIC_COLOR
        title_text = "EPIC • Violet Constellation Manifestation"
        profile = {
            "sky_top": Color(0.010, 0.005, 0.025, 1.0),
            "sky_bottom": Color(0.050, 0.018, 0.074, 1.0),
            "mountain_far": Color(0.100, 0.052, 0.130, 0.80),
            "mountain_near": Color(0.025, 0.010, 0.040, 0.98),
            "mist": Color(0.72, 0.48, 0.96, 0.09),
            "moon": Color(0.92, 0.74, 1.0, 0.11),
            "accent": EPIC_COLOR,
            "gold": Color(0.98, 0.78, 0.30, 1.0),
        }
    elif rarity_id == "legendary":
        accent = LEGENDARY_COLOR
        title_text = "LEGENDARY • Celestial Mandate Descends"
        profile = {
            "sky_top": Color(0.003, 0.006, 0.014, 1.0),
            "sky_bottom": Color(0.028, 0.020, 0.018, 1.0),
            "mountain_far": Color(0.090, 0.064, 0.048, 0.76),
            "mountain_near": Color(0.018, 0.015, 0.014, 0.98),
            "mist": Color(0.98, 0.78, 0.30, 0.07),
            "moon": Color(1.0, 0.88, 0.56, 0.13),
            "accent": LEGENDARY_COLOR,
            "gold": Color(1.0, 0.82, 0.38, 1.0),
        }

    subtitle.text = title_text
    subtitle.add_theme_color_override("font_color", accent.lightened(0.16))
    _apply_stage_accent(accent)
    if backdrop != null and backdrop.has_method("apply_profile"):
        backdrop.call("apply_profile", profile)


func _apply_stage_accent(accent: Color) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.002, 0.008, 0.012, 0.92)
    style.border_color = Color(accent.r, accent.g, accent.b, 0.62)
    style.set_border_width_all(2)
    style.corner_radius_top_left = 20
    style.corner_radius_top_right = 20
    style.corner_radius_bottom_left = 20
    style.corner_radius_bottom_right = 20
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
    style.shadow_size = 14
    stage_frame.add_theme_stylebox_override("panel", style)


func _set_buttons_enabled(enabled: bool) -> void:
    rare_button.disabled = not enabled
    epic_button.disabled = not enabled
    legendary_button.disabled = not enabled
    replay_button.disabled = not enabled


func _on_sequence_started(rarity_id: String) -> void:
    status_label.text = "PLAYING • %s reveal" % rarity_id.to_upper()


func _on_sequence_finished(rarity_id: String) -> void:
    _playing = false
    _set_buttons_enabled(true)
    status_label.text = "COMPLETE • %s • 1/2/3 switch rarity • SPACE replay" % rarity_id.to_upper()
