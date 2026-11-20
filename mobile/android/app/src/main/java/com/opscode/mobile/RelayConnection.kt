package com.opscode.mobile

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import okio.ByteString.Companion.toByteString
import org.json.JSONObject
import java.security.SecureRandom
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ExecutionException
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import kotlin.random.Random

internal data class RelayState(
    val feed: Feed? = null, val message: String? = null, val revoked: Boolean = false,
    val workspace: Boolean = false,
)

internal object Desktop {
    private val actor = ScheduledThreadPoolExecutor(1).apply { removeOnCancelPolicy = true }
    private val http = OkHttpClient.Builder()
        .followRedirects(false).followSslRedirects(false)
        .connectTimeout(6, TimeUnit.SECONDS).callTimeout(10, TimeUnit.SECONDS)
        .pingInterval(20, TimeUnit.SECONDS).build()
    private var active: RelayConnection? = null

    @Synchronized
    private fun connection(context: Context, link: Link): RelayConnection {
        active?.takeIf { it.link == link }?.let { return it }
        active?.dispose()
        return RelayConnection(context.applicationContext, link, actor, http).also { active = it }
    }

    fun watch(context: Context, link: Link, listener: (RelayState) -> Unit): AutoCloseable =
        connection(context, link).watch(listener)

    fun sync(context: Context, link: Link) = connection(context, link).sync()
    fun watchWorkspace(context: Context, link: Link, onChange: () -> Unit): AutoCloseable =
        connection(context, link).watchWorkspace(onChange)
    fun workspace(context: Context, link: Link, body: JSONObject): JSONObject =
        connection(context, link).call("workspace", body).awaitReply(if (body.optString("op") == "voice.start") 35 else 8)
    fun refresh(context: Context, link: Link): Feed = connection(context, link).snapshot().awaitReply()

    fun pair(invite: Invite): Link {
        val request = request("/v1/pair", invite.code).post(ByteArray(0).toRequestBody()).build()
        val response = try { http.newCall(request).execute() }
        catch (error: java.io.IOException) { throw CompanionFailure("Can’t reach the Opscode relay. Try again when online.", cause = error) }
        response.use {
            if (it.code != 201) throw CompanionFailure(when (it.code) {
                401 -> "This QR expired or was already used. Open a new one on the Mac."
                409 -> "Remove a device on the Mac before pairing another phone."
                429 -> "Too many pairing attempts. Wait a moment and try again."
                else -> "Pairing couldn’t reach the Opscode relay. Try again."
            }, it.code)
            val reply = JSONObject(it.body?.string() ?: throw CompanionFailure("Empty pairing response."))
            val token = reply.getString("token")
            if (!phoneToken.matches(token) || token.substringBefore('.') != reply.getString("device_id")) {
                throw CompanionFailure("The relay returned an invalid pairing response.")
            }
            return Link(invite.label, token, invite.key)
        }
    }

    fun decide(context: Context, link: Link, approval: Approval, allow: Boolean, choice: String?) {
        val body = JSONObject().put("turn_id", approval.turn).put("call_id", approval.call)
            .put("allow", allow).put("revision", approval.revision)
        choice?.let { body.put("choice", it) }
        connection(context, link).call("decision", body).awaitReply()
    }

    fun registerPush(context: Context, link: Link, token: String) {
        if (token.isNotBlank() && Links.read(context) == link) connection(context, link).registerPush(token)
    }

    fun disconnect(link: Link) {
        val response = try { http.newCall(request("/v1/device", link.token).delete().build()).execute() }
        catch (error: java.io.IOException) { throw CompanionFailure("Can’t reach the relay to revoke this phone.", cause = error) }
        response.use {
            if (it.code != 200 && it.code != 401) throw CompanionFailure("The relay couldn’t revoke this phone. Try again.", it.code)
        }
        synchronized(this) {
            if (active?.link == link) {
                active?.dispose()
                active = null
            }
        }
    }

    private fun request(path: String, token: String): Request.Builder = Request.Builder()
        .url(RELAY_URL + path).header("Authorization", "Bearer $token").header("Cache-Control", "no-store")
}

private fun <T> CompletableFuture<T>.awaitReply(seconds: Long = 8): T = try {
    get(seconds, TimeUnit.SECONDS)
} catch (error: ExecutionException) {
    throw error.cause as? CompanionFailure ?: CompanionFailure("The Mac couldn’t complete the request.", cause = error)
} catch (error: TimeoutException) {
    cancel(false)
    throw CompanionFailure("The Mac didn’t respond in time. It will reconnect automatically.", cause = error)
}

internal object RelayEnvelope {
    private val random = SecureRandom()
    private const val LIMIT = 65_536
    fun challenge(): String = ByteArray(16).apply(random::nextBytes).joinToString("") { "%02x".format(it) }

    private fun cipher(mode: Int, key: String, id: String, from: String, nonce: ByteArray): Cipher =
        Cipher.getInstance("AES/GCM/NoPadding").apply {
            val bytes = key.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
            init(mode, SecretKeySpec(bytes, "AES"), GCMParameterSpec(128, nonce))
            updateAAD("opscode.mobile.v1|$from|$id".toByteArray(Charsets.UTF_8))
        }

    fun seal(link: Link, message: JSONObject): ByteString {
        val nonce = ByteArray(12).apply(random::nextBytes)
        val encrypted = cipher(Cipher.ENCRYPT_MODE, link.key, link.id, "phone", nonce)
            .doFinal(message.toString().toByteArray(Charsets.UTF_8))
        require(nonce.size + encrypted.size <= LIMIT)
        return (nonce + encrypted).toByteString()
    }

    fun open(link: Link, message: ByteString): JSONObject {
        require(message.size in 29..LIMIT)
        val bytes = message.toByteArray()
        val plain = cipher(Cipher.DECRYPT_MODE, link.key, link.id, "mac", bytes.copyOfRange(0, 12))
            .doFinal(bytes, 12, bytes.size - 12)
        return JSONObject(plain.toString(Charsets.UTF_8))
    }
}

/** One socket per saved pairing shared by the screen, service and push handler. All mutable state lives on the actor. */
private class RelayConnection(
    context: Context,
    val link: Link,
    private val actor: ScheduledThreadPoolExecutor,
    private val http: OkHttpClient,
) {
    private val manager = context.getSystemService(ConnectivityManager::class.java)
    private var networkWatch = false
    private var network: Network? = null
    private var networkValidated = false
    private val networkListener = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) { actor.execute {
            if (!networkWatch || disposed || this@RelayConnection.network == network) return@execute
            this@RelayConnection.network = network
            networkValidated = false
            transportChanged()
        } }
        override fun onLost(network: Network) { actor.execute {
            if (!networkWatch || disposed || this@RelayConnection.network != network) return@execute
            this@RelayConnection.network = manager.activeNetwork?.takeIf { it != network }
            networkValidated = false
            transportChanged()
        } }
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            val validated = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            actor.execute {
                if (!networkWatch || disposed || this@RelayConnection.network != network) return@execute
                val recovered = validated && !networkValidated
                networkValidated = validated
                if (!recovered) return@execute
                if (socket == null) {
                    retry?.cancel(false)
                    retry = null
                    attempt = 0
                    open()
                } else if (session != null) requestFeed()
            }
        }
    }
    private val observers = mutableSetOf<(RelayState) -> Unit>()
    private val workspaceObservers = mutableSetOf<() -> Unit>()
    private val feeds = mutableSetOf<CompletableFuture<Feed>>()
    private data class Pending(val type: String, val reply: CompletableFuture<JSONObject>)
    private val requests = mutableMapOf<Long, Pending>()
    private var socket: WebSocket? = null
    private var socketTimer: ScheduledFuture<*>? = null
    private var retry: ScheduledFuture<*>? = null
    private var idle: ScheduledFuture<*>? = null
    private var syncTimer: ScheduledFuture<*>? = null
    private var attempt = 0
    private var macOnline = false
    private var challenge: String? = null
    private var session: String? = null
    private var workspace = false
    private var sentSeq = 0L
    private var receivedVersion = 0L
    private var desiredPush: String? = null
    private var sentPush: String? = null
    private var disposed = false
    private var state = RelayState(message = "Connecting to your Mac…")

    fun watch(listener: (RelayState) -> Unit): AutoCloseable {
        actor.execute {
            if (disposed) return@execute
            observers.add(listener)
            listener(state)
            activate()
        }
        return AutoCloseable {
            actor.execute {
                observers.remove(listener)
                scheduleIdle()
            }
        }
    }

    fun sync() { actor.execute {
        activate()
        requestFeed()
    } }

    fun watchWorkspace(onChange: () -> Unit): AutoCloseable {
        actor.execute { if (!disposed) workspaceObservers.add(onChange) }
        return AutoCloseable { actor.execute { workspaceObservers.remove(onChange) } }
    }

    fun snapshot(): CompletableFuture<Feed> {
        val answer = CompletableFuture<Feed>()
        actor.execute {
            if (disposed || state.revoked) {
                answer.completeExceptionally(revokedError())
                return@execute
            }
            feeds.add(answer)
            actor.schedule({
                if (feeds.remove(answer)) answer.completeExceptionally(unavailable())
                scheduleIdle()
            }, 7, TimeUnit.SECONDS)
            activate()
            requestFeed()
        }
        return answer
    }

    fun call(type: String, body: JSONObject): CompletableFuture<JSONObject> {
        val answer = CompletableFuture<JSONObject>()
        actor.execute {
            if (disposed || state.revoked) {
                answer.completeExceptionally(revokedError())
                return@execute
            }
            if (type == "workspace" && session != null && !workspace) {
                answer.completeExceptionally(CompanionFailure("Update Opscode on your Mac to use Projects."))
                return@execute
            }
            val seq = if (state.feed != null) send(type, body) else null
            if (seq == null) {
                answer.completeExceptionally(unavailable())
                return@execute
            }
            requests[seq] = Pending(type, answer)
            actor.schedule({
                requests.remove(seq)?.reply?.completeExceptionally(CompanionFailure("The Mac didn’t confirm the action. Check the latest activity."))
                scheduleIdle()
            }, if (type == "workspace" && body.optString("op") == "voice.start") 34 else 7, TimeUnit.SECONDS)
        }
        return answer
    }

    fun registerPush(token: String) { actor.execute {
        desiredPush = token
        activate()
        pushIfReady()
        scheduleIdle()
    } }

    fun dispose() { actor.execute {
        disposed = true
        observers.clear()
        workspaceObservers.clear()
        disconnectTransport()
        completeFeeds(revokedError())
        stopNetworkWatch()
    } }

    private fun activate() {
        if (disposed || state.revoked) return
        idle?.cancel(false)
        idle = null
        if (!networkWatch) {
            network = manager.activeNetwork
            networkValidated = false
            manager.registerDefaultNetworkCallback(networkListener)
            networkWatch = true
        }
        if (socket == null && retry == null) {
            if (network == null) report(RelayState(message = "Waiting for internet…"))
            else open()
        }
    }

    private fun transportChanged() {
        disconnectTransport()
        if (network == null) report(RelayState(message = "Waiting for internet…"))
        else {
            attempt = 0
            report(RelayState(message = "Reconnecting to your Mac…"))
            open()
        }
    }

    private fun open() {
        if (disposed || state.revoked || socket != null) return
        val req = Request.Builder().url(RELAY_URL.replace("https:", "wss:") + "/v1/socket/phone")
            .header("Authorization", "Bearer " + link.token).build()
        val listener = object : WebSocketListener() {
            override fun onMessage(webSocket: WebSocket, text: String) = enqueue(webSocket) {
                runCatching { relayEvent(JSONObject(text)) }
            }
            override fun onMessage(webSocket: WebSocket, bytes: ByteString) = enqueue(webSocket) {
                runCatching { receive(RelayEnvelope.open(link, bytes)) }
            }
            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) = enqueue(webSocket) {
                webSocket.close(code, null)
                disconnected(code == 4003, if (code == 4029) 10_000 else 0)
            }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                val status = response?.code
                val throttle = response?.header("Retry-After")?.toLongOrNull()?.coerceIn(1, 60) ?: 10
                response?.close()
                enqueue(webSocket) { disconnected(status == 401, if (status == 429) throttle * 1000 else 0) }
            }
        }
        socket = http.newWebSocket(req, listener)
        socketTimer = actor.schedule({ disconnected(false) }, 9, TimeUnit.SECONDS)
    }

    private fun enqueue(expected: WebSocket, action: () -> Unit) {
        actor.execute { if (!disposed && socket === expected) action() }
    }

    private fun relayEvent(message: JSONObject) {
        when (message.optString("type")) {
            "relay.ready" -> {
                if (message.optInt("protocol") != 1) return
                socketTimer?.cancel(false)
                socketTimer = null
                attempt = 0
                setMacOnline(message.optBoolean("mac_online"))
            }
            "relay.presence" -> if (message.optString("peer") == "mac") {
                if (message.optBoolean("online")) clearSession()
                setMacOnline(message.optBoolean("online"))
            }
            "relay.unavailable" -> setMacOnline(false)
        }
    }

    private fun setMacOnline(online: Boolean) {
        macOnline = online
        if (online) {
            if (challenge == null && session == null) {
                report(RelayState(message = "Syncing Mac activity…"))
                val nonce = RelayEnvelope.challenge()
                challenge = nonce
                val name = "${Build.MANUFACTURER} ${Build.MODEL}".filterNot(Char::isISOControl).trim().take(100)
                if (!write(JSONObject().put("type", "hello").put("challenge", nonce).put("name", name.ifEmpty { "Android phone" }))) {
                    disconnected(false)
                } else expectFeed()
            }
        } else {
            clearSession()
            report(RelayState(message = "Mac offline. Reconnecting when Opscode is available."))
            completeFeeds(unavailable())
        }
    }

    private fun receive(message: JSONObject) {
        if (message.optString("type") == "welcome") {
            val nonce = challenge ?: return
            val id = message.optString("session")
            if (nonce != message.optString("challenge") || !id.matches(Regex("[0-9a-f]{32}"))) return
            challenge = null
            session = id
            workspace = message.optBoolean("workspace")
            sentSeq = 0
            receivedVersion = 0
            pushIfReady()
            return
        }
        val current = session ?: return
        if (message.optString("session") != current) return
        when (message.optString("type")) {
            "feed" -> {
                val version = message.optLong("version")
                if (version <= receivedVersion) return
                val newFeed = message.optJSONObject("feed")?.let(MobileFeed::parse)
                receivedVersion = version
                syncTimer?.cancel(false)
                syncTimer = null
                report(if (newFeed != null) RelayState(feed = newFeed, workspace = workspace)
                    else RelayState(message = "Opscode is starting on your Mac…"))
                if (newFeed != null) {
                    feeds.forEach { it.complete(newFeed) }
                    feeds.clear()
                    scheduleIdle()
                }
            }
            "workspace.changed" -> workspaceObservers.forEach { it() }
            "workspace.result" -> {
                val seq = message.optLong("seq")
                val pending = requests[seq]?.takeIf { it.type == "workspace" } ?: return
                requests.remove(seq)
                val value = message.optJSONObject("data")
                if (value != null) pending.reply.complete(value)
                else pending.reply.completeExceptionally(CompanionFailure(message.optString("error", "The Mac couldn’t complete the action.")))
                scheduleIdle()
            }
            "result" -> {
                val seq = message.optLong("seq")
                val pending = requests[seq]?.takeIf { it.type == "decision" } ?: return
                requests.remove(seq)
                pending.reply.let { reply ->
                    when (message.optInt("status")) {
                        200 -> reply.complete(JSONObject())
                        409 -> reply.completeExceptionally(CompanionFailure("That approval changed or was already answered.", 409))
                        else -> reply.completeExceptionally(CompanionFailure("Couldn’t send the decision to your Mac."))
                    }
                    scheduleIdle()
                }
            }
        }
    }

    private fun requestFeed() {
        if (send("sync") != null) expectFeed()
    }

    private fun expectFeed() {
        if (syncTimer == null) syncTimer = actor.schedule({
            syncTimer = null
            if (macOnline) disconnected(false)
        }, 5, TimeUnit.SECONDS)
    }

    private fun pushIfReady() {
        val token = desiredPush ?: return
        if (sentPush != token && send("push", JSONObject().put("token", token)) != null) sentPush = token
    }

    private fun send(type: String, body: JSONObject? = null): Long? {
        val current = session ?: return null
        val seq = ++sentSeq
        val message = JSONObject().put("type", type).put("session", current).put("seq", seq)
        if (body != null) message.put("body", body)
        return seq.takeIf { write(message) }
    }

    private fun write(message: JSONObject): Boolean {
        val ws = socket ?: return false
        return ws.send(RelayEnvelope.seal(link, message))
    }

    private fun disconnected(revoked: Boolean, minimumDelay: Long = 0) {
        disconnectTransport()
        if (revoked) {
            report(RelayState(message = revokedError().message, revoked = true))
            completeFeeds(revokedError())
            stopNetworkWatch()
            return
        }
        report(RelayState(message = if (network == null) "Waiting for internet…" else "Reconnecting to your Mac…"))
        if (network != null && (!disposed && (observers.isNotEmpty() || feeds.isNotEmpty() || idle != null))) {
            val backoff = minOf(12_000L, 500L shl minOf(attempt++, 5))
            retry = actor.schedule({
                retry = null
                open()
            }, maxOf(minimumDelay, (backoff * Random.nextDouble(.8, 1.2)).toLong()), TimeUnit.MILLISECONDS)
        }
    }

    private fun clearSession() {
        challenge = null
        session = null
        workspace = false
        sentPush = null
        syncTimer?.cancel(false)
        syncTimer = null
        requests.values.forEach { it.reply.completeExceptionally(unavailable()) }
        requests.clear()
    }

    private fun disconnectTransport() {
        val old = socket
        socket = null
        old?.cancel()
        macOnline = false
        clearSession()
        retry?.cancel(false)
        retry = null
        socketTimer?.cancel(false)
        socketTimer = null
    }

    private fun scheduleIdle() {
        if (disposed || observers.isNotEmpty() || requests.isNotEmpty() || feeds.isNotEmpty() || idle != null) return
        idle = actor.schedule({
            idle = null
            if (observers.isEmpty() && requests.isEmpty() && feeds.isEmpty()) {
                disconnectTransport()
                stopNetworkWatch()
                if (!state.revoked) report(RelayState(message = "Connecting to your Mac…"))
            }
        }, 10, TimeUnit.SECONDS)
    }

    private fun stopNetworkWatch() {
        if (networkWatch) {
            networkWatch = false
            manager.unregisterNetworkCallback(networkListener)
        }
    }

    private fun completeFeeds(error: CompanionFailure) {
        feeds.forEach { it.completeExceptionally(error) }
        feeds.clear()
        scheduleIdle()
    }

    private fun report(value: RelayState) {
        if (state == value) return
        state = value
        observers.forEach { it(value) }
    }

    private fun revokedError() = CompanionFailure("This phone’s access was revoked. Pair again from your Mac.", 401)
    private fun unavailable() = CompanionFailure("The Mac is unavailable. Opscode will reconnect automatically.", 503)
}
