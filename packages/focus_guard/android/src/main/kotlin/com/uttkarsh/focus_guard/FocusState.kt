package com.uttkarsh.focus_guard

import android.content.Context

/**
 * The session this phone is enforcing, kept in shared preferences so the
 * service, the alarms and the boot receiver all see it, even when no Flutter
 * engine is running.
 */
data class FocusState(
    val startedAt: Long,
    val endsAt: Long,
    val blockApps: Boolean,
    val quiet: Boolean,
    val strict: Boolean,
    val blockGames: Boolean,
    val packages: Set<String>,
    val startedBy: String,
) {
    fun isOver(now: Long = System.currentTimeMillis()) = now >= endsAt

    companion object {
        private const val PREFS = "focus_guard"

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        fun load(context: Context): FocusState? {
            val p = prefs(context)
            if (!p.getBoolean("active", false)) return null
            return FocusState(
                startedAt = p.getLong("startedAt", 0),
                endsAt = p.getLong("endsAt", 0),
                blockApps = p.getBoolean("blockApps", false),
                quiet = p.getBoolean("quiet", false),
                strict = p.getBoolean("strict", false),
                blockGames = p.getBoolean("blockGames", false),
                packages = p.getStringSet("packages", emptySet())?.toSet() ?: emptySet(),
                startedBy = p.getString("startedBy", "") ?: "",
            )
        }

        fun save(context: Context, state: FocusState) {
            prefs(context).edit()
                .putBoolean("active", true)
                .putLong("startedAt", state.startedAt)
                .putLong("endsAt", state.endsAt)
                .putBoolean("blockApps", state.blockApps)
                .putBoolean("quiet", state.quiet)
                .putBoolean("strict", state.strict)
                .putBoolean("blockGames", state.blockGames)
                .putStringSet("packages", state.packages)
                .putString("startedBy", state.startedBy)
                .apply()
        }

        fun clear(context: Context) {
            prefs(context).edit().putBoolean("active", false).apply()
        }

        /** Whether this app turned Do Not Disturb on, so only then it turns it off. */
        fun quietedByUs(context: Context) = prefs(context).getBoolean("quietedByUs", false)

        fun setQuietedByUs(context: Context, value: Boolean) {
            prefs(context).edit().putBoolean("quietedByUs", value).apply()
        }
    }
}
