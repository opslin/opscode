package com.opscode.mobile

import java.util.Locale

internal sealed interface ScreenCommand {
    data class Scroll(val down: Boolean, val count: Int) : ScreenCommand
    data class Playback(val play: Boolean) : ScreenCommand
    data object Back : ScreenCommand
    data object Home : ScreenCommand

    fun label(): String = when (this) {
        is Scroll -> "Scroll ${if (down) "down" else "up"} ${if (count == 1) "once" else "$count times"}"
        is Playback -> if (play) "Play" else "Pause"
        Back -> "Go back"
        Home -> "Go home"
    }

    companion object {
        private val scroll = Regex("scroll (up|down)(?: (once|twice|[0-9]{1,2}|one|two|three|four|five|six|seven|eight|nine|ten)(?: times?)?)?")
        private val numbers = listOf("one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten")
        private val whitespace = Regex("\\s+")

        fun parse(text: String): ScreenCommand? {
            val phrase = text.lowercase(Locale.ROOT).trim().trimEnd('.', '?', '!').replace(whitespace, " ")
            when (phrase) {
                "back", "go back" -> return Back
                "home", "go home" -> return Home
                "play", "play video", "resume playback" -> return Playback(true)
                "pause", "pause video", "pause playback" -> return Playback(false)
            }
            val match = scroll.matchEntire(phrase) ?: return null
            val amount = match.groupValues[2]
            val count = when (amount) {
                "", "once" -> 1
                "twice" -> 2
                else -> amount.toIntOrNull() ?: (numbers.indexOf(amount) + 1)
            }
            return if (count in 1..10) Scroll(match.groupValues[1] == "down", count) else null
        }
    }
}
