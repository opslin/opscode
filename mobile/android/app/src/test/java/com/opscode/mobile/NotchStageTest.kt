package com.opscode.mobile

import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Insets
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.os.Looper
import android.view.DisplayCutout
import android.view.View
import android.view.WindowInsets
import android.widget.ScrollView
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.ceil
import kotlin.math.min
import kotlin.math.roundToInt
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class NotchStageTest {
    @Test
    fun wideCutoutExpandsCompactControlAndKeepsCameraCarve() {
        val stage = stage(width = 1440, height = 2960, density = 3.5f, safeTop = 171,
            camera = Rect(462, 0, 978, 171))

        assertEquals(ceil(516 + 80 * 3.5f).toInt(), stage.intField("compactWidth"))
        assertTrue(stage.hasCameraCarve())
    }

    @Test
    fun compactControlStartsTwelveDpBelowCameraAndSafeArea() {
        val stage = stage(width = 1440, height = 2960, density = 3.5f, safeTop = 171,
            camera = Rect(462, 0, 978, 171))

        assertEquals(171 + (12 * 3.5f).toInt(), stage.intField("top"))
    }

    @Test
    fun punchHoleOnlyAddsSideEars() {
        val stage = stage(width = 1280, height = 2856, density = 3f, safeTop = 156,
            camera = Rect(586, 0, 695, 156))

        assertEquals(ceil(109 + 80 * 3f).toInt(), stage.intField("compactWidth"))
        assertEquals(156 + 12 * 3, stage.intField("top"))
    }

    @Test
    fun circularCameraConnectsToCompactPill() {
        val stage = stage(width = 1280, height = 2856, density = 3f, safeTop = 156,
            camera = Rect(586, 0, 695, 156))
        stage.status(Pose.NEEDS, approvals = 1, working = 0, finished = 0, description = "Opscode")
        val bitmap = Bitmap.createBitmap(1280, 400, Bitmap.Config.ARGB_8888)

        stage.draw(Canvas(bitmap))

        assertEquals("The circular camera and pill should have a filled connecting neck",
            255, Color.alpha(bitmap.getPixel(640, 180)))
    }

    @Test
    fun compactOverlayLeavesTheCameraClearAndLimitsItsWindowHeight() {
        val activity = Robolectric.buildActivity(android.app.Activity::class.java).setup().get()
        val configuration = Configuration(activity.resources.configuration).apply { densityDpi = 160 }
        val context = activity.createConfigurationContext(configuration)
        val stage = NotchStage(context, ScrollView(context), overlay = true) {}
        val bounds = RectF(52f, 5f, 72f, 25f)
        val camera = Path().apply { addOval(bounds, Path.Direction.CW) }
        stage.window(NotchWindow(30, CutoutGeometry(camera, bounds, circular = true), panelSized = false))
        stage.status(Pose.WORKING, approvals = 0, working = 1, finished = 0, description = "Mac is working")
        stage.measure(View.MeasureSpec.makeMeasureSpec(124, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(800, View.MeasureSpec.AT_MOST))
        stage.layout(0, 0, 124, stage.measuredHeight)
        val bitmap = Bitmap.createBitmap(124, stage.measuredHeight, Bitmap.Config.ARGB_8888)
        stage.draw(Canvas(bitmap))

        assertEquals(90, stage.measuredHeight)
        assertEquals(0, Color.alpha(bitmap.getPixel(62, 15)))
        assertEquals(255, Color.alpha(bitmap.getPixel(62, 33)))
    }

    @Test
    fun alertGradientIsReusedAcrossFrames() {
        val stage = stage(width = 1280, height = 2856, density = 3f, safeTop = 156,
            camera = Rect(586, 0, 695, 156))
        stage.status(Pose.NEEDS, approvals = 1, working = 0, finished = 0, description = "Opscode")
        val canvas = Canvas(Bitmap.createBitmap(1280, 400, Bitmap.Config.ARGB_8888))

        stage.draw(canvas)
        val first = stage.field("alertSweep")
        stage.draw(canvas)

        assertSame(first, stage.field("alertSweep"))
    }

    @Test
    fun transitionFlagClearsWhenAnimationFinishes() {
        val stage = stage(width = 1280, height = 2856, density = 3f, safeTop = 156,
            camera = Rect(586, 0, 695, 156))

        stage.show(true)
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(700))

        assertEquals(0L, stage.longField("effectStarted"))
    }

    @Test
    fun noCameraUsesSlightlyLargerBaseline() {
        val stage = stage(width = 1280, height = 2856, density = 3f, safeTop = 84, camera = null)

        assertEquals(104 * 3, stage.intField("compactWidth"))
        assertEquals(84 + 12 * 3, stage.intField("top"))
    }

    @Test
    fun extremeCutoutCannotExceedAvailablePanelWidth() {
        val stage = stage(width = 400, height = 900, density = 3f, safeTop = 156,
            camera = Rect(0, 0, 400, 156))

        assertEquals(400 - 28 * 3, stage.intField("compactWidth"))
    }

    private fun stage(width: Int, height: Int, density: Float, safeTop: Int, camera: Rect?): NotchStage {
        val activity = Robolectric.buildActivity(android.app.Activity::class.java).setup().get()
        val configuration = Configuration(activity.resources.configuration).apply {
            densityDpi = (density * 160).roundToInt()
        }
        val context = activity.createConfigurationContext(configuration)
        val stage = NotchStage(context, ScrollView(context)) {}
        val cutout = DisplayCutout(Insets.of(0, safeTop, 0, 0), null, camera, null, null)
        val insets = WindowInsets.Builder()
            .setInsets(WindowInsets.Type.statusBars(), Insets.of(0, safeTop, 0, 0))
            .setInsets(WindowInsets.Type.navigationBars(), Insets.NONE)
            .setDisplayCutout(cutout)
            .build()
        stage.insets(insets)
        stage.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY),
        )
        stage.layout(0, 0, width, height)
        return stage
    }

    private fun NotchStage.intField(name: String): Int =
        NotchStage::class.java.getDeclaredField(name).apply { isAccessible = true }.getInt(this)

    private fun NotchStage.field(name: String): Any =
        NotchStage::class.java.getDeclaredField(name).apply { isAccessible = true }.get(this)!!

    private fun NotchStage.longField(name: String): Long =
        NotchStage::class.java.getDeclaredField(name).apply { isAccessible = true }.getLong(this)

    private fun NotchStage.hasCameraCarve(): Boolean {
        NotchStage::class.java.getDeclaredMethod("geometry").apply { isAccessible = true }.invoke(this)
        NotchStage::class.java.getDeclaredMethod("panelShape").apply { isAccessible = true }.invoke(this)
        val shape = field("shape") as Path
        val bounds = RectF(field("bounds") as RectF)
        val radius = min(bounds.height() / 2, 16 * resources.displayMetrics.density)
        val rounded = Path().apply { addRoundRect(bounds, radius, radius, Path.Direction.CW) }
        return !Path(rounded).apply { op(shape, Path.Op.DIFFERENCE) }.isEmpty
    }
}
