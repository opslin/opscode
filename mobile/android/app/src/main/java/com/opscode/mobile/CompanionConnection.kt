package com.opscode.mobile

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

/** Keeps the user-approved Mac link active while the notch screen is closed. */
class CompanionConnection : Service() {
    private val main = Handler(Looper.getMainLooper())
    private val overlay by lazy { ApprovalOverlay(this, ::decide) }
    private var target: Link? = null
    private var state: RelayState? = null
    private var watch: AutoCloseable? = null
    private var notificationText: String? = null
    private val screens = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            overlay.screenChanged()
            if (!activityVisible && intent.action != Intent.ACTION_SCREEN_OFF) {
                target?.let { Desktop.sync(this@CompanionConnection, it) }
            }
        }
    }
    private val worker = Executors.newSingleThreadExecutor()

    override fun onCreate() {
        super.onCreate()
        active = this
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(screens, filter, Context.RECEIVER_NOT_EXPORTED)
        else @Suppress("DEPRECATION") registerReceiver(screens, filter)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        overlay.configurationChanged()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val target = Links.read(this)
        if (!enabled(this) || target == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (this.target == target && watch != null) return START_STICKY

        val text = "Connecting to your Mac…"
        notificationText = text
        startForeground(CONNECTION, notification(text))
        watch?.close()
        this.target = target
        state = null
        overlay.clear()
        watch = Desktop.watch(this, target) { update ->
            main.post {
                if (active !== this || this.target != target) return@post
                state = update
                if (update.revoked) {
                    ApprovalAlerts.clearNotification(this)
                    if (!activityVisible) overlay.clear()
                    stopSelf()
                    return@post
                }
                updateNotification(update)
                if (!activityVisible) displayFeed()
            }
        }
        Desktop.sync(this, target)
        return START_STICKY
    }

    private fun notification(text: String): Notification {
        val notifications = getSystemService(NotificationManager::class.java)
        notifications.createNotificationChannel(NotificationChannel(CHANNEL, "Mac connection", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, CONNECTION, Intent(this, NotchActivity::class.java).setAction(OPEN_APPROVAL),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.approval_notification)
            .setContentTitle("Opscode Mac connection")
            .setContentText(text)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .build()
    }

    private fun updateNotification(update: RelayState) {
        val feed = update.feed
        val text = when {
            feed == null -> update.message ?: "Reconnecting to your Mac…"
            feed.needs == 1 -> "1 approval waiting"
            feed.needs > 1 -> "${feed.needs} approvals waiting"
            feed.working == 1 -> "1 task running on your Mac"
            feed.working > 1 -> "${feed.working} tasks running on your Mac"
            else -> "Mac connected"
        }
        if (text == notificationText) return
        notificationText = text
        getSystemService(NotificationManager::class.java).notify(CONNECTION, notification(text))
    }

    private fun displayFeed() {
        val link = target ?: return
        val feed = state?.feed
        if (feed == null) {
            overlay.clear()
            return
        }
        val visible = overlay.update(feed, link.label)
        ApprovalAlerts.update(this, link, feed, compact = visible)
    }

    private fun decide(approval: Approval, allow: Boolean, result: (String?) -> Unit) {
        val link = target ?: return result("The paired Mac is unavailable.")
        worker.execute {
            val error = runCatching { Desktop.decide(applicationContext, link, approval, allow, choice = null) }.exceptionOrNull()
            main.post {
                if (active !== this || target?.token != link.token) return@post
                result(error?.let { (it as? CompanionFailure)?.message ?: "Couldn’t send your decision to the Mac." })
                if (!activityVisible) Desktop.sync(this, link)
            }
        }
    }

    override fun onDestroy() {
        if (active === this) active = null
        unregisterReceiver(screens)
        overlay.clear()
        main.removeCallbacksAndMessages(null)
        watch?.close()
        worker.shutdownNow()
        super.onDestroy()
    }

    companion object {
        private const val CONNECTION = 43
        private const val CHANNEL = "mac-connection"
        private var active: CompanionConnection? = null
        private val visibleActivities = mutableSetOf<Any>()
        @Volatile internal var activityVisible = false
            private set
        internal fun setActivityVisible(owner: Any, visible: Boolean) {
            if (visible) visibleActivities.add(owner) else visibleActivities.remove(owner)
            val nowVisible = visibleActivities.isNotEmpty()
            if (activityVisible == nowVisible) return
            activityVisible = nowVisible
            val service = active ?: return
            if (nowVisible) service.overlay.screenChanged()
            else {
                service.displayFeed()
                service.target?.let { Desktop.sync(service, it) }
            }
        }

        internal fun backgroundStatus(): String = active?.let {
            when {
                it.overlay.lastAttachFailed -> "On · Android couldn’t show the notch"
                it.state?.feed != null -> "On"
                else -> "On · reconnecting"
            }
        } ?: "Starting…"
        private fun prefs(context: Context) = context.getSharedPreferences("mac-connection", Context.MODE_PRIVATE)
        internal fun canNotify(context: Context) = (Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
            context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
        internal fun enabled(context: Context) = prefs(context).getBoolean("enabled", true)
        internal fun setEnabled(context: Context, enabled: Boolean) {
            prefs(context).edit().putBoolean("enabled", enabled).apply()
            if (enabled) start(context) else context.stopService(Intent(context, CompanionConnection::class.java))
        }

        internal fun start(context: Context) {
            if (enabled(context) && activityVisible) {
                try {
                    context.startForegroundService(Intent(context, CompanionConnection::class.java))
                } catch (error: IllegalStateException) {
                    // Android can race an Activity transitioning out of the foreground.
                    // onPostResume retries when the Activity is visible.
                    android.util.Log.w("Opscode", "Android deferred the background connection", error)
                }
            }
        }
    }
}
