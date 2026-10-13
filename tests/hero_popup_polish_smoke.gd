extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("POPUP_POLISH_FAILURE "+label)
func settle() -> void:await create_timer(.12).timeout
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_hero_qa"):quit(2);return
 await create_timer(.4).timeout
 var inventory: Node=root.get_node("InventoryManager");var equipment: Node=root.get_node("EquipmentManager")
 equipment.active_run_loadout_snapshot.clear()
 for id: String in equipment.get_item_ids():inventory.item_counts[id]=1
 inventory.item_counts["refinement_shard"]=75;inventory.item_counts["nine_heavens_star_sword"]=3
 for id: String in ["nine_heavens_star_sword","sovereign_mantle","tribulation_bracer","cloudtreader_boots","ascendant_heart"]:equipment.equip_item(id)
 var before: Dictionary=equipment.build_equipment_save_data().duplicate(true);var counts: Dictionary=inventory.item_counts.duplicate(true)
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn");await settle()
 var screen: Control=current_scene
 root.content_scale_size=Vector2i.ZERO
 for viewport: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(896,504)]:
  root.size=viewport;await settle();screen._layout();await settle()
  for id: String in ["refinement_shard","sovereign_mantle","nine_heavens_star_sword","jade_binding_chain"]:
   screen._show_detail(id);await settle()
   var panel: Rect2=screen.sheet_panel.get_global_rect();var overlay: Rect2=screen.detail.get_global_rect()
   check(panel.size.y<overlay.size.y*.85,"compact item popup "+id+str(viewport))
   check(panel.position.x>=overlay.position.x and panel.end.x<=overlay.end.x+1,"popup width fits "+id+str(viewport))
   check(panel.position.y>=overlay.position.y and panel.end.y<=overlay.end.y+1,"popup height fits "+id+str(viewport))
   check(screen.sheet_scroll.get_global_rect().end.y<=screen.sheet_actions.get_global_rect().position.y+1,"scroll ends above fixed actions "+id)
   check(screen.sheet_panel.find_child("PopupHeader",true,false).get_parent()!=screen.sheet_body,"header is outside scroll")
   if id!="refinement_shard":check(screen.sheet_actions.find_child("EquipAction",true,false)!=null,"equip action outside description scroll")
   screen._close_detail();await process_frame
  screen._show_stats();await settle()
  check(screen.sheet_body.get_node("StatsGrid").get_child_count()==6,"six compact stat tiles")
  check(screen.sheet_panel.size.y<screen.detail.size.y*.85,"stats popup compact "+str(viewport))
  screen._refresh_all();await settle()
  check(screen.sheet_mode=="stats" and screen.detail_open,"refresh preserves stats mode")
  screen.handle_system_back();await process_frame;check(screen.detail==null,"Back closes stats without leaving HERO")
  var popup: PopupMenu=screen.filter_menu.get_popup()
  var skin: StyleBoxFlat=popup.get_theme_stylebox("panel") as StyleBoxFlat
  check(skin!=null and skin.bg_color.g>skin.bg_color.r*2,"jade menu instead of gray OS panel")
  check(popup.get_theme_icon("radio_checked").resource_path.ends_with("radio_selected.svg"),"authored selection indicator")
  check(screen.filter_menu.get_theme_icon("arrow").resource_path.ends_with("dropdown_arrow.svg"),"gold arrow replaces gray arrow")
  check(screen.filter_menu.get_theme_stylebox("normal") is StyleBoxTexture,"image-backed dropdown button")
 root.size=Vector2i(648,1152);await settle()
 screen._show_detail("nine_heavens_star_sword");await settle()
 screen._paragraph(screen.sheet_body,"Deskripsi panjang untuk pengujian scroll. ".repeat(70),14)
 screen._fit_sheet();await settle()
 screen.sheet_scroll.scroll_vertical=100000;await settle()
 check(screen.sheet_scroll.scroll_vertical>0,"long description genuinely scrolls")
 check(screen.sheet_actions.get_global_rect().end.y<=screen.sheet_panel.get_global_rect().end.y+1,"actions remain inside panel after scrolling")
 screen.handle_system_back();await process_frame
 check(current_scene==screen and screen.detail==null,"Back only dismisses modal")
 check(equipment.build_equipment_save_data()==before and inventory.item_counts==counts,"polish never mutates equipment or inventory")
 print("HERO_POPUP_POLISH_CHECKS=",checks,";FAILURES=",failures)
 quit(1 if failures else 0)
