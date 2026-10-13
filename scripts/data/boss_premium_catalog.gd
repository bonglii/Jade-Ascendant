extends RefCounted
const Chapters: Array = [preload("res://scripts/data/chapter_one_catalog.gd"),preload("res://scripts/data/chapter_two_catalog.gd"),preload("res://scripts/data/chapter_three_catalog.gd")]
const REALM_NAMES: Array[String] = ["VERDANT QI VALLEY","CRIMSON MOON SECT","NINE HEAVENS"]
static func get_profile(display_name: String) -> Dictionary:
	for chapter: int in range(Chapters.size()):
		var stages: Dictionary = Chapters[chapter].STAGES
		for stage: int in stages:
			if str(stages[stage].get("boss_name","")) != display_name: continue
			var accent: Color = stages[stage].get("accent",Color(0.42,0.92,0.76))
			return {"chapter":chapter+1,"stage":stage,"realm":REALM_NAMES[chapter],"accent":accent,"theme":["jade_valley","crimson_moon","nine_heavens"][chapter]}
	return {}
static func theme_color(theme: String) -> Color:
	match theme:
		"storm": return Color(0.72,0.52,1.0)
		"frostveil": return Color(0.48,0.89,1.0)
		"solar_nirvana": return Color(1.0,0.64,0.25)
		"crimson_moon": return Color(1.0,0.78,0.43)
		"nine_heavens": return Color(0.68,0.75,1.0)
	return Color(0.38,0.95,0.77)
