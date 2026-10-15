package com.yungdevstudio.jadeascendant.monetizationbridge

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Retry evidence only. Never grants currency or stores Firebase/App Check tokens.
 * noBackupFilesDir prevents restored ciphertext without its device Keystore key.
 * Any corrupt/unreadable record fails closed and is retained for diagnosis.
 */
internal class PendingPaidPurchaseStore(context: Context) {
    private val root = File(context.noBackupFilesDir, "jade-pending-paid-v2")
    private val alias = "jade-paid-purchase-journal-v2"
    private fun hash(value: String) = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    private fun folder(uid: String) = File(root, hash(uid))
    private fun file(uid: String, token: String) = AtomicFile(File(folder(uid), hash(token) + ".bin"))
    @Synchronized private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).build())
        }.generateKey()
    }
    private fun aad(uid: String) = ("jade-paid-v2:" + hash(uid)).toByteArray(Charsets.UTF_8)
    @Synchronized fun save(uid: String, product: String, token: String) {
        require(PendingPaidPurchaseRecord.valid(uid, product, token))
        val target = file(uid, token)
        if (target.baseFile.exists() || File(target.baseFile.path + ".bak").exists()) {
            val old = decode(uid, target)
            require(old.product == product && old.token == token)
            return
        }
        val dir = folder(uid)
        check(dir.isDirectory || dir.mkdirs())
        check((dir.listFiles { f -> f.name.endsWith(".bin") }?.size ?: 0) < 32)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key()); cipher.updateAAD(aad(uid))
        val raw = JSONObject().put("version", 2).put("owner", hash(uid)).put("product", product).put("token", token)
            .toString().toByteArray(Charsets.UTF_8)
        val encrypted = cipher.doFinal(raw)
        val output = target.startWrite()
        try {
            output.write(byteArrayOf(2, cipher.iv.size.toByte())); output.write(cipher.iv); output.write(encrypted)
            target.finishWrite(output) // AtomicFile flushes and syncs before network dispatch.
        } catch (e: Exception) { target.failWrite(output); throw e }
        check(decode(uid, target) == PendingPaidPurchaseRecord(product, token))
    }
    private fun decode(uid: String, target: AtomicFile): PendingPaidPurchaseRecord {
        val bytes = target.openRead().use { input ->
            val output = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(1024)
            while (true) {
                val count = input.read(buffer); if (count < 0) break
                require(output.size() + count <= 16_384); output.write(buffer, 0, count)
            }
            output.toByteArray().also { require(it.size >= 32) }
        }
        require(bytes[0] == 2.toByte() && bytes[1] == 12.toByte())
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(2, 14)))
        cipher.updateAAD(aad(uid))
        val value = JSONObject(String(cipher.doFinal(bytes.copyOfRange(14, bytes.size)), Charsets.UTF_8))
        require(value.keys().asSequence().toSet() == setOf("version", "owner", "product", "token"))
        require(value.getInt("version") == 2 && value.getString("owner") == hash(uid))
        val product = value.getString("product"); val token = value.getString("token")
        require(PendingPaidPurchaseRecord.valid(uid, product, token))
        require(target.baseFile.name == hash(token) + ".bin")
        return PendingPaidPurchaseRecord(product, token)
    }
    @Synchronized fun first(uid: String): PendingPaidPurchaseRecord? {
        // AtomicFile may leave .bak after process death. Re-open its base to recover.
        val names = folder(uid).listFiles()?.map { it.name.removeSuffix(".bak") }
            ?.filter { it.endsWith(".bin") }?.distinct()?.sorted() ?: return null
        require(names.size <= 32)
        return names.firstOrNull()?.let { decode(uid, AtomicFile(File(folder(uid), it))) }
    }
    @Synchronized fun removeConfirmed(uid: String, product: String, token: String) {
        val target = file(uid, token)
        check(decode(uid, target) == PendingPaidPurchaseRecord(product, token))
        target.delete()
    }
}
