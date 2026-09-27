extends "res://scripts/ui/trials_production_presenter.gd"

## Trials keeps its approved production UI, but explicit claim confirmation
## is now owned by RewardClaimResultPresenter for cross-menu consistency.

func _schedule_reward_result(
	source_title: String,
	amount: int,
	reward_count: int,
	previous_balance: int,
	new_balance: int,
	delay_seconds: float
) -> void:
	var unified_presenter: Node = get_node_or_null(
		"/root/RewardClaimResultPresenter"
	)
	if unified_presenter != null:
		return

	# Safety fallback if the runtime helper is unavailable.
	result_generation += 1
	var generation: int = result_generation
	await get_tree().create_timer(delay_seconds).timeout
	if generation != result_generation:
		return
	if not is_instance_valid(scene_root):
		return
	_show_reward_overlay(
		source_title,
		amount,
		reward_count,
		previous_balance,
		new_balance
	)
