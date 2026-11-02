package com.yungdevstudio.jadeascendant.monetizationbridge

import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import androidx.core.content.FileProvider
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/** Cosmetic PNG export only. No account, rewards, purchases or network access. */
internal object RunCardExportV1 {
    private val io = Executors.newSingleThreadExecutor()
    private val callbacks = ConcurrentHashMap<String, (Boolean, String) -> Unit>()
    fun export(activity: Activity?, id: String, path: String, share: Boolean, reply: (Boolean, String) -> Unit) {
        if (activity == null || !Regex("^[a-f0-9]{32}$").matches(id)) { reply(false,"EXPORT_UNAVAILABLE"); return }
        io.execute {
            try {
                val input = File(path).canonicalFile
                val roots = listOf(activity.filesDir.canonicalFile,activity.cacheDir.canonicalFile)
                require(roots.any { input.path.startsWith(it.path + File.separator) })
                require(input.isFile && input.name.startsWith("jade-run-") && input.extension == "png" && input.length() in 33..16_777_216)
                val bounds = BitmapFactory.Options().also { it.inJustDecodeBounds = true }
                BitmapFactory.decodeFile(input.path,bounds)
                require(bounds.outWidth == 1080 && bounds.outHeight in listOf(1350,1920) && bounds.outMimeType == "image/png")
                val folder = File(activity.cacheDir,"jade_run_cards").apply { mkdirs() }
                // Bound old cache; no unbounded private files from repeated share attempts.
                folder.listFiles()?.filter { it.isFile }?.sortedByDescending { it.lastModified() }?.drop(7)?.forEach { it.delete() }
                val cached = File(folder,"jade-run-${bounds.outHeight}-$id.png")
                input.copyTo(cached,true)
                activity.runOnUiThread {
                    try {
                        if (share) {
                            val uri = FileProvider.getUriForFile(activity,activity.packageName+".jade_run_cards",cached)
                            val intent = Intent(Intent.ACTION_SEND).setType("image/png")
                                .putExtra(Intent.EXTRA_STREAM,uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            intent.clipData = android.content.ClipData.newRawUri("Jade Ascendant",uri)
                            activity.startActivity(Intent.createChooser(intent,"Jade Ascendant"))
                            reply(true,"SHARE_CHOOSER_OPENED") // Never asserts that another app sent it.
                        } else {
                            callbacks[id] = reply
                            activity.startActivity(Intent(activity,JadeRunCardSaveActivity::class.java)
                                .putExtra("request",id).putExtra("path",cached.path))
                        }
                    } catch (_: Exception) { callbacks.remove(id); reply(false,"EXPORT_UNAVAILABLE") }
                }
            } catch (_: Exception) { reply(false,"PNG_EXPORT_FAILED") }
        }
    }
    fun complete(id: String, success: Boolean, code: String) { callbacks.remove(id)?.invoke(success,code) }
    fun copy(activity: Activity, id: String, path: String, uri: Uri) {
        io.execute {
            var success = false
            try {
                activity.contentResolver.openOutputStream(uri,"w").use { output ->
                    requireNotNull(output)
                    File(path).inputStream().use { input -> input.copyTo(output) }
                    output.flush()
                }
                success = true
            } catch (_: Exception) { /* Honest failure; never marks the card as saved. */ }
            complete(id,success,if(success) "PNG_SAVED" else "PNG_EXPORT_FAILED")
            activity.runOnUiThread { activity.finish() }
        }
    }
}

/** Own provider type prevents manifest merging with another library's FileProvider. */
class JadeRunCardProvider : FileProvider()

/** Storage Access Framework works at minSdk 24 without broad storage permissions. */
class JadeRunCardSaveActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        if (state != null) return
        try {
            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                .setType("image/png").putExtra(Intent.EXTRA_TITLE,"Jade-Ascendant-${System.currentTimeMillis()}.png"),701)
        } catch (_: Exception) {
            RunCardExportV1.complete(intent.getStringExtra("request") ?: "",false,"EXPORT_UNAVAILABLE"); finish()
        }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if (requestCode != 701) return
        val id = intent.getStringExtra("request") ?: ""
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            RunCardExportV1.complete(id,false,"SAVE_CANCELLED"); finish(); return
        }
        RunCardExportV1.copy(this,id,intent.getStringExtra("path") ?: "",uri)
    }
}
