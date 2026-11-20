package com.opscode.mobile

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.URI
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal data class Approval(
    val turn: String, val call: String, val tool: String, val summary: String, val detail: String,
    val choices: List<Choice> = emptyList(), val canAllow: Boolean = true, val revision: String = "",
)
internal data class Choice(val id: String, val label: String, val hint: String)
internal data class Session(
    val title: String, val project: String, val engine: String, val status: String, val line: String,
    val approvals: List<Approval> = emptyList(),
)
internal data class Feed(val sessions: List<Session>, val working: Int, val needs: Int, val finished: Int) {
    companion object {
        val empty = Feed(emptyList(), 0, 0, 0)

    }
}

internal const val RELAY_URL = "https://relay.shotlin.in"
internal val relaySecret = Regex("[0-9a-f]{64}")
internal val phoneToken = Regex("[0-9a-f]{32}\\.[0-9a-f]{64}")

internal data class Link(val label: String, val token: String, val key: String) {
    val id: String get() = token.substringBefore('.')
    val route: String get() = "Internet relay"
}

internal data class Invite(val code: String, val key: String, val label: String) {
    companion object {
        fun decode(value: String): Invite {
            try {
                require(value.length <= 1024)
                val uri = URI(value.trim())
                require(uri.scheme == "opscode-pair" && uri.host == "v2" && uri.rawPath == "/connect")
                require(uri.rawUserInfo == null && uri.port == -1 && uri.rawFragment == null)
                val fields = uri.rawQuery.split("&")
                require(fields.size == 3)
                val query = fields.associate {
                    val parts = it.split("=", limit = 2)
                    require(parts.size == 2)
                    parts[0] to java.net.URLDecoder.decode(parts[1], "UTF-8")
                }
                require(query.keys == setOf("code", "key", "label"))
                val code = query.getValue("code")
                val key = query.getValue("key")
                val label = query.getValue("label")
                require(relaySecret.matches(code) && relaySecret.matches(key))
                require(label.isNotBlank() && label.length <= 100 && label.none(Char::isISOControl))
                return Invite(code, key, label)
            } catch (_: Exception) {
                throw CompanionFailure("Scan a new QR in Opscode → Settings → Devices on your Mac.")
            }
        }
    }
}

internal class CompanionFailure(message: String, val status: Int = 0, cause: Throwable? = null) : IOException(message, cause)

internal object Links {
    private const val alias = "opscode.desktop.pairing.v1"
    private const val item = "paired-mac"
    private fun preferences(context: Context) = context.getSharedPreferences("paired-desktop", Context.MODE_PRIVATE)

    fun hasSavedLink(context: Context): Boolean = preferences(context).contains(item)

    @Synchronized
    fun read(context: Context): Link? {
        val encrypted = preferences(context).getString(item, null) ?: return null
        return try {
            val (iv, data) = encrypted.split(".").map { Base64.decode(it, Base64.NO_WRAP) }
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, iv))
            val json = JSONObject(cipher.doFinal(data).toString(Charsets.UTF_8))
            require(json.getInt("version") == 2)
            val token = json.getString("token").also { require(phoneToken.matches(it)) }
            val key = json.getString("key").also { require(relaySecret.matches(it)) }
            Link(json.getString("label"), token, key)
        } catch (_: Exception) {
            null
        }
    }

    @Synchronized
    fun save(context: Context, link: Link) {
        val payload = JSONObject().put("version", 2).put("label", link.label)
            .put("token", link.token).put("key", link.key)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
        val data = Base64.encodeToString(cipher.doFinal(payload.toString().toByteArray(Charsets.UTF_8)), Base64.NO_WRAP)
        check(preferences(context).edit().putString(item, "$iv.$data").commit()) { "Could not save the pairing." }
    }

    @Synchronized
    fun clear(context: Context) {
        check(preferences(context).edit().remove(item).commit())
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build())
        }.generateKey()
    }
}

internal object MobileFeed {
    fun parse(response: JSONObject): Feed {
        val counts = response.getJSONObject("counts")
        return Feed(
            response.getJSONArray("sessions").parse { session ->
                Session(session.getString("title"), session.optString("project"), session.optString("engine"),
                    session.getString("status"), session.optString("line"),
                    session.getJSONArray("approvals").parse { approval ->
                        Approval(approval.getString("turn_id"), approval.getString("call_id"),
                            approval.getString("tool"), approval.getString("summary"), approval.optString("detail"),
                            approval.optJSONArray("choices")?.parse {
                                Choice(it.getString("id"), it.getString("label"), it.optString("hint"))
                            }.orEmpty(), approval.optBoolean("can_allow", false), approval.getString("revision"))
                    })
            }, counts.getInt("working"), counts.getInt("needs"), counts.getInt("unseen"),
        )
    }

    private fun <T> JSONArray.parse(block: (JSONObject) -> T) = List(length()) { block(getJSONObject(it)) }
}
