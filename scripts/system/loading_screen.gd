extends Control

## Celestial Gate Loading Screen
## Hanya menangani presentasi. Proses loading dan pergantian scene dimiliki
## SceneTransitionManager agar layar ini dapat dipakai oleh seluruh game.

const CULTIVATION_TIPS: Array[String] = [
	"A balanced foundation creates the strongest immortal path.",
	"Equipment bonuses remain active throughout every cultivation run.",
	"Flying swords answer faster when Swift Qi has been refined.",
	"Daily quests provide steady resources for patient cultivators.",
	"True ascension is achieved through preparation, not haste."
]

@onready var background: TextureRect = %Background
@onready var content: Control = %Content
@onready var realm_label: Label = %RealmLabel
@onready var journey_label: Label = %JourneyLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var progress_label: Label = %ProgressLabel
@onready var status_label: Label = %StatusLabel
@onready var tip_label: Label = %TipLabel
@onready var gate_pulse: Control = %GatePulse

var target_progress: float = 0.0
var displayed_progress: float = 0.0
var pulse_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	content.modulate = Color(1.0, 1.0, 1.0, 0.0)
	background.pivot_offset = background.size * 0.5
	background.scale = Vector2(1.035, 1.035)
	_update_progress_display()


func configure(context: Dictionary = {}) -> void:
	var realm_title: String = str(
		context.get("title", "TRAVERSING THE CELESTIAL PATH")
	)
	realm_label.text = tr(realm_title).to_upper()
	var journey_subtitle: String = str(
		context.get("subtitle", "Opening a passage between realms")
	)
	journey_label.text = tr(journey_subtitle)
	var custom_tip: String = str(context.get("tip", ""))
	if custom_tip.is_empty():
		custom_tip = str(CULTIVATION_TIPS.pick_random())
	tip_label.text = tr(custom_tip)
	target_progress = 0.02
	displayed_progress = 0.0
	_update_progress_display()


func play_intro() -> void:
	var intro_tween: Tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(
		self,
		"modulate",
		Color.WHITE,
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(
		background,
		"scale",
		Vector2.ONE,
		1.4
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(
		content,
		"modulate",
		Color.WHITE,
		0.42
	).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)


func set_progress(value: float) -> void:
	target_progress = clampf(value, 0.0, 1.0)


func play_outro() -> void:
	set_progress(1.0)
	displayed_progress = 1.0
	_update_progress_display()
	await get_tree().create_timer(0.12, true).timeout
	var outro_tween: Tween = create_tween()
	outro_tween.tween_property(
		self,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		0.24
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await outro_tween.finished


func _process(delta: float) -> void:
	displayed_progress = lerpf(
		displayed_progress,
		target_progress,
		1.0 - exp(-delta * 7.0)
	)
	pulse_time += delta
	gate_pulse.modulate.a = 0.55 + sin(pulse_time * 2.4) * 0.18
	_update_progress_display()


func _update_progress_display() -> void:
	progress_bar.value = displayed_progress * 100.0
	progress_label.text = "%d%%" % int(round(displayed_progress * 100.0))
	if displayed_progress < 0.25:
		status_label.text = "ALIGNING SPIRIT VEINS"
	elif displayed_progress < 0.7:
		status_label.text = "OPENING CELESTIAL GATE"
	elif displayed_progress < 0.98:
		status_label.text = "STABILIZING PASSAGE"
	else:
		status_label.text = "PASSAGE STABLE"
