extends RefCounted
const COPY := {
 "jade_wind":["Exit across the short side of the lane.","Keluar lewat sisi pendek jalur."],
 "scarlet_rite":["Two bursts. Stay outside until the second mark fades.","Dua ledakan. Tetap di luar sampai tanda kedua padam."],
 "starfall":["Three frozen marks, in order. Keep a route to clear ground.","Tiga tanda beku, berurutan. Sisakan jalan ke ruang kosong."],
 "froststep":["Two brief zones; take the gap. Movement is never slowed.","Dua zona singkat; lewat celahnya. Gerakan tetap normal."],
 "sunforge":["One ring wave. Use the open gap or stay in its center.","Satu gelombang cincin. Gunakan celah atau pusatnya."]}
static func hint(theme: String, version: int, language: String) -> String:
	if version != 2:return "Aturan v1 · sesi lama tetap sama." if language=="id" else "Rules v1 · Existing sessions keep their rules."
	return ("ATURAN v2 · " if language=="id" else "RULES v2 · ")+str(COPY.get(theme,COPY.jade_wind)[1 if language=="id" else 0])
