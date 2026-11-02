extends RefCounted
const Snapshot = preload("res://scripts/data/run_share_snapshot.gd")
static func open(host: Node, raw: Dictionary) -> Control:
	# Rebuild the allowlisted DTO, stripping even accidental extra keys.
	var data: Dictionary = Snapshot.journey(int(raw.get("chapter",0)),int(raw.get("stage",0)),str(raw.get("title","")),raw)
	if raw.get("mode")=="trials" and not data.is_empty():
		data.mode="trials";data.tier=int(raw.get("tier",data.chapter))
	if data.is_empty():
		return null
	var controller = load("res://scripts/ui/run_share_controller.gd").new()
	controller.snapshot = data.duplicate(true)
	host.add_child(controller)
	return controller.sheet
