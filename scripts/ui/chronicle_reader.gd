extends RefCounted
const Catalog = preload("res://scripts/data/chronicle_catalog.gd")
static func open(host: Node, entry_id: String) -> Control:
	var entry: Dictionary = Catalog.get_entry(entry_id)
	if entry.is_empty() or not Catalog.unlocked(entry,JourneyManager.cleared_stage_keys,JourneyManager.cosmetic_badges):
		return null
	var sheet: Control = preload("res://scripts/ui/player_sheet.gd").create(host,Catalog.copy(entry,"title",SettingsManager.language),"ChronicleReader")
	sheet.content.add_child(sheet.label(str(entry.realm).to_upper(),13,Color("80c3a7")))
	var art := TextureRect.new()
	art.texture = load(preload("res://scripts/ui/journey_art_catalog.gd").get_realm_vista_path(int(entry.chapter)))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(0,180)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.content.add_child(art)
	sheet.content.add_child(sheet.label(Catalog.copy(entry,"body",SettingsManager.language),18))
	sheet.content.add_child(sheet.label("“"+Catalog.copy(entry,"line",SettingsManager.language)+"”",18,Color("ead19a")))
	sheet.content.add_child(sheet.label("Bisa dibaca kembali di Library › Chronicles." if SettingsManager.language == "id" else "Read again in Library › Chronicles.",13))
	preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(sheet)
	return sheet
