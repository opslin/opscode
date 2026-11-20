package com.opscode.mobile

import android.Manifest
import android.content.pm.PackageManager
import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.res.ColorStateList
import android.database.Cursor
import android.graphics.Color
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.provider.OpenableColumns
import android.text.InputFilter
import android.text.InputType
import android.util.Base64
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class WorkspaceActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private val reads = Executors.newSingleThreadExecutor()
    private val transfers = Executors.newSingleThreadExecutor()

    private lateinit var title: TextView
    private lateinit var projectButton: Button
    private lateinit var threadButton: Button
    private lateinit var newButton: Button
    private lateinit var pluginsButton: Button
    private lateinit var status: TextView
    private lateinit var approvals: Button
    private lateinit var scroll: ScrollView
    private lateinit var transcript: LinearLayout
    private lateinit var composer: EditText
    private lateinit var attachments: LinearLayout
    private lateinit var attachButton: Button
    private lateinit var engineButton: Button
    private lateinit var modeButton: Button
    private lateinit var teamRow: LinearLayout
    private lateinit var voiceButton: Button
    private var voice: MobileVoice? = null
    private var settingsPage: View? = null
    private lateinit var sendButton: Button
    private lateinit var projectContext: TextView
    private lateinit var shell: FrameLayout
    private var drawer: View? = null
    private var drawerList: LinearLayout? = null
    private var drawerRevision: List<String>? = null
    private val fullMessageTexts = mutableMapOf<String, String>()

    private var link: Link? = null
    private var watch: AutoCloseable? = null
    private var changes: AutoCloseable? = null
    private var visible = false
    private var connected = false
    private var engine: EnginePick? = null
    private var mode = "supervised"
    private var team = "normal"
    private var busy = false
    private var project: Project? = null
    private var chat: String? = null
    private var chatTitle = ""
    private var projects = emptyList<Project>()
    private var history = emptyList<JSONObject>()
    private var earlier = emptyList<JSONObject>()
    private var before = 0
    private var version = 0
    private var loading = false
    private var refreshAgain = false
    private var sentRequest: Pair<String, String>? = null
    private var savedDownload: Download? = null
    private val files = mutableListOf<Attachment>()
    private val projectFiles = mutableListOf<String>()
    private val sync = Runnable { refresh() }
    private data class Project(val id: String, val name: String)
    private data class EnginePick(val id: String, val label: String, val model: String? = null, val effort: String? = null)
    private data class Mode(val id: String, val title: String, val short: String, val summary: String)
    private data class Attachment(val uri: Uri, val name: String, var upload: String? = null)
    private data class Download(val workspace: String, val chat: String, val turn: String, val index: Int, val name: String)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        link = Links.read(this)
        chat = savedInstanceState?.getString("chat")
        val id = savedInstanceState?.getString("project")
        if (id != null) project = Project(id, savedInstanceState.getString("projectName", "Project"))
        chatTitle = savedInstanceState?.getString("title").orEmpty()
        savedInstanceState?.getString("engine")?.let {
            engine = EnginePick(it, savedInstanceState.getString("engineLabel", it),
                savedInstanceState.getString("model"), savedInstanceState.getString("effort"))
        }
        mode = savedInstanceState?.getString("mode") ?: "supervised"
        team = savedInstanceState?.getString("team") ?: "normal"
        if (Build.VERSION.SDK_INT >= 30) window.setDecorFitsSystemWindows(false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= 29) window.isNavigationBarContrastEnforced = false
        createUi()
        composer.setText(savedInstanceState?.getString("draft").orEmpty())
        renderHistory()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString("chat", chat)
        outState.putString("project", project?.id)
        outState.putString("projectName", project?.name)
        outState.putString("title", chatTitle)
        outState.putString("draft", composer.text.toString())
        outState.putString("engine", engine?.id)
        outState.putString("engineLabel", engine?.label)
        outState.putString("model", engine?.model)
        outState.putString("effort", engine?.effort)
        outState.putString("mode", mode)
        outState.putString("team", team)
        super.onSaveInstanceState(outState)
    }

    override fun onStart() {
        super.onStart()
        visible = true
        voiceButton.text = "▥  Voice mode"
        CompanionConnection.setActivityVisible(this, true)
        // Pairing or disconnecting happens in a separate activity. Reload its saved
        // link whenever this screen returns instead of keeping the launch-time value.
        link = Links.read(this)
        updateControls()
        val target = link
        if (target == null) {
            connectionText("Pair your Mac in Settings to open your projects.")
            return
        }
        CompanionConnection.start(this)
        watch = Desktop.watch(this, target) { state ->
            main.post {
                if (!visible || isDestroyed) return@post
                val wasConnected = connected
                connected = state.feed != null && state.workspace
                state.feed?.let { ApprovalAlerts.update(this, target, it, compact = true) }
                val needs = state.feed?.needs ?: 0
                approvals.visibility = if (needs > 0) View.VISIBLE else View.GONE
                approvals.text = if (needs == 1) "Review approval" else "Review $needs approvals"
                updateControls()
                if (connected) {
                    if (!busy && !wasConnected) {
                        connectionText("Connected to ${target.label}")
                        queueRefresh(0)
                    }
                } else {
                    connectionText(if (state.feed != null) "Update Opscode on your Mac to use Projects."
                        else state.message ?: "Reconnecting to your Mac…")
                }
            }
        }
        changes = Desktop.watchWorkspace(this, target) { main.post { if (visible) queueRefresh(180) } }
        Desktop.sync(this, target)
    }

    override fun onStop() {
        visible = false
        voice?.close()
        voice = null
        connected = false
        main.removeCallbacks(sync)
        watch?.close()
        changes?.close()
        CompanionConnection.setActivityVisible(this, false)
        super.onStop()
    }

    override fun onDestroy() {
        main.removeCallbacksAndMessages(null)
        reads.shutdown()
        transfers.shutdown()
        super.onDestroy()
    }

    private fun createUi() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(CANVAS)
            setOnApplyWindowInsetsListener { view, insets ->
                if (Build.VERSION.SDK_INT >= 30) {
                    val bars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
                    val keyboard = insets.getInsets(WindowInsets.Type.ime())
                    view.setPadding(bars.left, bars.top, bars.right, maxOf(bars.bottom, keyboard.bottom))
                } else {
                    @Suppress("DEPRECATION")
                    view.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
                }
                insets
            }
        }
        val top = horizontal().apply { setPadding(dp(12), dp(4), dp(12), dp(4)) }
        top.addView(control("☰", "Open navigation") { openDrawer() }, LinearLayout.LayoutParams(dp(48), dp(48)))
        val brand = label("New chat", 16, INK).apply { typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL) }
        top.addView(brand, LinearLayout.LayoutParams(0, -2, 1f).apply { marginStart = dp(6) })
        pluginsButton = control("⋯", "Settings") { showSettings() }
        top.addView(pluginsButton)
        root.addView(top)
        root.addView(View(this).apply { setBackgroundColor(LINE) }, LinearLayout.LayoutParams(-1, dp(1)))

        val content = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val centered = FrameLayout(this)
        centered.addView(content, FrameLayout.LayoutParams(minOf(resources.displayMetrics.widthPixels, dp(720)), -1, Gravity.TOP or Gravity.CENTER_HORIZONTAL))
        root.addView(centered, LinearLayout.LayoutParams(-1, 0, 1f))

        val toolbar = horizontal().apply { setPadding(dp(16), dp(8), dp(16), 0) }
        projectButton = control("Projects") { chooseProject() }
        threadButton = control("Chats") { chooseChat() }
        newButton = control("New chat") { selectChat(null, "") }
        toolbar.addView(projectButton, LinearLayout.LayoutParams(0, -2, 1f))
        toolbar.addView(threadButton)
        toolbar.addView(newButton)
        toolbar.visibility = View.GONE
        content.addView(toolbar)
        title = label("", 15, INK).apply { setPadding(dp(20), dp(5), dp(20), 0) }
        status = label("Connecting to your Mac…", 12, MUTED).apply { setPadding(dp(20), dp(4), dp(20), dp(8)) }
        content.addView(title)
        content.addView(status)
        approvals = control("Review approval") {
            startActivity(Intent(this, NotchActivity::class.java).setAction(OPEN_APPROVAL)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP))
        }.apply { visibility = View.GONE }
        content.addView(approvals, LinearLayout.LayoutParams(-1, -2).apply { setMargins(dp(16), 0, dp(16), 0) })
        transcript = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(17), dp(4), dp(17), dp(16))
        }
        scroll = ScrollView(this).apply {
            isFillViewport = true
            clipToPadding = false
            addView(transcript)
        }
        content.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))

        teamRow = horizontal().apply { setPadding(dp(12), 0, dp(12), dp(4)) }
        content.addView(HorizontalScrollView(this).apply { isHorizontalScrollBarEnabled = false; addView(teamRow) }, LinearLayout.LayoutParams(-1, dp(56)))
        voiceButton = control("▥  Voice mode", "Start live voice mode") { toggleVoice() }
        content.addView(voiceButton, LinearLayout.LayoutParams(-2, dp(48)).apply { gravity = Gravity.END; marginEnd = dp(16) })
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = panel(SURFACE, 16)
            setPadding(dp(7), dp(3), dp(7), dp(6))
        }
        attachments = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        box.addView(attachments)
        composer = EditText(this).apply {
            hint = "Describe a task, or add files…"
            setTextColor(INK)
            setHintTextColor(MUTED)
            textSize = 16f
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            filters = arrayOf(InputFilter.LengthFilter(8000))
            minLines = 2
            maxLines = 5
            background = null
            setPadding(dp(9), dp(10), dp(9), dp(8))
        }
        box.addView(composer, LinearLayout.LayoutParams(-1, -2))
        val controls = horizontal()
        attachButton = control("+", "Add to chat") { chooseAttachment() }.apply { textSize = 26f; setPadding(0, 0, 0, 0) }
        controls.addView(attachButton, LinearLayout.LayoutParams(dp(46), dp(48)))
        engineButton = control("Mac default") { chooseEngine() }
        controls.addView(engineButton, LinearLayout.LayoutParams(0, dp(48), 1f))
        modeButton = control("Supervised", "Permission mode") { chooseMode() }
        controls.addView(modeButton, LinearLayout.LayoutParams(0, dp(48), 1f))
        sendButton = control("↑", "Send message", primary = true) { send() }.apply { textSize = 24f; setPadding(0, 0, 0, 0); background = panel(INK, 24) }
        controls.addView(sendButton, LinearLayout.LayoutParams(dp(48), dp(48)))
        box.addView(controls)
        content.addView(box, LinearLayout.LayoutParams(-1, -2).apply { setMargins(dp(16), dp(4), dp(16), dp(12)) })
        projectContext = label("", 12, MUTED).apply {
            setPadding(dp(22), 0, dp(22), dp(12))
            setOnClickListener { chooseProject() }
        }
        content.addView(projectContext)
        shell = FrameLayout(this).apply { addView(root) }
        setContentView(shell)
        root.requestApplyInsets()
        updateControls()
    }

    private fun openDrawer() {
        if (drawer != null) return
        val overlay = FrameLayout(this).apply { setBackgroundColor(0x99000000.toInt()); setOnClickListener { closeDrawer() } }
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xff080809.toInt())
            setPadding(dp(16), dp(34), dp(16), dp(16))
            setOnClickListener { }
        }
        val heading = horizontal()
        heading.addView(ImageView(this).apply { setImageResource(R.drawable.opscode_workspace_mark) }, LinearLayout.LayoutParams(dp(28), dp(28)))
        heading.addView(label("Opscode", 20, INK).apply { typeface = Typeface.DEFAULT_BOLD; setPadding(dp(10), 0, 0, 0) }, LinearLayout.LayoutParams(0, -2, 1f))
        heading.addView(control("×", "Close navigation") { closeDrawer() })
        panel.addView(heading)
        panel.addView(control("+   New chat") {
            closeDrawer()
            if (project == null) chooseProject() else selectChat(null, "")
        }, LinearLayout.LayoutParams(-1, -2))
        panel.addView(control(project?.name ?: "Choose project") { closeDrawer(); chooseProject() },
            LinearLayout.LayoutParams(-1, -2))
        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        drawerList = list
        drawerRevision = null
        panel.addView(ScrollView(this).apply { addView(list) }, LinearLayout.LayoutParams(-1, 0, 1f))
        panel.addView(control("Settings") { closeDrawer(); showSettings() }, LinearLayout.LayoutParams(-1, -2))
        overlay.addView(panel, FrameLayout.LayoutParams(minOf(dp(320), resources.displayMetrics.widthPixels - dp(48)), -1, Gravity.START))
        shell.addView(overlay)
        drawer = overlay
        panel.translationX = -dp(320).toFloat()
        panel.animate().translationX(0f).setDuration(180).start()
        val current = project
        if (current == null || !connected) {
            list.addView(label(if (connected) "Select a project to see its chats." else "Connect your Mac to see your chats.", 14, MUTED))
            return
        }
        list.addView(label("Loading chats…", 14, MUTED))
        queueRefresh(0)
    }

    private fun renderDrawerChats(list: LinearLayout, current: Project, chats: List<JSONObject>) {
        val revision = chats.map(JSONObject::toString)
        if (drawerRevision == revision) return
        drawerRevision = revision
        list.removeAllViews()
        list.addView(label("Chats", 13, MUTED).apply { setPadding(dp(8), dp(18), 0, dp(8)) })
        if (chats.isEmpty()) list.addView(label("No chats yet", 14, MUTED))
        for (row in chats) list.addView(control(
            row.optString("title").ifBlank { "New chat" } + if (row.optBoolean("running")) "  •  Running" else ""
        ) {
            if (project == current) { closeDrawer(); selectChat(row.getString("id"), row.optString("title"), settings = row) }
        }, LinearLayout.LayoutParams(-1, -2))
    }

    private fun closeDrawer() {
        drawer?.let { shell.removeView(it) }
        drawer = null
        drawerList = null
        drawerRevision = null
    }

    @Deprecated("Uses the platform back action on Android 8–12.")
    override fun onBackPressed() {
        if (drawer != null) closeDrawer() else if (settingsPage != null) closeSettings() else super.onBackPressed()
    }

    private fun showSettings() {
        if (settingsPage != null) return
        val page = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setBackgroundColor(CANVAS); setPadding(dp(16), dp(32), dp(16), dp(16)) }
        page.addView(control("‹   Back to app") { closeSettings() }, LinearLayout.LayoutParams(-1, dp(56)))
        page.addView(label("Settings", 26, INK).apply { setPadding(dp(10), dp(20), 0, dp(14)); typeface = Typeface.DEFAULT_BOLD })
        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val options = listOf<Pair<String, () -> Unit>>(
            "Devices · connection and pairing" to { startActivity(Intent(this, NotchActivity::class.java).setAction("com.opscode.mobile.OPEN_SETTINGS")) },
            "Mac activity and approvals" to { startActivity(Intent(this, NotchActivity::class.java).setAction(OPEN_APPROVAL)) },
            "Camera and phone access" to { startActivity(Intent(this, NotchActivity::class.java).setAction("com.opscode.mobile.OPEN_SETTINGS")) },
            "Accounts on This Mac" to { chooseAccount() },
            "API providers on This Mac" to { chooseProvider() },
            "Voice · language and speaking voice" to { showVoiceSettings() },
            "Plugins" to { showPlugins() }, "MCP servers" to { showIntegrations() }
        )
        for ((name, action) in options) list.addView(control("$name    ›", name, action = action), LinearLayout.LayoutParams(-1, dp(56)))
        page.addView(ScrollView(this).apply { addView(list) }, LinearLayout.LayoutParams(-1, 0, 1f))
        shell.addView(page, FrameLayout.LayoutParams(-1, -1)); settingsPage = page
    }
    private fun closeSettings() { settingsPage?.let { shell.removeView(it) }; settingsPage = null }

    private fun toggleVoice() {
        if (voice != null) { voice?.close(); voice = null; voiceButton.text = "▥  Voice mode"; connectionText("Voice mode stopped."); return }
        if (!connected || project == null) { connectionText("Connect your Mac and choose a project first."); return }
        if (team != "normal") { connectionText("Open a normal chat for voice mode."); return }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 81); return
        }
        val current = project ?: return
        val target = link ?: return
        voiceButton.text = "■  End voice"
        connectionText("Starting voice on This Mac…")
        lateinit var session: MobileVoice
        session = MobileVoice(
            call = { op, args -> Desktop.workspace(applicationContext, target, args.put("op", op)) },
            report = { message -> main.post { if (!isDestroyed) connectionText(message) } },
            onClosed = { main.post { if (!isDestroyed && voice === session) { voice = null; voiceButton.text = "▥  Voice mode" } } },
        )
        voice = session
        session.start(current.id, chat, engine?.id, engine?.model, engine?.effort, mode)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 81) {
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) toggleVoice()
            else connectionText("Microphone permission is needed for voice mode.")
        }
    }

    private fun showVoiceSettings() = readAction({ target -> api(target, "voice.settings") }) { result ->
        val current = result.optJSONObject("settings") ?: JSONObject()
        val names = arrayOf("Microphone language · ${current.optString("voice_locale", "auto")}", "Reply language · ${current.optString("tts_locale", "auto")}", "Voice mode speaker · ${current.optString("voice_tts_voice").ifBlank { "Auto" }}")
        AlertDialog.Builder(this).setTitle("Voice on This Mac").setItems(names) { _, index ->
            val field = listOf("voice_locale", "tts_locale", "voice_tts_voice")[index]
            val values: List<Pair<String, String>> = if (index == 2) {
                listOf("" to "Automatic") + items(result, "voices").map { it.getString("id") to (it.optString("name") + " · " + it.optString("language")) }
            } else {
                val array = result.optJSONArray(if (index == 0) "speech" else "languages") ?: JSONArray()
                listOf("auto" to "Automatic") + List(array.length()) { array.getString(it) to array.getString(it) }
            }
            AlertDialog.Builder(this).setTitle(names[index]).setItems(values.map { it.second }.toTypedArray()) { _, selected ->
                readAction({ target -> api(target, "voice.settings.set", "field" to field, "value" to values[selected].first) }) { connectionText("Voice setting saved on your Mac.") }
            }.setNegativeButton("Cancel", null).show()
        }.setNegativeButton("Close", null).show()
    }

    private fun chooseProvider() = readAction({ target -> items(api(target, "providers"), "providers") }) { found ->
        if (found.isEmpty()) { connectionText("Set up an API provider in Opscode on your Mac."); return@readAction }
        AlertDialog.Builder(this).setTitle("API provider on This Mac")
            .setItems(found.map { it.optString("label") + if (it.optBoolean("active")) "  •  Active" else "" }.toTypedArray()) { _, index ->
                readAction({ target -> api(target, "provider.select", "provider" to found[index].getString("id")) }) { connectionText("API provider changed on your Mac.") }
            }.setNegativeButton("Cancel", null).show()
    }

    private fun chooseAccount() = readAction({ target -> items(api(target, "accounts"), "accounts") }) { found ->
        val applicable = if (chat != null) found.filter { it.optString("engine") == engine?.id } else found
        if (applicable.isEmpty()) { connectionText("Sign in to a coding account in Opscode on your Mac."); return@readAction }
        val labels = applicable.map { row ->
            val name = row.optString("email").ifBlank { row.optString("id") }
            "${ENGINE_LABELS[row.optString("engine")] ?: row.optString("engine")} · $name" + if (row.optBoolean("active")) "  •  Active" else ""
        }
        AlertDialog.Builder(this).setTitle(if (chat == null) "Default account on This Mac" else "Account for this chat")
            .setItems(labels.toTypedArray()) { _, index ->
                val account = applicable[index]; val current = project; val thread = chat
                if (thread != null && current != null) {
                    readAction({ target -> api(target, "chat.account", "workspace" to current.id, "chat" to thread, "account" to account.getString("id")) }) { connectionText("Account changed for this conversation.") }
                } else {
                    readAction({ target -> api(target, "account.switch", "engine" to account.getString("engine"), "account" to account.getString("id")) }) { connectionText("Default account changed on your Mac.") }
                }
            }.setNegativeButton("Cancel", null).show()
    }

    private fun showIntegrations() = readAction({ target -> items(api(target, "integrations"), "servers") }) { servers ->
        val text = if (servers.isEmpty()) "No MCP integrations configured on your Mac."
        else servers.joinToString("\n\n") { row ->
            row.optString("name") + "\n" + if (row.optBoolean("enabled")) row.optString("state", "Enabled") else "Off"
        }
        AlertDialog.Builder(this).setTitle("MCP integrations").setMessage(text)
            .setPositiveButton("Done", null).show()
    }

    private fun queueRefresh(delay: Long) {
        main.removeCallbacks(sync)
        main.postDelayed(sync, delay)
    }

    private fun refresh() {
        if (!visible || !connected) return
        if (loading) { refreshAgain = true; return }
        val target = link ?: return
        val current = version
        val currentProject = project
        val currentChat = chat
        val currentDrawerList = drawerList
        loading = true
        reads.execute {
            val result = runCatching {
                val list = if (currentProject == null) fetchProjects(target) else null
                val page = if (currentChat != null && currentProject != null)
                    api(target, "history", "workspace" to currentProject.id, "chat" to currentChat) else null
                val chats = if (currentDrawerList != null && currentProject != null)
                    pages(target, "chats", "chats", 50, "workspace" to currentProject.id) else null
                Triple(list, page, chats)
            }
            main.post {
                if (isDestroyed) return@post
                loading = false
                if (current == version && visible) result.onSuccess { (list, page, chats) ->
                    if (list != null) {
                        projects = list
                        if (project == null && list.size == 1) selectProject(list.single())
                        else if (project == null) renderHistory()
                    }
                    if (chats != null && currentDrawerList != null && drawerList === currentDrawerList && currentProject != null) {
                        renderDrawerChats(currentDrawerList, currentProject, chats)
                    }
                    if (page != null) {
                        page.optJSONObject("settings")?.let { applyChatSettings(it) }
                        val next = items(page, "messages")
                        val revision = next.map(JSONObject::toString)
                        if (revision != history.map(JSONObject::toString)) {
                            earlier = mergeEarlierHistory(earlier, history, next)
                            history = next
                            val cursor = page.optInt("before")
                            before = if (earlier.isEmpty()) cursor else minOf(before, cursor)
                            renderHistory()
                        }
                    }
                }.onFailure { if (!busy) connectionText(it.display()) }
                if (refreshAgain) {
                    refreshAgain = false
                    queueRefresh(75)
                }
            }
        }
    }

    private fun fetchProjects(target: Link): List<Project> = pages(target, "projects", "projects", 50)
        .map { Project(it.getString("id"), it.getString("name")) }

    private fun chooseProject() = readAction({ target -> fetchProjects(target) }) { found ->
        projects = found
        if (found.isEmpty()) {
            connectionText("Add a project in Opscode on your Mac.")
            return@readAction
        }
        AlertDialog.Builder(this).setTitle("Projects").setItems(found.map { it.name }.toTypedArray()) { _, i ->
            if (project?.id == found[i].id) return@setItems
            if (draftPresent()) confirmReset { selectProject(found[i]) } else selectProject(found[i])
        }.setNegativeButton("Cancel", null).show()
    }

    private fun selectProject(next: Project) {
        project = next
        selectChat(null, "", confirm = false)
    }

    private fun chooseChat() {
        val current = project ?: return
        readAction({ target -> pages(target, "chats", "chats", 50, "workspace" to current.id) }) { found ->
            if (project != current) return@readAction
            if (found.isEmpty()) {
                connectionText("This project has no conversations yet.")
                return@readAction
            }
            val names = found.map { row ->
                row.optString("title").ifBlank { "New chat" } + if (row.optBoolean("running")) "  •  Running" else ""
            }
            AlertDialog.Builder(this).setTitle("Chats").setItems(names.toTypedArray()) { _, i ->
                val row = found[i]
                selectChat(row.getString("id"), row.optString("title"), settings = row)
            }.setNegativeButton("Cancel", null).show()
        }
    }

    private fun selectChat(id: String?, name: String, confirm: Boolean = true, settings: JSONObject? = null) {
        if (confirm && draftPresent()) {
            confirmReset { selectChat(id, name, confirm = false, settings = settings) }
            return
        }
        version++
        chat = id
        chatTitle = name
        mode = "supervised"
        team = settings?.optString("team")?.takeIf { it.isNotBlank() } ?: "normal"
        engine = null
        settings?.let(::applyChatSettings)
        earlier = emptyList()
        history = emptyList()
        fullMessageTexts.clear()
        before = 0
        sentRequest = null
        composer.text.clear()
        files.clear()
        projectFiles.clear()
        renderAttachments()
        renderHistory()
        updateControls()
        queueRefresh(0)
    }

    private fun showPlugins() = readAction({ target -> pages(target, "plugins", "plugins", 40) }) { found ->
        val listing = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(23), dp(2), dp(23), dp(12))
        }
        if (found.isEmpty()) listing.addView(label("No plugins installed on this Mac.", 14, MUTED))
        for (plugin in found) {
            val name = plugin.optString("name") + if (plugin.optBoolean("enabled")) "  •  Enabled" else "  •  Off"
            listing.addView(label(name, 15, INK).apply { setPadding(0, dp(14), 0, dp(5)) })
            listing.addView(label(plugin.optString("description"), 13, MUTED))
        }
        AlertDialog.Builder(this).setTitle("Mac plugins").setView(ScrollView(this).apply { addView(listing) })
            .setPositiveButton("Done", null).show()
    }

    private fun chooseEngine() = readAction({ target -> items(api(target, "engines"), "engines") }) { found ->
        val choices = if (chat == null) listOf(JSONObject().put("label", "Mac default")) + found else found
        if (choices.isEmpty()) {
            connectionText("Set up an engine or API provider in Opscode on your Mac.")
            return@readAction
        }
        AlertDialog.Builder(this).setTitle("Engine and model").setItems(choices.map { it.getString("label") }.toTypedArray()) { _, i ->
            val choice = choices[i]
            val id = choice.optString("id")
            if (id.isEmpty()) applyEngine(null)
            else chooseModel(EnginePick(id, choice.getString("label")), items(choice, "models"))
        }.setNegativeButton("Cancel", null).show()
    }

    private fun chooseModel(pick: EnginePick, models: List<JSONObject>) {
        if (models.isEmpty()) { applyEngine(pick); return }
        val names = listOf("Default model") + models.map { it.getString("label") }
        AlertDialog.Builder(this).setTitle(pick.label).setItems(names.toTypedArray()) { _, i ->
            val model = models.getOrNull(i - 1)
            if (model == null) applyEngine(pick)
            else {
                val next = pick.copy(label = model.getString("label"), model = model.getString("id"))
                val values = model.optJSONArray("efforts")
                val efforts = if (values != null) List(values.length()) { values.getString(it) } else emptyList()
                if (efforts.isEmpty()) applyEngine(next)
                else AlertDialog.Builder(this).setTitle("Reasoning effort")
                    .setItems((listOf("Default") + efforts.map { it.replaceFirstChar(Char::uppercase) }).toTypedArray()) { _, choice ->
                        applyEngine(next.copy(effort = efforts.getOrNull(choice - 1)))
                    }.setNegativeButton("Cancel", null).show()
            }
        }.setNegativeButton("Cancel", null).show()
    }

    private fun applyEngine(pick: EnginePick?) {
        val current = project ?: return
        val thread = chat
        if (thread == null) {
            engine = pick
            updateControls()
            return
        }
        if (pick == null) return
        readAction({ target -> api(target, "chat.engine", "workspace" to current.id, "chat" to thread,
            "engine" to pick.id, "model" to pick.model, "effort" to pick.effort) }) { result ->
            if (project == current && chat == thread) result.optJSONObject("settings")?.let(::applyChatSettings)
        }
    }

    private fun chooseMode() {
        val labels = MODES.map { "${it.title}\n${it.summary}" }
        val dialog = AlertDialog.Builder(this).setTitle("Permissions")
        dialog.setSingleChoiceItems(labels.toTypedArray(), MODES.indexOfFirst { it.id == mode }) { sheet, i ->
            sheet.dismiss()
            val chosen = MODES[i].id
            if (chosen != mode) {
                if (chosen == "full") AlertDialog.Builder(this).setTitle("Give this chat full access?")
                    .setMessage("The Mac agent can edit files and run commands without asking you first.")
                    .setNegativeButton("Cancel", null).setPositiveButton("Use full access") { _, _ -> applyMode(chosen) }.show()
                else applyMode(chosen)
            }
        }.setNegativeButton("Cancel", null).show()
    }

    private fun applyMode(chosen: String) {
        val current = project ?: return
        val thread = chat
        if (thread == null) {
            mode = chosen
            updateControls()
        } else {
            readAction({ target -> api(target, "chat.mode", "workspace" to current.id, "chat" to thread, "mode" to chosen) }) { result ->
                if (project == current && chat == thread) result.optJSONObject("settings")?.let(::applyChatSettings)
            }
        }
    }

    private fun applyChatSettings(settings: JSONObject) {
        chatTitle = settings.optString("title", chatTitle)
        mode = settings.optString("mode", "supervised")
        val id = settings.optString("engine", "api")
        val model = settings.optString("model").ifBlank { null }
        engine = EnginePick(id, model ?: ENGINE_LABELS[id] ?: id, model, settings.optString("effort").ifBlank { null })
        title.text = chatTitle.ifBlank { "Conversation" }
        updateControls()
    }

    private fun loadEarlier() {
        val current = project ?: return
        val thread = chat ?: return
        val cursor = before
        readAction({ target -> api(target, "history", "workspace" to current.id, "chat" to thread, "before" to cursor) }) { page ->
            if (current != project || thread != chat) return@readAction
            earlier = items(page, "messages") + earlier
            before = page.optInt("before")
            renderHistory(follow = false)
        }
    }

    private fun renderHistory(follow: Boolean = true) {
        val nearBottom = scroll.getChildAt(0)?.let { it.height - scroll.height - scroll.scrollY < dp(100) } ?: true
        transcript.removeAllViews()
        title.text = if (chat == null) "" else chatTitle.ifBlank { "Conversation" }
        title.visibility = if (chat == null) View.GONE else View.VISIBLE
        if (history.isEmpty() && earlier.isEmpty()) {
            val empty = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(dp(17), dp(22), dp(17), dp(22))
                if (chat == null) background = object : android.graphics.drawable.Drawable() {
                    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                    override fun draw(canvas: Canvas) {
                        val step = dp(23).coerceAtLeast(1)
                        for (y in 0 until bounds.height() step step) for (x in 0 until bounds.width() step step) {
                            val dx = (x - bounds.width() / 2f) / (bounds.width() * .58f)
                            val dy = (y - bounds.height() / 2f) / (bounds.height() * .58f)
                            val alpha = (30 * (1f - (dx * dx + dy * dy)).coerceIn(0f, 1f)).toInt()
                            paint.color = Color.argb(alpha, 236, 128, 90)
                            canvas.drawCircle(x.toFloat(), y.toFloat(), dp(1).toFloat(), paint)
                        }
                    }
                    override fun setAlpha(alpha: Int) = Unit
                    override fun setColorFilter(filter: android.graphics.ColorFilter?) = Unit
                    @Deprecated("Deprecated in Android") override fun getOpacity() = android.graphics.PixelFormat.TRANSLUCENT
                }
            }
            if (chat == null && project != null) empty.addView(ImageView(this).apply {
                setImageResource(R.drawable.opscode_chat_robot)
                scaleType = ImageView.ScaleType.FIT_CENTER
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            }, LinearLayout.LayoutParams(dp(96), dp(96)).apply { gravity = Gravity.CENTER; bottomMargin = dp(14) })
            empty.addView(label(
                when {
                    chat != null -> "Loading conversation…"
                    project != null -> "What should we build in ${project?.name}?"
                    else -> "Choose a project"
                }, 26, INK).apply {
                gravity = Gravity.CENTER
                typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            })
            if (chat == null) empty.addView(label(if (project != null) "You and one model." else "Your Mac projects appear here.", 14, MUTED).apply {
                gravity = Gravity.CENTER
                setPadding(0, dp(10), 0, 0)
            })
            transcript.addView(empty, LinearLayout.LayoutParams(-1, 0, 1f))
        } else {
            if (before > 0) transcript.addView(control("Load earlier messages") { loadEarlier() })
            // Live snapshots overlap historical pages. Keep the copy from the latest snapshot.
            val rows = (earlier + history).associateBy { it.optString("turn") + ":" + it.optString("role") }.values
            val running = history.lastOrNull()?.takeIf { it.optString("status") == "streaming" }
            for (item in rows) {
                val user = item.optString("role") == "user"
                val block = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(dp(12), dp(9), dp(12), dp(10))
                    if (user) background = panel(SURFACE, 14)
                }
                block.addView(label(if (user) "You" else if (item.optString("status") == "streaming") "Opscode  •  Working" else "Opscode",
                    12, if (user) MUTED else GREEN))
                val revision = item.optString("revision")
                val body = (fullMessageTexts[revision] ?: item.optString("text")).ifBlank { item.optString("error").ifBlank { "…" } }
                block.addView(label(body, 15, INK).apply { setTextIsSelectable(true); setPadding(0, dp(5), 0, 0) })
                if (revision.isNotEmpty() && !fullMessageTexts.containsKey(revision)) {
                    block.addView(control("Show full message") { loadFullMessage(item) })
                }
                for (file in items(item, "files")) {
                    val photo = file.optString("kind") == "image"
                    block.addView(control(file.optString("name"), if (photo) "Preview photo" else "Save attachment") {
                        if (photo) previewPhoto(item, file) else openSave(item, file)
                    })
                }
                if (item === running) block.addView(control("Stop task") { stopTask(item.optString("turn")) })
                transcript.addView(block, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(8); bottomMargin = dp(6) })
            }
        }
        if (follow && nearBottom) scroll.post { scroll.fullScroll(View.FOCUS_DOWN) }
    }

    private fun loadFullMessage(item: JSONObject) {
        val current = project ?: return
        val thread = chat ?: return
        val revision = item.optString("revision")
        val initial = item.optString("text")
        val length = item.optInt("text_length")
        if (revision.isEmpty() || length <= initial.length) return
        connectionText("Loading the full message from your Mac…")
        readAction({ target ->
            val result = StringBuilder(initial)
            while (result.length < length) {
                val chunk = api(target, "history.text", "workspace" to current.id, "chat" to thread,
                    "index" to item.getInt("index"), "turn" to item.getString("turn"), "role" to item.getString("role"),
                    "revision" to revision, "offset" to result.length)
                if (chunk.getInt("offset") != result.length) throw CompanionFailure("The conversation changed. Refresh and try again.")
                val text = chunk.getString("text")
                if (text.isEmpty() || result.length + text.length > length) throw CompanionFailure("The message could not be loaded completely.")
                result.append(text)
            }
            result.toString()
        }) { text ->
            if (project == current && chat == thread) {
                fullMessageTexts[revision] = text
                connectionText("Connected to ${link?.label ?: "your Mac"}")
                renderHistory(follow = false)
            }
        }
    }

    private fun stopTask(turn: String) {
        val current = project ?: return
        val thread = chat ?: return
        readAction({ target -> api(target, "stop", "workspace" to current.id, "chat" to thread, "turn" to turn) }) {
            if (it.optBoolean("interrupted")) connectionText("Stopping task…")
            queueRefresh(0)
        }
    }

    private fun chooseAttachment() {
        AlertDialog.Builder(this).setTitle("Add to chat")
            .setItems(arrayOf("Project files on This Mac", "Photos on phone", "Files on phone")) { _, choice ->
                if (choice == 0) browseProjectFiles("") else pickFiles(if (choice == 1) "image/*" else "*/*")
            }
            .setNegativeButton("Cancel", null).show()
    }

    private fun browseProjectFiles(path: String) {
        val current = project ?: return
        readAction({ target -> api(target, "project.files", "workspace" to current.id, "path" to path) }) { result ->
            val entries = items(result, "entries")
            val names = entries.map { (if (it.optString("kind") == "dir") "▱  " else "   ") + it.getString("name") }
            val options = (if (path.isNotEmpty()) listOf("‹  Parent folder") else emptyList()) + names
            if (options.isEmpty()) { connectionText("This folder is empty."); return@readAction }
            AlertDialog.Builder(this).setTitle(if (path.isEmpty()) "This Mac · ${current.name}" else path)
                .setItems(options.toTypedArray()) { _, index ->
                    if (path.isNotEmpty() && index == 0) browseProjectFiles(path.substringBeforeLast('/', ""))
                    else {
                        val entry = entries[index - if (path.isNotEmpty()) 1 else 0]
                        val selected = listOf(path, entry.getString("name")).filter { it.isNotEmpty() }.joinToString("/")
                        if (entry.optString("kind") == "dir") browseProjectFiles(selected)
                        else if (files.size + projectFiles.size >= 6) connectionText("Attach up to six files at a time.")
                        else { if (!projectFiles.contains(selected)) projectFiles.add(selected); renderAttachments() }
                    }
                }.setNegativeButton("Done", null).show()
        }
    }

    private fun pickFiles(mimeType: String) {
        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            type = mimeType
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }, OPEN_FILES)
    }

    private fun openSave(item: JSONObject, file: JSONObject) {
        val current = project ?: return
        val currentChat = chat ?: return
        val name = file.optString("name")
        savedDownload = Download(current.id, currentChat, item.optString("turn"), file.optInt("index"), name)
        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            type = "application/octet-stream"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_TITLE, name)
        }, SAVE_FILE)
    }

    private fun previewPhoto(item: JSONObject, file: JSONObject) {
        val current = project ?: return
        val thread = chat ?: return
        val selected = Download(current.id, thread, item.optString("turn"), file.optInt("index"), file.optString("name"))
        readAction({ target ->
            val out = java.io.ByteArrayOutputStream()
            readDownload(target, selected, out)
            val bytes = out.toByteArray()
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw CompanionFailure("This photo could not be opened.")
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 1536) sample *= 2
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
                ?: throw CompanionFailure("This photo could not be opened.")
        }) { image ->
            if (project != current || chat != thread) return@readAction
            AlertDialog.Builder(this).setTitle(selected.name)
                .setView(ImageView(this).apply {
                    adjustViewBounds = true
                    scaleType = ImageView.ScaleType.FIT_CENTER
                    maxHeight = dp(440)
                    contentDescription = selected.name
                    setImageBitmap(image)
                })
                .setPositiveButton("Save") { _, _ -> openSave(item, file) }
                .setNegativeButton("Close", null).show()
        }
    }

    @Deprecated("Uses platform document-picker results.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK || data == null) return
        if (requestCode == OPEN_FILES) {
            val clip = data.clipData
            val selected = if (clip == null) listOfNotNull(data.data) else List(clip.itemCount) { clip.getItemAt(it).uri }
            for (uri in selected.distinct().take((6 - files.size - projectFiles.size).coerceAtLeast(0))) {
                if (files.none { it.uri == uri }) files.add(Attachment(uri, attachmentName(uri)))
            }
            if (selected.size > 6) connectionText("Attach up to six files at a time.")
            renderAttachments()
        } else if (requestCode == SAVE_FILE) {
            val selected = savedDownload ?: return
            savedDownload = null
            data.data?.let { download(selected, it) }
        }
    }

    private fun attachmentName(uri: Uri): String {
        val name = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor: Cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
        return name.orEmpty().replace(Regex("[\\\\/\\p{Cntrl}]"), "_").trim().trimStart('.').take(100).ifBlank { "attachment" }
    }

    private fun renderAttachments() {
        attachments.removeAllViews()
        for (path in projectFiles.toList()) {
            attachments.addView(control("Mac · $path  ×", "Remove $path") {
                if (!busy) { projectFiles.remove(path); renderAttachments() }
            })
        }
        for (item in files) {
            val row = horizontal()
            if (Build.VERSION.SDK_INT >= 29 && contentResolver.getType(item.uri)?.startsWith("image/") == true) {
                val preview = ImageView(this).apply {
                    scaleType = ImageView.ScaleType.CENTER_CROP
                    importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                }
                row.addView(preview, LinearLayout.LayoutParams(dp(36), dp(36)).apply { marginStart = dp(6) })
                reads.execute {
                    val image = runCatching { contentResolver.loadThumbnail(item.uri, Size(144, 144), null) }.getOrNull()
                    if (image != null) main.post { if (preview.isAttachedToWindow) preview.setImageBitmap(image) }
                }
            }
            row.addView(control(item.name + "  ×", "Remove ${item.name}") {
                if (busy) return@control
                files.remove(item)
                val upload = item.upload
                val target = link
                if (upload != null && target != null) transfers.execute { runCatching { api(target, "upload.cancel", "id" to upload) } }
                renderAttachments()
            })
            attachments.addView(row)
        }
    }

    private fun send() {
        val target = link ?: return
        val current = project ?: return
        val text = composer.text.toString().trim()
        if (busy || !connected || (text.isEmpty() && files.isEmpty() && projectFiles.isEmpty())) return
        val currentChat = chat
        val selectedEngine = engine.takeIf { currentChat == null }
        val selectedMode = mode
        val selectedTeam = team
        val selected = files.toList()
        val selectedProjectFiles = projectFiles.toList()
        val signature = JSONArray(listOf(text, selectedEngine?.toString(), selectedMode, selectedTeam, selected.map { it.uri.toString() }, selectedProjectFiles)).toString()
        val requestId = sentRequest?.takeIf { it.first == signature }?.second
            ?: UUID.randomUUID().toString().also { sentRequest = signature to it }
        busy = true
        updateControls()
        connectionText(if (selected.isEmpty()) "Sending…" else "Sending attachments…")
        transfers.execute {
            val result = runCatching {
                for (item in selected) {
                    val previous = item.upload
                    if (previous == null || !api(target, "upload.status", "id" to previous).optBoolean("ready")) {
                        item.upload = upload(target, current.id, item)
                    }
                }
                api(target, "submit", "workspace" to current.id, "chat" to currentChat,
                    "id" to requestId, "text" to text.ifEmpty { "Use the attached files." },
                    "files" to JSONArray(selected.map { it.upload }), "projectFiles" to JSONArray(selectedProjectFiles), "engine" to selectedEngine?.id, "model" to selectedEngine?.model,
                    "effort" to selectedEngine?.effort, "mode" to selectedMode.takeIf { currentChat == null }, "team" to selectedTeam.takeIf { currentChat == null && it != "normal" })
            }
            main.post {
                if (isDestroyed) return@post
                busy = false
                result.onSuccess { response ->
                    val thread = response.getString("chat")
                    if (thread != chat) selectChat(thread, text.take(80).ifBlank { "New task" }, confirm = false, settings = JSONObject().put("team", selectedTeam))
                    else {
                        composer.text.clear()
                        files.clear()
                        projectFiles.clear()
                        renderAttachments()
                    }
                    sentRequest = null
                    connectionText("Sent to ${target.label}")
                    queueRefresh(0)
                }.onFailure { connectionText(it.display()) }
                updateControls()
            }
        }
    }

    private fun upload(target: Link, workspace: String, item: Attachment): String {
        val temp = File.createTempFile("opscode-attachment", null, cacheDir)
        var id: String? = null
        try {
            val input = contentResolver.openInputStream(item.uri) ?: throw CompanionFailure("This attachment is unavailable.")
            input.use { source ->
                temp.outputStream().use { sink ->
                    val bytes = ByteArray(CHUNK)
                    var size = 0
                    while (true) {
                        val count = source.read(bytes)
                        if (count < 0) break
                        size += count
                        if (size > FILE_LIMIT) throw CompanionFailure("Choose a file up to 10 MB.")
                        sink.write(bytes, 0, count)
                    }
                }
            }
            id = api(target, "upload.begin", "workspace" to workspace, "name" to item.name, "size" to temp.length()).getString("id")
            temp.inputStream().use { source ->
                val data = ByteArray(CHUNK)
                var offset = 0L
                while (true) {
                    val size = source.read(data)
                    if (size < 0) break
                    val encoded = Base64.encodeToString(data, 0, size, Base64.NO_WRAP)
                    val response = api(target, "upload.chunk", "id" to id, "offset" to offset, "data" to encoded)
                    if (response.getLong("offset") != offset + size) throw CompanionFailure("Attachment transfer lost its place.")
                    offset += size
                }
            }
            return id
        } catch (error: Exception) {
            id?.let { runCatching { api(target, "upload.cancel", "id" to it) } }
            throw error
        } finally { temp.delete() }
    }

    private fun download(selected: Download, destination: Uri) {
        val target = link ?: return
        transfers.execute {
            val result = runCatching {
                val temp = File.createTempFile("opscode-download", null, cacheDir)
                try {
                    temp.outputStream().use { readDownload(target, selected, it) }
                    val out = contentResolver.openOutputStream(destination, "wt") ?: throw CompanionFailure("Android couldn’t open the save location.")
                    out.use { sink -> temp.inputStream().use { it.copyTo(sink) } }
                } finally {
                    temp.delete()
                }
            }
            main.post { if (!isDestroyed) connectionText(result.fold({ "Saved ${selected.name}" }, { it.display() })) }
        }
    }

    private fun readDownload(target: Link, selected: Download, output: java.io.OutputStream) {
        val reply = api(target, "download.begin", "workspace" to selected.workspace, "chat" to selected.chat,
            "turn" to selected.turn, "index" to selected.index)
        val id = reply.getString("id")
        val size = reply.getLong("size")
        try {
            if (size !in 0..FILE_LIMIT.toLong()) throw CompanionFailure("This attachment is too large to download on mobile.")
            var offset = 0L
            while (offset < size) {
                val next = api(target, "download.chunk", "id" to id, "offset" to offset)
                val bytes = Base64.decode(next.getString("data"), Base64.NO_WRAP)
                val end = next.getLong("offset")
                if (end <= offset || end > size || end != offset + bytes.size) throw CompanionFailure("Download lost its place.")
                output.write(bytes)
                offset = end
            }
        } finally {
            runCatching { api(target, "download.end", "id" to id) }
        }
    }

    private fun <T> readAction(action: (Link) -> T, apply: (T) -> Unit) {
        val target = link ?: return
        if (!connected) return
        reads.execute {
            val result = runCatching { action(target) }
            main.post {
                if (!visible || isDestroyed) return@post
                result.onSuccess(apply).onFailure { connectionText(it.display()) }
            }
        }
    }

    private fun api(target: Link, op: String, vararg args: Pair<String, Any?>): JSONObject =
        Desktop.workspace(applicationContext, target, JSONObject().put("op", op).apply {
            for ((key, value) in args) if (value != null) put(key, value)
        })

    private fun pages(target: Link, op: String, field: String, pageSize: Int, vararg args: Pair<String, Any?>): List<JSONObject> {
        val values = mutableListOf<JSONObject>()
        var offset = 0
        while (true) {
            val page = api(target, op, "offset" to offset, *args)
            val next = items(page, field)
            values += next
            if (!page.optBoolean("more")) break
            if (next.isEmpty() || offset > Int.MAX_VALUE - pageSize) throw CompanionFailure("The Mac returned an incomplete list. Try again.")
            offset += pageSize
        }
        return values
    }

    private fun draftPresent() = composer.text.isNotBlank() || files.isNotEmpty() || projectFiles.isNotEmpty()
    private fun confirmReset(action: () -> Unit) {
        AlertDialog.Builder(this).setTitle("Discard this draft?")
            .setPositiveButton("Discard") { _, _ -> action() }.setNegativeButton("Keep writing", null).show()
    }

    private fun connectionText(value: String) { status.text = value }
    private fun updateControls() {
        teamRow.removeAllViews()
        for (id in listOf("normal", "godmode", "warlord", "shinobi")) {
            val button = control(if (id == "normal") "Normal" else id.uppercase(), "${id.uppercase()} team mode") {
                if (chat == null) { team = id; updateControls() } else connectionText("Start a new chat to choose a team mode.")
            }
            val iconId = when (id) { "godmode" -> R.drawable.mode_godmode; "warlord" -> R.drawable.mode_warlord; "shinobi" -> R.drawable.mode_shinobi; else -> R.drawable.opscode_workspace_mark }
            val icon = getDrawable(iconId)?.mutate()
            icon?.setBounds(0, 0, dp(26), dp(26))
            button.setCompoundDrawables(icon, null, null, null)
            button.compoundDrawablePadding = dp(7)
            button.background = panel(if (team == id) 0xff49312b.toInt() else SURFACE, 22)
            button.isEnabled = connected && project != null && !busy
            teamRow.addView(button, LinearLayout.LayoutParams(-2, dp(48)).apply { marginEnd = dp(8) })
        }
        projectContext.text = "▱  ${project?.name ?: "Choose project"}     ▣  This Mac"
        projectButton.text = project?.name ?: "Projects"
        projectButton.isEnabled = connected && !busy
        threadButton.isEnabled = connected && project != null && !busy
        newButton.isEnabled = connected && project != null && !busy
        pluginsButton.isEnabled = !busy
        composer.isEnabled = project != null && !busy
        attachButton.isEnabled = project != null && !busy
        engineButton.isEnabled = connected && project != null && !busy && team == "normal"
        engineButton.text = engine?.label ?: "Mac default"
        modeButton.isEnabled = connected && project != null && !busy && team == "normal"
        modeButton.text = MODES.firstOrNull { it.id == mode }?.short ?: "Supervised"
        sendButton.isEnabled = connected && project != null && !busy
        voiceButton.isEnabled = connected && project != null && !busy
    }

    private fun items(value: JSONObject, field: String): List<JSONObject> = value.optJSONArray(field)?.let { array ->
        List(array.length()) { array.getJSONObject(it) }
    }.orEmpty()

    private fun Throwable.display() = (this as? CompanionFailure)?.message ?: "Opscode couldn’t complete that action."
    private fun dp(n: Int) = (n * resources.displayMetrics.density).roundToInt()
    private fun horizontal() = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
    private fun label(value: String, size: Int, color: Int) = TextView(this).apply {
        text = value
        textSize = size.toFloat()
        setTextColor(color)
        setLineSpacing(dp(3).toFloat(), 1f)
    }
    private fun panel(fill: Int, radius: Int) = GradientDrawable().apply {
        setColor(fill)
        cornerRadius = dp(radius).toFloat()
        setStroke(dp(1), LINE)
    }
    private fun control(value: String, description: String = value, primary: Boolean = false, action: () -> Unit) = Button(this).apply {
        text = value
        contentDescription = description
        isAllCaps = false
        textSize = 13f
        maxLines = 1
        ellipsize = android.text.TextUtils.TruncateAt.END
        minWidth = 0
        minimumWidth = 0
        minHeight = dp(48)
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        setPadding(dp(10), 0, dp(10), 0)
        setTextColor(ColorStateList(
            arrayOf(intArrayOf(-android.R.attr.state_enabled), intArrayOf()),
            intArrayOf(MUTED, if (primary) CANVAS else INK),
        ))
        background = RippleDrawable(ColorStateList.valueOf(0x337f8794), if (primary) panel(INK, 11) else null, panel(SURFACE, 10))
        setOnClickListener { action() }
    }

    companion object {
        private const val OPEN_FILES = 17
        private const val SAVE_FILE = 18
        private const val CHUNK = 36 * 1024
        private const val FILE_LIMIT = 10 * 1024 * 1024
        private val MODES = listOf(
            Mode("read", "Read only", "Read only", "Browse and explain project files."),
            Mode("supervised", "Supervised", "Supervised", "Ask before edits, commands, and tools."),
            Mode("auto_edits", "Auto-accept edits", "Auto edits", "Edits go ahead. Commands and tools ask."),
            Mode("auto", "Auto", "Auto", "Ask before higher-risk actions."),
            Mode("full", "Full access", "Full access", "Actions run without approval prompts."),
        )
        private val ENGINE_LABELS = mapOf(
            "api" to "API key", "claude-code" to "Claude Code", "codex" to "Codex", "antigravity" to "Antigravity", "qoder" to "Qoder",
        )
        private val CANVAS = 0xff_121213.toInt()
        private val SURFACE = 0xff_1a1a1c.toInt()
        private val LINE = 0xff_2c2d32.toInt()
        private val INK = 0xff_e1e3e8.toInt()
        private val MUTED = 0xff_9a9a9f.toInt()
        private val GREEN = 0xff_64ce8d.toInt()
    }
}
