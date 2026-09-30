extends RefCounted

## Stage-keyed boss visuals. All boss art is new; no Chapter 1 sprite fallback.
const FRAME_PATHS: Dictionary = {
	"4-1": "res://assets/enemy/chapter4/boss_1_frostveil_pathkeeper_spriteframes.tres",
	"4-2": "res://assets/enemy/chapter4/boss_2_shattered_mirror_abbot_spriteframes.tres",
	"4-3": "res://assets/enemy/chapter4/boss_3_lotus_of_still_waters_spriteframes.tres",
	"4-4": "res://assets/enemy/chapter4/boss_4_tollkeeper_of_the_deep_spriteframes.tres",
	"4-5": "res://assets/enemy/chapter4/boss_5_frostbound_sovereign_spriteframes.tres",
	"5-1": "res://assets/enemy/chapter5/boss_1_ember_stair_sentinel_spriteframes.tres",
	"5-2": "res://assets/enemy/chapter5/boss_2_crucible_forge_king_spriteframes.tres",
	"5-3": "res://assets/enemy/chapter5/boss_3_ashwing_matriarch_spriteframes.tres",
	"5-4": "res://assets/enemy/chapter5/boss_4_eclipse_ritual_hierophant_spriteframes.tres",
	"5-5": "res://assets/enemy/chapter5/boss_5_primordial_sun_sovereign_spriteframes.tres",
}

static func get_frames(realm_id: int, stage_id: int) -> SpriteFrames:
	# Load only the boss for the active trial; never preload 10 boss atlases.
	var art_path: String = str(FRAME_PATHS.get("%d-%d" % [realm_id, stage_id], ""))
	if art_path.is_empty() or not ResourceLoader.exists(art_path):
		return null
	return ResourceLoader.load(art_path, "SpriteFrames") as SpriteFrames
