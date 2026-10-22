package com.uttkarsh.focus_guard

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONException
import org.json.JSONObject

/** Receives the focus messages the server's focus-push function sends. */
class FocusMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (message.data["type"] != "focus") return
        val focus = try {
            JSONObject(message.data["focus"] ?: return)
        } catch (e: JSONException) {
            Log.w("FocusGuard", "Unreadable focus message", e)
            return
        }
        FocusRemote.apply(this, focus, message.data["version"] ?: "")
    }

    // The app asks Firebase for the token itself and sends it on its next
    // sync, so a new token needs nothing here.
    override fun onNewToken(token: String) = Unit
}
