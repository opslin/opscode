package com.opscode.mobile

import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import java.util.ArrayDeque
import java.util.Locale

/** One local command, against the same foreground window that was open before Quick Settings. */
class PhoneAccessibility : AccessibilityService() {
    internal data class Target(val packageName: String, val windowId: Int)
    private val main = Handler(Looper.getMainLooper())
    private var lastTarget: Target? = null
    private var job = 0

    override fun onServiceConnected() { active = this }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || !unlocked()) return
        val name = event.packageName?.toString() ?: return
        // The two temporary windows involved in invoking a command must not replace its target.
        if (name == packageName || name == "com.android.systemui") return
        lastTarget = Target(name, event.windowId).takeIf { eligible(it) }
    }

    override fun onInterrupt() { job++ }

    override fun onDestroy() {
        job++
        main.removeCallbacksAndMessages(null)
        if (active === this) active = null
        super.onDestroy()
    }

    internal fun target(): Target? = lastTarget?.takeIf { unlocked() }

    internal fun run(target: Target, command: ScreenCommand) {
        val current = ++job
        val deadline = SystemClock.uptimeMillis() + 1_400
        fun waitForScreen() {
            if (job != current || !unlocked() || !eligible(target)) return
            val ready = withTarget(target) { true } == true
            if (!ready) {
                if (SystemClock.uptimeMillis() < deadline) main.postDelayed(::waitForScreen, 80)
                else tell("Open the original app and try again.")
                return
            }
            when (command) {
                ScreenCommand.Back -> if (!performGlobalAction(GLOBAL_ACTION_BACK)) tell("Back is unavailable here.")
                ScreenCommand.Home -> if (!performGlobalAction(GLOBAL_ACTION_HOME)) tell("Home is unavailable here.")
                is ScreenCommand.Playback -> {
                    if (withTarget(target) { clickPlayback(it, command.play) } != true) {
                        tell(if (command.play) "No accessible Play button on this screen." else "No accessible Pause button on this screen.")
                    }
                }
                is ScreenCommand.Scroll -> scroll(target, command, current, 0)
            }
        }
        main.postDelayed(::waitForScreen, 125)
    }

    private fun scroll(target: Target, command: ScreenCommand.Scroll, current: Int, completed: Int) {
        if (job != current || !unlocked()) return
        val moved = withTarget(target) { scrollOnce(it, command.down) } == true
        if (!moved || completed + 1 == command.count) {
            val count = completed + if (moved) 1 else 0
            if (command.count > 1 || count == 0) {
                tell(if (count == 0) "This screen couldn’t scroll in that direction." else "Scrolled $count of ${command.count} times.")
            }
        } else main.postDelayed({ scroll(target, command, current, completed + 1) }, 420)
    }

    private inline fun <T> withTarget(target: Target, action: (AccessibilityNodeInfo) -> T): T? {
        if (!eligible(target) || !unlocked()) return null
        val root = rootInActiveWindow ?: return null
        try {
            if (root.windowId != target.windowId || root.packageName?.toString() != target.packageName || protected(root)) return null
            val focus = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            try { if (focus != null && protected(focus)) return null }
            finally { focus?.release() }
            return action(root)
        } finally { root.release() }
    }

    private fun scrollOnce(root: AccessibilityNodeInfo, down: Boolean): Boolean {
        val direction = if (down) AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_DOWN
            else AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_UP
        val fallback = if (down) AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD
            else AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD
        val bounds = Rect()
        var best: AccessibilityNodeInfo? = null
        var bestScore = 0L
        try {
            visit(root) { node ->
                val actions = node.actionList
                if (direction !in actions && (!node.isScrollable || fallback !in actions)) return@visit
                node.getBoundsInScreen(bounds)
                val area = bounds.width().coerceAtLeast(0).toLong() * bounds.height().coerceAtLeast(0)
                val score = if (direction in actions) area * 2 else area
                if (score > bestScore) {
                    best?.release()
                    @Suppress("DEPRECATION")
                    best = AccessibilityNodeInfo.obtain(node)
                    bestScore = score
                }
            }
            val node = best ?: return false
            return (direction in node.actionList && node.performAction(direction.id)) ||
                (fallback in node.actionList && node.performAction(fallback.id))
        } finally { best?.release() }
    }

    private fun clickPlayback(root: AccessibilityNodeInfo, play: Boolean): Boolean {
        val labels = if (play) setOf("play", "play video", "resume playback")
            else setOf("pause", "pause video", "pause playback")
        var selected: AccessibilityNodeInfo? = null
        var ambiguous = false
        try {
            visit(root) { node ->
                if (!node.isClickable || !node.isEnabled) return@visit
                val label = (node.contentDescription ?: node.text)?.toString()?.trim()?.lowercase(Locale.ROOT)
                if (label !in labels) return@visit
                if (selected != null) ambiguous = true
                else {
                    @Suppress("DEPRECATION")
                    selected = AccessibilityNodeInfo.obtain(node)
                }
            }
            return !ambiguous && selected?.performAction(AccessibilityNodeInfo.ACTION_CLICK) == true
        } finally { selected?.release() }
    }

    @Suppress("DEPRECATION")
    private inline fun visit(root: AccessibilityNodeInfo, block: (AccessibilityNodeInfo) -> Unit) {
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(AccessibilityNodeInfo.obtain(root))
        var discovered = 1
        try {
            while (queue.isNotEmpty()) {
                val node = queue.removeFirst()
                try {
                    if (!node.isVisibleToUser || protected(node) || node.packageName != root.packageName) continue
                    block(node)
                    for (index in 0 until minOf(node.childCount, MAX_NODES - discovered)) {
                        node.getChild(index)?.let { queue.add(it); discovered++ }
                    }
                } finally { node.release() }
            }
        } finally { queue.forEach { it.release() } }
    }

    private fun eligible(target: Target): Boolean =
        target.windowId >= 0 && target.packageName != "android" && target.packageName != packageName &&
            !target.packageName.endsWith(".settings") && !target.packageName.endsWith(".systemui") &&
            !target.packageName.endsWith(".permissioncontroller") && !target.packageName.endsWith(".packageinstaller")

    private fun unlocked(): Boolean = getSystemService(PowerManager::class.java).isInteractive &&
        !getSystemService(KeyguardManager::class.java).isKeyguardLocked

    private fun protected(node: AccessibilityNodeInfo): Boolean = node.isPassword ||
        (Build.VERSION.SDK_INT >= 34 && node.isAccessibilityDataSensitive)

    @Suppress("DEPRECATION")
    private fun AccessibilityNodeInfo.release() { recycle() }

    private fun tell(text: String) { Toast.makeText(this, text, Toast.LENGTH_SHORT).show() }

    companion object {
        private const val MAX_NODES = 250
        internal var active: PhoneAccessibility? = null
            private set
    }
}
