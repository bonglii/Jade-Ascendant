extends RefCounted

## Cloud Save Gate 2 — read-only transaction dependency inspector.
## This is an audited *structural* graph of permanent-domain write batches.
## It is NOT proof of purchase validity, earned rewards, or snapshot integrity.
## All upload/restore permissions remain false even if the graph is closed.
## Never treat input provided by the client as trusted economy evidence.

const TRANSACTION_FAMILIES: Dictionary = {
	"pavilion_summon": ["pavilion", "inventory"],
	"pavilion_currency_shop": ["pavilion", "progression", "inventory"],
	"pavilion_reward_or_liveops_claim": ["pavilion", "progression", "inventory"],
	"equipment_direct_purchase": ["progression", "inventory"],
	"equipment_ascension": ["equipment", "inventory"],
	"idle_cultivation_claim": ["idle_cultivation", "progression", "inventory"],
	"daily_quest_reward": ["daily_quests", "progression", "inventory"],
	"achievement_reward": ["achievements", "progression", "inventory"],
	"general_reward_grant": ["progression", "inventory"]
}


## Deterministic analysis of which audited transactions would be split if this
## set of domains were copied as a complete cross-device save.
## Accepts only uniquely named, registered permanent save domains. No disk I/O.
func inspect_domains(domain_ids: Array) -> Dictionary:
	if domain_ids.is_empty():
		return _reject("empty_domain_selection")

	var selected: Dictionary = {}
	for raw_id in domain_ids:
		if typeof(raw_id) != TYPE_STRING:
			return _reject("non_string_domain_id")
		var domain_id: String = raw_id
		if selected.has(domain_id):
			return _reject("duplicate_domain_id")
		if not SaveManager.has_save_domain(domain_id):
			return _reject("unregistered_domain")
		if SaveManager.get_save_scope(domain_id) != SaveManager.SCOPE_PERMANENT:
			return _reject("non_permanent_domain")
		selected[domain_id] = true

	var split_families: Array[String] = []
	var missing_dependencies: Dictionary = {}
	var family_names: Array = TRANSACTION_FAMILIES.keys()
	family_names.sort()
	for family_name in family_names:
		var members: Array = TRANSACTION_FAMILIES[family_name]
		var selected_count: int = 0
		for member in members:
			# Fail closed if the audited graph becomes stale relative to SaveManager.
			if not SaveManager.has_save_domain(member):
				return _reject("audited_domain_removed")
			if SaveManager.get_save_scope(member) != SaveManager.SCOPE_PERMANENT:
				return _reject("audited_domain_scope_changed")
			if selected.has(member):
				selected_count += 1
		if selected_count == 0 or selected_count == members.size():
			continue
		split_families.append(str(family_name))
		for member in members:
			if not selected.has(member):
				missing_dependencies[member] = true

	var missing_ids: Array = missing_dependencies.keys()
	missing_ids.sort()
	return {
		"valid": true,
		"reason": "audited_transaction_graph_only",
		"transaction_closed": split_families.is_empty(),
		"split_families": split_families,
		"missing_dependency_domains": missing_ids,
		"audited_family_count": TRANSACTION_FAMILIES.size(),
		"trusted_ledger_present": false,
		"economy_verified": false,
		"upload_allowed": false,
		"restore_allowed": false
	}


func _reject(reason: String) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"transaction_closed": false,
		"split_families": [],
		"missing_dependency_domains": [],
		"audited_family_count": TRANSACTION_FAMILIES.size(),
		"trusted_ledger_present": false,
		"economy_verified": false,
		"upload_allowed": false,
		"restore_allowed": false
	}
