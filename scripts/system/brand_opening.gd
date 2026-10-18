extends Control

## Lightweight presentation only. Static logo bounds prevent font/scale pumping.
const BACKGROUND: Color = Color("061b1d")
@onready var lockup: TextureRect = $Lockup
@onready var status: Label = $Status
@onready var studio: Label = $Studio
@onready var retry: Button = $Retry
var _age: float = 0.0
var _failed: bool = false
var _reduced: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reduced = SettingsManager.reduced_effects
	resized.connect(_layout)
	status.text = "Membuka perjalanan..." if SettingsManager.language == "id" else "Opening your journey..."
	retry.text = "COBA LAGI" if SettingsManager.language == "id" else "TRY AGAIN"
	retry.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_layout()
	if not _reduced:
		lockup.modulate.a = 0.35
		create_tween().tween_property(lockup, "modulate:a", 1.0, 0.38)

func _layout() -> void:
	var safe: Rect2 = Rect2(Vector2.ZERO, size)
	if OS.get_name() == "Android":
		var screen: Vector2i = DisplayServer.screen_get_size()
		var area: Rect2i = DisplayServer.get_display_safe_area()
		if screen.x > 0 and screen.y > 0 and area.size.x > 0:
			var ratio: Vector2 = size / Vector2(screen)
			safe = Rect2(Vector2(area.position) * ratio, Vector2(area.size) * ratio)
	var side: float = minf(safe.size.x * 0.88, safe.size.y * 0.62)
	lockup.position = safe.position + Vector2((safe.size.x - side) * 0.5, safe.size.y * 0.43 - side * 0.5)
	lockup.size = Vector2(side, side)
	status.position = safe.position + Vector2(20, safe.size.y * 0.78)
	status.size = Vector2(maxf(0, safe.size.x - 40), 32)
	studio.position = safe.position + Vector2(20, maxf(0, safe.size.y - 56))
	studio.size = Vector2(maxf(0, safe.size.x - 40), 28)
	retry.size = Vector2(minf(240, safe.size.x - 40), 52)
	retry.position = safe.position + Vector2((safe.size.x - retry.size.x) * 0.5, safe.size.y * 0.84)

func _process(delta: float) -> void:
	if _reduced or _failed:
		return
	_age += delta
	queue_redraw()

func _draw() -> void:
	if _failed:
		return
	var y: float = status.position.y - 15.0
	var width: float = minf(180.0, size.x * 0.35)
	var x: float = (size.x - width) * 0.5
	draw_line(Vector2(x, y), Vector2(x + width, y), Color(0.50, 0.64, 0.54, 0.22), 1.0, true)
	var t: float = 0.5 if _reduced else 0.5 + 0.5 * sin(_age * 2.5)
	var at: Vector2 = Vector2(x + 12.0 + t * (width - 24.0), y)
	draw_circle(at, 3.0, Color(0.50, 0.94, 0.76, 0.22))
	draw_circle(at, 1.5, Color(0.87, 0.77, 0.49, 0.9))

func show_failure() -> void:
	_failed = true
	status.text = "Halaman belum bisa dibuka." if SettingsManager.language == "id" else "Unable to open the next screen."
	retry.show()
	queue_redraw()

func clear_failure() -> void:
	_failed = false
	retry.hide()
	status.text = "Membuka perjalanan..." if SettingsManager.language == "id" else "Opening your journey..."
	queue_redraw()
