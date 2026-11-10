extends Node

const CampaignPacing = preload("res://scripts/data/campaign_pacing.gd")
const Atmosphere = preload("res://scripts/world/stage_atmosphere.gd")

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
var campaign_durations := PackedFloat32Array()
var campaign_realm: int = 0
var campaign_stage: int = 0
var _atmosphere_accent: Color = Color("81cda6")


func configure_campaign(realm: int, stage: int, profile: Dictionary) -> void:
	wave_duration = float(profile.get("wave_duration", wave_duration))
	campaign_realm = realm
	campaign_stage = stage
	_atmosphere_accent = profile.get("accent", _atmosphere_accent)
	if get_parent().has_method("finish_heavenly_trial"):
		return
	campaign_durations = CampaignPacing.durations(realm, stage)
	var difficulty: Node = get_parent().get_node_or_null("DifficultyManager")
	if difficulty != null and not campaign_durations.is_empty():
		var old_length: float = wave_duration * (final_wave - 1)
		difficulty.difficulty_interval = float(profile.get("difficulty_interval", 90.0)) * CampaignPacing.total(campaign_durations) / maxf(1.0, old_length)


func duration_for_wave(wave: int) -> float:
	return campaign_durations[wave - 1] if wave > 0 and wave <= campaign_durations.size() else wave_duration


func campaign_opening_qi_bonus() -> int:
	if campaign_durations.is_empty() or current_wave > 2 or EquipmentManager.is_practice():
		return 0
	return 2



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
	wave_timer = duration_for_wave(current_wave)
	if campaign_realm > 0:
		_install_atmosphere.call_deferred()


func _install_atmosphere() -> void:
	if not is_inside_tree():
		return
	var atmosphere := Atmosphere.new()
	atmosphere.name = "StageAtmosphere"
	atmosphere.configure(campaign_realm, campaign_stage, _atmosphere_accent)
	get_parent().add_child(atmosphere)


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
	wave_timer = duration_for_wave(current_wave)

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
