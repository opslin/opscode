package com.opscode.mobile

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.ScrollView
import androidx.core.view.doOnPreDraw
import kotlin.math.ceil
import kotlin.math.roundToInt

/** This window uses the same artwork and review cards as the in-app notch. */
internal class ApprovalOverlay(
    private val context: Context,
    private val onDecision: (Approval, Boolean, (String?) -> Unit) -> Unit,
) {
    private class Window(
        val manager: WindowManager,
        val view: NotchStage,
        val params: WindowManager.LayoutParams,
        val views: NotchViews,
        val content: LinearLayout,
        val displayWidth: Int,
        val safeTop: Int,
        val leftInset: Int,
        val rightInset: Int,
        val camera: CutoutGeometry?,
    )

    private val main = Handler(Looper.getMainLooper())
    private val dismissFailure = Runnable {
        suppressedFailures = failures
        update(lastFeed, mac)
    }
    private var window: Window? = null
    private var lastFeed = Feed.empty
    private var mac = ""
    private var pose: Pose? = null
    private var expanded = false
    private var settling = false
    private var pendingDecision: Approval? = null
    private var decisionError: String? = null
    private var suppressedFailures = emptySet<Pair<String, String>>()
    private val failures get() = lastFeed.sessions
        .filter { it.status == "failed" }.map { it.project to it.title }.toSet()
    private var approvalCount = 0

    var lastAttachFailed = false
        private set

    fun update(feed: Feed, label: String): Boolean {
        val changed = feed != lastFeed || label != mac
        lastFeed = feed
        mac = label
        val currentFailures = failures
        if (currentFailures.isEmpty()) suppressedFailures = emptySet()
        approvalCount = feed.sessions.sumOf { it.approvals.size }
        val next = when {
            approvalCount > 0 -> Pose.NEEDS
            currentFailures.any { it !in suppressedFailures } -> Pose.ERROR
            feed.working > 0 -> Pose.WORKING
            else -> null
        }
        if (pose != next) {
            pose = next
            decisionError = null
            scheduleFailureDismissal()
        }

        if (!canShow()) hide()
        else if (next == null) closeIdle()
        else {
            if (window == null) attach()
            window?.let {
                it.view.status(next, approvalCount, feed.working, 0, description())
                if (expanded && changed) renderPanel(it)
            }
        }
        return window != null && next != null
    }

    fun clear() {
        lastFeed = Feed.empty
        pose = null
        approvalCount = 0
        suppressedFailures = emptySet()
        pendingDecision = null
        decisionError = null
        lastAttachFailed = false
        hide()
    }

    fun screenChanged() {
        if (!canShow()) hide()
        else update(lastFeed, mac)
    }

    fun configurationChanged() {
        hide()
        screenChanged()
    }

    private fun attach() {
        val display = context.getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY) ?: return
        val screen = context.createDisplayContext(display)
        val visual = if (Build.VERSION.SDK_INT >= 30) screen.createWindowContext(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, null) else screen
        val manager = visual.getSystemService(WindowManager::class.java)
        val views = NotchViews(visual)
        val density = visual.resources.displayMetrics.density
        val metrics = if (Build.VERSION.SDK_INT >= 30) manager.currentWindowMetrics else null
        val width = if (Build.VERSION.SDK_INT >= 30 && metrics != null) metrics.bounds.width()
            else @Suppress("DEPRECATION") DisplayMetrics().also { display.getRealMetrics(it) }.widthPixels
        val insets = if (Build.VERSION.SDK_INT >= 30 && metrics != null) NotchInsets(metrics.windowInsets) else null
        @Suppress("DiscouragedApi")
        val statusHeight = visual.resources.getIdentifier("status_bar_height", "dimen", "android")
        val safeTop = insets?.top ?: if (statusHeight > 0) visual.resources.getDimensionPixelSize(statusHeight) else views.px(24)
        val fit = CameraFit.load(context)
        val camera = fittedCutout(insets?.topCutout(0, 0), fit.copy(manual = fit.manual &&
            visual.resources.configuration.orientation != android.content.res.Configuration.ORIENTATION_LANDSCAPE),
            width, safeTop, density)
        val content = views.vertical().apply { setPadding(views.px(8), 0, views.px(8), views.px(8)) }
        val panel = ScrollView(visual).apply {
            isVerticalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
            addView(content, android.widget.FrameLayout.LayoutParams(-1, -2))
        }
        val stage = NotchStage(visual, panel, overlay = true) { toggle() }.apply {
            setOnTouchListener { _, event ->
                if (event.actionMasked != MotionEvent.ACTION_OUTSIDE || !expanded) false
                else { toggle(); true }
            }
        }
        val params = WindowManager.LayoutParams(1, -2, WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT).apply {
            title = "Opscode activity notch"
            gravity = Gravity.TOP or Gravity.LEFT
            if (Build.VERSION.SDK_INT >= 30) {
                setFitInsetsTypes(0)
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            } else if (Build.VERSION.SDK_INT >= 28) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        val attached = Window(manager, stage, params, views, content, width, safeTop, insets?.left ?: 0, insets?.right ?: 0, camera)
        sizeWindow(attached, panelSized = false)
        try {
            manager.addView(stage, params)
            lastAttachFailed = false
            window = attached
            scheduleFailureDismissal()
        } catch (error: RuntimeException) {
            reportAttachFailure(error)
        }
    }

    private fun sizeWindow(attached: Window, panelSized: Boolean) {
        with(attached) {
            val width = viewWidth(views, panelSized, displayWidth - leftInset - rightInset, camera)
            val anchor = camera?.bounds?.centerX()?.roundToInt() ?: displayWidth / 2
            val x = (anchor - width / 2).coerceIn(leftInset, (displayWidth - rightInset - width).coerceAtLeast(leftInset))
            val cutout = camera?.let {
                CutoutGeometry(Path(it.contour).apply { offset(-x.toFloat(), 0f) },
                    RectF(it.bounds).apply { offset(-x.toFloat(), 0f) }, it.circular)
            }
            view.window(NotchWindow(safeTop, cutout, panelSized))
            params.x = x
            params.width = width
        }
    }

    private fun toggle() {
        val attached = window ?: return
        if (!canShow() || settling) return
        if (expanded) {
            expanded = false
            settling = true
            attached.view.show(false) {
                if (window !== attached) return@show
                settling = false
                if (pose == null) hide()
                else {
                    resize(attached, panelSized = false)
                    attached.content.removeAllViews()
                    scheduleFailureDismissal()
                }
            }
        } else {
            expanded = true
            main.removeCallbacks(dismissFailure)
            renderPanel(attached)
            if (resize(attached, panelSized = true)) {
                attached.view.doOnPreDraw {
                    if (window === attached && expanded && pose != null) attached.view.show(true)
                }
            }
        }
    }

    private fun resize(attached: Window, panelSized: Boolean): Boolean {
        sizeWindow(attached, panelSized)
        return runCatching { attached.manager.updateViewLayout(attached.view, attached.params) }
            .onFailure {
                hide()
                if (it is RuntimeException) reportAttachFailure(it)
            }.isSuccess
    }

    private fun renderPanel(attached: Window) = with(attached.views) {
        val content = attached.content
        val scroll = attached.view.panel.scrollY
        content.removeAllViews()
        content.addView(label("Opscode", 16, paper, true))
        content.addView(label(mac, 12, secondary), row(top = 2, bottom = 7))
        val heading = label(description(), 12, if (approvalCount > 0) red else secondary, true)
        if (Build.VERSION.SDK_INT >= 28) heading.isAccessibilityHeading = true
        content.addView(heading, row(bottom = 4))
        if (pendingDecision != null) content.addView(label("Sending your decision…", 12, secondary), row(bottom = 4))
        decisionError?.let { content.addView(label(it, 12, red), row(bottom = 4)) }
        for (session in lastFeed.sessions) {
            if (session.approvals.isEmpty() && session.status in listOf("working", "failed")) {
                content.addView(label(session.title, 13, paper, true), row(top = 5))
                if (session.line.isNotBlank()) content.addView(label(session.line, 12, secondary), row(top = 2, bottom = 4))
            }
            for (approval in session.approvals) {
                content.addView(approvalCard(session, approval, pendingDecision != null, selectable = false,
                    onDeny = { decide(approval, false) },
                    onReview = { if (approval.choices.isEmpty()) decide(approval, true) else openApp() }),
                    row(top = 2, bottom = 3))
            }
        }
        content.addView(button("Open Opscode", false, compact = true, action = ::openApp), row(top = 6))
        attached.view.panel.post { attached.view.panel.scrollTo(0, scroll) }
    }

    private fun decide(approval: Approval, allow: Boolean) {
        if (!canShow() || !expanded || pendingDecision != null || allow && (!approval.canAllow || approval.choices.isNotEmpty())) return
        if (lastFeed.sessions.none { approval in it.approvals }) return
        pendingDecision = approval
        decisionError = null
        window?.let(::renderPanel)
        onDecision(approval, allow) { error ->
            if (pendingDecision != approval) return@onDecision
            pendingDecision = null
            decisionError = error
            if (error == null) {
                val sessions = lastFeed.sessions.map { it.copy(approvals = it.approvals - approval) }
                update(lastFeed.copy(sessions = sessions, needs = (lastFeed.needs - 1).coerceAtLeast(0)), mac)
            }
            if (expanded) window?.let(::renderPanel)
        }
    }

    private fun openApp() {
        if (!canShow()) return
        runCatching {
            context.startActivity(Intent(context, NotchActivity::class.java).setAction(OPEN_APPROVAL)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
        }.onFailure { Log.w(TAG, "Could not open Mac activity", it) }
    }

    private fun description(): String = when (pose) {
        Pose.NEEDS -> if (approvalCount == 1) "1 needs you" else "$approvalCount need you"
        Pose.ERROR -> "Mac task needs attention"
        Pose.WORKING -> if (lastFeed.working == 1) "Mac is working" else "${lastFeed.working} Mac tasks running"
        else -> "Opscode"
    }

    private fun closeIdle() {
        if (settling) return
        if (expanded) toggle() else hide()
    }

    private fun scheduleFailureDismissal() {
        main.removeCallbacks(dismissFailure)
        if (pose == Pose.ERROR && !expanded && window != null) main.postDelayed(dismissFailure, 25_000)
    }

    private fun hide() {
        main.removeCallbacks(dismissFailure)
        val attached = window ?: return
        window = null
        expanded = false
        settling = false
        runCatching { attached.manager.removeViewImmediate(attached.view) }
    }

    private fun reportAttachFailure(error: RuntimeException) {
        if (!lastAttachFailed) Log.w(TAG, "Android could not attach the activity notch", error)
        lastAttachFailed = true
    }

    private fun canShow(): Boolean = !CompanionConnection.activityVisible && Settings.canDrawOverlays(context) &&
        context.getSystemService(PowerManager::class.java).isInteractive &&
        !context.getSystemService(KeyguardManager::class.java).isKeyguardLocked

    private companion object {
        const val TAG = "OpscodeOverlay"

        fun viewWidth(views: NotchViews, expanded: Boolean, available: Int, camera: CutoutGeometry?): Int {
            val full = minOf(views.px(364), available - views.px(16)).coerceAtLeast(1)
            if (expanded) return full
            val body = ceil((camera?.bounds?.width() ?: 0f) + views.px(80)).toInt()
            return minOf(full, maxOf(views.px(104), body) + views.px(12))
        }
    }
}
