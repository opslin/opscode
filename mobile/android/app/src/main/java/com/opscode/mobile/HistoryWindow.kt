package com.opscode.mobile

import org.json.JSONObject

/** Preserve messages that moved out of the live page after the user loaded older history. */
internal fun mergeEarlierHistory(earlier: List<JSONObject>, previous: List<JSONObject>, latest: List<JSONObject>): List<JSONObject> {
    if (earlier.isEmpty()) return earlier
    fun key(item: JSONObject) = item.optString("turn") + ":" + item.optString("role")
    val latestKeys = latest.map(::key).toHashSet()
    return (earlier + previous).filter { key(it) !in latestKeys }.associateBy(::key).values.toList()
}
