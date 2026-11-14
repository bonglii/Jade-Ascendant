extends SceneTree
## Production Library, isolated local saves, real native input; no live claims.
var checks: int=0
var failures: int=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("LIBRARY_READABILITY_FAIL "+label)

func frames(count: int=8) -> void:
	for index: int in range(count):await process_frame

func touch(at: Vector2, pressed: bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=0;event.position=at;event.pressed=pressed
	Input.parse_input_event(event)
	await frames(2)

func swipe(at: Vector2) -> void:
	await touch(at,true)
	for index: int in range(1,9):
		var event:=InputEventScreenDrag.new()
		event.index=0;event.position=at+Vector2(0,-8*index);event.relative=Vector2(0,-8)
		Input.parse_input_event(event)
		await frames(1)
	await touch(at+Vector2(0,-64),false)
	await frames()

func open_book() -> Control:
	check(change_scene_to_file("res://scenes/ui/skill_book_screen.tscn")==OK,"production Library loads")
	await scene_changed
	await frames(12)
	return current_scene

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_archive_polish_qa"):
		quit(2);return
	await frames()
	Input.set_emulate_touch_from_mouse(true)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	var settings: Node=root.get_node("SettingsManager")
	var equipment: Node=root.get_node("EquipmentManager")
	var inventory: Node=root.get_node("InventoryManager")
	inventory.item_counts["jade_binding_chain"]=1
	equipment.equipped_item_ids.armament="jade_binding_chain"
	var inventory_before: Dictionary=inventory.item_counts.duplicate(true)
	var slots_before: Dictionary=equipment.equipped_item_ids.duplicate(true)
	for language: String in ["en","id"]:
		settings.set_presentation("language",language)
		root.size=Vector2i(320,568)
		var book: Control=await open_book()
		for dimensions: Vector2i in [Vector2i(320,568),Vector2i(405,860),Vector2i(648,1152),Vector2i(860,405)]:
			root.size=dimensions
			await frames(12)
			var safe: Control=book.get_node("DeviceSafeArea")
			for mode: String in book.ARCHIVE_MODES:
				book._set_mode(mode)
				await frames()
				var label: String=language+" "+str(dimensions)+" "+mode
				var scroll: ScrollContainer=book.find_child("SkillBookScroll",true,false)
				check(scroll.size.y>=140,"reader has usable height "+label)
				check(safe.get_global_rect().grow(1).encloses(scroll.get_global_rect()),"reader stays inside safe area "+label)
				check(book._section_picker.selected==book.ARCHIVE_MODES.find(mode),"section picker follows mode "+label)
				check(book._category_picker.visible==(mode!="CHRONICLES" and book._use_category_picker()),"category controls match section "+label)
				for action: Control in [book._archive_back,book.find_child("LibraryJournal",true,false),book.find_child("LibraryTraining",true,false)]:
					check(safe.get_global_rect().grow(1).encloses(action.get_global_rect()),"navigation fits "+str(action.name)+" "+label)
				if mode=="EQUIPMENT":
					var grid: GridContainer=book._list.get_node("LibraryEquipmentGrid")
					check(grid.columns==5 and grid.get_child_count()==equipment.get_item_ids().size(),"all active equipment rendered once "+label)
					check(grid.get_global_rect().end.x<=safe.get_global_rect().end.x+1,"equipment grid width "+label)
					check(book._summary.visible==not book._compact_archive,"short screens release pinned selection space "+label)
				if mode=="SKILLS":
					for card: Button in book._list.get_children():
						var copy: VBoxContainer=card.get_child(0).get_child(1)
						check(copy.get_global_rect().end.y<=card.get_global_rect().end.y-8,"skill preview fits card "+str(card.name)+" "+label)
					book._open_skill_detail("spirit_sword")
					await frames()
					check(safe.get_global_rect().grow(1).encloses(book._detail_panel.get_global_rect()),"long skill detail fits "+label)
					var full_description: bool=false
					for copy_label: Label in book._detail_content.find_children("*","Label",true,false):
						if copy_label.text==book.tr(book._description("spirit_sword")):full_description=true
					check(full_description,"detail retains the complete production description "+label)
					var description: Label=book._detail_content.get_child(0).get_child(1)
					check(description.size.x>=book._detail_scroll.size.x-36,"detail text uses the reader width "+label)
					var bar: VScrollBar=book._detail_scroll.get_v_scroll_bar()
					check(bar.max_value>bar.page or book._detail_scroll.get_global_rect().grow(1).encloses(book._detail_content.get_global_rect()),"full description fits or can scroll "+label)
					book._close_popup()
		root.size=Vector2i(320,568)
		await frames()
		book._set_mode("EQUIPMENT")
		await frames()
		var scroll: ScrollContainer=book.find_child("SkillBookScroll",true,false)
		var grid: GridContainer=book._list.get_node("LibraryEquipmentGrid")
		var first: Button=grid.get_child(0)
		check(scroll.get_global_rect().grow(1).encloses(first.get_global_rect()),"compact phone shows a complete equipment tile "+language)
		await swipe(first.get_global_rect().get_center())
		check(scroll.scroll_vertical>20 and book._popup==null,"first real equipment swipe scrolls without opening detail "+language)
		book._search.text="  no-such-relic  "
		book._search.text_changed.emit(book._search.text)
		await frames()
		check(book._count.text.begins_with("0 ") and not book._summary.visible,"empty search clears stale selection "+language)
		book._search.text="   "+book.tr(str(equipment.get_item_data("jade_binding_chain").display_name))+"   "
		book._search.text_changed.emit(book._search.text)
		await frames()
		check(book._list.get_node("LibraryEquipmentGrid").get_child_count()==1,"localized search accepts surrounding spaces "+language)
		check(scroll.scroll_vertical==0,"new search starts at first result "+language)
		book._rarity="legendary";book._rarity_picker.select(4)
		book._set_mode("SKILLS");book._set_mode("EQUIPMENT")
		await frames()
		check(book._rarity=="ALL" and book._rarity_picker.selected==0,"section change resets hidden rarity state "+language)
		check(book._category_picker.text==("TIPE" if language=="id" else "TYPE") and book._rarity_picker.text==("RARITAS" if language=="id" else "RARITY"),"default filters identify their purpose "+language)
		grid=book._list.get_node("LibraryEquipmentGrid");first=grid.get_child(0)
		await touch(first.get_global_rect().get_center(),true)
		await touch(first.get_global_rect().get_center(),false)
		await frames()
		check(book._popup!=null,"compact equipment tap opens detail directly "+language)
		book._close_popup()
		root.size=Vector2i(648,1152);await frames()
		book._set_filter("SETS");await frames()
		var set_piece: Button=book._list.get_child(0).find_children("Relic_*","Button",true,false)[0]
		await touch(set_piece.get_global_rect().get_center(),true)
		await touch(set_piece.get_global_rect().get_center(),false)
		await frames()
		check(book._popup!=null,"set-piece tap opens visible detail on tall screens "+language)
		book._close_popup()
		root.size=Vector2i(320,568);await frames()
		var safe: Control=book.get_node("DeviceSafeArea")
		safe.offset_left=16;safe.offset_right=-16;safe.offset_top=24;safe.offset_bottom=-28
		await frames()
		book._open_equipment_detail("frost_lotus_robe");await frames()
		check(safe.get_global_rect().grow(1).encloses(book._detail_panel.get_global_rect()),"equipment popup respects inset safe area "+language)
		book._close_popup()
		book.queue_free();await frames()
	check(inventory.item_counts==inventory_before and equipment.equipped_item_ids==slots_before,"all archive browsing preserves inventory and loadout")
	print("LIBRARY_READABILITY_CHECKS=",checks,";FAILURES=",failures,";DISPLAY=",DisplayServer.get_name())
	if "--review" in OS.get_cmdline_user_args():
		settings.set_presentation("language","id" if "--review-id" in OS.get_cmdline_user_args() else "en")
		root.size=Vector2i(860,405) if "--landscape" in OS.get_cmdline_user_args() else Vector2i(320,568) if "--compact" in OS.get_cmdline_user_args() else Vector2i(405,860)
		var book: Control=await open_book()
		root.title="Jade Ascendant · Library review fixture"
		if "--skills" in OS.get_cmdline_user_args():book._set_mode("SKILLS")
		if "--sets" in OS.get_cmdline_user_args():book._set_filter("SETS")
		if "--builds" in OS.get_cmdline_user_args():book._set_mode("BUILDS")
		if "--chronicles" in OS.get_cmdline_user_args():book._set_mode("CHRONICLES")
		return
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	quit(1 if failures else 0)
