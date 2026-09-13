extends Node

# ==========================================
# WAVE SETTINGS
# ==========================================

@export var wave_duration: float = 30.0
@onready var checkpoint_manager = get_parent().get_node_or_null("CheckPointManager")
@export var final_wave: int = 10

# ==========================================
# STATE
# ==========================================

var current_wave: int = 1
var wave_timer: float = 0.0


# ==========================================
# READY
# ==========================================

func _ready() -> void:
	DebugLogger.system(str(
		"WaveManager aktif! ",
		" | Node: ",
		name,
		" | Path: ",
		get_path()
	))
	wave_timer = wave_duration


# ==========================================
# PROCESS
# ==========================================

func _process(delta: float) -> void:

	# Jika sudah mencapai final wave,
	# timer wave berhenti.
	if current_wave >= final_wave:
		return

	wave_timer -= delta

	if wave_timer <= 0.0:
		next_wave()


# ==========================================
# NEXT WAVE
# ==========================================

func next_wave() -> void:

	if current_wave >= final_wave:
		return

	current_wave += 1
	wave_timer = wave_duration

	DebugLogger.system(str(
		"WAVE NAIK! Wave: ",
		current_wave
	))

	if checkpoint_manager != null:
		checkpoint_manager.save_checkpoint()
	else:
		DebugLogger.system(str("WARNING: CheckPointManager tidak ditemukan!"))
# ==========================================
# SPAWN BONUS
# ==========================================

func get_spawn_bonus() -> int:

	if current_wave >= 10:
		return 3
	if current_wave >= 5:
		return 2
	if current_wave >= 3:
		return 1
	return 0
