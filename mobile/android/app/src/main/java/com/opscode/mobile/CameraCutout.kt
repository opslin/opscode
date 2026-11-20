package com.opscode.mobile

import android.content.Context
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.view.View
import android.view.WindowInsets
import kotlin.math.max
import kotlin.math.min

internal enum class CameraShape { AUTO, CIRCLE, WIDE }

internal data class CameraFit(val x: Int = 0, val y: Int = 0, val width: Int = 0, val height: Int = 0,
    val manual: Boolean = false, val shape: CameraShape = CameraShape.AUTO, val diameter: Int = 0) {
    fun save(context: Context) {
        context.getSharedPreferences("camera-fit", Context.MODE_PRIVATE).edit()
            .putInt("x", x).putInt("y", y).putInt("width", width).putInt("height", height)
            .putBoolean("manual", manual).putString("shape", shape.name).putInt("diameter", diameter).apply()
    }

    companion object {
        fun load(context: Context): CameraFit {
            val saved = context.getSharedPreferences("camera-fit", Context.MODE_PRIVATE)
            val shape = CameraShape.entries.firstOrNull { it.name == saved.getString("shape", null) } ?: CameraShape.AUTO
            return CameraFit(saved.getInt("x", 0), saved.getInt("y", 0), saved.getInt("width", 0),
                saved.getInt("height", 0), saved.getBoolean("manual", false), shape,
                saved.getInt("diameter", if (shape == CameraShape.CIRCLE) saved.getInt("width", 0) else 0))
        }
    }
}

internal class CutoutGeometry(val contour: Path, val bounds: RectF, val circular: Boolean = false) {
    /** Offset the actual contour so the shiny stroke stays outside the pixels the camera occupies. */
    fun outside(gap: Float): Path {
        val stroke = Paint().apply {
            style = Paint.Style.STROKE
            strokeWidth = gap * 2
            strokeJoin = Paint.Join.ROUND
        }
        return Path().also { expanded ->
            stroke.getFillPath(contour, expanded)
            if (!expanded.op(contour, Path.Op.UNION)) expanded.set(contour)
        }
    }
}

internal class NotchInsets(private val insets: WindowInsets) {
    private val location = IntArray(2)
    private val displayLocation = IntArray(2)
    private val cutout = if (Build.VERSION.SDK_INT >= 28) insets.displayCutout else null
    private val statusTop = if (Build.VERSION.SDK_INT >= 30) {
        insets.getInsetsIgnoringVisibility(WindowInsets.Type.statusBars()).top
    } else @Suppress("DEPRECATION") insets.stableInsetTop
    private val navigation = if (Build.VERSION.SDK_INT >= 30) {
        insets.getInsetsIgnoringVisibility(WindowInsets.Type.navigationBars()).let { Rect(it.left, 0, it.right, it.bottom) }
    } else {
        @Suppress("DEPRECATION")
        Rect(insets.stableInsetLeft, 0, insets.stableInsetRight, insets.stableInsetBottom)
    }

    val top: Int get() = max(statusTop, if (Build.VERSION.SDK_INT >= 28) cutout?.safeInsetTop ?: 0 else 0)
    val left: Int get() = max(navigation.left, if (Build.VERSION.SDK_INT >= 28) cutout?.safeInsetLeft ?: 0 else 0)
    val right: Int get() = max(navigation.right, if (Build.VERSION.SDK_INT >= 28) cutout?.safeInsetRight ?: 0 else 0)
    val bottom: Int get() = max(navigation.bottom, if (Build.VERSION.SDK_INT >= 28) cutout?.safeInsetBottom ?: 0 else 0)

    fun topCutout(view: View): CutoutGeometry? {
        view.getLocationInWindow(location)
        view.getLocationOnScreen(displayLocation)
        return topCutout(location[0], location[1], displayLocation[0], displayLocation[1])
    }

    /** Translates full-display metrics into a smaller window's coordinates. */
    fun topCutout(left: Int, top: Int): CutoutGeometry? = topCutout(left, top, left, top)

    private fun topCutout(left: Int, top: Int, displayLeft: Int, displayTop: Int): CutoutGeometry? {
        if (Build.VERSION.SDK_INT < 28) return null
        val display = cutout ?: return null
        val rect = if (Build.VERSION.SDK_INT >= 29) display.boundingRectTop else {
            if (display.safeInsetTop == 0) return null
            display.boundingRects.firstOrNull { it.top >= 0 && it.bottom <= max(statusTop, display.safeInsetTop) } ?: return null
        }
        if (rect.isEmpty) return null

        // Insets bounds are in the window; the outline returned by Android is in display pixels.
        val bounds = RectF(rect).apply { offset(-left.toFloat(), -top.toFloat()) }
        val exact = if (Build.VERSION.SDK_INT >= 31) display.cutoutPath?.let { raw ->
            val clip = Path().apply { addRect(bounds, Path.Direction.CW) }
            val outline = Path(raw).apply { offset(-displayLeft.toFloat(), -displayTop.toFloat()) }
            outline.takeIf { it.op(clip, Path.Op.INTERSECT) && !it.isEmpty }
        } else null
        if (exact != null) {
            val size = RectF()
            @Suppress("DEPRECATION")
            exact.computeBounds(size, true)
            if (!size.isEmpty) {
                val detached = size.top > -displayTop + 1f
                return CutoutGeometry(exact, size, detached && size.width() / size.height() in .80f..1.25f)
            }
        }
        return approximate(bounds)
    }
}

internal fun fittedCutout(original: CutoutGeometry?, fit: CameraFit, width: Int, safeTop: Int, density: Float): CutoutGeometry? {
    var source = original ?: if (fit.manual) {
        val x = width * .5f
        val y = max(safeTop * .5f, 10 * density)
        val radius = 8 * density
        approximate(RectF(x - radius, y - radius, x + radius, y + radius))
    } else return null
    if (fit.shape != CameraShape.AUTO) source = approximate(source.bounds, fit.shape)
    val b = source.bounds
    val adjusted = RectF(b).apply {
        val w = (b.width() + (if (fit.shape == CameraShape.CIRCLE) fit.diameter else fit.width) * density)
            .coerceAtLeast(5 * density)
        val h = if (fit.shape == CameraShape.CIRCLE) w else (b.height() + fit.height * density).coerceAtLeast(5 * density)
        val x = (b.centerX() + fit.x * density).coerceIn(0f, width.toFloat())
        val y = b.centerY() + fit.y * density
        set(x - w / 2, y - h / 2, x + w / 2, y + h / 2)
    }
    if (adjusted == b) return source
    val change = Matrix().apply { setRectToRect(b, adjusted, Matrix.ScaleToFit.FILL) }
    val shape = Path(source.contour).apply { transform(change) }
    return CutoutGeometry(shape, adjusted, source.circular && adjusted.width() / adjusted.height() in .80f..1.25f)
}

private fun approximate(bounds: RectF, shape: CameraShape = CameraShape.AUTO): CutoutGeometry {
    val outline = Path()
    val ratio = bounds.width() / bounds.height()
    val circular = shape == CameraShape.CIRCLE || shape == CameraShape.AUTO && ratio in .55f..1.45f
    val outlineBounds = if (circular) {
        val diameter = min(bounds.width(), bounds.height())
        RectF(bounds.centerX() - diameter / 2, bounds.centerY() - diameter / 2,
            bounds.centerX() + diameter / 2, bounds.centerY() + diameter / 2)
    } else RectF(bounds)
    if (circular) {
        outline.addOval(outlineBounds, Path.Direction.CW)
    } else {
        val corner = min(outlineBounds.width() * .31f, outlineBounds.height() * .85f)
        outline.addRoundRect(outlineBounds, floatArrayOf(0f, 0f, 0f, 0f, corner, corner, corner, corner), Path.Direction.CW)
    }
    return CutoutGeometry(outline, outlineBounds, circular)
}
