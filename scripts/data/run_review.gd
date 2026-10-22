extends RefCounted
## Read-only facts/advice about the current run. Never changes equipment,
## grants rewards, finalizes a run or infers that spending money is necessary.
static func capture(world: Node) -> Dictionary:
	var player: Node = world.get_node_or_null("player_1")
	if player == null: return {}
	var ledger: Node = player.get_node_or_null("WeaponManager/RunCombatLedger")
	var wave: Node = world.get_node_or_null("WaveManager")
	var survival: Node = world.get_node_or_null("SurvivalManager")
	if ledger == null or wave == null or survival == null: return {}
	var boss: Node = world.get_tree().get_first_node_in_group("boss")
	var fraction: float = -1.0
	if is_instance_valid(boss) and not bool(boss.get("is_dead")):
		fraction = clampf(float(boss.get("current_hp")) / maxf(float(boss.get("max_hp")), 0.001), 0.0, 1.0)
	return {"wave": int(wave.current_wave), "final_wave": int(wave.final_wave), "seconds": float(survival.survival_time), "level": int(player.level), "hits": int(ledger.hp_hits), "hp_loss": float(ledger.hp_loss), "incoming_complete": bool(ledger.incoming_complete), "metrics_complete": bool(ledger.metrics_complete), "boss_fraction": fraction, "boss_range": float(player.get_node("WeaponManager").boss_attack_range), "damage": ledger.damage_rows(), "skills": ledger.skills(), "damage_partial": bool(ledger.partial)}

static func advice(facts: Dictionary, language: String) -> Dictionary:
	var id: bool = language == "id"
	if facts.is_empty(): return {"title": "PERSIAPAN BERIKUTNYA" if id else "NEXT PREPARATION", "body": "Periksa build dan panduan skill di Hero/Library." if id else "Review your build and skill guide in Hero/Library."}
	if float(facts.get("boss_fraction", -1.0)) >= 0.0:
		var percent: int = ceili(float(facts.boss_fraction) * 100.0)
		return {"title": "BOSS TERSISA %d%% HP" % percent if id else "BOSS HAD %d%% HP LEFT" % percent, "body": "Hindari tanda serangan, lalu kembali dalam jangkauan serangan otomatis. Cek kombinasi skill dan pertahanan di Hero." if id else "Leave marked attacks, then return within auto-attack range. Review your skill combination and defenses in Hero."}
	if bool(facts.get("metrics_complete", false)) and int(facts.get("hits", 0)) >= 8:
		return {"title": "JAGA RUANG GERAK" if id else "KEEP ROOM TO MOVE", "body": "Run ini menerima %d hit ke HP. Tinggalkan celah untuk menghindar; pertimbangkan Qi Shield atau Iron Body saat ditawarkan." % int(facts.hits) if id else "This run took %d HP hits. Leave an escape route; consider Qi Shield or Iron Body when offered." % int(facts.hits)}
	if int(facts.get("wave", 1)) <= 3 and int(facts.get("level", 1)) < 5:
		return {"title": "BANGUN ART UTAMA" if id else "GROW YOUR MAIN ART", "body": "Ambil Qi setelah musuh tumbang. Fokuskan beberapa pilihan pada art utama sambil menjaga jarak aman." if id else "Collect Qi after enemies fall. Focus some choices on your main art while keeping a safe distance."}
	return {"title": "SESUAIKAN BUILD" if id else "REFINE YOUR BUILD", "body": "Empat armor/aksesori sejenis mengaktifkan set; weapon berdiri sendiri. Coba sinergi skill yang mendukung cara bertarungmu." if id else "Four matching armor/accessory pieces activate a set; your weapon is independent. Try skill synergies that fit your playstyle."}
