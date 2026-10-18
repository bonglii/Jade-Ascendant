extends VBoxContainer
var updates: Node
var language: String="en"
var status_text: Label
var toggle: Button
var system: Button
func _local(english: String, indonesian: String) -> String: return indonesian if language=="id" else english
func _ready() -> void:
 add_theme_constant_override("separation",12)
 status_text=Label.new(); status_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; status_text.add_theme_font_size_override("font_size",17); add_child(status_text)
 toggle=Button.new(); toggle.custom_minimum_size.y=60; toggle.theme_type_variation=&"JadePrimaryButton"; add_child(toggle)
 system=Button.new(); system.text=_local("ANDROID NOTIFICATION SETTINGS","PENGATURAN NOTIFIKASI ANDROID"); system.custom_minimum_size.y=56; system.theme_type_variation=&"JadeSecondaryButton"; add_child(system)
 system.pressed.connect(func() -> void:
  if updates!=null: updates.call("open_system_settings"))
 toggle.pressed.connect(func() -> void:
  var data: Dictionary=updates.call("status")
  updates.call("enable",not bool(data.get("opt_in",false)))
  _refresh())
 var timer:=Timer.new(); timer.wait_time=1.0; timer.timeout.connect(_refresh); add_child(timer); timer.start(); _refresh()
func _refresh() -> void:
 var data: Dictionary=updates.call("status") if updates!=null else {}
 var supported: bool=bool(data.get("supported",false)); var enabled: bool=bool(data.get("opt_in",false)); var state: String=str(data.get("stage","unavailable"))
 var text: String=_local("Off. You can play normally without alerts.","Nonaktif. Game tetap bisa dimainkan seperti biasa.")
 if not supported: text=_local("Available in the updated Android build.","Tersedia di build Android terbaru.")
 elif state=="system_blocked": text=_local("Android is blocking notifications. Enable them in Android settings.","Notifikasi diblokir Android. Aktifkan di pengaturan Android.")
 elif enabled: text=_local("Enabled · connected" if data.get("subscribed",false) else "Enabled · connecting; will retry automatically","Aktif · terhubung" if data.get("subscribed",false) else "Aktif · menyambung; dicoba ulang otomatis")
 status_text.text=text; toggle.text=_local("DISABLE ALERTS" if enabled else "ENABLE UPDATE ALERTS","NONAKTIFKAN NOTIFIKASI" if enabled else "AKTIFKAN NOTIFIKASI"); toggle.disabled=not supported; system.visible=supported
