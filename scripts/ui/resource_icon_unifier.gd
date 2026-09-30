extends Node

## Resource Icon Unification V1 — purely presentational.
## Unifies historic UI icon references to the same four approved master icons
## used by SharedHubResourceBar, Treasury and RewardDelivery. No reward data,
## save fields, gameplay, navigation, item art or button callbacks are changed.
##
## Dynamic UI (Victory, Defeat, Pavilion, claim popups) can create or retarget
## TextureRects after _ready; a narrowly scoped, low-rate recheck therefore
## follows only UI icon nodes, never the gameplay world or enemy tree.

const SPIRIT_STONE: Texture2D = preload(
	"res://assets/ui/shared/resources/spirit_stone_premium.png"
)
const REFINEMENT_SHARD: Texture2D = preload(
	"res://assets/ui/shared/resources/refinement_shard_premium.png"
)
const CELESTIAL_JADE: Texture2D = preload(
	"res://assets/ui/shared/resources/celestial_jade_premium.png"
)
const PAVILION_SEAL: Texture2D = preload(
	"res://assets/ui/shared/resources/pavilion_seal_premium.png"
)

const POLL_SECONDS: float = 0.45
const PRUNE_EVERY: int = 12

const LEGACY_PATHS: Dictionary = {
	"res://assets/ui/icons/spirit_stone.svg": "spirit_stone",
	"res://assets/ui/pavilion/icons/spirit_stone.png": "spirit_stone",
	"res://assets/ui/equipment/refinement_shard.svg": "refinement_shard",
	"res://assets/ui/pavilion/icons/refinement_shard.png": "refinement_shard",
	"res://assets/ui/pavilion/polish/celestial_jade.svg": "celestial_jade",
	"res://assets/ui/pavilion/icons/celestial_jade.png": "celestial_jade",
	"res://assets/ui/pavilion/polish/pavilion_seal.svg": "pavilion_seal",
	"res://assets/ui/pavilion/icons/pavilion_seal.png": "pavilion_seal",
}

var _watched: Array[WeakRef] = []
var _elapsed: float = 0.0
var _poll_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	# Pick up UI nodes already present when this autoload starts.
	_collect_existing(get_tree().root)
	call_deferred("_check_watched")


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	_watched.clear()


func _on_node_added(added_node: Node) -> void:
	if added_node is TextureRect or added_node is Button or added_node is TextureButton:
		_watched.append(weakref(added_node))
		# Texture assignment can occur after add_child() in production screens.
		# The scheduled recheck covers late assignment without a scene traversal.


func _collect_existing(root_node: Node) -> void:
	for child: Node in root_node.get_children():
		_on_node_added(child)
		_collect_existing(child)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < POLL_SECONDS:
		return
	_elapsed = 0.0
	_check_watched()


func _check_watched() -> void:
	_poll_count += 1
	var prune_now: bool = _poll_count % PRUNE_EVERY == 0
	for entry_index: int in range(_watched.size() - 1, -1, -1):
		var candidate: Node = _watched[entry_index].get_ref() as Node
		if not is_instance_valid(candidate):
			if prune_now:
				_watched.remove_at(entry_index)
			continue
		if candidate is TextureRect:
			var icon_rect: TextureRect = candidate as TextureRect
			var result: Texture2D = _canonical(icon_rect.texture)
			if result != null:
				icon_rect.texture = result
		elif candidate is TextureButton:
			var texture_button: TextureButton = candidate as TextureButton
			var normal_replacement: Texture2D = _canonical(texture_button.texture_normal)
			if normal_replacement != null:
				texture_button.texture_normal = normal_replacement
		elif candidate is Button:
			var icon_button: Button = candidate as Button
			var button_replacement: Texture2D = _canonical(icon_button.icon)
			if button_replacement != null:
				icon_button.icon = button_replacement


func _canonical(texture_value: Texture2D) -> Texture2D:
	if texture_value == null:
		return null
	var old_path: String = texture_value.resource_path
	if not LEGACY_PATHS.has(old_path):
		return null
	match str(LEGACY_PATHS[old_path]):
		"spirit_stone":
			return SPIRIT_STONE
		"refinement_shard":
			return REFINEMENT_SHARD
		"celestial_jade":
			return CELESTIAL_JADE
		"pavilion_seal":
			return PAVILION_SEAL
	return null
