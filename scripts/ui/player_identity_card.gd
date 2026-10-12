extends PanelContainer

const GOLD := Color(1.0,0.83,0.43)
const JADE := Color(0.40,0.94,0.79)
const MUTED := Color(0.70,0.83,0.80)
var _name: Label
var _uid: Label
var _edit: Button
var _copy: Button
var _editor: VBoxContainer
var _name_input: LineEdit
var _hint: Label
var _save: Button
var _status: Label
var _retry: Button
var _uid_kind: Label
var _server_connect: Button

func _ready() -> void:
	name = "PlayerIdentityCard"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.006,0.065,0.068,0.98)
	style.border_color = Color(0.27,0.70,0.59,0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	add_theme_stylebox_override("panel",style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	add_child(content)
	content.add_child(_label(_local("PLAYER IDENTITY","IDENTITAS PEMAIN"),12,JADE))
	var heading := HBoxContainer.new()
	content.add_child(heading)
	_name = _label("",24,GOLD)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(_name)
	_edit = _button(_local("EDIT","UBAH"),_begin_edit)
	heading.add_child(_edit)
	var uid_row := HBoxContainer.new()
	uid_row.add_theme_constant_override("separation",8)
	content.add_child(uid_row)
	var id_text := VBoxContainer.new()
	id_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uid_row.add_child(id_text)
	_uid_kind = _label("UID",11,MUTED)
	id_text.add_child(_uid_kind)
	_uid = _label("",14,Color(0.89,0.97,0.94))
	_uid.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	id_text.add_child(_uid)
	_copy = _button(_local("COPY","SALIN"),_copy_uid)
	uid_row.add_child(_copy)
	_editor = VBoxContainer.new()
	_editor.visible = false
	_editor.add_theme_constant_override("separation",8)
	content.add_child(_editor)
	_name_input = LineEdit.new()
	_name_input.name = "PlayerNameInput"
	_name_input.custom_minimum_size.y = 52
	_name_input.max_length = 64
	_name_input.placeholder_text = _local("Your player name","Nama pemain lu")
	_name_input.add_theme_font_size_override("font_size",19)
	_name_input.text_changed.connect(_validate_name_input)
	_name_input.text_submitted.connect(func(_text: String): _save_name())
	_editor.add_child(_name_input)
	_hint = _label("",13,MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_editor.add_child(_hint)
	var actions := HBoxContainer.new()
	_editor.add_child(actions)
	_save = _button(_local("SAVE NAME","SIMPAN NAMA"),_save_name)
	_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_save)
	actions.add_child(_button(_local("CANCEL","BATAL"),_cancel_edit))
	_status = _label(_local("Player identity on this device.","Identitas pemain di perangkat ini."),12,MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)
	_server_connect = _button(_local("CONNECT SERVER","HUBUNGKAN SERVER"),PlayerIdentityServerClient.connect_profile)
	content.add_child(_server_connect)
	_retry = _button(_local("RETRY","COBA LAGI"),PlayerIdentityManager.refresh_profile)
	content.add_child(_retry)
	PlayerIdentityManager.profile_changed.connect(_refresh)
	_refresh(PlayerIdentityManager.get_profile_snapshot())

func _local(en: String, id: String) -> String:
	return id if SettingsManager.language == "id" else en

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(72,46)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.add_theme_font_size_override("font_size",14)
	button.pressed.connect(action)
	return button

func _refresh(snapshot: Dictionary) -> void:
	var profile_ready: bool = bool(snapshot.ready)
	_name.text = str(snapshot.display_name) if profile_ready else _local("Profile unavailable","Profil belum tersedia")
	_uid.text = str(snapshot.player_uid) if profile_ready else "—"
	_uid.tooltip_text = str(snapshot.player_uid)
	_uid_kind.text = "UID" if bool(snapshot.server_registered) else _local("DEVICE ID","ID PERANGKAT")
	_edit.disabled = not profile_ready
	_copy.disabled = not profile_ready
	_retry.visible = not profile_ready
	if not profile_ready:
		_status.text = _local("Profile unavailable. Retry; gameplay progress is kept separately.","Profil belum tersedia. Coba lagi; progres game tetap tersimpan terpisah.")
		_editor.visible = false
	else:
		_status.text = _connection_hint(snapshot)
	_edit.visible = not _editor.visible
	_server_connect.visible = profile_ready and str(snapshot.server_status) != "connected"
	_server_connect.disabled = str(snapshot.server_status) in ["android_required","sign_in_required","connecting","checking_connection","resolving_ipv4"]

func _connection_hint(snapshot: Dictionary) -> String:
	var state: String = str(snapshot.server_status)
	if state == "connected": return _local("SERVER CONNECTED","SERVER TERHUBUNG")
	var message: String = _local("Server registration pending.","Registrasi server belum selesai.")
	match state:
		"connecting": message = _local("Connecting to server...","Menghubungkan server...")
		"resolving_ipv4": message = _local("Selecting server network route...","Memilih jalur jaringan server...")
		"checking_connection": message = _local("Checking game-to-server connection...","Memeriksa koneksi game ke server...")
		"android_required": message = _local("Server connection requires the Android build.","Koneksi server memerlukan build Android.")
		"sign_in_required": message = _local("Waiting for account connection.","Menunggu koneksi akun.")
		"token_error", "token_timeout", "invalid_token": message = _local("Account token unavailable. Retry account connection.","Token akun belum tersedia. Coba hubungkan akun lagi.")
		"empty_response", "invalid_response": message = _local("Invalid server response. Retry connection.","Respons server tidak valid. Coba hubungkan lagi.")
		"identity_response_rejected": message = _local("Server identity could not be saved or verified.","Identitas server belum dapat disimpan atau diverifikasi.")
	if state.begins_with("register_timeout_"):
		message = _local("Game reached server; registration timed out.","Game dapat mencapai server; registrasi melewati batas waktu.") if state.ends_with("__health_ok") else _local("Game could not confirm server reachability.","Game belum dapat memastikan akses ke server.")
	elif state.begins_with("network_"):
		message = _local("Server response timed out. Retry connection.","Respons server melewati batas waktu. Coba hubungkan lagi.") if state == "network_13" else _local("Network connection failed.","Koneksi jaringan gagal.")
	elif state.begins_with("http_"):
		message = _local("Server returned HTTP ","Server mengembalikan HTTP ") + state.substr(5) + "."
	elif state.begins_with("request_start_"):
		message = _local("Network request could not start.","Permintaan jaringan belum dapat dimulai.")
	# Fixed diagnostic codes only; never include native/token/provider messages.
	if state not in ["pending","connecting","connected","offline","checking_connection","resolving_ipv4"]: message += " ["+state+"]"
	return (_local("Saved server UID • ","UID server tersimpan • ") if bool(snapshot.server_registered) else _local("Device ID • ","ID perangkat • ")) + message

func _begin_edit() -> void:
	_name_input.text = str(PlayerIdentityManager.get_profile_snapshot().display_name)
	_editor.visible = true
	_edit.visible = false
	_validate_name_input(_name_input.text)
	_name_input.grab_focus()
	_name_input.select_all()
	call_deferred("_reveal_editor")

func _reveal_editor() -> void:
	var parent: Node = get_parent()
	while parent != null:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(_name_input)
			return
		parent = parent.get_parent()

func _validate_name_input(text: String) -> void:
	var valid: Dictionary = PlayerIdentityManager.validate_name(text)
	_save.disabled = not bool(valid.valid)
	_hint.text = _local("3–20 characters. Letters, numbers, spaces, . _ ' and -.","3–20 karakter. Huruf, angka, spasi, . _ ' dan -.") if bool(valid.valid) else _local("Use 3–20 characters; start with a letter or number.","Gunakan 3–20 karakter; awali dengan huruf atau angka.")
	_hint.add_theme_color_override("font_color",MUTED if bool(valid.valid) else GOLD)

func _cancel_edit() -> void:
	_name_input.release_focus()
	_editor.visible = false
	_edit.visible = true

func _save_name() -> void:
	if not _editor.visible or _save.disabled: return
	var result: Dictionary = PlayerIdentityManager.rename_player(_name_input.text)
	if not bool(result.success):
		_hint.text = _local("Name was not saved. Retry; your current name is unchanged.","Nama belum tersimpan. Coba lagi; nama sebelumnya tetap aman.")
		return
	_cancel_edit()
	_status.text = _local("NAME SAVED","NAMA TERSIMPAN")

func _copy_uid() -> void:
	var snapshot: Dictionary = PlayerIdentityManager.get_profile_snapshot()
	if not bool(snapshot.ready): return
	DisplayServer.clipboard_set(str(snapshot.player_uid))
	_status.text = _local("UID COPIED","UID DISALIN")
