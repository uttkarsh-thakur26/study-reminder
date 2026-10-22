package com.uttkarsh.focus_guard

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
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
 * control other apps' media. Nothing here reads notifications.
 */
class FocusMediaListener : NotificationListenerService()

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
    private var triedAt = 0L

    private val changed = MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
        watch(controllers.orEmpty())
    }

    /** Starts watching, once notification access is given. Safe to repeat. */
    fun start() {
        if (listening) return
        val now = SystemClock.elapsedRealtime()
        if (triedAt != 0L && now - triedAt < RETRY_MS) return
        triedAt = now
        if (!granted(context)) return
        try {
            sessions.addOnActiveSessionsChangedListener(changed, listener, handler)
            listening = true
            watch(sessions.getActiveSessions(listener))
        } catch (e: SecurityException) {
            // Access was taken back a moment ago.
            stop()
        }
    }

    /** Looks again, after the block list changed. */
    fun recheck() {
        for ((controller, _) in watched.values) pauseIfBlocked(controller)
    }

    fun stop() {
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
        private const val RETRY_MS = 5000L

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

        /**
         * Without notification access, takes the sound away from whatever is
         * playing, which makes media apps pause. Used when a blocked app was
         * just covered, since it may go on playing behind the block screen.
         */
        fun silence(context: Context) {
            val audio = context.getSystemService(AudioManager::class.java)
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                .build()
            if (audio.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                audio.abandonAudioFocusRequest(request)
            }
        }
    }
}
