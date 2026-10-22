package com.uttkarsh.focus_guard

import android.content.Context
import com.google.firebase.FirebaseApp
import org.json.JSONObject

/**
 * Sessions pushed from another device through Firebase. They arrive while
 * the app may be closed, so they are applied here without Flutter. The app
 * applies the same session again once it syncs, which changes nothing.
 */
object FocusRemote {
    /** False when the app was built without Firebase settings. */
    fun available(context: Context) = FirebaseApp.getApps(context).isNotEmpty()

    /**
     * Applies the shared session [focus], as the server has it (the synced
     * record's fields). A message about an older session than the one
     * running here is ignored, so the newest start wins.
     */
    fun apply(context: Context, focus: JSONObject, now: Long = System.currentTimeMillis()) {
        val startedAt = focus.optLong("started_at", 0)
        val endsAt = focus.optLong("ends_at", 0)
        val running = FocusState.load(context)
        if (running != null && running.startedAt > startedAt) return
        val forPhone = focus.optString("target", "both") != "laptop"
        if (focus.optBoolean("active") && forPhone && endsAt > now) {
            val (packages, games) = FocusState.blocklist(context)
            FocusController.start(
                context,
                FocusState(
                    startedAt = startedAt,
                    endsAt = endsAt,
                    blockApps = focus.optBoolean("block_apps"),
                    quiet = focus.optBoolean("quiet"),
                    strict = focus.optBoolean("strict"),
                    blockGames = games,
                    packages = packages,
                    startedBy = focus.optString("started_by"),
                ),
            )
        } else if (running != null) {
            FocusController.finish(context, done = false)
            FocusController.postStopped(context)
        }
    }
}
