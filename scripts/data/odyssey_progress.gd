extends RefCounted
## Read-only adapter. Server state and immutable reward IDs remain authoritative.
static func lap_mode(state: Dictionary) -> bool:return int(state.get("journey_laps_version",0))==2
static func current(state: Dictionary) -> int:return int(state.get("laps",0)) if lap_mode(state) else int(state.get("rolls",0))
static func goal(state: Dictionary) -> int:return 12 if lap_mode(state) else 72
static func threshold(state: Dictionary,reward_id: int) -> int:return int(reward_id/6) if lap_mode(state) else reward_id
static func ready(state: Dictionary,reward_id: int) -> bool:
 return current(state)>=threshold(state,reward_id) or (lap_mode(state) and int(state.get("journey_legacy_rolls",0))>=reward_id)

static func complete(state: Dictionary) -> bool:
 for reward_id: int in [24,48,72]:
  if reward_id not in state.get("milestones",[]):return false
 return true
static func visible(event: Dictionary,state: Dictionary,stamp: int) -> bool:
 if event.is_empty() or not bool(event.get("enabled",false)) or complete(state):return false
 if stamp<int(event.get("ends_at",0)):return true
 if stamp>=int(event.get("ends_at",0))+259200:return false
 for reward_id: int in [24,48,72]:
  if ready(state,reward_id) and reward_id not in state.get("milestones",[]):return true
 return false
