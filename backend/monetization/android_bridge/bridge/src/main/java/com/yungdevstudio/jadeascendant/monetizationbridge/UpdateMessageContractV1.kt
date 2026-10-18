package com.yungdevstudio.jadeascendant.monetizationbridge

internal object UpdateMessageContractV1 {
    const val TOPIC = "jade_release_updates_v1"
    const val CHANNEL = "jade_game_updates_v1"
    const val PACKAGE = "com.yungdevstudio.jadeascendant"
    data class Notice(val id: String, val versionCode: Long, val title: String, val body: String)
    fun parse(data: Map<String, String>, installed: Long, highestShown: Long, time: Long): Notice? {
        if (data.keys != setOf("kind", "campaign_id", "version_code", "title", "body", "expires_at")) return null
        if (data["kind"] != "app_update" || !Regex("^[a-f0-9]{32}$").matches(data["campaign_id"] ?: "")) return null
        val version = data["version_code"]?.takeIf { Regex("^[1-9][0-9]{0,8}$").matches(it) }?.toLongOrNull() ?: return null
        val expires = data["expires_at"]?.toLongOrNull() ?: return null
        if (version <= installed || version <= highestShown || expires <= time || expires > time + 8 * 86400) return null
        val title = data["title"]?.takeIf { it.isNotBlank() && it.length <= 80 && it.none { c -> c.code < 32 || c.code == 127 } } ?: return null
        val body = data["body"]?.takeIf { it.isNotBlank() && it.length <= 240 && it.none { c -> c.code < 32 || c.code == 127 } } ?: return null
        return Notice(data.getValue("campaign_id"), version, title, body)
    }
}
