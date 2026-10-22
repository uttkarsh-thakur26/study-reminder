package com.uttkarsh.focus_guard

import android.app.AlarmManager
import android.app.ForegroundServiceStartNotAllowedException
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Date

/**
 * Starts and ends sessions on this phone: Do Not Disturb, the session
 * service, the alarm that ends the session on time, and the notifications.
 * Every entry point (Dart, the alarms, the boot receiver) goes through here.
 */
object FocusController {
    private const val TAG = "FocusGuard"
    private const val SESSION_CHANNEL = "focus_guard_session"
    private const val DONE_CHANNEL = "focus_guard_done"
    const val SESSION_NOTIFICATION = 7301
    private const val DONE_NOTIFICATION = 7302
    private const val STOPPED_NOTIFICATION = 7303

    const val ACTION_END = "com.uttkarsh.focus_guard.END"
    const val ACTION_START = "com.uttkarsh.focus_guard.START"

    /** Saves [state] and enforces it. Safe to call again with the same state. */
    fun start(context: Context, state: FocusState) {
        if (state.isOver()) {
            finish(context, done = false)
            return
        }
        FocusState.save(context, state)
        applyQuiet(context, state.quiet)
        scheduleAlarm(context, ACTION_END, state.endsAt)
        startService(context, state, retry = true)
    }

    /** Enforces the saved session again, after a reboot or an app update. */
    fun restore(context: Context) {
        val state = FocusState.load(context) ?: return
        if (state.isOver()) finish(context, done = true) else start(context, state)
    }

    /** Ends the session. [done] posts "Focus done", for a session that ran out. */
    fun finish(context: Context, done: Boolean) {
        val state = FocusState.load(context)
        FocusState.clear(context)
        applyQuiet(context, false)
        cancelAlarm(context, ACTION_END)
        cancelAlarm(context, ACTION_START)
        context.stopService(Intent(context, FocusService::class.java))
        notifications(context).cancel(SESSION_NOTIFICATION)
        if (done && state != null) postDone(context, state)
    }

    fun isRunning(context: Context) = FocusState.load(context)?.isOver() == false

    /**
     * Starts the session service. Android may refuse while the app is in the
     * background: then try once more from an exact alarm, which is allowed to
     * start it, and failing that ask the user with a notification.
     */
    fun startService(context: Context, state: FocusState, retry: Boolean) {
        try {
            context.startForegroundService(Intent(context, FocusService::class.java))
            cancelAlarm(context, ACTION_START)
        } catch (e: Exception) {
            if (!isStartNotAllowed(e)) throw e
            Log.w(TAG, "Session service not allowed from the background", e)
            if (retry) {
                scheduleAlarm(context, ACTION_START, System.currentTimeMillis() + 1000)
            } else {
                notifications(context).notify(SESSION_NOTIFICATION, waitingNotification(context, state))
            }
        }
    }

    private fun isStartNotAllowed(e: Exception) =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            e is ForegroundServiceStartNotAllowedException

    // Do Not Disturb. Turned on only when it is off, and turned off only when
    // this app turned it on, so a user's own Do Not Disturb is left alone.
    // On Android 15 and later this switches a rule owned by this app.
    private fun applyQuiet(context: Context, on: Boolean) {
        val nm = notifications(context)
        if (!nm.isNotificationPolicyAccessGranted) return
        try {
            if (on) {
                val current = nm.currentInterruptionFilter
                if (current == NotificationManager.INTERRUPTION_FILTER_ALL ||
                    current == NotificationManager.INTERRUPTION_FILTER_UNKNOWN
                ) {
                    nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                    FocusState.setQuietedByUs(context, true)
                }
            } else if (FocusState.quietedByUs(context)) {
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                FocusState.setQuietedByUs(context, false)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Do Not Disturb change refused", e)
        }
    }

    private fun alarmIntent(context: Context, action: String): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            if (action == ACTION_END) 1 else 2,
            Intent(context, FocusReceiver::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun scheduleAlarm(context: Context, action: String, at: Long) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val intent = alarmIntent(context, action)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarms.canScheduleExactAlarms()) {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
            } else {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
            }
        } catch (e: SecurityException) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
        }
    }

    private fun cancelAlarm(context: Context, action: String) {
        context.getSystemService(AlarmManager::class.java).cancel(alarmIntent(context, action))
    }

    // Notifications.

    fun notifications(context: Context): NotificationManager =
        context.getSystemService(NotificationManager::class.java)

    private fun ensureChannels(context: Context) {
        val nm = notifications(context)
        nm.createNotificationChannel(
            NotificationChannel(SESSION_CHANNEL, "Focus session", NotificationManager.IMPORTANCE_LOW)
                .apply { description = "Shows while a focus session runs" },
        )
        nm.createNotificationChannel(
            NotificationChannel(DONE_CHANNEL, "Focus finished", NotificationManager.IMPORTANCE_DEFAULT)
                .apply { description = "When a focus session ends" },
        )
    }

    private fun openApp(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return null
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        launch.putExtra("focus_guard_open", true)
        return PendingIntent.getActivity(
            context,
            3,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun clock(context: Context, at: Long): String =
        android.text.format.DateFormat.getTimeFormat(context).format(Date(at))

    /** The notification the session service shows while it runs. */
    fun sessionNotification(context: Context, state: FocusState): Notification {
        ensureChannels(context)
        val text = buildString {
            append("Until ")
            append(clock(context, state.endsAt))
            if (state.startedBy.isNotEmpty()) append(" · started on ${state.startedBy}")
        }
        return Notification.Builder(context, SESSION_CHANNEL)
            .setSmallIcon(R.drawable.focus_guard_stat)
            .setContentTitle(if (state.blockApps) "Focus on · distractions blocked" else "Focus on")
            .setContentText(text)
            .setWhen(state.endsAt)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_STATUS)
            .setContentIntent(openApp(context))
            .build()
    }

    private fun waitingNotification(context: Context, state: FocusState): Notification {
        ensureChannels(context)
        return Notification.Builder(context, SESSION_CHANNEL)
            .setSmallIcon(R.drawable.focus_guard_stat)
            .setContentTitle("Focus is on until ${clock(context, state.endsAt)}")
            .setContentText("Tap to start blocking apps on this phone.")
            .setOngoing(true)
            .setContentIntent(openApp(context))
            .build()
    }

    private fun postDone(context: Context, state: FocusState) {
        ensureChannels(context)
        val minutes = ((state.endsAt - state.startedAt) / 60000).coerceAtLeast(1)
        val notification = Notification.Builder(context, DONE_CHANNEL)
            .setSmallIcon(R.drawable.focus_guard_stat)
            .setContentTitle("Focus done")
            .setContentText("$minutes minutes of focus. Nice work.")
            .setAutoCancel(true)
            .setContentIntent(openApp(context))
            .build()
        notifications(context).notify(DONE_NOTIFICATION, notification)
    }

    /** A short note that another device ended the session, gone after 10 s. */
    fun postStopped(context: Context) {
        ensureChannels(context)
        val notification = Notification.Builder(context, SESSION_CHANNEL)
            .setSmallIcon(R.drawable.focus_guard_stat)
            .setContentTitle("Focus ended")
            .setContentText("Stopped from your other device.")
            .setAutoCancel(true)
            .setTimeoutAfter(10_000)
            .setContentIntent(openApp(context))
            .build()
        notifications(context).notify(STOPPED_NOTIFICATION, notification)
    }
}
