extends RefCounted

## Device-only first-entry choice. This is UI preference, not a SaveManager domain.
## Firebase owns the signed-in session; no gameplay state is read or written here.
const FILE_PATH: String = "user://google_account_entry.cfg"
const SECTION: String = "entry"
const CHOICE_KEY: String = "completed"


static func was_completed() -> bool:
	var config := ConfigFile.new()
	if config.load(FILE_PATH) != OK:
		return false
	return bool(config.get_value(SECTION, CHOICE_KEY, false))


static func mark_completed() -> bool:
	var config := ConfigFile.new()
	# Do not overwrite unrelated preference fields if they are added later.
	config.load(FILE_PATH)
	config.set_value(SECTION, CHOICE_KEY, true)
	var save_error: Error = config.save(FILE_PATH)
	if save_error != OK:
		push_warning(
			"Account entry: could not persist the welcome choice (error %d)."
			% int(save_error)
		)
		return false
	return true
