package com.opscode.mobile

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.KeyguardManager
import android.app.NotificationManager
import android.provider.Settings
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class NotchActivity : Activity() {
    private val views by lazy { NotchViews(this) }
    private val paper get() = views.paper
    private val secondary get() = views.secondary
    private val red get() = views.red
    private val ui = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private lateinit var stage: NotchStage
    private lateinit var panel: ScrollView
    private lateinit var content: LinearLayout
    private lateinit var idleControls: LinearLayout
    private lateinit var cameraFit: CameraFit
    private var expanded = false
    private var backgrounded = true
    private var generation = 0
    private var busy = false
    private var relayWatch: AutoCloseable? = null
    private var revoked = false
    private var checkedConnection = false
    private var setupDialog: AlertDialog? = null
    private var setupRows: LinearLayout? = null
    private var setupState: List<Any?>? = null
    private var restoreSetup = false
    private val setupPrefs by lazy { getSharedPreferences("phone-setup", MODE_PRIVATE) }
    private var connected = false
    private var link: Link? = null
    private var feed = Feed.empty
    private var message: String? = null
    private val autoClose = Runnable { if (expanded && feed.needs == 0 && !busy) show(false) }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        window.attributes = window.attributes.apply {
            if (Build.VERSION.SDK_INT >= 28) layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        if (Build.VERSION.SDK_INT >= 29) window.isNavigationBarContrastEnforced = false
        cameraFit = CameraFit.load(this)
        link = Links.read(this)
        if (link == null && Links.hasSavedLink(this)) message = "Scan a new Mac QR to move your saved pairing to the Opscode relay."
        restoreSetup = state?.getBoolean("setupOpen") == true
        content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(px(8), px(1), px(8), px(8))
        }
        panel = ScrollView(this).apply {
            isVerticalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
            addView(content, android.widget.FrameLayout.LayoutParams(-1, -2))
        }
        stage = NotchStage(this, panel) { show(!expanded) }.apply {
            background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(0xff_1e1d21.toInt(), 0xff_141316.toInt(), 0xff_121114.toInt()))
            cameraFit(this@NotchActivity.cameraFit)
            setOnApplyWindowInsetsListener { _, insets ->
                this.insets(insets)
                insets
            }
        }
        idleControls = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(px(20), px(8), px(20), px(8))
        }
        setContentView(FrameLayout(this).apply {
            addView(stage, FrameLayout.LayoutParams(-1, -1))
            addView(idleControls, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM).apply { bottomMargin = px(38) })
            setOnApplyWindowInsetsListener { _, insets ->
                val bottom = if (Build.VERSION.SDK_INT >= 30) insets.getInsets(WindowInsets.Type.navigationBars()).bottom
                    else @Suppress("DEPRECATION") insets.systemWindowInsetBottom
                val params = idleControls.layoutParams as FrameLayout.LayoutParams
                val margin = bottom + px(12)
                if (params.bottomMargin != margin) idleControls.layoutParams = params.apply { bottomMargin = margin }
                insets
            }
        })
        if (intent.action == OPEN_PREVIEW) message = "Test alert received"
        render()
        if (intent.action in listOf(OPEN_APPROVAL, OPEN_PREVIEW) || state?.getBoolean("expanded") == true) show(true, animated = false)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean("expanded", expanded)
        outState.putBoolean("setupOpen", setupDialog?.isShowing == true)
        super.onSaveInstanceState(outState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == OPEN_APPROVAL || intent.action == OPEN_PREVIEW) {
            setupDialog?.dismiss()
            if (intent.action == OPEN_PREVIEW) notify("Test alert received")
            show(true)
            refresh()
        }
    }

    override fun onStart() {
        super.onStart()
        backgrounded = false
        CompanionConnection.setActivityVisible(this, true)
        link?.let {
            registerNotifications(this, it)
            CompanionConnection.start(this)
        }
        refresh()
        stage.refreshAnimation()
    }

    override fun onPostResume() {
        super.onPostResume()
        if (intent.action == "com.opscode.mobile.OPEN_SETTINGS") {
            intent.action = null
            phoneAccess()
        }
        if (link != null && !revoked) CompanionConnection.start(this)
        if (restoreSetup || (!setupPrefs.getBoolean("shown", false) && intent.action !in listOf(OPEN_APPROVAL, OPEN_PREVIEW))) {
            restoreSetup = false
            phoneAccess()
        }
        refreshSetup()
    }

    override fun onStop() {
        backgrounded = true
        CompanionConnection.setActivityVisible(this, false)
        stopWatching()
        super.onStop()
    }

    override fun onDestroy() {
        generation++
        stopWatching()
        setupDialog?.dismiss()
        ui.removeCallbacksAndMessages(null)
        worker.shutdown()
        super.onDestroy()
    }

    @Deprecated("Uses the platform Activity result API to keep the notch independent of AndroidX UI.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCAN && resultCode == RESULT_OK) data?.getStringExtra("qr")?.let(::pair)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, result: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, result)
        if (requestCode == SETUP_NOTICES) {
            refreshSetup()
            return
        }
        if (requestCode != PREVIEW_NOTICES) return
        if (result.firstOrNull() == PackageManager.PERMISSION_GRANTED) previewNotification()
        else notify("Allow Opscode notifications in Android settings to test the alert.")
    }

    @Deprecated("Uses the platform back action on Android 8–12.")
    override fun onBackPressed() {
        if (expanded) show(false) else super.onBackPressed()
    }

    private fun show(next: Boolean, animated: Boolean = true) {
        if (next == expanded) return
        ui.removeCallbacks(autoClose)
        expanded = next
        if (animated) stage.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
        stage.show(next, animated)
        updateChrome()
    }

    private fun previewNotification() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PREVIEW_NOTICES)
            return
        }
        val context = applicationContext
        Handler(Looper.getMainLooper()).postDelayed({ postApprovalNotification(context, preview = true) }, 6_000)
        android.widget.Toast.makeText(this, "Sample alert in 6 seconds. You can leave Opscode.", android.widget.Toast.LENGTH_SHORT).show()
    }

    private fun updateChrome() {
        val visible = expanded || (connected && feed.needs > 0)
        idleControls.visibility = if (visible) View.GONE else View.VISIBLE
    }

    private fun fitCamera() {
        ui.removeCallbacks(autoClose)
        val detected = stage.hasTopCutout()
        val before = cameraFit
        var draft = if (detected) before else before.copy(manual = true)
        stage.cameraFit(draft, preview = true)
        val form = vertical().apply { setPadding(px(22), 0, px(22), px(10)) }
        form.addView(label(if (detected) "Align the outline just outside your camera."
            else "Android did not report a top camera. Set an outline if your phone has one.", 13, secondary), row(bottom = 10))

        val controls = mutableListOf<Pair<SeekBar, () -> Int>>()
        fun slider(name: String, range: IntRange, current: () -> Int, changed: (Int) -> CameraFit): LinearLayout {
            val field = vertical()
            val value = label("", 13, paper)
            field.addView(value)
            val bar = SeekBar(this).apply {
                max = range.last - range.first
                minimumHeight = px(42)
                contentDescription = name
                progress = current().coerceIn(range) - range.first
            }
            fun display() {
                val amount = current()
                value.text = if (amount == 0) name else "$name  ${if (amount > 0) "+" else ""}$amount"
            }
            display()
            bar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
                    if (fromUser) {
                        draft = changed(progress + range.first)
                        stage.cameraFit(draft, preview = true)
                    }
                    display()
                }
                override fun onStartTrackingTouch(seekBar: SeekBar) = Unit
                override fun onStopTrackingTouch(seekBar: SeekBar) = Unit
            })
            controls += bar to { current().coerceIn(range) - range.first }
            field.addView(bar, row(bottom = 4))
            form.addView(field, row())
            return field
        }

        if (!detected) form.addView(Switch(this).apply {
            text = "Show manual outline"
            isChecked = draft.manual
            setOnCheckedChangeListener { _, checked ->
                draft = draft.copy(manual = checked)
                stage.cameraFit(draft, preview = true)
            }
        }, row(bottom = 10))
        form.addView(label("Shape", 13, paper), row(bottom = 4))
        val shapeButtons = mutableListOf<Pair<android.widget.Button, CameraShape>>()
        val sizeControls = mutableListOf<View>()
        var diameterControl: View? = null
        fun updateShapes() {
            shapeButtons.forEach { (button, shape) ->
                button.isSelected = draft.shape == shape
                button.setTextColor(if (button.isSelected) red else paper)
            }
            val circle = draft.shape == CameraShape.CIRCLE
            diameterControl?.visibility = if (circle) View.VISIBLE else View.GONE
            sizeControls.forEach { it.visibility = if (circle) View.GONE else View.VISIBLE }
        }
        val shapes = LinearLayout(this).apply { gravity = Gravity.CENTER }
        listOf(CameraShape.AUTO to "Auto", CameraShape.CIRCLE to "Circle", CameraShape.WIDE to "Wide notch")
            .forEach { (shape, title) ->
                val choice = button(title, false, compact = true) {
                    draft = draft.copy(shape = shape)
                    updateShapes()
                    stage.cameraFit(draft, preview = true)
                }
                shapeButtons += choice to shape
                shapes.addView(choice, LinearLayout.LayoutParams(0, -2, 1f).apply { marginEnd = px(4) })
            }
        form.addView(shapes, row(bottom = 10))
        val horizontal = if (detected) 28 else ((resources.configuration.screenWidthDp / 2).coerceAtLeast(28) - 10)
        slider("Horizontal position", -horizontal..horizontal, { draft.x }) { draft.copy(x = it) }
        slider("Vertical position", -20..32, { draft.y }) { draft.copy(y = it) }
        diameterControl = slider("Diameter", -22..30, { draft.diameter }) { draft.copy(diameter = it) }
        sizeControls += slider("Outline width", -22..30, { draft.width }) { draft.copy(width = it) }
        sizeControls += slider("Outline height", -22..30, { draft.height }) { draft.copy(height = it) }
        updateShapes()

        val scrolling = ScrollView(this).apply { addView(form) }
        val dialog = AlertDialog.Builder(this).setTitle("Camera fit").setView(scrolling)
            .setNegativeButton("Cancel", null)
            .setNeutralButton("Reset", null)
            .setPositiveButton("Save") { _, _ ->
                cameraFit = draft
                cameraFit.save(this)
            }.create()
        dialog.setOnDismissListener { stage.cameraFit(cameraFit) }
        dialog.show()
        dialog.window?.apply {
            setGravity(Gravity.BOTTOM)
            clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        }
        dialog.getButton(AlertDialog.BUTTON_NEUTRAL).setOnClickListener {
            draft = CameraFit(manual = draft.manual)
            controls.forEach { (bar, value) -> bar.progress = value() }
            updateShapes()
            stage.cameraFit(draft, preview = true)
        }
    }

    private fun stopWatching() {
        relayWatch?.close()
        relayWatch = null
    }

    private fun refresh() {
        val target = link ?: return
        if (backgrounded) return
        if (relayWatch == null) {
            relayWatch = Desktop.watch(this, target) { state ->
                ui.post {
                    if (isDestroyed || backgrounded || target != link) return@post
                    val updated = state.feed
                    val clearedApprovals = feed.needs > 0 && updated?.needs == 0
                    val changed = connected != (updated != null) || updated != null && updated != feed ||
                        revoked != state.revoked || message != state.message
                    checkedConnection = true
                    connected = updated != null
                    revoked = state.revoked
                    if (!busy) message = state.message
                    if (updated != null) {
                        feed = updated
                        ApprovalAlerts.update(this, target, updated, compact = true)
                    } else if (revoked) ApprovalAlerts.clearNotification(this)
                    if (changed) render()
                    if (expanded && clearedApprovals) scheduleClose()
                }
            }
        }
        Desktop.sync(this, target)
    }

    private fun pair(raw: String) {
        if (busy) return
        val invite = runCatching { Invite.decode(raw) }.getOrElse {
            notify(it.display())
            return
        }
        generation++
        busy = true
        notify("Pairing with your Mac…")
        worker.execute {
            val result = runCatching {
                val paired = Desktop.pair(invite)
                try { Links.save(applicationContext, paired) }
                catch (error: Exception) {
                    runCatching { Desktop.disconnect(paired) }
                    throw CompanionFailure("The phone couldn’t save the pairing securely. Open a fresh QR and try again.", cause = error)
                }
                paired
            }
            ui.post {
                if (isDestroyed) return@post
                busy = false
                result.onSuccess { paired ->
                    stopWatching()
                    connected = false
                    checkedConnection = false
                    revoked = false
                    link = paired
                    feed = Feed.empty
                    message = null
                    render()
                    show(true)
                    registerNotifications(this, paired)
                    CompanionConnection.start(this)
                    refresh()
                }.onFailure { notify(it.display()); refresh() }
            }
        }
    }

    private fun decide(approval: Approval, allow: Boolean, choice: String? = null) {
        if (busy || getSystemService(KeyguardManager::class.java).isKeyguardLocked) return
        val target = link ?: return
        if (!connected || (allow && !approval.canAllow)) return
        generation++
        val attempt = generation
        busy = true
        notify("Sending your decision…")
        worker.execute {
            val result = runCatching { Desktop.decide(applicationContext, target, approval, allow, choice) }
            ui.post {
                if (isDestroyed || attempt != generation) return@post
                busy = false
                result.onSuccess {
                    notify(if (allow) "Sent to your Mac." else "Denied on your Mac.")
                }.onFailure { notify(it.display()) }
                refresh()
            }
        }
    }

    private fun disconnect() {
        val target = link ?: return
        if (busy) return
        AlertDialog.Builder(this).setTitle("Disconnect this phone?")
            .setMessage("The relay will revoke this phone’s access.")
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Disconnect") { _, _ ->
                generation++
                val attempt = generation
                busy = true
                notify("Disconnecting…")
                worker.execute {
                    val result = runCatching {
                        try { Desktop.disconnect(target) } catch (error: CompanionFailure) {
                            if (error.status != 401) throw error
                        }
                        Links.clear(applicationContext)
                    }
                    ui.post {
                        if (isDestroyed || attempt != generation) return@post
                        busy = false
                        result.onSuccess {
                            stopWatching()
                            link = null
                            revoked = false
                            checkedConnection = false
                            stopService(Intent(this, CompanionConnection::class.java))
                            ApprovalAlerts.clearNotification(this)
                            feed = Feed.empty
                            connected = false
                            notify("Phone disconnected.")
                        }.onFailure { notify(it.display()); refresh() }
                    }
                }
            }.show()
    }

    private fun qrMenu() {
        val text = EditText(this).apply {
            hint = "Optional pairing link"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO
            setSingleLine(true)
        }
        val wrapper = LinearLayout(this).apply { setPadding(px(24), 0, px(24), 0); addView(text, -1, -2) }
        AlertDialog.Builder(this).setTitle(if (link == null) "Pair a Mac" else "Pair again")
            .setMessage("On the Mac, open Settings → Devices and choose Show pairing QR.")
            .setView(wrapper)
            .setNegativeButton("Cancel", null)
            .setNeutralButton("Use link") { _, _ -> pair(text.text.toString()) }
            .setPositiveButton("Scan QR") { _, _ ->
                @Suppress("DEPRECATION")
                startActivityForResult(Intent(this, QrActivity::class.java), SCAN)
            }.show()
    }

    private fun notify(value: String) {
        message = value
        render()
        if (expanded) content.announceForAccessibility(value)
    }

    private fun scheduleClose() {
        ui.removeCallbacks(autoClose)
        if (expanded) ui.postDelayed(autoClose, 2_400)
    }

    private fun render() {
        val oldScroll = panel.scrollY
        content.removeAllViews()
        val unpaired = link == null
        val hasApproval = feed.sessions.any { it.approvals.isNotEmpty() }
        val statusText = when {
            busy -> "Connecting…"
            unpaired -> "Mac not paired"
            !checkedConnection -> "Syncing Mac activity…"
            revoked -> "Pairing revoked"
            !connected -> "Paired · reconnecting"
            else -> "Connected · ${link?.route}"
        }
        val countNeeds = if (connected) feed.needs else 0
        val countWorking = if (connected) feed.working else 0
        val countFinished = if (connected) feed.finished else 0
        val pose = when {
            countNeeds > 0 -> Pose.NEEDS
            countWorking > 0 -> Pose.WORKING
            connected && feed.sessions.any { it.status == "failed" } -> Pose.ERROR
            countFinished > 0 -> Pose.DONE
            else -> Pose.SLEEPING
        }
        stage.status(pose, countNeeds, countWorking, countFinished,
            when (countNeeds) {
                0 -> "Opscode, $statusText"
                1 -> "Opscode, one approval waiting"
                else -> "Opscode, $countNeeds approvals waiting"
            })
        idleControls.removeAllViews()
        val shortcuts = LinearLayout(this).apply { gravity = Gravity.CENTER }
        shortcuts.addView(button(if (unpaired) "Pair Mac" else "Mac activity", false, compact = true) {
            if (unpaired) qrMenu() else show(true)
        })
        if (!unpaired) shortcuts.addView(button("Projects", true, compact = true) { openProjects() })
        idleControls.addView(shortcuts, row())
        idleControls.addView(LinearLayout(this).apply {
            gravity = Gravity.CENTER
            addView(button("Camera fit", false, compact = true, action = ::fitCamera),
                LinearLayout.LayoutParams(-2, -2).apply { marginEnd = px(6) })
            addView(button("Phone access", false, compact = true, action = ::phoneAccess))
        }, row(top = 6))
        updateChrome()

        val heading = vertical()
        heading.addView(label("Opscode", 16, paper, true))
        heading.addView(label(link?.label ?: "Pair a Mac to see live activity", 12, secondary), row(top = 2))
        val head = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
        head.addView(heading, LinearLayout.LayoutParams(0, -2, 1f))
        head.addView(button(if (unpaired) "Pair Mac" else "Disconnect", false, compact = true) {
            if (link == null) qrMenu() else disconnect()
        })
        content.addView(head, row(top = 0, bottom = 7))

        val counts = listOfNotNull(
            if (countNeeds == 1) "1 needs you" else if (countNeeds > 1) "$countNeeds need you" else null,
            if (countWorking > 0) "$countWorking working" else null,
            if (countFinished > 0) "$countFinished new" else null,
        ).joinToString("   ·   ")
        content.addView(label(counts.ifEmpty { statusText }, 12, if (countNeeds > 0) red else secondary), row(bottom = 5))
        message?.let { content.addView(label(it, 12, if (!connected) red else secondary), row(top = 3, bottom = 5)) }
        if (connected) {
            if (hasApproval) {
                section("Needs you")
                feed.sessions.forEach { session -> session.approvals.forEach { approval -> card(session, approval) } }
            }
            listOf("working" to "Working", "done" to "Finished", "idle" to "Recent").forEach { (status, title) ->
                val sessions = feed.sessions.filter { it.status == status || (status == "done" && it.status == "failed") }
                if (sessions.isNotEmpty()) {
                    section(title)
                    sessions.forEach(::sessionRow)
                }
            }
            if (feed.sessions.isEmpty()) content.addView(label("All quiet", 13, secondary), row(top = 10, bottom = 8))
        }
        val tools = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
        if (!unpaired && !connected && !busy) tools.addView(button("Refresh", false, compact = true, action = ::refresh),
            LinearLayout.LayoutParams(0, -2, 1f).apply { marginEnd = px(6) })
        if (revoked && !busy) tools.addView(button("Pair again", false, compact = true, action = ::qrMenu),
            LinearLayout.LayoutParams(0, -2, 1f).apply { marginEnd = px(6) })
        tools.addView(button("Phone access", false, compact = true, action = ::phoneAccess), LinearLayout.LayoutParams(0, -2, 1f))
        if (!unpaired) tools.addView(button("Projects", true, compact = true, action = ::openProjects), LinearLayout.LayoutParams(0, -2, 1f))
        content.addView(tools, row(top = 8, bottom = 2))
        if (!unpaired) {
            content.addView(Switch(this).apply {
                text = "Stay connected in background"
                setTextColor(secondary)
                isChecked = CompanionConnection.enabled(this@NotchActivity)
                setOnCheckedChangeListener { _, enabled -> CompanionConnection.setEnabled(this@NotchActivity, enabled) }
            }, row(top = 6))
        }
        if (oldScroll > 0) panel.post { panel.scrollTo(0, oldScroll) }
        refreshSetup()
    }

    private fun phoneAccess() {
        if (setupDialog?.isShowing == true) return
        setupPrefs.edit().putBoolean("shown", true).apply()
        val options = vertical().apply { setPadding(px(22), 0, px(22), px(12)) }
        val scroller = ScrollView(this).apply { addView(options) }
        setupRows = options
        setupState = null
        setupDialog = AlertDialog.Builder(this).setTitle("Set up Opscode").setView(scroller)
            .setPositiveButton("Done", null).create().apply {
                setOnDismissListener {
                    setupDialog = null
                    setupRows = null
                    setupState = null
                }
                show()
            }
        refreshSetup()
    }

    private fun openProjects() { startActivity(Intent(this, WorkspaceActivity::class.java)) }

    private fun refreshSetup() {
        val options = setupRows ?: return
        val notifications = CompanionConnection.canNotify(this)
        val manager = getSystemService(NotificationManager::class.java)
        val channel = manager.getNotificationChannel(approvalChannel(this))
        val approvalAllowed = notifications && channel?.importance != NotificationManager.IMPORTANCE_NONE
        val background = CompanionConnection.enabled(this)
        val overlay = Settings.canDrawOverlays(this)
        val backgroundStatus = when {
            link == null -> "Pair your Mac first"
            revoked -> "Pairing revoked"
            !background -> "Off"
            else -> CompanionConnection.backgroundStatus()
        }
        val vibrate = vibratingApprovals(this)
        val state = listOf(link, busy, checkedConnection, connected, message, notifications, approvalAllowed, backgroundStatus, overlay, vibrate)
        if (setupState == state) return
        setupState = state
        options.removeAllViews()
        fun item(title: String, status: String, help: String, action: String? = null, open: (() -> Unit)? = null) {
            options.addView(label(title, 15, paper, true).apply {
                if (Build.VERSION.SDK_INT >= 28) isAccessibilityHeading = true
            }, row(top = 12))
            options.addView(label(status, 12, secondary, true), row(top = 2))
            options.addView(label(help, 13, secondary), row(top = 3, bottom = 3))
            if (action != null && open != null) options.addView(button(action, false, compact = true, action = open), row())
        }
        item("Mac connection", when {
            busy -> "Connecting…"
            link == null -> "Not paired"
            connected -> "Connected · ${link?.route}"
            revoked -> "Pairing revoked"
            checkedConnection -> "Paired · reconnecting"
            else -> "Paired · syncing"
        }, message ?: if (link == null) "On the Mac, open Settings → Devices and show the pairing QR."
            else "${link?.label} · ${link?.route}", if (busy || link != null && !revoked) null else "Pair Mac", ::qrMenu)
        item("Approval notifications", if (approvalAllowed) "Allowed" else "Permission needed",
            "Receive Mac requests and open the notch to review them.", "Notification settings", ::requestSetupNotifications)
        item("Background connection", backgroundStatus,
            "Receives Mac activity and approvals after you leave Opscode. Android may pause it under battery restrictions.",
            if (link != null && !revoked && !background) "Enable background connection" else null, ::enableBackground)
        item("Notch over other apps", if (overlay) "Allowed" else "Optional · Off",
            "Shows a blue ring for running work, a red ring for approvals, and an amber ring when a Mac task fails. Tap to expand the notch.", "Overlay settings") {
            permissionExplanation()
        }
        options.addView(Switch(this).apply {
            text = "Vibrate for approvals"
            setTextColor(paper)
            minHeight = px(48)
            isChecked = vibrate
            setOnCheckedChangeListener { _, value -> setVibratingApprovals(this@NotchActivity, value) }
        }, row(top = 10))
        options.addView(button("Test notification", false, compact = true, action = ::previewNotification), row(top = 4))
    }

    private fun permissionExplanation() {
        AlertDialog.Builder(this)
            .setTitle("About the approval notch")
            .setMessage("Opscode uses display over other apps to show a status ring for Mac activity. Tap the notch to expand it and review Mac requests over your current app. Android controls this permission in Settings.")
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Continue to settings") { _, _ ->
                startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, android.net.Uri.parse("package:$packageName")))
            }
            .show()
    }

    private fun requestSetupNotifications() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            && !setupPrefs.getBoolean("askedNotifications", false)) {
            setupPrefs.edit().putBoolean("askedNotifications", true).apply()
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), SETUP_NOTICES)
            return
        }
        startActivity(Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            .putExtra(Settings.EXTRA_CHANNEL_ID, approvalChannel(this)))
    }

    private fun enableBackground() {
        CompanionConnection.setEnabled(this, true)
        render()
    }

    private fun section(title: String) {
        val heading = label(title, 11, 0xff_b2aeb4.toInt(), true)
        if (Build.VERSION.SDK_INT >= 28) heading.isAccessibilityHeading = true
        content.addView(heading, row(top = 9, bottom = 4))
    }

    private fun card(session: Session, approval: Approval) {
        val card = views.approvalCard(session, approval, busy, onDeny = { decide(approval, false) }, onReview = {
            if (approval.choices.isEmpty()) decide(approval, true)
            else AlertDialog.Builder(this).setTitle("Approve this request")
                .setItems(approval.choices.map { if (it.hint.isBlank()) it.label else "${it.label}\n${it.hint}" }.toTypedArray()) { _, i ->
                    confirmChoice(approval, approval.choices[i])
                }.setNegativeButton("Cancel", null).show()
        })
        content.addView(card, row(top = 2, bottom = 3))
    }

    private fun confirmChoice(approval: Approval, choice: Choice) {
        AlertDialog.Builder(this).setTitle(choice.label).setMessage(choice.hint.ifBlank { approval.summary })
            .setNegativeButton("Cancel", null).setPositiveButton("Confirm") { _, _ -> decide(approval, true, choice.id) }.show()
    }

    private fun sessionRow(session: Session) {
        val row = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(px(4), px(4), px(3), px(4))
        }
        row.addView(mark(session.engine, session.status), LinearLayout.LayoutParams(px(30), px(30)).apply { marginEnd = px(9) })
        val words = vertical()
        words.addView(label(session.title, 13, paper, true))
        if (session.line.isNotBlank()) words.addView(label(session.line, 12, secondary), row(top = 1))
        row.addView(words, LinearLayout.LayoutParams(0, -2, 1f))
        val status = when (session.status) { "working" -> "Working"; "done" -> "Done"; "failed" -> "Failed"; else -> "" }
        if (status.isNotEmpty()) row.addView(label(status, 10,
            when (session.status) { "working" -> 0xff_ffb48a.toInt(); "failed" -> red; else -> secondary }).apply {
            setPadding(px(6), 0, 0, 0)
        })
        content.addView(row)
    }

    private fun mark(engine: String, status: String) = views.mark(engine, status)
    private fun button(text: String, primary: Boolean, compact: Boolean = false, action: () -> Unit) =
        views.button(text, primary, compact, action)
    private fun label(value: String, sp: Int, ink: Int, bold: Boolean = false) = views.label(value, sp, ink, bold)
    private fun vertical() = views.vertical()
    private fun row(top: Int = 0, bottom: Int = 0) = views.row(top, bottom)
    private fun px(dp: Int) = views.px(dp)
    private fun Throwable.display() = (this as? CompanionFailure)?.message
        ?: "Couldn’t sync Mac activity. Opscode will reconnect automatically."

    companion object {
        private const val SCAN = 12
        private const val PREVIEW_NOTICES = 14
        private const val SETUP_NOTICES = 66
    }
}
