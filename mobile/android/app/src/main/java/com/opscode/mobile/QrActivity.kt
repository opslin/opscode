package com.opscode.mobile

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class QrActivity : ComponentActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val delivered = AtomicBoolean()
    private val scanner by lazy {
        BarcodeScanning.getClient(BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).build())
    }
    private lateinit var camera: PreviewView
    private lateinit var prompt: TextView
    private val permission = registerForActivityResult(ActivityResultContracts.RequestPermission()) {
        if (it) startScanner() else prompt.text = "Camera denied. You can scan a QR image instead."
    }
    private val pickImage = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            val input = runCatching { InputImage.fromFilePath(this, uri) }.getOrNull()
            if (input == null) prompt.text = "Couldn’t open that QR image."
            else scanner.process(input)
                .addOnSuccessListener { hits -> if (!accept(hits)) prompt.text = "No Opscode pairing QR found in that image." }
                .addOnFailureListener { prompt.text = "Couldn’t read that QR image." }
        }
    }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        camera = PreviewView(this).apply {
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        root.addView(camera, FrameLayout.LayoutParams(-1, -1))
        root.addView(Reticle(), FrameLayout.LayoutParams(-1, -1))
        prompt = TextView(this).apply {
            text = "Point at the QR in Opscode on your Mac."
            textSize = 15f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setBackgroundColor(0xdd_0a080a.toInt())
            setPadding(dp(15), dp(12), dp(15), dp(12))
        }
        val controls = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            addView(prompt, -1, -2)
            addView(android.widget.LinearLayout(this@QrActivity).apply {
                gravity = Gravity.CENTER
                addView(android.widget.Button(this@QrActivity).apply {
                    text = "Scan QR image"
                    setOnClickListener { pickImage.launch("image/*") }
                })
                addView(android.widget.Button(this@QrActivity).apply { text = "Cancel"; setOnClickListener { finish() } })
            })
        }
        root.addView(controls, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM).apply { bottomMargin = dp(38) })
        setContentView(root)
        if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) startScanner()
        else permission.launch(Manifest.permission.CAMERA)
    }

    @androidx.annotation.OptIn(ExperimentalGetImage::class)
    private fun startScanner() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            if (isFinishing || isDestroyed) return@addListener
            try {
                val provider = future.get()
                val preview = Preview.Builder().build().also { it.setSurfaceProvider(camera.surfaceProvider) }
                val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysis.setAnalyzer(executor) { frame ->
                    val image = frame.image
                    if (image == null || delivered.get()) frame.close()
                    else scanner.process(InputImage.fromMediaImage(image, frame.imageInfo.rotationDegrees))
                        .addOnSuccessListener { hits -> accept(hits) }
                        .addOnCompleteListener { frame.close() }
                }
                provider.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
            } catch (_: Exception) {
                prompt.text = "Camera unavailable. You can scan a QR image instead."
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun accept(hits: List<Barcode>): Boolean {
        val result = hits.firstNotNullOfOrNull { barcode ->
            barcode.rawValue?.takeIf { runCatching { Invite.decode(it) }.isSuccess }
        } ?: return false
        if (!isDestroyed && delivered.compareAndSet(false, true)) {
            setResult(Activity.RESULT_OK, Intent().putExtra("qr", result))
            finish()
        }
        return true
    }

    override fun onDestroy() {
        delivered.set(true)
        scanner.close()
        executor.shutdown()
        super.onDestroy()
    }

    private fun dp(value: Int) = (resources.displayMetrics.density * value).toInt()

    private inner class Reticle : View(this@QrActivity) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            color = 0xff_ff9a78.toInt()
            strokeWidth = dp(2).toFloat()
        }
        init { importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO }
        override fun onDraw(canvas: Canvas) {
            val side = minOf(width * .7f, height * .53f)
            val left = (width - side) / 2
            val top = (height - side) / 2
            val segment = dp(25).toFloat()
            val right = left + side
            val bottom = top + side
            for ((x, sx) in arrayOf(left to 1, right to -1)) for ((y, sy) in arrayOf(top to 1, bottom to -1)) {
                canvas.drawLine(x, y, x + sx * segment, y, paint)
                canvas.drawLine(x, y, x, y + sy * segment, paint)
            }
        }
    }
}
