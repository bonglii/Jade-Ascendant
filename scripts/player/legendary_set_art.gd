extends RefCounted

## Legendary is the 5-star rarity; duplicate ascension is a separate progression.
## Four armor/accessory pieces activate these visuals, never the armament.
const ROOT: String = "res://assets/effects/legendary_sets/"
const SETS: Dictionary = {
	"nine_heavens": {"kind":"poison", "color":Color(0.24,0.96,0.51), "orbit":5},
	"solar_meridian": {"kind":"burn", "color":Color(1.0,0.62,0.16), "orbit":6},
	"vermilion_verdict": {"kind":"verdict", "color":Color(1.0,0.25,0.18), "orbit":4},
	"celestial_aegis": {"kind":"aegis", "color":Color(0.48,0.73,1.0), "orbit":6}
}
const CELL: int = 256
const GUTTER: int = 16
static var cache: Dictionary = {}

static func qualifies(set_id: String, pieces: int) -> bool:
	return pieces == 4 and SETS.has(set_id)

static func textures(set_id: String) -> Array[Texture2D]:
	if cache.has(set_id): return cache[set_id]
	var frames: Array[Texture2D] = []
	if not SETS.has(set_id): return frames
	var image: Texture2D = load(ROOT + set_id + ".png")
	for index: int in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = image
		frame.region = Rect2((index % 2) * CELL, (index >> 1) * CELL, CELL, CELL)
		frame.filter_clip = true
		frames.append(frame)
	cache[set_id] = frames
	return frames
