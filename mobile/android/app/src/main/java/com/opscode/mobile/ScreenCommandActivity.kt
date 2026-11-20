package com.opscode.mobile

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.KeyguardManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.text.InputType
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.roundToInt

class ScreenCommandActivity : Activity() {
    private var speech: SpeechRecognizer? = null
    private var dialog: AlertDialog? = null
    private lateinit var input: EditText
    private lateinit var listen: Button
    private lateinit var status: TextView

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        if (!interactive()) { finish(); return }
        val service = PhoneAccessibility.active
        val target = service?.target()
        if (service == null || target == null) {
            dialog = AlertDialog.Builder(this).setTitle("Opscode Screen")
                .setMessage(if (service == null) "Enable Opscode Screen Control in Android Accessibility."
                    else "Open the app you want to control, then use the Opscode Screen tile.")
                .setNegativeButton("Close") { _, _ -> finish() }
                .setOnCancelListener { finish() }.apply {
                    if (service == null) setPositiveButton("Accessibility settings") { _, _ ->
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        finish()
                    }
                }.show()
            return
        }

        val form = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val side = (24 * resources.displayMetrics.density).roundToInt()
            setPadding(side, 0, side, 0)
        }
        input = EditText(this).apply {
            hint = "Screen command"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO
            setSingleLine(true)
        }
        form.addView(input)
        status = TextView(this).apply { accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE }
        listen = Button(this).apply { text = "Listen"; setOnClickListener { requestListening() } }
        if (Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
            form.addView(listen)
        } else status.text = "On-device speech recognition is unavailable. You can type a command."
        form.addView(status)

        val sheet = AlertDialog.Builder(this).setTitle("Opscode Screen")
            .setMessage("Try “scroll down ten times,” “go back,” “go home,” “play,” or “pause.”")
            .setView(form).setNegativeButton("Cancel") { _, _ -> finish() }
            .setPositiveButton("Run", null).setOnCancelListener { finish() }.create()
        dialog = sheet
        sheet.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN)
        sheet.show()
        sheet.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
            val command = ScreenCommand.parse(input.text.toString())
            if (command == null) { input.error = "Enter one supported command."; return@setOnClickListener }
            if (!interactive() || PhoneAccessibility.active !== service) { finish(); return@setOnClickListener }
            // Close both the sheet and its host before acting on the original app.
            service.run(target, command)
            sheet.dismiss()
            finish()
        }
    }

    private fun requestListening() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), MICROPHONE)
        } else startListening()
    }

    private fun startListening() {
        if (Build.VERSION.SDK_INT < 31 || !interactive() || !SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) return
        releaseSpeech()
        listen.isEnabled = false
        status.text = "Listening…"
        try {
            speech = SpeechRecognizer.createOnDeviceSpeechRecognizer(this).apply {
                setRecognitionListener(object : RecognitionListener {
                    override fun onResults(result: Bundle?) {
                        val candidates = result?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty()
                        val command = candidates.firstNotNullOfOrNull(ScreenCommand::parse)
                        if (command == null) status.text = "Try again or type a command."
                        else {
                            input.setText(command.label())
                            status.text = "Tap Run to confirm."
                        }
                        releaseSpeech()
                    }

                    override fun onError(error: Int) {
                        status.text = "On-device speech is unavailable right now. Try typing."
                        releaseSpeech()
                    }
                    override fun onReadyForSpeech(params: Bundle?) = Unit
                    override fun onBeginningOfSpeech() = Unit
                    override fun onRmsChanged(rmsdB: Float) = Unit
                    override fun onBufferReceived(buffer: ByteArray?) = Unit
                    override fun onEndOfSpeech() { status.text = "Recognizing…" }
                    override fun onPartialResults(partialResults: Bundle?) = Unit
                    override fun onEvent(eventType: Int, params: Bundle?) = Unit
                })
                startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                    .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3))
            }
        } catch (_: RuntimeException) {
            status.text = "On-device speech is unavailable right now. Try typing."
            releaseSpeech()
        }
    }

    private fun releaseSpeech() {
        val current = speech
        speech = null
        current?.destroy()
        if (::listen.isInitialized) listen.isEnabled = true
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, result: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, result)
        if (requestCode != MICROPHONE) return
        if (result.firstOrNull() == PackageManager.PERMISSION_GRANTED) startListening()
        else status.text = "Microphone access is off. You can type a command."
    }

    override fun onStop() {
        releaseSpeech()
        super.onStop()
    }

    override fun onDestroy() {
        dialog?.dismiss()
        super.onDestroy()
    }

    private fun interactive() = getSystemService(PowerManager::class.java).isInteractive &&
        !getSystemService(KeyguardManager::class.java).isKeyguardLocked

    companion object { private const val MICROPHONE = 80 }
}
