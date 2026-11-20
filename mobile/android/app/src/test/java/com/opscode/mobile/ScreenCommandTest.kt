package com.opscode.mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ScreenCommandTest {
    @Test fun acceptsExactLocalCommands() {
        assertEquals(ScreenCommand.Scroll(true, 10), ScreenCommand.parse("Scroll down ten times."))
        assertEquals(ScreenCommand.Scroll(false, 2), ScreenCommand.parse(" scroll  up twice "))
        assertEquals(ScreenCommand.Home, ScreenCommand.parse("go home"))
        assertEquals(ScreenCommand.Back, ScreenCommand.parse("Go back!"))
        assertEquals(ScreenCommand.Playback(false), ScreenCommand.parse("Pause video"))
    }

    @Test fun rejectsChainingAndScrollBeyondTheLimit() {
        for (invalid in listOf("scroll down zero times", "scroll down 100 times", "scroll up 11 times",
            "scroll down and approve", "click allow", "unlock the phone", "play then press home")) {
            assertNull(invalid, ScreenCommand.parse(invalid))
        }
    }

    @Test fun recognitionLabelsCanBeConfirmedDirectly() {
        val commands = listOf(ScreenCommand.Scroll(true, 1), ScreenCommand.Scroll(false, 10),
            ScreenCommand.Playback(true), ScreenCommand.Playback(false), ScreenCommand.Home, ScreenCommand.Back)
        for (command in commands) assertEquals(command, ScreenCommand.parse(command.label()))
    }
}
