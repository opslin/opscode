package com.opscode.mobile

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class DissolveBatcherTest {
    @Test
    fun thousandsOfTilesUseBoundedDrawingBatches() {
        val colors = IntArray(8) { Color.rgb(it * 20, 20, 20) }
        val batcher = DissolveBatcher(colors)
        val canvas = Canvas(Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888))
        val paint = Paint()

        batcher.begin()
        repeat(2_000) { index ->
            batcher.add(index % colors.size, index % 256, 0f, 0f, 8f, 8f)
        }
        batcher.draw(canvas, paint)

        assertTrue("Dissolve must use at most 128 path draws", batcher.batchCount <= 128)
    }
}
