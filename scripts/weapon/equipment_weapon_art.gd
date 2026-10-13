extends RefCounted

## Presentation-only crops of original generated art. All collision/damage stays
## in the original Spirit Sword projectile. No PNG pixels are edited here.
const ENTRIES: Dictionary = {
	"cinnabar_moon_saber": {"path":"res://assets/ui/equipment/imperial_v3/cinnabar_moon_saber.png", "bounds":Rect2(0.01594896,0.34051037,0.96730463,0.39792663)},
	"mistveil_jian": {"path":"res://assets/ui/equipment/imperial_v3/mistveil_jian.png", "bounds":Rect2(0.02216216,0.19647059,0.95621622,0.72117647)},
	"mountain_ward_jian": {"path":"res://assets/ui/equipment/imperial_v3/mountain_ward_jian.png", "bounds":Rect2(0.02311161,0.27733935,0.95321308,0.63021421)},
	"nine_heavens_star_sword": {"path":"res://assets/ui/equipment/imperial_v3/nine_heavens_star_sword.png", "bounds":Rect2(0.01563288,0.21815889,0.96722138,0.66834805)},
	"spirit_seal_fan": {"path":"res://assets/ui/equipment/imperial_v3/spirit_seal_fan.png", "bounds":Rect2(0.13556619,0.03588517,0.82137161,0.94816587)},
	"stillwater_mirror_blade": {"path":"res://assets/ui/equipment/imperial_v3/stillwater_mirror_blade.png", "bounds":Rect2(0.01933702,0.16436464,0.96132597,0.77624309)},
	"sunfire_dragon_jian": {"path":"res://assets/ui/equipment/imperial_v3/sunfire_dragon_jian.png", "bounds":Rect2(0.01058932,0.16988950,0.97882136,0.60359116)},
	"wanderer_jade_jian": {"path":"res://assets/ui/equipment/imperial_v3/wanderer_jade_jian.png", "bounds":Rect2(0.02854512,0.05662983,0.95349908,0.90745856)},
}

static func apply(projectile: Area2D, armament_id: String) -> bool:
	var art: Sprite2D = projectile.get_node_or_null("EquipmentArt") as Sprite2D
	if not ENTRIES.has(armament_id):
		if art != null: art.visible = false
		return false
	var entry: Dictionary = ENTRIES[armament_id]
	var texture: Texture2D = load(entry.path) as Texture2D
	if texture == null: return false
	if art == null:
		art = Sprite2D.new()
		art.name = "EquipmentArt"
		projectile.add_child(art)
	art.texture = texture
	art.visible = true
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.region_enabled = true
	var normalized: Rect2 = entry.bounds
	art.region_rect = Rect2(normalized.position * texture.get_size(), normalized.size * texture.get_size())
	var factor: float = minf(64.0 / art.region_rect.size.x, 28.0 / art.region_rect.size.y)
	art.scale = Vector2.ONE * factor
	art.position = Vector2(8, 1)
	var legacy: CanvasItem = projectile.get_node_or_null("AnimatedSprite2D")
	if legacy != null: legacy.visible = false
	return true
