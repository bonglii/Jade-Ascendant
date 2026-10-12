extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: run.call_deferred()
func frames(count: int=4) -> void:
	for _frame in range(count): await process_frame
func build(presenter: Node) -> PanelContainer:
	var popup:=Control.new();root.add_child(popup)
	var panel:=PanelContainer.new();popup.add_child(panel)
	panel.anchor_top=0.5;panel.anchor_bottom=0.5;panel.offset_top=-777;panel.offset_bottom=777
	var scroll:=ScrollContainer.new();panel.add_child(scroll)
	var body:=VBoxContainer.new();scroll.add_child(body)
	var label:=Label.new();label.text="Idle modal lifetime fixture";body.add_child(label)
	presenter._popup=popup;presenter._modal_panel=panel;presenter._premium_scroll=scroll;presenter._premium_body=body
	return panel
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_gacha_qa"):push_error("Isolated QA required");quit(2);return
	await create_timer(0.5).timeout
	var presenter: Node=load("res://scripts/ui/idle_cultivation_presenter_premium.gd").new()
	root.get_node("IdleCultivationManager").add_child(presenter);presenter.set_process(false)
	await frames()
	var stones: int=root.get_node("ProgressionManager").spirit_stone
	for index in range(20):
		build(presenter)
		presenter._fit_modal_to_content()
		if index%2:await frames(1)
		presenter._close_popup()
		var reopened: PanelContainer=build(presenter)
		await frames()
		check(reopened.offset_top==-777,"stale fit cannot resize reopened popup "+str(index))
		presenter._fit_modal_to_content();await frames()
		check(reopened.offset_top!=-777,"current popup fits normally "+str(index))
		presenter._close_popup();await frames()
		check(presenter._premium_body==null and presenter._modal_panel==null,"closed references cleared "+str(index))
	build(presenter);presenter._fit_modal_to_content()
	root.get_node("IdleCultivationManager").remove_child(presenter)
	await frames()
	check(true,"detached presenter safely cancels fit")
	check(root.get_node("ProgressionManager").spirit_stone==stones,"layout fixes do not grant resources")
	presenter._popup.queue_free();presenter.free();await frames()
	print("IDLE_MODAL_QA checks=",checks," failures=",failures)
	quit(1 if failures else 0)
