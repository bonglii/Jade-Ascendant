extends CharacterBody2D

## Boss
## Mengelola movement, health, melee attack, ranged attack,
## pemilihan attack pattern, phase combat, dan status kematian Boss.

signal boss_defeated
signal health_changed(current_hp: float, max_hp: float)
signal phase_changed(current_phase: int)

const PROJECTILE_SCENE: PackedScene = preload(
	"res://scenes/enemy/boss_projectile.tscn"
)

const LIGHTNING_STRIKE_SCENE: PackedScene = preload(
	"res://scenes/enemy/boss_lightning_strike.tscn"
)

const QI_SHOCKWAVE_SCENE: PackedScene = preload(
	"res://scenes/enemy/boss_qi_shockwave.tscn"
)

const TRIAL_GUARDIAN_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/boss_1_valley_trial_guardian_spriteframes.tres"
)

const TRIAL_GUARDIAN_STYLE: int = 0
const TRIAL_GUARDIAN_DISPLAY_NAME: String = "Valley Trial Guardian"
const TRIAL_GUARDIAN_VISUAL_POSITION: Vector2 = Vector2(0.0, -18.0)
const TRIAL_GUARDIAN_VISUAL_SCALE: Vector2 = Vector2(1.30, 1.30)
const TRIAL_GUARDIAN_FOOTPRINT_RADIUS: float = 18.0
const TRIAL_GUARDIAN_FOOTPRINT_HEIGHT: float = 40.0
const TRIAL_GUARDIAN_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 12.0)

const SOVEREIGN_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/boss_1_jade_valley_sovereign_spriteframes.tres"
)

const SOVEREIGN_STYLE: int = 0
const ASCENDED_SOVEREIGN_STYLE: int = 4
const SOVEREIGN_DISPLAY_NAME: String = "Jade Valley Sovereign"
const ASCENDED_SOVEREIGN_DISPLAY_NAME: String = "Jade Valley Sovereign · Ascended"
const SOVEREIGN_VISUAL_POSITION: Vector2 = Vector2(0.0, -27.0)
const SOVEREIGN_VISUAL_SCALE: Vector2 = Vector2(1.65, 1.65)
const SOVEREIGN_FOOTPRINT_RADIUS: float = 22.0
const SOVEREIGN_FOOTPRINT_HEIGHT: float = 50.0
const SOVEREIGN_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 15.0)

const MISTBLADE_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/boss_1_mistblade_warden_spriteframes.tres"
)

const MISTBLADE_STYLE: int = 1
const MISTBLADE_VISUAL_POSITION: Vector2 = Vector2(0.0, -25.0)
const MISTBLADE_VISUAL_SCALE: Vector2 = Vector2(1.55, 1.55)
const MISTBLADE_FOOTPRINT_RADIUS: float = 18.0
const MISTBLADE_FOOTPRINT_HEIGHT: float = 42.0
const MISTBLADE_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 15.0)

const SHRINE_KEEPER_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/boss_1_jade_shrine_keeper_spriteframes.tres"
)

const SHRINE_KEEPER_STYLE: int = 2
const SHRINE_KEEPER_VISUAL_POSITION: Vector2 = Vector2(0.0, -22.0)
const SHRINE_KEEPER_VISUAL_SCALE: Vector2 = Vector2(1.45, 1.45)
const SHRINE_KEEPER_FOOTPRINT_RADIUS: float = 24.0
const SHRINE_KEEPER_FOOTPRINT_HEIGHT: float = 52.0
const SHRINE_KEEPER_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 14.0)

const STORMPEAK_HERALD_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/boss_1_stormpeak_herald_spriteframes.tres"
)

const STORMPEAK_HERALD_STYLE: int = 3
const STORMPEAK_HERALD_VISUAL_POSITION: Vector2 = Vector2(0.0, -25.0)
const STORMPEAK_HERALD_VISUAL_SCALE: Vector2 = Vector2(1.52, 1.52)
const STORMPEAK_HERALD_FOOTPRINT_RADIUS: float = 20.0
const STORMPEAK_HERALD_FOOTPRINT_HEIGHT: float = 48.0
const STORMPEAK_HERALD_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 14.0)

# Chapter 2 — Crimson Moon Sect dedicated boss identities.
# Combat values remain profile-driven by ChapterTwoCatalog; these constants own
# presentation and gameplay footprint only.
const BLOODWOOD_MOONSTALKER_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/boss_2_bloodwood_moonstalker_spriteframes.tres"
)
const BLOODWOOD_MOONSTALKER_DISPLAY_NAME: String = "Bloodwood Moonstalker"
const BLOODWOOD_MOONSTALKER_VISUAL_POSITION: Vector2 = Vector2(0.0, -22.0)
const BLOODWOOD_MOONSTALKER_VISUAL_SCALE: Vector2 = Vector2(1.45, 1.45)
const BLOODWOOD_MOONSTALKER_FOOTPRINT_RADIUS: float = 18.0
const BLOODWOOD_MOONSTALKER_FOOTPRINT_HEIGHT: float = 42.0
const BLOODWOOD_MOONSTALKER_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 14.0)

const CINNABAR_VEIL_ASSASSIN_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/boss_2_cinnabar_veil_assassin_spriteframes.tres"
)
const CINNABAR_VEIL_ASSASSIN_DISPLAY_NAME: String = "Cinnabar Veil Assassin"
const CINNABAR_VEIL_ASSASSIN_VISUAL_POSITION: Vector2 = Vector2(0.0, -24.0)
const CINNABAR_VEIL_ASSASSIN_VISUAL_SCALE: Vector2 = Vector2(1.42, 1.42)
const CINNABAR_VEIL_ASSASSIN_FOOTPRINT_RADIUS: float = 17.0
const CINNABAR_VEIL_ASSASSIN_FOOTPRINT_HEIGHT: float = 40.0
const CINNABAR_VEIL_ASSASSIN_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 14.0)

const SCARLET_RITE_KEEPER_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/boss_2_scarlet_rite_keeper_spriteframes.tres"
)
const SCARLET_RITE_KEEPER_DISPLAY_NAME: String = "Scarlet Rite Keeper"
const SCARLET_RITE_KEEPER_VISUAL_POSITION: Vector2 = Vector2(0.0, -21.0)
const SCARLET_RITE_KEEPER_VISUAL_SCALE: Vector2 = Vector2(1.50, 1.50)
const SCARLET_RITE_KEEPER_FOOTPRINT_RADIUS: float = 24.0
const SCARLET_RITE_KEEPER_FOOTPRINT_HEIGHT: float = 54.0
const SCARLET_RITE_KEEPER_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 15.0)

const BLOOD_MOON_ASCENDANT_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/boss_2_blood_moon_ascendant_spriteframes.tres"
)
const BLOOD_MOON_ASCENDANT_DISPLAY_NAME: String = "Blood Moon Ascendant"
const BLOOD_MOON_ASCENDANT_VISUAL_POSITION: Vector2 = Vector2(0.0, -28.0)
const BLOOD_MOON_ASCENDANT_VISUAL_SCALE: Vector2 = Vector2(1.58, 1.58)
const BLOOD_MOON_ASCENDANT_FOOTPRINT_RADIUS: float = 19.0
const BLOOD_MOON_ASCENDANT_FOOTPRINT_HEIGHT: float = 46.0
const BLOOD_MOON_ASCENDANT_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 14.0)

const CRIMSON_MOON_SECT_MASTER_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/boss_2_crimson_moon_sect_master_spriteframes.tres"
)
const CRIMSON_MOON_SECT_MASTER_DISPLAY_NAME: String = "Crimson Moon Sect Master"
const CRIMSON_MOON_SECT_MASTER_VISUAL_POSITION: Vector2 = Vector2(0.0, -29.0)
const CRIMSON_MOON_SECT_MASTER_VISUAL_SCALE: Vector2 = Vector2(1.70, 1.70)
const CRIMSON_MOON_SECT_MASTER_FOOTPRINT_RADIUS: float = 22.0
const CRIMSON_MOON_SECT_MASTER_FOOTPRINT_HEIGHT: float = 50.0
const CRIMSON_MOON_SECT_MASTER_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 15.0)

# Chapter 3 — Nine Heavens Star Palace dedicated boss identities.
# Combat values remain profile-driven by ChapterThreeCatalog.
const CLOUDSEA_GATE_WARDEN_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/chapter3/boss_3_cloudsea_gate_warden_spriteframes.tres"
)
const CLOUDSEA_GATE_WARDEN_DISPLAY_NAME: String = "Cloudsea Gate Warden"
const CLOUDSEA_GATE_WARDEN_VISUAL_POSITION: Vector2 = Vector2(0.0, -24.0)
const CLOUDSEA_GATE_WARDEN_VISUAL_SCALE: Vector2 = Vector2(1.48, 1.48)
const CLOUDSEA_GATE_WARDEN_FOOTPRINT_RADIUS: float = 20.0
const CLOUDSEA_GATE_WARDEN_FOOTPRINT_HEIGHT: float = 46.0
const CLOUDSEA_GATE_WARDEN_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 14.0)

const ASTRAL_MIRROR_DAOIST_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/chapter3/boss_3_astral_mirror_daoist_spriteframes.tres"
)
const ASTRAL_MIRROR_DAOIST_DISPLAY_NAME: String = "Astral Mirror Daoist"
const ASTRAL_MIRROR_DAOIST_VISUAL_POSITION: Vector2 = Vector2(0.0, -26.0)
const ASTRAL_MIRROR_DAOIST_VISUAL_SCALE: Vector2 = Vector2(1.46, 1.46)
const ASTRAL_MIRROR_DAOIST_FOOTPRINT_RADIUS: float = 18.0
const ASTRAL_MIRROR_DAOIST_FOOTPRINT_HEIGHT: float = 42.0
const ASTRAL_MIRROR_DAOIST_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 14.0)

const CONSTELLATION_SWORD_SAINT_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/chapter3/boss_3_constellation_sword_saint_spriteframes.tres"
)
const CONSTELLATION_SWORD_SAINT_DISPLAY_NAME: String = "Constellation Sword Saint"
const CONSTELLATION_SWORD_SAINT_VISUAL_POSITION: Vector2 = Vector2(0.0, -27.0)
const CONSTELLATION_SWORD_SAINT_VISUAL_SCALE: Vector2 = Vector2(1.58, 1.58)
const CONSTELLATION_SWORD_SAINT_FOOTPRINT_RADIUS: float = 20.0
const CONSTELLATION_SWORD_SAINT_FOOTPRINT_HEIGHT: float = 46.0
const CONSTELLATION_SWORD_SAINT_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 14.0)

const NINEFOLD_HEAVEN_ARBITER_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/chapter3/boss_3_ninefold_heaven_arbiter_spriteframes.tres"
)
const NINEFOLD_HEAVEN_ARBITER_DISPLAY_NAME: String = "Ninefold Heaven Arbiter"
const NINEFOLD_HEAVEN_ARBITER_VISUAL_POSITION: Vector2 = Vector2(0.0, -29.0)
const NINEFOLD_HEAVEN_ARBITER_VISUAL_SCALE: Vector2 = Vector2(1.62, 1.62)
const NINEFOLD_HEAVEN_ARBITER_FOOTPRINT_RADIUS: float = 20.0
const NINEFOLD_HEAVEN_ARBITER_FOOTPRINT_HEIGHT: float = 48.0
const NINEFOLD_HEAVEN_ARBITER_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 15.0)

const STAR_PALACE_CELESTIAL_SOVEREIGN_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/enemy/chapter3/boss_3_star_palace_celestial_sovereign_spriteframes.tres"
)
const STAR_PALACE_CELESTIAL_SOVEREIGN_DISPLAY_NAME: String = "Star Palace Celestial Sovereign"
const STAR_PALACE_CELESTIAL_SOVEREIGN_VISUAL_POSITION: Vector2 = Vector2(0.0, -31.0)
const STAR_PALACE_CELESTIAL_SOVEREIGN_VISUAL_SCALE: Vector2 = Vector2(1.78, 1.78)
const STAR_PALACE_CELESTIAL_SOVEREIGN_FOOTPRINT_RADIUS: float = 23.0
const STAR_PALACE_CELESTIAL_SOVEREIGN_FOOTPRINT_HEIGHT: float = 52.0
const STAR_PALACE_CELESTIAL_SOVEREIGN_FOOTPRINT_POSITION: Vector2 = Vector2(0.0, 15.0)

const PHASE_ONE: int = 1
const PHASE_TWO: int = 2

const FACING_HORIZONTAL_THRESHOLD: float = 0.05
const MELEE_VISUAL_DURATION: float = 0.45
const PROJECTILE_CAST_VISUAL_DURATION: float = 0.50
const RADIAL_CAST_VISUAL_DURATION: float = 0.65
const PHASE_TWO_VISUAL_DURATION: float = 0.90

const RANGED_SINGLE_PROJECTILE: int = 0
const RANGED_RADIAL_BURST: int = 1
const RANGED_HEAVENLY_LIGHTNING: int = 2
const RANGED_ASCENDED_CROSS: int = 3

@export var speed: float = 50.0
@export var reward_source_id: String = "boss_1"
@export var melee_distance: float = 120.0
@export var ranged_distance: float = 300.0
@export var max_hp: float = 500.0
@export var attack_damage: float = 6.0
@export var attack_cooldown: float = 1.5
@export var projectile_damage: float = 2.0
@export var ranged_attack_cooldown: float = 3.0
@export var radial_projectile_count: int = 8
@export_range(0.0, 1.0, 0.05) var phase_two_hp_ratio: float = 0.60
@export var phase_two_ranged_attack_cooldown: float = 2.25
@export var phase_transition_invulnerability: float = 0.0
@export var phase_two_radial_projectile_count: int = 12
@export var lightning_damage: float = 8.0
@export var lightning_radius: float = 60.0
@export var lightning_telegraph_duration: float = 0.85
@export var shockwave_damage: float = 6.0
@export var shockwave_radius: float = 150.0
@export var shockwave_telegraph_duration: float = 0.65
@export var shockwave_cooldown: float = 4.0
@export var ascended_cross_damage: float = 8.0
@export var ascended_cross_radius: float = 52.0
@export var ascended_cross_spacing: float = 112.0
@export var ascended_cross_telegraph_duration: float = 1.10
@export var encounter_display_name: String = "Jade Valley Sovereign"
@export_enum("Sovereign", "Mistblade", "Shrine Keeper", "Storm Herald", "Ascended Sovereign") var encounter_style: int = 0

var current_hp: float
var player: Node2D = null
var is_dead: bool = false
var attack_timer: float = 0.0
var ranged_attack_timer: float = 0.0
var shockwave_timer: float = 0.0
var current_phase: int = PHASE_ONE
var last_ranged_pattern: int = -1
var facing_left: bool = true
var visual_action_timer: float = 0.0
var phase_transition_timer: float = 0.0


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

## Called before entering the tree. Encounter data is stored first; bespoke
## presentation for supported styles is applied safely in _ready(), after nodes exist.
func configure_encounter(profile: Dictionary) -> void:
	encounter_display_name = str(profile.get("boss_name", encounter_display_name))
	encounter_style = int(profile.get("boss_style", 0))
	var stats: Dictionary = profile.get("boss_stats", {})
	for key: String in stats:
		if key in ["max_hp", "speed", "melee_distance", "ranged_distance",
			"attack_damage", "attack_cooldown", "projectile_damage",
			"ranged_attack_cooldown", "phase_two_ranged_attack_cooldown",
			"radial_projectile_count", "phase_two_radial_projectile_count",
			"phase_two_hp_ratio", "phase_transition_invulnerability",
			"lightning_damage", "lightning_radius", "lightning_telegraph_duration",
			"shockwave_damage", "shockwave_radius", "shockwave_cooldown",
			"shockwave_telegraph_duration", "ascended_cross_damage",
			"ascended_cross_radius", "ascended_cross_spacing",
			"ascended_cross_telegraph_duration"]:
			set(key, stats[key])

func get_encounter_display_name() -> String:
	return encounter_display_name


## Applies art and collision that are unique to one encounter identity.
## Combat behavior and stage balance remain driven by the existing profile.
func _apply_encounter_presentation() -> void:
	if encounter_style == TRIAL_GUARDIAN_STYLE and encounter_display_name == TRIAL_GUARDIAN_DISPLAY_NAME:
		animated_sprite.sprite_frames = TRIAL_GUARDIAN_SPRITE_FRAMES
		animated_sprite.position = TRIAL_GUARDIAN_VISUAL_POSITION
		animated_sprite.scale = TRIAL_GUARDIAN_VISUAL_SCALE

		# Stage 1-1 is a lesser trial protector, not the Chapter Sovereign. The
		# collider follows the compact lower-body footprint only; the polearm,
		# ribbon cloth, and verdant Qi trails are presentation-only.
		var trial_footprint := CapsuleShape2D.new()
		trial_footprint.radius = TRIAL_GUARDIAN_FOOTPRINT_RADIUS
		trial_footprint.height = TRIAL_GUARDIAN_FOOTPRINT_HEIGHT
		collision_shape.position = TRIAL_GUARDIAN_FOOTPRINT_POSITION
		collision_shape.shape = trial_footprint
		return

	if encounter_style == SOVEREIGN_STYLE and encounter_display_name == SOVEREIGN_DISPLAY_NAME:
		animated_sprite.sprite_frames = SOVEREIGN_SPRITE_FRAMES
		animated_sprite.position = SOVEREIGN_VISUAL_POSITION
		animated_sprite.scale = SOVEREIGN_VISUAL_SCALE

		# The Chapter 1 Sovereign keeps the original jade-gold atlas that the other
		# bosses once borrowed. Now that those encounters own bespoke art, this resource
		# is truly Sovereign-specific. Collision follows the grounded robe/body footprint,
		# never the cape, sword arcs, orbiting seals, or ceremonial phase effects.
		var sovereign_footprint := CapsuleShape2D.new()
		sovereign_footprint.radius = SOVEREIGN_FOOTPRINT_RADIUS
		sovereign_footprint.height = SOVEREIGN_FOOTPRINT_HEIGHT
		collision_shape.position = SOVEREIGN_FOOTPRINT_POSITION
		collision_shape.shape = sovereign_footprint
		return

	if encounter_style == ASCENDED_SOVEREIGN_STYLE and encounter_display_name == ASCENDED_SOVEREIGN_DISPLAY_NAME:
		animated_sprite.sprite_frames = SOVEREIGN_SPRITE_FRAMES
		animated_sprite.position = SOVEREIGN_VISUAL_POSITION
		animated_sprite.scale = Vector2(1.78, 1.78)
		var ascended_footprint := CapsuleShape2D.new()
		ascended_footprint.radius = SOVEREIGN_FOOTPRINT_RADIUS
		ascended_footprint.height = SOVEREIGN_FOOTPRINT_HEIGHT
		collision_shape.position = SOVEREIGN_FOOTPRINT_POSITION
		collision_shape.shape = ascended_footprint
		return

	if encounter_display_name == BLOODWOOD_MOONSTALKER_DISPLAY_NAME:
		animated_sprite.sprite_frames = BLOODWOOD_MOONSTALKER_SPRITE_FRAMES
		animated_sprite.position = BLOODWOOD_MOONSTALKER_VISUAL_POSITION
		animated_sprite.scale = BLOODWOOD_MOONSTALKER_VISUAL_SCALE

		var moonstalker_footprint := CapsuleShape2D.new()
		moonstalker_footprint.radius = BLOODWOOD_MOONSTALKER_FOOTPRINT_RADIUS
		moonstalker_footprint.height = BLOODWOOD_MOONSTALKER_FOOTPRINT_HEIGHT
		collision_shape.position = BLOODWOOD_MOONSTALKER_FOOTPRINT_POSITION
		collision_shape.shape = moonstalker_footprint
		return

	if encounter_display_name == CINNABAR_VEIL_ASSASSIN_DISPLAY_NAME:
		animated_sprite.sprite_frames = CINNABAR_VEIL_ASSASSIN_SPRITE_FRAMES
		animated_sprite.position = CINNABAR_VEIL_ASSASSIN_VISUAL_POSITION
		animated_sprite.scale = CINNABAR_VEIL_ASSASSIN_VISUAL_SCALE

		var veil_assassin_footprint := CapsuleShape2D.new()
		veil_assassin_footprint.radius = CINNABAR_VEIL_ASSASSIN_FOOTPRINT_RADIUS
		veil_assassin_footprint.height = CINNABAR_VEIL_ASSASSIN_FOOTPRINT_HEIGHT
		collision_shape.position = CINNABAR_VEIL_ASSASSIN_FOOTPRINT_POSITION
		collision_shape.shape = veil_assassin_footprint
		return

	if encounter_display_name == SCARLET_RITE_KEEPER_DISPLAY_NAME:
		animated_sprite.sprite_frames = SCARLET_RITE_KEEPER_SPRITE_FRAMES
		animated_sprite.position = SCARLET_RITE_KEEPER_VISUAL_POSITION
		animated_sprite.scale = SCARLET_RITE_KEEPER_VISUAL_SCALE

		var rite_keeper_footprint := CapsuleShape2D.new()
		rite_keeper_footprint.radius = SCARLET_RITE_KEEPER_FOOTPRINT_RADIUS
		rite_keeper_footprint.height = SCARLET_RITE_KEEPER_FOOTPRINT_HEIGHT
		collision_shape.position = SCARLET_RITE_KEEPER_FOOTPRINT_POSITION
		collision_shape.shape = rite_keeper_footprint
		return

	if encounter_display_name == BLOOD_MOON_ASCENDANT_DISPLAY_NAME:
		animated_sprite.sprite_frames = BLOOD_MOON_ASCENDANT_SPRITE_FRAMES
		animated_sprite.position = BLOOD_MOON_ASCENDANT_VISUAL_POSITION
		animated_sprite.scale = BLOOD_MOON_ASCENDANT_VISUAL_SCALE

		var ascendant_footprint := CapsuleShape2D.new()
		ascendant_footprint.radius = BLOOD_MOON_ASCENDANT_FOOTPRINT_RADIUS
		ascendant_footprint.height = BLOOD_MOON_ASCENDANT_FOOTPRINT_HEIGHT
		collision_shape.position = BLOOD_MOON_ASCENDANT_FOOTPRINT_POSITION
		collision_shape.shape = ascendant_footprint
		return

	if encounter_display_name == CRIMSON_MOON_SECT_MASTER_DISPLAY_NAME:
		animated_sprite.sprite_frames = CRIMSON_MOON_SECT_MASTER_SPRITE_FRAMES
		animated_sprite.position = CRIMSON_MOON_SECT_MASTER_VISUAL_POSITION
		animated_sprite.scale = CRIMSON_MOON_SECT_MASTER_VISUAL_SCALE

		var sect_master_footprint := CapsuleShape2D.new()
		sect_master_footprint.radius = CRIMSON_MOON_SECT_MASTER_FOOTPRINT_RADIUS
		sect_master_footprint.height = CRIMSON_MOON_SECT_MASTER_FOOTPRINT_HEIGHT
		collision_shape.position = CRIMSON_MOON_SECT_MASTER_FOOTPRINT_POSITION
		collision_shape.shape = sect_master_footprint
		return

	if encounter_display_name == CLOUDSEA_GATE_WARDEN_DISPLAY_NAME:
		animated_sprite.sprite_frames = CLOUDSEA_GATE_WARDEN_SPRITE_FRAMES
		animated_sprite.position = CLOUDSEA_GATE_WARDEN_VISUAL_POSITION
		animated_sprite.scale = CLOUDSEA_GATE_WARDEN_VISUAL_SCALE
		var gate_warden_footprint := CapsuleShape2D.new()
		gate_warden_footprint.radius = CLOUDSEA_GATE_WARDEN_FOOTPRINT_RADIUS
		gate_warden_footprint.height = CLOUDSEA_GATE_WARDEN_FOOTPRINT_HEIGHT
		collision_shape.position = CLOUDSEA_GATE_WARDEN_FOOTPRINT_POSITION
		collision_shape.shape = gate_warden_footprint
		return

	if encounter_display_name == ASTRAL_MIRROR_DAOIST_DISPLAY_NAME:
		animated_sprite.sprite_frames = ASTRAL_MIRROR_DAOIST_SPRITE_FRAMES
		animated_sprite.position = ASTRAL_MIRROR_DAOIST_VISUAL_POSITION
		animated_sprite.scale = ASTRAL_MIRROR_DAOIST_VISUAL_SCALE
		var mirror_daoist_footprint := CapsuleShape2D.new()
		mirror_daoist_footprint.radius = ASTRAL_MIRROR_DAOIST_FOOTPRINT_RADIUS
		mirror_daoist_footprint.height = ASTRAL_MIRROR_DAOIST_FOOTPRINT_HEIGHT
		collision_shape.position = ASTRAL_MIRROR_DAOIST_FOOTPRINT_POSITION
		collision_shape.shape = mirror_daoist_footprint
		return

	if encounter_display_name == CONSTELLATION_SWORD_SAINT_DISPLAY_NAME:
		animated_sprite.sprite_frames = CONSTELLATION_SWORD_SAINT_SPRITE_FRAMES
		animated_sprite.position = CONSTELLATION_SWORD_SAINT_VISUAL_POSITION
		animated_sprite.scale = CONSTELLATION_SWORD_SAINT_VISUAL_SCALE
		var sword_saint_footprint := CapsuleShape2D.new()
		sword_saint_footprint.radius = CONSTELLATION_SWORD_SAINT_FOOTPRINT_RADIUS
		sword_saint_footprint.height = CONSTELLATION_SWORD_SAINT_FOOTPRINT_HEIGHT
		collision_shape.position = CONSTELLATION_SWORD_SAINT_FOOTPRINT_POSITION
		collision_shape.shape = sword_saint_footprint
		return

	if encounter_display_name == NINEFOLD_HEAVEN_ARBITER_DISPLAY_NAME:
		animated_sprite.sprite_frames = NINEFOLD_HEAVEN_ARBITER_SPRITE_FRAMES
		animated_sprite.position = NINEFOLD_HEAVEN_ARBITER_VISUAL_POSITION
		animated_sprite.scale = NINEFOLD_HEAVEN_ARBITER_VISUAL_SCALE
		var arbiter_footprint := CapsuleShape2D.new()
		arbiter_footprint.radius = NINEFOLD_HEAVEN_ARBITER_FOOTPRINT_RADIUS
		arbiter_footprint.height = NINEFOLD_HEAVEN_ARBITER_FOOTPRINT_HEIGHT
		collision_shape.position = NINEFOLD_HEAVEN_ARBITER_FOOTPRINT_POSITION
		collision_shape.shape = arbiter_footprint
		return

	if encounter_display_name == STAR_PALACE_CELESTIAL_SOVEREIGN_DISPLAY_NAME:
		animated_sprite.sprite_frames = STAR_PALACE_CELESTIAL_SOVEREIGN_SPRITE_FRAMES
		animated_sprite.position = STAR_PALACE_CELESTIAL_SOVEREIGN_VISUAL_POSITION
		animated_sprite.scale = STAR_PALACE_CELESTIAL_SOVEREIGN_VISUAL_SCALE
		var celestial_sovereign_footprint := CapsuleShape2D.new()
		celestial_sovereign_footprint.radius = STAR_PALACE_CELESTIAL_SOVEREIGN_FOOTPRINT_RADIUS
		celestial_sovereign_footprint.height = STAR_PALACE_CELESTIAL_SOVEREIGN_FOOTPRINT_HEIGHT
		collision_shape.position = STAR_PALACE_CELESTIAL_SOVEREIGN_FOOTPRINT_POSITION
		collision_shape.shape = celestial_sovereign_footprint
		return

	if encounter_style == MISTBLADE_STYLE:
		animated_sprite.sprite_frames = MISTBLADE_SPRITE_FRAMES
		animated_sprite.position = MISTBLADE_VISUAL_POSITION
		animated_sprite.scale = MISTBLADE_VISUAL_SCALE

		# The Warden is a narrow, mobile swordsman. Its collider follows the lower-body
		# gameplay footprint, not the straw hat, torn robe, sword, or mist trails.
		var mistblade_footprint := CapsuleShape2D.new()
		mistblade_footprint.radius = MISTBLADE_FOOTPRINT_RADIUS
		mistblade_footprint.height = MISTBLADE_FOOTPRINT_HEIGHT
		collision_shape.position = MISTBLADE_FOOTPRINT_POSITION
		collision_shape.shape = mistblade_footprint
		return

	if encounter_style == SHRINE_KEEPER_STYLE:
		animated_sprite.sprite_frames = SHRINE_KEEPER_SPRITE_FRAMES
		animated_sprite.position = SHRINE_KEEPER_VISUAL_POSITION
		animated_sprite.scale = SHRINE_KEEPER_VISUAL_SCALE

		# The Keeper is deliberately broader and heavier than the Mistblade Warden.
		# Collision still represents the grounded body/feet, never the shoulder stones,
		# shrine seals, ward aura, or other presentation-only extensions.
		var shrine_footprint := CapsuleShape2D.new()
		shrine_footprint.radius = SHRINE_KEEPER_FOOTPRINT_RADIUS
		shrine_footprint.height = SHRINE_KEEPER_FOOTPRINT_HEIGHT
		collision_shape.position = SHRINE_KEEPER_FOOTPRINT_POSITION
		collision_shape.shape = shrine_footprint
		return

	if encounter_style == STORMPEAK_HERALD_STYLE:
		animated_sprite.sprite_frames = STORMPEAK_HERALD_SPRITE_FRAMES
		animated_sprite.position = STORMPEAK_HERALD_VISUAL_POSITION
		animated_sprite.scale = STORMPEAK_HERALD_VISUAL_SCALE

		# The Herald is a tall storm ritualist: slimmer than the stone Keeper, but
		# more planted than the Mistblade. Lightning arcs, staff/robe tails, and
		# storm sigils remain presentation-only and never inflate gameplay contact.
		var stormpeak_footprint := CapsuleShape2D.new()
		stormpeak_footprint.radius = STORMPEAK_HERALD_FOOTPRINT_RADIUS
		stormpeak_footprint.height = STORMPEAK_HERALD_FOOTPRINT_HEIGHT
		collision_shape.position = STORMPEAK_HERALD_FOOTPRINT_POSITION
		collision_shape.shape = stormpeak_footprint

func _is_nine_heavens_boss() -> bool:
	return encounter_display_name in [
		CLOUDSEA_GATE_WARDEN_DISPLAY_NAME,
		ASTRAL_MIRROR_DAOIST_DISPLAY_NAME,
		CONSTELLATION_SWORD_SAINT_DISPLAY_NAME,
		NINEFOLD_HEAVEN_ARBITER_DISPLAY_NAME,
		STAR_PALACE_CELESTIAL_SOVEREIGN_DISPLAY_NAME,
	]

func _get_attack_presentation_theme() -> String:
	return "nine_heavens" if _is_nine_heavens_boss() else ""

func _ready() -> void:
	_apply_encounter_presentation()
	CombatFeedback.register_actor(self)
	current_hp = max_hp
	current_phase = PHASE_ONE

	health_changed.emit(current_hp, max_hp)
	find_player()
	_update_facing_to_player()
	AudioManager.set_context("boss")
	_play_idle_animation()

	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("BOSS MUNCUL!"))
	DebugLogger.system(str("Boss HP: ", current_hp))
	DebugLogger.system(str("Boss Phase: ", current_phase))
	DebugLogger.system(str("=========================================="))

## Memberikan identitas stabil untuk lookup reward Boss tanpa
## mengubah signature signal boss_defeated yang sudah dipakai sistem lain.
func get_reward_source_id() -> String:
	return reward_source_id.strip_edges()

## Mengatur movement, cooldown, dan combat behavior Boss.
func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	if player == null or not is_instance_valid(player):
		find_player()
		velocity = Vector2.ZERO
		return

	update_attack_timer(delta)
	update_ranged_attack_timer(delta)
	update_shockwave_timer(delta)
	update_visual_action_timer(delta)
	update_phase_transition_timer(delta)

	# A phase ward is a short, explicit combat state. The Boss pauses while
	# the transformation animation/ward is visible, so the second phase cannot
	# be erased by burst damage before it becomes playable.
	if phase_transition_timer > 0.0:
		velocity = Vector2.ZERO
		return

	update_behavior()

## Mencari Player dari group player.
func find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		DebugLogger.system(str("WARNING: Boss tidak menemukan Player."))


## Mengurangi visual action lock tanpa mengubah mechanic combat.
func update_visual_action_timer(delta: float) -> void:
	if visual_action_timer <= 0.0:
		return

	visual_action_timer = maxf(
		visual_action_timer - delta,
		0.0
	)


## Mengurangi phase ward timer dan memperbarui visual defensive ward.
func update_phase_transition_timer(delta: float) -> void:
	if phase_transition_timer <= 0.0:
		return

	phase_transition_timer = maxf(
		phase_transition_timer - delta,
		0.0
	)
	queue_redraw()


## Phase ward adalah defensive state nyata, bukan danger telegraph.
## Ia digambar dekat footprint Boss agar tidak menyerupai AoE hostile.
func _draw() -> void:
	if phase_transition_timer <= 0.0:
		return

	var duration: float = maxf(phase_transition_invulnerability, 0.001)
	var progress: float = 1.0 - clampf(phase_transition_timer / duration, 0.0, 1.0)
	var center: Vector2 = Vector2(0.0, -16.0)
	var ward_primary: Color = Color(0.49, 0.96, 0.68, 0.78)
	var ward_secondary: Color = Color(0.92, 0.76, 0.36, 0.58)
	var ward_fill: Color = Color(0.32, 0.86, 0.58, 0.045)

	# The Sovereign's awakened ward is ceremonial jade-gold rather than the
	# Keeper's earthier shrine ward. It remains defensive and body-tight, never a
	# dodge telegraph.
	if encounter_style == SOVEREIGN_STYLE and encounter_display_name == SOVEREIGN_DISPLAY_NAME:
		ward_primary = Color(0.78, 1.0, 0.72, 0.90)
		ward_secondary = Color(1.0, 0.79, 0.30, 0.78)
		ward_fill = Color(0.44, 0.92, 0.55, 0.060)

	if encounter_style == ASCENDED_SOVEREIGN_STYLE:
		ward_primary = Color(0.68, 1.0, 0.78, 0.94)
		ward_secondary = Color(1.0, 0.84, 0.36, 0.82)
		ward_fill = Color(0.42, 0.98, 0.64, 0.072)

	# Stormpeak Herald keeps the same defensive phase-gate mechanic but speaks
	# the hostile storm palette instead of borrowing the Shrine Keeper's jade.
	# The rings stay tight to the body so this never reads as a dodge telegraph.
	if encounter_style == STORMPEAK_HERALD_STYLE:
		ward_primary = Color(0.78, 0.64, 1.0, 0.84)
		ward_secondary = Color(0.91, 0.86, 1.0, 0.68)
		ward_fill = Color(0.42, 0.20, 0.78, 0.055)

	# Crimson Moon Sect bosses share a hostile crimson/cinnabar defensive ward.
	# Exact-name matching intentionally overrides Chapter 1 style colors because
	# Chapter 2 reuses the proven behavior styles without reusing their identity.
	if encounter_display_name in [
		BLOODWOOD_MOONSTALKER_DISPLAY_NAME,
		CINNABAR_VEIL_ASSASSIN_DISPLAY_NAME,
		SCARLET_RITE_KEEPER_DISPLAY_NAME,
		BLOOD_MOON_ASCENDANT_DISPLAY_NAME,
		CRIMSON_MOON_SECT_MASTER_DISPLAY_NAME,
	]:
		ward_primary = Color(1.0, 0.30, 0.38, 0.88)
		ward_secondary = Color(1.0, 0.66, 0.38, 0.70)
		ward_fill = Color(0.68, 0.06, 0.13, 0.060)

	# Nine Heavens bosses use an amethyst / star-gold defensive ward.
	# It remains body-tight so it cannot be mistaken for a dodge telegraph.
	if _is_nine_heavens_boss():
		ward_primary = Color(0.72, 0.48, 1.0, 0.88)
		ward_secondary = Color(1.0, 0.82, 0.42, 0.74)
		ward_fill = Color(0.33, 0.16, 0.62, 0.055)

	draw_circle(center, 50.0, ward_fill)
	draw_arc(
		center,
		53.0,
		progress * 1.8,
		progress * 1.8 + TAU * 0.76,
		36,
		ward_primary,
		3.0,
		true
	)
	draw_arc(
		center,
		60.0,
		-progress * 1.4 + PI,
		-progress * 1.4 + PI + TAU * 0.58,
		36,
		ward_secondary,
		2.0,
		true
	)

## Memperbarui facing dari arah gerak horizontal.
func _update_facing_from_motion(
	motion_direction: Vector2
) -> void:
	if (
		motion_direction.x
		<= -FACING_HORIZONTAL_THRESHOLD
	):
		facing_left = true
	elif (
		motion_direction.x
		>= FACING_HORIZONTAL_THRESHOLD
	):
		facing_left = false

## Menghadap posisi target tertentu.
func _update_facing_to_position(
	target_position: Vector2
) -> void:
	var horizontal_offset: float = (
		target_position.x - global_position.x
	)

	if horizontal_offset < 0.0:
		facing_left = true
	elif horizontal_offset > 0.0:
		facing_left = false

## Menghadap Player jika tersedia.
func _update_facing_to_player() -> void:
	if player == null or not is_instance_valid(player):
		return

	_update_facing_to_position(
		player.global_position
	)

## Mengembalikan nama animation berdasarkan facing.
func _directional_animation(
	prefix: String
) -> StringName:
	var suffix: String = "right"

	if facing_left:
		suffix = "left"

	return StringName(
		"%s_%s" % [prefix, suffix]
	)

## Memainkan idle hanya ketika Boss tidak sedang melakukan visual attack.
func _play_idle_animation() -> void:
	if visual_action_timer > 0.0:
		return

	_play_loop_animation(
		_directional_animation("idle")
	)

## Memainkan walk hanya ketika Boss tidak sedang melakukan visual attack.
func _play_walk_animation() -> void:
	if visual_action_timer > 0.0:
		return

	_play_loop_animation(
		_directional_animation("walk")
	)

## Memainkan animation non-loop sesuai mechanic actual.
func _play_action_animation(
	prefix: String,
	target_duration: float
) -> void:
	if animated_sprite == null:
		return

	var sprite_frames: SpriteFrames = (
		animated_sprite.sprite_frames
	)

	if sprite_frames == null:
		return

	var animation_name: StringName = (
		_directional_animation(prefix)
	)

	if not sprite_frames.has_animation(
		animation_name
	):
		return

	var frame_count: int = (
		sprite_frames.get_frame_count(
			animation_name
		)
	)

	var animation_fps: float = (
		sprite_frames.get_animation_speed(
			animation_name
		)
	)

	var base_duration: float = (
		float(frame_count)
		/ maxf(animation_fps, 0.001)
	)

	var safe_duration: float = maxf(
		target_duration,
		0.01
	)

	var custom_speed: float = (
		base_duration
		/ safe_duration
	)

	animated_sprite.play(
		animation_name,
		custom_speed
	)

	visual_action_timer = safe_duration

## Helper loop animation agar tidak restart setiap physics frame.
func _play_loop_animation(
	animation_name: StringName
) -> void:
	if animated_sprite == null:
		return

	if animated_sprite.sprite_frames == null:
		return

	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		return

	if (
		animated_sprite.animation != animation_name
		or not animated_sprite.is_playing()
	):
		animated_sprite.play(
			animation_name
		)

## Menentukan perilaku Boss berdasarkan jarak terhadap Player.
func update_behavior() -> void:
	var distance_to_player: float = global_position.distance_to(player.global_position)

	if distance_to_player <= melee_distance:
		velocity = Vector2.ZERO
		_update_facing_to_player()
		try_attack()

		if visual_action_timer <= 0.0:
			_play_idle_animation()

		return

	if distance_to_player <= ranged_distance:
		if encounter_style == 1:
			# The Mistblade Warden circles while casting, instead of anchoring
			# in one position like the shrine and gate guardians.
			var direction: Vector2 = global_position.direction_to(player.global_position)
			var strafe_sign: float = -1.0 if last_ranged_pattern == 1 else 1.0
			velocity = (direction * 0.3 + direction.orthogonal() * strafe_sign).normalized() * speed
			move_and_slide()
			_update_facing_to_player()
			try_ranged_attack()
			_play_walk_animation()
			return
		if encounter_style == ASCENDED_SOVEREIGN_STYLE and current_phase == PHASE_TWO:
			var ascend_direction: Vector2 = global_position.direction_to(player.global_position)
			var ascend_sign: float = -1.0 if last_ranged_pattern % 2 == 0 else 1.0
			velocity = (ascend_direction * 0.12 + ascend_direction.orthogonal() * ascend_sign).normalized() * speed * 0.72
			move_and_slide()
			_update_facing_to_player()
			try_ranged_attack()
			_play_walk_animation()
			return
		velocity = Vector2.ZERO
		_update_facing_to_player()
		try_ranged_attack()

		if visual_action_timer <= 0.0:
			_play_idle_animation()

		return

	move_toward_player()

## Menggerakkan Boss menuju Player.
func move_toward_player() -> void:
	var direction: Vector2 = global_position.direction_to(
		player.global_position
	)

	_update_facing_from_motion(direction)

	velocity = direction * speed
	move_and_slide()

	_play_walk_animation()

## Mengurangi melee attack cooldown setiap frame.
func update_attack_timer(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta

## Mengurangi ranged attack cooldown setiap frame.
func update_ranged_attack_timer(delta: float) -> void:
	if ranged_attack_timer > 0.0:
		ranged_attack_timer -= delta

## Mengurangi Qi Shockwave cooldown setiap frame.
func update_shockwave_timer(delta: float) -> void:
	if shockwave_timer > 0.0:
		shockwave_timer -= delta

## Menjalankan close-range behavior berdasarkan phase Boss.
func try_attack() -> void:
	if attack_timer > 0.0:
		return

	if (current_phase == PHASE_TWO or encounter_style == 2) and shockwave_timer <= 0.0:
		cast_qi_shockwave()
		shockwave_timer = shockwave_cooldown
	else:
		attack_player()

	attack_timer = attack_cooldown

## Memberikan melee damage kepada Player.
func attack_player() -> void:
	if player == null or not is_instance_valid(player):
		return

	var player_health: PlayerHealth = player.get_node_or_null("PlayerHealth") as PlayerHealth

	if player_health == null:
		DebugLogger.system(str("WARNING: Boss tidak menemukan PlayerHealth."))
		return

	_update_facing_to_player()

	_play_action_animation(
		"melee",
		MELEE_VISUAL_DURATION
	)

	DebugLogger.system(str("BOSS ATTACK!"))
	DebugLogger.system(str("Boss Damage: ", attack_damage))

	player_health.take_damage(attack_damage)

## Memilih ranged attack tanpa mengulang pattern sebelumnya.
func try_ranged_attack() -> void:
	if ranged_attack_timer > 0.0:
		return

	var attack_pattern: int = choose_ranged_pattern()

	match attack_pattern:
		RANGED_SINGLE_PROJECTILE:
			shoot_projectile()
		RANGED_RADIAL_BURST:
			shoot_radial_projectiles()
		RANGED_HEAVENLY_LIGHTNING:
			cast_heavenly_lightning()
		RANGED_ASCENDED_CROSS:
			cast_ascended_cross()

	last_ranged_pattern = attack_pattern
	ranged_attack_timer = get_current_ranged_attack_cooldown()

## Mengembalikan ranged cooldown berdasarkan phase Boss saat ini.
func get_current_ranged_attack_cooldown() -> float:
	if current_phase == PHASE_TWO:
		return phase_two_ranged_attack_cooldown

	return ranged_attack_cooldown

## Mengembalikan jumlah radial projectile berdasarkan phase Boss saat ini.
func get_current_radial_projectile_count() -> int:
	if current_phase == PHASE_TWO:
		return phase_two_radial_projectile_count

	return radial_projectile_count

## Memilih ranged pattern secara acak dengan anti-repeat.
func choose_ranged_pattern() -> int:
	var available_patterns: Array[int] = [
		RANGED_SINGLE_PROJECTILE,
		RANGED_RADIAL_BURST,
		RANGED_HEAVENLY_LIGHTNING
	]
	if encounter_style == 1 or encounter_style == 2:
		available_patterns = [RANGED_SINGLE_PROJECTILE, RANGED_RADIAL_BURST]
	elif encounter_style == 3:
		available_patterns = [RANGED_HEAVENLY_LIGHTNING, RANGED_SINGLE_PROJECTILE]
		if current_phase == PHASE_TWO:
			available_patterns = [RANGED_HEAVENLY_LIGHTNING, RANGED_RADIAL_BURST]
	elif encounter_style == ASCENDED_SOVEREIGN_STYLE:
		if current_phase == PHASE_TWO:
			available_patterns = [RANGED_RADIAL_BURST, RANGED_HEAVENLY_LIGHTNING, RANGED_ASCENDED_CROSS]

	if last_ranged_pattern in available_patterns:
		available_patterns.erase(last_ranged_pattern)

	return available_patterns.pick_random()

## Pattern #1: menembakkan satu projectile menuju posisi Player.
func shoot_projectile() -> void:
	if player == null or not is_instance_valid(player):
		return

	_update_facing_to_player()

	_play_action_animation(
		"projectile",
		PROJECTILE_CAST_VISUAL_DURATION
	)

	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.set("damage", projectile_damage)
	projectile.set("presentation_theme", _get_attack_presentation_theme())

	get_parent().add_child(projectile)

	projectile.global_position = global_position
	projectile.setup(player.global_position)

	DebugLogger.system(str("BOSS PROJECTILE FIRED!"))

## Pattern #2: menembakkan projectile secara melingkar dari posisi Boss.
func shoot_radial_projectiles() -> void:
	_update_facing_to_player()

	_play_action_animation(
		"radial",
		RADIAL_CAST_VISUAL_DURATION
	)

	var projectile_count: int = get_current_radial_projectile_count()

	if projectile_count <= 0:
		return

	var angle_step: float = TAU / projectile_count

	for i in range(projectile_count):
		var projectile = PROJECTILE_SCENE.instantiate()
		projectile.set("damage", projectile_damage)
		projectile.set("presentation_theme", _get_attack_presentation_theme())
		var angle: float = angle_step * i
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)

		get_parent().add_child(projectile)

		projectile.global_position = global_position
		projectile.setup_direction(direction)

	DebugLogger.system(str("BOSS RADIAL BURST!"))
	DebugLogger.combat(
		"Boss Radial Burst | Phase: %d | Projectiles: %d"
		% [current_phase, projectile_count]
	)

## Pattern #3: membuat Heavenly Lightning pada snapshot posisi Player.
func cast_heavenly_lightning() -> void:
	if player == null or not is_instance_valid(player):
		return

	var target_position: Vector2 = player.global_position

	_update_facing_to_position(
		target_position
	)

	_play_action_animation(
		"lightning",
		lightning_telegraph_duration
	)
	var lightning_strike = LIGHTNING_STRIKE_SCENE.instantiate()

	lightning_strike.base_damage = lightning_damage
	lightning_strike.strike_radius = lightning_radius
	lightning_strike.telegraph_duration = lightning_telegraph_duration
	lightning_strike.set("presentation_theme", _get_attack_presentation_theme())

	get_tree().current_scene.add_child(lightning_strike)
	lightning_strike.global_position = target_position

	DebugLogger.combat(
		"Boss Heavenly Lightning Cast | Target: %s"
		% target_position
	)


func cast_ascended_cross() -> void:
	if player == null or not is_instance_valid(player):
		return
	var target: Vector2 = player.global_position
	var axis: Vector2 = global_position.direction_to(target).orthogonal().normalized()
	if axis.length_squared() < 0.001:
		axis = Vector2.RIGHT
	_update_facing_to_position(target)
	_play_action_animation("lightning", ascended_cross_telegraph_duration)
	for offset_index: int in [-1, 0, 1]:
		var strike = LIGHTNING_STRIKE_SCENE.instantiate()
		strike.base_damage = ascended_cross_damage
		strike.strike_radius = ascended_cross_radius
		strike.telegraph_duration = ascended_cross_telegraph_duration
		strike.set("presentation_theme", _get_attack_presentation_theme())
		get_tree().current_scene.add_child(strike)
		strike.global_position = target + axis * ascended_cross_spacing * float(offset_index)
	DebugLogger.combat("Boss Ascended Cross Cast | Target: %s" % target)

## Membuat Qi Shockwave pada snapshot posisi Boss.
func cast_qi_shockwave() -> void:
	_update_facing_to_player()

	_play_action_animation(
		"shockwave",
		shockwave_telegraph_duration
	)

	var shockwave = QI_SHOCKWAVE_SCENE.instantiate()

	shockwave.base_damage = shockwave_damage
	shockwave.shockwave_radius = shockwave_radius
	shockwave.telegraph_duration = shockwave_telegraph_duration
	shockwave.set("presentation_theme", _get_attack_presentation_theme())

	get_tree().current_scene.add_child(shockwave)
	shockwave.global_position = global_position

	DebugLogger.combat(
		"Boss Qi Shockwave Cast | Position: %s"
		% global_position
	)

## Mengurangi HP Boss dan mengirim perubahan HP ke UI.
func take_damage(amount: float) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	# Damage during a visible phase ward is intentionally rejected. This is
	# enabled only by encounter profiles that explicitly opt into the mechanic.
	if phase_transition_timer > 0.0:
		return

	var next_hp: float = maxf(current_hp - amount, 0.0)

	# Opt-in two-phase damage gate: the hit that crosses the phase threshold
	# stops at the threshold instead of deleting the second phase. The damage
	# number reports only damage that was actually applied.
	if current_phase == PHASE_ONE and phase_transition_invulnerability > 0.0:
		var phase_threshold_hp: float = max_hp * phase_two_hp_ratio
		if next_hp <= phase_threshold_hp:
			next_hp = phase_threshold_hp

	var applied_damage: float = current_hp - next_hp
	if applied_damage <= 0.0:
		return

	current_hp = next_hp
	CombatFeedback.hit(self, applied_damage)

	health_changed.emit(current_hp, max_hp)

	DebugLogger.system(str("BOSS HP: ", current_hp, "/", max_hp))

	update_phase()

	if current_hp <= 0.0:
		die()

## Mengevaluasi transisi phase berdasarkan persentase HP Boss.
func update_phase() -> void:
	if current_phase != PHASE_ONE:
		return

	if max_hp <= 0.0:
		return

	var hp_ratio: float = current_hp / max_hp

	if hp_ratio > phase_two_hp_ratio:
		return

	enter_phase_two()

## Memindahkan Boss ke Phase 2 satu kali ketika threshold HP tercapai.
func enter_phase_two() -> void:
	if current_phase == PHASE_TWO:
		return

	current_phase = PHASE_TWO
	phase_transition_timer = maxf(phase_transition_invulnerability, 0.0)
	queue_redraw()
	CombatFeedback.pulse(global_position, "level")
	CombatFeedback.actor_action(self, PHASE_TWO_VISUAL_DURATION)
	AudioManager.play_sfx("level")
	phase_changed.emit(current_phase)

	_update_facing_to_player()

	_play_action_animation(
		"phase2",
		PHASE_TWO_VISUAL_DURATION
	)

	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("BOSS PHASE 2 DIMULAI!"))
	DebugLogger.system(str("Boss HP: ", current_hp, "/", max_hp))
	DebugLogger.system(str("Ranged Cooldown: ", get_current_ranged_attack_cooldown()))
	DebugLogger.system(str("Radial Projectiles: ", get_current_radial_projectile_count()))
	DebugLogger.system(str("=========================================="))

## Menyelesaikan Boss fight dan mengirim signal kemenangan.
func die() -> void:
	if is_dead:
		return

	is_dead = true
	CombatFeedback.death(self, true)
	remove_from_group("enemy")
	velocity = Vector2.ZERO

	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("BOSS DIKALAHKAN!"))
	DebugLogger.system(str("=========================================="))

	boss_defeated.emit()
	queue_free()
