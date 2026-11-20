package com.opscode.mobile

import android.content.Context
import android.graphics.Path
import android.graphics.RectF
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class CameraCutoutTest {
    @Test
    fun circleDiameterDoesNotStretchWhenOtherShapeSizesAreSaved() {
        val bounds = RectF(570f, 24f, 644f, 98f)
        val reported = CutoutGeometry(Path().apply { addOval(bounds, Path.Direction.CW) }, bounds, true)
        val value = CameraFit(x = 2, y = -1, width = 28, height = -12, shape = CameraShape.CIRCLE, diameter = 4)

        val adjusted = checkNotNull(fittedCutout(reported, value, width = 1200, safeTop = 120, density = 3f))
        assertEquals(86f, adjusted.bounds.width(), 0f)
        assertEquals(86f, adjusted.bounds.height(), 0f)
        assertEquals(613f, adjusted.bounds.centerX(), 0f)
        assertEquals(58f, adjusted.bounds.centerY(), 0f)
    }

    @Test
    fun savedCircleShapeOverridesWideReportedCutout() {
        val context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("camera-fit", Context.MODE_PRIVATE).edit()
            .clear().putString("shape", "CIRCLE").commit()
        val bounds = RectF(462f, 0f, 978f, 171f)
        val reported = CutoutGeometry(Path().apply {
            addRoundRect(bounds, 42f, 42f, Path.Direction.CW)
        }, RectF(bounds))

        val fitted = fittedCutout(reported, CameraFit.load(context), 1440, 171, 3.5f)
        val expected = RectF(634.5f, 0f, 805.5f, 171f)
        val difference = Path().apply {
            addOval(expected, Path.Direction.CW)
            op(checkNotNull(fitted).contour, Path.Op.XOR)
        }

        assertTrue("Saved Circle mode should replace the reported wide contour with a true circle", difference.isEmpty)
    }
}
