extends RefCounted
const PATHS: Array[String]=["vitality","sword_power","swift_qi"]
const OPTIONS: Dictionary={"vitality":["renewal","ward"],"sword_power":["focus","pulse"],"swift_qi":["stride","flow"]}
const NODES: Dictionary={
 "renewal":{"description_en":"Recover 1 HP every 20 kills. Cannot revive the player.","name":"JADE RENEWAL","description":"Pulih 1 HP tiap 20 kill. Tidak menghidupkan kembali player.","bonus":{"kill_heal":1.0}},
 "ward":{"description_en":"Reduce incoming HP damage by 6%. Applied separately from set armor.","name":"IRON MERIDIAN","description":"Kurangi damage HP yang diterima 6%. Diterapkan terpisah dari bonus set.","bonus":{"reduction":0.06}},
 "focus":{"description_en":"+5% damage while HP is at least 80%.","name":"STILL SWORD","description":"+5% damage saat HP minimal 80%.","bonus":{"high_health_damage":0.05}},
 "pulse":{"description_en":"Direct hits pulse 15% damage to up to 3 other enemies within 80 units. 3s cooldown; no recursive pulse or set-passive proc.","name":"DAO PULSE","description":"Hit langsung memicu gelombang 15% damage ke maksimal 3 musuh lain dalam radius 80. Cooldown 3 detik; tidak memicu diri sendiri atau pasif set.","bonus":{"splash":0.15}},
 "stride":{"description_en":"+8% movement speed.","name":"CLOUD STRIDE","description":"+8% movement speed.","bonus":{"movement":0.08}},
 "flow":{"description_en":"Starting attack cooldown ×0.96. Respects the minimum cooldown floor.","name":"QUIET QI","description":"Cooldown attack awal ×0.96. Tetap mengikuti batas cooldown minimum.","bonus":{"cooldown":0.04}}
}
static func eligible_choice(path: String,id: String) -> bool:return path in PATHS and id in OPTIONS[path]
