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
    /** The length of a round and of the break after it; 0 for one round. */
    val workMs: Long = 0L,
    val breakMs: Long = 0L,
    /** How many rounds were planned; time added goes to the last one. */
    val plannedRounds: Int = 1,
    /** For a session resumed after a pause, how far into its plan it was. */
    val doneMs: Long = 0L,
) {
    fun isOver(now: Long = System.currentTimeMillis()) = now >= endsAt

    /** Where the session is at a moment. [round] counts from 1. */
    data class Phase(
        val onBreak: Boolean,
        val round: Int,
        val rounds: Int,
        val startsAt: Long,
        val endsAt: Long,
    )

    private val hasBreaks: Boolean
        get() = workMs > 0L && breakMs > 0L

    /** Rounds of [workMs] with breaks of [breakMs]; the last runs to the end. */
    fun rounds(): Int = if (hasBreaks && plannedRounds > 1) plannedRounds else 1

    /**
     * The round or break at [now]. The app works this out the same way
     * (FocusPlan in Dart); keep the two alike.
     */
    /** Where the plan began: before [startedAt] for a resumed session. */
    private val planStart: Long
        get() = startedAt - doneMs

    fun phaseAt(now: Long = System.currentTimeMillis()): Phase {
        val n = rounds()
        val start = planStart
        if (n == 1) return Phase(false, 1, 1, start, endsAt)
        val cycle = workMs + breakMs
        for (k in 0 until n - 1) {
            val workEnd = start + k * cycle + workMs
            if (now < workEnd) return Phase(false, k + 1, n, start + k * cycle, workEnd)
            val next = start + (k + 1) * cycle
            if (now < next) return Phase(true, k + 1, n, workEnd, next)
        }
        return Phase(false, n, n, start + (n - 1) * cycle, endsAt)
    }

    /** Working time in the whole session, a part before a pause included. */
    fun focusedMs(): Long {
        val n = rounds()
        val start = planStart
        if (n == 1) return endsAt - start
        val cycle = workMs + breakMs
        var total = 0L
        for (k in 0 until n) {
            val from = start + k * cycle
            if (from >= endsAt) break
            val to = if (k == n - 1) endsAt else minOf(from + workMs, endsAt)
            total += to - from
        }
        return total
    }

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
                workMs = p.getLong("workMs", 0L),
                breakMs = p.getLong("breakMs", 0L),
                plannedRounds = p.getInt("rounds", 1),
                doneMs = p.getLong("doneMs", 0L),
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
                .putLong("workMs", state.workMs)
                .putLong("breakMs", state.breakMs)
                .putInt("rounds", state.plannedRounds)
                .putLong("doneMs", state.doneMs)
                .apply()
        }

        fun clear(context: Context) {
            prefs(context).edit().putBoolean("active", false).apply()
        }

        /**
         * What to block when a session arrives from another device: this
         * phone's own picks, saved by the app whenever the user changes them.
         */
        fun blocklist(context: Context): Pair<Set<String>, Boolean> {
            val p = prefs(context)
            val packages = p.getStringSet("blocklistPackages", emptySet())?.toSet() ?: emptySet()
            return packages to p.getBoolean("blocklistGames", false)
        }

        fun saveBlocklist(context: Context, packages: Set<String>, games: Boolean) {
            prefs(context).edit()
                .putStringSet("blocklistPackages", packages)
                .putBoolean("blocklistGames", games)
                .apply()
        }

        /**
         * The version of the shared session this phone last acted on, kept
         * after the session ends so older news cannot bring it back.
         */
        fun lastVersion(context: Context): String? = prefs(context).getString("version", null)

        fun setLastVersion(context: Context, version: String) {
            prefs(context).edit().putString("version", version).apply()
        }

        /**
         * Notes that the "Focus here" request ending at [until] was taken.
         * False if it was already, so it starts no second session.
         */
        fun takeRequest(context: Context, until: Long): Boolean {
            val p = prefs(context)
            if (p.getLong("request", 0L) == until) return false
            p.edit().putLong("request", until).commit()
            return true
        }

        /** Whether this app turned Do Not Disturb on, so only then it turns it off. */
        fun quietedByUs(context: Context) = prefs(context).getBoolean("quietedByUs", false)

        fun setQuietedByUs(context: Context, value: Boolean) {
            prefs(context).edit().putBoolean("quietedByUs", value).apply()
        }
    }
}
