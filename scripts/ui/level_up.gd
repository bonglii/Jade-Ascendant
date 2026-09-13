extends Control

## Level Up
## Mengelola pilihan upgrade saat Player naik level.
## Logic availability dan application tetap menjadi authority gameplay existing.
## Script ini juga mengisi presentation metadata untuk choice cards.

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
		var pressed_callable: Callable = _on_upgrade_button_pressed.bind(i)
		if not button.pressed.is_connected(pressed_callable):
			button.pressed.connect(pressed_callable)

func show_level_up() -> void:
	if player == null:
		return

	generate_upgrades()

	if current_upgrades.is_empty():
		DebugLogger.system(str("Tidak ada upgrade yang tersedia."))
		return

	breakthrough_level_label.text = tr("LEVEL %d • BREAKTHROUGH") % int(player.level)
	update_buttons()

	show()
	get_tree().paused = true

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

	var is_resonance: bool = RESONANCE_UPGRADE_IDS.has(upgrade_id)
	if is_resonance:
		category_label.add_theme_color_override("font_color", Color(0.96, 0.72, 0.26, 1.0))
		state_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.38, 1.0))
		title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 1.0))
	else:
		category_label.add_theme_color_override("font_color", Color(0.29, 0.90, 0.82, 1.0))
		state_label.add_theme_color_override("font_color", Color(0.91, 0.72, 0.32, 1.0))
		title_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.62, 1.0))

func get_upgrade_category(upgrade_id: String) -> String:
	match upgrade_id:
		"spirit_sword", "fire_orb", "thunder_talisman", "yin_yang_blades", "heavenly_sword_rain", "eight_trigrams_formation":
			return "WEAPON ART"
		"body_refinement", "qi_shield", "iron_body", "blood_qi":
			return "BODY CULTIVATION"
		"spiritual_insight", "sword_intent":
			return "DAO INSIGHT"
		"sword_dao_resonance", "yin_yang_reversal", "heavenly_tribulation":
			return "RESONANCE"
	return "MARTIAL FLOW"

func get_upgrade_state_label(upgrade_id: String) -> String:
	if RESONANCE_UPGRADE_IDS.has(upgrade_id):
		return "RESONANCE • UNLOCK"

	if WEAPON_UPGRADE_IDS.has(upgrade_id):
		var weapon_name: String = _get_weapon_name(upgrade_id)
		var weapon: Variant = weapon_manager.get_weapon_by_name(weapon_name)
		if weapon == null:
			return "NEW ART"
		return "UPGRADE"

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
			return "Movement Speed"
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
			return "Refine the flying sword that hunts nearby enemies."
		"fire_orb":
			return "Strengthen the fire orb launched toward nearby targets."
		"power":
			return "Condense martial force to amplify all outgoing damage."
		"attack_speed":
			return "Cycle qi faster to shorten the interval between attacks."
		"movement_speed":
			return "Circulate swift qi through the body to move faster."
		"body_refinement":
			return "Temper the body to expand the vessel of life."
		"qi_shield":
			return "Form a protective qi layer that negates an incoming hit."
		"thunder_talisman":
			return "Command chained lightning through a thunder talisman."
		"yin_yang_blades":
			return "Orbit paired blades around the cultivator to cut nearby foes."
		"heavenly_sword_rain":
			return "Call repeated sword strikes around a chosen enemy."
		"eight_trigrams_formation":
			return "Manifest a pulsing formation that damages enemies within it."
		"spiritual_insight":
			return "Deepen comprehension to gain more experience from battle."
		"iron_body":
			return "Harden flesh and bone to reduce incoming damage."
		"blood_qi":
			return "Convert repeated kills into gradual recovery during the run."
		"sword_intent":
			return "Sharpen sword intent to increase critical strike chance."
		"sword_dao_resonance":
			return "Spirit Sword hits can launch a resonance sword toward a secondary enemy."
		"yin_yang_reversal":
			return "A Qi Shield block awakens a temporary empowered Yin-Yang orbit."
		"heavenly_tribulation":
			return "Successful Sword Rain impacts can call down Heavenly Lightning."
	return "Refine this cultivation path for the current run."

func get_upgrade_effect(upgrade_id: String) -> String:
	match upgrade_id:
		"spirit_sword":
			return "+5 BASE DAMAGE"
		"fire_orb":
			return "+10 BASE DAMAGE"
		"power":
			return "+10% DAMAGE POWER"
		"attack_speed":
			return "ATTACK COOLDOWN ×0.90"
		"movement_speed":
			return "MOVEMENT SPEED ×1.10"
		"body_refinement":
			return "+2 MAX HP • +2 HP"
		"qi_shield":
			return "+1 SHIELD CHARGE"
		"thunder_talisman":
			if _is_new_weapon(upgrade_id):
				return "GAIN THUNDER TALISMAN"
			return "+4 BASE DAMAGE • CHAIN MILESTONES"
		"yin_yang_blades":
			if _is_new_weapon(upgrade_id):
				return "GAIN 2 ORBITING BLADES"
			return "+3 BASE DAMAGE • BLADE MILESTONES"
		"heavenly_sword_rain":
			if _is_new_weapon(upgrade_id):
				return "GAIN HEAVENLY SWORD RAIN"
			return "+4 BASE DAMAGE • STRIKE MILESTONES"
		"eight_trigrams_formation":
			if _is_new_weapon(upgrade_id):
				return "GAIN EIGHT TRIGRAMS FORMATION"
			return "REFINE FORMATION BY LEVEL"
		"spiritual_insight":
			return "+15% EXP MULTIPLIER"
		"iron_body":
			return "+5% DAMAGE REDUCTION"
		"blood_qi":
			return "HEAL 1 HP • LOWER KILL THRESHOLD"
		"sword_intent":
			return "+5% CRITICAL CHANCE"
		"sword_dao_resonance":
			return "SECONDARY SPIRIT SWORD"
		"yin_yang_reversal":
			return "4s EMPOWERED ORBIT AFTER SHIELD BLOCK"
		"heavenly_tribulation":
			return "HEAVENLY LIGHTNING ON SWORD RAIN HIT"
	return "RUN UPGRADE"

func get_upgrade_progress(upgrade_id: String) -> String:
	if RESONANCE_UPGRADE_IDS.has(upgrade_id):
		return "RUN-LIMITED UNLOCK"

	if WEAPON_UPGRADE_IDS.has(upgrade_id):
		var weapon_name: String = _get_weapon_name(upgrade_id)
		var weapon: Variant = weapon_manager.get_weapon_by_name(weapon_name)
		if weapon == null:
			return "NEW • LV.1"
		var weapon_level: int = int(weapon.level)
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
	get_tree().paused = false
	player.call_deferred("resolve_pending_level_up")

func _on_upgrade_button_pressed(button_index: int) -> void:
	if not visible:
		return
	if button_index < 0:
		return
	if button_index >= current_upgrades.size():
		return

	var upgrade_id: String = current_upgrades[button_index]
	apply_upgrade(upgrade_id)
