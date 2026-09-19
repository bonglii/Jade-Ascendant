extends Control

const LiveOpsUi = preload(
	"res://scripts/ui/liveops/live_ops_ui.gd"
)

const ICON_MAILBOX: Texture2D = preload(
	"res://assets/ui/liveops/mailbox.png"
)

var content: VBoxContainer
var live_ops: Node


func _ready() -> void:
	live_ops = get_node_or_null("/root/LiveOpsManager")
	if live_ops == null:
		push_error("MailboxScreen: LiveOpsManager tidak tersedia.")
		return

	SceneTransitionManager.set_back_handler(_back)

	var shell: Dictionary = LiveOpsUi.build_shell(
		self,
		tr("JADE SANCTUARY"),
		tr("Mailbox"),
		tr(
			"Messages, gifts, and system notices from the Jade Sanctuary."
		),
		ICON_MAILBOX
	)
	content = shell["content"] as VBoxContainer
	(shell["back_button"] as Button).pressed.connect(_back)

	live_ops.mark_all_mail_read()
	_refresh()


func _refresh() -> void:
	LiveOpsUi.clear_container(content)
	var entries: Array[Dictionary] = live_ops.get_mail_entries()
	if entries.is_empty():
		var empty_card := LiveOpsUi.make_card(content)
		LiveOpsUi.add_label(
			empty_card,
			tr("NO MAIL"),
			13,
			Color(0.96, 0.78, 0.34, 1.0)
		)
		LiveOpsUi.add_label(
			empty_card,
			tr("Your mailbox is empty."),
			14
		)
		return

	for mail: Dictionary in entries:
		_add_mail_card(mail)


func _add_mail_card(mail: Dictionary) -> void:
	var reward: Dictionary = mail.get("reward", {})
	var claimed: bool = bool(mail.get("claimed", false))
	var accent: Color = (
		Color(0.96, 0.78, 0.34, 1.0)
		if not reward.is_empty() and not claimed
		else Color(0.30, 0.82, 0.72, 1.0)
	)
	var card := LiveOpsUi.make_card(content, accent)
	var message_icon := TextureRect.new()
	message_icon.custom_minimum_size = Vector2(46.0, 46.0)
	message_icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	message_icon.texture = ICON_MAILBOX
	message_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	message_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	message_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(message_icon)
	LiveOpsUi.add_label(
		card,
		tr(str(mail.get("sender", ""))),
		11,
		accent
	)
	LiveOpsUi.add_label(
		card,
		tr(str(mail.get("title", ""))),
		19,
		Color(0.94, 0.98, 0.96, 1.0)
	)
	LiveOpsUi.add_label(
		card,
		tr(str(mail.get("body", ""))),
		13,
		Color(0.70, 0.82, 0.79, 1.0)
	)

	if reward.is_empty():
		LiveOpsUi.add_label(
			card,
			tr("READ"),
			11,
			Color(0.46, 0.76, 0.70, 1.0)
		)
		return

	LiveOpsUi.add_label(
		card,
		tr("ATTACHMENT"),
		11,
		Color(0.96, 0.78, 0.34, 1.0)
	)
	LiveOpsUi.add_label(
		card,
		RewardManager.get_reward_summary(reward),
		14,
		Color(0.92, 0.88, 0.68, 1.0)
	)

	if claimed:
		var claimed_button := LiveOpsUi.add_action_button(
			card,
			tr("CLAIMED"),
			Callable(),
			false
		)
		claimed_button.disabled = true
		return

	var mail_id: String = str(mail.get("id", ""))
	LiveOpsUi.add_action_button(
		card,
		tr("CLAIM ATTACHMENT"),
		func() -> void: _claim_mail(mail_id),
		true
	)


func _claim_mail(mail_id: String) -> void:
	if live_ops.claim_mail(mail_id):
		_refresh()


func _back() -> void:
	LiveOpsUi.return_home(self)
