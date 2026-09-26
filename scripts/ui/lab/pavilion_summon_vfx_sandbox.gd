extends Control

## Pavilion Summon VFX Sandbox — Legendary Vertical Slice v1.
## Rare and Epic motion are locked. This scene validates only the Legendary
## Celestial Mandate escalation using the approved Legendary VFX pack.
## Presentation-only: no summon resolution, currency, pity, save, or inventory calls.

const SummonVFXCatalog = preload(
	"res://scripts/ui/summon_vfx/pavilion_summon_vfx_catalog.gd"
)

const LEGENDARY_ITEM_ICON: String = "res://assets/ui/equipment/final/nine_heavens_star_sword.png"
const LEGENDARY_ITEM_NAME: String = "Nine Heavens Star Sword"

@onready var backdrop: Control = $Backdrop
@onready var controller = $SafeArea/Margin/Stack/StageFrame/VFXController
@onready var play_button: Button = $SafeArea/Margin/Stack/PlayButton
@onready var status_label: Label = $SafeArea/Margin/Stack/StatusLabel

var _playing: bool = false


func _ready() -> void:
	_configure_pavilion_backdrop()
	play_button.pressed.connect(_play_legendary_summon)
	controller.sequence_started.connect(_on_sequence_started)
	controller.sequence_finished.connect(_on_sequence_finished)
	status_label.text = "READY • Legendary vertical slice"
	call_deferred("_play_legendary_summon")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_play_legendary_summon()


func _configure_pavilion_backdrop() -> void:
	if backdrop != null and backdrop.has_method("apply_profile"):
		backdrop.call("apply_profile", {
			"sky_top": Color(0.003, 0.006, 0.014, 1.0),
			"sky_bottom": Color(0.028, 0.020, 0.018, 1.0),
			"mountain_far": Color(0.090, 0.064, 0.048, 0.76),
			"mountain_near": Color(0.018, 0.015, 0.014, 0.98),
			"mist": Color(0.98, 0.78, 0.30, 0.07),
			"moon": Color(1.0, 0.88, 0.56, 0.13),
			"accent": Color(1.0, 0.76, 0.24, 1.0),
			"gold": Color(1.0, 0.82, 0.38, 1.0)
		})


func _play_legendary_summon() -> void:
	if _playing or controller.is_busy():
		return
	_playing = true
	play_button.disabled = true
	play_button.text = "SUMMONING..."
	status_label.text = "PLAYING • Celestial Mandate Descends"
	await controller.play_sequence(
		SummonVFXCatalog.get_profile_for_item("legendary", LEGENDARY_ITEM_NAME),
		LEGENDARY_ITEM_ICON,
		LEGENDARY_ITEM_NAME
	)


func _on_sequence_started(_rarity_id: String) -> void:
	status_label.text = "PLAYING • mandala → heavenly beam → dragon apparition → Legendary reveal"


func _on_sequence_finished(_rarity_id: String) -> void:
	_playing = false
	play_button.disabled = false
	play_button.text = "PLAY LEGENDARY SUMMON"
	status_label.text = "COMPLETE • judge event weight, focal lock, clipping • SPACE = replay"
