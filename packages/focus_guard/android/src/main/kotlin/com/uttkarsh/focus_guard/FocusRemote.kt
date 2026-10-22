package com.uttkarsh.focus_guard

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.firebase.FirebaseApp
import org.json.JSONObject

/**
 * Sessions pushed from another device through Firebase. They arrive while
 * the app may be closed, so they are applied here without Flutter. The app
 * applies the same version again once it syncs, which changes nothing.
 */
object FocusRemote {
    private const val LONGEST_MS = 24 * 60 * 60 * 1000L
    private val main = Handler(Looper.getMainLooper())

    /** False when the app was built without Firebase settings. */
    fun available(context: Context) = FirebaseApp.getApps(context).isNotEmpty()

    /**
     * Applies the shared session [focus] (the synced record's fields) at
     * [version], on the main thread like every other entry point.
     */
    fun apply(context: Context, focus: JSONObject, version: String) {
        val app = context.applicationContext
        val state = sessionForPhone(app, focus, System.currentTimeMillis())
        main.post { FocusController.apply(app, version, state, pushed = true) }
    }

    /** The session to enforce here, or null when it does not run on the phone. */
    private fun sessionForPhone(context: Context, focus: JSONObject, now: Long): FocusState? {
        val endsAt = focus.optLong("ends_at", 0)
        val forPhone = focus.optString("target", "both") != "laptop"
        if (!focus.optBoolean("active") || !forPhone || endsAt <= now) return null
        // Nothing the app can start runs this long; not worth locking the phone.
        if (endsAt - now > LONGEST_MS) return null
        val (packages, games) = FocusState.blocklist(context)
        return FocusState(
            startedAt = focus.optLong("started_at", now),
            endsAt = endsAt,
            blockApps = focus.optBoolean("block_apps"),
            quiet = focus.optBoolean("quiet"),
            strict = focus.optBoolean("strict"),
            blockGames = games,
            packages = packages,
            startedBy = focus.optString("started_by"),
        )
    }
}
