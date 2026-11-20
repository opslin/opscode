package com.opscode.mobile

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlin.concurrent.thread

internal const val OPEN_APPROVAL = "com.opscode.mobile.OPEN_APPROVAL"
private const val APPROVAL_CHANNEL = "desktop-approvals"
private const val VIBRATING_APPROVAL_CHANNEL = "desktop-approvals-vibration"
internal const val APPROVAL_NOTIFICATION = 41
internal const val PREVIEW_NOTIFICATION = 42
internal const val OPEN_PREVIEW = "com.opscode.mobile.OPEN_PREVIEW"

class ApprovalPush : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (message.data["kind"] != "approval") return
        val link = Links.read(this) ?: return
        runCatching { Desktop.refresh(this, link) }
            .onSuccess { ApprovalAlerts.update(this, link, it) }
            .onFailure {
                if ((it as? CompanionFailure)?.status == 401) ApprovalAlerts.clearNotification(this)
                else ApprovalAlerts.signal(this)
            }
    }

    override fun onNewToken(token: String) {
        Links.read(this)?.let { link -> runCatching { Desktop.registerPush(this, link, token) } }
    }
}

internal fun postApprovalNotification(context: Context, preview: Boolean, compact: Boolean = false) {
    if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
    val notifications = context.getSystemService(NotificationManager::class.java)
    val channel = approvalChannel(context, compact)
    val id = if (preview) PREVIEW_NOTIFICATION else APPROVAL_NOTIFICATION
    val review = PendingIntent.getActivity(context, id,
        Intent(context, NotchActivity::class.java).setAction(if (preview) OPEN_PREVIEW else OPEN_APPROVAL),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    val action = Notification.Action.Builder(null, "Review", review).apply {
        if (Build.VERSION.SDK_INT >= 31) setAuthenticationRequired(true)
    }.build()
    val alert = Notification.Builder(context, channel)
        .setSmallIcon(R.drawable.approval_notification)
        .setContentTitle(if (preview) "Opscode test notification" else "Opscode needs your approval")
        .setContentText(if (preview) "Notifications are working on this phone." else "Unlock to review a request from your Mac.")
        .setVisibility(Notification.VISIBILITY_PUBLIC)
        .setCategory(Notification.CATEGORY_STATUS)
        .setContentIntent(review)
        .addAction(action)
        .setAutoCancel(true)
        .build()
    notifications.notify(id, alert)
}

internal fun registerNotifications(context: Context, link: Link) {
    if (FirebaseApp.getApps(context).isEmpty()) return
    FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
        thread(name = "Opscode push registration") { runCatching { Desktop.registerPush(context, link, token) } }
    }
}

internal fun vibratingApprovals(context: Context): Boolean {
    val manager = context.getSystemService(NotificationManager::class.java)
    return context.getSharedPreferences("alert-options", Context.MODE_PRIVATE)
        .getBoolean("vibrate", manager.getNotificationChannel(APPROVAL_CHANNEL) == null)
}

internal fun setVibratingApprovals(context: Context, enabled: Boolean) {
    context.getSharedPreferences("alert-options", Context.MODE_PRIVATE).edit().putBoolean("vibrate", enabled).apply()
}

internal fun approvalChannel(context: Context, compact: Boolean = false): String {
    val vibrate = vibratingApprovals(context)
    val id = if (vibrate) VIBRATING_APPROVAL_CHANNEL else APPROVAL_CHANNEL
    val manager = context.getSystemService(NotificationManager::class.java)
    manager.createNotificationChannel(NotificationChannel(id,
        if (vibrate) "Mac approvals with vibration" else "Mac approvals", NotificationManager.IMPORTANCE_HIGH).apply {
        if (vibrate) vibrationPattern = longArrayOf(0, 160, 100, 240)
    })
    if (!compact) return id
    val primary = manager.getNotificationChannel(id) ?: return id
    if (primary.importance <= NotificationManager.IMPORTANCE_DEFAULT) return id
    // A heads-up banner would cover the unlocked notch. Keep the tray alert and its vibration.
    val compactId = "$id-notch"
    manager.createNotificationChannel(NotificationChannel(compactId,
        if (vibrate) "Notch approvals with vibration" else "Notch approvals", NotificationManager.IMPORTANCE_DEFAULT).apply {
        setSound(primary.sound, primary.audioAttributes)
        if (primary.shouldVibrate()) {
            primary.vibrationPattern?.let { vibrationPattern = it } ?: enableVibration(true)
        }
    })
    return compactId
}

/** The socket, the open notch and optional push share the same notification revision state. */
internal object ApprovalAlerts {
    private var token: String? = null
    private var pending = emptySet<String>()
    private var lastAlertAt: Long? = null
    private var lastCompact: Boolean? = null

    @Synchronized
    fun update(context: Context, link: Link, feed: Feed, compact: Boolean = false) {
        if (token != link.token) {
            token = link.token
            pending = emptySet()
            lastAlertAt = null
            lastCompact = null
        }
        val next = feed.sessions.flatMap { it.approvals }.map { it.revision }.toSet()
        val hasNew = next.any { it !in pending }
        pending = next
        if (next.isEmpty()) {
            clearNotification(context)
            lastCompact = null
        } else if (hasNew || lastCompact == null) signal(context, compact)
        else if (lastCompact == true && !compact) {
            clearNotification(context)
            postApprovalNotification(context, preview = false)
            lastCompact = false
        }
    }

    @Synchronized
    fun signal(context: Context, compact: Boolean = false) {
        val now = android.os.SystemClock.elapsedRealtime()
        if (lastAlertAt?.let { now - it < 2_000 } == true) return
        postApprovalNotification(context, preview = false, compact = compact)
        lastAlertAt = now
        lastCompact = compact
    }

    fun clearNotification(context: Context) {
        context.getSystemService(NotificationManager::class.java).cancel(APPROVAL_NOTIFICATION)
    }
}
