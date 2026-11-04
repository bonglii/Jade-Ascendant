extends Node
var snapshot: Dictionary = {}
var sheet: Control
var _preview: TextureRect
var _format: OptionButton
var _alias_toggle: CheckBox
var _alias: LineEdit
var _status: Label
var _image: Image
var _renderer = preload("res://scripts/ui/run_card_renderer.gd").new()
var _native: Object
var _request: String = ""
var _save: Button
var _share: Button
var _temporary: String = ""
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var id: bool = SettingsManager.language == "id"
	sheet = preload("res://scripts/ui/player_sheet.gd").create(get_parent(),"KARTU RUN" if id else "RUN CARD","RunSharePanel")
	sheet.tree_exited.connect(queue_free)
	_format = OptionButton.new()
	_format.name = "RunCardFormat"
	_format.add_item("Feed · 1080 × 1350")
	_format.add_item("Story · 1080 × 1920")
	_format.custom_minimum_size.y = 44
	_format.item_selected.connect(func(_index: int):_render())
	sheet.content.add_child(_format)
	_alias_toggle = CheckBox.new()
	_alias_toggle.name = "RunCardShowAlias"
	_alias_toggle.text = "Tampilkan alias pilihan gue" if id else "Show my chosen alias"
	_alias_toggle.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_alias_toggle.custom_minimum_size.y = 44
	sheet.content.add_child(_alias_toggle)
	_alias = LineEdit.new()
	_alias.name = "RunCardAlias"
	_alias.placeholder_text = "Alias · opsional, 24 karakter" if id else "Alias · optional, 24 characters"
	_alias.max_length = 24
	_alias.custom_minimum_size.y = 44
	_alias.hide()
	sheet.content.add_child(_alias)
	_alias_toggle.toggled.connect(func(enabled: bool):_alias.visible=enabled;_render())
	_alias.text_submitted.connect(func(_value: String):_render())
	var apply: Button = sheet.button("PERBARUI PREVIEW" if id else "UPDATE PREVIEW")
	apply.pressed.connect(_render)
	sheet.content.add_child(apply)
	_preview = TextureRect.new()
	_preview.name = "RunCardPreview"
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(0,390)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.content.add_child(_preview)
	_status = sheet.label("PNG hanya berisi hasil run ini. Tidak ada data akun atau bonus share." if id else "PNG contains only this run. No account data or share rewards.",13)
	sheet.content.add_child(_status)
	_save = sheet.button("SIMPAN PNG" if id else "SAVE PNG")
	_save.name = "SaveRunCard"
	_save.pressed.connect(_export.bind(false))
	sheet.actions.add_child(_save)
	_share = sheet.button("BAGIKAN PNG" if id else "SHARE PNG")
	_share.name = "ShareRunCard"
	_share.pressed.connect(_export.bind(true))
	sheet.actions.add_child(_share)
	if Engine.has_singleton("JadeMonetizationNativeBridge"):
		_native = Engine.get_singleton("JadeMonetizationNativeBridge")
		if _native.has_signal("runCardExportResultV1"):
			_native.connect("runCardExportResultV1",_native_result)
	_share.visible = OS.get_name() == "Android"
	_render.call_deferred()
	preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(sheet)
func _render() -> void:
	if not is_instance_valid(sheet): return
	_image = _renderer.render(snapshot,_format.selected==1,_alias.text if _alias_toggle.button_pressed else "",SettingsManager.language)
	if _image != null: _preview.texture = ImageTexture.create_from_image(_image)
func _export(share: bool) -> void:
	if not _request.is_empty(): return
	_render() # Export exactly the visible alias/format from the same immutable run.
	if _image == null: return
	if OS.get_name() == "Android":
		if _native == null or not _native.has_method("exportRunCardV1"):
			_status.text = "Ekspor Android memerlukan build native terbaru." if SettingsManager.language=="id" else "Android export requires the updated native build."
			return
		_request = Crypto.new().generate_random_bytes(16).hex_encode()
		_temporary = "user://jade-run-"+_request+".png"
		if _image.save_png(_temporary) != OK:
			_request = ""
			_status.text = "PNG gagal dibuat." if SettingsManager.language=="id" else "PNG could not be created."
			return
		_save.disabled = true
		_share.disabled = true
		_status.text = "Menyiapkan gambar untuk dibagikan…" if SettingsManager.language == "id" else "Preparing image to share…"
		if not share:
			_status.text = "Menyimpan PNG…" if SettingsManager.language == "id" else "Saving PNG…"
		_native.call("exportRunCardV1",_request,ProjectSettings.globalize_path(_temporary),share)
	else:
		var dialog := FileDialog.new()
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.use_native_dialog = true
		dialog.filters = PackedStringArray(["*.png ; PNG"])
		dialog.current_file = "Jade-Ascendant.png"
		sheet.add_child(dialog)
		dialog.file_selected.connect(func(path: String):
			var success: bool = _image.save_png(path) == OK
			_status.text = ("PNG tersimpan." if success else "PNG gagal disimpan.") if SettingsManager.language=="id" else ("PNG saved." if success else "PNG could not be saved.")
			dialog.queue_free())
		dialog.canceled.connect(func():_status.text="Dibatalkan." if SettingsManager.language=="id" else "Cancelled.";dialog.queue_free())
		dialog.popup_centered_ratio(.8)
func _native_result(request: String, _success: bool, code: String) -> void:
	if request != _request: return
	_request = ""
	_save.disabled = false
	_share.disabled = false
	var texts: Dictionary = {
		"PNG_SAVED":["PNG saved.","PNG tersimpan."],
		"SHARE_CHOOSER_OPENED":["Share window opened. Choose an app or cancel.","Menu bagikan terbuka. Pilih aplikasi atau batalkan."],
		"SAVE_CANCELLED":["Save cancelled.","Penyimpanan dibatalkan."]}
	var values: Array = texts.get(code,["PNG export failed. Try again.","Ekspor PNG gagal. Coba lagi."])
	_status.text = str(values[1 if SettingsManager.language=="id" else 0])
	if not _temporary.is_empty(): DirAccess.remove_absolute(ProjectSettings.globalize_path(_temporary));_temporary=""
func _exit_tree() -> void:
	if _native != null and _native.has_signal("runCardExportResultV1") and _native.is_connected("runCardExportResultV1",_native_result):
		_native.disconnect("runCardExportResultV1",_native_result)
	if not _temporary.is_empty(): DirAccess.remove_absolute(ProjectSettings.globalize_path(_temporary))
