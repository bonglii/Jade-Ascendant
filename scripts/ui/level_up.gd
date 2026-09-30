extends Control

## Level Up
## Mengelola pilihan upgrade saat Player naik level.
## Gameplay availability/application tetap menjadi authority existing.
## Visual polish dibangun runtime supaya tidak mengubah contract node produksi.

const SWORD_DAO_RESONANCE_REQUIRED_SPIRIT_SWORD_LEVEL: int = 3
const SWORD_DAO_RESONANCE_REQUIRED_SWORD_INTENT_LEVEL: int = 2

const YIN_YANG_REVERSAL_REQUIRED_BLADES_LEVEL: int = 3
const YIN_YANG_REVERSAL_REQUIRED_QI_SHIELD_LEVEL: int = 2

const HEAVENLY_TRIBULATION_REQUIRED_SWORD_RAIN_LEVEL: int = 3
const HEAVENLY_TRIBULATION_REQUIRED_THUNDER_LEVEL: int = 3

const WEAPON_UPGRADE_IDS: Array[String] = [
	"spirit_sword",
	"fire_orb",
	"thunder_talisman",
	"yin_yang_blades",
	"heavenly_sword_rain",
	"eight_trigrams_formation"
]

const RESONANCE_UPGRADE_IDS: Array[String] = [
	"sword_dao_resonance",
	"yin_yang_reversal",
	"heavenly_tribulation"
]

const ICON_PATHS: Dictionary = {
	"spirit_sword": "res://assets/ui/level_up/skill_art/spirit_sword.png",
	"fire_orb": "res://assets/ui/level_up/skill_art/fire_orb.png",
	"thunder_talisman": "res://assets/ui/level_up/skill_art/thunder_talisman.png",
	"yin_yang_blades": "res://assets/ui/level_up/skill_art/yin_yang_blades.png",
	"heavenly_sword_rain": "res://assets/ui/level_up/skill_art/heavenly_sword_rain.png",
	"eight_trigrams_formation": "res://assets/ui/level_up/skill_art/eight_trigrams_formation.png",
	"power": "res://assets/ui/level_up/skill_art/power.png",
	"attack_speed": "res://assets/ui/level_up/skill_art/attack_speed.png",
	"movement_speed": "res://assets/ui/level_up/skill_art/movement_speed.png",
	"body_refinement": "res://assets/ui/level_up/skill_art/body_refinement.png",
	"qi_shield": "res://assets/ui/level_up/skill_art/qi_shield.png",
	"spiritual_insight": "res://assets/ui/level_up/skill_art/spiritual_insight.png",
	"iron_body": "res://assets/ui/level_up/skill_art/iron_body.png",
	"blood_qi": "res://assets/ui/level_up/skill_art/blood_qi.png",
	"sword_intent": "res://assets/ui/level_up/skill_art/sword_intent.png",
	"sword_dao_resonance": "res://assets/ui/level_up/skill_art/sword_dao_resonance.png",
	"yin_yang_reversal": "res://assets/ui/level_up/skill_art/yin_yang_reversal.png",
	"heavenly_tribulation": "res://assets/ui/level_up/skill_art/heavenly_tribulation.png"
}

# Dedicated, scalable frame art for the complete three-choice breakthrough altar.
# Only the outer Frame skin is replaced; layout and card visuals stay untouched.
const BREAKTHROUGH_FRAME_ART: Texture2D = preload(
	"res://assets/ui/level_up/ascension_frame_ritual.svg"
)

const CARD_JADE: Color = Color(0.25, 0.93, 0.72, 1.0)
const CARD_CYAN: Color = Color(0.19, 0.76, 1.0, 1.0)
const CARD_GOLD: Color = Color(1.0, 0.68, 0.20, 1.0)
const CARD_IVORY: Color = Color(1.0, 0.88, 0.53, 1.0)
const CARD_TEXT: Color = Color(0.94, 0.98, 0.96, 1.0)
const CARD_MUTED: Color = Color(0.76, 0.84, 0.82, 1.0)

# Per-skill visual identity. State treatment is layered on top instead of replacing
# the skill theme, so every choice stays recognizable at a glance.
const SKILL_THEME_COLORS: Dictionary = {
	"spirit_sword": [Color(0.20, 0.93, 0.87, 1.0), Color(0.72, 0.98, 0.96, 1.0), Color(0.010, 0.080, 0.082, 0.992)],
	"fire_orb": [Color(1.00, 0.25, 0.10, 1.0), Color(1.00, 0.67, 0.14, 1.0), Color(0.125, 0.022, 0.010, 0.992)],
	"thunder_talisman": [Color(0.53, 0.35, 1.00, 1.0), Color(0.20, 0.80, 1.00, 1.0), Color(0.040, 0.025, 0.115, 0.992)],
	"yin_yang_blades": [Color(0.98, 0.69, 0.20, 1.0), Color(0.28, 0.68, 1.00, 1.0), Color(0.085, 0.056, 0.018, 0.992)],
	"heavenly_sword_rain": [Color(0.18, 0.69, 1.00, 1.0), Color(0.68, 0.91, 1.00, 1.0), Color(0.010, 0.047, 0.102, 0.992)],
	"eight_trigrams_formation": [Color(0.12, 0.88, 0.73, 1.0), Color(1.00, 0.73, 0.20, 1.0), Color(0.010, 0.080, 0.064, 0.992)],
	"power": [Color(1.00, 0.23, 0.28, 1.0), Color(1.00, 0.52, 0.28, 1.0), Color(0.112, 0.018, 0.025, 0.992)],
	"attack_speed": [Color(1.00, 0.72, 0.18, 1.0), Color(1.00, 0.90, 0.52, 1.0), Color(0.102, 0.066, 0.010, 0.992)],
	"movement_speed": [Color(0.16, 0.78, 1.00, 1.0), Color(0.48, 0.96, 1.00, 1.0), Color(0.010, 0.064, 0.103, 0.992)],
	"body_refinement": [Color(0.18, 0.88, 0.38, 1.0), Color(0.55, 1.00, 0.66, 1.0), Color(0.012, 0.086, 0.038, 0.992)],
	"qi_shield": [Color(0.20, 0.55, 1.00, 1.0), Color(0.42, 0.90, 1.00, 1.0), Color(0.012, 0.045, 0.105, 0.992)],
	"spiritual_insight": [Color(0.67, 0.36, 1.00, 1.0), Color(0.89, 0.62, 1.00, 1.0), Color(0.070, 0.020, 0.110, 0.992)],
	"iron_body": [Color(0.92, 0.46, 0.16, 1.0), Color(1.00, 0.72, 0.36, 1.0), Color(0.095, 0.040, 0.014, 0.992)],
	"blood_qi": [Color(0.92, 0.08, 0.25, 1.0), Color(1.00, 0.38, 0.46, 1.0), Color(0.100, 0.008, 0.026, 0.992)],
	"sword_intent": [Color(0.72, 0.82, 1.00, 1.0), Color(1.00, 0.80, 0.30, 1.0), Color(0.036, 0.048, 0.090, 0.992)],
	"sword_dao_resonance": [Color(0.26, 0.93, 0.88, 1.0), Color(1.00, 0.78, 0.25, 1.0), Color(0.018, 0.075, 0.075, 0.994)],
	"yin_yang_reversal": [Color(0.48, 0.55, 1.00, 1.0), Color(1.00, 0.70, 0.18, 1.0), Color(0.045, 0.040, 0.095, 0.994)],
	"heavenly_tribulation": [Color(0.58, 0.38, 1.00, 1.0), Color(1.00, 0.82, 0.28, 1.0), Color(0.047, 0.025, 0.110, 0.994)]
}

const STATE_BADGE_COLORS: Dictionary = {
	"refine": Color(0.32, 0.92, 0.70, 1.0),
	"weapon": Color(0.48, 0.92, 0.86, 1.0),
	"new": Color(0.20, 0.78, 1.00, 1.0),
	"awakening": Color(1.00, 0.64, 0.12, 1.0),
	"final": Color(1.00, 0.86, 0.48, 1.0),
	"resonance": Color(0.82, 0.48, 1.00, 1.0)
}

var upgrade_pool: Array[String] = [
	"spirit_sword",
	"fire_orb",
	"power",
	"attack_speed",
	"movement_speed",
	"body_refinement",
	"qi_shield",
	"thunder_talisman",
	"yin_yang_blades",
	"heavenly_sword_rain",
	"eight_trigrams_formation",
	"spiritual_insight",
	"iron_body",
	"blood_qi",
	"sword_intent",
	"sword_dao_resonance",
	"yin_yang_reversal",
	"heavenly_tribulation"
]

var current_upgrades: Array[String] = []

var player: Variant = null
var player_stats: Variant = null
var player_health: PlayerHealth = null
var weapon_manager: Variant = null

var upgrade_buttons: Array[Button] = []
var selection_locked: bool = false

@onready var breakthrough_level_label: Label = %BreakthroughLevelLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_error(str("ERROR: Player tidak ditemukan oleh LevelUp!"))
		return

	player_stats = player.get_node_or_null("PlayerStats")
	player_health = player.get_node_or_null("PlayerHealth") as PlayerHealth
	weapon_manager = player.get_node_or_null("WeaponManager")

	if player_stats == null:
		push_error(str("ERROR: PlayerStats tidak ditemukan oleh LevelUp!"))
		return

	if player_health == null:
		push_error(str("ERROR: PlayerHealth tidak ditemukan oleh LevelUp!"))
		return

	if weapon_manager == null:
		push_error(str("ERROR: WeaponManager tidak ditemukan oleh LevelUp!"))
		return

	find_upgrade_buttons()
	_polish_header()
	hide()


func find_upgrade_buttons() -> void:
	upgrade_buttons.clear()

	var found_buttons: Array[Node] = find_children(
		"UpgradeButton*",
		"Button",
		true,
		false
	)

	for found_node in found_buttons:
		if not found_node is Button:
			continue
		var button: Button = found_node as Button
		upgrade_buttons.append(button)

	if upgrade_buttons.size() < 3:
		push_error(str("ERROR: LevelUp membutuhkan minimal 3 UpgradeButton!"))
		return

	for i in range(3):
		var button: Button = upgrade_buttons[i]
		_prepare_upgrade_button_visual(button)
		var pressed_callable: Callable = _on_upgrade_button_pressed.bind(i)
		if not button.pressed.is_connected(pressed_callable):
			button.pressed.connect(pressed_callable)


func show_level_up() -> void:
	if player == null:
		return

	selection_locked = false
	generate_upgrades()

	if current_upgrades.is_empty():
		DebugLogger.system(str("Tidak ada upgrade yang tersedia."))
		return

	breakthrough_level_label.text = tr("LEVEL %d") % int(player.level)
	update_buttons()

	for button in upgrade_buttons:
		button.scale = Vector2.ONE
		button.modulate = Color.WHITE

	show()
	get_tree().paused = true

	# HUD presentation reacts to visibility_changed synchronously.
	# Re-apply state colors afterwards so FINAL REFINEMENT keeps its gold treatment.
	_refresh_choice_visual_colors()
	_refresh_breakthrough_accent()
	_queue_special_choice_pulse()

	DebugLogger.system(str("=== LEVEL UP MENU ==="))
	for i in range(current_upgrades.size()):
		DebugLogger.system(str("Pilihan ", i + 1, ": ", current_upgrades[i]))


func generate_upgrades() -> void:
	current_upgrades.clear()

	var available_upgrades: Array[String] = []

	for upgrade_id in upgrade_pool:
		if is_upgrade_available(upgrade_id):
			available_upgrades.append(upgrade_id)

	available_upgrades.shuffle()

	var option_count: int = min(3, available_upgrades.size())
	for i in range(option_count):
		current_upgrades.append(available_upgrades[i])


func is_upgrade_available(upgrade_id: String) -> bool:
	match upgrade_id:
		"fire_orb":
			var fire_orb: Variant = weapon_manager.get_weapon_by_name("Fire Orb")
			return fire_orb == null or fire_orb.level < FireOrbWeapon.MAX_LEVEL

		"thunder_talisman":
			var thunder_talisman: Variant = weapon_manager.get_weapon_by_name("Thunder Talisman")
			return thunder_talisman == null or thunder_talisman.level < ThunderTalismanWeapon.MAX_LEVEL

		"spirit_sword":
			var spirit_sword: Variant = weapon_manager.get_weapon_by_name("Spirit Sword")
			if spirit_sword == null:
				return false
			return spirit_sword.level < SpiritSwordWeapon.MAX_LEVEL

		"attack_speed":
			return player_stats.can_upgrade_attack_speed()

		"yin_yang_blades":
			var yin_yang_blades: Variant = weapon_manager.get_weapon_by_name("Yin-Yang Blades")
			if yin_yang_blades == null:
				return true
			return yin_yang_blades.level < YinYangBladesWeapon.MAX_LEVEL

		"heavenly_sword_rain":
			var heavenly_sword_rain: Variant = weapon_manager.get_weapon_by_name("Heavenly Sword Rain")
			if heavenly_sword_rain == null:
				return true
			return heavenly_sword_rain.level < HeavenlySwordRainWeapon.MAX_LEVEL

		"eight_trigrams_formation":
			var eight_trigrams_formation: Variant = weapon_manager.get_weapon_by_name("Eight Trigrams Formation")
			if eight_trigrams_formation == null:
				return true
			return eight_trigrams_formation.level < EightTrigramsFormationWeapon.MAX_LEVEL

		"spiritual_insight":
			return player.can_upgrade_spiritual_insight()

		"iron_body":
			return player_health.can_upgrade_iron_body()

		"blood_qi":
			return player_health.can_upgrade_blood_qi()

		"sword_intent":
			return player_stats.can_upgrade_sword_intent()

		"sword_dao_resonance":
			return can_unlock_sword_dao_resonance()

		"yin_yang_reversal":
			return can_unlock_yin_yang_reversal()

		"heavenly_tribulation":
			return can_unlock_heavenly_tribulation()

	return true


func can_unlock_sword_dao_resonance() -> bool:
	if player_stats == null or weapon_manager == null:
		return false
	if player_stats.has_sword_dao_resonance():
		return false
	if player_stats.sword_intent_level < SWORD_DAO_RESONANCE_REQUIRED_SWORD_INTENT_LEVEL:
		return false

	var resonance_spirit_sword: Variant = weapon_manager.get_weapon_by_name("Spirit Sword")
	if resonance_spirit_sword == null:
		return false

	return resonance_spirit_sword.level >= SWORD_DAO_RESONANCE_REQUIRED_SPIRIT_SWORD_LEVEL


func can_unlock_yin_yang_reversal() -> bool:
	if player_stats == null or player_health == null or weapon_manager == null:
		return false
	if player_stats.has_yin_yang_reversal():
		return false
	if player_health.qi_shield_level < YIN_YANG_REVERSAL_REQUIRED_QI_SHIELD_LEVEL:
		return false

	var reversal_yin_yang_blades: Variant = weapon_manager.get_weapon_by_name("Yin-Yang Blades")
	if reversal_yin_yang_blades == null:
		return false

	return reversal_yin_yang_blades.level >= YIN_YANG_REVERSAL_REQUIRED_BLADES_LEVEL


func can_unlock_heavenly_tribulation() -> bool:
	if player_stats == null or weapon_manager == null:
		return false
	if player_stats.has_heavenly_tribulation():
		return false

	var heavenly_sword_rain: Variant = weapon_manager.get_weapon_by_name("Heavenly Sword Rain")
	if heavenly_sword_rain == null:
		return false
	if heavenly_sword_rain.level < HEAVENLY_TRIBULATION_REQUIRED_SWORD_RAIN_LEVEL:
		return false

	var thunder_talisman: Variant = weapon_manager.get_weapon_by_name("Thunder Talisman")
	if thunder_talisman == null:
		return false

	return thunder_talisman.level >= HEAVENLY_TRIBULATION_REQUIRED_THUNDER_LEVEL


func update_buttons() -> void:
	for i in range(3):
		var button: Button = upgrade_buttons[i]

		if i >= current_upgrades.size():
			button.disabled = true
			button.hide()
			continue

		var upgrade_id: String = current_upgrades[i]
		button.disabled = false
		button.show()
		_update_choice_card(button, upgrade_id)



func _update_choice_card(button: Button, upgrade_id: String) -> void:
	# Keep legacy scene labels populated for HUD/presentation compatibility.
	var category_label: Label = button.get_node("Margin/Content/TopRow/CategoryLabel") as Label
	var state_label: Label = button.get_node("Margin/Content/TopRow/StateLabel") as Label
	var title_label: Label = button.get_node("Margin/Content/TitleLabel") as Label
	var description_label: Label = button.get_node("Margin/Content/DescriptionLabel") as Label
	var effect_label: Label = button.get_node("Margin/Content/BottomRow/EffectLabel") as Label
	var progress_label: Label = button.get_node("Margin/Content/BottomRow/ProgressLabel") as Label

	category_label.text = get_upgrade_category(upgrade_id)
	state_label.text = get_upgrade_state_label(upgrade_id)
	title_label.text = get_upgrade_display_name(upgrade_id)
	description_label.text = get_upgrade_description(upgrade_id)
	effect_label.text = get_upgrade_effect(upgrade_id)
	progress_label.text = get_upgrade_progress(upgrade_id)

	button.set_meta("upgrade_id", upgrade_id)
	_set_premium_card_text(button, upgrade_id)
	_update_choice_icon(button, upgrade_id)
	_apply_choice_card_style(button, upgrade_id)

func get_upgrade_category(upgrade_id: String) -> String:
	match upgrade_id:
		"spirit_sword", "fire_orb", "thunder_talisman", "yin_yang_blades", "heavenly_sword_rain", "eight_trigrams_formation":
			return "WEAPON ART"
		"body_refinement", "qi_shield", "iron_body", "blood_qi":
			return "BODY CULTIVATION"
		"spiritual_insight", "sword_intent":
			return "DAO INSIGHT"
		"sword_dao_resonance", "yin_yang_reversal", "heavenly_tribulation":
			return "DAO RESONANCE"
	return "MARTIAL FLOW"


func get_upgrade_state_label(upgrade_id: String) -> String:
	if RESONANCE_UPGRADE_IDS.has(upgrade_id):
		return "DAO RESONANCE"

	if WEAPON_UPGRADE_IDS.has(upgrade_id):
		var weapon_name: String = _get_weapon_name(upgrade_id)
		var weapon: Variant = weapon_manager.get_weapon_by_name(weapon_name)
		if weapon == null:
			return "NEW ART"

		if _is_final_weapon_refinement(upgrade_id):
			return "FINAL REFINEMENT"

		var next_level: int = int(weapon.level) + 1
		if _is_weapon_milestone(upgrade_id, next_level):
			return "ART AWAKENING"
		return "ART REFINEMENT"

	return "REFINE"


func get_upgrade_display_name(upgrade_id: String) -> String:
	match upgrade_id:
		"spirit_sword":
			return "Spirit Sword"
		"fire_orb":
			return "Fire Orb"
		"power":
			return "Power"
		"attack_speed":
			return "Attack Speed"
		"movement_speed":
			return "Swift Qi"
		"body_refinement":
			return "Body Refinement"
		"qi_shield":
			return "Qi Shield"
		"thunder_talisman":
			return "Thunder Talisman"
		"yin_yang_blades":
			return "Yin-Yang Blades"
		"heavenly_sword_rain":
			return "Heavenly Sword Rain"
		"eight_trigrams_formation":
			return "Eight Trigrams Formation"
		"spiritual_insight":
			return "Spiritual Insight"
		"iron_body":
			return "Iron Body"
		"blood_qi":
			return "Blood Qi"
		"sword_intent":
			return "Sword Intent"
		"sword_dao_resonance":
			return "Sword Dao Resonance"
		"yin_yang_reversal":
			return "Yin-Yang Reversal"
		"heavenly_tribulation":
			return "Heavenly Tribulation"
	return upgrade_id


func get_upgrade_description(upgrade_id: String) -> String:
	match upgrade_id:
		"spirit_sword":
			return "Milestones add a second sword and pierce."
		"fire_orb":
			return "Heavy flame orb; milestones empower Cinder Bloom."
		"power":
			return "Condense martial force to amplify all damage."
		"attack_speed":
			return "Cycle qi faster for shorter attack intervals."
		"movement_speed":
			return "Channel swift qi through the body to move faster."
		"body_refinement":
			return "Temper the body to expand vitality."
		"qi_shield":
			return "Block incoming hits with a protective qi layer."
		"thunder_talisman":
			return "Chain lightning; milestones reach more enemies."
		"yin_yang_blades":
			return "Orbiting blades; milestones add extra blades."
		"heavenly_sword_rain":
			return "Heavenly strikes; refine strike count and radius."
		"eight_trigrams_formation":
			return "Refine Bagua damage, radius, duration, and count."
		"spiritual_insight":
			return "Deepen comprehension for more battle EXP."
		"iron_body":
			return "Harden the body to reduce incoming damage."
		"blood_qi":
			return "Repeated kills restore HP more often."
		"sword_intent":
			return "Sharpen sword intent to raise critical chance."
		"sword_dao_resonance":
			return "Spirit Sword hits may launch a resonance sword."
		"yin_yang_reversal":
			return "Qi Shield blocks awaken an empowered orbit."
		"heavenly_tribulation":
			return "Sword Rain impacts may call Heavenly Lightning."
	return "Refine this cultivation path for the current run."


func get_upgrade_effect(upgrade_id: String) -> String:
	if WEAPON_UPGRADE_IDS.has(upgrade_id):
		return _get_weapon_upgrade_effect(upgrade_id)

	match upgrade_id:
		"power":
			return "+10% DAMAGE"
		"attack_speed":
			return "ATTACK COOLDOWN  ×0.90"
		"movement_speed":
			return "+10% MOVEMENT SPEED"
		"body_refinement":
			return "MAX HP  +2  •  RESTORE 2 HP"
		"qi_shield":
			return "QI SHIELD  +1 CHARGE"
		"spiritual_insight":
			return "+15% EXP GAIN"
		"iron_body":
			return "DAMAGE TAKEN  -5%"
		"blood_qi":
			return "HEAL 1 HP • FASTER PROC"
		"sword_intent":
			return "CRITICAL CHANCE  +5%"
		"sword_dao_resonance":
			return "SECONDARY SPIRIT SWORD"
		"yin_yang_reversal":
			return "4s EMPOWERED ORBIT"
		"heavenly_tribulation":
			return "HEAVENLY LIGHTNING"
	return "RUN UPGRADE"


func _get_weapon_upgrade_effect(upgrade_id: String) -> String:
	if _is_new_weapon(upgrade_id):
		match upgrade_id:
			"fire_orb":
				return "UNLOCK • HEAVY FLAME SHOT"
			"thunder_talisman":
				return "UNLOCK • 2 CHAIN HITS"
			"yin_yang_blades":
				return "UNLOCK • 2 ORBITING BLADES"
			"heavenly_sword_rain":
				return "UNLOCK • 2 SWORD STRIKES"
			"eight_trigrams_formation":
				return "UNLOCK • 80 RADIUS"

	var current_level: int = _get_current_weapon_level(upgrade_id)
	var next_level: int = current_level + 1

	match upgrade_id:
		"spirit_sword":
			if next_level == 5:
				return "+5 DMG • SECOND SPIRIT SWORD"
			if next_level == 7:
				return "+5 DMG • +1 PIERCE"
			return "+5 BASE DAMAGE"

		"fire_orb":
			if next_level == 3:
				return "+10 DMG • CINDER BLOOM 48R / 30%"
			if next_level == 5:
				return "+10 DMG • BLOOM 60R / 35%"
			if next_level == 7:
				return "+10 DMG • BLOOM 72R / 40%"
			return "+10 BASE DAMAGE"

		"thunder_talisman":
			if next_level == 3:
				return "+4 DMG • 3 CHAIN HITS"
			if next_level == 5:
				return "+4 DMG • 4 CHAIN HITS"
			if next_level == 7:
				return "+4 DMG • 5 CHAIN HITS"
			return "+4 BASE DAMAGE"

		"yin_yang_blades":
			if next_level == 3:
				return "+3 DMG • 3 ORBITING BLADES"
			if next_level == 5:
				return "+3 DMG • 4 ORBITING BLADES"
			if next_level == 7:
				return "+3 DMG • 5 ORBITING BLADES"
			return "+3 BASE DAMAGE"

		"heavenly_sword_rain":
			if next_level == 3:
				return "+4 DMG • 3 STRIKES"
			if next_level == 4:
				return "+4 DMG • RADIUS 32 → 38"
			if next_level == 5:
				return "+4 DMG • 4 STRIKES"
			if next_level == 6:
				return "+4 DMG • RADIUS 38 → 44"
			if next_level == 7:
				return "+4 DMG • 5 STRIKES"
			return "+4 BASE DAMAGE"

		"eight_trigrams_formation":
			match next_level:
				2:
					return "DAMAGE 8 → 11"
				3:
					return "RADIUS 80 → 96"
				4:
					return "DAMAGE 11 → 14"
				5:
					return "DURATION 4s → 5s"
				6:
					return "DAMAGE 14 → 18"
				7:
					return "1 → 2 FORMATIONS"

	return "WEAPON REFINEMENT"


func _get_current_weapon_level(upgrade_id: String) -> int:
	var weapon_name: String = _get_weapon_name(upgrade_id)
	if weapon_name.is_empty():
		return 0

	var weapon: Variant = weapon_manager.get_weapon_by_name(weapon_name)
	if weapon == null:
		return 0

	return int(weapon.level)


func _get_weapon_max_level(upgrade_id: String) -> int:
	match upgrade_id:
		"spirit_sword":
			return SpiritSwordWeapon.MAX_LEVEL
		"fire_orb":
			return FireOrbWeapon.MAX_LEVEL
		"thunder_talisman":
			return ThunderTalismanWeapon.MAX_LEVEL
		"yin_yang_blades":
			return YinYangBladesWeapon.MAX_LEVEL
		"heavenly_sword_rain":
			return HeavenlySwordRainWeapon.MAX_LEVEL
		"eight_trigrams_formation":
			return EightTrigramsFormationWeapon.MAX_LEVEL
	return 0


func _is_final_weapon_refinement(upgrade_id: String) -> bool:
	if not WEAPON_UPGRADE_IDS.has(upgrade_id):
		return false
	if _is_new_weapon(upgrade_id):
		return false

	var max_level: int = _get_weapon_max_level(upgrade_id)
	if max_level <= 0:
		return false

	return _get_current_weapon_level(upgrade_id) + 1 >= max_level


func _is_weapon_milestone(upgrade_id: String, next_level: int) -> bool:
	match upgrade_id:
		"spirit_sword":
			return next_level == 5 or next_level == 7
		"fire_orb":
			return next_level == 3 or next_level == 5 or next_level == 7
		"thunder_talisman":
			return next_level == 3 or next_level == 5 or next_level == 7
		"yin_yang_blades":
			return next_level == 3 or next_level == 5 or next_level == 7
		"heavenly_sword_rain":
			return next_level == 3 or next_level == 5 or next_level == 7
		"eight_trigrams_formation":
			return next_level == 7
	return false


func get_upgrade_progress(upgrade_id: String) -> String:
	if RESONANCE_UPGRADE_IDS.has(upgrade_id):
		return "RUN-LIMITED UNLOCK"

	if WEAPON_UPGRADE_IDS.has(upgrade_id):
		var weapon_name: String = _get_weapon_name(upgrade_id)
		var weapon: Variant = weapon_manager.get_weapon_by_name(weapon_name)
		if weapon == null:
			return "NEW • LV.1"
		var weapon_level: int = int(weapon.level)
		if _is_final_weapon_refinement(upgrade_id):
			return "LV.%d → LV.%d • MAX" % [weapon_level, weapon_level + 1]
		return "LV.%d → LV.%d" % [weapon_level, weapon_level + 1]

	var current_level: int = _get_passive_level(upgrade_id)
	return "LV.%d → LV.%d" % [current_level, current_level + 1]


func _get_passive_level(upgrade_id: String) -> int:
	match upgrade_id:
		"power":
			return int(player_stats.power_level)
		"attack_speed":
			return int(player_stats.attack_speed_level)
		"movement_speed":
			return int(player.movement_speed_level)
		"body_refinement":
			return int(player_health.body_refinement_level)
		"qi_shield":
			return int(player_health.qi_shield_level)
		"spiritual_insight":
			return int(player.spiritual_insight_level)
		"iron_body":
			return int(player_health.iron_body_level)
		"blood_qi":
			return int(player_health.blood_qi_level)
		"sword_intent":
			return int(player_stats.sword_intent_level)
	return 0


func _get_weapon_name(upgrade_id: String) -> String:
	match upgrade_id:
		"spirit_sword":
			return "Spirit Sword"
		"fire_orb":
			return "Fire Orb"
		"thunder_talisman":
			return "Thunder Talisman"
		"yin_yang_blades":
			return "Yin-Yang Blades"
		"heavenly_sword_rain":
			return "Heavenly Sword Rain"
		"eight_trigrams_formation":
			return "Eight Trigrams Formation"
	return ""


func _is_new_weapon(upgrade_id: String) -> bool:
	if not WEAPON_UPGRADE_IDS.has(upgrade_id):
		return false
	var weapon_name: String = _get_weapon_name(upgrade_id)
	return weapon_manager.get_weapon_by_name(weapon_name) == null


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"spirit_sword":
			weapon_manager.upgrade_weapon("Spirit Sword")
		"fire_orb":
			apply_fire_orb_upgrade()
		"power":
			player_stats.upgrade_power()
		"attack_speed":
			player_stats.upgrade_attack_speed()
		"movement_speed":
			player.upgrade_movement_speed()
		"body_refinement":
			player_health.upgrade_body_refinement()
		"qi_shield":
			player_health.upgrade_qi_shield()
		"thunder_talisman":
			apply_thunder_talisman_upgrade()
		"yin_yang_blades":
			apply_yin_yang_blades_upgrade()
		"heavenly_sword_rain":
			apply_heavenly_sword_rain_upgrade()
		"eight_trigrams_formation":
			apply_eight_trigrams_formation_upgrade()
		"spiritual_insight":
			player.upgrade_spiritual_insight()
		"iron_body":
			player_health.upgrade_iron_body()
		"blood_qi":
			player_health.upgrade_blood_qi()
		"sword_intent":
			player_stats.upgrade_sword_intent()
		"sword_dao_resonance":
			player_stats.unlock_sword_dao_resonance()
		"yin_yang_reversal":
			player_stats.unlock_yin_yang_reversal()
		"heavenly_tribulation":
			player_stats.unlock_heavenly_tribulation()
		_:
			DebugLogger.system(str("WARNING: Upgrade tidak dikenal: ", upgrade_id))
			selection_locked = false
			return

	DebugLogger.system(str("Upgrade dipilih: ", upgrade_id))
	close_level_up()


func apply_fire_orb_upgrade() -> void:
	var fire_orb: Variant = weapon_manager.get_weapon_by_name("Fire Orb")
	if fire_orb == null:
		weapon_manager.add_fire_orb()
		return
	weapon_manager.upgrade_weapon("Fire Orb")


func apply_thunder_talisman_upgrade() -> void:
	var thunder_talisman: Variant = weapon_manager.get_weapon_by_name("Thunder Talisman")
	if thunder_talisman == null:
		weapon_manager.add_thunder_talisman()
		return
	weapon_manager.upgrade_weapon("Thunder Talisman")


func apply_yin_yang_blades_upgrade() -> void:
	var yin_yang_blades: Variant = weapon_manager.get_weapon_by_name("Yin-Yang Blades")
	if yin_yang_blades == null:
		weapon_manager.add_yin_yang_blades()
		return
	weapon_manager.upgrade_weapon("Yin-Yang Blades")


func apply_heavenly_sword_rain_upgrade() -> void:
	var heavenly_sword_rain: Variant = weapon_manager.get_weapon_by_name("Heavenly Sword Rain")
	if heavenly_sword_rain == null:
		weapon_manager.add_heavenly_sword_rain()
		return
	weapon_manager.upgrade_weapon("Heavenly Sword Rain")


func apply_eight_trigrams_formation_upgrade() -> void:
	var eight_trigrams_formation: Variant = weapon_manager.get_weapon_by_name("Eight Trigrams Formation")
	if eight_trigrams_formation == null:
		weapon_manager.add_eight_trigrams_formation()
		return
	weapon_manager.upgrade_weapon("Eight Trigrams Formation")


func close_level_up() -> void:
	hide()
	current_upgrades.clear()
	selection_locked = false
	get_tree().paused = false
	player.call_deferred("resolve_pending_level_up")



func _on_upgrade_button_pressed(button_index: int) -> void:
	if selection_locked:
		return
	if not visible:
		return
	if button_index < 0:
		return
	if button_index >= current_upgrades.size():
		return

	selection_locked = true
	var upgrade_id: String = current_upgrades[button_index]
	_play_upgrade_selection_sfx()

	if _reduced_effects_enabled():
		apply_upgrade(upgrade_id)
		return

	var selected_button: Button = upgrade_buttons[button_index]
	selected_button.pivot_offset = selected_button.size * 0.5

	var accent: Color = _get_choice_border_accent(upgrade_id, _get_choice_visual_state(upgrade_id))
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	for i in range(upgrade_buttons.size()):
		var button: Button = upgrade_buttons[i]
		if not button.visible:
			continue
		if i == button_index:
			tween.parallel().tween_property(button, "scale", Vector2(1.025, 1.025), 0.11)
			tween.parallel().tween_property(
				button,
				"modulate",
				Color(1.0 + accent.r * 0.08, 1.0 + accent.g * 0.05, 1.0 + accent.b * 0.04, 1.0),
				0.11
			)
		else:
			tween.parallel().tween_property(button, "modulate", Color(0.36, 0.42, 0.40, 1.0), 0.11)

	await tween.finished
	if is_inside_tree() and visible:
		apply_upgrade(upgrade_id)

func _polish_header() -> void:
	var frame: PanelContainer = find_child("Frame", true, false) as PanelContainer
	if frame != null:
		frame.custom_minimum_size = Vector2(600.0, 950.0)
		_polish_outer_frame(frame)

	var margin: MarginContainer = get_node_or_null("SafeArea/Center/Frame/Margin") as MarginContainer
	if margin != null:
		margin.add_theme_constant_override("margin_left", 27)
		margin.add_theme_constant_override("margin_right", 27)
		margin.add_theme_constant_override("margin_top", 20)
		margin.add_theme_constant_override("margin_bottom", 18)
		_build_breakthrough_backdrop(margin)

	var content: VBoxContainer = get_node_or_null("SafeArea/Center/Frame/Margin/Content") as VBoxContainer
	if content != null:
		content.add_theme_constant_override("separation", 9)

	var eyebrow: Label = find_child("Eyebrow", true, false) as Label
	if eyebrow != null:
		eyebrow.text = "SPIRITUAL BREAKTHROUGH"
		eyebrow.add_theme_font_size_override("font_size", 13)
		eyebrow.add_theme_color_override("font_color", CARD_GOLD)
		eyebrow.add_theme_constant_override("outline_size", 3)
		eyebrow.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.022, 0.96))

	breakthrough_level_label.add_theme_font_size_override("font_size", 30)
	breakthrough_level_label.add_theme_color_override("font_color", CARD_IVORY)
	breakthrough_level_label.add_theme_constant_override("outline_size", 4)
	breakthrough_level_label.add_theme_color_override("font_outline_color", Color(0.012, 0.035, 0.030, 0.98))

	var title: Label = find_child("Title", true, false) as Label
	if title != null:
		title.text = "CHOOSE YOUR PATH"
		title.add_theme_font_size_override("font_size", 31)
		title.add_theme_color_override("font_color", Color(0.985, 0.97, 0.86, 1.0))
		title.add_theme_constant_override("outline_size", 3)
		title.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.028, 0.98))

	var subtitle: Label = find_child("Subtitle", true, false) as Label
	if subtitle != null:
		subtitle.text = "One insight will shape the rest of this run."
		subtitle.add_theme_font_size_override("font_size", 13)
		subtitle.add_theme_color_override("font_color", Color(0.72, 0.80, 0.77, 1.0))

	var divider: ColorRect = find_child("Divider", true, false) as ColorRect
	if divider != null:
		divider.custom_minimum_size = Vector2(0.0, 2.0)

	var footer_hint: Label = find_child("FooterHint", true, false) as Label
	if footer_hint != null:
		footer_hint.text = "TAP A PATH TO CONTINUE"
		footer_hint.add_theme_font_size_override("font_size", 13)
		footer_hint.add_theme_color_override("font_color", Color(0.67, 0.77, 0.73, 1.0))

	var dim: ColorRect = find_child("Dim", true, false) as ColorRect
	if dim != null:
		dim.color = Color(0.001, 0.008, 0.016, 0.86)


func _polish_outer_frame(frame: PanelContainer) -> void:
	# Keep the original StyleBoxTexture content insets. Changing them would
	# move the existing three choices or reduce their touch targets.
	# A nine-slice texture preserves the ornamental corners on all viewports.
	var ritual_frame: StyleBoxTexture = StyleBoxTexture.new()
	ritual_frame.texture = BREAKTHROUGH_FRAME_ART
	ritual_frame.texture_margin_left = 64.0
	ritual_frame.texture_margin_top = 64.0
	ritual_frame.texture_margin_right = 64.0
	ritual_frame.texture_margin_bottom = 64.0
	ritual_frame.content_margin_left = 24.0
	ritual_frame.content_margin_top = 20.0
	ritual_frame.content_margin_right = 24.0
	ritual_frame.content_margin_bottom = 20.0
	frame.add_theme_stylebox_override("panel", ritual_frame)


func _refresh_breakthrough_accent() -> void:
	var has_prestige_choice: bool = false
	var has_new_art: bool = false

	for upgrade_id in current_upgrades:
		var state: String = _get_choice_visual_state(upgrade_id)
		if state in ["awakening", "final", "resonance"]:
			has_prestige_choice = true
		elif state == "new":
			has_new_art = true

	var accent: Color = CARD_JADE
	if has_prestige_choice:
		accent = CARD_GOLD
	elif has_new_art:
		accent = CARD_CYAN

	breakthrough_level_label.add_theme_color_override(
		"font_color",
		CARD_IVORY if has_prestige_choice else accent.lightened(0.20)
	)

	var eyebrow: Label = find_child("Eyebrow", true, false) as Label
	if eyebrow != null:
		eyebrow.add_theme_color_override("font_color", accent.lightened(0.08))

	var divider: ColorRect = find_child("Divider", true, false) as ColorRect
	if divider != null:
		divider.color = Color(accent.r, accent.g, accent.b, 0.70)

	_set_breakthrough_backdrop_accent(accent, has_prestige_choice)


func _prepare_upgrade_button_visual(button: Button) -> void:
	button.custom_minimum_size = Vector2(button.custom_minimum_size.x, 208.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_contents = true

	# Keep production scene subtree alive for external/HUD compatibility,
	# but render the premium production card through an isolated overlay.
	var legacy_margin: MarginContainer = button.get_node_or_null("Margin") as MarginContainer
	if legacy_margin != null:
		legacy_margin.visible = false

	var old_icon_well: Node = button.get_node_or_null("ChoiceIconWell")
	if old_icon_well != null:
		old_icon_well.queue_free()

	_build_premium_card_visual(button)


func _update_choice_icon(button: Button, upgrade_id: String) -> void:
	var icon: TextureRect = button.get_node_or_null("CardVisual/IconWell/Icon") as TextureRect
	if icon == null:
		return

	var icon_path: String = str(ICON_PATHS.get(upgrade_id, ""))
	if icon_path.is_empty():
		icon.texture = null
		return

	var resource: Resource = load(icon_path)
	if resource is Texture2D:
		icon.texture = resource as Texture2D
	else:
		icon.texture = null


func _apply_choice_card_style(button: Button, upgrade_id: String) -> void:
	var state: String = _get_choice_visual_state(upgrade_id)
	var skill_primary: Color = _get_skill_primary(upgrade_id)
	var skill_secondary: Color = _get_skill_secondary(upgrade_id)
	var accent: Color = _get_choice_border_accent(upgrade_id, state)
	var badge_accent: Color = _get_state_badge_accent(state, skill_secondary)
	var background: Color = _get_choice_background(upgrade_id, state)

	var border_width: int = 2
	var shadow_size: int = 10
	if state == "final":
		border_width = 3
		shadow_size = 16
	elif state == "awakening" or state == "resonance":
		border_width = 3
		shadow_size = 14
	elif state == "new":
		shadow_size = 12

	var normal_style: StyleBoxFlat = _make_card_style(
		background,
		accent,
		border_width,
		Color(skill_primary.r, skill_primary.g, skill_primary.b, 0.34),
		shadow_size
	)
	var hover_style: StyleBoxFlat = _make_card_style(
		background.lightened(0.045),
		accent.lightened(0.15),
		maxi(border_width, 3),
		Color(skill_primary.r, skill_primary.g, skill_primary.b, 0.48),
		shadow_size + 3
	)
	var pressed_style: StyleBoxFlat = _make_card_style(
		background.lightened(0.075),
		badge_accent.lightened(0.12),
		3,
		Color(skill_secondary.r, skill_secondary.g, skill_secondary.b, 0.56),
		shadow_size + 4
	)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)

	var rail: ColorRect = button.get_node_or_null("CardVisual/AccentRail") as ColorRect
	if rail != null:
		rail.color = Color(skill_primary.r, skill_primary.g, skill_primary.b, 0.95)

	var rail_glow: ColorRect = button.get_node_or_null("CardVisual/AccentRailGlow") as ColorRect
	if rail_glow != null:
		rail_glow.color = Color(skill_secondary.r, skill_secondary.g, skill_secondary.b, 0.52)

	var inner_frame: Panel = button.get_node_or_null("CardVisual/Ornaments/InnerFrame") as Panel
	if inner_frame != null:
		var inner_style: StyleBoxFlat = StyleBoxFlat.new()
		inner_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		inner_style.border_color = Color(skill_secondary.r, skill_secondary.g, skill_secondary.b, 0.34)
		inner_style.set_border_width_all(1)
		inner_style.set_corner_radius_all(8)
		inner_frame.add_theme_stylebox_override("panel", inner_style)

	var edge_color: Color = Color(accent.r, accent.g, accent.b, 0.78)
	var edge_soft: Color = Color(skill_secondary.r, skill_secondary.g, skill_secondary.b, 0.38)
	if state in ["awakening", "final", "resonance"]:
		edge_color = Color(badge_accent.r, badge_accent.g, badge_accent.b, 0.90)

	for edge_name in ["TopEdge", "LeftEdge", "RightEdge"]:
		var edge: ColorRect = button.get_node_or_null("CardVisual/Ornaments/" + edge_name) as ColorRect
		if edge != null:
			edge.color = edge_color
	var bottom_edge: ColorRect = button.get_node_or_null("CardVisual/Ornaments/BottomEdge") as ColorRect
	if bottom_edge != null:
		bottom_edge.color = edge_soft

	for gem_name in ["CornerGemTL", "CornerGemTR", "CornerGemBL", "CornerGemBR"]:
		var gem: ColorRect = button.get_node_or_null("CardVisual/Ornaments/" + gem_name) as ColorRect
		if gem != null:
			gem.color = Color(skill_secondary.r, skill_secondary.g, skill_secondary.b, 0.92)
	var top_gem: ColorRect = button.get_node_or_null("CardVisual/Ornaments/TopGem") as ColorRect
	if top_gem != null:
		top_gem.color = badge_accent.lightened(0.08)

	var icon_well: Panel = button.get_node_or_null("CardVisual/IconWell") as Panel
	if icon_well != null:
		var icon_style: StyleBoxFlat = StyleBoxFlat.new()
		icon_style.bg_color = Color(
			background.r * 0.54,
			background.g * 0.54,
			background.b * 0.54,
			0.995
		)
		icon_style.border_color = skill_secondary.lightened(0.08)
		icon_style.set_border_width_all(2 if state != "final" else 3)
		icon_style.set_corner_radius_all(14)
		icon_style.shadow_color = Color(skill_primary.r, skill_primary.g, skill_primary.b, 0.42)
		icon_style.shadow_size = 10 if state != "final" else 14
		icon_style.shadow_offset = Vector2(0.0, 3.0)
		icon_well.add_theme_stylebox_override("panel", icon_style)

	var badge: PanelContainer = button.get_node_or_null("CardVisual/Info/MetaRow/StateBadge") as PanelContainer
	if badge != null:
		var badge_style: StyleBoxFlat = StyleBoxFlat.new()
		badge_style.bg_color = Color(
			badge_accent.r * 0.13,
			badge_accent.g * 0.13,
			badge_accent.b * 0.13,
			0.94
		)
		badge_style.border_color = badge_accent
		badge_style.set_border_width_all(1 if state not in ["awakening", "final", "resonance"] else 2)
		badge_style.set_corner_radius_all(8)
		badge_style.content_margin_left = 9.0
		badge_style.content_margin_right = 9.0
		badge_style.content_margin_top = 3.0
		badge_style.content_margin_bottom = 3.0
		badge_style.shadow_color = Color(badge_accent.r, badge_accent.g, badge_accent.b, 0.26)
		badge_style.shadow_size = 5
		badge.add_theme_stylebox_override("panel", badge_style)

	var description_divider: ColorRect = button.get_node_or_null("CardVisual/Info/DescriptionDivider") as ColorRect
	if description_divider != null:
		description_divider.color = Color(skill_secondary.r, skill_secondary.g, skill_secondary.b, 0.24)

	var effect_panel: PanelContainer = button.get_node_or_null("CardVisual/Info/EffectPanel") as PanelContainer
	if effect_panel != null:
		var effect_style: StyleBoxFlat = StyleBoxFlat.new()
		effect_style.bg_color = Color(
			skill_primary.r * 0.045,
			skill_primary.g * 0.045,
			skill_primary.b * 0.045,
			0.92
		)
		effect_style.border_color = Color(skill_secondary.r, skill_secondary.g, skill_secondary.b, 0.40)
		effect_style.border_width_left = 4
		effect_style.border_width_top = 1
		effect_style.border_width_bottom = 1
		effect_style.set_corner_radius_all(7)
		effect_style.content_margin_left = 11.0
		effect_style.content_margin_right = 8.0
		effect_style.content_margin_top = 5.0
		effect_style.content_margin_bottom = 5.0
		effect_panel.add_theme_stylebox_override("panel", effect_style)

	var mastery: Label = button.get_node_or_null("CardVisual/IconWell/MasterySeal") as Label
	if mastery != null:
		mastery.visible = state == "final" or state == "resonance"
		mastery.add_theme_color_override(
			"font_color",
			CARD_IVORY if state == "final" else badge_accent.lightened(0.10)
		)

	_apply_choice_text_colors(button, upgrade_id, state)


func _refresh_choice_visual_colors() -> void:
	for i in range(min(current_upgrades.size(), upgrade_buttons.size())):
		if not upgrade_buttons[i].visible:
			continue
		_apply_choice_card_style(upgrade_buttons[i], current_upgrades[i])


func _apply_choice_text_colors(button: Button, upgrade_id: String, state: String) -> void:
	var category_label: Label = button.get_node_or_null("CardVisual/Info/MetaRow/CategoryLabel") as Label
	var badge_label: Label = button.get_node_or_null("CardVisual/Info/MetaRow/StateBadge/Label") as Label
	var title_label: Label = button.get_node_or_null("CardVisual/Info/TitleLabel") as Label
	var progress_label: Label = button.get_node_or_null("CardVisual/Info/ProgressLabel") as Label
	var effect_label: Label = button.get_node_or_null("CardVisual/Info/EffectPanel/EffectLabel") as Label
	var description_label: Label = button.get_node_or_null("CardVisual/Info/DescriptionClip/DescriptionLabel") as Label

	var skill_primary: Color = _get_skill_primary(upgrade_id)
	var skill_secondary: Color = _get_skill_secondary(upgrade_id)
	var badge_accent: Color = _get_state_badge_accent(state, skill_secondary)

	if category_label != null:
		category_label.add_theme_color_override("font_color", skill_primary.lightened(0.22))
	if badge_label != null:
		badge_label.add_theme_color_override("font_color", badge_accent.lightened(0.18))
		badge_label.add_theme_constant_override("outline_size", 1)
		badge_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 0.94))
	if title_label != null:
		title_label.add_theme_color_override(
			"font_color",
			CARD_IVORY if state == "final" else CARD_TEXT
		)
	if progress_label != null:
		progress_label.add_theme_color_override(
			"font_color",
			badge_accent.lightened(0.18) if state in ["new", "awakening", "final", "resonance"] else skill_secondary.lightened(0.10)
		)
	if effect_label != null:
		effect_label.add_theme_color_override(
			"font_color",
			CARD_IVORY if state in ["awakening", "final", "resonance"] else skill_secondary.lightened(0.22)
		)
	if description_label != null:
		description_label.add_theme_color_override("font_color", CARD_MUTED)


func _build_breakthrough_backdrop(margin: MarginContainer) -> void:
	if margin.get_node_or_null("BreakthroughBackdrop") != null:
		return

	var backdrop: Control = Control.new()
	backdrop.name = "BreakthroughBackdrop"
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(backdrop)
	margin.move_child(backdrop, 0)

	var header_glow: Panel = Panel.new()
	header_glow.name = "HeaderGlow"
	header_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_glow.anchor_right = 1.0
	header_glow.offset_bottom = 183.0
	backdrop.add_child(header_glow)

	var header_style: StyleBoxFlat = StyleBoxFlat.new()
	header_style.bg_color = Color(0.012, 0.095, 0.092, 0.52)
	header_style.border_color = Color(0.30, 0.86, 0.70, 0.34)
	header_style.border_width_bottom = 1
	header_style.set_corner_radius_all(13)
	header_glow.add_theme_stylebox_override("panel", header_style)

	var halo: TextureRect = TextureRect.new()
	halo.name = "RitualHalo"
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.texture = load("res://assets/ui/cultivation/meridian_dao_core.png")
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	halo.anchor_left = 0.5
	halo.anchor_right = 0.5
	halo.offset_left = -88.0
	halo.offset_right = 88.0
	halo.offset_top = -6.0
	halo.offset_bottom = 170.0
	halo.modulate = Color(0.30, 0.94, 0.78, 0.12)
	header_glow.add_child(halo)

	var left_line: ColorRect = ColorRect.new()
	left_line.name = "LeftLine"
	left_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_line.anchor_left = 0.0
	left_line.anchor_top = 0.0
	left_line.offset_left = 40.0
	left_line.offset_right = 205.0
	left_line.offset_top = 84.0
	left_line.offset_bottom = 85.5
	left_line.color = Color(0.92, 0.70, 0.30, 0.45)
	header_glow.add_child(left_line)

	var right_line: ColorRect = ColorRect.new()
	right_line.name = "RightLine"
	right_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_line.anchor_left = 1.0
	right_line.anchor_right = 1.0
	right_line.offset_left = -205.0
	right_line.offset_right = -40.0
	right_line.offset_top = 84.0
	right_line.offset_bottom = 85.5
	right_line.color = left_line.color
	header_glow.add_child(right_line)


func _set_breakthrough_backdrop_accent(accent: Color, prestige: bool) -> void:
	var header_glow: Panel = get_node_or_null(
		"SafeArea/Center/Frame/Margin/BreakthroughBackdrop/HeaderGlow"
	) as Panel
	if header_glow != null:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(
			accent.r * 0.06,
			accent.g * 0.06,
			accent.b * 0.06,
			0.56
		)
		style.border_color = Color(accent.r, accent.g, accent.b, 0.42)
		style.border_width_bottom = 1
		style.set_corner_radius_all(13)
		header_glow.add_theme_stylebox_override("panel", style)

	var halo: TextureRect = get_node_or_null(
		"SafeArea/Center/Frame/Margin/BreakthroughBackdrop/HeaderGlow/RitualHalo"
	) as TextureRect
	if halo != null:
		halo.modulate = Color(
			accent.r,
			accent.g,
			accent.b,
			0.18 if prestige else 0.13
		)

	for line_name in ["LeftLine", "RightLine"]:
		var line: ColorRect = get_node_or_null(
			"SafeArea/Center/Frame/Margin/BreakthroughBackdrop/HeaderGlow/" + line_name
		) as ColorRect
		if line != null:
			line.color = Color(accent.r, accent.g, accent.b, 0.52)


func _build_premium_card_visual(button: Button) -> void:
	if button.get_node_or_null("CardVisual") != null:
		return

	var card: Control = Control.new()
	card.name = "CardVisual"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.clip_contents = true
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(card)

	# Layered ornamental frame. These pieces stay behind content and are tinted
	# per skill/state at runtime, giving depth without adding heavy textures.
	var ornaments: Control = Control.new()
	ornaments.name = "Ornaments"
	ornaments.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornaments.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(ornaments)

	var inner_frame: Panel = Panel.new()
	inner_frame.name = "InnerFrame"
	inner_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_frame.offset_left = 5.0
	inner_frame.offset_top = 5.0
	inner_frame.offset_right = -5.0
	inner_frame.offset_bottom = -5.0
	ornaments.add_child(inner_frame)

	var top_edge: ColorRect = ColorRect.new()
	top_edge.name = "TopEdge"
	top_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_edge.anchor_right = 1.0
	top_edge.offset_left = 30.0
	top_edge.offset_right = -30.0
	top_edge.offset_top = 3.0
	top_edge.offset_bottom = 5.0
	ornaments.add_child(top_edge)

	var bottom_edge: ColorRect = ColorRect.new()
	bottom_edge.name = "BottomEdge"
	bottom_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_edge.anchor_top = 1.0
	bottom_edge.anchor_right = 1.0
	bottom_edge.anchor_bottom = 1.0
	bottom_edge.offset_left = 42.0
	bottom_edge.offset_right = -42.0
	bottom_edge.offset_top = -5.0
	bottom_edge.offset_bottom = -3.0
	ornaments.add_child(bottom_edge)

	var left_edge: ColorRect = ColorRect.new()
	left_edge.name = "LeftEdge"
	left_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_edge.anchor_bottom = 1.0
	left_edge.offset_left = 3.0
	left_edge.offset_right = 5.0
	left_edge.offset_top = 28.0
	left_edge.offset_bottom = -28.0
	ornaments.add_child(left_edge)

	var right_edge: ColorRect = ColorRect.new()
	right_edge.name = "RightEdge"
	right_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_edge.anchor_left = 1.0
	right_edge.anchor_right = 1.0
	right_edge.anchor_bottom = 1.0
	right_edge.offset_left = -5.0
	right_edge.offset_right = -3.0
	right_edge.offset_top = 28.0
	right_edge.offset_bottom = -28.0
	ornaments.add_child(right_edge)

	var gem_specs: Array = [
		["CornerGemTL", 10.0, 10.0, 0.0, 0.0],
		["CornerGemTR", -18.0, 10.0, 1.0, 0.0],
		["CornerGemBL", 10.0, -18.0, 0.0, 1.0],
		["CornerGemBR", -18.0, -18.0, 1.0, 1.0]
	]
	for spec in gem_specs:
		var gem: ColorRect = ColorRect.new()
		gem.name = str(spec[0])
		gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem.anchor_left = float(spec[3])
		gem.anchor_right = float(spec[3])
		gem.anchor_top = float(spec[4])
		gem.anchor_bottom = float(spec[4])
		gem.offset_left = float(spec[1])
		gem.offset_top = float(spec[2])
		gem.offset_right = float(spec[1]) + 8.0
		gem.offset_bottom = float(spec[2]) + 8.0
		gem.pivot_offset = Vector2(4.0, 4.0)
		gem.rotation = deg_to_rad(45.0)
		ornaments.add_child(gem)

	var top_gem: ColorRect = ColorRect.new()
	top_gem.name = "TopGem"
	top_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_gem.anchor_left = 0.5
	top_gem.anchor_right = 0.5
	top_gem.offset_left = -6.0
	top_gem.offset_right = 6.0
	top_gem.offset_top = -1.0
	top_gem.offset_bottom = 11.0
	top_gem.pivot_offset = Vector2(6.0, 6.0)
	top_gem.rotation = deg_to_rad(45.0)
	ornaments.add_child(top_gem)

	var rail_glow: ColorRect = ColorRect.new()
	rail_glow.name = "AccentRailGlow"
	rail_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_glow.anchor_bottom = 1.0
	rail_glow.offset_left = 4.0
	rail_glow.offset_right = 8.0
	rail_glow.offset_top = 15.0
	rail_glow.offset_bottom = -15.0
	card.add_child(rail_glow)

	var rail: ColorRect = ColorRect.new()
	rail.name = "AccentRail"
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.anchor_bottom = 1.0
	rail.offset_left = 5.0
	rail.offset_right = 7.0
	rail.offset_top = 12.0
	rail.offset_bottom = -12.0
	rail.color = CARD_JADE
	card.add_child(rail)

	var icon_well: Panel = Panel.new()
	icon_well.name = "IconWell"
	icon_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_well.anchor_top = 0.5
	icon_well.anchor_bottom = 0.5
	icon_well.offset_left = 16.0
	icon_well.offset_right = 140.0
	icon_well.offset_top = -62.0
	icon_well.offset_bottom = 62.0
	card.add_child(icon_well)

	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = 9.0
	icon.offset_top = 9.0
	icon.offset_right = -9.0
	icon.offset_bottom = -9.0
	icon_well.add_child(icon)

	var mastery_seal: Label = Label.new()
	mastery_seal.name = "MasterySeal"
	mastery_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mastery_seal.anchor_left = 1.0
	mastery_seal.anchor_right = 1.0
	mastery_seal.offset_left = -30.0
	mastery_seal.offset_right = -4.0
	mastery_seal.offset_top = 4.0
	mastery_seal.offset_bottom = 28.0
	mastery_seal.text = "VII"
	mastery_seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mastery_seal.add_theme_font_size_override("font_size", 11)
	mastery_seal.add_theme_constant_override("outline_size", 2)
	mastery_seal.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.01, 0.95))
	mastery_seal.visible = false
	icon_well.add_child(mastery_seal)

	var info: VBoxContainer = VBoxContainer.new()
	info.name = "Info"
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.clip_contents = true
	info.anchor_right = 1.0
	info.anchor_bottom = 1.0
	info.offset_left = 154.0
	info.offset_top = 10.0
	info.offset_right = -18.0
	info.offset_bottom = -10.0
	info.add_theme_constant_override("separation", 2)
	card.add_child(info)

	var meta_row: HBoxContainer = HBoxContainer.new()
	meta_row.name = "MetaRow"
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_row.custom_minimum_size = Vector2(0.0, 25.0)
	info.add_child(meta_row)

	var category: Label = Label.new()
	category.name = "CategoryLabel"
	category.mouse_filter = Control.MOUSE_FILTER_IGNORE
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category.theme_type_variation = &"JadeSubtitle"
	category.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	category.add_theme_font_size_override("font_size", 12)
	meta_row.add_child(category)

	var badge: PanelContainer = PanelContainer.new()
	badge.name = "StateBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(0.0, 25.0)
	meta_row.add_child(badge)

	var badge_label: Label = Label.new()
	badge_label.name = "Label"
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.add_theme_font_size_override("font_size", 11)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)

	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.theme_type_variation = &"JadeHeroName"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.022, 0.96))
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(title)

	var progress: Label = Label.new()
	progress.name = "ProgressLabel"
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.theme_type_variation = &"JadeQiLabel"
	progress.add_theme_constant_override("outline_size", 1)
	progress.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 0.90))
	progress.add_theme_font_size_override("font_size", 13)
	info.add_child(progress)

	var effect_panel: PanelContainer = PanelContainer.new()
	effect_panel.name = "EffectPanel"
	effect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_panel.custom_minimum_size = Vector2(0.0, 48.0)
	info.add_child(effect_panel)

	var effect: Label = Label.new()
	effect.name = "EffectLabel"
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.theme_type_variation = &"JadeQiLabel"
	effect.add_theme_font_size_override("font_size", 16)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.max_lines_visible = 2
	effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect.add_theme_constant_override("outline_size", 1)
	effect.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 0.88))
	effect_panel.add_child(effect)

	var description_divider: ColorRect = ColorRect.new()
	description_divider.name = "DescriptionDivider"
	description_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_divider.custom_minimum_size = Vector2(0.0, 1.0)
	description_divider.color = Color(0.55, 0.70, 0.66, 0.18)
	info.add_child(description_divider)

	var description_clip: Control = Control.new()
	description_clip.name = "DescriptionClip"
	description_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_clip.clip_contents = true
	description_clip.custom_minimum_size = Vector2(0.0, 34.0)
	info.add_child(description_clip)

	var description: Label = Label.new()
	description.name = "DescriptionLabel"
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.theme_type_variation = &"JadeMutedLabel"
	description.add_theme_font_size_override("font_size", 13)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 2
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description.set_anchors_preset(Control.PRESET_FULL_RECT)
	description_clip.add_child(description)


func _set_premium_card_text(button: Button, upgrade_id: String) -> void:
	var category: Label = button.get_node_or_null("CardVisual/Info/MetaRow/CategoryLabel") as Label
	var state: Label = button.get_node_or_null("CardVisual/Info/MetaRow/StateBadge/Label") as Label
	var title: Label = button.get_node_or_null("CardVisual/Info/TitleLabel") as Label
	var progress: Label = button.get_node_or_null("CardVisual/Info/ProgressLabel") as Label
	var effect: Label = button.get_node_or_null("CardVisual/Info/EffectPanel/EffectLabel") as Label
	var description: Label = button.get_node_or_null("CardVisual/Info/DescriptionClip/DescriptionLabel") as Label

	if category != null:
		category.text = get_upgrade_category(upgrade_id)
	if state != null:
		state.text = get_upgrade_state_label(upgrade_id)
	if title != null:
		title.text = get_upgrade_display_name(upgrade_id)
	if progress != null:
		progress.text = get_upgrade_progress(upgrade_id)
	if effect != null:
		effect.text = _get_card_effect_text(upgrade_id)
	if description != null:
		description.text = get_upgrade_description(upgrade_id)


func _get_card_effect_text(upgrade_id: String) -> String:
	var effect_text: String = get_upgrade_effect(upgrade_id)
	# Two-line benefits scan much better on the portrait mobile card than a
	# compressed single line. Gameplay-facing source text remains unchanged.
	if " • " in effect_text:
		return effect_text.replace(" • ", "\n")
	return effect_text

func _get_choice_visual_state(upgrade_id: String) -> String:
	if RESONANCE_UPGRADE_IDS.has(upgrade_id):
		return "resonance"

	if WEAPON_UPGRADE_IDS.has(upgrade_id):
		if _is_new_weapon(upgrade_id):
			return "new"
		if _is_final_weapon_refinement(upgrade_id):
			return "final"

		var next_level: int = _get_current_weapon_level(upgrade_id) + 1
		if _is_weapon_milestone(upgrade_id, next_level):
			return "awakening"
		return "weapon"

	return "refine"


func _get_skill_theme(upgrade_id: String) -> Array:
	var raw_theme: Variant = SKILL_THEME_COLORS.get(upgrade_id, [])
	if raw_theme is Array and (raw_theme as Array).size() >= 3:
		return raw_theme as Array
	return [CARD_JADE, Color(0.72, 1.0, 0.90, 1.0), Color(0.016, 0.080, 0.065, 0.992)]


func _get_skill_primary(upgrade_id: String) -> Color:
	var skill_theme: Array = _get_skill_theme(upgrade_id)
	var color: Color = skill_theme[0]
	return color


func _get_skill_secondary(upgrade_id: String) -> Color:
	var skill_theme: Array = _get_skill_theme(upgrade_id)
	var color: Color = skill_theme[1]
	return color


func _get_skill_base_background(upgrade_id: String) -> Color:
	var skill_theme: Array = _get_skill_theme(upgrade_id)
	var color: Color = skill_theme[2]
	return color


func _get_state_badge_accent(state: String, fallback: Color) -> Color:
	var color: Color = STATE_BADGE_COLORS.get(state, fallback)
	return color


func _get_choice_border_accent(upgrade_id: String, state: String) -> Color:
	var primary: Color = _get_skill_primary(upgrade_id)
	var secondary: Color = _get_skill_secondary(upgrade_id)
	match state:
		"new":
			return primary.lerp(secondary, 0.28).lightened(0.08)
		"awakening":
			return primary.lerp(CARD_GOLD, 0.34).lightened(0.05)
		"final":
			return primary.lerp(CARD_IVORY, 0.52).lightened(0.05)
		"resonance":
			return primary.lerp(Color(0.82, 0.48, 1.0, 1.0), 0.34).lightened(0.06)
	return primary


func _get_choice_background(upgrade_id: String, state: String) -> Color:
	var base: Color = _get_skill_base_background(upgrade_id)
	match state:
		"new":
			return base.lightened(0.018)
		"awakening":
			return base.lerp(Color(0.100, 0.055, 0.010, 0.992), 0.20)
		"final":
			return base.lerp(Color(0.105, 0.067, 0.015, 0.995), 0.28)
		"resonance":
			return base.lerp(Color(0.070, 0.030, 0.100, 0.994), 0.25)
	return base


func _make_card_style(
	background: Color,
	border: Color,
	border_width: int,
	shadow: Color,
	shadow_size: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(12)
	style.shadow_color = shadow
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 3.0)
	style.anti_aliasing = true
	return style



func _queue_special_choice_pulse() -> void:
	if _reduced_effects_enabled():
		return

	await get_tree().create_timer(0.38, true, false, true).timeout
	if not is_inside_tree() or not visible:
		return

	for i in range(min(current_upgrades.size(), upgrade_buttons.size())):
		var state: String = _get_choice_visual_state(current_upgrades[i])
		if state not in ["new", "awakening", "final", "resonance"]:
			continue

		var button: Button = upgrade_buttons[i]
		var badge: PanelContainer = button.get_node_or_null("CardVisual/Info/MetaRow/StateBadge") as PanelContainer
		var icon_well: Panel = button.get_node_or_null("CardVisual/IconWell") as Panel
		if badge == null or icon_well == null:
			continue

		badge.pivot_offset = badge.size * 0.5
		icon_well.pivot_offset = icon_well.size * 0.5

		var pulse: Tween = create_tween()
		pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		pulse.set_trans(Tween.TRANS_SINE)
		pulse.set_ease(Tween.EASE_OUT)
		pulse.parallel().tween_property(badge, "scale", Vector2(1.06, 1.06), 0.11)
		pulse.parallel().tween_property(icon_well, "scale", Vector2(1.035, 1.035), 0.11)
		pulse.chain().tween_property(badge, "scale", Vector2.ONE, 0.16)
		pulse.parallel().tween_property(icon_well, "scale", Vector2.ONE, 0.16)

func _reduced_effects_enabled() -> bool:
	var settings_manager: Node = get_node_or_null("/root/SettingsManager")
	if settings_manager == null:
		return false
	return bool(settings_manager.get("reduced_effects"))


func _play_upgrade_selection_sfx() -> void:
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		return
	if audio_manager.has_method("play_sfx"):
		audio_manager.call("play_sfx", "upgrade")
