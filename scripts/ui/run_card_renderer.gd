extends RefCounted
## CPU image compositing keeps PNG export independent of a GPU/readback viewport.
const Snapshot = preload("res://scripts/data/run_share_snapshot.gd")
const GOLD := Color("ead19a")
const JADE := Color("88dcb7")
const WHITE := Color("ecf0df")
var _font: FontFile = preload("res://assets/ui/library/fonts/archive_serif.ttf")
var _glyphs: Dictionary = {}
var _image: Image

func render(snapshot: Dictionary, story: bool, alias: String = "", language: String = "en") -> Image:
	if snapshot.is_empty():
		return null
	var height: int = 1920 if story else 1350
	_image = Image.create(1080,height,false,Image.FORMAT_RGBA8)
	_image.fill(Color("061c22"))
	_image.fill_rect(Rect2i(24,24,1032,height-48),Color("91ad8b"))
	_image.fill_rect(Rect2i(26,26,1028,height-52),Color("061c22"))
	_text("JADE ASCENDANT",Vector2i(64,92),48,GOLD)
	_text("CHRONICLES OF LIN YUE",Vector2i(66,120),18,JADE)
	var hero_height: int = 700 if story else 260
	var art: Texture2D = load(preload("res://scripts/ui/journey_art_catalog.gd").get_realm_vista_path(int(snapshot.chapter)))
	if art != null:
		var landscape: Image = art.get_image()
		if landscape.is_compressed(): landscape.decompress()
		landscape.convert(Image.FORMAT_RGBA8)
		var scale: float = maxf(952.0/landscape.get_width(),float(hero_height)/landscape.get_height())
		landscape.resize(ceili(landscape.get_width()*scale),ceili(landscape.get_height()*scale),Image.INTERPOLATE_LANCZOS)
		_image.blit_rect(landscape,Rect2i((landscape.get_width()-952)/2,(landscape.get_height()-hero_height)/2,952,hero_height),Vector2i(64,150))
	var base: int = 150 + hero_height
	_text(("HEAVENLY TRIALS  /  TIER %d  /  CLEAR"%int(snapshot.get("tier",1))) if snapshot.get("mode")=="trials" else ("JOURNEY  /  %d-%d  /  VICTORY"%[snapshot.chapter,snapshot.stage]),Vector2i(64,base+42),24,JADE)
	_fitted(str(snapshot.title),Vector2i(64,base+100),46,952,WHITE)
	_text(preload("res://scripts/data/stage_record_book.gd").clock(int(snapshot.time_ms)),Vector2i(64,base+173),62,GOLD)
	var id: bool = language == "id"
	var metrics: String = ("%d hit HP  /  %d kematian" if id else "%d HP hits  /  %d deaths")%[snapshot.hits,snapshot.deaths] if snapshot.complete else ("Catatan HP belum lengkap" if id else "HP record incomplete")
	_text(metrics,Vector2i(64,base+213),25,WHITE)
	var medals := "CLEAR"
	if snapshot.complete:
		if snapshot.deaths == 0: medals += "  /  SURVIVOR"
		if snapshot.hits == 0 and snapshot.deaths == 0: medals += "  /  UNTOUCHED"
	if bool(snapshot.get("oath_completed",false)):medals += "  /  OATH KEEPER"
	_fitted(medals,Vector2i(64,base+252),23,952,JADE)
	_image.fill_rect(Rect2i(64,base+273,952,1),Color("46786c"))
	var damage: Dictionary = snapshot.damage
	var sources: Array = damage.keys()
	sources.sort_custom(func(a: String,b: String):return int(damage[a])>int(damage[b]))
	var total: int = 0
	for value: Variant in damage.values(): total += int(value)
	_text(("DAMAGE TERCATAT  " if id else "RECORDED DAMAGE  ")+str(total) if snapshot.damage_complete else ("DAMAGE PARSIAL  /  tanpa total atau persentase" if id else "PARTIAL DAMAGE  /  no total or percentages"),Vector2i(64,base+312),23,GOLD)
	if sources.is_empty():
		_text("Belum ada data damage" if id else "No damage data available",Vector2i(64,base+354),21,WHITE)
	for index: int in range(mini(3,sources.size())):
		var key: String = str(sources[index])
		var name: String = Snapshot.skill_name({"id":key}) if key in preload("res://scripts/data/skill_catalog.gd").UPGRADE_IDS else key.trim_prefix("set_").capitalize()
		for skill: Dictionary in snapshot.skills:
			if skill.id == key: name = Snapshot.skill_name(skill)
		_fitted(name,Vector2i(64,base+350+index*30),22,620,WHITE)
		_text(str(damage[key]),Vector2i(800,base+350+index*30),22,JADE)
	_text("BUILD RUN INI" if id else "THIS RUN’S BUILD",Vector2i(64,base+455),25,GOLD)
	for index: int in range(snapshot.skills.size()):
		var skill: Dictionary = snapshot.skills[index]
		var x: int = 64 + (index%2)*480
		var row_height: int = 34 if snapshot.skills.size()<=20 else (25 if story else 21)
		var y: int = base + 492 + (index/2)*row_height
		_fitted(Snapshot.skill_name(skill)+"  Lv.%d"%int(skill.level),Vector2i(x,y),26 if snapshot.skills.size()<=12 else (21 if story else 18),454,WHITE)
	if snapshot.skills.is_empty():
		_text("Build tidak tersedia" if id else "Build unavailable",Vector2i(64,base+492),21,WHITE)
	var chosen: String = Snapshot.alias_text(alias)
	if not chosen.is_empty(): _text(chosen,Vector2i(64,height-86),26,JADE)
	_text("ASCEND. REMEMBER. RETURN.",Vector2i(64,height-52),21,GOLD)
	return _image

func _fitted(value: String, point: Vector2i, pixels: int, width: int, ink: Color) -> void:
	while pixels > 14 and _font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x > width:
		pixels -= 1
	_text(value,point,pixels,ink)
func _text(value: String, point: Vector2i, pixels: int, ink: Color) -> void:
	var cursor: float = float(point.x)
	for index: int in range(value.length()):
		var glyph: int = _font.get_glyph_index(pixels,value.unicode_at(index),0)
		var cache_key: String = "%d:%d:%s"%[pixels,glyph,ink.to_html()]
		if not _glyphs.has(cache_key):
			_font.render_glyph(0,Vector2i(pixels,0),glyph)
			var texture_index: int = _font.get_glyph_texture_idx(0,Vector2i(pixels,0),glyph)
			var rectangle: Rect2i = Rect2i(_font.get_glyph_uv_rect(0,Vector2i(pixels,0),glyph))
			if texture_index >= 0 and rectangle.has_area():
				var atlas: Image = _font.get_texture_image(0,Vector2i(pixels,0),texture_index)
				var stamp: Image = atlas.get_region(rectangle)
				stamp.convert(Image.FORMAT_RGBA8)
				for y: int in range(stamp.get_height()):
					for x: int in range(stamp.get_width()):
						var alpha: float = stamp.get_pixel(x,y).a
						stamp.set_pixel(x,y,Color(ink,alpha))
				_glyphs[cache_key] = stamp
			else:
				_glyphs[cache_key] = null
		# Rasterize before reading metrics, then use shaped prefix widths.
		cursor = float(point.x) + _font.get_string_size(value.left(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x - _font.get_glyph_advance(0,pixels,glyph).x
		var bitmap: Image = _glyphs[cache_key]
		if bitmap != null:
			var offset: Vector2i = Vector2i(_font.get_glyph_offset(0,Vector2i(pixels,0),glyph))
			_image.blend_rect(bitmap,Rect2i(Vector2i.ZERO,bitmap.get_size()),Vector2i(roundi(cursor),point.y)+offset)
		cursor += _font.get_glyph_advance(0,pixels,glyph).x
