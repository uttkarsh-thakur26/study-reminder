package com.uttkarsh.study_widget

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONException
import org.json.JSONObject

/** One reminder on the widget. [color] is ARGB, or 0 for the widget's accent. */
data class StudyWidgetItem(val title: String, val at: Long, val color: Int)

/**
 * What the app last sent: its next reminders, soonest first, and when the
 * phone's focus session ends (0 when none runs).
 */
data class StudyWidgetData(val items: List<StudyWidgetItem>, val focusUntil: Long) {
    /** The reminders still to come at [now]. */
    fun upcoming(now: Long): List<StudyWidgetItem> = items.filter { it.at > now }

    fun focusing(now: Long): Boolean = focusUntil > now

    companion object {
        val EMPTY = StudyWidgetData(emptyList(), 0L)

        /** Reads what the app sent; anything unreadable shows as nothing. */
        fun parse(json: String?): StudyWidgetData {
            if (json.isNullOrEmpty()) return EMPTY
            return try {
                val root = JSONObject(json)
                val items = ArrayList<StudyWidgetItem>()
                val list = root.optJSONArray("items")
                if (list != null) {
                    for (i in 0 until list.length()) {
                        val o: JSONObject = list.optJSONObject(i) ?: continue
                        val at: Long = o.optLong("at", 0L)
                        if (at <= 0L) continue
                        val title: String = if (o.isNull("title")) "" else o.optString("title", "")
                        // Sent as an unsigned ARGB number; the low 32 bits are the colour.
                        val color: Int = if (o.isNull("color")) 0 else o.optLong("color", 0L).toInt()
                        items.add(StudyWidgetItem(title, at, color))
                    }
                }
                items.sortBy { it.at }
                val focusUntil: Long = if (root.isNull("focusUntil")) 0L else root.optLong("focusUntil", 0L)
                StudyWidgetData(items, focusUntil)
            } catch (e: JSONException) {
                EMPTY
            }
        }
    }
}

/**
 * The widget's data and the token its "+" carries, kept in shared
 * preferences so the widget redraws without the app running.
 */
object StudyWidgetStore {
    private const val PREFS = "study_widget"
    private const val KEY_DATA = "data"
    private const val KEY_TOKEN = "quickAddToken"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun load(context: Context): StudyWidgetData =
        StudyWidgetData.parse(prefs(context).getString(KEY_DATA, null))

    fun save(context: Context, json: String) {
        prefs(context).edit().putString(KEY_DATA, json).commit()
    }

    /**
     * The token the "+" button hands the app. Each tap is taken once: taking
     * it moves the token on, so Android handing the same intent back later
     * (Recents, a restart of the app's process) opens nothing again.
     */
    fun token(context: Context): Long {
        val p = prefs(context)
        val current = p.getLong(KEY_TOKEN, 0L)
        if (current != 0L) return current
        val fresh = System.currentTimeMillis()
        p.edit().putLong(KEY_TOKEN, fresh).commit()
        return fresh
    }

    /** Takes the tap that carried [token]. False if it was taken already. */
    fun take(context: Context, token: Long): Boolean {
        val p = prefs(context)
        if (token == 0L || token != p.getLong(KEY_TOKEN, 0L)) return false
        p.edit().putLong(KEY_TOKEN, token + 1L).commit()
        return true
    }
}
