extends Node2D
class_name LinYuePavilionAuraPresentation
## Cosmetic only; drawing stays behind the actual player's body at scene z=2.
var _aura_id: String = "plain"
var _clock: float = 0.0
var _tick: float = 0.0
var _fade: float = 1.0
var _visual

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	PavilionManager.pavilion_changed.connect(_sync_aura)
	SettingsManager.settings_changed.connect(_sync_aura)
	visibility_changed.connect(_sync_processing)
	_sync_aura()
	set_physics_process(false)

func _sync_aura() -> void:
	if not PavilionManager.is_aura_feature_enabled():
		visible = false
		set_process(false)
		return
	if _visual == null:
		_visual = load("res://scripts/ui/pavilion_aura_visual.gd").new()
	var next_id: String = PavilionManager.get_cosmetic_id()
	if next_id != _aura_id:
		_aura_id = next_id
		_clock = 0; _tick = 0
		_fade = 1.0 if SettingsManager.reduced_effects else 0.0
	visible = _aura_id in _visual.IDS and PavilionManager.is_cosmetic_owned(_aura_id)
	_sync_processing()
	queue_redraw()

func _sync_processing() -> void:
	set_process(is_visible_in_tree() and not SettingsManager.reduced_effects)
	if SettingsManager.reduced_effects: _fade = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	var step: float = minf(delta, 0.1)
	_clock = fposmod(_clock + step, _visual.PERIOD)
	_fade = minf(1.0, _fade + step / 0.24)
	_tick += step
	if _tick < 1.0 / 30.0: return
	_tick = 0.0
	queue_redraw()

func _draw() -> void:
	if not visible: return
	_visual.build(_aura_id, _clock, SettingsManager.reduced_effects)
	_visual.paint(self, Vector2.ZERO, 1.0, _fade)
