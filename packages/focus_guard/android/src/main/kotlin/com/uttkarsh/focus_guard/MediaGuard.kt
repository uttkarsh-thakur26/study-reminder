package com.uttkarsh.focus_guard

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.media.session.MediaController
import android.media.session.MediaSession
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.SystemClock
import android.provider.Settings
import android.service.notification.NotificationListenerService

/**
 * Notification access, which Android requires before an app may see and
 * control other apps' media. Nothing here reads notifications: once
 * connected it asks to be let go, so none are delivered, and the access
 * stays granted.
 */
class FocusMediaListener : NotificationListenerService() {
    override fun onListenerConnected() {
        requestUnbind()
    }
}

/**
 * Pauses video and music from blocked apps while a session runs, so they
 * cannot keep playing in a floating window or in the background (YouTube
 * Premium, for example). Reacts as soon as one starts or resumes playing,
 * with the screen off too.
 */
class MediaGuard(
    private val context: Context,
    private val handler: Handler,
    private val isBlocked: (String) -> Boolean,
) {
    private val sessions = context.getSystemService(MediaSessionManager::class.java)
    private val listener = ComponentName(context, FocusMediaListener::class.java)
    private val watched = HashMap<MediaSession.Token, Pair<MediaController, MediaController.Callback>>()
    private var listening = false
    private var checkedAt = 0L

    private val changed = MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
        watch(controllers.orEmpty())
    }

    /**
     * Starts watching once notification access is given, and notices it
     * being taken back, so a later grant starts it again. Cheap to call
     * often: it looks at most every few seconds.
     */
    fun start() {
        val now = SystemClock.elapsedRealtime()
        if (checkedAt != 0L && now - checkedAt < RECHECK_MS) return
        checkedAt = now
        if (!granted(context)) {
            release()
            return
        }
        if (listening) return
        try {
            sessions.addOnActiveSessionsChangedListener(changed, listener, handler)
            listening = true
            watch(sessions.getActiveSessions(listener))
        } catch (e: SecurityException) {
            // Access was taken back a moment ago.
            release()
        }
    }

    /** Looks again, after the block list changed. */
    fun recheck() {
        for ((controller, _) in watched.values) pauseIfBlocked(controller)
    }

    fun stop() {
        release()
        checkedAt = 0L
    }

    private fun release() {
        if (listening) sessions.removeOnActiveSessionsChangedListener(changed)
        listening = false
        for ((controller, callback) in watched.values) controller.unregisterCallback(callback)
        watched.clear()
    }

    private fun watch(controllers: List<MediaController>) {
        val tokens = controllers.map { it.sessionToken }.toSet()
        val gone = watched.keys - tokens
        for (token in gone) {
            val (controller, callback) = watched.remove(token) ?: continue
            controller.unregisterCallback(callback)
        }
        for (controller in controllers) {
            if (controller.sessionToken !in watched) {
                val callback = object : MediaController.Callback() {
                    override fun onPlaybackStateChanged(state: PlaybackState?) = pauseIfBlocked(controller)
                }
                controller.registerCallback(callback, handler)
                watched[controller.sessionToken] = controller to callback
            }
            pauseIfBlocked(controller)
        }
    }

    private fun pauseIfBlocked(controller: MediaController) {
        val state = controller.playbackState?.state ?: return
        if (state !in playing) return
        if (!isBlocked(controller.packageName)) return
        controller.transportControls.pause()
    }

    companion object {
        private const val RECHECK_MS = 5000L

        private val playing = setOf(
            PlaybackState.STATE_PLAYING,
            PlaybackState.STATE_BUFFERING,
            PlaybackState.STATE_CONNECTING,
            PlaybackState.STATE_FAST_FORWARDING,
            PlaybackState.STATE_REWINDING,
        )

        fun granted(context: Context): Boolean {
            val component = ComponentName(context, FocusMediaListener::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                return context.getSystemService(NotificationManager::class.java)
                    .isNotificationListenerAccessGranted(component)
            }
            val enabled = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
                ?: return false
            return enabled.split(':').any { ComponentName.unflattenFromString(it) == component }
        }
    }
}
