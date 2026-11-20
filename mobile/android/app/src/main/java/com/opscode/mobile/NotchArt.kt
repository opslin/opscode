package com.opscode.mobile

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Matrix
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.os.SystemClock
import android.view.Choreographer
import android.view.View
import android.view.WindowInsets
import android.view.animation.PathInterpolator
import android.widget.FrameLayout
import android.widget.ScrollView
import kotlin.math.ceil
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.random.Random

internal enum class Pose(val fps: Int) { SLEEPING(4), WORKING(9), NEEDS(10), DONE(12), ERROR(12) }

internal fun notchFrameDelay(animated: Boolean, shown: Boolean, focused: Boolean, glowing: Boolean,
    transitioning: Boolean, poseFps: Int): Long? {
    if (!animated || !shown || !focused) return null
    if (transitioning) return 0
    if (glowing) return 33
    return (1000 / poseFps).toLong()
}

internal data class NotchWindow(val safeTop: Int, val cutout: CutoutGeometry?, val panelSized: Boolean)

internal class NotchStage(context: Context, val panel: ScrollView, private val overlay: Boolean = false,
    onToggle: () -> Unit) : FrameLayout(context) {
    private val density = resources.displayMetrics.density
    private val hit = View(context).apply {
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
        accessibilityClassNameForButton()
        isFocusable = true
        setOnClickListener { onToggle() }
    }
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val squares = Paint()
    private val sprite = EmberSprite()
    private val dissolve = DissolveBatcher(dissolveColors)
    private val bounds = RectF()
    private val shape = Path()
    private val connectedShape = Path()
    private val connectedBounds = RectF()
    private val neck = Path()
    private var joinedFraction = Float.NaN
    private var drawnFraction = Float.NaN
    private val sweep = Matrix()
    private val alertSweep = SweepGradient(0f, 0f, shineColors, shinePositions)
    private val chevron = Path()
    private val cameraColor = 0xff_ffa98e.toInt()
    private val focusStroke = 0xff_ffb48a.toInt()
    private val startCurve = PathInterpolator(.32f, 1.22f, .42f, 1f)
    private val endCurve = PathInterpolator(.45f, 0f, .2f, 1f)
    private var safeInsets: NotchInsets? = null
    private var notchWindow: NotchWindow? = null
    private var automaticCutout: CutoutGeometry? = null
    private var cutout: CutoutGeometry? = null
    private var cameraStroke: Path? = null
    private var fit = CameraFit()
    private var fitting = false
    private var openWidth = 0
    private var compactWidth = 0
    private var top = 0
    private var center = 0f
    private var compactCenter = 0f
    private val bandHeight = px(48)
    private var fraction = 0f
    private var animation: ValueAnimator? = null
    private var effectStarted = 0L
    private var lastPose = SystemClock.uptimeMillis()
    private var tiles: List<Tile> = emptyList()
    private var pose = Pose.SLEEPING
    private var approvals = 0
    private var working = 0
    private var finished = 0
    private var description = "Opscode"
    private var expanded = false
    private val hasCompact get() = approvals > 0 || overlay && (pose == Pose.WORKING || pose == Pose.ERROR)
    private val canAnimate get() = overlay || hasWindowFocus()
    private val choreographer = Choreographer.getInstance()
    private var framePending = false
    private var lastFrameNanos = 0L
    private val redraw = Choreographer.FrameCallback { frameTimeNanos ->
        framePending = false
        if (isShown && canAnimate) {
            lastFrameNanos = frameTimeNanos
            invalidate()
        }
    }

    init {
        setWillNotDraw(false)
        clipChildren = false
        clipToPadding = false
        panel.clipToPadding = false
        panel.importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        panel.visibility = INVISIBLE
        addView(panel)
        addView(hit)
    }

    fun insets(insets: WindowInsets) {
        safeInsets = NotchInsets(insets)
        requestLayout()
    }

    fun window(value: NotchWindow) {
        notchWindow = value
        requestLayout()
    }

    fun hasTopCutout(): Boolean = automaticCutout != null

    fun cameraFit(value: CameraFit, preview: Boolean = false) {
        fit = value
        fitting = preview
        requestLayout()
        invalidate()
    }

    fun status(pose: Pose, approvals: Int, working: Int, finished: Int, description: String) {
        if (this.pose != pose) lastPose = SystemClock.uptimeMillis()
        this.pose = pose
        this.approvals = approvals
        this.working = working
        this.finished = finished
        this.description = description
        updateAccessibility()
        updateFrame()
    }

    fun show(open: Boolean, animated: Boolean = true, onFinished: () -> Unit = {}) {
        if (expanded == open && animation == null) {
            onFinished()
            return
        }
        expanded = open
        cancelFrame()
        val previous = animation
        animation = null
        previous?.cancel()
        updateAccessibility()
        if (!animated || !ValueAnimator.areAnimatorsEnabled() || openWidth == 0) {
            fraction = if (open) 1f else 0f
            effectStarted = 0L
            updateFrame()
            onFinished()
            return
        }

        if (!open && panel.hasFocus()) hit.requestFocus()
        effectStarted = SystemClock.uptimeMillis()
        // Keep the fine pixel effect under the camera and across the first rows.
        tiles = buildTiles(openWidth, min(bandHeight + panel.measuredHeight, px(176)))
        animation = ValueAnimator.ofFloat(fraction, if (open) 1f else 0f).apply {
            duration = if (open) 520 else 340
            interpolator = if (open) startCurve else endCurve
            addUpdateListener {
                fraction = (it.animatedValue as Float).coerceIn(0f, 1.035f)
                updateFrame()
            }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    effectStarted = 0L
                    tiles = emptyList()
                    if (this@NotchStage.animation === animation) {
                        this@NotchStage.animation = null
                        onFinished()
                    }
                    invalidate()
                }
            })
            start()
        }
    }

    fun refreshAnimation() = invalidate()

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val w = MeasureSpec.getSize(widthMeasureSpec)
        val h = MeasureSpec.getSize(heightMeasureSpec)
        val insets = safeInsets
        val safeTop = notchWindow?.safeTop ?: insets?.top ?: 0
        automaticCutout = if (overlay) notchWindow?.cutout else insets?.topCutout(this)
        // Center a comfortable panel between side cutouts in landscape and narrow windows.
        val left = (insets?.left ?: 0).coerceAtMost(w / 2)
        val right = w - (insets?.right ?: 0).coerceAtMost(w / 2)
        val span = right - left
        center = (left + right) / 2f
        openWidth = min(px(352), max(1, span - px(if (overlay) 12 else 28)))
        val appliedFit = if (overlay || w > h && automaticCutout == null) fit.copy(manual = false) else fit
        cutout = fittedCutout(automaticCutout, appliedFit, w, safeTop, density)
        cameraStroke = cutout?.outside(px(2f))
        joinedFraction = Float.NaN
        drawnFraction = Float.NaN
        compactWidth = min(openWidth, max(px(104), ceil((cutout?.bounds?.width() ?: 0f) + px(80)).toInt()))
        val indent = compactWidth / 2f + px(8)
        compactCenter = (cutout?.bounds?.centerX() ?: center)
            .coerceIn(min(center, left + indent), max(center, right - indent))
        top = max(safeTop, ceil(cutout?.bounds?.bottom ?: 0f).toInt()) + px(12)
        val contentWidth = max(1, openWidth - px(12))
        val contentHeight = (h - top - bandHeight - (insets?.bottom ?: 0) - px(13)).coerceAtLeast(0)
        panel.measure(exact(contentWidth), MeasureSpec.makeMeasureSpec(contentHeight, MeasureSpec.AT_MOST))
        hit.measure(exact(openWidth), exact(bandHeight))
        val measuredHeight = top + bandHeight + if (notchWindow?.panelSized == true) panel.measuredHeight + px(13) else 0
        setMeasuredDimension(w, if (overlay) min(h, measuredHeight) else h)
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        val innerLeft = (center - panel.measuredWidth / 2f).roundToInt()
        panel.layout(innerLeft, top + bandHeight, innerLeft + panel.measuredWidth, top + bandHeight + panel.measuredHeight)
        updateFrame()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val now = SystemClock.uptimeMillis()
        val animated = ValueAnimator.areAnimatorsEnabled()
        val elapsed = if (animated) now - lastPose else 0L
        val camera = cutout
        val connected = hasCompact && !fitting && fraction < .16f && camera?.circular == true &&
            abs(camera.bounds.centerX() - compactCenter) < compactWidth / 2f - px(15)
        if ((hasCompact || fitting) && !connected) drawCameraOutline(canvas, elapsed)
        if (fitting || (fraction <= 0f && !hasCompact)) {
            cancelFrame()
            return
        }

        val compact = fraction <= 0f
        if (drawnFraction != fraction) {
            geometry()
            panelShape()
            drawnFraction = fraction
        }
        val contour = if (connected) connectedCompactShape() else shape
        paint.style = Paint.Style.FILL
        paint.shader = null
        paint.color = Color.BLACK
        canvas.save()
        if (connected) canvas.clipOutPath(checkNotNull(cutout).contour)
        canvas.drawPath(contour, paint)
        if (hasCompact || pose == Pose.ERROR) {
            drawAlertContour(canvas, contour, if (connected) connectedBounds else bounds, elapsed, compact)
        } else drawQuietRing(canvas, elapsed, contour)
        canvas.restore()

        val dy = lerp(bounds.centerY(), top + px(31f), fraction.coerceIn(0f, 1f))
        val spriteScale = max(1, px(if (compact) 1f else 1.5f).roundToInt()).toFloat()
        if (compact || fraction >= .4f) {
            sprite.draw(canvas, bounds.left + px(if (compact) 9 else 13), dy - 8 * spriteScale,
                spriteScale, pose, (elapsed * pose.fps / 1000).toInt())
            if (compact) {
                chevron.reset()
                val x = bounds.centerX()
                chevron.moveTo(x - px(3f), dy - px(1f))
                chevron.lineTo(x, dy + px(2f))
                chevron.lineTo(x + px(3f), dy - px(1f))
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = px(1.2f)
                paint.color = 0xff_eab6aa.toInt()
                canvas.drawPath(chevron, paint)
                if (approvals > 0) drawBadge(canvas, dy, approvals, isAlert = true)
                else drawStatus(canvas, dy, elapsed)
            } else drawStatus(canvas, dy, elapsed)
        }
        if (hit.isFocused && !isInTouchMode) {
            paint.shader = null
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = px(1.5f)
            paint.color = focusStroke
            canvas.drawPath(shape, paint)
        }
        when (val delay = notchFrameDelay(animated, isShown, canAnimate,
            glowing = approvals > 0 || pose == Pose.DONE && elapsed < 1_100,
            transitioning = effectStarted != 0L, poseFps = pose.fps)) {
            null -> cancelFrame()
            0L -> Unit // ValueAnimator already invalidates on every display frame.
            else -> scheduleFrame(delay)
        }
    }

    override fun dispatchDraw(canvas: Canvas) {
        if (fraction <= 0f || fitting) return
        canvas.save()
        canvas.clipPath(shape)
        super.dispatchDraw(canvas)
        drawDissolve(canvas)
        canvas.restore()
    }

    override fun onWindowFocusChanged(hasWindowFocus: Boolean) {
        super.onWindowFocusChanged(hasWindowFocus)
        if (hasWindowFocus) invalidate() else cancelFrame()
    }

    override fun onDetachedFromWindow() {
        cancelFrame()
        val previous = animation
        animation = null
        previous?.cancel()
        super.onDetachedFromWindow()
    }

    private fun scheduleFrame(delayMs: Long) {
        if (framePending) return
        val now = System.nanoTime()
        val interval = delayMs * 1_000_000L
        val previous = lastFrameNanos.takeIf { now - it in 0..interval * 2 } ?: now
        // Queue shortly before the target vsync. Waiting the whole interval in onDraw
        // misses that vsync and turns a 30 fps request into roughly 20 fps at 60 Hz.
        val waitMs = ((previous + interval - now) / 1_000_000L - 3).coerceAtLeast(0)
        framePending = true
        choreographer.postFrameCallbackDelayed(redraw, waitMs)
    }

    private fun cancelFrame() {
        if (!framePending) return
        choreographer.removeFrameCallback(redraw)
        framePending = false
        lastFrameNanos = 0L
    }

    private fun updateFrame() {
        panel.alpha = ((fraction - .22f) / .72f).coerceIn(0f, 1f)
        panel.visibility = if ((fraction > 0f || expanded) && !fitting) VISIBLE else INVISIBLE
        panel.importantForAccessibility = if (expanded && !fitting) IMPORTANT_FOR_ACCESSIBILITY_AUTO else IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        hit.visibility = if (!fitting && (expanded || hasCompact)) VISIBLE else INVISIBLE
        val x = if (expanded) center else compactCenter
        val half = (if (expanded) openWidth else compactWidth) / 2f
        hit.layout((x - half).roundToInt(), top, (x + half).roundToInt(), top + bandHeight)
        invalidate()
    }

    private fun updateAccessibility() {
        hit.contentDescription = "$description. ${if (expanded) "Close notch" else "Open notch"}"
        if (android.os.Build.VERSION.SDK_INT >= 30) hit.stateDescription = if (expanded) "Expanded" else "Collapsed"
    }

    private fun geometry() {
        val half = lerp(compactWidth / 2f, openWidth / 2f, fraction)
        val x = lerp(compactCenter, center, fraction)
        val upper = lerp(top + px(5f), top.toFloat(), fraction)
        val lower = lerp(top + px(36f), (top + bandHeight + panel.measuredHeight + px(5)).toFloat(), fraction.coerceAtMost(1f))
        bounds.set(x - half, upper, x + half, lower)
    }

    private fun panelShape() {
        val radius = min(bounds.height() / 2, lerp(px(16f), px(34f), fraction))
        val camera = cutout?.bounds
        val depth = lerp(px(4f), px(11f), fraction)
        val x = if (camera == null) 0f else lerp(compactCenter, camera.centerX(), fraction)
        val room = min(x - bounds.left, bounds.right - x) - radius - px(3)
        val shoulder = camera?.let {
            min(room, lerp(
                (it.width() / 2f + px(6)).coerceAtLeast(px(20f)),
                (it.width() / 2f + px(11)).coerceAtLeast(px(20f)),
                fraction
            ))
        }
        shape.reset()
        if (shoulder == null || shoulder < px(10f)) {
            shape.addRoundRect(bounds, radius, radius, Path.Direction.CW)
            return
        }
        val l = bounds.left
        val t = bounds.top
        val r = bounds.right
        val b = bounds.bottom
        shape.moveTo(l + radius, t)
        shape.lineTo(x - shoulder, t)
        shape.cubicTo(x - shoulder * .63f, t, x - shoulder * .55f, t + depth, x, t + depth)
        shape.cubicTo(x + shoulder * .55f, t + depth, x + shoulder * .63f, t, x + shoulder, t)
        shape.lineTo(r - radius, t)
        shape.quadTo(r, t, r, t + radius)
        shape.lineTo(r, b - radius)
        shape.quadTo(r, b, r - radius, b)
        shape.lineTo(l + radius, b)
        shape.quadTo(l, b, l, b - radius)
        shape.lineTo(l, t + radius)
        shape.quadTo(l, t, l + radius, t)
        shape.close()
    }

    private fun connectedCompactShape(): Path {
        if (joinedFraction == fraction) return connectedShape
        val camera = checkNotNull(cutout)
        val outline = checkNotNull(cameraStroke)
        val taper = 1f - fraction / .16f
        val half = min(camera.bounds.width() * .21f, px(11f)) * taper
        val x = camera.bounds.centerX()
        val upper = camera.bounds.bottom - px(2f)
        val shoulder = bounds.top + px(1f)
        val lower = bounds.top + px(9f)
        val base = min(bounds.width() * .26f, px(29f)) * taper
        val panelX = bounds.centerX()
        val curveY = lerp(upper, shoulder, .53f)
        neck.apply {
            rewind()
            moveTo(x - half, upper)
            cubicTo(x - half * .76f, curveY, panelX - base * .63f, shoulder, panelX - base, shoulder)
            lineTo(panelX - base, lower)
            lineTo(panelX + base, lower)
            lineTo(panelX + base, shoulder)
            cubicTo(panelX + base * .63f, shoulder, x + half * .76f, curveY, x + half, upper)
            close()
        }
        connectedShape.set(outline)
        connectedShape.op(neck, Path.Op.UNION)
        connectedShape.op(shape, Path.Op.UNION)
        connectedBounds.set(bounds)
        connectedBounds.union(camera.bounds)
        joinedFraction = fraction
        return connectedShape
    }

    private fun drawCameraOutline(canvas: Canvas, elapsed: Long) {
        val camera = cutout ?: return
        val outline = cameraStroke ?: return
        canvas.save()
        canvas.clipOutPath(camera.contour)
        if (fitting) {
            paint.shader = null
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = px(1.15f)
            paint.color = cameraColor
            canvas.drawPath(outline, paint)
        } else drawAlertContour(canvas, outline, camera.bounds, elapsed, compact = true)
        canvas.restore()
    }

    private fun drawAlertContour(canvas: Canvas, contour: Path, area: RectF, elapsed: Long, compact: Boolean) {
        val pulse = .7f + .3f * kotlin.math.cos(elapsed / 1800f * 2 * Math.PI).toFloat()
        val tint = if (overlay) when (pose) {
            Pose.WORKING -> 0xff_79c5ff.toInt()
            Pose.ERROR -> 0xff_ffbb66.toInt()
            else -> null
        } else null
        paint.style = Paint.Style.STROKE
        paint.strokeJoin = Paint.Join.ROUND
        for ((stroke, alpha) in glowStrokes) {
            paint.strokeWidth = px(stroke * if (compact) .48f else .82f)
            paint.color = ((alpha * pulse).toInt() shl 24) or ((tint ?: 0xff_ff2f23.toInt()) and 0x00ff_ffff)
            canvas.drawPath(contour, paint)
        }
        paint.strokeWidth = px(if (compact) .82f else 1f)
        paint.color = if (tint != null) ((225 * pulse).toInt() shl 24) or (tint and 0x00ff_ffff)
            else if (compact) 0xff_9b4a3f.toInt() else 0xff_713429.toInt()
        canvas.drawPath(contour, paint)
        if (tint != null) return
        val angle = elapsed % 2200 * (360f / 2200)
        sweep.setRotate(angle)
        sweep.postTranslate(area.centerX(), area.centerY())
        alertSweep.setLocalMatrix(sweep)
        paint.shader = alertSweep
        paint.color = Color.WHITE
        canvas.drawPath(contour, paint)
        paint.shader = null
    }

    private fun drawQuietRing(canvas: Canvas, elapsed: Long, contour: Path = shape) {
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = px(1f)
        paint.color = 0xff_353238.toInt()
        if (pose == Pose.DONE && elapsed < 1100) {
            val middle = bounds.left + bounds.width() * (elapsed / 1100f)
            paint.shader = LinearGradient(middle - px(42), top.toFloat(), middle + px(42), top.toFloat(),
                intArrayOf(0xff_353238.toInt(), 0xff_ffddbc.toInt(), 0xff_353238.toInt()), null, Shader.TileMode.CLAMP)
        }
        canvas.drawPath(contour, paint)
        paint.shader = null
    }

    private fun drawStatus(canvas: Canvas, y: Float, elapsed: Long) {
        if (approvals == 0 && working == 0 && finished == 0) {
            squares.color = 0xff_4c494d.toInt()
            val x = bounds.right - px(25)
            canvas.drawRect(x, y - px(2), x + px(4), y + px(2), squares)
            return
        }
        if (approvals > 0 || working > 0) {
            val positions = ledPositions
            val x = bounds.right - px(if (approvals > 0) 48 else 28)
            val active = (elapsed / 120 % positions.size).toInt()
            for ((index, position) in positions.withIndex()) {
                val dx = x + (position % 3) * px(4)
                val dy = y - px(5) + (position / 3) * px(4)
                squares.color = when (index) {
                    active -> if (approvals > 0) 0xff_ff6b60.toInt() else 0xff_ffdcbd.toInt()
                    (active + positions.lastIndex) % positions.size -> if (approvals > 0) 0xff_8a271c.toInt() else 0xff_9b583a.toInt()
                    else -> 0xff_32201e.toInt()
                }
                canvas.drawRect(dx, dy, dx + px(2.5f), dy + px(2.5f), squares)
            }
        }
        val count = if (approvals > 0) approvals else finished
        if (count > 0) drawBadge(canvas, y, count, approvals > 0)
    }

    private fun drawBadge(canvas: Canvas, y: Float, count: Int, isAlert: Boolean) {
        val x = bounds.right - px(15)
        paint.style = Paint.Style.FILL
        paint.color = if (isAlert) 0xff_ff3b30.toInt() else Color.WHITE
        canvas.drawRoundRect(x - px(7), y - px(7), x + px(7), y + px(7), px(4f), px(4f), paint)
        Ember.number(canvas, squares, x, y, px(1.55f), count, if (isAlert) Color.WHITE else Color.BLACK)
    }

    // Port of the desktop notch's radial, randomly delayed 8-pixel cells and ember colors.
    private data class Tile(val x: Float, val y: Float, val at: Float, val base: Int, val hot: Int?)
    private fun buildTiles(width: Int, height: Int): List<Tile> {
        val cell = px(8)
        val anchorX = (cutout?.bounds?.centerX()?.minus(center - width / 2f) ?: (width / 2f)).coerceIn(0f, width.toFloat())
        val columns = ceil(width.toFloat() / cell).toInt()
        val travel = hypot(width / 2f, height.toFloat())
        if (travel <= 0f) return emptyList()
        val random = Random(SystemClock.uptimeMillis().toInt())
        return List(columns * ceil(height.toFloat() / cell).toInt()) { i ->
            val x = (i % columns * cell).toFloat()
            val y = (i / columns * cell).toFloat()
            val distance = hypot(x + cell / 2f - anchorX, y) / travel
            val r = random.nextFloat()
            val hot = when {
                r > .97f -> 5
                r > .94f -> 6
                r > .90f -> 7
                else -> null
            }
            Tile(x, y, distance * 300 + r * 160, random.nextInt(5), hot)
        }
    }

    private fun drawDissolve(canvas: Canvas) {
        if (effectStarted == 0L || !ValueAnimator.areAnimatorsEnabled()) return
        val elapsed = SystemClock.uptimeMillis() - effectStarted
        if (elapsed > if (expanded) 630 else 340) {
            effectStarted = 0L
            return
        }
        val time = if (expanded) elapsed.toFloat() else 630f * (1 - elapsed / 340f)
        val origin = center - openWidth / 2f
        val cell = px(8)
        dissolve.begin()
        for (tile in tiles) {
            val decay = (time - tile.at) / 170
            if (decay >= 1f) continue
            val k = max(0f, decay)
            val color = if (decay in 0f..0.55f) tile.hot ?: tile.base else tile.base
            val alpha = ((1 - k) * 255).roundToInt()
            val inset = px(2f) * k
            val x = origin + tile.x
            val y = top + tile.y
            dissolve.add(color, alpha, x + inset, y + inset, x + cell - inset, y + cell - inset)
        }
        dissolve.draw(canvas, squares)
        squares.alpha = 255
    }

    private fun View.accessibilityClassNameForButton() {
        accessibilityDelegate = object : AccessibilityDelegate() {
            override fun onInitializeAccessibilityNodeInfo(host: View, info: android.view.accessibility.AccessibilityNodeInfo) {
                super.onInitializeAccessibilityNodeInfo(host, info)
                info.className = android.widget.Button::class.java.name
            }
        }
    }

    private fun px(value: Int) = (value * density).roundToInt()
    private fun px(value: Float) = value * density
    private fun exact(value: Int) = MeasureSpec.makeMeasureSpec(max(0, value), MeasureSpec.EXACTLY)
    private fun lerp(a: Float, b: Float, t: Float) = a + (b - a) * t

    private companion object {
        val glowStrokes = listOf(11f to 17, 7f to 23, 3f to 39)
        val ledPositions = intArrayOf(0, 1, 2, 5, 8, 7, 6, 3)
        val dissolveColors = intArrayOf(Color.BLACK, 0xff_050101.toInt(), 0xff_0d0302.toInt(),
            0xff_1a0604.toInt(), 0xff_2b0905.toInt(), 0xff_ffb48a.toInt(), 0xff_ff6a3d.toInt(), 0xff_ff3b30.toInt())
        val shineColors = intArrayOf(0x00_ff3b30, 0x00_ff3b30, 0xff_ff3b30.toInt(), 0xff_ffe3d4.toInt(), 0xff_ff3b30.toInt(), 0x00_ff3b30)
        val shinePositions = floatArrayOf(0f, .54f, .74f, .81f, .86f, 1f)
    }
}

internal class DissolveBatcher(private val colors: IntArray) {
    private val paths = arrayOfNulls<Path>(colors.size * 16)
    private val active = BooleanArray(paths.size)
    var batchCount = 0
        private set

    fun begin() {
        for (index in paths.indices) {
            if (active[index]) paths[index]?.rewind()
            active[index] = false
        }
        batchCount = 0
    }

    fun add(color: Int, alpha: Int, left: Float, top: Float, right: Float, bottom: Float) {
        val level = (alpha.coerceIn(0, 255) * 15 + 127) / 255
        if (level == 0) return
        val index = color * 16 + level
        if (!active[index]) {
            active[index] = true
            batchCount++
        }
        val path = paths[index] ?: Path().also { paths[index] = it }
        path.addRect(left, top, right, bottom, Path.Direction.CW)
    }

    fun draw(canvas: Canvas, paint: Paint) {
        for (index in paths.indices) {
            if (!active[index]) continue
            paint.color = colors[index / 16]
            paint.alpha = (index % 16) * 255 / 15
            canvas.drawPath(checkNotNull(paths[index]), paint)
        }
    }
}

private class EmberSprite {
    private val image = Bitmap.createBitmap(18, 16, Bitmap.Config.ARGB_8888)
    private val raster = Canvas(image)
    private val ink = Paint()
    private val pixelPaint = Paint().apply { isFilterBitmap = false }
    private val target = RectF()
    private var lastPose: Pose? = null
    private var lastFrame = -1

    fun draw(canvas: Canvas, left: Float, top: Float, scale: Float, pose: Pose, frame: Int) {
        if (pose != lastPose || frame != lastFrame) {
            image.eraseColor(Color.TRANSPARENT)
            Ember.draw(raster, ink, 0f, 0f, 1f, pose, frame)
            lastPose = pose
            lastFrame = frame
        }
        target.set(left.roundToInt().toFloat(), top.roundToInt().toFloat(),
            left.roundToInt() + image.width * scale, top.roundToInt() + image.height * scale)
        canvas.drawBitmap(image, null, target, pixelPaint)
    }
}

private object Ember {
    private val body = arrayOf(
        "....bbbb.....", "..dbbbbbbbd..", ".dbhhbbbbbbd.", ".dbhbbbbbbbd.",
        ".dbbbbbbbbbd.", ".dbbbbbbbbbd.", ".dbbbbbbbbbd.", ".ddbbbbbbbdd.",
        "..ddddddddd..", "...d.....d..."
    )
    private val shades = mapOf('b' to 0xff_ff5a36.toInt(), 'h' to 0xff_ffa27a.toInt(), 'd' to 0xff_c9301c.toInt())
    private val flame = arrayOf(
        arrayOf(Triple(0,0,0), Triple(0,-1,1), Triple(1,-1,0), Triple(0,-2,2)),
        arrayOf(Triple(0,0,0), Triple(-1,-1,0), Triple(0,-1,1), Triple(-1,-2,2), Triple(0,-3,2)),
        arrayOf(Triple(0,0,0), Triple(0,-1,1), Triple(1,-2,0), Triple(1,-3,2))
    )
    private val warm = intArrayOf(0xff_ff8a3d.toInt(), 0xff_ffd166.toInt(), 0xff_ff3b30.toInt())
    private val ink = 0xff_1b0705.toInt()
    private val mouth = 0xff_5b0f08.toInt()
    private val hops = intArrayOf(0,-2,-3,-2,0,0,0,0)
    private val shakes = intArrayOf(0,1,0,-1)
    private val digits = arrayOf("111101101101111","010110010010111","111001111100111","111001111001111",
        "101101111001001","111100111001111","111100111101111","111001010010010","111101111101111","111101111001111")

    fun draw(canvas: Canvas, paint: Paint, left: Float, top: Float, scale: Float, pose: Pose, frame: Int) {
        val dx = if (pose == Pose.ERROR) shakes[frame % shakes.size] else 0
        val dy = when (pose) {
            Pose.SLEEPING -> if (frame % 8 < 4) 0 else 1
            Pose.WORKING -> if (frame % 4 == 1) -1 else 0
            Pose.DONE -> hops[frame % hops.size]
            else -> 0
        }
        fun dot(x: Int, y: Int, color: Int) {
            val l = left + x * scale
            val t = top + y * scale
            paint.color = color
            canvas.drawRect(l, t, l + scale, t + scale, paint)
        }
        body.forEachIndexed { row, line ->
            line.forEachIndexed pixel@{ column, mark ->
                val color = shades[mark] ?: return@pixel
                val dimmed = if (pose == Pose.SLEEPING) Color.rgb((Color.red(color) * .72f).toInt(),
                    (Color.green(color) * .72f).toInt(), (Color.blue(color) * .72f).toInt()) else color
                dot(2 + dx + column, 4 + dy + row, dimmed)
            }
        }
        if (pose == Pose.ERROR || (pose == Pose.SLEEPING && frame % 6 < 3)) dot(8 + dx, 3 + dy, warm[0])
        else for ((x, y, index) in flame[frame % 3]) dot(8 + dx + x, 3 + dy + y, warm[index])
        for (eye in intArrayOf(5,10)) {
            val x = eye + dx
            val y = 7 + dy
            when (pose) {
                Pose.SLEEPING -> { dot(x,y+1,ink); dot(x+1,y+1,ink) }
                Pose.DONE -> { dot(x,y+1,ink); dot(x+1,y,ink); dot(x+2,y+1,ink) }
                Pose.ERROR -> { dot(x,y,ink); dot(x+2,y,ink); dot(x+1,y+1,ink); dot(x,y+2,ink); dot(x+2,y+2,ink) }
                else -> {
                    for (sx in 0..1) for (sy in 0..1) dot(x+sx,y+sy,Color.WHITE)
                    val look = if (pose == Pose.WORKING) frame / 6 % 4 else 0
                    dot(x + if (look >= 2) 1 else 0, y + if (look == 3) 0 else 1, ink)
                }
            }
        }
        dot(8 + dx, 10 + dy, mouth)
        when (pose) {
            Pose.NEEDS -> {
                dot(8,11,mouth); dot(14,7,shades.getValue('b'))
                val raised = frame % 4 < 2
                dot(15,if (raised) 6 else 7,shades.getValue('b'))
                dot(if (raised) 15 else 16,if (raised) 5 else 6,shades.getValue('h'))
                if (frame % 6 < 4) for (row in intArrayOf(0,1,2,4)) dot(2,row,warm[2])
            }
            Pose.WORKING -> if (frame % 3 == 0) dot(6 + frame % 5,0,warm[1])
            Pose.DONE -> {
                dot(7,10+dy,mouth); dot(9,10+dy,mouth)
                arrayOf(1 to 3, 16 to 2, 15 to 9, 0 to 10).forEachIndexed { i, (x, y) ->
                    if ((frame + i * 2) % 6 < 2) dot(x,y,0xff_ffe9b0.toInt())
                }
            }
            Pose.ERROR -> dot(9+dx,10,mouth)
            Pose.SLEEPING -> if (frame % 12 < 6) {
                val drift = frame % 12 / 2
                for ((x, y) in arrayOf(0 to 0, 1 to 0, 2 to 0, 1 to 1, 0 to 2, 1 to 2, 2 to 2)) {
                    dot(14+x,6-drift+y,0xff_788197.toInt())
                }
            }
        }
    }

    fun number(canvas: Canvas, paint: Paint, cx: Float, cy: Float, scale: Float, count: Int, color: Int) {
        paint.color = color
        val glyph = digits[count.coerceIn(0,9)]
        glyph.forEachIndexed { i, pixel ->
            if (pixel == '0') return@forEachIndexed
            val x = cx + (i % 3 - 1.5f) * scale
            val y = cy + (i / 3 - 2.5f) * scale
            canvas.drawRect(x,y,x+scale,y+scale,paint)
        }
    }
}
