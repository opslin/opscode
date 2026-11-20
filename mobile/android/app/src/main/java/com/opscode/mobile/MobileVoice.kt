package com.opscode.mobile

import android.annotation.SuppressLint
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.util.Base64
import org.json.JSONObject
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/** Captures and plays audio locally; all speech recognition and generation run on the paired Mac. */
internal class MobileVoice(
    private val call: (String, JSONObject) -> JSONObject,
    private val report: (String) -> Unit,
    private val onClosed: () -> Unit,
) : AutoCloseable {
    private val alive = AtomicBoolean(true)
    private val audio = LinkedBlockingQueue<JSONObject>(120)
    private val generation = AtomicInteger(0)
    @Volatile private var recorder: AudioRecord? = null
    @Volatile private var track: AudioTrack? = null
    @Volatile private var started = false
    private var echo: AcousticEchoCanceler? = null

    fun start(project: String, chat: String?, engine: String?, model: String?, effort: String?, mode: String) {
        Thread({
            try {
                call("voice.start", JSONObject().put("workspace", project).put("mode", mode).apply {
                    if (chat != null) put("chat", chat)
                    if (engine != null) put("engine", engine)
                    if (model != null) put("model", model)
                    if (effort != null) put("effort", effort)
                })
                started = true
                if (!alive.get()) { runCatching { call("voice.stop", JSONObject()) }; return@Thread }
                report("Voice mode connected to This Mac")
                Thread({ capture() }, "opscode-microphone").start()
                Thread({ play() }, "opscode-speaker").start()
                poll()
            } catch (e: Exception) {
                if (alive.get()) report(e.message ?: "Voice mode could not connect.")
            } finally { close() }
        }, "opscode-voice").start()
    }

    @SuppressLint("MissingPermission")
    private fun capture() {
        try {
            val min = AudioRecord.getMinBufferSize(16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
            check(min > 0) { "Microphone is unavailable." }
            val mic = AudioRecord(MediaRecorder.AudioSource.VOICE_COMMUNICATION, 16000, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, maxOf(min, 12800))
            recorder = mic
            check(mic.state == AudioRecord.STATE_INITIALIZED) { "Microphone is unavailable." }
            if (AcousticEchoCanceler.isAvailable()) echo = AcousticEchoCanceler.create(mic.audioSessionId)?.apply { enabled = true }
            mic.startRecording()
            val bytes = ByteArray(3200)
            while (alive.get()) {
                val count = mic.read(bytes, 0, bytes.size)
                if (count <= 0) throw IllegalStateException("Microphone stopped.")
                call("voice.audio", JSONObject().put("pcm", Base64.encodeToString(bytes, 0, count, Base64.NO_WRAP)))
            }
        } catch (e: Exception) {
            if (alive.get()) { report(e.message ?: "Microphone stopped."); close() }
        }
    }

    private fun poll() {
        var ack = 0L
        while (alive.get()) {
            val response = call("voice.poll", JSONObject().put("ack", ack))
            if (!response.has("seq")) { Thread.sleep(100); continue }
            val event = response.getJSONObject("event")
            when (event.optString("ev")) {
                "audio", "done" -> if (!audio.offer(event, 2, TimeUnit.SECONDS)) throw IllegalStateException("Voice playback fell behind.")
                "stop_audio" -> {
                    generation.incrementAndGet(); audio.clear()
                    track?.let { runCatching { it.pause(); it.flush(); it.play() } }
                    runCatching { call("voice.playback", JSONObject().put("playing", false)) }
                }
                "partial", "heard", "say" -> event.optString("text").takeIf { it.isNotBlank() }?.let(report)
                "ended" -> { report("Voice mode ended on your Mac."); return }
                "error" -> report(event.optString("message", "Voice error on your Mac."))
            }
            ack = response.getLong("seq")
        }
    }

    private fun play() {
        var rate = 0
        var playing = false
        var writtenFrames = 0L
        var playbackGeneration = generation.get()
        try {
            while (alive.get()) {
                val event = audio.poll(200, TimeUnit.MILLISECONDS) ?: continue
                if (playbackGeneration != generation.get()) { playbackGeneration = generation.get(); writtenFrames = 0; playing = false }
                if (event.optString("ev") == "done") {
                    val deadline = System.currentTimeMillis() + 30_000
                    while (alive.get() && playbackGeneration == generation.get() && track != null && track!!.playbackHeadPosition.toLong() < writtenFrames && System.currentTimeMillis() < deadline) Thread.sleep(30)
                    if (playing) { call("voice.playback", JSONObject().put("playing", false)); playing = false }
                    continue
                }
                val nextRate = event.optInt("rate", 24000)
                if (track == null || nextRate != rate) {
                    track?.release()
                    rate = nextRate
                    writtenFrames = 0
                    val min = AudioTrack.getMinBufferSize(rate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
                    check(min > 0) { "Speaker is unavailable." }
                    track = AudioTrack.Builder().setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                        .setAudioFormat(AudioFormat.Builder().setSampleRate(rate).setEncoding(AudioFormat.ENCODING_PCM_16BIT).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                        .setBufferSizeInBytes(maxOf(min, rate / 2)).setTransferMode(AudioTrack.MODE_STREAM).build().also { it.play() }
                }
                if (!playing) { call("voice.playback", JSONObject().put("playing", true)); playing = true }
                if (event.optBoolean("first")) call("voice.progress", JSONObject().put("tts", event.optString("tts")).put("played", event.optInt("i") + 1))
                val bytes = Base64.decode(event.getString("pcm"), Base64.NO_WRAP)
                var offset = 0
                while (offset < bytes.size && alive.get()) {
                    val written = track?.write(bytes, offset, bytes.size - offset) ?: -1
                    if (written <= 0) throw IllegalStateException("Speaker stopped.")
                    offset += written
                    writtenFrames += written / 2
                }
            }
        } catch (e: Exception) {
            if (alive.get()) { report(e.message ?: "Voice playback stopped."); close() }
        }
    }

    override fun close() {
        if (!alive.getAndSet(false)) return
        runCatching { recorder?.stop() }
        runCatching { recorder?.release() }
        runCatching { echo?.release() }
        runCatching { track?.stop() }
        runCatching { track?.release() }
        if (started) Thread({ runCatching { call("voice.stop", JSONObject()) } }, "opscode-voice-stop").start()
        onClosed()
    }
}
