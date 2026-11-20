package com.opscode.mobile

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class HistoryWindowTest {
    private fun message(turn: String, role: String = "user") = JSONObject().put("turn", turn).put("role", role)

    @Test fun loadedOlderMessagesStayVisibleWhenNewMessagesPushThemOutOfTheLatestPage() {
        val kept = mergeEarlierHistory(listOf(message("a")), listOf(message("b"), message("c")), listOf(message("c"), message("d")))
        assertEquals(listOf("a", "b"), kept.map { it.getString("turn") })
    }

    @Test fun liveWindowDoesNotGrowUntilTheUserLoadsEarlierMessages() {
        assertEquals(emptyList<JSONObject>(), mergeEarlierHistory(emptyList(), listOf(message("a")), listOf(message("b"))))
    }
}
