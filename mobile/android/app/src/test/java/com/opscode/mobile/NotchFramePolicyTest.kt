package com.opscode.mobile

import org.junit.Assert.assertEquals
import org.junit.Test

class NotchFramePolicyTest {
    @Test
    fun persistentAlertRedrawsAtThirtyFps() {
        assertEquals(33L, notchFrameDelay(animated = true, shown = true, focused = true,
            glowing = true, transitioning = false, poseFps = 10))
    }

    @Test
    fun transitionsRemainDisplaySynchronized() {
        assertEquals(0L, notchFrameDelay(animated = true, shown = true, focused = true,
            glowing = true, transitioning = true, poseFps = 10))
    }

    @Test
    fun unfocusedNotchStopsSchedulingFrames() {
        assertEquals(null, notchFrameDelay(animated = true, shown = true, focused = false,
            glowing = true, transitioning = false, poseFps = 10))
    }
}
