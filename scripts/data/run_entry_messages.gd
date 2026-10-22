extends RefCounted
## Presentation categories are carried by the failed check, never guessed from
## a generic HTTP failure or from the presence of a checkpoint.
static func view(code: String, language: String="en", owner_hint: String="") -> Dictionary:
 var id: bool=language=="id"
 var rows: Dictionary={
  "ACCOUNT_MISMATCH":["Use the run's account","Gunakan akun pemilik run","This checkpoint belongs to a different account. Sign in with its original account to continue.","Checkpoint ini terhubung ke akun berbeda. Masuk dengan akun asalnya untuk melanjutkan.","account"],
  "ACCOUNT_CHANGED":["Account changed","Akun berubah","The active account changed during verification. Reopen the stage and retry with the intended account.","Akun aktif berubah saat verifikasi. Buka kembali stage dan coba dengan akun yang diinginkan.","retry"],
  "SIGN_IN_REQUIRED":["Sign-in needs attention","Periksa login akun","Your account could not be verified yet. Check Google sign-in and the connection, then retry.","Akun belum dapat diverifikasi. Periksa login Google dan koneksi, lalu coba lagi.","account"],
  "COMPASS_GRANT_REQUIRED":["Compass ownership not confirmed","Kepemilikan Compass belum terkonfirmasi","The server has not confirmed this account's Compass grant. Complete its mailbox delivery or check the event reward. You can use another weapon meanwhile.","Server belum mengonfirmasi hadiah Compass akun ini. Selesaikan pengiriman mailbox atau periksa hadiah event. Sementara itu, gunakan senjata lain.","hero"],
  "COMPASS_VERIFICATION_UNAVAILABLE":["Compass verification unavailable","Verifikasi Compass belum tersedia","The ownership service could not be reached. This does not mean the Compass belongs to another account. Retry shortly.","Layanan kepemilikan belum dapat dihubungi. Ini tidak berarti Compass milik akun lain. Coba kembali sebentar lagi.","retry"],
  "APP_VERIFICATION_UNAVAILABLE":["App verification unavailable","Verifikasi aplikasi belum tersedia","The app could not complete its security verification. Check the connection and use the current Google Play build, then retry.","Aplikasi belum dapat menyelesaikan verifikasi keamanan. Periksa koneksi dan gunakan build Google Play terbaru, lalu coba kembali.","retry"],
  "ACCOUNT_HELD":["Account review required","Akun perlu diperiksa","A refunded purchase requires review before using the affected equipment. Open Settings and copy the support report.","Pembelian yang dikembalikan dananya perlu diperiksa sebelum equipment terkait digunakan. Buka Settings dan salin laporan bantuan.","account"],
  "CHECKPOINT_UNAVAILABLE":["Checkpoint needs recovery","Checkpoint perlu dipulihkan","The saved run could not be read safely. Reopen the game and retry. Contact support if it persists.","Run tersimpan belum dapat dibaca dengan aman. Buka ulang game dan coba lagi. Hubungi bantuan jika masih terjadi.","close"],
  "RECOVERY_REQUIRED":["Previous action needs recovery","Aksi sebelumnya perlu dipulihkan","A previous action has not finished verification. Retry recovery before starting another run.","Verifikasi aksi sebelumnya belum selesai. Coba pemulihan sebelum memulai run lain.","retry"],
  "RUN_STATE_CHANGED":["Run verification changed","Status verifikasi run berubah","The server did not confirm the saved loadout. Retry to recover its current state; do not change accounts unless asked.","Server belum mengonfirmasi loadout tersimpan. Coba kembali untuk memulihkan status terbaru; tidak perlu mengganti akun tanpa petunjuk.","retry"],
  "SAVE_UNAVAILABLE":["Save storage unavailable","Penyimpanan save belum siap","The previous run could not be replaced safely. Free storage and retry.","Run sebelumnya belum dapat diganti dengan aman. Periksa ruang penyimpanan lalu coba kembali.","close"],
  "VERIFICATION_BUSY":["Verification in progress","Verifikasi sedang berjalan","Wait for the current check to finish, then retry.","Tunggu pemeriksaan yang sedang berjalan selesai, lalu coba kembali.","retry"],
  "CONNECTION_UNAVAILABLE":["Connection interrupted","Koneksi terputus","Run verification did not finish. Check the connection and retry with the same account.","Verifikasi run belum selesai. Periksa koneksi lalu coba kembali dengan akun yang sama.","retry"]
 }
 var row: Array=rows.get(code,rows.CONNECTION_UNAVAILABLE)
 var body: String=str(row[3 if id else 2])
 if code=="ACCOUNT_MISMATCH":
  body+="\n\n"+(("Petunjuk akun asal: " if id else "Original account hint: ")+owner_hint if not owner_hint.is_empty() else ("Email akun asal belum tercatat pada perangkat ini." if id else "The original email hint is not recorded on this device."))
 return {"code":code,"title":row[1 if id else 0],"body":body,"action":row[4],"footer":"Save lama tidak diganti oleh verifikasi yang gagal." if id else "A failed verification does not replace the saved run."}
