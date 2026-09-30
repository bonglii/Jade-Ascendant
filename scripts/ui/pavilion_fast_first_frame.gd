extends "res://scripts/ui/pavilion_locked_runtime_screen.gd"

## Pavilion first-paint pass V3 — atomic initial composition.
## Source baseline: approved production composer + the V2 fast-first-frame pass.
## Gameplay, pity, Wish Fate, grants, inventory and save are not modified.
##
## Production's original _ready() first creates the backdrop and prepares
## the menu, then defers _finish_pavilion_initialization(). With the V2
## staging, players could see an empty Pavilion followed by feature panels
## arriving over multiple frames. Build the initial visible UI within _ready
## instead. This happens before scene_changed / menu fade-in can show it.
##
## Important: the inherited _ready() still queues the deferred callback.
## The one-shot guard ensures that callback never builds everything twice.

var _initial_ui_ready: bool = false
var _featured_snapshot: String = ""


func _ready() -> void:
	var startup_started_at: int = Time.get_ticks_msec()
	super()
	# All @onready bindings, the global wallet and the approved background
	# are already initialized by the production _ready() above.
	_finish_pavilion_initialization(startup_started_at)


func _finish_pavilion_initialization(startup_started_at: int) -> void:
	if _initial_ui_ready or not is_inside_tree():
		return
	_initial_ui_ready = true

	# Keep Scroll hidden only while building: no half-built UI is painted.
	var pavilion_scroll: ScrollContainer = $SafeArea/Scroll as ScrollContainer
	if pavilion_scroll != null:
		pavilion_scroll.visible = false

	var critical_started_at: int = Time.get_ticks_msec()
	_build_status_banner()
	_build_summon_section()
	var featured_build_ms: int = Time.get_ticks_msec() - critical_started_at

	# The lower feature blocks were previously deferred across four frames.
	# Create their visible shells together; the collapsed Forge's item cards
	# remain lazy, saving main-thread work on this critical path.
	_build_meditation_section()
	_build_aura_section()
	_build_forge_section()
	_build_player_trust_section()
	_add_bottom_safe_spacer()

	# Resolve all saved state ONCE, after every section exists. The composer
	# can then reveal the complete UI as one composition, not in instalments.
	# The Forge cards remain unbuilt while their approved fold is closed.
	if not PavilionManager.pavilion_changed.is_connected(_refresh):
		PavilionManager.pavilion_changed.connect(_refresh)
	_refresh()

	if pavilion_scroll != null:
		pavilion_scroll.visible = true
	DebugLogger.system(
		"Pavilion atomic UI ready | total %d ms | featured %d ms | complete before first paint"
		% [Time.get_ticks_msec() - startup_started_at, featured_build_ms]
	)

	# SummonRevealOverlay is intentionally NOT built here. It holds the entire
	# cinematic/result hierarchy and stays invisible until the first summon.
	# The original action handler is protected by _summon() below.


func _load_featured_items() -> void:
	# Set the live target before the FIRST featured-card construction. The
	# production composer previously built default/unselected cards, and then
	# rebuilt every image-backed card once it read the saved Wish target.
	super()
	var live_target: String = PavilionManager.get_wish_target_item_id()
	selected_rate_up_item_id = (
		live_target if live_target in featured_items else ""
	)


func _rebuild_featured_selector() -> void:
	# Locked composer initially constructs the featured cards and then calls
	# this again when the pity / Wish Fate state is refreshed. Skip the second
	# rebuild unless selection, availability or item order has really changed.
	var current_state: String = (
		str(featured_items)
		+ "|" + selected_rate_up_item_id
		+ "|" + str(PavilionManager.get_wish_target_options())
	)
	if (
		current_state == _featured_snapshot
		and featured_row != null
		and is_instance_valid(featured_row)
		and featured_row.get_child_count() == featured_items.size()
	):
		return
	_featured_snapshot = current_state
	super()


func _rebuild_equipment() -> void:
	# Forge is intentionally parked for the current release.
	# Keep the legacy backend dormant for a future update, but never construct
	# deterministic-acquisition cards in the production Pavilion.
	return


func _summon(pull_count: int) -> void:
	# Preserve the V2 grant-safety guard. Before a first transaction, the
	# cinematic/result view must exist; never allow a successful summon whose
	# rewards are granted without presenting its outcome.
	if summon_reveal_overlay == null or not is_instance_valid(summon_reveal_overlay):
		_build_summon_reveal_overlay()
	super(pull_count)

# ---------------------------------------------------------------------------
# CURRENT RELEASE FEATURE PARK
# ---------------------------------------------------------------------------
# Forge and Pavilion Aura are intentionally removed from the production
# surface for this release. Their legacy backend/data/assets remain untouched
# so a future update can redesign them without a save-schema migration.
#
# Current Pavilion focus:
#   - Equipment Summon
#   - pity / Legendary Mandate
#   - Wish / Rate-Up
#   - meditation / rewarded economy services


func _build_aura_section() -> void:
	# Do not expose stage-clear cosmetic auras in the current release.
	aura_grid = null
	aura_featured = null


func _rebuild_auras() -> void:
	# _refresh() still calls this inherited hook. Keep it intentionally inert
	# while the Aura feature is parked.
	return


func _build_forge_section() -> void:
	# Do not expose deterministic equipment acquisition in Pavilion.
	# This also removes its first-paint/layout cost.
	equipment_list = null
	compact_forge_host = null
	compact_forge_details = null
	compact_forge_toggle = null
	compact_forge_expanded = false


func _build_player_trust_section() -> void:
	var panel := _panel(content, _sanctum_section_style(CYAN, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)

	_label(
		copy,
		tr("PLAYER-FIRST ECONOMY"),
		11,
		Color(CYAN.r, CYAN.g, CYAN.b, 0.90)
	)
	_label(
		copy,
		tr("Odds visible • Pity disclosed • No forced purchase"),
		15,
		Color(1.0, 0.86, 0.48)
	)

	var privacy := _button(
		row,
		tr("PRIVACY & SUPPORT"),
		_open_privacy,
		false,
		CYAN
	)
	privacy.custom_minimum_size = Vector2(142.0, 42.0)


func _refresh_status() -> void:
	# Healthy state remains visually quiet. The old Forge-specific active-run
	# message is removed together with Forge.
	if SaveManager.is_progress_read_only():
		_set_status(
			tr(
				"SAVE RECOVERY REQUIRED • REOPEN THE GAME BEFORE "
				+ "CHANGING ECONOMY STATE"
			),
			Color(0.95, 0.43, 0.38)
		)
	else:
		status_panel.visible = false
